import jwt from "jsonwebtoken";
import { env } from "../config/env.js";
import { RefreshToken } from "../models/RefreshToken.js";

export function signAccessToken(user) {
  return jwt.sign(
    {
      sub: user._id.toString(),
      phone: user.phone,
      role: user.role,
      permissions: user.permissions
    },
    env.jwtAccessSecret,
    { expiresIn: env.accessTokenExpires }
  );
}

export function signRefreshToken(user) {
  return jwt.sign({ sub: user._id.toString() }, env.jwtRefreshSecret, {
    expiresIn: env.refreshTokenExpires
  });
}

export function verifyAccessToken(token) {
  return jwt.verify(token, env.jwtAccessSecret);
}

export function verifyRefreshToken(token) {
  return jwt.verify(token, env.jwtRefreshSecret);
}

export async function storeRefreshToken(userId, token, device = "web") {
  const expiresAt = new Date(Date.now() + 365 * 24 * 60 * 60 * 1000);
  await RefreshToken.create({ user: userId, token, device, expiresAt });
}

export async function revokeRefreshToken(token) {
  await RefreshToken.findOneAndUpdate({ token, revokedAt: null }, { revokedAt: new Date() });
}

export async function isRefreshTokenValid(token) {
  const doc = await RefreshToken.findOne({ token, revokedAt: null });
  return !!doc;
}