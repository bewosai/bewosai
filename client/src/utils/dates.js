// Business dates follow Nepal time (Asia/Kathmandu, UTC+5:45, no daylight
// saving) no matter what timezone the browser is set to.
//
// Don't build "today" with `new Date().toISOString().slice(0, 10)`: that's the
// UTC date, which is still *yesterday* between midnight and ~5:45 AM in Nepal,
// so new invoices/expenses/purchases would default to the previous day.

export const NEPAL_TZ = "Asia/Kathmandu";

// "en-CA" formats as YYYY-MM-DD.
const nepalDate = new Intl.DateTimeFormat("en-CA", {
  timeZone: NEPAL_TZ,
  year: "numeric",
  month: "2-digit",
  day: "2-digit",
});

/** YYYY-MM-DD for [d] (default: now) on the Nepal calendar. */
export const dateStr = (d = new Date()) => nepalDate.format(d);

/** Today's date in Nepal, YYYY-MM-DD. */
export const todayStr = () => dateStr();

/** YYYY-MM for [d] (default: now) in Nepal. */
export const monthStr = (d = new Date()) => dateStr(d).slice(0, 7);

const nepalDateTime = new Intl.DateTimeFormat("en-GB", {
  timeZone: NEPAL_TZ,
  day: "2-digit",
  month: "short",
  year: "numeric",
  hour: "numeric",
  minute: "2-digit",
  hour12: true,
});

/** "18 Sep 2026, 8:47 pm" for a timestamp, shown in Nepal time whatever the browser's timezone. */
export const formatNepalDateTime = (value) => (value ? nepalDateTime.format(new Date(value)) : "—");

/** "Just now", "5 min ago", "3 hr ago", "2 days ago" — or the full Nepal date once it's over a month old. */
export function timeAgo(value, now = Date.now()) {
  if (!value) return "Never";
  const secs = Math.max(0, Math.round((now - new Date(value).getTime()) / 1000));
  if (secs < 60) return "Just now";
  const mins = Math.floor(secs / 60);
  if (mins < 60) return `${mins} min ago`;
  const hrs = Math.floor(mins / 60);
  if (hrs < 24) return `${hrs} hr ago`;
  const days = Math.floor(hrs / 24);
  if (days < 30) return `${days} day${days > 1 ? "s" : ""} ago`;
  return formatNepalDateTime(value);
}
