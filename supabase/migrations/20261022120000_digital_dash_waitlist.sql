-- Digital Dash app store waitlist: emails from the home page "Get notified" form.
-- Safe to run more than once. Row level security is on with no policies, so nobody can read or
-- change the list through the API; the only way in is dash_waitlist_join(), which anyone may call.
-- Read the list in the Supabase dashboard (Table Editor > dash_waitlist) when the apps launch.

CREATE TABLE IF NOT EXISTS public.dash_waitlist (
  id BIGSERIAL PRIMARY KEY,
  email TEXT NOT NULL CHECK (char_length(email) BETWEEN 5 AND 254),
  platform TEXT NOT NULL DEFAULT 'both' CHECK (platform IN ('ios','android','both')),
  created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now()
);
CREATE UNIQUE INDEX IF NOT EXISTS dash_waitlist_email ON public.dash_waitlist (lower(email));
ALTER TABLE public.dash_waitlist ENABLE ROW LEVEL SECURITY;

-- Join the waitlist. Returns 'ok' for a new or existing email alike, so the form can't be used to
-- find out who signed up; 'invalid' for a bad address; 'busy' if sign-ups are being flooded.
CREATE OR REPLACE FUNCTION public.dash_waitlist_join(p_email TEXT, p_platform TEXT DEFAULT 'both')
RETURNS TEXT LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE e TEXT := lower(btrim(coalesce(p_email,'')));
  pf TEXT := CASE WHEN p_platform IN ('ios','android') THEN p_platform ELSE 'both' END;
BEGIN
  IF char_length(e) NOT BETWEEN 5 AND 254 OR e !~ '^[^@[:space:]]+@[^@[:space:]]+\.[^@[:space:]]+$' THEN RETURN 'invalid'; END IF;
  IF (SELECT count(*) FROM public.dash_waitlist WHERE created_at > now() - interval '1 minute') >= 200 THEN RETURN 'busy'; END IF;
  INSERT INTO public.dash_waitlist (email, platform) VALUES (e, pf)
  ON CONFLICT (lower(email)) DO UPDATE
    SET platform = CASE WHEN public.dash_waitlist.platform = excluded.platform THEN excluded.platform ELSE 'both' END;
  RETURN 'ok';
END $$;

REVOKE ALL ON FUNCTION public.dash_waitlist_join(text,text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.dash_waitlist_join(text,text) TO anon, authenticated;
