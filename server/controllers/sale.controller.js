import mongoose from "mongoose";
import { Sale } from "../models/Sale.js";
import { Item } from "../models/Item.js";
import { asyncHandler } from "../utils/asyncHandler.js";
import { calcDocumentTotals } from "../utils/calculations.js";
import { ApiError } from "../utils/ApiError.js";

export const createSale = asyncHandler(async (req, res) => {
  const {
    items,
    extraDiscount = 0,
    paid = 0,
    party = null,
    invoiceNo,
    invoiceDate,
    note = "",
    status = "sale",
  } = req.body;

  if (!invoiceNo || !String(invoiceNo).trim()) {
    throw new ApiError(400, "Invoice number is required");
  }

  if (!Array.isArray(items) || items.length === 0) {
    throw new ApiError(400, "Items required");
  }

  const itemIds = items.map((x) => x.item).filter(Boolean);

  const itemDocs = await Item.find({
    _id: { $in: itemIds },
    owner: req.user._id,
    deletedAt: null,
  });

  const itemMap = Object.fromEntries(itemDocs.map((x) => [String(x._id), x]));

  const prepared = items.map((row) => {
    const itemDoc = itemMap[String(row.item)];

    if (!itemDoc) {
      throw new ApiError(404, `Item not found: ${row.item}`);
    }

    const qty = Number(row.qty || 0);
    const price = Number(
      row.price !== undefined && row.price !== null ? row.price : itemDoc.salePrice || 0
    );
    const discount = Number(row.discount || 0);
    const taxRate = Number(row.taxRate || 0);

    if (qty <= 0) {
      throw new ApiError(400, `Invalid quantity for ${itemDoc.name}`);
    }

    if (price < 0) {
      throw new ApiError(400, `Invalid price for ${itemDoc.name}`);
    }

    if (status === "sale" && itemDoc.stockQty < qty) {
      throw new ApiError(400, `Not enough stock for ${itemDoc.name}`);
    }

    return {
      item: itemDoc._id,
      name: itemDoc.name,
      qty,
      price,
      discount,
      taxRate,
    };
  });

  const totals = calcDocumentTotals(prepared, extraDiscount, paid);

  if (status === "sale") {
    for (const row of prepared) {
      const itemDoc = itemMap[String(row.item)];
      itemDoc.stockQty -= row.qty;
      await itemDoc.save();
    }
  }

  const sale = await Sale.create({
    owner: req.user._id,
    party: party || null,
    invoiceNo: String(invoiceNo).trim(),
    invoiceDate: invoiceDate || new Date(),
    status,
    items: prepared,
    totals,
    note,
  });

  const populated = await Sale.findById(sale._id).populate("party");

  res.status(201).json({
    success: true,
    message: `${status} created successfully`,
    sale: populated,
  });
});

export const getSales = asyncHandler(async (req, res) => {
  const { type } = req.query;

  const filter = {
    owner: req.user._id,
    deletedAt: null,
  };

  if (type) {
    filter.status = type;
  }

  const docs = await Sale.find(filter).populate("party").sort({ createdAt: -1 });

  res.status(200).json({
    success: true,
    count: docs.length,
    sales: docs,
  });
});

export const getDeletedSales = asyncHandler(async (req, res) => {
  const docs = await Sale.find({
    owner: req.user._id,
    deletedAt: { $ne: null },
  })
    .populate("party")
    .sort({ deletedAt: -1 });

  res.status(200).json({
    success: true,
    count: docs.length,
    sales: docs,
  });
});

export const getSaleById = asyncHandler(async (req, res) => {
  if (!mongoose.Types.ObjectId.isValid(req.params.id)) {
    throw new ApiError(400, "Invalid sale id");
  }

  const sale = await Sale.findOne({
    _id: req.params.id,
    owner: req.user._id,
  }).populate("party");

  if (!sale) {
    throw new ApiError(404, "Sale not found");
  }

  res.status(200).json({
    success: true,
    sale,
  });
});

