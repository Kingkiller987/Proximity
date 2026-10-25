-- Proximity Milestone 2: PostGIS Landmark Visits, Multi-Day Events, Immutable Handles & Private Media Storage
-- Requires PostgreSQL 15+ with PostGIS and pgcrypto extensions enabled.

create extension if not exists postgis;
create extension if not exists pgcrypto;

-- 1. Profiles: Server-assigned immutable anonymous handles (AdjectiveNoun + optional 3-digit suffix)
create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  anonymous_handle text not null unique
    check (anonymous_handle ~ '^[A-Z][a-z]+[A-Z][a-z]+([0-9]{3})?$'),
  visible_in_nearby boolean not null default false,
  ghost_browse_nearby boolean not null default true,
  nearby_radius_meters integer not null default 500
    check (nearby_radius_meters in (250, 500, 1000, 2500)),
  message_retention_hours integer not null default 24
    check (message_retention_hours between 1 and 168),
  created_at timestamptz not null default now()
);

alter table public.profiles enable row level security;

create policy "Users can read their own profile"
  on public.profiles for select
  to authenticated
  using (auth.uid() = id);

create policy "Users can update their own privacy settings"
  on public.profiles for update
  to authenticated
  using (auth.uid() = id)
  with check (auth.uid() = id);

-- Block direct client updates to anonymous_handle; only visibility/privacy flags may change.
create or replace function public.prevent_anonymous_handle_mutation()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if new.anonymous_handle is distinct from old.anonymous_handle then
    raise exception 'anonymous_handle is system-assigned and immutable';
  end if;
  return new;
end;
$$;

drop trigger if exists trg_profiles_immutable_handle on public.profiles;
create trigger trg_profiles_immutable_handle
  before update on public.profiles
  for each row
  execute function public.prevent_anonymous_handle_mutation();

