import { Expense } from "../models/Expense.js";
import { RecycleBin } from "../models/RecycleBin.js";
import { asyncHandler } from "../utils/asyncHandler.js";

export const createExpense = asyncHandler(async (req, res) => {
  const doc = await Expense.create({ ...req.body, owner: req.user._id });
  res.status(201).json(doc);
});

export const getExpenses = asyncHandler(async (req, res) => {
  const docs = await Expense.find({ owner: req.user._id, deletedAt: null }).sort({ createdAt: -1 });
  res.json(docs);
});

export const deleteExpense = asyncHandler(async (req, res) => {
  const doc = await Expense.findOne({ _id: req.params.id, owner: req.user._id, deletedAt: null });
  doc.deletedAt = new Date();
  await doc.save();
  await RecycleBin.create({ owner: req.user._id, entityType: "expense", entityId: doc._id, data: doc.toObject() });
  res.json({ message: "Expense moved to recycle bin" });
});