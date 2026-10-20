-- Digital Dash: one-time database setup.
-- Paste all of this into Supabase, SQL Editor, New query, and click Run.
-- It is the same as the files in supabase/migrations/, in order, and it records them as applied
-- so the GitHub integration doesn't try to run them again.

BEGIN;

-- ===== 20260226013640_bcec28c4-2608-42ac-ac04-608ef57e5dc7.sql =====
-- Create contact submissions table (public, no auth needed)
CREATE TABLE public.contact_submissions (
  id UUID NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
  name TEXT NOT NULL,
  email TEXT NOT NULL,
  message TEXT NOT NULL,
  created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now()
);

-- Enable RLS
ALTER TABLE public.contact_submissions ENABLE ROW LEVEL SECURITY;

-- Allow anyone to insert (public contact form)
CREATE POLICY "Anyone can submit contact form"
  ON public.contact_submissions
  FOR INSERT
  WITH CHECK (true);

-- ===== 20261001120000_digital_dash_accounts.sql =====
-- Digital Dash accounts: one saved state per user, plus private image storage.
-- Every row and file is readable and writable only by its owner (row level security).

CREATE TABLE IF NOT EXISTS public.dash_state (
  user_id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  data JSONB NOT NULL DEFAULT '{}'::jsonb,
  rev BIGINT NOT NULL DEFAULT 1,          -- bumps on every save; used to spot edits from another device
  device TEXT,                            -- e.g. "Chrome on Mac", shown as "last saved on"
  updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now()
);

ALTER TABLE public.dash_state ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users read their own dashboard"
  ON public.dash_state FOR SELECT TO authenticated
  USING (auth.uid() = user_id);
CREATE POLICY "Users create their own dashboard"
  ON public.dash_state FOR INSERT TO authenticated
  WITH CHECK (auth.uid() = user_id);
CREATE POLICY "Users update their own dashboard"
  ON public.dash_state FOR UPDATE TO authenticated
  USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);
CREATE POLICY "Users delete their own dashboard"
  ON public.dash_state FOR DELETE TO authenticated
  USING (auth.uid() = user_id);

-- Background, clock and widget photos. Files live under "<user id>/<image key>".
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES ('dash-images', 'dash-images', false, 5242880, ARRAY['image/jpeg','image/png','image/webp','image/gif'])
ON CONFLICT (id) DO NOTHING;

CREATE POLICY "Users read their own dash images"
  ON storage.objects FOR SELECT TO authenticated
  USING (bucket_id = 'dash-images' AND (storage.foldername(name))[1] = auth.uid()::text);
CREATE POLICY "Users upload their own dash images"
  ON storage.objects FOR INSERT TO authenticated
  WITH CHECK (bucket_id = 'dash-images' AND (storage.foldername(name))[1] = auth.uid()::text);
CREATE POLICY "Users replace their own dash images"
  ON storage.objects FOR UPDATE TO authenticated
  USING (bucket_id = 'dash-images' AND (storage.foldername(name))[1] = auth.uid()::text);
CREATE POLICY "Users delete their own dash images"
  ON storage.objects FOR DELETE TO authenticated
  USING (bucket_id = 'dash-images' AND (storage.foldername(name))[1] = auth.uid()::text);

-- "Delete my account": removes the signed-in user (their dash_state row goes with it via the
-- foreign key). The app deletes the user's images through the storage API first.
CREATE OR REPLACE FUNCTION public.delete_my_dash_account()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'Not signed in';
  END IF;
  DELETE FROM auth.users WHERE id = auth.uid();
END;
$$;

REVOKE ALL ON FUNCTION public.delete_my_dash_account() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.delete_my_dash_account() TO authenticated;

-- ===== 20261001130000_digital_dash_ai.sql =====
-- Digital Dash AI helper: a per-user daily request counter so the shared API key can't be drained.
CREATE TABLE IF NOT EXISTS public.dash_ai_usage (
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  day DATE NOT NULL DEFAULT current_date,
  count INTEGER NOT NULL DEFAULT 0,
  PRIMARY KEY (user_id, day)
);
ALTER TABLE public.dash_ai_usage ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Users read their own AI usage"
  ON public.dash_ai_usage FOR SELECT TO authenticated
  USING (auth.uid() = user_id);
-- No insert/update policies: only dash_ai_take() below writes, so users can't reset their own count.

