import { Router } from "express";
import { requireAuth } from "../middlewares/auth.middleware.js";
import { requirePermission } from "../middlewares/role.middleware.js";
import {
  createPayment,
  getPayments,
  deletePayment
} from "../controllers/payment.controller.js";

const router = Router();
router.use(requireAuth, requirePermission("payments"));
router.post("/", createPayment);
router.get("/", getPayments);
router.delete("/:id", deletePayment);

export default router;