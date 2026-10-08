# Digital Dash

A study dashboard for students: focus timers with study music, tasks that repeat and break into steps, courses and grades, a calendar with .ics import, a week review with a year-long focus heatmap, a net worth tracker with money goals, study rooms with friends, and reminders on your phone.

Live: https://usedigitaldash.vercel.app

## Run it locally

```
npm start
```

This builds `dist/` and serves it. Open `/digital-dash.html`. Without Supabase settings everything still works and saves on the device; accounts, rooms, the AI helper and reminders stay off.

## How it's built

- `public/digital-dash.html` is the whole app: one file with inline CSS and JS, no framework.
- `public/digital-dash-sw.js`, `digital-dash.webmanifest` and the icons make it installable and usable offline.
- `public/digital-dash-privacy.html` is the privacy policy.
- `scripts/build.mjs` copies `public/` to `dist/` and writes `digital-dash-config.js` from the Supabase env vars.
- `supabase/` holds the database setup (`migrations/`, or `setup-all.sql` in one file) and two Edge Functions: `dash-ai` (AI helper) and `dash-push` (reminders by notification, email and text).

Full details, including setup for each feature, are in [docs/digital-dash.md](docs/digital-dash.md).

## Deploying on Vercel

1. Import this repo as a new Vercel project. `vercel.json` sets the build (`npm run build`, output `dist`).
2. Add two environment variables, type **Config**, for Production and Preview:
   - `VITE_SUPABASE_URL`: your Supabase project URL
   - `VITE_SUPABASE_PUBLISHABLE_KEY`: the **publishable** (or anon) key, never the secret key
3. Deploy. `/` redirects to `/digital-dash.html`, and `/privacy` to the privacy policy.
4. In Supabase, Authentication, URL Configuration, set the Site URL to `https://<your-domain>/digital-dash.html` and add `https://<your-domain>/**` to Redirect URLs.