-- Counts one request for the signed-in user and returns false once today's limit is reached.
CREATE OR REPLACE FUNCTION public.dash_ai_take(p_limit INTEGER)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  used INTEGER;
BEGIN
  IF auth.uid() IS NULL THEN
    RETURN FALSE;
  END IF;
  INSERT INTO public.dash_ai_usage (user_id, day, count)
  VALUES (auth.uid(), current_date, 1)
  ON CONFLICT (user_id, day) DO UPDATE SET count = public.dash_ai_usage.count + 1
  RETURNING count INTO used;
  RETURN used <= LEAST(GREATEST(p_limit, 1), 200);
END;
$$;
REVOKE ALL ON FUNCTION public.dash_ai_take(INTEGER) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.dash_ai_take(INTEGER) TO authenticated;

-- ===== 20261001140000_digital_dash_push.sql =====
-- Digital Dash reminders: push subscriptions per device, and the reminders each account has scheduled.
-- The app writes reminders ahead of time; the dash-push Edge Function (run every minute by pg_cron)
-- sends the ones that are due as Web Push notifications.

CREATE TABLE IF NOT EXISTS public.dash_push_subs (
  endpoint TEXT PRIMARY KEY,                 -- one row per browser/device subscription
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  p256dh TEXT NOT NULL,
  auth TEXT NOT NULL,
  device TEXT,
  created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now()
);
ALTER TABLE public.dash_push_subs ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Users read their own push subscriptions"
  ON public.dash_push_subs FOR SELECT TO authenticated USING (auth.uid() = user_id);
CREATE POLICY "Users remove their own push subscriptions"
  ON public.dash_push_subs FOR DELETE TO authenticated USING (auth.uid() = user_id);

-- Registers (or moves) this device's subscription to the signed-in user. A device that someone else
-- used before is reassigned, which a plain upsert can't do under row level security.
CREATE OR REPLACE FUNCTION public.dash_push_register(p_endpoint TEXT, p_p256dh TEXT, p_auth TEXT, p_device TEXT)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF auth.uid() IS NULL THEN RAISE EXCEPTION 'Not signed in'; END IF;
  IF p_endpoint !~ '^https://' THEN RAISE EXCEPTION 'Bad endpoint'; END IF;
  INSERT INTO public.dash_push_subs (endpoint, user_id, p256dh, auth, device)
  VALUES (p_endpoint, auth.uid(), p_p256dh, p_auth, left(p_device, 60))
  ON CONFLICT (endpoint) DO UPDATE
    SET user_id = auth.uid(), p256dh = excluded.p256dh, auth = excluded.auth, device = excluded.device, created_at = now();
END;
$$;
REVOKE ALL ON FUNCTION public.dash_push_register(TEXT, TEXT, TEXT, TEXT) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.dash_push_register(TEXT, TEXT, TEXT, TEXT) TO authenticated;

CREATE TABLE IF NOT EXISTS public.dash_reminders (
  id TEXT NOT NULL,                          -- "<user id>:<tag>:<time>", so every device writes the same ids
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  at TIMESTAMP WITH TIME ZONE NOT NULL,
  kind TEXT NOT NULL,                        -- due | event | morning | timer | test
  title TEXT NOT NULL,
  body TEXT NOT NULL DEFAULT '',
  tag TEXT,
  url TEXT,
  sent_at TIMESTAMP WITH TIME ZONE,
  PRIMARY KEY (user_id, id)                  -- keyed per user, so nobody can claim another account's ids
);
CREATE INDEX IF NOT EXISTS dash_reminders_pending ON public.dash_reminders (at) WHERE sent_at IS NULL;
ALTER TABLE public.dash_reminders ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Users read their own reminders"
  ON public.dash_reminders FOR SELECT TO authenticated USING (auth.uid() = user_id);
CREATE POLICY "Users schedule their own reminders"
  ON public.dash_reminders FOR INSERT TO authenticated WITH CHECK (auth.uid() = user_id);
CREATE POLICY "Users change their own reminders"
  ON public.dash_reminders FOR UPDATE TO authenticated USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);
CREATE POLICY "Users cancel their own reminders"
  ON public.dash_reminders FOR DELETE TO authenticated USING (auth.uid() = user_id);

-- ===== 20261008120000_digital_dash_task_reminders.sql =====
-- Digital Dash: email and text message reminders for tasks.
-- dash_contacts holds where a person wants reminders to go. Only the dash-push Edge Function (service
-- role) reads or writes it: the app talks to the function, so the phone verification code hash and the
-- unsubscribe token never reach the browser.

