-- Archer FM Phase 5: atomic server-authoritative progression purchases.
-- This migration intentionally accepts cost/target only from trusted gateway code.
begin;

create or replace function public.purchase_player_progression(
  p_user_id uuid,
  p_purchase_type text,
  p_target_id text,
  p_cost bigint,
  p_max_level integer,
  p_expected_hero_revision bigint,
  p_expected_monster_revision bigint,
  p_idempotency_key text
)
returns table (
  currency_balance bigint,
  hero_revision bigint,
  monster_revision bigint,
  resulting_level integer,
  already_applied boolean
)
language plpgsql
security definer
set search_path = ''
as $purchase$
declare
  hero_data jsonb;
  monster_data jsonb;
  current_balance bigint;
  current_hero_revision bigint;
  current_monster_revision bigint;
  current_level integer;
  existing_transaction public.currency_transactions%rowtype;
  next_level integer;
  transaction_reason text;
begin
  if p_user_id is null
     or p_purchase_type is null
     or p_purchase_type not in ('weapon_unlock', 'weapon_upgrade', 'monster_upgrade')
     or p_target_id is null or char_length(p_target_id) not between 1 and 96
     or p_cost is null or p_cost <= 0
     or p_max_level is null or p_max_level < 1 or p_max_level > 40
     or p_expected_hero_revision is null or p_expected_hero_revision < 0
     or p_expected_monster_revision is null or p_expected_monster_revision < 0
     or p_idempotency_key is null
     or char_length(p_idempotency_key) not between 1 and 128 then
    raise exception 'invalid_progression_purchase' using errcode = '22023';
  end if;

  -- Defense in depth: even trusted gateway mistakes cannot create ownership
  -- records for weapon IDs that do not exist in the shipped four-hero roster.
  if p_purchase_type in ('weapon_unlock', 'weapon_upgrade')
     and p_target_id not in (
       'ranger_greenbow', 'ranger_longbow', 'ranger_twinshot',
       'flame_greatsword', 'flame_cleaver', 'flame_dualblades',
       'shadow_twinfangs', 'shadow_nightfang', 'shadow_soulblades',
       'storm_spear', 'storm_halberd', 'storm_lance'
     ) then
    raise exception 'unknown_weapon_id' using errcode = '22023';
  end if;

  if p_purchase_type = 'monster_upgrade'
     and p_target_id not in ('runner', 'tank', 'stalker', 'ranged') then
    raise exception 'unknown_monster_type' using errcode = '22023';
  end if;

  -- Always lock in the same order to avoid cross-purchase deadlocks.
  select data, revision into hero_data, current_hero_revision
    from public.hero_progress where user_id = p_user_id for update;
  if not found then
    raise exception 'hero_progress_missing' using errcode = 'P0002';
  end if;
  select data, revision into monster_data, current_monster_revision
    from public.monster_progress where user_id = p_user_id for update;
  if not found then
    raise exception 'monster_progress_missing' using errcode = 'P0002';
  end if;

  current_balance := (hero_data->>'permanentCurrency')::bigint;
  if current_balance is null or current_balance < 0 then
    raise exception 'invalid_persisted_currency' using errcode = '22023';
  end if;

  -- Idempotent retries return the committed outcome, never charge twice.
  select * into existing_transaction
    from public.currency_transactions
    where user_id = p_user_id and idempotency_key = p_idempotency_key;
  if found then
    -- The idempotency key is authoritative for retries. A retry may
    -- observe a newer level-dependent catalog price after the first request
    -- committed but its response was lost; never charge again or reject it
    -- merely because the current quote has moved to the next level.
    if existing_transaction.reason <> p_purchase_type
       or existing_transaction.reference_id <> p_target_id then
      raise exception 'progression_purchase_idempotency_conflict'
        using errcode = '23505';
    end if;
    if p_purchase_type = 'weapon_unlock' then
      next_level := 0;
    elsif p_purchase_type = 'weapon_upgrade' then
      next_level := coalesce((hero_data->'weaponUpgradeLevels'->>p_target_id)::integer, 0);
    else
      next_level := coalesce((monster_data->'levels'->>p_target_id)::integer, 1);
    end if;
    return query select current_balance, current_hero_revision,
      current_monster_revision, next_level, true;
    return;
  end if;

  if current_hero_revision <> p_expected_hero_revision
     or current_monster_revision <> p_expected_monster_revision then
    raise exception 'progression_purchase_revision_conflict'
      using errcode = '40001';
  end if;
  if current_balance < p_cost then
    raise exception 'insufficient_currency' using errcode = '22003';
  end if;

  if p_purchase_type = 'weapon_unlock' then
    if jsonb_typeof(hero_data->'unlockedWeaponIds') <> 'array'
       or (hero_data->'unlockedWeaponIds') ? p_target_id then
      raise exception 'weapon_already_unlocked_or_invalid_save'
        using errcode = '22023';
    end if;
    hero_data := jsonb_set(
      hero_data,
      '{unlockedWeaponIds}',
      (hero_data->'unlockedWeaponIds') || to_jsonb(p_target_id),
      true
    );
    hero_data := jsonb_set(
      hero_data,
      array['weaponUpgradeLevels', p_target_id],
      '0'::jsonb,
      true
    );
    next_level := 0;
    transaction_reason := 'weapon_unlock';
  elsif p_purchase_type = 'weapon_upgrade' then
    if jsonb_typeof(hero_data->'unlockedWeaponIds') <> 'array'
       or not ((hero_data->'unlockedWeaponIds') ? p_target_id) then
      raise exception 'weapon_locked' using errcode = '22023';
    end if;
    current_level := coalesce((hero_data->'weaponUpgradeLevels'->>p_target_id)::integer, 0);
    if current_level < 0 or current_level >= p_max_level then
      raise exception 'weapon_max_level' using errcode = '22023';
    end if;
    next_level := current_level + 1;
    hero_data := jsonb_set(
      hero_data,
      array['weaponUpgradeLevels', p_target_id],
      to_jsonb(next_level),
      true
    );
    transaction_reason := 'weapon_upgrade';
  else
    if jsonb_typeof(monster_data->'levels') <> 'object'
       or not ((monster_data->'levels') ? p_target_id) then
      raise exception 'unknown_monster_type' using errcode = '22023';
    end if;
    current_level := (monster_data->'levels'->>p_target_id)::integer;
    if current_level < 1 or current_level >= p_max_level then
      raise exception 'monster_max_level' using errcode = '22023';
    end if;
    next_level := current_level + 1;
    monster_data := jsonb_set(
      monster_data,
      array['levels', p_target_id],
      to_jsonb(next_level),
      true
    );
    transaction_reason := 'monster_upgrade';
  end if;

  current_balance := current_balance - p_cost;
  hero_data := jsonb_set(hero_data, '{permanentCurrency}', to_jsonb(current_balance), true);
  update public.hero_progress
    set data = hero_data, revision = revision + 1, updated_at = now()
    where user_id = p_user_id;
  if p_purchase_type = 'monster_upgrade' then
    update public.monster_progress
      set data = monster_data, revision = revision + 1, updated_at = now()
      where user_id = p_user_id;
  end if;

  insert into public.currency_transactions(
    user_id, idempotency_key, amount, reason, reference_id
  ) values (
    p_user_id, p_idempotency_key, -p_cost, transaction_reason, p_target_id
  );

  return query
    select current_balance,
      current_hero_revision + 1,
      current_monster_revision + case when p_purchase_type = 'monster_upgrade' then 1 else 0 end,
      next_level,
      false;
end;
$purchase$;

revoke all on function public.purchase_player_progression(
  uuid, text, text, bigint, integer, bigint, bigint, text
) from public, anon, authenticated;
grant execute on function public.purchase_player_progression(
  uuid, text, text, bigint, integer, bigint, bigint, text
) to service_role;

commit;
