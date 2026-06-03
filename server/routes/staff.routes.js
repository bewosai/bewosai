import { Router } from "express";
import { requireAuth } from "../middlewares/auth.middleware.js";
import { requirePermission } from "../middlewares/role.middleware.js";
import {
  createStaff,
  getStaff,
  updateStaffPermissions
} from "../controllers/staff.controller.js";

const router = Router();
router.use(requireAuth, requirePermission("staff"));
router.post("/", createStaff);
router.get("/", getStaff);
router.put("/:id", updateStaffPermissions);

export default router;