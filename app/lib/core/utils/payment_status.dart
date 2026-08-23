/// Derives a bill's payment status from its own total/paid amounts — there's
/// no separate stored field for this, mirrors the same derivation used on
/// the web client (client/src/utils/paymentStatus.js).
String paymentStatus({required double total, required double paid}) {
  if (total <= 0 || paid >= total) return 'PAID';
  if (paid > 0) return 'PARTIAL';
  return 'UNPAID';
}