CREATE TABLE IF NOT EXISTS public.dash_contacts (
  user_id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  email_on BOOLEAN NOT NULL DEFAULT false,         -- agreed to email reminders at their account email
  phone TEXT,                                       -- E.164, e.g. +15195551234
  phone_verified_at TIMESTAMP WITH TIME ZONE,
  sms_on BOOLEAN NOT NULL DEFAULT false,            -- turned off by STOP replies or from the app
  code_hash TEXT,                                   -- HMAC of the pending verification code
  code_phone TEXT,                                  -- the number that code was sent to
  code_expires TIMESTAMP WITH TIME ZONE,
  code_tries INTEGER NOT NULL DEFAULT 0,
  codes_sent JSONB NOT NULL DEFAULT '[]'::jsonb,    -- recent send times, for rate limiting
  unsub_token UUID NOT NULL DEFAULT gen_random_uuid(),
  updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now()
);
ALTER TABLE public.dash_contacts ENABLE ROW LEVEL SECURITY;
-- No policies on purpose: signed-in users can't read or write this table directly.

-- Daily message counts per account, so a mistake (or a misbehaving client) can't run up a bill.
CREATE TABLE IF NOT EXISTS public.dash_msg_usage (
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  day DATE NOT NULL,
  email INTEGER NOT NULL DEFAULT 0,
  sms INTEGER NOT NULL DEFAULT 0,
  PRIMARY KEY (user_id, day)
);
ALTER TABLE public.dash_msg_usage ENABLE ROW LEVEL SECURITY;

-- Which channels each reminder goes out on. Existing reminders stay push-only.
ALTER TABLE public.dash_reminders ADD COLUMN IF NOT EXISTS channels TEXT[] NOT NULL DEFAULT ARRAY['push'];
ALTER TABLE public.dash_reminders DROP CONSTRAINT IF EXISTS dash_reminders_channels_ok;
ALTER TABLE public.dash_reminders ADD CONSTRAINT dash_reminders_channels_ok
  CHECK (channels <@ ARRAY['push','email','sms'] AND cardinality(channels) BETWEEN 1 AND 3);

-- ===== 20261020120000_digital_dash_friends.sql =====
-- Digital Dash friends and a weekly focus leaderboard.
-- Safe to run more than once. The tables have row level security with no direct access for other
-- users: everything that touches another person goes through the functions below, which only ever
-- show you yourself and people who accepted your friend request (or sent you one).

-- Your public face to friends: a display name and a friend code to share.
CREATE TABLE IF NOT EXISTS public.dash_profiles (
  user_id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  name TEXT NOT NULL CHECK (char_length(name) BETWEEN 1 AND 40),
  code TEXT NOT NULL UNIQUE CHECK (code ~ '^[A-Z2-9]{8}$'),
  share_focus BOOLEAN NOT NULL DEFAULT true,   -- show my focus time on friends' leaderboards
  created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now()
);
ALTER TABLE public.dash_profiles ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Users read their own profile" ON public.dash_profiles;
CREATE POLICY "Users read their own profile" ON public.dash_profiles FOR SELECT TO authenticated USING (auth.uid() = user_id);

-- One row per pair, stored with a < b. requested_by is who sent it; status pending or accepted.
CREATE TABLE IF NOT EXISTS public.dash_friends (
  a UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  b UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  requested_by UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  status TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('pending','accepted')),
  created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now(),
  PRIMARY KEY (a, b),
  CHECK (a < b)
);
ALTER TABLE public.dash_friends ENABLE ROW LEVEL SECURITY;
CREATE INDEX IF NOT EXISTS dash_friends_b ON public.dash_friends (b);

