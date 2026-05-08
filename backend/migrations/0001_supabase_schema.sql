create extension if not exists pgcrypto;

create or replace function public.set_updated_at()
returns trigger
language plpgsql
as $$
begin
    new.updated_at = timezone('utc', now());
    return new;
end;
$$;

create table if not exists public.users_profile (
    id uuid primary key default gen_random_uuid(),
    user_id uuid not null unique references auth.users (id) on delete cascade,
    user_name text not null default 'Adventurer',
    user_role text not null default 'Beginner',
    level integer not null default 0 check (level >= 0),
    current_exp integer not null default 0 check (current_exp >= 0),
    max_exp integer not null default 500 check (max_exp > 0),
    credits integer not null default 0 check (credits >= 0),
    daily_reset_key text not null default '',
    weekly_reset_key text not null default '',
    monthly_reset_key text not null default '',
    created_at timestamptz not null default timezone('utc', now()),
    updated_at timestamptz not null default timezone('utc', now())
);

create table if not exists public.user_stats (
    id uuid primary key default gen_random_uuid(),
    user_id uuid not null unique references auth.users (id) on delete cascade,
    profile_id uuid not null unique references public.users_profile (id) on delete cascade,
    completed_quest_count integer not null default 0 check (completed_quest_count >= 0),
    earned_exp integer not null default 0 check (earned_exp >= 0),
    daily_reward_count integer not null default 0 check (daily_reward_count >= 0),
    daily_reward_target integer not null default 3 check (daily_reward_target >= 0),
    weekly_reward_count integer not null default 0 check (weekly_reward_count >= 0),
    weekly_reward_target integer not null default 7 check (weekly_reward_target >= 0),
    monthly_reward_count integer not null default 0 check (monthly_reward_count >= 0),
    monthly_reward_target integer not null default 30 check (monthly_reward_target >= 0),
    weekly_completed_count integer not null default 0 check (weekly_completed_count >= 0),
    weekly_completion_rate integer not null default 0 check (weekly_completion_rate between 0 and 100),
    previous_weekly_completion_rate integer not null default 0 check (previous_weekly_completion_rate between 0 and 100),
    weekly_rate_delta integer not null default 0,
    diligence_stat integer not null default 0 check (diligence_stat >= 0),
    order_stat integer not null default 0 check (order_stat >= 0),
    intelligence_stat integer not null default 0 check (intelligence_stat >= 0),
    health_stat integer not null default 0 check (health_stat >= 0),
    weekly_activity_counts integer[] not null default array[0, 0, 0, 0, 0, 0, 0],
    weekly_activity_bars double precision[] not null default array[0, 0, 0, 0, 0, 0, 0]::double precision[],
    created_at timestamptz not null default timezone('utc', now()),
    updated_at timestamptz not null default timezone('utc', now()),
    constraint weekly_activity_counts_size_check check (cardinality(weekly_activity_counts) = 7),
    constraint weekly_activity_bars_size_check check (cardinality(weekly_activity_bars) = 7)
);

create table if not exists public.quests (
    id uuid primary key default gen_random_uuid(),
    user_id uuid not null references auth.users (id) on delete cascade,
    profile_id uuid not null references public.users_profile (id) on delete cascade,
    client_quest_id text,
    title text not null,
    exp integer not null default 0 check (exp >= 0),
    difficulty text not null,
    category text not null,
    elapsed_seconds integer not null default 0 check (elapsed_seconds >= 0),
    default_duration_seconds integer not null default 0 check (default_duration_seconds >= 0),
    status text not null default 'active',
    source text not null default 'manual',
    source_reference text,
    created_at timestamptz not null default timezone('utc', now()),
    updated_at timestamptz not null default timezone('utc', now()),
    constraint quests_difficulty_check check (difficulty in ('easy', 'normal', 'hard')),
    constraint quests_category_check check (category in ('work', 'life', 'study', 'home')),
    constraint quests_status_check check (status in ('active', 'completed', 'archived', 'deleted')),
    constraint quests_source_check check (source in ('manual', 'ocr', 'notion', 'ai', 'migration'))
);

create unique index if not exists quests_user_id_client_quest_id_idx
    on public.quests (user_id, client_quest_id)
    where client_quest_id is not null;

create index if not exists quests_user_id_status_idx
    on public.quests (user_id, status, created_at desc);

create table if not exists public.completed_quests (
    id uuid primary key default gen_random_uuid(),
    user_id uuid not null references auth.users (id) on delete cascade,
    profile_id uuid not null references public.users_profile (id) on delete cascade,
    quest_id uuid references public.quests (id) on delete set null,
    client_quest_id text,
    title text not null,
    difficulty text not null,
    category text not null,
    earned_exp integer not null default 0 check (earned_exp >= 0),
    completed_at timestamptz not null,
    elapsed_seconds integer not null default 0 check (elapsed_seconds >= 0),
    proof_image_path text,
    completion_source text not null default 'manual',
    created_at timestamptz not null default timezone('utc', now()),
    updated_at timestamptz not null default timezone('utc', now()),
    constraint completed_quests_difficulty_check check (difficulty in ('easy', 'normal', 'hard')),
    constraint completed_quests_category_check check (category in ('work', 'life', 'study', 'home')),
    constraint completed_quests_source_check check (completion_source in ('manual', 'timer', 'migration', 'sync'))
);

create index if not exists completed_quests_user_id_completed_at_idx
    on public.completed_quests (user_id, completed_at desc);

