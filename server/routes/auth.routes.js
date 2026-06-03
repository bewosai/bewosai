import { Router } from "express";
import { body } from "express-validator";
import {
  requestOtp,
  verifyLoginOtp,
  refreshSession,
  logout,
  me
} from "../controllers/auth.controller.js";
import { validate } from "../middlewares/validate.middleware.js";
import { requireAuth } from "../middlewares/auth.middleware.js";

const router = Router();

router.post("/request-otp", [body("phone").notEmpty()], validate, requestOtp);
router.post("/verify-otp", [body("phone").notEmpty(), body("code").notEmpty()], validate, verifyLoginOtp);
router.post("/refresh", refreshSession);
router.post("/logout", logout);
router.get("/me", requireAuth, me);

export default router;