export function round2(n) {
  return Number(Number(n || 0).toFixed(2));
}

export function calcLine({ qty, price, discount = 0, taxRate = 0 }) {
  const quantity = Number(qty || 0);
  const unitPrice = Number(price || 0);
  const lineBase = quantity * unitPrice;
  const lineDiscount = Number(discount || 0);
  const taxable = Math.max(0, lineBase - lineDiscount);
  const tax = taxable * (Number(taxRate || 0) / 100);
  const total = taxable + tax;

  return {
    qty: round2(quantity),
    price: round2(unitPrice),
    base: round2(lineBase),
    discount: round2(lineDiscount),
    taxable: round2(taxable),
    taxRate: round2(taxRate),
    tax: round2(tax),
    total: round2(total),
  };
}

export function calcDocumentTotals(items = [], extraDiscount = 0, previousPaid = 0) {
  const lines = items.map(calcLine);

  const subtotal = lines.reduce((s, x) => s + x.base, 0);
  const itemDiscount = lines.reduce((s, x) => s + x.discount, 0);
  const taxable = lines.reduce((s, x) => s + x.taxable, 0);
  const tax = lines.reduce((s, x) => s + x.tax, 0);

  const grandBeforeExtra = taxable + tax;
  const extra = Number(extraDiscount || 0);
  const grandTotal = Math.max(0, grandBeforeExtra - extra);
  const paid = Number(previousPaid || 0);
  const due = Math.max(0, grandTotal - paid);

  return {
    lines,
    subtotal: round2(subtotal),
    itemDiscount: round2(itemDiscount),
    taxable: round2(taxable),
    tax: round2(tax),
    extraDiscount: round2(extra),
    grandTotal: round2(grandTotal),
    paid: round2(paid),
    due: round2(due),
  };
}

export function calcPartyBalance({
  openingBalance = 0,
  totalSales = 0,
  totalPurchases = 0,
  totalPaymentsIn = 0,
  totalPaymentsOut = 0,
}) {
  const receivable =
    Number(openingBalance) + Number(totalSales) - Number(totalPaymentsIn);

  const payable = Number(totalPurchases) - Number(totalPaymentsOut);

  return {
    receivable: round2(receivable),
    payable: round2(payable),
    net: round2(receivable - payable),
  };
}

export function calcSaleProfit({ saleItems = [], itemCostsMap = {} }) {
  let revenue = 0;
  let cost = 0;

  for (const row of saleItems) {
    const line = calcLine(row);
    revenue += Number(line.total || 0);

    const avgCost = Number(itemCostsMap[String(row.item)] || 0);
    cost += avgCost * Number(row.qty || 0);
  }

  return {
    revenue: round2(revenue),
    cost: round2(cost),
    profit: round2(revenue - cost),
  };
}

export function calcSimpleTotals(items = [], discount = 0, paid = 0) {
  const subtotal = items.reduce(
    (sum, x) => sum + Number(x.qty || 0) * Number(x.price || 0),
    0
  );

  const grandTotal = Math.max(0, subtotal - Number(discount || 0));
  const due = Math.max(0, grandTotal - Number(paid || 0));

  return {
    subtotal: round2(subtotal),
    discount: round2(discount),
    grandTotal: round2(grandTotal),
    paid: round2(paid),
    due: round2(due),
  };
}