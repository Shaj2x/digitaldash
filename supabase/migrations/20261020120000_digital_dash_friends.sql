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
