-- Digital Dash usernames and profile photos. Run after 20261020120000_digital_dash_friends.sql.
-- Safe to run more than once.
-- A username is 3 to 20 lowercase letters, numbers or underscores, stored lowercase, and the unique
-- index means no two people can ever hold the same one (whatever case they typed it in).
-- A profile photo is a small square image (the app makes it 128px) kept as a data URL in the profile,
-- so friends can see it through the same functions that show them your name. Nobody else can.

ALTER TABLE public.dash_profiles ADD COLUMN IF NOT EXISTS username TEXT;
ALTER TABLE public.dash_profiles ADD COLUMN IF NOT EXISTS avatar TEXT;
DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'dash_profiles_username_format') THEN
    ALTER TABLE public.dash_profiles ADD CONSTRAINT dash_profiles_username_format CHECK (username ~ '^[a-z0-9_]{3,20}$');
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'dash_profiles_avatar_format') THEN
    ALTER TABLE public.dash_profiles ADD CONSTRAINT dash_profiles_avatar_format
      CHECK (char_length(avatar) <= 40000 AND avatar ~ '^data:image/(webp|jpeg|png);base64,[A-Za-z0-9+/]+={0,2}$');
  END IF;
END $$;
CREATE UNIQUE INDEX IF NOT EXISTS dash_profiles_username_key ON public.dash_profiles (username);

-- Is a username free? 'free', 'mine', 'taken', 'reserved' or 'invalid'.
CREATE OR REPLACE FUNCTION public.dash_username_check(p_username TEXT)
RETURNS TEXT LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
DECLARE u TEXT := lower(btrim(coalesce(p_username,''), ' @')); owner UUID;
BEGIN
  IF auth.uid() IS NULL THEN RAISE EXCEPTION 'Not signed in'; END IF;
  IF u !~ '^[a-z0-9_]{3,20}$' THEN RETURN 'invalid'; END IF;
  IF u IN ('admin','administrator','digitaldash','digital_dash','support','help','moderator','official','staff','system','root','null','undefined','me','you') THEN RETURN 'reserved'; END IF;
  SELECT user_id INTO owner FROM public.dash_profiles WHERE username = u;
  IF owner IS NULL THEN RETURN 'free'; END IF;
  RETURN CASE WHEN owner = auth.uid() THEN 'mine' ELSE 'taken' END;
END $$;

-- Create or update my profile in one call. Leave a field NULL to keep it; p_clear_avatar removes the
-- photo. Returns {"status": ok | taken | reserved | invalid | name_required | bad_image, "profile": {...}}.
CREATE OR REPLACE FUNCTION public.dash_profile_set(p_name TEXT DEFAULT NULL, p_username TEXT DEFAULT NULL,
  p_avatar TEXT DEFAULT NULL, p_clear_avatar BOOLEAN DEFAULT false, p_share BOOLEAN DEFAULT NULL)
RETURNS JSONB LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE me UUID := auth.uid(); r public.dash_profiles; c TEXT; chk TEXT; had BOOLEAN;
  n TEXT := left(btrim(regexp_replace(coalesce(p_name,''), '[[:cntrl:]<>]', '', 'g')), 40);
  u TEXT := lower(btrim(coalesce(p_username,''), ' @'));
BEGIN
  IF me IS NULL THEN RAISE EXCEPTION 'Not signed in'; END IF;
  IF p_username IS NOT NULL THEN
    chk := public.dash_username_check(u);
    IF chk NOT IN ('free','mine') THEN RETURN jsonb_build_object('status', chk); END IF;
  END IF;
  IF p_avatar IS NOT NULL AND NOT (char_length(p_avatar) <= 40000 AND p_avatar ~ '^data:image/(webp|jpeg|png);base64,[A-Za-z0-9+/]+={0,2}$') THEN
    RETURN jsonb_build_object('status', 'bad_image');
  END IF;
  SELECT * INTO r FROM public.dash_profiles WHERE user_id = me;
  had := FOUND;
  BEGIN
    IF had THEN
      UPDATE public.dash_profiles SET
        name = CASE WHEN n <> '' THEN n ELSE name END,
        username = CASE WHEN p_username IS NOT NULL THEN u ELSE username END,
        avatar = CASE WHEN p_clear_avatar THEN NULL WHEN p_avatar IS NOT NULL THEN p_avatar ELSE avatar END,
        share_focus = coalesce(p_share, share_focus)
      WHERE user_id = me RETURNING * INTO r;
    ELSE
      IF n = '' THEN RETURN jsonb_build_object('status', 'name_required'); END IF;
      LOOP
        c := (SELECT string_agg(substr('ABCDEFGHJKLMNPQRSTUVWXYZ23456789', 1 + floor(random() * 32)::int, 1), '') FROM generate_series(1, 8));
        EXIT WHEN NOT EXISTS (SELECT 1 FROM public.dash_profiles WHERE code = c);
      END LOOP;
      INSERT INTO public.dash_profiles (user_id, name, code, share_focus, username, avatar)
      VALUES (me, n, c, coalesce(p_share, true), CASE WHEN p_username IS NOT NULL THEN u END, CASE WHEN NOT p_clear_avatar THEN p_avatar END)
      RETURNING * INTO r;
    END IF;
  EXCEPTION WHEN unique_violation THEN
    RETURN jsonb_build_object('status', 'taken');   -- someone took it a moment ago
  END;
  RETURN jsonb_build_object('status', 'ok', 'profile', jsonb_build_object(
    'name', r.name, 'code', r.code, 'share_focus', r.share_focus, 'username', r.username, 'avatar', r.avatar));
