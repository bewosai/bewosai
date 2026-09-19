/**
 * AD ↔ BS (Bikram Sambat) date conversion.
 * Reference: BS 2081 Baishakh 1 = AD 2024 April 13
 */
import { nepalYMD } from "./dates";

// Days in each BS month per year [Baishakh … Chaitra].
// Source: medic/bikram-sambat (github.com/medic/bikram-sambat), cross-checked
// against independently reported real-world anchor dates (BS 2082 Baishakh 1
// = Apr 14 2025, BS 2083 Baishakh 1 = Apr 14 2026) — the previous table here
// was internally self-consistent but wrong by a day in several years (e.g.
// it computed BS 2083 Baishakh 1 as Apr 13, 2026 instead of the correct
// Apr 14), which silently mis-displayed every BS date from ~2081 onward.
const BS_MONTH_DAYS = {
  2077: [31, 32, 31, 32, 31, 30, 30, 30, 29, 30, 29, 31],
  2078: [31, 31, 31, 32, 31, 31, 30, 29, 30, 29, 30, 30],
  2079: [31, 31, 32, 31, 31, 31, 30, 29, 30, 29, 30, 30],
  2080: [31, 32, 31, 32, 31, 30, 30, 30, 29, 29, 30, 30],
  2081: [31, 32, 31, 32, 31, 30, 30, 30, 29, 30, 29, 31],
  2082: [31, 31, 32, 31, 31, 31, 30, 29, 30, 29, 30, 30],
  2083: [31, 31, 32, 31, 31, 31, 30, 29, 30, 29, 30, 30],
  2084: [31, 31, 32, 31, 31, 30, 30, 30, 29, 30, 30, 30],
  2085: [31, 32, 31, 32, 30, 31, 30, 30, 29, 30, 30, 30],
  2086: [30, 32, 31, 32, 31, 30, 30, 30, 29, 30, 30, 30],
  2087: [31, 31, 32, 31, 31, 31, 30, 30, 29, 30, 30, 30],
  2088: [30, 31, 32, 32, 30, 31, 30, 30, 29, 30, 30, 30],
  2089: [30, 32, 31, 32, 31, 30, 30, 30, 29, 30, 30, 30],
  2090: [30, 32, 31, 32, 31, 30, 30, 30, 29, 30, 30, 30],
};

// Reference point: 2081/1/1 BS = April 13, 2024 AD
const REF_BS = { year: 2081, month: 1, day: 1 };
const REF_AD = new Date(2024, 3, 13); // month is 0-indexed

export const BS_MONTH_NAMES_EN = [
  "Baishakh", "Jestha", "Ashadh", "Shrawan", "Bhadra", "Ashwin",
  "Kartik", "Mangsir", "Poush", "Magh", "Falgun", "Chaitra",
];

export const BS_MONTH_NAMES_NE = [
  "बैशाख", "जेठ", "असार", "साउन", "भदौ", "असोज",
  "कार्तिक", "मंसिर", "पुष", "माघ", "फागुन", "चैत",
];

function daysInBSMonth(year, month) {
  return BS_MONTH_DAYS[year]?.[month - 1] ?? 30;
}

/** Convert AD Date (or a date-only/timestamp string) → BS { year, month, day }.
 *
 * A `Date` object here is always a synthetic calendar placeholder — every
 * caller in this codebase builds one with `new Date(y, m-1, d)` (e.g. the
 * date picker's own grid, or `parseISO`), so its *local* fields already are
 * the intended Y/M/D; there is no real-world instant to convert.
 *
 * A string is different: it's real data from the server (a date-only value
 * or a full timestamp), so it goes through dates.js's nepalYMD, which reads
 * the Nepal calendar day rather than the browser's local one — a UTC
 * timestamp read with plain getFullYear()/getMonth() would give the wrong
 * BS date for anyone outside Nepal's own timezone, or within ~6 hours of
 * midnight even inside it. Pass the raw string, not `new Date(str)`, when
 * converting a real timestamp for exactly this reason. */
export function adToBS(adDate) {
  const { y, mo, d } = adDate instanceof Date
    ? { y: adDate.getFullYear(), mo: adDate.getMonth() + 1, d: adDate.getDate() }
    : nepalYMD(adDate);
  const input = new Date(y, mo - 1, d);
  const diffMs = input - REF_AD;
  let diffDays = Math.round(diffMs / 86400000);

  let { year, month, day } = REF_BS;

  if (diffDays >= 0) {
    while (diffDays > 0) {
      const daysInMonth = daysInBSMonth(year, month);
      const remaining = daysInMonth - day;
      if (diffDays <= remaining) {
        day += diffDays;
        diffDays = 0;
      } else {
        diffDays -= remaining + 1;
        day = 1;
        month++;
        if (month > 12) { month = 1; year++; }
      }
    }
  } else {
    diffDays = -diffDays;
    while (diffDays > 0) {
      if (diffDays < day) {
        day -= diffDays;
        diffDays = 0;
      } else {
        diffDays -= day;
        month--;
        if (month < 1) { month = 12; year--; }
        day = daysInBSMonth(year, month);
      }
    }
  }

  return { year, month, day };
}

/** Convert BS { year, month, day } → AD Date */
export function bsToAD(bsYear, bsMonth, bsDay) {
  const { year: ry, month: rm, day: rd } = REF_BS;
  let diffDays = 0;

  // Count days from REF_BS to target BS date
  let y = ry, m = rm, d = rd;

  if (bsYear > ry || (bsYear === ry && bsMonth > rm) || (bsYear === ry && bsMonth === rm && bsDay >= rd)) {
    // Forward
    while (!(y === bsYear && m === bsMonth && d === bsDay)) {
      diffDays++;
      d++;
      if (d > daysInBSMonth(y, m)) { d = 1; m++; }
      if (m > 12) { m = 1; y++; }
    }
  } else {
    // Backward
    while (!(y === bsYear && m === bsMonth && d === bsDay)) {
      diffDays--;
      d--;
      if (d < 1) { m--; if (m < 1) { m = 12; y--; } d = daysInBSMonth(y, m); }
    }
  }

  const result = new Date(REF_AD);
  result.setDate(result.getDate() + diffDays);
  return result;
}

/** Format BS date as string */
export function formatBS(bsDate, lang = "en") {
  const names = lang === "ne" ? BS_MONTH_NAMES_NE : BS_MONTH_NAMES_EN;
  return `${bsDate.year} ${names[bsDate.month - 1]} ${bsDate.day}`;
}

/** Get all BS dates in a BS month as AD dates (for calendar rendering) */
export function getBSMonthADDates(bsYear, bsMonth) {
  const days = daysInBSMonth(bsYear, bsMonth);
  const dates = [];
  for (let d = 1; d <= days; d++) {
    dates.push({ bsDay: d, adDate: bsToAD(bsYear, bsMonth, d) });
  }
  return dates;
}

/** BS week day of the first day of a BS month (0=Sun) */
export function bsMonthStartWeekday(bsYear, bsMonth) {
  const firstAD = bsToAD(bsYear, bsMonth, 1);
  return firstAD.getDay();
}

export const NEPALI_DIGITS = ["०", "१", "२", "३", "४", "५", "६", "७", "८", "९"];

export function toNepaliDigits(num) {
  return String(num)
    .split("")
    .map((c) => (c >= "0" && c <= "9" ? NEPALI_DIGITS[parseInt(c)] : c))
    .join("");
}
