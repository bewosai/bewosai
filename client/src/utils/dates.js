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


// A bare "YYYY-MM-DD" (a Django DateField — sale_date, expiry_date, ...) has no
// time or timezone of its own — parsing it with `new Date(str)` reads it as UTC
// midnight, which then renders as the *previous* day in any browser west of UTC.
// Extracted separately from a real timestamp (a DateTimeField), which does need
// converting to Nepal time to know which calendar day it falls on there.
// Anchored end-to-end: a timestamp ("2026-09-17T20:00:00Z") starts with the
// same shape and must NOT take this branch, or its time component (which can
// push it into the next Nepal day) is silently dropped.
const DATE_ONLY_RE = /^(\d{4})-(\d{2})-(\d{2})$/;

/** { y, mo, d } for [input] on the Nepal calendar — a date-only string is read
 * literally; anything else (a Date, or a full timestamp string) is converted to
 * Nepal time first. This is the one safe way to ask "which calendar day is this"
 * anywhere in the app. */
export function nepalYMD(input) {
  if (typeof input === "string") {
    const m = input.match(DATE_ONLY_RE);
    if (m) return { y: +m[1], mo: +m[2], d: +m[3] };
  }
  const date = input instanceof Date ? input : new Date(input);
  const parts = Object.fromEntries(nepalDate.formatToParts(date).map((p) => [p.type, p.value]));
  return { y: +parts.year, mo: +parts.month, d: +parts.day };
}

const AD_MONTHS_EN = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"];

/** "18 Sep 2026" for a date-only value or a timestamp, safe from the
 * date-only + toLocaleDateString timezone bug described above. */
export function formatDateOnly(input) {
  if (!input) return "—";
  const { y, mo, d } = nepalYMD(input);
  return `${String(d).padStart(2, "0")} ${AD_MONTHS_EN[mo - 1]} ${y}`;
}
