// Digital Dash reminders: Web Push, email and text messages.
//   {action: "key"}            -> the public VAPID key the browser subscribes with (no sign-in needed)
//   {action: "test"}           -> sends "Reminders are on" to the signed-in user's devices
//   {action: "run"}            -> sends every reminder that is due; called each minute by pg_cron with x-cron-secret
// Signed in, for email and text reminders:
//   {action: "contact"}        -> where reminders can go (email, masked phone) and which services are set up
//   {action: "email", on}      -> agree to (or stop) email reminders at the account email
//   {action: "phone-start", phone} / {action: "phone-verify", code} / {action: "phone-remove"} / {action: "sms", on}
//   {action: "test-email"} / {action: "test-sms"}
// GET ?action=unsub&u=<user id>&t=<token> (or the one-click POST) turns email reminders off.
// Secrets: VAPID_PUBLIC_KEY, VAPID_PRIVATE_KEY, VAPID_SUBJECT, CRON_SECRET; for email RESEND_API_KEY and
// REMIND_FROM ("Digital Dash <reminders@yourdomain.com>"); for texts TWILIO_ACCOUNT_SID, TWILIO_AUTH_TOKEN and
// TWILIO_FROM (a phone number, or a Messaging Service SID starting with MG). Optional: SITE_URL, REMIND_SECRET,
// SMS_DAILY_LIMIT (default 20), EMAIL_DAILY_LIMIT (default 50).
import webpush from "npm:web-push@3.6.7";
import { createClient, type SupabaseClient } from "npm:@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type, x-cron-secret, x-supabase-client-platform, x-supabase-client-platform-version, x-supabase-client-runtime, x-supabase-client-runtime-version",
  "Access-Control-Allow-Methods": "GET, POST, OPTIONS",
};
const json = (body: unknown, status = 200) =>
  new Response(JSON.stringify(body), { status, headers: { ...corsHeaders, "Content-Type": "application/json" } });

const env = (k: string) => Deno.env.get(k) ?? "";
// Push is optional: email and texts still work when the VAPID keys aren't set.
const pushReady = (() => {
  if (!env("VAPID_PUBLIC_KEY") || !env("VAPID_PRIVATE_KEY")) return false;
  try { webpush.setVapidDetails(env("VAPID_SUBJECT") || "mailto:hello@example.com", env("VAPID_PUBLIC_KEY"), env("VAPID_PRIVATE_KEY")); return true; } catch { return false; }
})();
const SITE = (env("SITE_URL") || "https://usedigitaldash.vercel.app").replace(/\/+$/, "");
const APP = SITE + "/digital-dash.html";
const SMS_DAILY = Number(env("SMS_DAILY_LIMIT")) || 20;
const EMAIL_DAILY = Number(env("EMAIL_DAILY_LIMIT")) || 50;
const emailReady = () => !!env("RESEND_API_KEY");
const smsReady = () => !!(env("TWILIO_ACCOUNT_SID") && env("TWILIO_AUTH_TOKEN") && env("TWILIO_FROM"));

type Sub = { endpoint: string; p256dh: string; auth: string };
type Note = { title: string; body: string; tag?: string | null; url?: string | null; at?: number };
type Contact = {
  user_id: string; email_on: boolean; phone: string | null; phone_verified_at: string | null; sms_on: boolean;
  code_hash: string | null; code_phone: string | null; code_expires: string | null; code_tries: number;
  codes_sent: string[]; unsub_token: string;
};

/* ---------- push ---------- */
// Encrypt with web-push, deliver with fetch (Deno's fetch is more reliable than Node's https shim).
async function deliver(sub: Sub, note: Note): Promise<"ok" | "gone" | "error"> {
  try {
    const req = webpush.generateRequestDetails(
      { endpoint: sub.endpoint, keys: { p256dh: sub.p256dh, auth: sub.auth } },
      JSON.stringify(note),
      { TTL: 4 * 3600, urgency: "high" },
    );
    const res = await fetch(req.endpoint, { method: req.method, headers: req.headers as Record<string, string>, body: req.body });
    await res.body?.cancel();
    if (res.status === 404 || res.status === 410) return "gone"; // the device unsubscribed or reinstalled
    return res.ok ? "ok" : "error";
  } catch {
    return "error";
  }
}

