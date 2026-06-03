import { Router } from "express";
import { requireAuth } from "../middlewares/auth.middleware.js";
import { requirePermission } from "../middlewares/role.middleware.js";
import { getDashboard } from "../controllers/dashboard.controller.js";

const router = Router();
router.use(requireAuth, requirePermission("dashboard"));
router.get("/", getDashboard);

export default router;