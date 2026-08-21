const ONES = [
  "", "One", "Two", "Three", "Four", "Five", "Six", "Seven", "Eight", "Nine",
  "Ten", "Eleven", "Twelve", "Thirteen", "Fourteen", "Fifteen", "Sixteen",
  "Seventeen", "Eighteen", "Nineteen",
];
const TENS = [
  "", "", "Twenty", "Thirty", "Forty", "Fifty", "Sixty", "Seventy", "Eighty", "Ninety",
];

// Below 1000 — the one place ones/tens/hundreds combine before switching to
// the lakh/crore grouping used for everything above it.
function belowThousand(n) {
  if (n === 0) return "";
  if (n < 20) return ONES[n];
  if (n < 100) return TENS[Math.floor(n / 10)] + (n % 10 ? " " + ONES[n % 10] : "");
  return ONES[Math.floor(n / 100)] + " Hundred" + (n % 100 ? " " + belowThousand(n % 100) : "");
}

/**
 * Spells out a rupee amount the way a Nepali/Indian bill does — grouped by
 * thousand/lakh/crore (not the Western million/billion split), e.g.
 * 1,234,567 → "Twelve Lakh Thirty Four Thousand Five Hundred Sixty Seven".
 * Rounds to the nearest rupee; paisa isn't printed on a bill.
 */
export function amountInWords(amount, { currency = "Rupees", onlySuffix = "Only" } = {}) {
  const n = Math.round(Math.abs(Number(amount) || 0));
  if (n === 0) return `Zero ${currency} ${onlySuffix}`;

  const crore = Math.floor(n / 10000000);
  const lakh = Math.floor((n % 10000000) / 100000);
  const thousand = Math.floor((n % 100000) / 1000);
  const rest = n % 1000;

  const parts = [];
  if (crore) parts.push(`${belowThousand(crore)} Crore`);
  if (lakh) parts.push(`${belowThousand(lakh)} Lakh`);
  if (thousand) parts.push(`${belowThousand(thousand)} Thousand`);
  if (rest) parts.push(belowThousand(rest));

  return `${parts.join(" ")} ${currency} ${onlySuffix}`.trim();
}
