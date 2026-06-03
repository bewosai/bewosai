import { Router } from "express";
import {
  createParty,
  deleteParty,
  getParties,
  getPartyById,
  getPartyLedger,
  getPartyStats,
  updateParty,
} from "../controllers/party.controller.js";
import { requireAuth } from "../middlewares/auth.middleware.js";

const router = Router();

router.use(requireAuth);

router.get("/", getParties);
router.get("/stats", getPartyStats);
router.get("/:id", getPartyById);
router.get("/:id/ledger", getPartyLedger);
router.post("/", createParty);
router.put("/:id", updateParty);
router.delete("/:id", deleteParty);

export default router;