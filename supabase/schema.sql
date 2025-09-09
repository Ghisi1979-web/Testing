-- silentdrop core schema (EU region). RLS ON.
-- Extensions
create extension if not exists pgcrypto;
create extension if not exists pgjwt;

-- Auth-linked profile
create table if not exists public.users (
  id uuid primary key references auth.users(id) on delete cascade,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  email text,
  display_name text,
  birthdate date,
  country text,
  tier text check (tier in ('soft','explicit')) default 'soft',
  premium boolean not null default false,
  pair_id uuid,
  constraints_unique_email unique (email)
);

alter table public.users enable row level security;

-- Pairs
create table if not exists public.pairs (
  id uuid primary key default gen_random_uuid(),
  created_at timestamptz not null default now()
);
alter table public.pairs enable row level security;

-- Pair links (invite codes)
create table if not exists public.pair_links (
  id uuid primary key default gen_random_uuid(),
  created_at timestamptz not null default now(),
  inviter_user_id uuid not null references public.users(id) on delete cascade,
  code text not null unique,
  claimed_by_user_id uuid references public.users(id) on delete set null,
  pair_id uuid references public.pairs(id) on delete cascade
);
alter table public.pair_links enable row level security;

-- Modules
create table if not exists public.modules (
  id uuid primary key default gen_random_uuid(),
  slug text not null unique,
  title text not null,
  description text,
  sort_order int not null default 0
);
alter table public.modules enable row level security;

-- Cards
create table if not exists public.cards (
  id uuid primary key default gen_random_uuid(),
  module_id uuid not null references public.modules(id) on delete cascade,
  title text not null,
  content text,
  level int not null check (level between 1 and 3),
  tier text not null check (tier in ('soft','explicit')),
  sort_order int not null default 0
);
alter table public.cards enable row level security;

-- User progress
create table if not exists public.user_progress (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.users(id) on delete cascade,
  card_id uuid not null references public.cards(id) on delete cascade,
  status text not null check (status in ('not_started','in_progress','completed')),
  updated_at timestamptz not null default now(),
  unique (user_id, card_id)
);
alter table public.user_progress enable row level security;

