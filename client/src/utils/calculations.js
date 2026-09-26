// Suggested price when a billing line's unit is switched between a
// product's primary and secondary unit (see inventory Unit model —
// conversion_factor: "1 primary = conversion_factor secondary", e.g.
// 1 Box = 12 Piece). Dividing the base price by the factor gives the
// per-secondary-unit price; picking the primary unit restores the base
// price. `basePrice` should be the product's sale_price or purchase_price
// (whichever this form bills), already resolved by the caller. When the
// product has its own price for the secondary unit (secondary_sale_price /
// secondary_purchase_price) pass it as `secondaryPrice` and it wins over the
// divided price. Returned value is only a starting point — the user can still
// edit it afterward.
export function priceForUnit(basePrice, unitDetail, unitLabel, secondaryPrice) {
  const base = parseFloat(basePrice || 0);
  const factor = parseFloat(unitDetail?.conversion_factor || 0);
  if (unitDetail && unitLabel && factor > 0 && unitLabel === unitDetail.secondary_unit) {
    const own = parseFloat(secondaryPrice);
    if (own > 0) return own;
    return Math.round((base / factor) * 100) / 100;
  }
  return base;
}

// Line discount typed either as a % of the line or as a rupee amount; always
// returns rupees, never negative and never more than the line itself.
export function lineDiscountAmount(gross, value, mode) {
  const g = Math.max(0, parseFloat(gross) || 0);
  const v = Math.max(0, parseFloat(value) || 0);
  const amount = mode === "percent" ? g * Math.min(100, v) / 100 : v;
  return Math.round(Math.min(amount, g) * 100) / 100;
}

export function calcPartyBalance({
  openingBalance = 0,
  totalSales = 0,
  totalPurchases = 0,
  totalPaymentsIn = 0,
  totalPaymentsOut = 0,
}) {
  const receivable = Number(openingBalance) + Number(totalSales) - Number(totalPaymentsIn);
  const payable = Number(totalPurchases) - Number(totalPaymentsOut);
  const net = receivable - payable;

  return {
    receivable,
    payable,
    net,
    direction:
      net > 0 ? "party_owes_you" : net < 0 ? "you_owe_party" : "settled",
  };
}