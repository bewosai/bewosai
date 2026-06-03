import { Payment } from "../models/Payment.js";
import { RecycleBin } from "../models/RecycleBin.js";
import { asyncHandler } from "../utils/asyncHandler.js";

export const createPayment = asyncHandler(async (req, res) => {
  const doc = await Payment.create({ ...req.body, owner: req.user._id });
  res.status(201).json(doc);
});

export const getPayments = asyncHandler(async (req, res) => {
  const docs = await Payment.find({ owner: req.user._id, deletedAt: null }).populate("party").sort({ createdAt: -1 });
  res.json(docs);
});

export const deletePayment = asyncHandler(async (req, res) => {
  const doc = await Payment.findOne({ _id: req.params.id, owner: req.user._id, deletedAt: null });
  doc.deletedAt = new Date();
  await doc.save();
  await RecycleBin.create({ owner: req.user._id, entityType: "payment", entityId: doc._id, data: doc.toObject() });
  res.json({ message: "Payment moved to recycle bin" });
});