import mongoose from "mongoose";
import { Party } from "../models/Party.js";
import { Sale } from "../models/Sale.js";
import { Purchase } from "../models/Purchase.js";
import { Payment } from "../models/Payment.js";
import { RecycleBin } from "../models/RecycleBin.js";
import { asyncHandler } from "../utils/asyncHandler.js";
import { calcPartyBalance } from "../utils/calculations.js";
import { ApiError } from "../utils/ApiError.js";

function normalizePartyPayload(body = {}) {
  return {
    name: String(body.name || "").trim(),
    type: body.type || "customer",
    phone: String(body.phone || "").trim(),
    email: String(body.email || "").trim().toLowerCase(),
    address: String(body.address || "").trim(),
    contactPerson: String(body.contactPerson || "").trim(),
    notes: String(body.notes || "").trim(),
    creditLimit: Number(body.creditLimit || 0),
    openingBalance: Number(body.openingBalance || 0),
    status: body.status || "active",
  };
}

export const createParty = asyncHandler(async (req, res) => {
  const payload = normalizePartyPayload(req.body);

  if (!payload.name) {
    throw new ApiError(400, "Party name is required");
  }

  const exists = await Party.findOne({
    owner: req.user._id,
    name: payload.name,
    deletedAt: null,
  });

  if (exists) {
    throw new ApiError(409, "Party with this name already exists");
  }

  const doc = await Party.create({
    ...payload,
    owner: req.user._id,
  });

  res.status(201).json(doc);
});

export const getParties = asyncHandler(async (req, res) => {
  const {
    search = "",
    type = "",
    status = "",
    page = 1,
    limit = 12,
    sortBy = "createdAt",
    sortOrder = "desc",
  } = req.query;

  const pageNumber = Math.max(Number(page) || 1, 1);
  const pageSize = Math.min(Math.max(Number(limit) || 12, 1), 100);

  const query = {
    owner: req.user._id,
    deletedAt: null,
  };

  if (type && ["customer", "supplier", "both"].includes(type)) {
    query.type = type;
  }

  if (status && ["active", "inactive"].includes(status)) {
    query.status = status;
  }

  if (search.trim()) {
    query.$or = [
      { name: { $regex: search.trim(), $options: "i" } },
      { phone: { $regex: search.trim(), $options: "i" } },
      { email: { $regex: search.trim(), $options: "i" } },
      { address: { $regex: search.trim(), $options: "i" } },
      { contactPerson: { $regex: search.trim(), $options: "i" } },
      { type: { $regex: search.trim(), $options: "i" } },
    ];
  }

  const allowedSort = ["createdAt", "updatedAt", "name", "openingBalance"];
  const safeSortBy = allowedSort.includes(sortBy) ? sortBy : "createdAt";
  const safeSortOrder = sortOrder === "asc" ? 1 : -1;

  const [items, total] = await Promise.all([
    Party.find(query)
      .sort({ [safeSortBy]: safeSortOrder })
      .skip((pageNumber - 1) * pageSize)
      .limit(pageSize),
    Party.countDocuments(query),
  ]);

  res.json({
    items,
    pagination: {
      page: pageNumber,
      limit: pageSize,
      total,
      totalPages: Math.ceil(total / pageSize),
    },
  });
});

export const getPartyStats = asyncHandler(async (req, res) => {
  const owner = req.user._id;

  const parties = await Party.find({ owner, deletedAt: null });

  const stats = {
    total: parties.length,
    customers: parties.filter((x) => x.type === "customer").length,
    suppliers: parties.filter((x) => x.type === "supplier").length,
    both: parties.filter((x) => x.type === "both").length,
    active: parties.filter((x) => x.status === "active").length,
    inactive: parties.filter((x) => x.status === "inactive").length,
    totalOpeningBalance: parties.reduce(
      (sum, x) => sum + Number(x.openingBalance || 0),
      0
    ),
  };

  res.json(stats);
});

