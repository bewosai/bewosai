export const formatCurrency = (value) => {
  const num = Number(value || 0);
  return new Intl.NumberFormat("en-NP", {
    style: "currency",
    currency: "NPR",
    maximumFractionDigits: 2,
  }).format(num);
};

import { formatDateOnly } from "./dates";

export const formatDate = (date) => {
  if (!date) return "-";
  // Reads the Nepal calendar day, not the browser's own — see utils/dates.js.
  return formatDateOnly(date);
};

export const formatNumber = (value) => {
  return Number(value || 0).toLocaleString("en-NP");
};