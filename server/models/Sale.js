import mongoose from "mongoose";

const saleItemSchema = new mongoose.Schema(
  {
    item: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "Item",
      required: true,
    },
    name: {
      type: String,
      trim: true,
      default: "",
    },
    qty: {
      type: Number,
      required: true,
      min: 0.01,
    },
    price: {
      type: Number,
      required: true,
      min: 0,
    },
    discount: {
      type: Number,
      default: 0,
      min: 0,
    },
    taxRate: {
      type: Number,
      default: 0,
      min: 0,
    },
  },
  { _id: false }
);

const saleSchema = new mongoose.Schema(
  {
    owner: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "User",
      required: true,
      index: true,
    },
    party: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "Party",
      default: null,
    },
    invoiceNo: {
      type: String,
      required: true,
      trim: true,
    },
    invoiceDate: {
      type: Date,
      default: Date.now,
    },
    status: {
      type: String,
      enum: ["sale", "quotation", "returned"],
      default: "sale",
    },
    items: {
      type: [saleItemSchema],
      default: [],
    },
    totals: {
      subtotal: { type: Number, default: 0 },
      itemDiscount: { type: Number, default: 0 },
      taxable: { type: Number, default: 0 },
      tax: { type: Number, default: 0 },
      extraDiscount: { type: Number, default: 0 },
      grandTotal: { type: Number, default: 0 },
      paid: { type: Number, default: 0 },
      due: { type: Number, default: 0 },
    },
    note: {
      type: String,
      trim: true,
      default: "",
    },
    deletedAt: {
      type: Date,
      default: null,
      index: true,
    },
  },
  { timestamps: true }
);

export const Sale = mongoose.model("Sale", saleSchema);