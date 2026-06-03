import mongoose from "mongoose";
import { PAYMENT_TYPES, PAYMENT_MODES } from "../utils/constants.js";

const paymentSchema = new mongoose.Schema(
  {
    owner: { type: mongoose.Schema.Types.ObjectId, ref: "User", required: true, index: true },
    party: { type: mongoose.Schema.Types.ObjectId, ref: "Party", required: true },
    type: { type: String, enum: Object.values(PAYMENT_TYPES), required: true },
    mode: { type: String, enum: PAYMENT_MODES, default: "cash" },
    amount: { type: Number, required: true },
    paymentDate: { type: Date, default: Date.now },
    note: String,
    deletedAt: { type: Date, default: null }
  },
  { timestamps: true }
);

export const Payment = mongoose.model("Payment", paymentSchema);