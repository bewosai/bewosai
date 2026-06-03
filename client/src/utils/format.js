export const formatCurrency = (value) => {
  const num = Number(value || 0);
  return new Intl.NumberFormat("en-NP", {
    style: "currency",
    currency: "NPR",
    maximumFractionDigits: 2,
  }).format(num);
};

export const formatDate = (date) => {
  if (!date) return "-";
  return new Date(date).toLocaleDateString();
};

export const formatNumber = (value) => {
  return Number(value || 0).toLocaleString("en-NP");
};