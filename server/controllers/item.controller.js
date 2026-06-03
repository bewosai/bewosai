import mongoose from "mongoose";
import { Item } from "../models/Item.js";
import { RecycleBin } from "../models/RecycleBin.js";
import { asyncHandler } from "../utils/asyncHandler.js";
import { ApiError } from "../utils/ApiError.js";

const normalizePayload = (body) => ({
  name: String(body.name || "").trim(),
  sku: String(body.sku || "").trim(),
  unit: String(body.unit || "pcs").trim(),
  category: String(body.category || "General").trim(),
  brand: String(body.brand || "").trim(),
  salePrice: Number(body.salePrice || 0),
  purchasePrice: Number(body.purchasePrice || 0),
  taxRate: Number(body.taxRate || 0),
  stockQty: Number(body.stockQty || 0),
  lowStockAlertAt: Number(body.lowStockAlertAt || 10),
  notes: String(body.notes || "").trim(),
  status: body.status || "active",
});

// CREATE
export const createItem = asyncHandler(async (req, res) => {
  const payload = normalizePayload(req.body);

  if (!payload.name) throw new ApiError(400, "Item name is required");

  const exists = await Item.findOne({
    business: req.business._id,
    name: payload.name,
    deletedAt: null,
  });

  if (exists) throw new ApiError(409, "Item with this name already exists for this business");

  const item = await Item.create({
    ...payload,
    business: req.business._id,
  });

  res.status(201).json(item);
});

// GET ALL
export const getItems = asyncHandler(async (req, res) => {
  const { search = "", status = "", stock = "" } = req.query;
  const page = parseInt(req.query.page) || 1;
  const limit = parseInt(req.query.limit) || 20;

  const query = { business: req.business._id, deletedAt: null };

  if (status) query.status = status;
  if (search) {
    query.$or = [
      { name: { $regex: search, $options: "i" } },
      { sku: { $regex: search, $options: "i" } },
      { category: { $regex: search, $options: "i" } },
    ];
  }

  const items = await Item.find(query)
    .sort({ createdAt: -1 })
    .skip((page - 1) * limit)
    .limit(limit);

  const total = await Item.countDocuments(query);

  res.json({
    items,
    pagination: { page, limit, total, totalPages: Math.ceil(total / limit) },
  });
});

// GET STATS
export const getItemStats = asyncHandler(async (req, res) => {
  const items = await Item.find({ business: req.business._id, deletedAt: null });

  const totalItems = items.length;
  const lowStockItems = items.filter(i => i.stockQty > 0 && i.stockQty <= i.lowStockAlertAt).length;
  const outOfStockItems = items.filter(i => i.stockQty <= 0).length;
  const totalStockValue = items.reduce((sum, i) => sum + i.stockQty * i.purchasePrice, 0);

  res.json({ totalItems, lowStockItems, outOfStockItems, totalStockValue });
});

// GET BY ID
export const getItemById = asyncHandler(async (req, res) => {
  if (!mongoose.Types.ObjectId.isValid(req.params.id)) {
    throw new ApiError(400, "Invalid item ID");
  }

  const item = await Item.findOne({
    _id: req.params.id,
    business: req.business._id,
    deletedAt: null,
  });

  if (!item) throw new ApiError(404, "Item not found");

  res.json(item);
});

// UPDATE
export const updateItem = asyncHandler(async (req, res) => {
  const payload = normalizePayload(req.body);

  const item = await Item.findOneAndUpdate(
    { _id: req.params.id, business: req.business._id, deletedAt: null },
    payload,
    { new: true, runValidators: true }
  );

  if (!item) throw new ApiError(404, "Item not found");

  res.json(item);
});

// DELETE (Soft + Recycle)
export const deleteItem = asyncHandler(async (req, res) => {
  const item = await Item.findOne({
    _id: req.params.id,
    business: req.business._id,
    deletedAt: null,
  });

  if (!item) throw new ApiError(404, "Item not found");

  item.deletedAt = new Date();
  await item.save();

  await RecycleBin.create({
    business: req.business._id,
    entityType: "Item",
    entityId: item._id,
    data: item.toObject(),
  });

  res.json({ message: "Item moved to recycle bin" });
});

// RESTORE
export const restoreItem = asyncHandler(async (req, res) => {
  const item = await Item.findOne({
    _id: req.params.id,
    business: req.business._id,
    deletedAt: { $ne: null },
  });

  if (!item) throw new ApiError(404, "Item not found in recycle bin");

  item.deletedAt = null;
  await item.save();

  res.json({ message: "Item restored", item });
});