-- Focus totals per week (week = that Monday's date), reported by the app.
CREATE TABLE IF NOT EXISTS public.dash_focus_week (
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  week DATE NOT NULL,
  minutes INTEGER NOT NULL DEFAULT 0 CHECK (minutes BETWEEN 0 AND 10080),
  sessions INTEGER NOT NULL DEFAULT 0 CHECK (sessions BETWEEN 0 AND 1000),
  updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now(),
  PRIMARY KEY (user_id, week)
);
ALTER TABLE public.dash_focus_week ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Users read their own focus weeks" ON public.dash_focus_week;
CREATE POLICY "Users read their own focus weeks" ON public.dash_focus_week FOR SELECT TO authenticated USING (auth.uid() = user_id);

-- Create or update my profile. A new profile gets a random 8-character code (no 0/O/1/I).
CREATE OR REPLACE FUNCTION public.dash_profile_save(p_name TEXT, p_share BOOLEAN DEFAULT NULL)
RETURNS public.dash_profiles LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE me UUID := auth.uid(); n TEXT := left(btrim(regexp_replace(coalesce(p_name,''), '[[:cntrl:]<>]', '', 'g')), 40); c TEXT; r public.dash_profiles;
BEGIN
  IF me IS NULL THEN RAISE EXCEPTION 'Not signed in'; END IF;
  IF n = '' THEN RAISE EXCEPTION 'Name required'; END IF;
  SELECT * INTO r FROM public.dash_profiles WHERE user_id = me;
  IF FOUND THEN
    UPDATE public.dash_profiles SET name = n, share_focus = coalesce(p_share, share_focus) WHERE user_id = me RETURNING * INTO r;
    RETURN r;
  END IF;
  LOOP
    c := (SELECT string_agg(substr('ABCDEFGHJKLMNPQRSTUVWXYZ23456789', 1 + floor(random() * 32)::int, 1), '') FROM generate_series(1, 8));
    EXIT WHEN NOT EXISTS (SELECT 1 FROM public.dash_profiles WHERE code = c);
  END LOOP;
  INSERT INTO public.dash_profiles (user_id, name, code, share_focus) VALUES (me, n, c, coalesce(p_share, true)) RETURNING * INTO r;
  RETURN r;
END $$;

-- Send a request by friend code. If they already asked me, this accepts it instead.
CREATE OR REPLACE FUNCTION public.dash_friend_add(p_code TEXT)
RETURNS TEXT LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE me UUID := auth.uid(); other UUID; lo UUID; hi UUID; f public.dash_friends;
BEGIN
  IF me IS NULL THEN RAISE EXCEPTION 'Not signed in'; END IF;
  IF NOT EXISTS (SELECT 1 FROM public.dash_profiles WHERE user_id = me) THEN RETURN 'no_profile'; END IF;
  SELECT user_id INTO other FROM public.dash_profiles WHERE code = upper(regexp_replace(coalesce(p_code,''), '[^A-Za-z0-9]', '', 'g'));
  IF other IS NULL THEN RETURN 'not_found'; END IF;
  IF other = me THEN RETURN 'self'; END IF;
  lo := least(me, other); hi := greatest(me, other);
  SELECT * INTO f FROM public.dash_friends WHERE a = lo AND b = hi;
  IF FOUND THEN
    IF f.status = 'accepted' THEN RETURN 'already'; END IF;
    IF f.requested_by = other THEN UPDATE public.dash_friends SET status = 'accepted' WHERE a = lo AND b = hi; RETURN 'accepted'; END IF;
    RETURN 'pending';
  END IF;
  IF (SELECT count(*) FROM public.dash_friends WHERE requested_by = me AND status = 'pending') >= 50 THEN RETURN 'too_many'; END IF;
  INSERT INTO public.dash_friends (a, b, requested_by) VALUES (lo, hi, me);
  RETURN 'sent';
END $$;

-- Accept or decline a request someone sent me.
CREATE OR REPLACE FUNCTION public.dash_friend_respond(p_other UUID, p_accept BOOLEAN)
RETURNS VOID LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE me UUID := auth.uid();
BEGIN
  IF me IS NULL THEN RAISE EXCEPTION 'Not signed in'; END IF;
  IF p_accept THEN
    UPDATE public.dash_friends SET status = 'accepted'
      WHERE a = least(me, p_other) AND b = greatest(me, p_other) AND requested_by = p_other AND status = 'pending';
  ELSE
    DELETE FROM public.dash_friends
      WHERE a = least(me, p_other) AND b = greatest(me, p_other) AND requested_by = p_other AND status = 'pending';
  END IF;
END $$;

-- Remove a friend, or cancel a request I sent.
CREATE OR REPLACE FUNCTION public.dash_friend_remove(p_other UUID)
RETURNS VOID LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE me UUID := auth.uid();
BEGIN
  IF me IS NULL THEN RAISE EXCEPTION 'Not signed in'; END IF;
  DELETE FROM public.dash_friends WHERE a = least(me, p_other) AND b = greatest(me, p_other);
END $$;

-- My friends and requests, with names only (never codes or emails).
CREATE OR REPLACE FUNCTION public.dash_friends_list()
RETURNS TABLE (user_id UUID, name TEXT, state TEXT) LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public AS $$
  SELECT p.user_id, p.name,
         CASE WHEN f.status = 'accepted' THEN 'friend' WHEN f.requested_by = auth.uid() THEN 'outgoing' ELSE 'incoming' END
  FROM public.dash_friends f
  JOIN public.dash_profiles p ON p.user_id = CASE WHEN f.a = auth.uid() THEN f.b ELSE f.a END
  WHERE auth.uid() IN (f.a, f.b)
  ORDER BY 3, 2;
$$;

-- Report my totals for a week. Only this week or last week can be written.
CREATE OR REPLACE FUNCTION public.dash_focus_report(p_week DATE, p_minutes INTEGER, p_sessions INTEGER)
RETURNS VOID LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE me UUID := auth.uid();
BEGIN
  IF me IS NULL THEN RAISE EXCEPTION 'Not signed in'; END IF;
  IF extract(isodow FROM p_week) <> 1 OR p_week < current_date - 14 OR p_week > current_date + 1 THEN RETURN; END IF;
  INSERT INTO public.dash_focus_week (user_id, week, minutes, sessions, updated_at)
  VALUES (me, p_week, least(greatest(coalesce(p_minutes,0),0),10080), least(greatest(coalesce(p_sessions,0),0),1000), now())
  ON CONFLICT (user_id, week) DO UPDATE SET minutes = excluded.minutes, sessions = excluded.sessions, updated_at = now();
END $$;

-- The leaderboard for a week: me plus accepted friends who share their focus time.
CREATE OR REPLACE FUNCTION public.dash_leaderboard(p_week DATE)
RETURNS TABLE (user_id UUID, name TEXT, minutes INTEGER, sessions INTEGER, is_me BOOLEAN) LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public AS $$
  WITH people AS (
    SELECT auth.uid() AS uid
    UNION
    SELECT CASE WHEN f.a = auth.uid() THEN f.b ELSE f.a END FROM public.dash_friends f
      WHERE f.status = 'accepted' AND auth.uid() IN (f.a, f.b)
  )
  SELECT p.user_id, p.name, coalesce(w.minutes, 0), coalesce(w.sessions, 0), p.user_id = auth.uid()
  FROM people x
  JOIN public.dash_profiles p ON p.user_id = x.uid AND (p.share_focus OR p.user_id = auth.uid())
  LEFT JOIN public.dash_focus_week w ON w.user_id = p.user_id AND w.week = p_week
  WHERE auth.uid() IS NOT NULL
  ORDER BY 3 DESC, 2;
$$;

DO $$ DECLARE f TEXT; BEGIN
  FOREACH f IN ARRAY ARRAY['dash_profile_save(text,boolean)','dash_friend_add(text)','dash_friend_respond(uuid,boolean)','dash_friend_remove(uuid)','dash_friends_list()','dash_focus_report(date,integer,integer)','dash_leaderboard(date)'] LOOP
    EXECUTE format('REVOKE ALL ON FUNCTION public.%s FROM PUBLIC, anon', f);
    EXECUTE format('GRANT EXECUTE ON FUNCTION public.%s TO authenticated', f);
  END LOOP;
END $$;

-- Record the migrations as applied (same format the Supabase CLI uses).
CREATE SCHEMA IF NOT EXISTS supabase_migrations;
CREATE TABLE IF NOT EXISTS supabase_migrations.schema_migrations (version text PRIMARY KEY, statements text[], name text);
INSERT INTO supabase_migrations.schema_migrations (version, name) VALUES ('20260226013640', 'bcec28c4-2608-42ac-ac04-608ef57e5dc7') ON CONFLICT (version) DO NOTHING;
INSERT INTO supabase_migrations.schema_migrations (version, name) VALUES ('20261001120000', 'digital_dash_accounts') ON CONFLICT (version) DO NOTHING;
INSERT INTO supabase_migrations.schema_migrations (version, name) VALUES ('20261001130000', 'digital_dash_ai') ON CONFLICT (version) DO NOTHING;
INSERT INTO supabase_migrations.schema_migrations (version, name) VALUES ('20261001140000', 'digital_dash_push') ON CONFLICT (version) DO NOTHING;
INSERT INTO supabase_migrations.schema_migrations (version, name) VALUES ('20261008120000', 'digital_dash_task_reminders') ON CONFLICT (version) DO NOTHING;
INSERT INTO supabase_migrations.schema_migrations (version, name) VALUES ('20261020120000', 'digital_dash_friends') ON CONFLICT (version) DO NOTHING;

COMMIT;
