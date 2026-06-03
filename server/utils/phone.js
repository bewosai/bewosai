import { env } from "../config/env.js";
import { ApiError } from "./ApiError.js";

export function normalizeNepalPhone(phone = "") {
  let value = String(phone).replace(/\s+/g, "").trim();

  if (value.startsWith("98") && value.length === 10) {
    return `${env.defaultCountryCode}${value}`;
  }

  if (value.startsWith("977") && value.length === 13) {
    return `+${value}`;
  }

  if (/^\+9779[678]\d{8}$/.test(value)) {
    return value;
  }

  throw new ApiError(400, "Invalid Nepal mobile number. Use 98XXXXXXXX or +97798XXXXXXXX");
}