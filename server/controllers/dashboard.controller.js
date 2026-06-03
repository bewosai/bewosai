import { Sale } from "../models/Sale.js";
import { Purchase } from "../models/Purchase.js";
import { Expense } from "../models/Expense.js";
import { Payment } from "../models/Payment.js";
import { Item } from "../models/Item.js";
import { asyncHandler } from "../utils/asyncHandler.js";
import { calcSaleProfit } from "../utils/calculations.js";

export const getDashboard = asyncHandler(async (req, res) => {
  const [sales, purchases, expenses, payments, items] = await Promise.all([
    Sale.find({ owner: req.user._id, deletedAt: null }),
    Purchase.find({ owner: req.user._id, deletedAt: null }),
    Expense.find({ owner: req.user._id, deletedAt: null }),
    Payment.find({ owner: req.user._id, deletedAt: null }),
    Item.find({ owner: req.user._id, deletedAt: null })
  ]);

  const totalSales = sales.reduce((s, x) => s + Number(x.totals?.grandTotal || 0), 0);
  const totalPurchases = purchases.reduce((s, x) => s + Number(x.totals?.grandTotal || 0), 0);
  const totalExpenses = expenses.reduce((s, x) => s + Number(x.amount || 0), 0);
  const paymentsReceived = payments.filter((x) => x.type === "in").reduce((s, x) => s + Number(x.amount || 0), 0);
  const paymentsSent = payments.filter((x) => x.type === "out").reduce((s, x) => s + Number(x.amount || 0), 0);

  const itemCostsMap = Object.fromEntries(items.map((x) => [String(x._id), Number(x.purchasePrice || 0)]));
  const grossProfit = sales.reduce(
    (s, sale) => s + calcSaleProfit({ saleItems: sale.items, itemCostsMap }).profit,
    0
  );

  const lowStock = items.filter((x) => Number(x.stockQty) <= Number(x.lowStockAlertAt || 0));

  res.json({
    totalSales,
    totalPurchases,
    totalExpenses,
    paymentsReceived,
    paymentsSent,
    grossProfit,
    netProfit: grossProfit - totalExpenses,
    stockValue: items.reduce((s, x) => s + Number(x.stockQty || 0) * Number(x.purchasePrice || 0), 0),
    lowStockCount: lowStock.length,
    lowStock
  });
});