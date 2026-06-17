-- ═══════════════════════════════════════════════════════════════════════
-- Track Check — normalize schema
-- Replaces: entries (entry_date date, data jsonb)
-- With:     users, workout_logs, feeling_logs, food_logs,
--           supplement_logs, water_logs, flare_logs
--
-- The old `entries` table is NOT dropped here. Drop it manually after
-- the app is fully migrated and all data is verified:
--   drop table public.entries;
-- ═══════════════════════════════════════════════════════════════════════

-- ───────────────────────────────────────────────────────
-- HELPER: auto-update updated_at on any table that has it
-- ───────────────────────────────────────────────────────

create or replace function public.set_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;


-- ═══════════════════════════════════════════════════════
-- USERS  (profile table — extends auth.users)
-- ═══════════════════════════════════════════════════════

create table if not exists public.users (
  id                uuid        primary key references auth.users(id) on delete cascade,
  email             text,
  created_at        timestamptz not null default now(),
  conditions        text[]      not null default '{}',
  unit_preference   text        not null default 'imperial',
  notification_time time
);

alter table public.users enable row level security;

create policy "users: select own row"
  on public.users for select
  using (auth.uid() = id);

create policy "users: insert own row"
  on public.users for insert
  with check (auth.uid() = id);

create policy "users: update own row"
  on public.users for update
  using (auth.uid() = id);


-- ═══════════════════════════════════════════════════════
-- WORKOUT_LOGS
-- ═══════════════════════════════════════════════════════

create table if not exists public.workout_logs (
  id              uuid        primary key default gen_random_uuid(),
  user_id         uuid        not null references public.users(id) on delete cascade,
  log_date        date        not null,
  day_type        text,
  exercises       jsonb       not null default '{}',
  cardio          jsonb       not null default '{}',
  stabilization   jsonb       not null default '{}',
  notes           text        not null default '',
  created_at      timestamptz not null default now(),
  updated_at      timestamptz not null default now(),

  unique (user_id, log_date)
);

create index on public.workout_logs (user_id, log_date);

create trigger trg_workout_logs_updated_at
  before update on public.workout_logs
  for each row execute function public.set_updated_at();

alter table public.workout_logs enable row level security;

create policy "workout_logs: select own rows"
  on public.workout_logs for select
  using (auth.uid() = user_id);

create policy "workout_logs: insert own rows"
  on public.workout_logs for insert
  with check (auth.uid() = user_id);

create policy "workout_logs: update own rows"
  on public.workout_logs for update
  using (auth.uid() = user_id);

create policy "workout_logs: delete own rows"
  on public.workout_logs for delete
  using (auth.uid() = user_id);


-- ═══════════════════════════════════════════════════════
-- FEELING_LOGS  (multiple rows per user per day — no unique constraint)
-- ═══════════════════════════════════════════════════════

create table if not exists public.feeling_logs (
  id                 uuid        primary key default gen_random_uuid(),
  user_id            uuid        not null references public.users(id) on delete cascade,
  log_date           date        not null,
  logged_at          timestamptz not null default now(),
  mental             int         check (mental between 1 and 10),
  physical           int         check (physical between 1 and 10),
  gut                int         check (gut between 1 and 10),
  energy             int         check (energy between 1 and 10),
  clarity            int         check (clarity between 1 and 10),
  stress             int         check (stress between 1 and 10),
  sleep_quality      int         check (sleep_quality between 1 and 10),
  stiffness_minutes  int         check (stiffness_minutes >= 0),
  subluxations       int         check (subluxations >= 0),
  notes              text        not null default '',
  created_at         timestamptz not null default now()
);

create index on public.feeling_logs (user_id, log_date);
create index on public.feeling_logs (user_id, logged_at);

alter table public.feeling_logs enable row level security;

create policy "feeling_logs: select own rows"
  on public.feeling_logs for select
  using (auth.uid() = user_id);

create policy "feeling_logs: insert own rows"
  on public.feeling_logs for insert
  with check (auth.uid() = user_id);

create policy "feeling_logs: update own rows"
  on public.feeling_logs for update
  using (auth.uid() = user_id);

create policy "feeling_logs: delete own rows"
  on public.feeling_logs for delete
  using (auth.uid() = user_id);


-- ═══════════════════════════════════════════════════════
-- FOOD_LOGS
-- ═══════════════════════════════════════════════════════

