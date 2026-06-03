import { ApiError } from "../utils/ApiError.js";

export function requirePermission(key) {
  return (req, res, next) => {
    if (!req.user?.permissions?.[key]) {
      return next(new ApiError(403, `No permission for ${key}`));
    }
    next();
  };
}