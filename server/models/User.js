import mongoose from "mongoose";
import { USER_ROLES } from "../utils/constants.js";

const userSchema = new mongoose.Schema(
  {
    businessName: { type: String, trim: true },
    name: { type: String, required: true, trim: true },
    phone: { type: String, required: true, unique: true, index: true },
    role: {
      type: String,
      enum: Object.values(USER_ROLES),
      default: USER_ROLES.OWNER
    },
    permissions: {
      dashboard: { type: Boolean, default: true },
      parties: { type: Boolean, default: true },
      items: { type: Boolean, default: true },
      sales: { type: Boolean, default: true },
      purchases: { type: Boolean, default: true },
      payments: { type: Boolean, default: true },
      expenses: { type: Boolean, default: true },
      reports: { type: Boolean, default: true },
      recycle: { type: Boolean, default: false },
      staff: { type: Boolean, default: false }
    },
    isActive: { type: Boolean, default: true },
    lastLoginAt: Date
  },
  { timestamps: true }
);

export const User = mongoose.model("User", userSchema);