async function sendToUsers(admin: SupabaseClient, userIds: string[], notes: Map<string, Note[]>) {
  if (!pushReady) return { sent: 0, removed: 0 };
  const { data: subs } = await admin.from("dash_push_subs").select("endpoint,user_id,p256dh,auth").in("user_id", userIds);
  const gone: string[] = [];
  let sent = 0;
  await Promise.all((subs ?? []).map(async (s: Sub & { user_id: string }) => {
    for (const n of notes.get(s.user_id) ?? []) {
      const r = await deliver(s, n);
      if (r === "gone") { gone.push(s.endpoint); break; }
      if (r === "ok") sent++;
    }
  }));
  if (gone.length) await admin.from("dash_push_subs").delete().in("endpoint", gone);
  return { sent, removed: gone.length };
}

/* ---------- email (Resend) and text (Twilio) ---------- */
const escHtml = (s: string) => s.replace(/[&<>"']/g, (c) => ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;" }[c]!));
const unsubUrl = (fnUrl: string, c: Contact) => `${fnUrl}?action=unsub&u=${c.user_id}&t=${c.unsub_token}`;

async function sendEmail(to: string, subject: string, title: string, body: string, unsub: string): Promise<boolean> {
  const text = `${title}\n${body}\n\nOpen Digital Dash: ${APP}#tasks\n\nYou're getting this because you turned on email reminders. Stop them: ${unsub}`;
  const html = `<div style="font-family:system-ui,-apple-system,Segoe UI,sans-serif;max-width:480px;margin:0 auto;padding:24px;color:#1b1830">
<p style="margin:0 0 4px;font-size:13px;color:#6a6580">Digital Dash reminder</p>
<h1 style="margin:0 0 8px;font-size:22px;line-height:1.3">${escHtml(title)}</h1>
<p style="margin:0 0 20px;font-size:15px;line-height:1.5;color:#3b3650">${escHtml(body)}</p>
<a href="${APP}#tasks" style="display:inline-block;background:#ffb547;color:#1b1830;text-decoration:none;font-weight:600;padding:10px 18px;border-radius:10px">Open Digital Dash</a>
<p style="margin:28px 0 0;font-size:12px;color:#8a85a0">You turned on email reminders in Digital Dash. <a href="${unsub}" style="color:#8a85a0">Stop email reminders</a></p></div>`;
  try {
    const res = await fetch("https://api.resend.com/emails", {
      method: "POST",
      headers: { Authorization: `Bearer ${env("RESEND_API_KEY")}`, "Content-Type": "application/json" },
      body: JSON.stringify({
        from: env("REMIND_FROM") || "Digital Dash <onboarding@resend.dev>",
        to: [to], subject, text, html,
        headers: { "List-Unsubscribe": `<${unsub}>`, "List-Unsubscribe-Post": "List-Unsubscribe=One-Click" },
      }),
    });
    await res.body?.cancel();
    return res.ok;
  } catch {
    return false;
  }
}

// Returns "ok", "stopped" (the person replied STOP, so texts must stop) or "error".
async function sendSms(to: string, body: string): Promise<"ok" | "stopped" | "error"> {
  const sid = env("TWILIO_ACCOUNT_SID"), from = env("TWILIO_FROM");
  const form = new URLSearchParams({ To: to, Body: body });
  form.set(from.startsWith("MG") ? "MessagingServiceSid" : "From", from);
  try {
    const res = await fetch(`https://api.twilio.com/2010-04-01/Accounts/${sid}/Messages.json`, {
      method: "POST",
      headers: { Authorization: "Basic " + btoa(`${sid}:${env("TWILIO_AUTH_TOKEN")}`), "Content-Type": "application/x-www-form-urlencoded" },
      body: form,
    });
    if (res.ok) { await res.body?.cancel(); return "ok"; }
    const err = await res.json().catch(() => ({}));
    return err?.code === 21610 ? "stopped" : "error";
  } catch {
    return "error";
  }
}
const smsText = (title: string, body: string) => {
  const tail = " Reply STOP to opt out.";
  let msg = `Digital Dash: ${title}${body ? ` (${body})` : ""}.`;
  if (msg.length + tail.length > 300) msg = msg.slice(0, 296 - tail.length) + "…";
  return msg + tail;
};

// Counts a message against today's limit; false when the limit is reached.
async function takeQuota(admin: SupabaseClient, uid: string, kind: "email" | "sms"): Promise<boolean> {
  const day = new Date().toISOString().slice(0, 10), cap = kind === "sms" ? SMS_DAILY : EMAIL_DAILY;
  const { data } = await admin.from("dash_msg_usage").select("email,sms").eq("user_id", uid).eq("day", day).maybeSingle();
  const used = data ? (data as Record<string, number>)[kind] : 0;
  if (used >= cap) return false;
  await admin.from("dash_msg_usage").upsert({ user_id: uid, day, email: (data?.email ?? 0) + (kind === "email" ? 1 : 0), sms: (data?.sms ?? 0) + (kind === "sms" ? 1 : 0) }, { onConflict: "user_id,day" });
  return true;
}

