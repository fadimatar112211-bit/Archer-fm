-- Archer FM Phase 5: Supabase account-scoped persistence baseline.
-- Apply with Supabase CLI migrations. Never expose the service-role key to a client.
begin;

create table if not exists public.player_profiles (
  user_id uuid primary key references auth.users(id) on delete cascade,
  display_name text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint player_profiles_display_name_length
    check (display_name is null or char_length(display_name) between 1 and 32),
  constraint player_profiles_display_name_safe
    check (
      display_name is null or (
        display_name = btrim(display_name)
        and display_name !~ '[[:cntrl:]]'
        and display_name !~ U&'[\202A-\202E]'
      )
    )
);

-- Keep profile timestamps accurate without granting clients permission to
-- modify created_at/updated_at directly.
create or replace function public.set_player_profile_updated_at()
returns trigger
language plpgsql
set search_path = ''
as $
begin
  new.updated_at = now();
  return new;
end;
$;

drop trigger if exists player_profiles_set_updated_at on public.player_profiles;
create trigger player_profiles_set_updated_at
  before update on public.player_profiles
  for each row execute procedure public.set_player_profile_updated_at();
revoke all on function public.set_player_profile_updated_at()
  from public, anon, authenticated;

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

-- Explicitly remove broad/default table grants before granting the minimum
-- client surface. RLS policies alone are not a substitute for SQL privileges.
revoke all on table public.player_profiles,
  public.hero_progress,
  public.monster_progress,
  public.currency_transactions,
  public.match_results
  from public, anon, authenticated;

grant select on table public.player_profiles,
  public.hero_progress,
  public.monster_progress,
  public.currency_transactions,
  public.match_results
  to authenticated;

grant update (display_name) on table public.player_profiles to authenticated;
grant all on table public.player_profiles,
  public.hero_progress,
  public.monster_progress,
  public.currency_transactions,
  public.match_results
  to service_role;
revoke all on sequence public.currency_transactions_id_seq
  from public, anon, authenticated;
grant usage, select on sequence public.currency_transactions_id_seq
  to service_role;

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
revoke all on function public.handle_new_archer_fm_user()
  from public, anon, authenticated;


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
as $phase5$
declare
  current_revision bigint;
begin
  if p_user_id is null or p_expected_revision is null or p_expected_revision < 0 then
    raise exception 'invalid_hero_progress_revision' using errcode = '22023';
  end if;
  if jsonb_typeof(p_data) is distinct from 'object' then
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
$phase5$;

create or replace function public.save_monster_progress(
  p_user_id uuid,
  p_data jsonb,
  p_expected_revision bigint
)
returns bigint
language plpgsql
security definer
set search_path = ''
as $phase5$
declare
  current_revision bigint;
begin
  if p_user_id is null or p_expected_revision is null or p_expected_revision < 0 then
    raise exception 'invalid_monster_progress_revision' using errcode = '22023';
  end if;
  if jsonb_typeof(p_data) is distinct from 'object' then
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
$phase5$;

revoke all on function public.save_hero_progress(uuid, jsonb, bigint)
  from public, anon, authenticated;
revoke all on function public.save_monster_progress(uuid, jsonb, bigint)
  from public, anon, authenticated;
grant execute on function public.save_hero_progress(uuid, jsonb, bigint)
  to service_role;
grant execute on function public.save_monster_progress(uuid, jsonb, bigint)
  to service_role;


-- Finalize one authenticated player's match result and reward in one database
-- transaction. Retries with the same match/player and identical payload return
-- the original result without awarding currency twice.
create or replace function public.finalize_match_player_result(
  p_match_id text,
  p_user_id uuid,
  p_placement smallint,
  p_score bigint,
  p_crystals_remaining smallint,
  p_finish_reason text,
  p_reward_amount bigint,
  p_idempotency_key text
)
returns table (
  result_id uuid,
  reward_transaction_id bigint,
  currency_balance bigint
)
language plpgsql
security definer
set search_path = ''
as $phase5$
declare
  current_currency bigint;
  existing public.match_results%rowtype;
  transaction_id bigint;
  inserted_result_id uuid;
  existing_reward bigint := 0;
  existing_idempotency_key text;
begin
  if p_match_id is null or char_length(p_match_id) not between 1 and 128
     or p_user_id is null
     or p_placement is null or p_placement not between 1 and 4
     or p_score is null or p_score < 0
     or p_crystals_remaining is null or p_crystals_remaining not between 0 and 7
     or p_finish_reason is null or char_length(p_finish_reason) not between 1 and 48
     or p_reward_amount is null or p_reward_amount < 0
     or p_idempotency_key is null
     or char_length(p_idempotency_key) not between 1 and 128 then
    raise exception 'invalid_match_settlement' using errcode = '22023';
  end if;

  -- Lock the profile's progression row to serialize currency settlement.
  select (data->>'permanentCurrency')::bigint
    into current_currency
    from public.hero_progress
    where user_id = p_user_id
    for update;

  if not found then
    insert into public.hero_progress(user_id)
      values (p_user_id) on conflict (user_id) do nothing;
    select (data->>'permanentCurrency')::bigint
      into current_currency
      from public.hero_progress
      where user_id = p_user_id
      for update;
  end if;

  if current_currency is null or current_currency < 0 then
    raise exception 'invalid_persisted_currency' using errcode = '22023';
  end if;

  select * into existing
    from public.match_results
    where match_id = p_match_id and user_id = p_user_id
    for update;

  if found then
    if existing.reward_transaction_id is not null then
      select amount, idempotency_key
        into existing_reward, existing_idempotency_key
        from public.currency_transactions
        where id = existing.reward_transaction_id;
    end if;
    if existing.placement <> p_placement
       or existing.score <> p_score
       or existing.crystals_remaining <> p_crystals_remaining
       or existing.finish_reason <> p_finish_reason
       or existing_reward <> p_reward_amount
       or (p_reward_amount > 0 and existing_idempotency_key <> p_idempotency_key) then
      raise exception 'match_result_idempotency_conflict' using errcode = '23505';
    end if;
    return query select existing.id, existing.reward_transaction_id, current_currency;
    return;
  end if;

  if p_reward_amount > 0 then
    insert into public.currency_transactions(
      user_id, idempotency_key, amount, reason, reference_id
    ) values (
      p_user_id, p_idempotency_key, p_reward_amount, 'match_reward', p_match_id
    ) returning id into transaction_id;

    current_currency := current_currency + p_reward_amount;
    update public.hero_progress
      set data = jsonb_set(data, '{permanentCurrency}', to_jsonb(current_currency), true),
          revision = revision + 1,
          updated_at = now()
      where user_id = p_user_id;
  end if;

  insert into public.match_results(
    match_id, user_id, placement, score, crystals_remaining,
    finish_reason, reward_transaction_id
  ) values (
    p_match_id, p_user_id, p_placement, p_score, p_crystals_remaining,
    p_finish_reason, transaction_id
  ) returning id into inserted_result_id;

  return query select inserted_result_id, transaction_id, current_currency;
end;
$phase5$;

revoke all on function public.finalize_match_player_result(
  text, uuid, smallint, bigint, smallint, text, bigint, text
) from public, anon, authenticated;
grant execute on function public.finalize_match_player_result(
  text, uuid, smallint, bigint, smallint, text, bigint, text
) to service_role;


commit;
