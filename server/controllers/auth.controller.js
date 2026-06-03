import jwt from "jsonwebtoken";
import { User } from "../models/User.js";
import { asyncHandler } from "../utils/asyncHandler.js";
import { normalizeNepalPhone } from "../utils/phone.js";
import { createAndSendOtp, verifyOtp } from "../services/otp.service.js";
import {
  signAccessToken,
  signRefreshToken,
  storeRefreshToken,
  verifyRefreshToken,
  revokeRefreshToken,
  isRefreshTokenValid
} from "../services/token.service.js";
import { env } from "../config/env.js";
import { ApiError } from "../utils/ApiError.js";

function setRefreshCookie(res, token) {
  res.cookie("refreshToken", token, {
    httpOnly: true,
    secure: env.cookieSecure,
    sameSite: "lax",
    maxAge: 365 * 24 * 60 * 60 * 1000
  });
}

export const requestOtp = asyncHandler(async (req, res) => {
  const { phone } = req.body;

  if (!phone) {
    throw new ApiError(400, "Phone is required");
  }

  const normalizedPhone = normalizeNepalPhone(phone);
  await createAndSendOtp(normalizedPhone);

  res.json({ message: "OTP sent successfully" });
});

export const verifyLoginOtp = asyncHandler(async (req, res) => {
  const { name, phone, code } = req.body;

  if (!phone) {
    throw new ApiError(400, "Phone is required");
  }

  if (!code) {
    throw new ApiError(400, "OTP code is required");
  }

  const normalizedPhone = normalizeNepalPhone(phone);
  const safeName = String(name ?? "").trim() || "Business Owner";
  const safeBusinessName = `${safeName}'s Business`;

  const ok = await verifyOtp(normalizedPhone, code);
  if (!ok) {
    throw new ApiError(400, "Invalid OTP");
  }

  let user = await User.findOne({ phone: normalizedPhone });

  if (!user) {
    user = await User.create({
      name: safeName,
      phone: normalizedPhone,
      businessName: safeBusinessName
    });
  } else {
    if (!user.name || !String(user.name).trim()) {
      user.name = safeName;
    }

    if (!user.businessName || !String(user.businessName).trim()) {
      user.businessName = safeBusinessName;
    }

    user.lastLoginAt = new Date();
    await user.save();
  }

  const accessToken = signAccessToken(user);
  const refreshToken = signRefreshToken(user);

  await storeRefreshToken(
    user._id,
    refreshToken,
    req.headers["user-agent"] || "web"
  );

  setRefreshCookie(res, refreshToken);

  res.json({
    message: "Login successful",
    accessToken,
    user
  });
});
export const refreshSession = asyncHandler(async (req, res) => {
  const refreshToken = req.cookies.refreshToken;

  if (!refreshToken) {
    throw new ApiError(401, "No refresh token");
  }

  const exists = await isRefreshTokenValid(refreshToken);
  if (!exists) {
    throw new ApiError(401, "Refresh token revoked");
  }

  const payload = verifyRefreshToken(refreshToken);
  const user = await User.findById(payload.sub);

  if (!user) {
    throw new ApiError(401, "User not found");
  }

  const newAccessToken = signAccessToken(user);

  res.json({
    accessToken: newAccessToken,
    user
  });
});

export const logout = asyncHandler(async (req, res) => {
  const refreshToken = req.cookies.refreshToken;

  if (refreshToken) {
    await revokeRefreshToken(refreshToken);
  }

  res.clearCookie("refreshToken");
  res.json({ message: "Logged out" });
});

export const me = asyncHandler(async (req, res) => {
  const authHeader = req.headers.authorization || "";
  const token = authHeader.startsWith("Bearer ")
    ? authHeader.slice(7)
    : null;

  if (!token) {
    throw new ApiError(401, "Unauthorized");
  }

  const payload = jwt.verify(token, env.jwtAccessSecret);
  const user = await User.findById(payload.sub);

  if (!user) {
    throw new ApiError(401, "User not found");
  }

  res.json({ user });
});