import express from "express";
import cors from "cors";
import helmet from "helmet";
import morgan from "morgan";
import cookieParser from "cookie-parser";
import { env } from "./config/env.js";
import authRoutes from "./routes/auth.routes.js";
import dashboardRoutes from "./routes/dashboard.routes.js";
import partyRoutes from "./routes/party.routes.js";
import itemRoutes from "./routes/item.routes.js";
import saleRoutes from "./routes/sale.routes.js";
import purchaseRoutes from "./routes/purchase.routes.js";
import paymentRoutes from "./routes/payment.routes.js";
import expenseRoutes from "./routes/expense.routes.js";
import reportRoutes from "./routes/report.routes.js";
import recycleRoutes from "./routes/recycle.routes.js";
import staffRoutes from "./routes/staff.routes.js";
import { errorHandler, notFound } from "./middlewares/error.middleware.js";

const app = express();

app.use(helmet());
app.use(cors({ origin: env.clientUrl, credentials: true }));
app.use(morgan("dev"));
app.use(express.json());
app.use(cookieParser());

app.get("/api/health", (req, res) => res.json({ ok: true }));
app.use("/api/auth", authRoutes);
app.use("/api/dashboard", dashboardRoutes);
app.use("/api/parties", partyRoutes);
app.use("/api/items", itemRoutes);
app.use("/api/sales", saleRoutes);
app.use("/api/purchases", purchaseRoutes);
app.use("/api/payments", paymentRoutes);
app.use("/api/expenses", expenseRoutes);
app.use("/api/reports", reportRoutes);
app.use("/api/recycle", recycleRoutes);
app.use("/api/staff", staffRoutes);

app.use(notFound);
app.use(errorHandler);

export default app;