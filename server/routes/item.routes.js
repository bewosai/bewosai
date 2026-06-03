import { Router } from "express";
import { requireAuth } from "../middlewares/auth.middleware.js";
import { requirePermission } from "../middlewares/role.middleware.js";
import {
  createItem,
  getItems,
  getItemById,
  getItemStats,
  updateItem,
  deleteItem,
  restoreItem,
} from "../controllers/item.controller.js";

const router = Router();

router.use(requireAuth);                    // Authentication required
router.use(requirePermission("items"));     // Permission check

router.post("/", createItem);
router.get("/", getItems);
router.get("/stats", getItemStats);
router.get("/:id", getItemById);
router.put("/:id", updateItem);
router.delete("/:id", deleteItem);
router.post("/:id/restore", restoreItem);

export default router;