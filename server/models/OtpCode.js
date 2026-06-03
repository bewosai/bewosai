import mongoose from "mongoose";

const otpCodeSchema = new mongoose.Schema(
  {
    phone: { type: String, required: true, index: true },
    code: { type: String, required: true },
    purpose: { type: String, default: "login" },
    expiresAt: { type: Date, required: true, expires: 0 },
    attempts: { type: Number, default: 0 },
    verified: { type: Boolean, default: false }
  },
  { timestamps: true }
);

export const OtpCode = mongoose.model("OtpCode", otpCodeSchema);