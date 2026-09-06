export const PAYMENT_METHODS = [
  { value: "CASH",         label: "Cash" },
  { value: "BANK",         label: "Bank Transfer" },
  { value: "ESEWA",        label: "eSewa" },
  { value: "KHALTI",       label: "Khalti" },
  { value: "IME_PAY",      label: "IME Pay" },
  { value: "MOBILE",       label: "Mobile Banking" },
  { value: "CHEQUE",       label: "Cheque" },
  { value: "CREDIT",       label: "Credit" },
  { value: "SPLIT",        label: "Split (Cash + Bank)" },
];

export const PAYMENT_METHOD_LABELS = Object.fromEntries(
  PAYMENT_METHODS.map(m => [m.value, m.label])
);

export const SALE_STATUS = {
  CONFIRMED: { label: "Confirmed", cls: "bg-green-500/10 text-green-400 border-green-500/20" },
  DRAFT:     { label: "Draft",     cls: "bg-navy-700/50 text-navy-400 border-navy-700" },
  OVERDUE:   { label: "Overdue",   cls: "bg-red-500/10 text-red-400 border-red-500/20" },
  PARTIAL:   { label: "Partial",   cls: "bg-orange-500/10 text-orange-400 border-orange-500/20" },
  PAID:      { label: "Paid",      cls: "bg-green-500/10 text-green-400 border-green-500/20" },
  CANCELLED: { label: "Cancelled", cls: "bg-red-500/10 text-red-400 border-red-500/20" },
  SENT:      { label: "Sent",      cls: "bg-blue-500/10 text-blue-400 border-blue-500/20" },
  ACCEPTED:  { label: "Accepted",  cls: "bg-green-500/10 text-green-400 border-green-500/20" },
  REJECTED:  { label: "Rejected",  cls: "bg-red-500/10 text-red-400 border-red-500/20" },
};

export const STOCK_MOVEMENT_TYPES = [
  { value: "IN",          label: "Stock In",      color: "text-green-400" },
  { value: "OUT",         label: "Stock Out",     color: "text-red-400" },
  { value: "ADJUSTMENT",  label: "Adjustment",    color: "text-blue-400" },
  { value: "OPENING",     label: "Opening Stock", color: "text-orange-400" },
  { value: "DAMAGE",      label: "Damage",        color: "text-red-500" },
  { value: "LOST",        label: "Lost",          color: "text-red-400" },
  { value: "TRANSFER",    label: "Transfer",      color: "text-purple-400" },
];

export const PARTY_TYPE_META = {
  CUSTOMER: { label: "Customer", color: "text-green-400 bg-green-500/10 border-green-500/20" },
  SUPPLIER: { label: "Supplier", color: "text-blue-400 bg-blue-500/10 border-blue-500/20"   },
  BOTH:     { label: "Both",     color: "text-orange-400 bg-orange-500/10 border-orange-500/20" },
};

export const CUSTOMER_TYPES = ["RETAIL", "WHOLESALE", "DISTRIBUTOR", "RESELLER"];

export const EXPENSE_CATEGORIES = [
  "Rent", "Salary", "Transport", "Fuel", "Internet",
  "Electricity", "Marketing", "Office", "Miscellaneous",
];

export const CURRENCY = "Rs.";

export const INPUT_CLS =
  "w-full rounded-xl border border-navy-700 bg-navy-950 px-3 py-2.5 text-sm text-white outline-none placeholder:text-navy-500 focus:border-orange-500 transition";

export const LABEL_CLS = "mb-1 block text-xs font-semibold text-navy-400";
