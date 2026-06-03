import mongoose from "mongoose";

const expenseSchema = new mongoose.Schema(
  {
    owner: { type: mongoose.Schema.Types.ObjectId, ref: "User", required: true, index: true },
    title: { type: String, required: true },
    category: { type: String, default: "general" },
    amount: { type: Number, required: true },
    expenseDate: { type: Date, default: Date.now },
    note: String,
    deletedAt: { type: Date, default: null }
  },
  { timestamps: true }
);

export const Expense = mongoose.model("Expense", expenseSchema);