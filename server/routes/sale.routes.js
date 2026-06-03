import express from "express";
import {
  createSale,
  getSales,
  getDeletedSales,
  getSaleById,
  deleteSale,
  restoreSale,
  forceDeleteSale,
  addPaymentIn,
  createSalesReturn,
} from "../controllers/sale.controller.js";
import { protect } from "../middlewares/auth.middleware.js";

const router = express.Router();

router.use(protect);

router.get("/", getSales);
router.get("/deleted", getDeletedSales);
router.get("/:id", getSaleById);

router.post("/", createSale);
router.post("/:id/payment-in", addPaymentIn);
router.post("/:id/return", createSalesReturn);

router.delete("/:id", deleteSale);
router.patch("/:id/restore", restoreSale);
router.delete("/:id/force", forceDeleteSale);

export default router;