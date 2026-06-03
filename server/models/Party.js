import mongoose from "mongoose";

const partySchema = new mongoose.Schema(
  {
    owner: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "User",
      required: true,
      index: true,
    },

    name: {
      type: String,
      required: true,
      trim: true,
      maxlength: 120,
    },

    type: {
      type: String,
      enum: ["customer", "supplier", "both"],
      default: "customer",
      index: true,
    },

    phone: {
      type: String,
      trim: true,
      default: "",
    },

    email: {
      type: String,
      trim: true,
      lowercase: true,
      default: "",
    },

    address: {
      type: String,
      trim: true,
      default: "",
    },

    contactPerson: {
      type: String,
      trim: true,
      default: "",
    },

   

    notes: {
      type: String,
      trim: true,
      default: "",
    },

    creditLimit: {
      type: Number,
      default: 0,
      min: 0,
    },

    openingBalance: {
      type: Number,
      default: 0,
    },

    status: {
      type: String,
      enum: ["active", "inactive"],
      default: "active",
      index: true,
    },

    deletedAt: {
      type: Date,
      default: null,
      index: true,
    },
  },
  { timestamps: true }
);

partySchema.index({ owner: 1, name: 1 });
partySchema.index({ owner: 1, type: 1, deletedAt: 1 });
partySchema.index({ owner: 1, phone: 1 });

export const Party = mongoose.model("Party", partySchema);