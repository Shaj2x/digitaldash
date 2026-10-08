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