-- 2. User Blocks
create table if not exists public.user_blocks (
  blocker_id uuid not null references public.profiles(id) on delete cascade,
  blocked_id uuid not null references public.profiles(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (blocker_id, blocked_id),
  check (blocker_id <> blocked_id)
);

alter table public.user_blocks enable row level security;

create policy "Users manage their own block list"
  on public.user_blocks for all
  to authenticated
  using (auth.uid() = blocker_id)
  with check (auth.uid() = blocker_id);

-- 3. Curated System-Defined Landmarks (Regular users cannot insert/modify landmarks)
create table if not exists public.landmarks (
  id text primary key,
  name text not null,
  area_name text not null,
  center geography(Point, 4326) not null,
  radius_meters double precision not null check (radius_meters between 50 and 1000),
  is_active boolean not null default true,
  created_at timestamptz not null default now()
);

create index if not exists idx_landmarks_center_gist on public.landmarks using gist (center);

alter table public.landmarks enable row level security;

-- 4. Landmark Visit Sessions (Strict current-visit-only window with <= 30s freshness)
create sequence if not exists public.landmark_message_seq;

create table if not exists public.landmark_visit_sessions (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  landmark_id text not null references public.landmarks(id) on delete cascade,
  entered_at timestamptz not null default now(),
  last_heartbeat_at timestamptz not null default now(),
  exited_at timestamptz,
  min_message_sequence bigint not null default 1,
  last_accuracy_meters double precision not null check (last_accuracy_meters >= 0 and last_accuracy_meters <= 50.0)
);

create index if not exists idx_landmark_visits_active
  on public.landmark_visit_sessions (user_id, landmark_id)
  where exited_at is null;

alter table public.landmark_visit_sessions enable row level security;

create policy "Users can view their own active landmark visit sessions"
  on public.landmark_visit_sessions for select
  to authenticated
  using (
    auth.uid() = user_id
    and exited_at is null
    and last_heartbeat_at >= (now() - interval '30 seconds')
  );

-- Server-side PostGIS heartbeat RPC: verifies ST_DWithin(center, fix, radius_meters),
-- GPS accuracy <= 50m, and fix freshness <= 30s before opening or extending a visit session.
create or replace function public.upsert_landmark_heartbeat(
  p_landmark_id text,
  p_lat double precision,
  p_lon double precision,
  p_accuracy_meters double precision,
  p_recorded_at timestamptz
)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_user_id uuid := auth.uid();
  v_point geography(Point, 4326);
  v_inside boolean;
  v_session_id uuid;
  v_next_seq bigint;
begin
  if v_user_id is null then
    raise exception 'Authentication required';
  end if;

  if p_accuracy_meters < 0 or p_accuracy_meters > 50.0 then
    update public.landmark_visit_sessions
       set exited_at = now()
     where user_id = v_user_id and landmark_id = p_landmark_id and exited_at is null;
    return null;
  end if;

  if p_recorded_at < (now() - interval '30 seconds') or p_recorded_at > (now() + interval '10 seconds') then
    update public.landmark_visit_sessions
       set exited_at = now()
     where user_id = v_user_id and landmark_id = p_landmark_id and exited_at is null;
    return null;
  end if;

  v_point := st_setsrid(st_makepoint(p_lon, p_lat), 4326)::geography;

  select st_dwithin(l.center, v_point, l.radius_meters)
    into v_inside
    from public.landmarks l
   where l.id = p_landmark_id and l.is_active = true;

  if coalesce(v_inside, false) = false then
    update public.landmark_visit_sessions
       set exited_at = now()
     where user_id = v_user_id and landmark_id = p_landmark_id and exited_at is null;
    return null;
  end if;

  select s.id
    into v_session_id
    from public.landmark_visit_sessions s
   where s.user_id = v_user_id
     and s.landmark_id = p_landmark_id
     and s.exited_at is null
     and s.last_heartbeat_at >= (now() - interval '30 seconds')
   order by s.entered_at desc
   limit 1;

  if v_session_id is not null then
    update public.landmark_visit_sessions
       set last_heartbeat_at = now(),
           last_accuracy_meters = p_accuracy_meters
     where id = v_session_id;
    return v_session_id;
  else
    update public.landmark_visit_sessions
       set exited_at = now()
     where user_id = v_user_id and landmark_id = p_landmark_id and exited_at is null;

    select coalesce(last_value, 0) + 1 into v_next_seq from public.landmark_message_seq;

    insert into public.landmark_visit_sessions (
      user_id, landmark_id, entered_at, last_heartbeat_at, min_message_sequence, last_accuracy_meters
    ) values (
      v_user_id, p_landmark_id, now(), now(), v_next_seq, p_accuracy_meters
    )
    returning id into v_session_id;

    return v_session_id;
  end if;
end;
$$;

create policy "Users can view landmarks only while inside an active visit session"
  on public.landmarks for select
  to authenticated
  using (
    is_active = true
    and exists (
      select 1
        from public.landmark_visit_sessions s
       where s.user_id = auth.uid()
         and s.landmark_id = landmarks.id
         and s.exited_at is null
         and s.last_heartbeat_at >= (now() - interval '30 seconds')
    )
  );

-- 5. Landmark Chat Messages (Current-visit-only RLS: created_at >= visit.entered_at and sequence >= visit.min_message_sequence)
create table if not exists public.landmark_messages (
  id uuid primary key default gen_random_uuid(),
  landmark_id text not null references public.landmarks(id) on delete cascade,
  sender_id uuid not null references public.profiles(id) on delete cascade,
  body text not null default '',
  media_id uuid,
  sequence bigint not null default nextval('public.landmark_message_seq'),
  created_at timestamptz not null default now(),
  expires_at timestamptz not null
);

create index if not exists idx_landmark_messages_channel_created
  on public.landmark_messages (landmark_id, created_at desc);

alter table public.landmark_messages enable row level security;

create policy "Read current-visit landmark messages only"
  on public.landmark_messages for select
  to authenticated
  using (
    expires_at > now()
    and not exists (
      select 1 from public.user_blocks b
       where (b.blocker_id = auth.uid() and b.blocked_id = landmark_messages.sender_id)
          or (b.blocker_id = landmark_messages.sender_id and b.blocked_id = auth.uid())
    )
    and exists (
      select 1
        from public.landmark_visit_sessions s
       where s.user_id = auth.uid()
         and s.landmark_id = landmark_messages.landmark_id
         and s.exited_at is null
         and s.last_heartbeat_at >= (now() - interval '30 seconds')
         and landmark_messages.created_at >= s.entered_at
         and landmark_messages.sequence >= s.min_message_sequence
    )
  );

create policy "Send landmark message only during active visit"
  on public.landmark_messages for insert
  to authenticated
  with check (
    auth.uid() = sender_id
    and expires_at > now()
    and exists (
      select 1
        from public.landmark_visit_sessions s
       where s.user_id = auth.uid()
         and s.landmark_id = landmark_messages.landmark_id
         and s.exited_at is null
         and s.last_heartbeat_at >= (now() - interval '30 seconds')
    )
  );

-- 6. Events & Multi-Day Schedules
create table if not exists public.events (
  id uuid primary key default gen_random_uuid(),
  host_id uuid not null references public.profiles(id) on delete cascade,
  title text not null,
  description text not null,
  category_tag text not null,
  area_name text not null,
  venue_point geography(Point, 4326) not null,
  radius_meters double precision not null check (radius_meters between 100 and 5000),
  access_type text not null check (access_type in ('public', 'joinCode', 'inviteOnly')),
  join_code_hash text,
  timezone_name text not null default 'America/New_York',
  start_date date not null,
  end_date date not null,
  daily_open_minutes integer not null check (daily_open_minutes between 0 and 1439),
  daily_close_minutes integer not null check (daily_close_minutes between 0 and 1439),
  starts_at timestamptz not null,
  expires_at timestamptz not null,
  is_cancelled boolean not null default false,
  is_ended boolean not null default false,
  is_started boolean not null default false,
  started_at timestamptz,
  pending_host_transfer_user_id uuid references public.profiles(id) on delete set null,
  created_at timestamptz not null default now(),
  check (end_date >= start_date),
  check ((end_date - start_date) <= 365)
);

create index if not exists idx_events_venue_gist on public.events using gist (venue_point);

create table if not exists public.event_schedule_days (
  event_id uuid not null references public.events(id) on delete cascade,
  local_date date not null,
  is_closed boolean not null default false,
  open_minutes integer check (open_minutes between 0 and 1439),
  close_minutes integer check (close_minutes between 0 and 1439),
  primary key (event_id, local_date)
);

create table if not exists public.event_participants (
  event_id uuid not null references public.events(id) on delete cascade,
  user_id uuid not null references public.profiles(id) on delete cascade,
  joined_at timestamptz not null default now(),
  primary key (event_id, user_id)
);

alter table public.events enable row level security;
alter table public.event_schedule_days enable row level security;
alter table public.event_participants enable row level security;

create policy "Read active non-blocked events"
  on public.events for select
  to authenticated
  using (
    is_ended = false
    and is_cancelled = false
    and expires_at > now()
    and not exists (
      select 1 from public.user_blocks b
       where (b.blocker_id = auth.uid() and b.blocked_id = events.host_id)
          or (b.blocker_id = events.host_id and b.blocked_id = auth.uid())
    )
    and (
      access_type = 'public'
      or host_id = auth.uid()
      or exists (
        select 1 from public.event_participants ep
         where ep.event_id = events.id and ep.user_id = auth.uid()
      )
    )
  );

create policy "Hosts can create events"
  on public.events for insert
  to authenticated
  with check (auth.uid() = host_id);

create policy "Hosts can update their own events"
  on public.events for update
  to authenticated
  using (auth.uid() = host_id)
  with check (auth.uid() = host_id);

create policy "Read schedule days for accessible events"
  on public.event_schedule_days for select
  to authenticated
  using (
    exists (
      select 1 from public.events e
       where e.id = event_schedule_days.event_id
         and e.is_ended = false
         and e.is_cancelled = false
         and e.expires_at > now()
    )
  );

create policy "Hosts manage schedule days for their events"
  on public.event_schedule_days for all
  to authenticated
  using (
    exists (
      select 1 from public.events e
       where e.id = event_schedule_days.event_id and e.host_id = auth.uid()
    )
  )
  with check (
    exists (
      select 1 from public.events e
       where e.id = event_schedule_days.event_id and e.host_id = auth.uid()
    )
  );

create policy "Participants and hosts can view event membership"
  on public.event_participants for select
  to authenticated
  using (
    user_id = auth.uid()
    or exists (
      select 1 from public.events e
       where e.id = event_participants.event_id and e.host_id = auth.uid()
    )
  );

create policy "Users can leave events they do not host"
  on public.event_participants for delete
  to authenticated
  using (
    user_id = auth.uid()
    and not exists (
      select 1 from public.events e
       where e.id = event_participants.event_id and e.host_id = auth.uid()
    )
  );

-- 7. Direct Message Threads (Required for DM Media Authorization)
create table if not exists public.dm_threads (
  id text primary key,
  from_user_id uuid not null references public.profiles(id) on delete cascade,
  to_user_id uuid not null references public.profiles(id) on delete cascade,
  status text not null check (status in ('pending', 'accepted', 'declined')),
  created_at timestamptz not null default now()
);

alter table public.dm_threads enable row level security;

create policy "Participants can read unblocked DM threads"
  on public.dm_threads for select
  to authenticated
  using (
    (from_user_id = auth.uid() or to_user_id = auth.uid())
    and not exists (
      select 1 from public.user_blocks b
       where (b.blocker_id = from_user_id and b.blocked_id = to_user_id)
          or (b.blocker_id = to_user_id and b.blocked_id = from_user_id)
    )
  );

-- 8. Private Media Objects & Storage Authorization
create table if not exists public.chat_media_objects (
  id uuid primary key default gen_random_uuid(),
  channel_kind text not null check (channel_kind in ('landmark', 'event', 'dm')),
  channel_id text not null,
  sender_id uuid not null references public.profiles(id) on delete cascade,
  storage_object_key text not null unique,
  mime_type text not null check (mime_type in ('image/jpeg', 'image/png', 'image/webp')),
  size_bytes integer not null check (size_bytes > 0 and size_bytes <= 5242880),
  width integer not null check (width > 0),
  height integer not null check (height > 0),
  exif_stripped boolean not null default true check (exif_stripped = true),
  sequence bigint not null default nextval('public.landmark_message_seq'),
  created_at timestamptz not null default now(),
  expires_at timestamptz not null
);

alter table public.chat_media_objects enable row level security;

create policy "Read media metadata only when authorized for landmark visit, event, or accepted DM"
  on public.chat_media_objects for select
  to authenticated
  using (
    expires_at > now()
    and not exists (
      select 1 from public.user_blocks b
       where (b.blocker_id = auth.uid() and b.blocked_id = chat_media_objects.sender_id)
          or (b.blocker_id = chat_media_objects.sender_id and b.blocked_id = auth.uid())
    )
    and (
      (
        channel_kind = 'landmark'
        and exists (
          select 1
            from public.landmark_visit_sessions s
           where s.user_id = auth.uid()
             and s.landmark_id = chat_media_objects.channel_id
             and s.exited_at is null
             and s.last_heartbeat_at >= (now() - interval '30 seconds')
             and chat_media_objects.created_at >= s.entered_at
             and chat_media_objects.sequence >= s.min_message_sequence
        )
      )
      or (
        channel_kind = 'event'
        and exists (
          select 1
            from public.events e
            join public.event_participants ep on ep.event_id = e.id
           where e.id::text = chat_media_objects.channel_id
             and ep.user_id = auth.uid()
             and e.is_ended = false
             and e.is_cancelled = false
             and e.expires_at > now()
        )
      )
      or (
        channel_kind = 'dm'
        and exists (
          select 1
            from public.dm_threads t
           where t.id = chat_media_objects.channel_id
             and t.status = 'accepted'
             and (t.from_user_id = auth.uid() or t.to_user_id = auth.uid())
             and not exists (
               select 1 from public.user_blocks b
                where (b.blocker_id = t.from_user_id and b.blocked_id = t.to_user_id)
                   or (b.blocker_id = t.to_user_id and b.blocked_id = t.from_user_id)
             )
        )
      )
    )
  );

create policy "Upload media metadata only when authorized for target channel"
  on public.chat_media_objects for insert
  to authenticated
  with check (
    auth.uid() = sender_id
    and expires_at > now()
    and exif_stripped = true
    and (
      (
        channel_kind = 'landmark'
        and exists (
          select 1
            from public.landmark_visit_sessions s
           where s.user_id = auth.uid()
             and s.landmark_id = chat_media_objects.channel_id
             and s.exited_at is null
             and s.last_heartbeat_at >= (now() - interval '30 seconds')
        )
      )
      or (
        channel_kind = 'event'
        and exists (
          select 1
            from public.events e
            join public.event_participants ep on ep.event_id = e.id
           where e.id::text = chat_media_objects.channel_id
             and ep.user_id = auth.uid()
             and e.is_ended = false
             and e.is_cancelled = false
             and e.expires_at > now()
        )
      )
      or (
        channel_kind = 'dm'
        and exists (
          select 1
            from public.dm_threads t
           where t.id = chat_media_objects.channel_id
             and t.status = 'accepted'
             and (t.from_user_id = auth.uid() or t.to_user_id = auth.uid())
             and not exists (
               select 1 from public.user_blocks b
                where (b.blocker_id = t.from_user_id and b.blocked_id = t.to_user_id)
                   or (b.blocker_id = t.to_user_id and b.blocked_id = t.from_user_id)
             )
        )
      )
    )
  );

create policy "Senders can delete their own media objects"
  on public.chat_media_objects for delete
  to authenticated
  using (auth.uid() = sender_id);

-- 9. Architectural Reference Specification: Event Lifecycle & Host Transfer RPCs
-- NOTE: The following SQL definitions represent architectural reference specifications for production deployment.
-- They are documented here for design and migration reference and do not represent deployed or operational live server enforcement.
-- Client-side validation in Proximity provides initial UX guidance; true physical presence and atomic ownership
-- transfers require server-side execution with trusted device telemetry.

-- Start Event: Validates host presence at venue point within event radius, fresh GPS fix, and operating schedule window.
create or replace function public.start_event(
  p_event_id uuid,
  p_lat double precision,
  p_lng double precision,
  p_accuracy_meters double precision,
  p_fix_recorded_at timestamptz
)
returns boolean
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  v_event record;
  v_now timestamptz := now();
  v_fix_age interval;
  v_distance double precision;
begin
  select * into v_event
    from public.events
   where id = p_event_id;

  if not found then
    raise exception 'Event not found';
  end if;

  if v_event.host_id <> auth.uid() then
    raise exception 'Only the event host can start this event';
  end if;

  if v_event.is_ended or v_event.is_cancelled then
    raise exception 'Cannot start an ended or cancelled event';
  end if;

  if v_event.is_started then
    return true; -- Idempotent if already started
  end if;

  -- 1. Validate GPS accuracy and freshness
  if p_accuracy_meters < 0 or p_accuracy_meters > 50.0 then
    raise exception 'GPS fix accuracy insufficient to verify host presence (<= 50m required)';
  end if;

  v_fix_age := v_now - p_fix_recorded_at;
  if v_fix_age < interval '0 seconds' or v_fix_age > interval '30 seconds' then
    raise exception 'GPS fix is stale (> 30s) or from the future';
  end if;

  -- 2. Verify physical presence within event radius via PostGIS ST_DWithin
  v_distance := ST_Distance(
    v_event.venue_point,
    ST_SetSRID(ST_MakePoint(p_lng, p_lat), 4326)::geography
  );
  if v_distance > v_event.radius_meters then
    raise exception 'Host is % meters away from venue; must be within % meters to start event',
      round(v_distance::numeric, 1), v_event.radius_meters;
  end if;

  -- 3. Validate operating schedule (respecting venue timezone)
  if v_now < v_event.starts_at then
    raise exception 'Event scheduled start has not arrived yet';
  end if;

  if v_now >= v_event.expires_at then
    raise exception 'Event operating window has already expired';
  end if;

  -- Atomic update
  update public.events
     set is_started = true,
         started_at = v_now
   where id = p_event_id;

  return true;
end;
$$;

-- Accept Event Host Transfer: Recipient independently verifies location, permission, membership, radius, and block status.
create or replace function public.accept_event_host_transfer(
  p_event_id uuid,
  p_lat double precision,
  p_lng double precision,
  p_accuracy_meters double precision,
  p_fix_recorded_at timestamptz
)
returns boolean
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  v_event record;
  v_recipient_id uuid := auth.uid();
  v_now timestamptz := now();
  v_fix_age interval;
  v_distance double precision;
begin
  select * into v_event
    from public.events
   where id = p_event_id
   for update; -- Lock row for atomic transfer

  if not found then
    raise exception 'Event not found';
  end if;

  if v_event.pending_host_transfer_user_id is distinct from v_recipient_id then
    raise exception 'No pending host transfer offered to this user';
  end if;

  if v_event.is_ended or v_event.is_cancelled then
    raise exception 'Cannot accept host transfer on an ended or cancelled event';
  end if;

  -- 1. Verify recipient is a joined participant
  if not exists (
    select 1 from public.event_participants ep
     where ep.event_id = p_event_id and ep.user_id = v_recipient_id
  ) then
    raise exception 'Recipient must be a joined event participant';
  end if;

  -- 2. Verify no active block between original host and recipient
  if exists (
    select 1 from public.user_blocks b
     where (b.blocker_id = v_event.host_id and b.blocked_id = v_recipient_id)
        or (b.blocker_id = v_recipient_id and b.blocked_id = v_event.host_id)
  ) then
    raise exception 'Cannot transfer host ownership across blocked users';
  end if;

  -- 3. Verify recipient's fresh accurate location fix
  if p_accuracy_meters < 0 or p_accuracy_meters > 50.0 then
    raise exception 'Recipient GPS accuracy insufficient (<= 50m required)';
  end if;

  v_fix_age := v_now - p_fix_recorded_at;
  if v_fix_age < interval '0 seconds' or v_fix_age > interval '30 seconds' then
    raise exception 'Recipient GPS fix is stale (> 30s)';
  end if;

  -- 4. Verify recipient physical presence within venue radius
  v_distance := ST_Distance(
    v_event.venue_point,
    ST_SetSRID(ST_MakePoint(p_lng, p_lat), 4326)::geography
  );
  if v_distance > v_event.radius_meters then
    raise exception 'Recipient is not within venue radius (% meters away)', round(v_distance::numeric, 1);
  end if;

  -- 5. Atomic ownership transfer: designate new host, clear pending invitation
  update public.events
     set host_id = v_recipient_id,
         pending_host_transfer_user_id = null
   where id = p_event_id;

  return true;
end;
$$;
