# Digital Dash

A personal productivity dashboard: live clocks to stay motivated while working, a to-do list with urgency levels, a calendar, a net worth tracker, and deep visual customization (themes, custom colour schemes, backgrounds, fonts, widgets).

Everything lives in a single self-contained file, `public/digital-dash.html` (served at `/digital-dash.html`), with inline CSS and JS. The only build step copies `public/` to `dist/` and writes the Supabase settings file.

## Brand

- Logos live in `public/brand/`: `dd-lockup.png` (mark and wordmark in a box) and `dd-mark.png` (the DD diamond). They're transparent off-white, so in the app and on the home page they're used as CSS masks (`dd-mark-256.png`, `dd-lockup-640.png`) and take the current text colour in any theme. `-dark` copies are for light backgrounds elsewhere. Also there: `og.png` (link previews) and `favicon-32.png`.
- App icons (`digital-dash-icon-192/512`, `maskable-512`, `apple-180`) are the mark on #1B1B1B.
- The **Digital** theme (`brand` skin: #1B1B1B charcoal, #EFEEE8 off-white) matches the logo. It's the default for new users only; anyone who already has a saved theme keeps it.
- The welcome tour opens with the lockup, then "Make it yours": pick a look and a clock on the spot. Its last step lists everything else you can customize.
- The home page (`/`) has one live demo phone, kept in view (sticky) beside the intro and the "Make it yours" controls. Each choice restyles the **whole page** (the theme's exact colours, the display font for headings, a live aurora background, liquid glass) and the phone, through `window.dashDemo`, which only exists with `?demo=1`.
- Sections are styled to the brand, not as generic cards: features as a numbered ledger with a small live demo each (ticking timer, tasks ticking off, week bars, grade needed, "Try 140 × 8" with a NEW PR stamp, Funds hiding behind the privacy eye); How it works as a stopwatch track (0:00 → 0:60); Privacy as a printed data receipt. The page doesn't promise "no ads" (ads are planned); it does promise data is never sold.
- First-visit opening (`#intro`, about 2 seconds): the two halves of the DD mark slam together on charcoal, then split apart like doors, each half riding off with its side of the screen to reveal the page. Only on the very first visit (`dd.intro`), never for someone who already has a dashboard saved, never with reduced motion; a tap or Esc ends it early.
- The pick is saved as `dd.pick`. A new visitor's first app open starts with it, and the welcome tour shows it selected. A returning visitor's page starts in their own dashboard's look; changing it there doesn't touch their saved theme until they press "Use this look in my dashboard" (`apply:true`), which the app applies once on next open and syncs.

## iPhone preview

`/preview` (`public/preview.html`) shows the live app inside iPhone frames:
- **Devices:** iPhone 17 Pro (402 × 874 pt), 17 Pro Max (440 × 956 pt, the App Store 6.9" screenshot size), iPhone SE (375 × 667 pt), a foldable iPhone concept, and all of them side by side.
- **Foldable concept:** closed is about 474 × 696 pt, open about 904 × 640 pt with a crease. Apple hasn't announced it, so these sizes are estimates from reported specs; update them when the real ones are out.
- **Controls:** pick the screen (Focus, Tasks, Week plan, Calendar, Net and the Health tabs), rotate, fit or actual size, and fold or unfold.
- **Safe areas:** the status bar and home indicator areas are left out of the app's frame, like iOS safe areas, and take the app's background colour.
- **Data:** it runs the real app on the same site, so it uses the data saved in that browser.

## Running it

Open `public/digital-dash.html` in a browser, or build and serve it:

```
npm start           # builds dist/ and serves it; then open /digital-dash.html
```

With `VITE_SUPABASE_URL` and `VITE_SUPABASE_PUBLISHABLE_KEY` set, accounts, rooms, AI and reminders turn on.

## How the file is organized

The file has three parts: `<style>`, the markup, and one IIFE `<script>`. The script is split into sections with comment banners (`/* ---------- NAME ---------- */`):

| Section | What it does |
|---|---|
| persistence | Global state `S`, `DEFAULT`, `merge()`, `save()`, `connect()` |
| theme | Skins, fonts (`UIF`, `CLF`), gradients (`GRADS`), custom schemes, backgrounds, clock stage background, image storage helpers, background colour matching |
| motion | `anim()`, `vt()`, `flipRender()`, `initSeg()`/`glide()`, `moveInd()`, `tweenNum()` (see Motion below) |
| navigation | `show(view)` switches between the 5 views. Navigation is a floating dock (`.rail`) at the bottom centre; brand, sync, sounds mini-player, install and search buttons sit in `.topbar` |
| CLOCKS | Flip, Digital, Analog, Words, Progress rings, Focus timer (chime; custom timers via the + button: `useTimer`, `addTimer`, `removeTimer`; focus timers log a session, breaks don't) |
| TASKS | Urgency 0 to 3 (Critical, High, Medium, Low), due dates with optional time (`dueTime`), sort by urgency then due |
| deadline pressure | `pressing(now)` picks tasks due within `PRESS_WIN` (3h); `updatePressure()` tints the clock stage (`#pressure`, weighted by `URG_W`), draws due ticks on the day line and shows a live countdown on the now-task pill; one toast at 15 minutes left |
| CALENDAR | Month grid, events plus tasks with due dates. `#cal-mode` switches to the week review |
| week review | `weekStats(start, upTo)`, `renderWeek()`: KPIs (focus time, sessions, tasks finished, net worth change, streak) compared with the same point last week, bar charts with tooltips and an `sr-only` table. Route `#week` |
| calendar import | `parseICS` / `expandICS` (RRULE daily/weekly/monthly/yearly, INTERVAL, COUNT, UNTIL, EXDATE, TZID) / `importICS`. File upload or URL (webcal is rewritten to https; many hosts block CORS, the error says so). Imported events carry `src`; re-importing replaces them. Colours `CAL_SLOTS` were checked with the dataviz palette validator |
| jukebox | Ambient sounds made live with Web Audio (no files): rain, waves, wind, fire, cafe, brown, pink, white noise, binaural. `jbPlay`, `jbPause`, mixes in `JB_MIXES`; optional auto mode plays during focus timers (`jbTimerSync`) |
| instruments | `INST` synth voices (epiano, piano, bass, pad, bell, kalimba, marimba, music box, lead, brass, drums). Each takes an AudioContext, so the music player and timer share them |
| study music | Music channels in `JBS` (`music:true`): lo-fi beats, soft piano, ambient drift, kalimba. `musBuild` registers a step function with the conductor `MUS`, which schedules swung 16ths at 74 bpm on the audio clock over shared chord progressions (`PROGS`), so layers stay in key. Shared reverb `jbVerb()`, a compressor on the master |
| Spotify now playing | `WT.spotify` widget. Signs in with Spotify using Authorization Code + PKCE (no secret, no server): `npConnect` sends you to Spotify, `npCallback` swaps the `?code=` for tokens, `npAccess` refreshes them. Scopes: `user-read-currently-playing user-read-playback-state`. Polls `/me/player/currently-playing` every 5s while visible; `npPaint` moves the progress bar locally between polls. Tokens are kept in localStorage key `digitaldash.spotify`, never in `S`. Each person registers their own Spotify app and pastes its Client ID; the redirect URI must match the page address exactly. Signing in does not work inside an iframe preview such as claude.ai |
| timer sounds | `TS_FX` synthesized end sounds: tones (chime, bell, marimba, harp, gong, birds, digital, soft swell) and melodies in `MELO` (sunrise, wake up, music box, piano, lo-fi keys, synth pop, fanfare, dream), picked from a dropdown with a preview button, chosen separately for focus and break in the timer editor (`settings.ts`). `tsPlay` ducks the jukebox while it rings (`jbDuck`); optional ring 3 times, a cue at 1 minute left, and ticking |
| live backgrounds | `LIVE` scenes drawn on `#bg-live` (aurora, sunset, lagoon, starfield, waves, fireflies). Soft scenes render at 1/10 or 1/2 size and scale up. 30fps, 15fps under glass refraction, paused when hidden, one still frame with reduced motion. `settings.bg.live`, `bg.speed`, `bg.grain` (film grain overlay on `#bg-dim::after`) |
| glass hover | `LG_LEAN`, `LG_NUDGE`, `LG_LIT` list what leans, nudges and catches the light. Aim is measured against the box at hover entry (`restRect`) so a moving piece does not chase Chrome's synthetic mousemoves. Pressing any of them in glass mode spreads a ripple (`.lg-rip`) |
| command bar | `<dialog id="cmd">`, Ctrl/Cmd+K or `/`. `cmdResults(q)` builds rows; `parseTask` / `parseWhen` understand things like "gym tomorrow 5pm high", "essay sep 30 !!!", "timer 40", "play rain", "theme midnight", "done lab", "tfsa 13000", "week". A bare time already past rolls to tomorrow |
| NET WORTH | Assets and debts accounts, daily history snapshots, SVG line chart, privacy eye (`setPrivacy()`: masks every amount, shows growth as a percentage; stored as `settings.hideNw`) |
| mini stats | Widget system (`WT` registry, `renderWidgets`, widget config forms) |
| focus controls | Clock picker, 24h and seconds toggles, zen mode |
| editable subtitles | Any element with `data-sub="key"` becomes inline editable; saved to `S.settings.subs` |

## State

Everything is in one object `S`, saved as JSON:

```
S = {
  tasks:    [{id, title, urg, due:"YYYY-MM-DD", dueTime:"HH:MM"?, plan:"YYYY-MM-DD"?, done, doneAt, created}],
  events:   [{id, date, time, title, src?}],          // src = imported calendar id
  calendars:[{id, name, url?, slot, count, at}],     // imported .ics calendars
  accounts: [{id, name, kind:"asset"|"debt", cat, value}],
  history:  [{d:"YYYY-MM-DD", v:netWorth}],        // one point per day
  sessions: {"YYYY-MM-DD": count},                  // finished focus timers
  focusLog: {"YYYY-MM-DD": seconds},                // focus time, for the week review
  timers:   [{id, name, sec, kind:"focus"|"break"}],  // Focus timer choices (settings.timerId = last used)
  schemes:  [{id, name, c:{bg,panel,ink,accent,card,cardInk}}],
  widgets:  [{id, type, size:"s"|"w", title?, cfg?}],
  courses:  [{id, name, target, items:[{id, name, w, score}]}],  // grades; name links to t.course
  goals:    [{id, name, target, by?, track:"nw"|accountId}],     // money goals
  settings: {
    skin, accent, uiFont, clockFont, clock, h24, secs, currency, hideNw, surface:"solid"|"glass",
    radius, clockScale, subs:{}, refract,
    jb:    {vol, on:[soundIds], lv:{id:level}, auto},
    bg:    {type:"none"|"color"|"gradient"|"image", color, grad, image, iw, ih, dim, blur, match, pal},
    stage: {type:"theme"|"color"|"gradient"|"image"|"glass", color, grad, image, iw, ih, dim, ink}
  }
}
```

`merge()` fills in defaults for any missing keys, so adding a new setting only needs a default in `DEFAULT`.

## Installable app (PWA)

- `public/digital-dash.webmanifest` (scope `/digital-dash`, standalone, shortcuts to Tasks, Week review and Calendar) and icons `public/digital-dash-*.png`.
- `public/digital-dash-sw.js`: network first for the app, cache fallback so it opens offline; Google Fonts cache first. Bump `CACHE` when the precache list changes.
- The Install button appears when the browser fires `beforeinstallprompt`; on iPhone, Your data shows the Share, Add to Home Screen steps.

## Accounts (Supabase)

Optional sign-in so data saves to the cloud and follows you across devices. Signed out, everything works as before and saves in the browser.

**How it works**
- Sign in with an email magic link or Google (Supabase Auth, implicit flow). The redirect lands back on `digital-dash.html#access_token=...`; `acBoot()` takes the token out of the address bar before the router reads the hash.
- The whole state `S` is one row in `public.dash_state` (`user_id`, `data` jsonb, `rev`, `device`, `updated_at`). Row level security: only the owner can read or write their row.
- Each `save()` marks the device dirty (`digitaldash.acct` in localStorage) and pushes about 1.2 s later. An update only lands if `rev` still matches the last one this device saw. If another device saved first, the newer version is loaded and the toast offers Undo to put this device's version back. The app also checks for newer saves when the tab regains focus and every 60 s.
- First sign-in on a device: no row yet, so this device's data is uploaded. Device empty: account data is loaded. Both have data: a dialog asks which to keep.
- Photos go to the private `dash-images` storage bucket under `<user id>/<image key>` and download on demand on other devices.
- The account dialog (top bar avatar, `Account` in the command bar, or Themes, Your data) shows sync status, counts, presets, colour schemes, timers and imported calendars, plus Download backup, Sign out (optionally clearing this device) and Delete account (`delete_my_dash_account()` RPC after removing the user's photos).
- Spotify tokens are kept out of `S`, so they never reach the account.

**Config**: `scripts/build.mjs` writes `/digital-dash-config.js` (`window.DASH_CONFIG = {supabaseUrl, supabaseKey}`) from `VITE_SUPABASE_URL` and `VITE_SUPABASE_PUBLISHABLE_KEY`. It refuses a secret key. Without it, the account dialog says the site isn't connected yet. supabase-js loads from jsDelivr only when the config exists.

**One-time setup**
1. Run `supabase/migrations/20261001120000_digital_dash_accounts.sql` on the project: either let the Supabase GitHub integration apply it, or paste `supabase/setup-all.sql` (all migrations in one file) into the Supabase SQL editor and run it. It creates `dash_state`, its policies, the `dash-images` bucket with policies, and `delete_my_dash_account()`.
2. Supabase, Authentication, URL Configuration: add the dashboard's full address (for example `https://your-site/digital-dash.html`) to Redirect URLs. Also add the local address you test on (`http://localhost:3000/digital-dash.html`).
3. Email sign-in works with Supabase's built-in mailer for testing (it is rate limited). For real use, set up custom SMTP under Authentication, Emails.
4. Google (optional): in Google Cloud create an OAuth client (Web), add `https://<project>.supabase.co/auth/v1/callback` as an authorized redirect URI, then paste the client ID and secret into Supabase, Authentication, Sign In / Providers, Google. Until then the Google button explains that it isn't turned on.

**Testing checklist**
- Sign in by email on a laptop with some tasks; the row appears in `dash_state` with `rev` 1.
- Add a task; `rev` goes up and the avatar dot turns green.
- Sign in on a phone; the laptop's data loads. Edit on the phone, come back to the laptop tab; it updates.
- Edit on both before syncing to see the "Loaded newer changes" toast and Undo.
- Upload a background photo; it shows on the other device.
- Delete the account and confirm the row and files are gone.

## Recurring tasks and checklists

- `t.rep = {f, n, days}`: `f` is `d` (every n days), `wd` (weekdays), `w` (weekly on `days`, Sunday = 0, every `n` weeks) or `m` (monthly). Set from the task form (Repeat + day buttons) or the command bar: "gym every mon wed fri 6pm", "problem set every friday", "readings weekdays", "rent monthly", "water plants every other day", "review notes every 2 weeks".
- Ticking a repeating task keeps it as done and adds the next one (`spawnNext`, `nextDate`); if it was finished late, the next one lands on the next date still ahead. Unticking removes that next one again. With no date given, the first one lands on the next matching day (`firstDue`).
- Ticking a task off keeps it in place for 6 seconds (`DONE_GRACE`) with an Undo button and a shrinking bar before it leaves the open list; the toast has Undo too. `setTaskDone(t, done)` is the one place that ticks or unticks (it also spawns or removes the next repeat), and `undoDone(t)` puts a task back.
- `t.steps = [{id, t, done}]` is the checklist, opened with the list button on a task. The row shows a progress bar; finishing every step offers to tick off the task. The AI helper's "Add as checklist" puts its steps here.

## Health: gym

Health (`#health`, `#gym`, `#gym-progress`; "gym", "workout", "progress", "plates", "bodyweight" in the command bar) is its own dock section with **Workout** and **Progress** tabs (`S.settings.gymTab`). Data lives in `S.gym`, created on first use (`gymS()`), so nothing else is touched.

Meals and macros are hidden for now (`renderHealth` never shows `#meal-body`). Its code and any `S.food` data are kept, so it can come back without losing anything.

- **Workout:** start empty, repeat the last workout, or start a saved routine. Adding an exercise fills its sets from last time and shows last time and your best set. Sets have weight, reps and a tick; ticking starts the rest timer (off, 1 to 4 min, +30s, Skip). Finish drops empty sets; history (6 shown, "Show all") can be reopened to edit or deleted with Undo.
- **What to lift next** (`gymSuggest`, double progression): if every set at last time's top weight matched the first set's reps, suggest one step up (5 lb / 2.5 kg) at those reps; if reps dropped, stay and match them; bodyweight moves get "one more rep". "Use" fills the unticked sets.
- **Plate calculator** (`plateSplit`): plates per side for a target with a chosen bar (Olympic, women's, EZ, none), the closest loadable weight when it isn't exact, and a warm-up ladder (bar × 10, 40% × 5, 60% × 3, 80% × 2). Each exercise has a "Plates for…" shortcut.
- **New PR**: a set beating your best estimated 1RM for that exercise (Epley, weight × (1 + reps ÷ 30)) is flagged on the exercise.
- **Progress tab:** weekly goal (1 to 7 workouts) with a streak of weeks hitting it; a 12-week calendar; a chart per exercise of est. 1RM, top weight or volume per session (`lineChart`: 2px line, ringed 8px dots, crosshair and tooltip on hover, tap or arrow keys, table view); sets per muscle group this week (`gymMuscle` groups exercises by name, unknown ones count as Other); personal records; a bodyweight log (`S.gym.body`, one entry per day) with its own chart and change over 30 days.
- **Training split** (`S.gym.split`): the Workout tab shows "Your split" with today's (or, in a rotation, the next) routine, a Start button and the week or rotation strip.
  - **Edit split** opens a dialog with the split name, the schedule (the same days each week, or a rotation Day 1, 2, 3… that moves on when you finish that day's workout or press "Rest day done"), and a routine or Rest for each day. Rotation days can be added, removed and reordered.
  - Each routine (`S.gym.templates`, shared with "Save as routine") can be renamed, have exercises added, removed and reordered, or be deleted; days using a deleted routine become rest.
  - **Presets:** Push/Pull/Legs, Upper/Lower, Full body 3×, Bro split, Arnold split and a PPL rotation. A routine with the same name is reused, so your own exercises are kept.
  - Changes only apply when you press Save split, and that has Undo. Removing the split keeps your routines. Workouts started from the split remember the day (`w.split`).
- **Workouts on the calendar** (`gymCalItems`, added in `itemsFor`):
  - Finished workouts show on their day.
  - The split's planned routine shows from today on: weekly splits by weekday, rotations counting forward from today's "up next" day, starting tomorrow once today's is done.
  - They appear in the Month view (as "Gym: Push"), the day panel (tapping one opens Gym), the Week and Month plan, and the Upcoming widget (today only).
  - They're worked out each time and never saved as events, so changing the split updates the calendar straight away. They can't be dragged.
  - "Show workouts on the calendar" in Gym settings (`S.gym.cal`) turns them off.
- **Body and calories tab** (`#bmi`, "bmi", "calories", "cut or bulk" in the command bar). It uses the same maths as calculator.net's BMI and Calorie calculators, stored in `S.gym.profile`:
  - **Inputs:** US or metric units (switching converts what you typed), age, sex, height, weight, optional body fat %, the 7 activity levels (BMR, 1.2, 1.375, 1.465, 1.55, 1.725, 1.9), formula (Mifflin-St Jeor default, Revised Harris-Benedict, Katch-McArdle), and kcal or kJ.
  - **BMI:** WHO adult categories, healthy weight for your height, the distance to the healthy range, BMI Prime and Ponderal index.
  - **Calories:** maintenance (BMR × activity) and lose or gain 0.5, 1 or 2 lb a week (0.25, 0.5 or 1 kg) at ∓250, 500 or 1,000 kcal, with % of maintenance. Days under 1,500 kcal (men) or 1,200 (women) are flagged "low".
  - **Cut, maintain or bulk:** `bodyCalc` decides from body fat % when you give it (men over 25% or women over 32% cut; under 12% or 20% lean bulk; otherwise maintain). Without body fat it uses BMI: under 18.5 bulk, 18.5–22 lean bulk, 22–25 maintain, 25+ cut. You can pick any plan; macros follow it: protein 2.2 g/kg on a cut and 1.8 otherwise, fat 25% of calories, carbs the rest.
  - **Weight:** logging bodyweight on Progress updates the weight used here.
  - Checked against the calculator.net example (25, male, 5'10", 165 lb, moderate, Mifflin): BMI 23.7, BMR 1,740, maintenance 2,549, then 2,299 / 2,049 / 1,549 to lose and 2,799 / 3,049 / 3,549 to gain.

## Editing tasks

- The pencil button on a task (task list, week plan and the month view's day card), or double-clicking a task's title, opens the Edit task dialog (`teOpen`): title, urgency, course, due date and time, and the planned day.
- Only those fields change; steps, repeat, reminder, study history and everything else on the task are kept. Saving offers Undo with the old values.
- "Break down with AI" is hidden (`AI_BREAKDOWN = false`) until the AI helper is set up; the code and any steps it already added stay.

## Archive

- Finished tasks leave your lists `S.settings.archiveDays` after you tick them off (1, 3, 7, 14 or 30 days, or never; default 7). `archSweep` sets `t.archived` (a timestamp) on load and every hour; it skips tasks still in their Undo grace period. Old done tasks with no `doneAt` use `created`.
- Archived tasks are hidden from the task list, week plan and calendar (`sortedTasks`, `itemsFor`) but still count in stats, the week review and the Done this week widget.
- The Archive button under the task list (or "archive" in the command bar) opens a separate dialog: change the number of days, search, Restore (back to Done for another full period via `t.restoredAt`), delete one for good, archive everything finished now, or delete the whole archive. All with Undo. The newest 1000 archived tasks are kept.
- Toasts move into an open dialog so their Undo button can be clicked while the dialog is up.

## Week plan

Tasks > Week plan (`#plan`, also a home screen shortcut and "week plan" in the command bar) lets you plan by **Week** or **Month** (`S.settings.planMode`), so you can split up your work and see how each day looks.

- `t.plan` is the day you plan to work on a task, separate from its due date. A task shows on its plan day, or on its due day until it has one (`wpDay`).
- Week: a column per day with that day's calendar events (with times), its tasks (tick them off; done ones stay on the day, struck through), a done/total bar and quick add. Columns fill the screen height on desktop, side-scroll on tablets (starting at today) and stack on phones.
- Month: a calendar grid where each day shows its events and tasks (dots on phones). Pick a day to see its full card beside the grid (below it on smaller screens) to tick off, move or add tasks.
- Quick add understands the command bar syntax ("quiz prep 4pm #MATH1600 high") and plans the task for that day.
- Move a task by dragging it to another day or month cell (press and hold on touch), with its Move menu (another day that week, next week, or back to not planned), or by tapping a "Not planned yet" chip and then a day. Moves have Undo.
- "Not planned yet" holds open tasks with no plan that aren't due in the period shown. On the current week or month, "Move to today" brings unfinished planned tasks from earlier days forward.
- While the plan is showing, the page widens to 1640px and the Tasks subtitle hides to give the days more room.
- The Tasks "Today" filter and the Due today widget count tasks planned for today; the calendar's "No date yet" tray leaves out planned tasks.

## Study tracking

- `t.course` (task form Course field with suggestions, or `#ES1050` in the command bar).
- The focus timer's "Working on" picker (`settings.tmTag`: `t:<task id>`, `c:<course>` or nothing) tags each finished focus session in `S.focusTags = [{d, sec, task, course}]`.
- Tasks show "3 sessions · 1h 15m". The week review adds "Time by course" (sorted bars, one hue, value on every row, with untagged focus time shown separately so totals still add up) and "Most time on".

## Phone and accessibility

- **Voice:** a mic button on the task form adds a task from speech straight away (with Undo); the command bar mic types what you said so you can pick a result. Uses the browser's speech recognition (`SpeechRecognition` or `webkitSpeechRecognition`; Chrome, Edge, Safari, Samsung Internet) and stays hidden where it's missing. `parseWhen` understands spoken forms: "5 p.m.", "at 5" (1 to 7 means PM), "this Friday", "remind me to…", "due on Monday".
- **App icon badge:** `appBadge()` sets the installed app's badge to open tasks due today or overdue (`navigator.setAppBadge`), on every save, when the app comes back to the front and every 5 minutes.
- **Home screen shortcuts** (long-press the app icon), from the manifest: New task (`#new-task`), Start focus (`#start-focus`), Today (`#today`), Calendar. `shortcutLink()` handles them and swaps the address to a plain view so a reload doesn't repeat them.
- **Today filter** on Tasks: open tasks due today or overdue.
- **Accessibility:** axe-core reports no WCAG 2.2 AA or best-practice issues on any view at phone width (solid, light and glass themes) or in the command bar, reminder and account dialogs. Editable page titles stay real headings; every settings control is named by its row text (`labelFields()`); calendar days are read as "9 October, Friday, today, 2 items"; a "Skip to content" link; touch targets are at least 44 px on touch screens.
- **Phones on their side** (short landscape): compact header, icon-only dock, and the clock also fits the height.

## Hover animations

- Themes, Hover animations. `S.settings.hover = {style, k, speed, light, ripple}`; missing values fall back to `HV_DEF`.
- Styles: `auto` (Liquid on glass, Lift on solid), `lift`, `glow`, `tilt`, `magnetic`, `liquid`, `off`. `applyHover()` resolves the style into `html[data-hv]`, `--hv-k` (strength, 0.25 to 2) and `--hv-dur` (speed). Lift and Glow are CSS; Tilt, Magnetic and Liquid are drawn by the spring engine (`pieceDraw`), whose stiffness scales with speed.
- Cursor light (`html.hv-light`) moves a soft spotlight with the pointer on solid surfaces; glass keeps its own sheen. Press ripple works on both surfaces.
- Built-in presets are in `HV_PRESETS`; your own are `S.settings.hoverSaved = [{id, name, v}]` (up to 12, delete with Undo). Hover is also saved with look presets (`PRESET_KEYS`).
- Mouse only. Reduced motion drops the movement and keeps colour changes and the light.

## Courses and grades

- Tasks has a `#task-mode` switch: Tasks or Courses and grades (`setTaskMode`, `renderCoursesPane`).
- Each course has a goal percent and weighted parts. Scores accept `42/50`, `84` or `84%` (`gPct`). `gradeCalc` gives the average so far, the score needed on the ungraded weight to hit the goal, the best grade still possible, and the final grade once everything is in. Weights that don't add up to 100 get a note.
- Renaming a course renames it on tasks (`t.course`) and tagged focus sessions too. Each card shows open tasks and focus time this week for that course.

## Grade calculator

Courses and grades > Grade calculator (or "grade calculator" in the command bar), modelled on calculator.net's. State is `S.gcalc` and syncs.

- Grades in percentages ("85", "85%" or "42/50"), letters or points. Percent and letters: weighted average Σ(grade × weight) / Σweight; with no weights at all every row counts the same; rows missing a weight when others have one are skipped (and said so). Points: Σearned / Σpossible. Letters average GPA points (or the middle of each range on scales without GPA) and map back to a letter.
- Scales: Standard (US, A 93+, A- 90, B+ 87…), Ontario (U of T style, A+ 90, A 85, A- 80…) and Western University (A+ 90, A 80, B 70, C 60, D 50). The scale table highlights your current letter.
- "What do I need on the rest?": goal (percent or letter, which uses that letter's cutoff) and the weight still to come (defaults to 100 − the weights entered). Need = (goal − average × (100 − R)/100) / (R/100); points mode uses (goal × (possible + P) − earned) / P.
- Final exam calculator: need = (want − current × (1 − w)) / w, with "already locked in" and "out of reach" cases.
- "Save as a course" turns the rows into a course on My courses (points become weights by share of the total).

## Money goals

- Net (the net worth page) has a Goals panel. A goal tracks net worth or one asset account, with an optional date; it shows progress and how much a month is needed to reach it in time. With amounts hidden it shows only percentages and months left.

## Drag and drop

- `dragable(container, selector, {target, drop, when})`: one pointer-event drag for mouse, pen and touch. Touch starts after a 280 ms hold so the page still scrolls; Escape cancels; a drop never counts as a click.
- Calendar: undated tasks sit in a tray under the month (`renderTray`). Drag one onto a day, or tap it and then tap a day (`pickTask`). Items in the day list can be dragged to another day (`moveItemTo`, with Undo); imported calendar events stay put.
- Widgets reorder by drag while customizing (the arrow buttons still work).

## Focus heatmap

- `focusHeatmap()` adds "A year of focus" to the current week review: 53 weeks of days, one accent hue in five steps (0, under 25 min, under 1 h, under 2 h, 2 h+), a legend, tooltips and a text summary (active days, longest run, total). It scrolls sideways inside its panel on phones.

## Reminders (Web Push)

Phone and computer notifications, even when Digital Dash is closed: a task's due time (15 min to 1 day before), a morning summary of what's due, calendar events 15 minutes before, and "Focus session done".

How it works:
- Themes, Reminders, "Turn on reminders for this device" asks for permission, subscribes with the VAPID public key from `dash-push` (`{action:"key"}`) and saves the subscription with `dash_push_register()`.
- The app works out the next 7 days of reminders (`remBuild`) and keeps them in `dash_reminders` (ids are `<user>:<tag>:<time>`, so every device writes the same rows; stale ones are deleted). It re-syncs about 4 seconds after changes. The focus timer's reminder is written when it starts and removed when paused.
- `dash-push` with `{action:"run"}` (every minute from pg_cron, with the `x-cron-secret` header) sends what's due, marks it sent, skips anything more than 30 minutes stale and drops subscriptions the push service reports as gone. It encrypts with `web-push` and delivers with `fetch`.
- `digital-dash-sw.js` shows the notification and opens or focuses the app at the right page when it's tapped.
- Signing out turns reminders off on that device.
- iPhone and iPad (iOS 16.4 or later) only allow web notifications for apps added to the Home Screen; the panel explains this when needed.

**One-time setup**
1. Run `supabase/migrations/20261001140000_digital_dash_push.sql`.
2. Make VAPID keys: `npx web-push generate-vapid-keys`. Add secrets `VAPID_PUBLIC_KEY`, `VAPID_PRIVATE_KEY`, `VAPID_SUBJECT` (`mailto:you@example.com`) and a long random `CRON_SECRET`.
3. Deploy: `supabase functions deploy dash-push` (`verify_jwt = false` is set in `supabase/config.toml`, because the cron call uses the secret instead).
4. Open `supabase/digital-dash-reminders-cron.sql`, put in your project ref and the same `CRON_SECRET`, and run it in the SQL editor. It enables `pg_cron` and `pg_net` and calls `dash-push` every minute.
5. On your phone: open the site, add it to the Home Screen (needed on iPhone), open it from there, sign in, then Themes, Reminders, turn on, and press "Send a test".

## Email and text reminders for tasks

- The bell on a task opens **Remind me**: when (at the due time, 15 min to 1 day before, or a date and time you pick; tasks with only a date use 9:00 AM) and how (email, text message, notification). Stored as `t.remind = {lead, ch, at?}`; repeats carry relative reminders to the next one.
- Where they go is set in Themes, Reminders, **Email and text reminders**: agree to emails at the account email, and add a mobile number, which is confirmed with a 6-digit code (`phone-start`, `phone-verify`). That lives in `dash_contacts`, which only the `dash-push` function can read; the browser only ever sees a masked number.
- `remBuild()` writes task reminders (`kind: "task"`, up to 30 days ahead) to `dash_reminders` with a `channels` array. `dash-push`, run every minute, sends push to devices, email through Resend and texts through Twilio, with daily caps per account (`dash_msg_usage`, 20 texts and 50 emails by default).
- Opt-outs: every email has an unsubscribe link (and a one-click `List-Unsubscribe` header); a STOP reply makes Twilio refuse further texts, and the function then turns texts off for that account.

**Setup**
1. Run `supabase/migrations/20261008120000_digital_dash_task_reminders.sql` (the GitHub integration does it on merge).
2. Email: create a Resend account and API key. Until you verify a domain in Resend, it can only email your own address; to email other people, add your domain in Resend and set `REMIND_FROM` to an address on it.
3. Texts: create a Twilio account, buy a number (or use a Messaging Service), and set `TWILIO_ACCOUNT_SID`, `TWILIO_AUTH_TOKEN` and `TWILIO_FROM`. A trial account can only text numbers you've verified in Twilio. Under Messaging, Geo permissions, allow only the countries you need (for example Canada and the US) to block SMS fraud. Texting US numbers needs A2P 10DLC registration, or a verified toll-free number.
4. Secrets: `supabase secrets set RESEND_API_KEY=... REMIND_FROM="Digital Dash <reminders@yourdomain.com>" TWILIO_ACCOUNT_SID=... TWILIO_AUTH_TOKEN=... TWILIO_FROM=+1... SITE_URL=https://usedigitaldash.vercel.app`, then `supabase functions deploy dash-push`. Optional: `SMS_DAILY_LIMIT`, `EMAIL_DAILY_LIMIT`, `REMIND_SECRET`.
5. The pg_cron job from `supabase/digital-dash-reminders-cron.sql` must be running (it already sends push reminders).

## Study rooms (Supabase Realtime)

Focus with friends: see who's in a session and start a shared timer. No tables; a room is the Realtime channel `dash-room-<CODE>`.

- **Create or join**: Focus page, Study room card. Codes are 6 characters (`K86-VZ7`); "Copy invite" gives `digital-dash.html?room=CODE`, which joins straight away (asking for a display name first if you're signed out). The last room is rejoined on reload; Leave forgets it.
- **Presence** carries `{id, name, status: focus|break|idle, ends, len, task, group}`. It comes from your own focus timer, and is re-sent only when it changes (`rmPush`).
- **Room timer** (`group`): "Start together" broadcasts `{kind, len, ends, started, by, name}`; anyone with "Run it on my timer" on gets the same end time on their focus timer (`T.id = "room"`). Late joiners pick it up from presence (newest `started` wins). "End for everyone" broadcasts a stop.
- **Reactions** (👏 🔥 💪 ☕) are broadcasts with a floating emoji and a toast. "Show my top task while I focus" is off by default.
- Signed in, your account name is used; signed out, you type a name and a random id stays on the device (`digitaldash.room`).
- **Setup**: nothing beyond the account setup, as long as Realtime allows public channels (Supabase, Project Settings, Realtime; on by default). Anyone with a code can join that room, so codes are random and unlisted.

## AI helper (Supabase Edge Function + Claude)

Two actions, both previews you confirm before anything changes:
- **Break it down**: the sparkle button on a task (or "break down chem" in the command bar). Returns 3 to 8 steps with time estimates and dates before the deadline. You can untick or edit steps; picked ones are added as tasks named `Parent: step` with Undo.
- **Plan my week**: button on the Tasks page (or "plan my week"). Sends open tasks and the next 7 days of calendar events, gets back timed focus sessions plus warnings, and adds the ones you keep as calendar events with `src: "ai"` (shown as "AI plan"). A new plan replaces earlier AI sessions from today on; Undo restores.

How it works:
- `supabase/functions/dash-ai/index.ts` (Deno) checks the caller is signed in, counts the request with `dash_ai_take()` (per-user daily limit, default 25, env `DASH_AI_DAILY_LIMIT`), then calls Claude with the official SDK (`npm:@anthropic-ai/sdk`): model `claude-opus-5-5`, `effort: "medium"`, structured JSON output (`output_config.format` json_schema), and `fallbacks: "default"` (beta `server-side-fallback-2026-07-01`) so a declined request is retried on Anthropic's recommended fallback model. Refusals, truncation and API errors become friendly messages.
- The browser calls it with `AC.sb.functions.invoke("dash-ai", ...)`, so the API key never leaves the server. The client re-checks every returned date, time and task id before showing it.

**One-time setup**
1. Run `supabase/migrations/20261001130000_digital_dash_ai.sql` (usage table and `dash_ai_take`).
2. Add the secret: `supabase secrets set ANTHROPIC_API_KEY=sk-ant-...` (or in Supabase, Edge Functions, Secrets). Optional: `DASH_AI_DAILY_LIMIT`.
3. Deploy: `supabase functions deploy dash-ai`. `verify_jwt = true` is set in `supabase/config.toml`.
4. Cost: each request is one Claude call. The daily limit caps it per person; lower it if you share the app widely.

## Privacy

What leaves the device, and where it goes:
- **Signed out:** nothing. Everything stays in this browser's storage.
- **Signed in:** the whole dashboard (tasks, calendar, net worth, settings) and uploaded photos are stored in the site owner's Supabase project, readable only by that account (row level security). Deleting the account removes them.
- **AI helper:** task titles, due dates, urgency, course names and the next 7 days of calendar event titles and times are sent to Anthropic's API through the `dash-ai` function, only when you press Break it down or Plan my week. Nothing else (no net worth, no notes).
- **Reminders:** reminder titles and times (task and event titles) are stored in `dash_reminders` and sent through the browser's push service (Google, Apple or Mozilla) as encrypted messages.
- **Study rooms:** your display name, focus status and time left are visible to anyone with the room code; your top task only if you turn that on.
- **Spotify:** the app talks to Spotify directly from the browser with your own app's Client ID; tokens never reach the Supabase project.

The same points are shown in short in the app: in the Account dialog, the AI helper and the study room card.

## Storage

- `localStorage` key `grindboard.v1` holds `S` (kept for backward compatibility with the old name).
- Background photo: `localStorage` key `digitaldash.bgimg`. Other images: `digitaldash.img.<key>`.
- Image `src` values: `"local"` (page background), `"local:<key>"` (stage or widget image), or `"/_blob/<id>"` (claude.ai asset store).
- `connect()` and `storeImage()` try the claude.ai artifact runtime (`window.claude.use("db" | "user" | "assets")`). Outside claude.ai that runtime does not exist, so the app silently falls back to localStorage. Nothing breaks, but data only lives in that browser.

## Theming

- Colours are CSS variables on `:root`: `--bg --panel --panel2 --ink --muted --line --accent --accent-ink --card --card-ink`, plus urgency colours `--u0` to `--u3`.
- Built-in skins are `html:root[data-skin="..."]` blocks (the `:root` part is needed so they beat the dark mode media query).
- Custom schemes and background matching set the variables inline via `setScheme()`; `--panel2`, `--line`, `--muted` and `--accent-ink` are derived automatically.
- Background matching: `computePal()` reads the background (photo pixels sampled on a 48x48 canvas, or gradient/solid hex values) into `{base, vivid}`, and `deriveScheme()` turns that into a light or dark scheme. It is on by default and turns off when the user picks a fixed theme.
- Fonts load on demand from Google Fonts via `loadFonts()`. Clock fonts carry a digit width (`--dw`) so flip cards fit wide fonts; `--fs` scales the flip clock down for them.

## Widgets

Registry `WT` in the widgets section. Each type has `name`, `title`, `desc`, and optional default `cfg`. To add one: add an entry to `WT`, a `case` in `wBody()`, and any settings fields in `wCfgForm()`. Current types: open, today, sessions, networth, toptasks, upcoming, countdown, quote, note, world, progress, image, donewk.

## Motion

The goal is that nothing teleports and nothing waits on you. Rules the code follows:

- **Tokens** live on `:root`: `--ease-out` `cubic-bezier(0.23,1,0.32,1)` for entering and leaving, `--ease-in-out` `cubic-bezier(0.77,0,0.175,1)` for things moving on screen, `--ease-drawer` for the zen morph, and durations `--t-press` 120ms, `--t-fast` 160ms, `--t-ui` 220ms, `--t-move` 260ms. `EASE_OUT` and `EASE_IO` mirror them for WAAPI. Reuse these, don't add new curves.
- **Only `transform`, `opacity` and `clip-path` animate.** The day line and progress bars use `scaleX`, not `width`.
- **Clocks run off the main thread.** Analog hands are infinite linear CSS spins phase-locked to the wall clock with a negative `animation-delay` (`syncAnalog()`). The flip leaf is a CSS keyframe that accelerates over the hinge, overshoots slightly and settles, with shading on both faces. The JS tick runs once per second, aligned to the second boundary, not a 60fps rAF loop.
- **Lists re-render with `flipRender(container, render, mode)`.** Rows keyed by `data-id` slide from their old position, new rows fade in with a short stagger, and removed rows fade out as ghosts. Pass `"plain"` when the whole list swaps (task filters, another day). Used for tasks, widgets, day items and accounts.
- **Segmented controls** get a thumb that glides to the pressed option by animating `clip-path: inset()`. A MutationObserver on `aria-pressed` moves it, so code only has to set `aria-pressed`. Call `initSeg()` on any new `.seg`.
- **Tabs**: one rail indicator slides between them (`moveInd()`); views fade and rise 8px in.
- **Feedback**: buttons scale to .97 on press; task checks draw their tick and strike through the title before the row moves, which is why toggles wait 420ms (`afterTaskChange`).
- **View transitions** (`vt()`) morph the clock stage into zen mode and crossfade theme swaps. Browsers without the API just switch instantly.
- **Toasts** use transitions, not keyframes, so rapid toasts retarget instead of restarting.
- **Hover motion** is gated behind `(hover: hover) and (pointer: fine)`.
- **Liquid glass** (`S.settings.surface = "glass"`, class `lg` on `<html>`), modelled on the Liquid Glass Room artifact. In Chromium (class `lgr`, toggle `settings.refract`) each pane gets real refraction: an SVG filter used as its `backdrop-filter`, whose `feDisplacementMap` reads a map drawn from the rounded rectangle's signed distance field (convex squircle bezel, pointing inward). Filters are cached per kind and size (`lgFilter`); big panes use one displacement pass with no frost, small pieces (segmented controls, toast) split R/G/B for a colour fringe. Other browsers fall back to `blur() saturate()`. The material is `--rim` (inset highlights lit from the top-left) plus `--lift` (two-layer shadow), and a screen-blended `::after` sheen whose hotspot follows the cursor (`--lx/--ly`, faded by the registered `--hov`). `prefers-reduced-transparency` and `prefers-contrast: more` fall back to solid panels.
- **Droplets** (glass mode): the selected-tab highlight (`.seg .thumb`, `.rail .ind`) and a fainter hover bead (`.hbead`) are boxes whose four edges run on springs; along the direction of travel the leading edge is stiffer, so the droplet stretches toward the new tab and then catches up (`dropTo`). `glide()` and `moveInd()` hand over to them when `lg` is on; `lgModeChanged()` swaps back.
- **Glass hover** (mouse only): the "liquid glass engine" section. Widgets, theme cards and task rows lean up to ~6px toward the cursor and bulge that way (scaled down for big panes), with a ripple on entry and a flick outward on exit so they wobble back; buttons get half the lean on the `translate` property so `:active` scale still composes. One passive `pointermove` listener, one rAF loop that sleeps at rest. Reduced motion keeps the hotspot and drops the movement.
- **Presets** (`S.presets`, Themes > Presets): named copies of `PRESET_KEYS` (scheme, accent, fonts, radius, clock size and style, surface, refraction, background, clock background). Photos are copied to their own image keys (`p<id>bg`, `p<id>st`) and a custom scheme is stored with the preset. Apply runs as a view transition; the preset matching the current look shows "In use".
- **Select menus**: where `appearance: base-select` is supported they are drawn in theme colours (glass in glass mode) and open from the trigger in 180ms. Elsewhere `color-scheme`, set from the theme's `--bg` in `applyTheme()`, keeps native menus and date pickers light or dark to match.
- **Font fitting** (`fitFonts()`): after the chosen fonts load, a canvas measures the clock font's widest digit, average capital, colon ink and where digits sit in the line box, and the text font's average lowercase width, all relative to the defaults (Big Shoulders, Bricolage). It sets `--hs` (headings, brand, section titles, Words clock), `--fs`/`--ns` (clocks and big numbers), `--dw` (flip card width), `--cw`/`--kx`/`--ky` (colon width and dot centring), `--dy` (vertical centring of digits) and `--us` (body text), on soft power curves so wide faces shrink without looking tiny. `fitClock()` then scales the clock (`--fk`) if it is still wider than the stage, and font-picker and preset previews size to their tiles. Measurements are cached only once the real face has loaded. The 12-hour flip clock hides its empty leading card.
- **Clock colour guard** (`applyStage()`): if the digit colour (chosen or from the scheme) is below 4.5:1 against the clock background, it is pushed toward white or black until it reads, and a note appears under "Clock digit colour".
- **Reduced motion** means gentler, not none: movement is dropped and fades are kept. `anim()` strips transforms automatically; the analog second hand ticks with `steps(60)`.

## UI/UX baseline (from the ui-ux-pro-max guidelines)

- **Targets**: every control is at least 24×24px with a mouse (WCAG 2.2 AA) and 44px on touch (`@media (pointer: coarse)`). Small visuals that must stay small, like the task tick, get an invisible hit area (`.check::after`).
- **Text**: nothing below 12px; form fields are 16px on phones so iOS doesn't zoom on focus.
- **Contrast**: all built-in themes pass 4.5:1 for text, including muted text on `--panel2`. Custom schemes derive `--muted` and step it toward `--ink` until it passes (`setScheme`). Clock digits have their own guard (`applyStage`).
- **Recoverable deletes**: deleting a task, event, account, widget or widget image shows a toast with Undo for 5 s (`toast(msg,{run,done})`); images are only discarded in `done`, after Undo expires.
- **Deep links and Back**: each tab is a URL hash (`#tasks`, `#calendar`, `#money`, `#themes`); tab clicks push history, `popstate` switches tabs, and loading with a hash opens that tab.

## Conventions

- UI copy is plain, friendly, sentence case, and uses no em dashes.
- Keep it one file with no framework unless we deliberately decide to migrate.
- Respect `prefers-reduced-motion`. Every animation has a reduced variant (see Motion).
- Mobile: below 720px the dock stretches edge to edge with stacked icon and label; the search button shrinks to an icon and keyboard hints hide on touch screens.

## Home page motion and cursor

- Hero rises in with a 60 ms stagger (after the first-visit DD split); sections reveal as they scroll in (`.rv` + IntersectionObserver; anything scrolled past shows at once). The How it works track draws, the privacy receipt prints and gets stamped, the "Make it yours" stats count up.
- The outlined "Make it yours." fills under the mouse or a dragged finger (`clip-path` circle on `.fill`); the phone tilts toward the mouse; the main button leans in (`translate`). "Try a new look" picks a random theme, clock and font; looks change with a circular view transition from what was pressed.
- Custom cursor (mouse only, never with reduced motion or forced colours): the DD mark at rest, leaning with movement; a worn stamp-ink ring over anything pressable (Tap / Live / Open labels); a text bar over words; clicking empty space stamps the DD mark. Shake the mouse (four quick reversals) and the mark grows big to find it.
- Springs (`spring()`, response in seconds, damping 1) run in one rAF loop that sleeps at rest; they sub-step so stiff springs stay stable.

## Look links

- Themes > Share this look (and the share icon on each preset, and Share this look on the home page) copies `digital-dash.html?look=<base64url JSON>`: the PRESET_KEYS settings without photos, plus the custom colour scheme if the look uses one.
- Opening one: a brand-new visitor just starts with it; anyone with a dashboard gets "Try this look?". Applying saves it as a preset and offers Undo. `lookClean` keeps only options that exist in the default settings with the same type and a plain value (no quotes, brackets or `url(`), so a link can't inject CSS or markup.

## Free tool pages

- `/grade-calculator`, `/final-grade-calculator`, `/pomodoro-timer`, `/bmi-calculator`, `/calorie-calculator` and `/tools`, generated by `python3 scripts/gen-tools.py` (edit the script, not the HTML). Shared look and maths in `public/tools/tools.css` and `tools.js`; the maths matches the app's (`gcCalc`, `gcFinal`, `bodyCalc`, `bodyPlans`).
- Each has a title and description for search, canonical URL, FAQ structured data, an explainer, related tools, and `public/sitemap.xml` / `robots.txt` list them. Change `SITE` in the generator when a custom domain is set up.
- "Save this in Digital Dash" writes `dd.import` to localStorage and opens the app, where `ddImport()` adds a course, final exam numbers, body details or timers, always with Undo (it never replaces without it), and skips the welcome tour that visit.

## Recap card

- Calendar > Week review > Share recap, or "recap" / "wrapped" in the command bar. A small studio: pick a design, period, size and colours, then share or save.
- Designs (`RC_DESIGNS`, drawn by `rcPaint`): Poster (the focus total as flip-clock cards, a bar chart and stat tiles), Rings (a clock-face dial where each day is a wedge), Receipt (a paper receipt with a "Paid in focus" stamp), Calendar (a heatmap of the days) and Photo (your own photo, or a soft gradient, with Strava-style stats on top). Swipe or drag the preview, or use the arrow keys; with a mouse it tilts and catches the light.
- Sizes: Story 1080×1920, Post 1080×1350, Square 1080×1080. Colours: the current theme, Light, Dark, or Bold (the accent as the background). Design, size and colours are remembered (`digitaldash.rcpref`); items left off the card in `digitaldash.rchide`. A chosen photo is only held in memory for that visit.
- Periods: this week, last week, this month, this term (Jan–Apr, May–Aug, Sep–Dec).
- The card has its own type so it looks the same everywhere: Big Shoulders Display (headlines, numbers), Bricolage Grotesque (labels) and JetBrains Mono (receipt), served from `public/fonts/` (all SIL Open Font License) and loaded with `FontFace` when the studio opens; the service worker keeps them for offline use.
- Export: Share (Web Share API with the PNG; downloads where files can't be shared), Save image (full-size PNG), Sticker (the stats on a transparent 1080×760 PNG to put over a photo) and Copy (Clipboard API). Previews are drawn at 720 wide; exports are redrawn at full size.

## Friends and weekly leaderboard

- Focus page > Friends (signed in). Pick a display name; share the 8-character code or the invite link `digital-dash.html?friend=CODE`; accept or decline requests; see this week's or last week's focus time ranked. "Show my focus time to friends" can be turned off.
- **One-time setup:** run `supabase/migrations/20261020120000_digital_dash_friends.sql` in the Supabase SQL editor (it's safe to run twice), or let the GitHub integration apply it. Until then the Friends panel stays hidden.
- Tables `dash_profiles`, `dash_friends` (one row per pair, `a < b`), `dash_focus_week` (minutes and sessions per Monday). Row level security with no access to other people's rows; everything goes through security-definer functions that only return you and people connected to you: `dash_profile_save`, `dash_friend_add`, `dash_friend_respond`, `dash_friend_remove`, `dash_friends_list`, `dash_focus_report` (this or last week only, capped at a week of minutes), `dash_leaderboard`. Deleting the account removes all of it.
- **Usernames and profile photos:** Account > Profile sets a display name, a username and a photo. A username is 3 to 20 lowercase letters, numbers or `_`, checked live as you type ("@name is available" or "is taken"). It is stored lowercase with a unique index, so no two people can hold the same one in any capitalisation; a few names (admin, support, digitaldash...) are reserved. Friends can be added by `@username` or by code (a leading `@` always means a username; otherwise a code is tried first). The photo is cropped to a 128px square in the browser and kept as a small data URL (webp or jpeg, max 40,000 characters) on the profile, shown to friends and to people who sent you a request, never to someone you've only sent a request to. The account button uses it too.
- **One-time setup for usernames:** run `supabase/migrations/20261021120000_digital_dash_usernames.sql` after the friends migration (safe to run twice). It adds `username` and `avatar` to `dash_profiles`, `dash_username_check`, `dash_profile_set` (name, username, photo and sharing in one call), and updates `dash_friend_add`, `dash_friends_list` and `dash_leaderboard`. Until it runs, friends keeps working with codes and the Profile section says usernames aren't switched on.

## Languages

- `public/i18n/i18n.js` loads first on every page. The pages stay written in English; it swaps text nodes and `placeholder`, `aria-label`, `title`, `alt` in place from `public/i18n/<lang>.json`, watching for changes with a MutationObserver. Patterns handle text with values (`Edit {0}`, `{n} sessions`). Dates use the chosen language (it wraps `toLocaleDateString` and friends when no locale is given). The dictionary is cached in localStorage, so later visits and offline translate before the first paint. Changing language reloads.
- Languages: English, Spanish, French, Portuguese, German, Italian, Vietnamese, Hindi, Chinese, Japanese, Korean. The picker is in Themes > More settings > Look and in the home and tool page headers (`<select data-lang>`). Default: the browser's language if it's one of these.
- Sources: `scripts/i18n/en.json` (strings, patterns, extra) and one `scripts/i18n/<lang>.txt` per language (`number|translation`). Run `python3 scripts/build-i18n.py`; it checks placeholders and lists missing numbers. Add new English at the end of "extra" so numbers don't shift. Anything without a translation stays English. User content (task titles and so on) is never in the dictionary; mark anything else that must not change `translate="no"`.
- The Words clock stays English (its sentences are built word by word).

## Demo video

- Home page > See it in action (`#demo`). `public/media/digital-dash-demo.mp4` (16:9, 1080p, about 1:07) and `digital-dash-demo-vertical.mp4` (9:16, used on portrait phones), each with a poster JPG. The 16:9 file is the `<source>`; the script swaps in the vertical one before loading.
- It loads only when the section is near (`preload="none"`, then metadata), plays muted and looped while at least half is on screen, and pauses when scrolled away. With reduced motion or Data Saver it never autoplays: the centre Play button starts it. Sound on/off and Play/Pause sit under the video. The service worker's scope is `/digital-dash`, so it never caches these files.
- The film is real use of the app recorded with a Playwright screencast and edited in an HTML timeline; the soundtrack is generated with Web Audio to the same timeline.

## Ideas for next steps

- Move to a real stack (for example Vite + React or Next.js) and split sections into modules.
- Import bank balances automatically, calendar sync with Google Calendar.
- Two-way Google Calendar sync (needs OAuth and a backend; today's import is read-only).

## Home page: note, what's new, QR and app waitlist

- **What's new** strip under the nav (`.news` in `public/index.html`): three short links to the latest features. Update the three `<li>`s when something ships.
- **QR code** next to Open app, desktop only (fine pointer, wider than 820px): a static inline SVG pointing at `/digital-dash.html`, in a popover that closes on Escape or a click outside.
- **Note from the maker** (`#note`) before the FAQ, signed with a first name only.
- **App store waitlist** (`#apps`): email plus iPhone, Android or both. It posts to the `dash_waitlist_join` RPC with the site's public Supabase key from `/digital-dash-config.js`. Duplicate emails also return "ok", so the form can't reveal who signed up, and a hidden honeypot field drops simple bots.
- **One-time setup:** run `supabase/migrations/20261022120000_digital_dash_waitlist.sql` in the Supabase SQL editor (safe to run twice). The list is readable only in the Supabase dashboard (Table Editor > `dash_waitlist`); row level security blocks it from the API.

## Addresses

- Main domain: `https://digitaldashdaily.com` (Vercel, DNS at Spaceship). `usedigitaldash.vercel.app` keeps working.
- `vercel.json` has `cleanUrls`, so pages are served without `.html`: the app is `/digital-dash` and `/app` forwards to it. Old `.html` links forward automatically (308), keeping the query and `#tab`.
- The service worker scope stays `/digital-dash`, so offline support and push reminders carry on unchanged. Its cache is `digital-dash-v4`, which precaches `/digital-dash`.
- Spotify sign-in uses the page address as its redirect, so a Spotify app set up for the old address needs `https://digitaldashdaily.com/digital-dash` added as a redirect URI.

## October updates

- **AI helper off:** `AI_ON = false` hides Plan my week, Break it down and their commands, and drops the AI line from the account panel. The privacy page says it's not available. Flip `AI_ON` to `true` to bring it all back.
- **Greeting:** the Focus page heading picks a random line for the part of the day (night, morning, afternoon, evening) from `GREETS`, changing only when the part of the day changes. It's still editable like every title and subtitle: while editing a customised one, a bar under it offers **Reset to original**, and Themes > Fonts has **Reset all titles and subtitles** (with Undo). Resetting the greeting brings the changing lines back.
- **Photo drop zones:** choosing Photo for the background or the clock no longer opens the file picker. It shows a drop zone you can click (or Enter), drag an image onto, or paste into (Ctrl/Cmd+V while it's focused or showing). The file goes through the same input handler as choosing one.
- **Calendar:** events have a Start and an optional End. The end fills in an hour after the start, and the length is stored as `dur` minutes, shown as "3:00 PM–4:30 PM". **Month review** (`#month-review`) sits next to Week review and compares the month with the same days of last month: focus, sessions, tasks, net worth, best day, focus and tasks per week, time by course, and finished, slipped and coming-up lists. Share recap opens the Month card.
- **Live Spotify:** set `SPOTIFY_CLIENT_ID` in Vercel (the Client ID of a Spotify app with `https://digitaldashdaily.com/digital-dash` as a redirect URI) and Now playing becomes one tap: Connect Spotify, then live song info every 3 seconds with previous, play/pause and next. Controls need Spotify Premium, and a missing device or permission gets a clear message. Without the env var it falls back to the bring-your-own Client ID steps. In Spotify's development mode, only accounts added under User Management can connect until the app gets extended quota.
- **Spotify live listening:** a Spotify panel on the Focus page (`#spx`), free for every user with no Spotify approval. People who link Spotify to a free Last.fm account enter their Last.fm username, and the card polls `user.getrecenttracks` every 15 s while Focus is open: Listening now with album art, recently played and Open in Spotify. **Dash Island:** an option that adds a Dynamic Island style black pill while a song is playing (art, title and artist, equalizer). It sits in the exact centre of the top bar (a three-column grid: logo, island, buttons; the page is 1320px wide, and below 1180px the small sync label hides while the island shows so it stays centred), and floats at the top of the screen once you scroll past the top bar. Tap it for a card with album, Open in Spotify and Hide Dash Island. It sits in the top bar between the logo and the buttons and floats at the top of the screen once you scroll past it. With Dash Island on, polling runs on every page. Needs `LASTFM_API_KEY` in Vercel (free from last.fm/api/account/create; public, read-only); without it the card says live listening isn't switched on. Settings: `S.settings.sp = {lfm, island}`. The built-in Spotify player was removed. Changing songs on someone's device isn't possible for everyone: Spotify limits that to apps with extended access; the one-tap Now playing widget still offers it to the owner plus up to 5 approved users.
- **Shopping list:** a Shopping tab under Tasks (`#shopping`, `S.shop`). Type "2 milk $4.50": a leading number or "x2" is the quantity, an amount with a currency sign or cents is the price per item, and `shopCat` guesses the aisle from English keywords (anything else goes under Other). Adding an item that's already on the list raises its quantity. Items group by aisle with an estimated total; ticking one moves it to In cart, Clear checked removes those (with Undo) and keeps them as Buy again chips (`S.shopRecent`, up to 16). Tap a name to edit it with the same syntax, Copy list puts it on the clipboard by aisle, and the command bar takes "buy eggs", "add apples to my shopping list" and "shopping list".
- **Sound effects:** Themes > Sound effects turns on ASMR-style sounds, off by default and saved in `S.settings.sfx` (`{on, kind, tap, tick, vol}`). Typing plays a key sound in text fields (never password fields) in one of five styles: Soft, Creamy (lubed linear switches: a short tap rings a few low keycap and case resonances in `sfxCreamy`, then a softer, higher return as the key comes back up), Mechanical, Typewriter (with a bell on Enter) or Bubble. It follows `input` events, so phone keyboards work too. Buttons and links click on press, and ticking off a task chimes; each can be switched off, and there's a volume slider and a box to try it. Everything is synthesized with Web Audio (`sfxPlay`), so nothing downloads.
