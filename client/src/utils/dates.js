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