/* ---------- contacts ---------- */
async function getContact(admin: SupabaseClient, uid: string): Promise<Contact> {
  const { data } = await admin.from("dash_contacts").select("*").eq("user_id", uid).maybeSingle();
  if (data) return data as Contact;
  const { data: made } = await admin.from("dash_contacts").upsert({ user_id: uid }, { onConflict: "user_id" }).select("*").single();
  return made as Contact;
}
const secret = () => env("REMIND_SECRET") || env("CRON_SECRET");
async function hmac(text: string): Promise<string> {
  const key = await crypto.subtle.importKey("raw", new TextEncoder().encode(secret()), { name: "HMAC", hash: "SHA-256" }, false, ["sign"]);
  const sig = await crypto.subtle.sign("HMAC", key, new TextEncoder().encode(text));
  return [...new Uint8Array(sig)].map((b) => b.toString(16).padStart(2, "0")).join("");
}
// Accepts "519 555 1234", "(519) 555-1234", "+44 7700 900123"; numbers without a country code are North American.
function normPhone(raw: string): string | null {
  let s = String(raw || "").trim().replace(/[\s().\-]/g, "");
  if (/^\d{10}$/.test(s)) s = "+1" + s;
  else if (/^1\d{10}$/.test(s)) s = "+" + s;
  else if (s.startsWith("00")) s = "+" + s.slice(2);
  return /^\+[1-9]\d{7,14}$/.test(s) ? s : null;
}
const maskPhone = (p: string | null) => (p ? p.slice(0, p.length - 4).replace(/\d/g, "•") + p.slice(-4) : null);
function contactView(c: Contact, email: string | null) {
  return {
    email, email_on: c.email_on, phone: maskPhone(c.phone), phone_verified: !!c.phone_verified_at, sms_on: c.sms_on,
    pending: c.code_phone && c.code_expires && Date.parse(c.code_expires) > Date.now() ? maskPhone(c.code_phone) : null,
    can: { email: emailReady(), sms: smsReady() }, limits: { sms: SMS_DAILY, email: EMAIL_DAILY },
  };
}