create table if not exists public.recent_activities (
    id uuid primary key default gen_random_uuid(),
    user_id uuid not null references auth.users (id) on delete cascade,
    profile_id uuid not null references public.users_profile (id) on delete cascade,
    completed_quest_id uuid references public.completed_quests (id) on delete set null,
    activity_date date not null,
    subtitle text not null,
    exp integer not null default 0 check (exp >= 0),
    activity_type text not null default 'quest_completed',
    created_at timestamptz not null default timezone('utc', now()),
    updated_at timestamptz not null default timezone('utc', now()),
    constraint recent_activities_type_check check (
        activity_type in ('quest_completed', 'reward_claimed', 'dungeon_cleared', 'system')
    )
);

create index if not exists recent_activities_user_id_activity_date_idx
    on public.recent_activities (user_id, activity_date desc, created_at desc);

create table if not exists public.dungeon_clears (
    id uuid primary key default gen_random_uuid(),
    user_id uuid not null references auth.users (id) on delete cascade,
    profile_id uuid not null references public.users_profile (id) on delete cascade,
    dungeon_id text not null,
    cleared_at timestamptz not null default timezone('utc', now()),
    created_at timestamptz not null default timezone('utc', now()),
    updated_at timestamptz not null default timezone('utc', now()),
    unique (user_id, dungeon_id)
);

create index if not exists dungeon_clears_user_id_idx
    on public.dungeon_clears (user_id, cleared_at desc);

create table if not exists public.notion_connections (
    id uuid primary key default gen_random_uuid(),
    user_id uuid not null references auth.users (id) on delete cascade,
    profile_id uuid not null references public.users_profile (id) on delete cascade,
    workspace_name text,
    workspace_id text,
    database_id text not null,
    database_title text,
    database_url text not null,
    notion_user_id text,
    access_token_encrypted text,
    refresh_token_encrypted text,
    last_synced_at timestamptz,
    sync_status text not null default 'pending',
    created_at timestamptz not null default timezone('utc', now()),
    updated_at timestamptz not null default timezone('utc', now()),
    constraint notion_connections_sync_status_check check (
        sync_status in ('pending', 'active', 'error', 'disconnected')
    )
);

create unique index if not exists notion_connections_user_id_database_id_idx
    on public.notion_connections (user_id, database_id);

create table if not exists public.quest_generation_logs (
    id uuid primary key default gen_random_uuid(),
    user_id uuid not null references auth.users (id) on delete cascade,
    profile_id uuid references public.users_profile (id) on delete set null,
    quest_id uuid references public.quests (id) on delete set null,
    provider text not null default 'gemini',
    prompt text,
    source_text text,
    generated_count integer not null default 0 check (generated_count >= 0),
    accepted_count integer not null default 0 check (accepted_count >= 0),
    request_payload jsonb not null default '{}'::jsonb,
    response_payload jsonb not null default '{}'::jsonb,
    status text not null default 'success',
    error_message text,
    created_at timestamptz not null default timezone('utc', now()),
    updated_at timestamptz not null default timezone('utc', now()),
    constraint quest_generation_logs_status_check check (
        status in ('success', 'partial', 'failed')
    )
);

create index if not exists quest_generation_logs_user_id_created_at_idx
    on public.quest_generation_logs (user_id, created_at desc);

create trigger set_users_profile_updated_at
before update on public.users_profile
for each row
execute function public.set_updated_at();

create trigger set_user_stats_updated_at
before update on public.user_stats
for each row
execute function public.set_updated_at();

create trigger set_quests_updated_at
before update on public.quests
for each row
execute function public.set_updated_at();

create trigger set_completed_quests_updated_at
before update on public.completed_quests
for each row
execute function public.set_updated_at();

create trigger set_recent_activities_updated_at
before update on public.recent_activities
for each row
execute function public.set_updated_at();

create trigger set_dungeon_clears_updated_at
before update on public.dungeon_clears
for each row
execute function public.set_updated_at();

create trigger set_notion_connections_updated_at
before update on public.notion_connections
for each row
execute function public.set_updated_at();

create trigger set_quest_generation_logs_updated_at
before update on public.quest_generation_logs
for each row
execute function public.set_updated_at();

alter table public.users_profile enable row level security;
alter table public.user_stats enable row level security;
alter table public.quests enable row level security;
alter table public.completed_quests enable row level security;
alter table public.recent_activities enable row level security;
alter table public.dungeon_clears enable row level security;
alter table public.notion_connections enable row level security;
alter table public.quest_generation_logs enable row level security;

comment on table public.users_profile is
'Maps AppLocalData profile fields to one row per authenticated user. Service-role access works immediately; RLS policies can be added later.';

comment on table public.user_stats is
'Stores AppLocalData aggregate stats and weekly arrays separately from profile identity fields.';

comment on table public.quests is
'Stores active or archived QuestItem rows. client_quest_id supports migration from Flutter local IDs.';

comment on table public.completed_quests is
'Stores CompletedQuestRecord history snapshots so quest edits do not mutate past completions.';

comment on table public.recent_activities is
'Stores RecentActivity feed entries derived from completed quests, rewards, and dungeon clears.';

comment on table public.dungeon_clears is
'Normalizes clearedDungeonIds from AppLocalData into one row per cleared dungeon.';

comment on table public.notion_connections is
'Stores one or more Notion integration bindings per user for future sync support.';

comment on table public.quest_generation_logs is
'Audit log for Gemini or other AI quest generation requests and responses.';
