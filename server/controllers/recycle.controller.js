import { RecycleBin } from "../models/RecycleBin.js";
import { Party } from "../models/Party.js";
import { Item } from "../models/Item.js";
import { Sale } from "../models/Sale.js";
import { Purchase } from "../models/Purchase.js";
import { Payment } from "../models/Payment.js";
import { Expense } from "../models/Expense.js";
import { asyncHandler } from "../utils/asyncHandler.js";

const modelMap = {
  party: Party,
  item: Item,
  sale: Sale,
  purchase: Purchase,
  payment: Payment,
  expense: Expense
};

export const getRecycleItems = asyncHandler(async (req, res) => {
  const docs = await RecycleBin.find({ owner: req.user._id }).sort({ deletedAt: -1 });
  res.json(docs);
});

export const restoreRecycleItem = asyncHandler(async (req, res) => {
  const doc = await RecycleBin.findOne({ _id: req.params.id, owner: req.user._id });
  const Model = modelMap[doc.entityType];
  await Model.findByIdAndUpdate(doc.entityId, { deletedAt: null });
  await doc.deleteOne();
  res.json({ message: "Restored successfully" });
});

export const deleteRecycleItemForever = asyncHandler(async (req, res) => {
  const doc = await RecycleBin.findOne({ _id: req.params.id, owner: req.user._id });
  const Model = modelMap[doc.entityType];
  await Model.findByIdAndDelete(doc.entityId);
  await doc.deleteOne();
  res.json({ message: "Deleted forever" });
});