const page = (title: string, body: string) =>
  new Response(`<!doctype html><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>${title}</title>
<body style="font-family:system-ui,sans-serif;background:#141220;color:#eeecf7;display:grid;place-items:center;min-height:100vh;margin:0;padding:16px">
<div style="max-width:420px;text-align:center"><h1 style="font-size:22px">${title}</h1><p style="color:#a9a4bf;line-height:1.5">${body}</p>
<p><a href="${APP}" style="color:#ffb547">Open Digital Dash</a></p></div></body>`, { headers: { "Content-Type": "text/html; charset=utf-8" } });

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response(null, { headers: corsHeaders });
  const url = new URL(req.url);
  const admin = createClient(env("SUPABASE_URL"), env("SUPABASE_SERVICE_ROLE_KEY"));
  const fnUrl = `${env("SUPABASE_URL")}/functions/v1/dash-push`;

  // Unsubscribe link in emails (GET from the link, POST from the mail app's one-click button).
  if (url.searchParams.get("action") === "unsub") {
    const u = url.searchParams.get("u") ?? "", t = url.searchParams.get("t") ?? "";
    if (/^[0-9a-f-]{36}$/.test(u) && /^[0-9a-f-]{36}$/.test(t)) {
      await admin.from("dash_contacts").update({ email_on: false, updated_at: new Date().toISOString() }).eq("user_id", u).eq("unsub_token", t);
    }
    return req.method === "POST" ? json({ ok: true }) : page("Email reminders are off", "You won't get any more reminder emails. You can turn them back on in Digital Dash, under Themes, Reminders.");
  }
  if (req.method !== "POST") return json({ error: "Use POST" }, 405);
  let body: any = {};
  try { body = await req.json(); } catch { /* empty body */ }

  if (body.action === "key") {
    if (!pushReady) return json({ error: "Reminders aren't set up on this site yet." }, 500);
    return json({ key: env("VAPID_PUBLIC_KEY") });
  }

  if (body.action === "run") {
    if (!env("CRON_SECRET") || req.headers.get("x-cron-secret") !== env("CRON_SECRET")) return json({ error: "Forbidden" }, 403);
    const now = Date.now();
    const { data: due, error } = await admin.from("dash_reminders")
      .select("id,user_id,at,title,body,tag,url,channels")
      .is("sent_at", null)
      .lte("at", new Date(now + 30_000).toISOString())
      .gte("at", new Date(now - 30 * 60_000).toISOString()) // skip anything more than 30 minutes stale
      .order("at").limit(500);
    if (error) return json({ error: error.message }, 500);
    // Mark first so an overlapping run can't send twice (reminders are keyed by user and id).
    const idsByUser = new Map<string, string[]>();
    for (const r of due ?? []) idsByUser.set(r.user_id, [...(idsByUser.get(r.user_id) ?? []), r.id]);
    for (const [uid, ids] of idsByUser) {
      await admin.from("dash_reminders").update({ sent_at: new Date().toISOString() }).eq("user_id", uid).in("id", ids);
    }
    const chans = (r: { channels?: string[] | null }) => r.channels ?? ["push"];
    const pushBy = new Map<string, Note[]>();
    for (const r of due ?? []) {
      if (!chans(r).includes("push")) continue;
      pushBy.set(r.user_id, [...(pushBy.get(r.user_id) ?? []), { title: r.title, body: r.body, tag: r.tag, url: r.url, at: Date.parse(r.at) }]);
    }
    let emails = 0, texts = 0;
    const direct = (due ?? []).filter((r) => chans(r).some((c) => c !== "push"));
    if (direct.length) {
      const uids = [...new Set(direct.map((r) => r.user_id))];
      const { data: cs } = await admin.from("dash_contacts").select("*").in("user_id", uids);
      const contacts = new Map((cs ?? []).map((c: Contact) => [c.user_id, c]));
      const emailOf = new Map<string, string>();
      for (const r of direct) {
        const c = contacts.get(r.user_id);
        if (!c) continue;
        if (chans(r).includes("email") && c.email_on && emailReady()) {
          if (!emailOf.has(r.user_id)) {
            const { data } = await admin.auth.admin.getUserById(r.user_id);
            emailOf.set(r.user_id, data?.user?.email ?? "");
          }
          const to = emailOf.get(r.user_id);
          if (to && await takeQuota(admin, r.user_id, "email") && await sendEmail(to, `Reminder: ${r.title}`, r.title, r.body, unsubUrl(fnUrl, c))) emails++;
        }
        if (chans(r).includes("sms") && c.sms_on && c.phone && c.phone_verified_at && smsReady()) {
          if (!(await takeQuota(admin, r.user_id, "sms"))) continue;
          const res = await sendSms(c.phone, smsText(r.title, r.body));
          if (res === "ok") texts++;
          else if (res === "stopped") { c.sms_on = false; await admin.from("dash_contacts").update({ sms_on: false }).eq("user_id", r.user_id); }
        }
      }
    }
    const result = pushBy.size ? await sendToUsers(admin, [...pushBy.keys()], pushBy) : { sent: 0, removed: 0 };
    await admin.from("dash_reminders").delete().lt("at", new Date(now - 2 * 86400_000).toISOString());
    return json({ due: due?.length ?? 0, ...result, emails, texts });
  }

  // Everything below needs a signed-in user.
  const auth = req.headers.get("Authorization");
  if (!auth) return json({ error: "Sign in first." }, 401);
  const asUser = createClient(env("SUPABASE_URL"), env("SUPABASE_ANON_KEY"), { global: { headers: { Authorization: auth } } });
  const { data: ud } = await asUser.auth.getUser();
  const user = ud?.user;
  if (!user) return json({ error: "Sign in first." }, 401);
  const uid = user.id;

  if (body.action === "test") {
    const note = { title: "Reminders are on", body: "This is how Digital Dash will nudge you.", tag: "test", url: "/digital-dash.html", at: Date.now() };
    const result = await sendToUsers(admin, [uid], new Map([[uid, [note]]]));
    if (!result.sent) return json({ error: "No device got it. Turn reminders off and on again on this device." }, 404);
    return json(result);
  }

  const c = await getContact(admin, uid);
  const save = (patch: Partial<Contact>) => admin.from("dash_contacts").update({ ...patch, updated_at: new Date().toISOString() }).eq("user_id", uid);

  switch (body.action) {
    case "contact":
      return json(contactView(c, user.email ?? null));

    case "email": {
      if (body.on && !emailReady()) return json({ error: "Email reminders aren't set up on this site yet." }, 400);
      if (body.on && !user.email) return json({ error: "Your account has no email address." }, 400);
      await save({ email_on: !!body.on });
      return json(contactView({ ...c, email_on: !!body.on }, user.email ?? null));
    }

    case "phone-start": {
      if (!smsReady()) return json({ error: "Text reminders aren't set up on this site yet." }, 400);
      const phone = normPhone(body.phone);
      if (!phone) return json({ error: "That doesn't look like a phone number. Include the area code, e.g. 519 555 1234." }, 400);
      const now = Date.now(), recent = (c.codes_sent ?? []).filter((t) => now - Date.parse(t) < 3600_000);
      if (recent.length >= 5) return json({ error: "Too many codes in the last hour. Try again later." }, 429);
      if (recent.length && now - Date.parse(recent[recent.length - 1]) < 45_000) return json({ error: "Wait a few seconds before asking for another code." }, 429);
      const code = String(crypto.getRandomValues(new Uint32Array(1))[0] % 1_000_000).padStart(6, "0");
      const sent = await sendSms(phone, `Your Digital Dash code is ${code}. It expires in 10 minutes. If you didn't ask for it, ignore this text.`);
      if (sent === "stopped") return json({ error: "This number replied STOP earlier. Text START to the number we text from, then try again." }, 400);
      if (sent !== "ok") return json({ error: "Couldn't text that number. Check it and try again." }, 502);
      await save({
        code_hash: await hmac(`${uid}:${phone}:${code}`), code_phone: phone, code_expires: new Date(now + 10 * 60_000).toISOString(),
        code_tries: 0, codes_sent: [...recent, new Date(now).toISOString()],
      });
      return json({ ok: true, pending: maskPhone(phone) });
    }

    case "phone-verify": {
      const code = String(body.code ?? "").replace(/\D/g, "");
      if (!c.code_hash || !c.code_phone || !c.code_expires || Date.parse(c.code_expires) < Date.now()) return json({ error: "That code expired. Send a new one." }, 400);
      if (c.code_tries >= 5) return json({ error: "Too many wrong codes. Send a new one." }, 429);
      if (code.length !== 6 || (await hmac(`${uid}:${c.code_phone}:${code}`)) !== c.code_hash) {
        await save({ code_tries: c.code_tries + 1 });
        return json({ error: "That code isn't right. Check the text and try again." }, 400);
      }
      const next = { phone: c.code_phone, phone_verified_at: new Date().toISOString(), sms_on: true, code_hash: null, code_phone: null, code_expires: null, code_tries: 0 };
      await save(next);
      return json(contactView({ ...c, ...next }, user.email ?? null));
    }

    case "phone-remove": {
      const next = { phone: null, phone_verified_at: null, sms_on: false, code_hash: null, code_phone: null, code_expires: null, code_tries: 0 };
      await save(next);
      return json(contactView({ ...c, ...next }, user.email ?? null));
    }

    case "sms": {
      if (body.on && !(c.phone && c.phone_verified_at)) return json({ error: "Add and verify your number first." }, 400);
      await save({ sms_on: !!body.on });
      return json(contactView({ ...c, sms_on: !!body.on }, user.email ?? null));
    }

    case "test-email": {
      if (!emailReady()) return json({ error: "Email reminders aren't set up on this site yet." }, 400);
      if (!c.email_on || !user.email) return json({ error: "Turn on email reminders first." }, 400);
      if (!(await takeQuota(admin, uid, "email"))) return json({ error: "You've reached today's email limit." }, 429);
      const ok = await sendEmail(user.email, "Email reminders are on", "Email reminders are on", "This is how Digital Dash will remind you about tasks.", unsubUrl(fnUrl, c));
      return ok ? json({ ok: true }) : json({ error: "The email didn't send. The site's email sender may need setting up." }, 502);
    }

    case "test-sms": {
      if (!smsReady()) return json({ error: "Text reminders aren't set up on this site yet." }, 400);
      if (!(c.sms_on && c.phone && c.phone_verified_at)) return json({ error: "Add and verify your number first." }, 400);
      if (!(await takeQuota(admin, uid, "sms"))) return json({ error: "You've reached today's text limit." }, 429);
      const r = await sendSms(c.phone, smsText("Text reminders are on", "this is how Digital Dash will remind you"));
      if (r === "stopped") { await save({ sms_on: false }); return json({ error: "This number replied STOP. Text START to turn texts back on." }, 400); }
      return r === "ok" ? json({ ok: true }) : json({ error: "The text didn't send. Try again in a minute." }, 502);
    }
  }

  return json({ error: "Unknown action" }, 400);
});
