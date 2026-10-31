-- Tricky Word Treasure Hunt: username-only players, rounds, and per-word stats.
-- Tables are locked down (RLS on, no policies, no grants); the game talks to them only
-- through tw_login and tw_save_round (SECURITY DEFINER), which validate their inputs.

create table if not exists public.tw_players (
  id           uuid primary key default gen_random_uuid(),
  name_key     text not null unique,            -- lower-cased name used for lookup
  display_name text not null,
  total_stars  int  not null default 0,
  created_at   timestamptz not null default now(),
  last_seen    timestamptz not null default now()
);

create table if not exists public.tw_rounds (
  id         bigint generated always as identity primary key,
  player_id  uuid not null references public.tw_players(id) on delete cascade,
  mode       text not null check (mode in ('listen','flash','spell')),
  practice   boolean not null default false,
  score      int  not null check (score between 0 and 30),
  total      int  not null check (total between 1 and 30),
  played_at  timestamptz not null default now()
);
create index if not exists tw_rounds_player_idx on public.tw_rounds(player_id, mode);

create table if not exists public.tw_word_stats (
  player_id  uuid not null references public.tw_players(id) on delete cascade,
  word       text not null,
  correct    int  not null default 0,
  missed     int  not null default 0,
  weight     int  not null default 0,  -- +2 per miss, -1 per first-try correct (min 0)
  last_seen  timestamptz not null default now(),
  primary key (player_id, word)
);

alter table public.tw_players    enable row level security;
alter table public.tw_rounds     enable row level security;
alter table public.tw_word_stats enable row level security;
revoke all on public.tw_players, public.tw_rounds, public.tw_word_stats from anon, authenticated;

-- Profile JSON returned to the game: name, total stars, best score per game, trickiest words.
create or replace function public.tw_profile(p_player uuid)
returns jsonb language sql stable security definer set search_path = '' as $$
  select jsonb_build_object(
    'name', p.display_name,
    'total_stars', p.total_stars,
    'best', coalesce((
      select jsonb_object_agg(b.mode, jsonb_build_object('score', b.score, 'total', b.total))
      from (select distinct on (r.mode) r.mode, r.score, r.total
            from public.tw_rounds r
            where r.player_id = p.id and not r.practice
            order by r.mode, r.score desc, r.played_at) b), '{}'::jsonb),
    'tricky', coalesce((
      select jsonb_agg(jsonb_build_object('word', s.word, 'weight', s.weight) order by s.weight desc, s.last_seen desc)
      from (select * from public.tw_word_stats s
            where s.player_id = p.id and s.weight > 0
            order by s.weight desc, s.last_seen desc limit 30) s), '[]'::jsonb))
  from public.tw_players p where p.id = p_player;
$$;

create or replace function public.tw_get_player(p_name text)
returns uuid language plpgsql security definer set search_path = '' as $$
declare v_name text; v_id uuid;
begin
  v_name := btrim(regexp_replace(coalesce(p_name,''), '\s+', ' ', 'g'));
  if v_name !~ '^[A-Za-z0-9 _-]{1,20}$' then
    raise exception 'invalid name';
  end if;
  insert into public.tw_players(name_key, display_name)
  values (lower(v_name), v_name)
  on conflict (name_key) do update set last_seen = now()
  returning id into v_id;
  return v_id;
end $$;

-- Sign in (creates the player the first time a name is used).
create or replace function public.tw_login(p_name text)
returns jsonb language plpgsql security definer set search_path = '' as $$
begin
  return public.tw_profile(public.tw_get_player(p_name));
end $$;

-- Save one finished round and update per-word stats.
create or replace function public.tw_save_round(
  p_name text, p_mode text, p_score int, p_total int, p_practice boolean, p_results jsonb)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare v_id uuid; r jsonb; v_word text; v_ok boolean;
begin
  if p_mode not in ('listen','flash','spell') then raise exception 'invalid mode'; end if;
  if p_total not between 1 and 30 or p_score not between 0 and p_total then raise exception 'invalid score'; end if;
  if jsonb_typeof(p_results) <> 'array' or jsonb_array_length(p_results) > 30 then raise exception 'invalid results'; end if;

  v_id := public.tw_get_player(p_name);
  insert into public.tw_rounds(player_id, mode, practice, score, total)
  values (v_id, p_mode, coalesce(p_practice,false), p_score, p_total);
  update public.tw_players set total_stars = total_stars + p_score, last_seen = now() where id = v_id;

  for r in select * from jsonb_array_elements(p_results) loop
    v_word := lower(r->>'word');
    v_ok   := coalesce((r->>'correct')::boolean, false);
    continue when v_word is null or v_word !~ '^[a-z'']{1,20}$';
    insert into public.tw_word_stats(player_id, word, correct, missed, weight)
    values (v_id, v_word, case when v_ok then 1 else 0 end, case when v_ok then 0 else 1 end, case when v_ok then 0 else 2 end)
    on conflict (player_id, word) do update set
      correct   = public.tw_word_stats.correct + case when v_ok then 1 else 0 end,
      missed    = public.tw_word_stats.missed  + case when v_ok then 0 else 1 end,
      weight    = greatest(0, public.tw_word_stats.weight + case when v_ok then -1 else 2 end),
      last_seen = now();
  end loop;

  return public.tw_profile(v_id);
end $$;

revoke all on function public.tw_profile(uuid), public.tw_get_player(text) from public, anon, authenticated;
revoke all on function public.tw_login(text), public.tw_save_round(text,text,int,int,boolean,jsonb) from public;
grant execute on function public.tw_login(text), public.tw_save_round(text,text,int,int,boolean,jsonb) to anon, authenticated;
