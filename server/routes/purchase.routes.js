import { Router } from "express";
import { requireAuth } from "../middlewares/auth.middleware.js";
import { requirePermission } from "../middlewares/role.middleware.js";
import {
  createPurchase,
  getPurchases,
  deletePurchase
} from "../controllers/purchase.controller.js";

const router = Router();
router.use(requireAuth, requirePermission("purchases"));
router.post("/", createPurchase);
router.get("/", getPurchases);
router.delete("/:id", deletePurchase);

export default router;