export const getPartyById = asyncHandler(async (req, res) => {
  const doc = await Party.findOne({
    _id: req.params.id,
    owner: req.user._id,
    deletedAt: null,
  });

  if (!doc) {
    throw new ApiError(404, "Party not found");
  }

  res.json(doc);
});

export const getPartyLedger = asyncHandler(async (req, res) => {
  const partyId = req.params.id;

  if (!mongoose.Types.ObjectId.isValid(partyId)) {
    throw new ApiError(400, "Invalid party id");
  }

  const party = await Party.findOne({
    _id: partyId,
    owner: req.user._id,
    deletedAt: null,
  });

  if (!party) {
    throw new ApiError(404, "Party not found");
  }

  const [sales, purchases, payments] = await Promise.all([
    Sale.find({
      owner: req.user._id,
      party: partyId,
      deletedAt: null,
    }).sort({ createdAt: -1 }),

    Purchase.find({
      owner: req.user._id,
      party: partyId,
      deletedAt: null,
    }).sort({ createdAt: -1 }),

    Payment.find({
      owner: req.user._id,
      party: partyId,
      deletedAt: null,
    }).sort({ createdAt: -1 }),
  ]);

  const totalSales = sales.reduce(
    (s, x) => s + Number(x.totals?.grandTotal || 0),
    0
  );

  const totalPurchases = purchases.reduce(
    (s, x) => s + Number(x.totals?.grandTotal || 0),
    0
  );

  const totalPaymentsIn = payments
    .filter((x) => x.type === "in")
    .reduce((s, x) => s + Number(x.amount || 0), 0);

  const totalPaymentsOut = payments
    .filter((x) => x.type === "out")
    .reduce((s, x) => s + Number(x.amount || 0), 0);

  const balance = calcPartyBalance({
    openingBalance: party.openingBalance || 0,
    totalSales,
    totalPurchases,
    totalPaymentsIn,
    totalPaymentsOut,
  });

  const transactions = [
    ...sales.map((x) => ({
      _id: x._id,
      type: "sale",
      amount: Number(x.totals?.grandTotal || 0),
      date: x.createdAt,
      refNo: x.invoiceNumber || "",
      note: x.note || "",
    })),
    ...purchases.map((x) => ({
      _id: x._id,
      type: "purchase",
      amount: Number(x.totals?.grandTotal || 0),
      date: x.createdAt,
      refNo: x.billNumber || "",
      note: x.note || "",
    })),
    ...payments.map((x) => ({
      _id: x._id,
      type: x.type === "in" ? "payment_in" : "payment_out",
      amount: Number(x.amount || 0),
      date: x.createdAt,
      refNo: x.referenceNo || "",
      note: x.note || "",
    })),
  ].sort((a, b) => new Date(b.date) - new Date(a.date));

  res.json({
    party,
    summary: {
      totalSales,
      totalPurchases,
      totalPaymentsIn,
      totalPaymentsOut,
      balance,
    },
    transactions,
  });
});

export const updateParty = asyncHandler(async (req, res) => {
  const payload = normalizePartyPayload(req.body);

  if (!payload.name) {
    throw new ApiError(400, "Party name is required");
  }

  const doc = await Party.findOneAndUpdate(
    {
      _id: req.params.id,
      owner: req.user._id,
      deletedAt: null,
    },
    payload,
    {
      new: true,
      runValidators: true,
    }
  );

  if (!doc) {
    throw new ApiError(404, "Party not found");
  }

  res.json(doc);
});

export const deleteParty = asyncHandler(async (req, res) => {
  const doc = await Party.findOne({
    _id: req.params.id,
    owner: req.user._id,
    deletedAt: null,
  });

  if (!doc) {
    throw new ApiError(404, "Party not found");
  }

  doc.deletedAt = new Date();
  await doc.save();

  await RecycleBin.create({
    owner: req.user._id,
    entityType: "party",
    entityId: doc._id,
    data: doc.toObject(),
  });

  res.json({ message: "Party moved to recycle bin" });
});