create table if not exists public.food_logs (
  id              uuid        primary key default gen_random_uuid(),
  user_id         uuid        not null references public.users(id) on delete cascade,
  log_date        date        not null,
  meals           jsonb       not null default '{}',
  cheats          jsonb       not null default '{}',
  total_calories  int,
  total_protein   int,
  total_carbs     int,
  total_fat       int,
  created_at      timestamptz not null default now(),
  updated_at      timestamptz not null default now(),

  unique (user_id, log_date)
);

create index on public.food_logs (user_id, log_date);

create trigger trg_food_logs_updated_at
  before update on public.food_logs
  for each row execute function public.set_updated_at();

alter table public.food_logs enable row level security;

create policy "food_logs: select own rows"
  on public.food_logs for select
  using (auth.uid() = user_id);

create policy "food_logs: insert own rows"
  on public.food_logs for insert
  with check (auth.uid() = user_id);

create policy "food_logs: update own rows"
  on public.food_logs for update
  using (auth.uid() = user_id);

create policy "food_logs: delete own rows"
  on public.food_logs for delete
  using (auth.uid() = user_id);


-- ═══════════════════════════════════════════════════════
-- SUPPLEMENT_LOGS
-- ═══════════════════════════════════════════════════════

create table if not exists public.supplement_logs (
  id           uuid        primary key default gen_random_uuid(),
  user_id      uuid        not null references public.users(id) on delete cascade,
  log_date     date        not null,
  supplements  jsonb       not null default '{}',
  created_at   timestamptz not null default now(),
  updated_at   timestamptz not null default now(),

  unique (user_id, log_date)
);

create index on public.supplement_logs (user_id, log_date);

create trigger trg_supplement_logs_updated_at
  before update on public.supplement_logs
  for each row execute function public.set_updated_at();

alter table public.supplement_logs enable row level security;

create policy "supplement_logs: select own rows"
  on public.supplement_logs for select
  using (auth.uid() = user_id);

create policy "supplement_logs: insert own rows"
  on public.supplement_logs for insert
  with check (auth.uid() = user_id);

create policy "supplement_logs: update own rows"
  on public.supplement_logs for update
  using (auth.uid() = user_id);

create policy "supplement_logs: delete own rows"
  on public.supplement_logs for delete
  using (auth.uid() = user_id);


-- ═══════════════════════════════════════════════════════
-- WATER_LOGS
-- ═══════════════════════════════════════════════════════

create table if not exists public.water_logs (
  id          uuid        primary key default gen_random_uuid(),
  user_id     uuid        not null references public.users(id) on delete cascade,
  log_date    date        not null,
  total_oz    numeric     not null default 0,
  entries     jsonb       not null default '[]',
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now(),

  unique (user_id, log_date)
);

create index on public.water_logs (user_id, log_date);

create trigger trg_water_logs_updated_at
  before update on public.water_logs
  for each row execute function public.set_updated_at();

alter table public.water_logs enable row level security;

create policy "water_logs: select own rows"
  on public.water_logs for select
  using (auth.uid() = user_id);

create policy "water_logs: insert own rows"
  on public.water_logs for insert
  with check (auth.uid() = user_id);

create policy "water_logs: update own rows"
  on public.water_logs for update
  using (auth.uid() = user_id);

create policy "water_logs: delete own rows"
  on public.water_logs for delete
  using (auth.uid() = user_id);


-- ═══════════════════════════════════════════════════════
-- FLARE_LOGS
-- ═══════════════════════════════════════════════════════

create table if not exists public.flare_logs (
  id          uuid        primary key default gen_random_uuid(),
  user_id     uuid        not null references public.users(id) on delete cascade,
  log_date    date        not null,
  status      text        not null default 'good',
  triggers    text[]      not null default '{}',
  notes       text        not null default '',
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now(),

  unique (user_id, log_date)
);

create index on public.flare_logs (user_id, log_date);

create trigger trg_flare_logs_updated_at
  before update on public.flare_logs
  for each row execute function public.set_updated_at();

alter table public.flare_logs enable row level security;

create policy "flare_logs: select own rows"
  on public.flare_logs for select
  using (auth.uid() = user_id);

create policy "flare_logs: insert own rows"
  on public.flare_logs for insert
  with check (auth.uid() = user_id);

create policy "flare_logs: update own rows"
  on public.flare_logs for update
  using (auth.uid() = user_id);

create policy "flare_logs: delete own rows"
  on public.flare_logs for delete
  using (auth.uid() = user_id);
