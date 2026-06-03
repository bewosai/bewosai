import { Sale } from "../models/Sale.js";
import { Purchase } from "../models/Purchase.js";
import { Expense } from "../models/Expense.js";
import { Payment } from "../models/Payment.js";
import { Item } from "../models/Item.js";
import { asyncHandler } from "../utils/asyncHandler.js";

export const getSummaryReport = asyncHandler(async (req, res) => {
  const { from, to } = req.query;
  const dateFilter = {};
  if (from || to) {
    dateFilter.$gte = from ? new Date(from) : new Date("2000-01-01");
    dateFilter.$lte = to ? new Date(to) : new Date();
  }

  const [sales, purchases, expenses, payments, items] = await Promise.all([
    Sale.find({ owner: req.user._id, deletedAt: null, ...(from || to ? { invoiceDate: dateFilter } : {}) }),
    Purchase.find({ owner: req.user._id, deletedAt: null, ...(from || to ? { billDate: dateFilter } : {}) }),
    Expense.find({ owner: req.user._id, deletedAt: null, ...(from || to ? { expenseDate: dateFilter } : {}) }),
    Payment.find({ owner: req.user._id, deletedAt: null, ...(from || to ? { paymentDate: dateFilter } : {}) }),
    Item.find({ owner: req.user._id, deletedAt: null })
  ]);

  res.json({
    salesCount: sales.length,
    purchaseCount: purchases.length,
    expenseCount: expenses.length,
    paymentCount: payments.length,
    totalSales: sales.reduce((s, x) => s + Number(x.totals?.grandTotal || 0), 0),
    totalPurchases: purchases.reduce((s, x) => s + Number(x.totals?.grandTotal || 0), 0),
    totalExpenses: expenses.reduce((s, x) => s + Number(x.amount || 0), 0),
    totalReceipts: payments.filter((x) => x.type === "in").reduce((s, x) => s + Number(x.amount || 0), 0),
    totalPaymentsOut: payments.filter((x) => x.type === "out").reduce((s, x) => s + Number(x.amount || 0), 0),
    stockValue: items.reduce((s, x) => s + Number(x.stockQty || 0) * Number(x.purchasePrice || 0), 0)
  });
});