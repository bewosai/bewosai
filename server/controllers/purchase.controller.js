import { Purchase } from "../models/Purchase.js";
import { Item } from "../models/Item.js";
import { RecycleBin } from "../models/RecycleBin.js";
import { asyncHandler } from "../utils/asyncHandler.js";
import { calcDocumentTotals } from "../utils/calculations.js";
import { ApiError } from "../utils/ApiError.js";

export const createPurchase = asyncHandler(async (req, res) => {
  const { items, extraDiscount = 0, paid = 0, party, billNo, billDate, note } = req.body;

  const itemDocs = await Item.find({
    _id: { $in: items.map((x) => x.item) },
    owner: req.user._id,
    deletedAt: null
  });

  const itemMap = Object.fromEntries(itemDocs.map((x) => [String(x._id), x]));

  const prepared = items.map((row) => {
    const item = itemMap[String(row.item)];
    if (!item) throw new ApiError(404, "Item not found");

    return {
      item: row.item,
      name: item.name,
      qty: Number(row.qty),
      price: Number(row.price ?? item.purchasePrice ?? 0),
      discount: Number(row.discount || 0),
      taxRate: Number(row.taxRate ?? item.taxRate ?? 0)
    };
  });

  const totals = calcDocumentTotals(prepared, extraDiscount, paid);

  for (const row of prepared) {
    const item = itemMap[String(row.item)];
    item.stockQty = Number(item.stockQty || 0) + Number(row.qty || 0);
    item.purchasePrice = Number(row.price || item.purchasePrice || 0);
    await item.save();
  }

  const doc = await Purchase.create({
    owner: req.user._id,
    party,
    billNo,
    billDate,
    items: prepared,
    totals,
    note
  });

  res.status(201).json(doc);
});

export const getPurchases = asyncHandler(async (req, res) => {
  const docs = await Purchase.find({ owner: req.user._id, deletedAt: null }).populate("party").sort({ createdAt: -1 });
  res.json(docs);
});

export const deletePurchase = asyncHandler(async (req, res) => {
  const doc = await Purchase.findOne({ _id: req.params.id, owner: req.user._id, deletedAt: null });
  doc.deletedAt = new Date();
  await doc.save();
  await RecycleBin.create({ owner: req.user._id, entityType: "purchase", entityId: doc._id, data: doc.toObject() });
  res.json({ message: "Purchase moved to recycle bin" });
});