export const deleteSale = asyncHandler(async (req, res) => {
  const sale = await Sale.findOne({
    _id: req.params.id,
    owner: req.user._id,
    deletedAt: null,
  });

  if (!sale) {
    throw new ApiError(404, "Sale not found");
  }

  sale.deletedAt = new Date();
  await sale.save();

  res.status(200).json({
    success: true,
    message: "Moved to recycle bin",
  });
});

export const restoreSale = asyncHandler(async (req, res) => {
  const sale = await Sale.findOne({
    _id: req.params.id,
    owner: req.user._id,
    deletedAt: { $ne: null },
  });

  if (!sale) {
    throw new ApiError(404, "Sale not found in recycle bin");
  }

  sale.deletedAt = null;
  await sale.save();

  res.status(200).json({
    success: true,
    message: "Sale restored successfully",
  });
});

export const forceDeleteSale = asyncHandler(async (req, res) => {
  const sale = await Sale.findOne({
    _id: req.params.id,
    owner: req.user._id,
  });

  if (!sale) {
    throw new ApiError(404, "Sale not found");
  }

  await Sale.deleteOne({ _id: sale._id });

  res.status(200).json({
    success: true,
    message: "Sale permanently deleted",
  });
});

export const addPaymentIn = asyncHandler(async (req, res) => {
  const { amount } = req.body;

  const sale = await Sale.findOne({
    _id: req.params.id,
    owner: req.user._id,
    deletedAt: null,
  });

  if (!sale) {
    throw new ApiError(404, "Sale not found");
  }

  const amt = Number(amount || 0);

  if (amt <= 0) {
    throw new ApiError(400, "Valid payment amount is required");
  }

  sale.totals.paid = Number(sale.totals.paid || 0) + amt;
  sale.totals.due = Math.max(0, Number(sale.totals.grandTotal || 0) - sale.totals.paid);

  await sale.save();

  res.status(200).json({
    success: true,
    message: "Payment added successfully",
    sale,
  });
});

export const createSalesReturn = asyncHandler(async (req, res) => {
  const original = await Sale.findOne({
    _id: req.params.id,
    owner: req.user._id,
    deletedAt: null,
    status: "sale",
  });

  if (!original) {
    throw new ApiError(404, "Original sale not found");
  }

  const returnItems = req.body.items || [];

  if (!Array.isArray(returnItems) || returnItems.length === 0) {
    throw new ApiError(400, "Return items required");
  }

  const prepared = [];
  for (const row of returnItems) {
    const originalRow = original.items.find((x) => String(x.item) === String(row.item));

    if (!originalRow) {
      throw new ApiError(400, "Returned item not found in original sale");
    }

    const qty = Number(row.qty || 0);

    if (qty <= 0 || qty > originalRow.qty) {
      throw new ApiError(400, `Invalid return quantity for ${originalRow.name}`);
    }

    prepared.push({
      item: originalRow.item,
      name: originalRow.name,
      qty,
      price: originalRow.price,
      discount: originalRow.discount || 0,
      taxRate: originalRow.taxRate || 0,
    });

    const itemDoc = await Item.findOne({
      _id: originalRow.item,
      owner: req.user._id,
      deletedAt: null,
    });

    if (itemDoc) {
      itemDoc.stockQty += qty;
      await itemDoc.save();
    }
  }

  const totals = calcDocumentTotals(prepared, 0, 0);

  const saleReturn = await Sale.create({
    owner: req.user._id,
    party: original.party || null,
    invoiceNo: `${original.invoiceNo}-RET`,
    invoiceDate: new Date(),
    status: "returned",
    items: prepared,
    totals,
    note: `Sales return against ${original.invoiceNo}`,
  });

  res.status(201).json({
    success: true,
    message: "Sales return created successfully",
    sale: saleReturn,
  });
});