-- Run after applying the Phase 5 migration in a Supabase staging project.
-- This script performs read-only privilege/policy assertions and raises on failure.
do $phase5_check$
declare
  relation_name text;
begin
  foreach relation_name in array array[
    'public.player_profiles',
    'public.hero_progress',
    'public.monster_progress',
    'public.currency_transactions',
    'public.match_results'
  ] loop
    if not exists (
      select 1
      from pg_class c
      join pg_namespace n on n.oid = c.relnamespace
      where n.nspname = 'public'
        and c.relname = split_part(relation_name, '.', 2)
        and c.relrowsecurity
    ) then
      raise exception 'RLS is not enabled on %', relation_name;
    end if;

    if has_table_privilege('anon', relation_name, 'SELECT')
       or has_table_privilege('anon', relation_name, 'INSERT')
       or has_table_privilege('anon', relation_name, 'UPDATE')
       or has_table_privilege('anon', relation_name, 'DELETE') then
      raise exception 'anon has an unexpected table privilege on %', relation_name;
    end if;

    if not has_table_privilege('authenticated', relation_name, 'SELECT') then
      raise exception 'authenticated cannot read own RLS-protected rows in %', relation_name;
    end if;

    if has_table_privilege('authenticated', relation_name, 'INSERT')
       or has_table_privilege('authenticated', relation_name, 'DELETE') then
      raise exception 'authenticated has an unexpected write privilege on %', relation_name;
    end if;
  end loop;

  if has_table_privilege('authenticated', 'public.player_profiles', 'UPDATE') then
    raise exception 'authenticated has broad profile UPDATE; only display_name should be writable';
  end if;
  if not has_column_privilege(
    'authenticated', 'public.player_profiles', 'display_name', 'UPDATE'
  ) then
    raise exception 'authenticated cannot update the permitted display_name column';
  end if;

  if has_table_privilege('authenticated', 'public.hero_progress', 'UPDATE')
     or has_table_privilege('authenticated', 'public.monster_progress', 'UPDATE')
     or has_table_privilege('authenticated', 'public.currency_transactions', 'UPDATE')
     or has_table_privilege('authenticated', 'public.match_results', 'UPDATE') then
    raise exception 'authenticated has a forbidden progression/economy UPDATE privilege';
  end if;

  if has_function_privilege(
       'anon', 'public.save_hero_progress(uuid,jsonb,bigint)', 'EXECUTE'
     )
     or has_function_privilege(
       'authenticated', 'public.save_hero_progress(uuid,jsonb,bigint)', 'EXECUTE'
     )
     or has_function_privilege(
       'anon', 'public.save_monster_progress(uuid,jsonb,bigint)', 'EXECUTE'
     )
     or has_function_privilege(
       'authenticated', 'public.save_monster_progress(uuid,jsonb,bigint)', 'EXECUTE'
     )
     or has_function_privilege(
       'anon', 'public.finalize_match_player_result(text,uuid,smallint,bigint,smallint,text,bigint,text)', 'EXECUTE'
     )
     or has_function_privilege(
       'authenticated', 'public.finalize_match_player_result(text,uuid,smallint,bigint,smallint,text,bigint,text)', 'EXECUTE'
     ) then
    raise exception 'A client role can execute a server-only persistence RPC';
  end if;

  if not has_function_privilege(
       'service_role', 'public.save_hero_progress(uuid,jsonb,bigint)', 'EXECUTE'
     )
     or not has_function_privilege(
       'service_role', 'public.save_monster_progress(uuid,jsonb,bigint)', 'EXECUTE'
     )
     or not has_function_privilege(
       'service_role', 'public.finalize_match_player_result(text,uuid,smallint,bigint,smallint,text,bigint,text)', 'EXECUTE'
     ) then
    raise exception 'service_role is missing a required persistence RPC grant';
  end if;

  if not has_sequence_privilege(
    'service_role', 'public.currency_transactions_id_seq', 'USAGE'
  ) then
    raise exception 'service_role cannot allocate currency ledger identities';
  end if;
end;
$phase5_check$;

select 'Phase 5 RLS and privilege checks passed.' as result;
