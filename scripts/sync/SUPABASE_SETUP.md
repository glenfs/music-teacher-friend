# Supabase setup for Cloud Sync (Tier A)

One-time setup in the Supabase dashboard. Takes ~5 minutes.

## 1. Verify auth settings

In **Supabase dashboard → Authentication → Providers**:
- **Email** provider must be enabled (default). Both "Confirm email" and "Magic link" should be on.
- No OAuth providers required for MVP.

In **Authentication → Email Templates → Magic Link**:
- The default template includes both a clickable link AND the OTP code via `{{ .Token }}`. If you've customised the template, make sure `{{ .Token }}` is still in the body — that's the 6-digit code users will type into the app.

## 2. Create the `sync_snapshots` table

Open **SQL Editor** in the Supabase dashboard and run:

```sql
-- One row per (user, device) snapshot. Each push inserts a new row; pulls
-- read the most recent one. Older snapshots remain available for future
-- "view history / restore from earlier" features.
create table if not exists public.sync_snapshots (
  id           uuid primary key default gen_random_uuid(),
  user_id      uuid not null references auth.users(id) on delete cascade,
  device_label text not null default '',
  payload_json jsonb not null,
  created_at   timestamptz not null default now()
);

-- Fast "latest snapshot for this user" lookup.
create index if not exists idx_sync_snapshots_user_created
  on public.sync_snapshots (user_id, created_at desc);

-- Lock the table down: only the owner can see / write their own rows.
alter table public.sync_snapshots enable row level security;

create policy "Users can read own snapshots"
  on public.sync_snapshots for select
  using (auth.uid() = user_id);

create policy "Users can insert own snapshots"
  on public.sync_snapshots for insert
  with check (auth.uid() = user_id);

create policy "Users can update own snapshots"
  on public.sync_snapshots for update
  using (auth.uid() = user_id);

create policy "Users can delete own snapshots"
  on public.sync_snapshots for delete
  using (auth.uid() = user_id);
```

## 3. (Optional) Snapshot retention

Once you've been using sync for a while, snapshots will accumulate. A simple
retention rule keeps the last 30 per user:

```sql
-- Run on a schedule (Supabase → Database → Cron) once a day:
delete from public.sync_snapshots
where id in (
  select id from (
    select id,
           row_number() over (partition by user_id order by created_at desc) as rn
    from public.sync_snapshots
  ) ranked
  where rn > 30
);
```

Defer this until you actually have a few weeks of real usage.

## 4. Verify it works

After running the SQL, in the Supabase dashboard:
- **Table Editor → sync_snapshots** should show an empty table with the columns
  `id`, `user_id`, `device_label`, `payload_json`, `created_at`.
- **Authentication → Policies → sync_snapshots** should show 4 RLS policies.

You're done. The app code in this folder will:
- Send OTP codes via `auth/v1/otp`
- Verify codes via `auth/v1/verify`
- Insert snapshots via `rest/v1/sync_snapshots`
- Query the latest via `rest/v1/sync_snapshots?order=created_at.desc&limit=1`

All of which are gated by the RLS policies above, so users can only ever
read / write their own rows — even if the publishable client key leaks.

## Notes on keys

The **publishable** key (`sb_publishable_*`) is embedded in `sync_config.gd`
and is safe to commit. The **secret** key (`sb_secret_*` / service-role) is
NEVER used by the client — it lives only in the Supabase dashboard. If the
publishable key is ever rotated, update `SUPABASE_ANON_KEY` in
`scripts/sync/sync_config.gd`.
