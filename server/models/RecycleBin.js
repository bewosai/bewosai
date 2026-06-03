import mongoose from "mongoose";

const recycleBinSchema = new mongoose.Schema(
  {
    owner: { type: mongoose.Schema.Types.ObjectId, ref: "User", required: true, index: true },
    entityType: { type: String, required: true },
    entityId: { type: mongoose.Schema.Types.ObjectId, required: true },
    data: { type: Object, required: true },
    deletedAt: { type: Date, default: Date.now }
  },
  { timestamps: true }
);

export const RecycleBin = mongoose.model("RecycleBin", recycleBinSchema);