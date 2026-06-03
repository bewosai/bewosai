import { Router } from "express";
import { requireAuth } from "../middlewares/auth.middleware.js";
import { requirePermission } from "../middlewares/role.middleware.js";
import {
  createExpense,
  getExpenses,
  deleteExpense
} from "../controllers/expense.controller.js";

const router = Router();
router.use(requireAuth, requirePermission("expenses"));
router.post("/", createExpense);
router.get("/", getExpenses);
router.delete("/:id", deleteExpense);

export default router;