END $$;

-- Send a request by username (with or without @) or by friend code. "@name" is always a username;
-- otherwise a friend code is tried first, then a username.
CREATE OR REPLACE FUNCTION public.dash_friend_add(p_code TEXT)
RETURNS TEXT LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE me UUID := auth.uid(); other UUID; lo UUID; hi UUID; f public.dash_friends;
  raw TEXT := btrim(coalesce(p_code,'')); u TEXT := lower(btrim(coalesce(p_code,''), ' @'));
BEGIN
  IF me IS NULL THEN RAISE EXCEPTION 'Not signed in'; END IF;
  IF NOT EXISTS (SELECT 1 FROM public.dash_profiles WHERE user_id = me) THEN RETURN 'no_profile'; END IF;
  IF left(raw, 1) <> '@' THEN
    SELECT user_id INTO other FROM public.dash_profiles WHERE code = upper(regexp_replace(raw, '[^A-Za-z0-9]', '', 'g'));
  END IF;
  IF other IS NULL AND u ~ '^[a-z0-9_]{3,20}$' THEN
    SELECT user_id INTO other FROM public.dash_profiles WHERE username = u;
  END IF;
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

-- The list and leaderboard now include username and photo (the return type changes, so drop first).
DROP FUNCTION IF EXISTS public.dash_friends_list();
CREATE FUNCTION public.dash_friends_list()
RETURNS TABLE (user_id UUID, name TEXT, state TEXT, username TEXT, avatar TEXT) LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public AS $$
  SELECT p.user_id, p.name,
         CASE WHEN f.status = 'accepted' THEN 'friend' WHEN f.requested_by = auth.uid() THEN 'outgoing' ELSE 'incoming' END,
         p.username,
         CASE WHEN f.status = 'accepted' OR f.requested_by <> auth.uid() THEN p.avatar END   -- no photo until they accept
  FROM public.dash_friends f
  JOIN public.dash_profiles p ON p.user_id = CASE WHEN f.a = auth.uid() THEN f.b ELSE f.a END
  WHERE auth.uid() IN (f.a, f.b)
  ORDER BY 3, 2;
$$;

DROP FUNCTION IF EXISTS public.dash_leaderboard(date);
CREATE FUNCTION public.dash_leaderboard(p_week DATE)
RETURNS TABLE (user_id UUID, name TEXT, minutes INTEGER, sessions INTEGER, is_me BOOLEAN, username TEXT, avatar TEXT) LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public AS $$
  WITH people AS (
    SELECT auth.uid() AS uid
    UNION
    SELECT CASE WHEN f.a = auth.uid() THEN f.b ELSE f.a END FROM public.dash_friends f
      WHERE f.status = 'accepted' AND auth.uid() IN (f.a, f.b)
  )
  SELECT p.user_id, p.name, coalesce(w.minutes, 0), coalesce(w.sessions, 0), p.user_id = auth.uid(), p.username, p.avatar
  FROM people x
  JOIN public.dash_profiles p ON p.user_id = x.uid AND (p.share_focus OR p.user_id = auth.uid())
  LEFT JOIN public.dash_focus_week w ON w.user_id = p.user_id AND w.week = p_week
  WHERE auth.uid() IS NOT NULL
  ORDER BY 3 DESC, 2;
$$;

DO $$ DECLARE f TEXT; BEGIN
  FOREACH f IN ARRAY ARRAY['dash_username_check(text)','dash_profile_set(text,text,text,boolean,boolean)','dash_friend_add(text)','dash_friends_list()','dash_leaderboard(date)'] LOOP
    EXECUTE format('REVOKE ALL ON FUNCTION public.%s FROM PUBLIC, anon', f);
    EXECUTE format('GRANT EXECUTE ON FUNCTION public.%s TO authenticated', f);
  END LOOP;
END $$;