-- Journal entries
-- visibility: 'private' | 'pair' | 'coach' | 'community'
-- state: 'draft' | 'pending' | 'approved' | 'published'
create table if not exists public.journal_entries (
  id uuid primary key default gen_random_uuid(),
  author_id uuid not null references public.users(id) on delete cascade,
  pair_id uuid references public.pairs(id) on delete set null,
  title text,
  content text,
  visibility text not null default 'private' check (visibility in ('private','pair','coach','community')),
  state text not null default 'draft' check (state in ('draft','pending','approved','published')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
alter table public.journal_entries enable row level security;

-- Channels (messaging)
-- type: 'pair' | 'coach' | 'community'
create table if not exists public.channels (
  id uuid primary key default gen_random_uuid(),
  type text not null check (type in ('pair','coach','community')),
  pair_id uuid references public.pairs(id) on delete set null,
  slug text,
  title text,
  created_at timestamptz not null default now()
);
alter table public.channels enable row level security;

-- Channel members
create table if not exists public.channel_members (
  channel_id uuid not null references public.channels(id) on delete cascade,
  user_id uuid not null references public.users(id) on delete cascade,
  role text not null default 'member' check (role in ('member','moderator','admin')),
  primary key (channel_id, user_id)
);
alter table public.channel_members enable row level security;

-- Messages
create table if not exists public.messages (
  id uuid primary key default gen_random_uuid(),
  channel_id uuid not null references public.channels(id) on delete cascade,
  author_id uuid not null references public.users(id) on delete cascade,
  content text,
  created_at timestamptz not null default now()
);
alter table public.messages enable row level security;

-- Reports
create table if not exists public.reports (
  id uuid primary key default gen_random_uuid(),
  reporter_id uuid not null references public.users(id) on delete cascade,
  target_type text not null check (target_type in ('user','message','journal','media')),
  target_id uuid not null,
  reason text,
  created_at timestamptz not null default now(),
  status text not null default 'open' check (status in ('open','reviewing','resolved','rejected'))
);
alter table public.reports enable row level security;

-- Subscriptions (premium)
create table if not exists public.subscriptions (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.users(id) on delete cascade,
  product text not null check (product in ('premium')),
  status text not null check (status in ('active','canceled','past_due')),
  started_at timestamptz not null default now(),
  ended_at timestamptz
);
alter table public.subscriptions enable row level security;

-- Media assets
-- status: 'queued_ai' | 'approved' | 'flagged'
create table if not exists public.media_assets (
  id uuid primary key default gen_random_uuid(),
  owner_user_id uuid not null references public.users(id) on delete cascade,
  pair_id uuid references public.pairs(id) on delete set null,
  storage_path text not null,
  bucket text not null check (bucket in ('media_soft','media_explicit')),
  declared_tier text not null check (declared_tier in ('soft','explicit')),
  detected_tier text,
  labels jsonb default '[]'::jsonb,
  score numeric,
  status text not null default 'queued_ai' check (status in ('queued_ai','approved','flagged')),
  created_at timestamptz not null default now()
);
alter table public.media_assets enable row level security;

-- Journal media join
create table if not exists public.journal_media (
  journal_id uuid not null references public.journal_entries(id) on delete cascade,
  media_id uuid not null references public.media_assets(id) on delete cascade,
  primary key (journal_id, media_id)
);
alter table public.journal_media enable row level security;

-- Moderation events
create table if not exists public.moderation_events (
  id uuid primary key default gen_random_uuid(),
  target_type text not null check (target_type in ('media','journal')),
  target_id uuid not null,
  actor_user_id uuid not null references public.users(id) on delete cascade,
  decision text not null check (decision in ('approve','reject','flag')),
  reason text,
  created_at timestamptz not null default now()
);
alter table public.moderation_events enable row level security;

-- Helper: function to check membership in pair
create or replace function public.user_in_pair(u uuid, p uuid)
returns boolean language sql stable as $$
  select exists (
    select 1 from public.users where id = u and pair_id = p
  );
$$;

-- Policies
-- users: owner only
create policy if not exists users_select_self on public.users
  for select using (auth.uid() = id);
create policy if not exists users_update_self on public.users
  for update using (auth.uid() = id);

-- pairs: members only
create policy if not exists pairs_member_access on public.pairs
  for select using (exists (select 1 from public.users where id = auth.uid() and pair_id = pairs.id));

-- pair_links: inviter or claim owner can see; insert by any authed
create policy if not exists pair_links_select on public.pair_links
  for select using (
    inviter_user_id = auth.uid() or claimed_by_user_id = auth.uid()
  );
create policy if not exists pair_links_insert on public.pair_links
  for insert with check (inviter_user_id = auth.uid());
create policy if not exists pair_links_update on public.pair_links
  for update using (inviter_user_id = auth.uid() or claimed_by_user_id = auth.uid());

-- modules/cards: readable by all authenticated; no insert/update except admin (out of scope here)
create policy if not exists modules_select on public.modules for select using (true);
create policy if not exists cards_select on public.cards for select using (true);

-- user_progress: owner only
create policy if not exists user_progress_rw on public.user_progress
  for all using (user_id = auth.uid()) with check (user_id = auth.uid());

-- journal_entries
create policy if not exists journal_entries_select on public.journal_entries
  for select using (
    author_id = auth.uid()
    or (visibility in ('pair','coach','community') and pair_id is not null and public.user_in_pair(auth.uid(), pair_id))
  );
create policy if not exists journal_entries_modify on public.journal_entries
  for all using (author_id = auth.uid()) with check (author_id = auth.uid());

-- channels: members only for select; insert by server/seed
create policy if not exists channels_select on public.channels
  for select using (
    exists (
      select 1 from public.channel_members cm where cm.channel_id = channels.id and cm.user_id = auth.uid()
    )
  );

-- channel_members: user can see own memberships
create policy if not exists channel_members_select on public.channel_members
  for select using (user_id = auth.uid());

-- messages: only channel members can read/write
create policy if not exists messages_select on public.messages
  for select using (
    exists (
      select 1 from public.channel_members cm where cm.channel_id = messages.channel_id and cm.user_id = auth.uid()
    )
  );
create policy if not exists messages_insert on public.messages
  for insert with check (
    exists (
      select 1 from public.channel_members cm where cm.channel_id = messages.channel_id and cm.user_id = auth.uid()
    ) and author_id = auth.uid()
  );

-- reports: reporter can create and view own; moderators can be added later via role
create policy if not exists reports_rw on public.reports
  for all using (reporter_id = auth.uid()) with check (reporter_id = auth.uid());

-- subscriptions: owner only
create policy if not exists subscriptions_rw on public.subscriptions
  for all using (user_id = auth.uid()) with check (user_id = auth.uid());

-- media_assets: owner or pair partner can read; owner write
create policy if not exists media_assets_select on public.media_assets
  for select using (
    owner_user_id = auth.uid() or (pair_id is not null and public.user_in_pair(auth.uid(), pair_id))
  );
create policy if not exists media_assets_insert on public.media_assets
  for insert with check (owner_user_id = auth.uid());
create policy if not exists media_assets_update_owner on public.media_assets
  for update using (owner_user_id = auth.uid());

-- journal_media: visible if can see journal or media
create policy if not exists journal_media_select on public.journal_media
  for select using (
    exists (
      select 1 from public.journal_entries je where je.id = journal_media.journal_id and (
        je.author_id = auth.uid() or (je.pair_id is not null and public.user_in_pair(auth.uid(), je.pair_id))
      )
    )
  );
create policy if not exists journal_media_write on public.journal_media
  for all using (
    exists (
      select 1 from public.journal_entries je where je.id = journal_media.journal_id and je.author_id = auth.uid()
    )
  ) with check (
    exists (
      select 1 from public.journal_entries je where je.id = journal_media.journal_id and je.author_id = auth.uid()
    )
  );

-- moderation_events: only actor can create; select own
create policy if not exists moderation_events_rw on public.moderation_events
  for all using (actor_user_id = auth.uid()) with check (actor_user_id = auth.uid());

-- Storage buckets to be created via CLI/UI: media_soft, media_explicit (private)

-- Create buckets if not exist (Supabase >= 2023-05)
do $$ begin
  perform storage.create_bucket('media_soft', false);
exception when others then null; end $$;
do $$ begin
  perform storage.create_bucket('media_explicit', false);
exception when others then null; end $$;

-- Storage RLS policies (storage.objects)
-- Read: owner or pair partner; Write: owner only. Buckets are private.
create policy if not exists storage_media_select on storage.objects
  for select using (
    bucket_id in ('media_soft','media_explicit') and (
      exists (
        select 1 from public.media_assets ma
        where ma.storage_path = storage.objects.name and ma.bucket = storage.objects.bucket_id
          and (ma.owner_user_id = auth.uid() or (ma.pair_id is not null and public.user_in_pair(auth.uid(), ma.pair_id)))
      )
    )
  );

create policy if not exists storage_media_insert on storage.objects
  for insert with check (
    bucket_id in ('media_soft','media_explicit') and (
      exists (
        select 1 from public.media_assets ma
        where ma.storage_path = storage.objects.name and ma.bucket = storage.objects.bucket_id
          and ma.owner_user_id = auth.uid()
      )
    )
  );


