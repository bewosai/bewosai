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