import mongoose from "mongoose";

const purchaseItemSchema = new mongoose.Schema(
  {
    item: { type: mongoose.Schema.Types.ObjectId, ref: "Item", required: true },
    name: String,
    qty: { type: Number, required: true },
    price: { type: Number, required: true },
    discount: { type: Number, default: 0 },
    taxRate: { type: Number, default: 0 }
  },
  { _id: false }
);

const purchaseSchema = new mongoose.Schema(
  {
    owner: { type: mongoose.Schema.Types.ObjectId, ref: "User", required: true, index: true },
    party: { type: mongoose.Schema.Types.ObjectId, ref: "Party" },
    billNo: { type: String, required: true },
    billDate: { type: Date, default: Date.now },
    items: [purchaseItemSchema],
    totals: {
      subtotal: Number,
      itemDiscount: Number,
      taxable: Number,
      tax: Number,
      extraDiscount: Number,
      grandTotal: Number,
      paid: Number,
      due: Number
    },
    note: String,
    deletedAt: { type: Date, default: null }
  },
  { timestamps: true }
);

export const Purchase = mongoose.model("Purchase", purchaseSchema);