-- Archer FM Phase 5: Supabase account-scoped persistence baseline.
-- Apply with Supabase CLI migrations. Never expose the service-role key to a client.
begin;

create table if not exists public.player_profiles (
  user_id uuid primary key references auth.users(id) on delete cascade,
  display_name text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint player_profiles_display_name_length
    check (display_name is null or char_length(display_name) between 1 and 32)
);

create table if not exists public.hero_progress (
  user_id uuid primary key references auth.users(id) on delete cascade,
  schema_version integer not null default 1 check (schema_version = 1),
  data jsonb not null default '{"schemaVersion":1,"permanentCurrency":0,"unlockedWeaponIds":["ranger_greenbow","flame_greatsword","shadow_twinfangs","storm_spear"],"weaponUpgradeLevels":{},"heroLevels":{},"heroExperience":{}}'::jsonb,
  revision bigint not null default 0 check (revision >= 0),
  updated_at timestamptz not null default now(),
  constraint hero_progress_data_object check (jsonb_typeof(data) = 'object')
);

create table if not exists public.monster_progress (
  user_id uuid primary key references auth.users(id) on delete cascade,
  schema_version integer not null default 1 check (schema_version = 1),
  data jsonb not null default '{"version":1,"levels":{"runner":1,"tank":1,"stalker":1,"ranged":1}}'::jsonb,
  revision bigint not null default 0 check (revision >= 0),
  updated_at timestamptz not null default now(),
  constraint monster_progress_data_object check (jsonb_typeof(data) = 'object')
);

-- Every currency movement is an immutable server-authored ledger entry.
-- idempotency_key prevents retries from applying the same reward/spend twice.
create table if not exists public.currency_transactions (
  id bigint generated always as identity primary key,
  user_id uuid not null references auth.users(id) on delete cascade,
  idempotency_key text not null,
  amount bigint not null check (amount <> 0),
  reason text not null check (char_length(reason) between 1 and 80),
  reference_id text,
  created_at timestamptz not null default now(),
  unique (user_id, idempotency_key)
);

create table if not exists public.match_results (
  id uuid primary key default gen_random_uuid(),
  match_id text not null,
  user_id uuid not null references auth.users(id) on delete cascade,
  placement smallint not null check (placement between 1 and 4),
  score bigint not null check (score >= 0),
  crystals_remaining smallint not null check (crystals_remaining between 0 and 7),
  finish_reason text not null check (char_length(finish_reason) between 1 and 48),
  reward_transaction_id bigint references public.currency_transactions(id),
  completed_at timestamptz not null default now(),
  unique (match_id, user_id)
);

create index if not exists currency_transactions_user_created_idx
  on public.currency_transactions(user_id, created_at desc);
create index if not exists match_results_user_completed_idx
  on public.match_results(user_id, completed_at desc);

alter table public.player_profiles enable row level security;
alter table public.hero_progress enable row level security;
alter table public.monster_progress enable row level security;
alter table public.currency_transactions enable row level security;
alter table public.match_results enable row level security;

-- A signed-in player can read their own profile and update only its display name.
drop policy if exists player_profiles_select_own on public.player_profiles;
create policy player_profiles_select_own on public.player_profiles
  for select to authenticated using (auth.uid() = user_id);
drop policy if exists player_profiles_update_own on public.player_profiles;
create policy player_profiles_update_own on public.player_profiles
  for update to authenticated using (auth.uid() = user_id)
  with check (auth.uid() = user_id);
revoke update on table public.player_profiles from authenticated;
grant update (display_name) on table public.player_profiles to authenticated;

-- Clients can read their own progression, but cannot write progression,
-- balances, rewards or match results. Trusted backend uses service-role access.
drop policy if exists hero_progress_select_own on public.hero_progress;
create policy hero_progress_select_own on public.hero_progress
  for select to authenticated using (auth.uid() = user_id);
drop policy if exists monster_progress_select_own on public.monster_progress;
create policy monster_progress_select_own on public.monster_progress
  for select to authenticated using (auth.uid() = user_id);
drop policy if exists currency_transactions_select_own on public.currency_transactions;
create policy currency_transactions_select_own on public.currency_transactions
  for select to authenticated using (auth.uid() = user_id);
drop policy if exists match_results_select_own on public.match_results;
create policy match_results_select_own on public.match_results
  for select to authenticated using (auth.uid() = user_id);

-- Do not add client INSERT/UPDATE/DELETE policies for economy or progression.
-- Backend writes must use verified JWT subject + service-role credentials.

create or replace function public.handle_new_archer_fm_user()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  insert into public.player_profiles(user_id)
  values (new.id)
  on conflict (user_id) do nothing;

  insert into public.hero_progress(user_id)
  values (new.id)
  on conflict (user_id) do nothing;

  insert into public.monster_progress(user_id)
  values (new.id)
  on conflict (user_id) do nothing;

  return new;
end;
$$;

drop trigger if exists on_auth_user_created_archer_fm on auth.users;
create trigger on_auth_user_created_archer_fm
  after insert on auth.users
  for each row execute procedure public.handle_new_archer_fm_user();


-- Optimistic revision checks prevent two game-server instances from silently
-- overwriting each other's progression updates. These RPCs are backend-only.
create or replace function public.save_hero_progress(
  p_user_id uuid,
  p_data jsonb,
  p_expected_revision bigint
)
returns bigint
language plpgsql
security definer
set search_path = ''
as $
declare
  current_revision bigint;
begin
  if jsonb_typeof(p_data) <> 'object' then
    raise exception 'invalid_progress_document' using errcode = '22023';
  end if;

  select revision into current_revision
  from public.hero_progress
  where user_id = p_user_id
  for update;

  if not found then
    insert into public.hero_progress(user_id)
    values (p_user_id)
    on conflict (user_id) do nothing;
    select revision into current_revision
    from public.hero_progress
    where user_id = p_user_id
    for update;
  end if;

  if current_revision <> p_expected_revision then
    raise exception 'hero_progress_revision_conflict' using errcode = '40001';
  end if;

  update public.hero_progress
  set data = p_data,
      revision = current_revision + 1,
      updated_at = now()
  where user_id = p_user_id;

  return current_revision + 1;
end;
$;

create or replace function public.save_monster_progress(
  p_user_id uuid,
  p_data jsonb,
  p_expected_revision bigint
)
returns bigint
language plpgsql
security definer
set search_path = ''
as $
declare
  current_revision bigint;
begin
  if jsonb_typeof(p_data) <> 'object' then
    raise exception 'invalid_monster_progress_document' using errcode = '22023';
  end if;

  select revision into current_revision
  from public.monster_progress
  where user_id = p_user_id
  for update;

  if not found then
    insert into public.monster_progress(user_id)
    values (p_user_id)
    on conflict (user_id) do nothing;
    select revision into current_revision
    from public.monster_progress
    where user_id = p_user_id
    for update;
  end if;

  if current_revision <> p_expected_revision then
    raise exception 'monster_progress_revision_conflict' using errcode = '40001';
  end if;

  update public.monster_progress
  set data = p_data,
      revision = current_revision + 1,
      updated_at = now()
  where user_id = p_user_id;

  return current_revision + 1;
end;
$;

revoke all on function public.save_hero_progress(uuid, jsonb, bigint)
  from public, anon, authenticated;
revoke all on function public.save_monster_progress(uuid, jsonb, bigint)
  from public, anon, authenticated;
grant execute on function public.save_hero_progress(uuid, jsonb, bigint)
  to service_role;
grant execute on function public.save_monster_progress(uuid, jsonb, bigint)
  to service_role;

commit;
