import mongoose from "mongoose";

const itemSchema = new mongoose.Schema(
  {
    business: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "Business",
      required: true,
      index: true,
    },

    name: {
      type: String,
      required: true,
      trim: true,
      maxlength: 150,
    },

    sku: {
      type: String,
      trim: true,
      default: "",
    },

    unit: {
      type: String,
      trim: true,
      default: "pcs",
    },

    category: {
      type: String,
      trim: true,
      default: "General",
    },

    brand: {
      type: String,
      trim: true,
      default: "",
    },

    salePrice: { type: Number, required: true, default: 0, min: 0 },
    purchasePrice: { type: Number, required: true, default: 0, min: 0 },
    taxRate: { type: Number, default: 0, min: 0, max: 100 },

    stockQty: { type: Number, default: 0, min: 0 },
    lowStockAlertAt: { type: Number, default: 10, min: 0 },

    notes: { type: String, trim: true, default: "" },

    status: {
      type: String,
      enum: ["active", "inactive"],
      default: "active",
    },

    deletedAt: {
      type: Date,
      default: null,
      index: true,
    },
  },
  { timestamps: true }
);

// Important indexes for multi-business
itemSchema.index({ business: 1, name: 1 });
itemSchema.index({ business: 1, sku: 1 });
itemSchema.index({ business: 1, deletedAt: 1 });

export const Item = mongoose.model("Item", itemSchema);