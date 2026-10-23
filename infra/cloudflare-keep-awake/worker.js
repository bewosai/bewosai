/*
 * Keeps the Render backend awake so nobody waits 30-60 s for it to start.
 *
 * Render's free plan stops the backend after 15 minutes without a request;
 * GitHub's scheduled "Keep backend awake" job is supposed to run every 5
 * minutes but GitHub actually runs it only every few hours. Cloudflare runs
 * this on time.
 *
 * Set up (Cloudflare dashboard, free plan):
 *   1. Workers & Pages -> Create -> Create Worker -> name it "bewosai-keep-awake" -> Deploy.
 *   2. Edit code -> replace everything with this file -> Deploy.
 *   3. Settings -> Triggers -> Cron Triggers -> Add -> "*/10 * * * *" -> Add.
 *
 * It pings "/", which doesn't touch the database, so Neon can still sleep.
 * Render's free 750 hours a month cover one service running all month.
 */
const BACKEND = "https://bewosai-backend-0esi.onrender.com/";

export default {
  async scheduled(event, env, ctx) {
    ctx.waitUntil(fetch(BACKEND, { headers: { "User-Agent": "bewosai-keep-awake" } }));
  },
  // Opening the worker's URL in a browser pings once too, to check it works.
  async fetch() {
    const started = Date.now();
    const res = await fetch(BACKEND, { headers: { "User-Agent": "bewosai-keep-awake" } });
    return new Response(`Backend answered ${res.status} in ${Date.now() - started} ms`);
  },
};
