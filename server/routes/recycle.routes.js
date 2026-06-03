import { Router } from "express";
import { requireAuth } from "../middlewares/auth.middleware.js";
import { requirePermission } from "../middlewares/role.middleware.js";
import {
  getRecycleItems,
  restoreRecycleItem,
  deleteRecycleItemForever
} from "../controllers/recycle.controller.js";

const router = Router();
router.use(requireAuth, requirePermission("recycle"));
router.get("/", getRecycleItems);
router.post("/:id/restore", restoreRecycleItem);
router.delete("/:id", deleteRecycleItemForever);

export default router;