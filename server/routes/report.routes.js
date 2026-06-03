import { Router } from "express";
import { requireAuth } from "../middlewares/auth.middleware.js";
import { requirePermission } from "../middlewares/role.middleware.js";
import { getSummaryReport } from "../controllers/report.controller.js";

const router = Router();
router.use(requireAuth, requirePermission("reports"));
router.get("/summary", getSummaryReport);

export default router;