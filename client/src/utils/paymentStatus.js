/**
 * Derives a bill's payment status from its own paid/due amounts — there's
 * no separate stored field for this, it's always computed the same way
 * wherever a Sale or Purchase needs to show or filter by it.
 */
export function paymentStatus(item) {
  const total = parseFloat(item.total ?? item.total_amount ?? 0);
  const paid = parseFloat(item.paid_amount ?? 0);
  if (total <= 0 || paid >= total) return "PAID";
  if (paid > 0) return "PARTIAL";
  return "UNPAID";
}

export const PAYMENT_STATUS_META = {
  PAID:    { label: "Paid",    color: "bg-green-500/10 text-green-400" },
  PARTIAL: { label: "Partial", color: "bg-yellow-500/10 text-yellow-400" },
  UNPAID:  { label: "Unpaid",  color: "bg-red-500/10 text-red-400" },
};
