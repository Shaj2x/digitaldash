// Copies public/ into dist/ and writes dist/digital-dash-config.js from the Supabase env vars.
// Only the publishable key goes in; row level security keeps each user's data private.
import { cpSync, rmSync, writeFileSync } from "node:fs";

const url = process.env.VITE_SUPABASE_URL || "";
const key = process.env.VITE_SUPABASE_PUBLISHABLE_KEY || "";
if (/^sb_secret_/.test(key)) {
  console.error("VITE_SUPABASE_PUBLISHABLE_KEY is a secret key. Use the publishable (or anon) key instead.");
  process.exit(1);
}

rmSync("dist", { recursive: true, force: true });
cpSync("public", "dist", { recursive: true });
writeFileSync("dist/digital-dash-config.js", `window.DASH_CONFIG=${JSON.stringify({ supabaseUrl: url, supabaseKey: key })};`);
console.log(url ? `Built dist/ for ${url}` : "Built dist/ without Supabase settings (accounts stay off)");
