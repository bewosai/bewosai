import { User } from "../models/User.js";
import { asyncHandler } from "../utils/asyncHandler.js";

export const createStaff = asyncHandler(async (req, res) => {
  const staff = await User.create({
    ...req.body,
    role: req.body.role || "staff"
  });
  res.status(201).json(staff);
});

export const getStaff = asyncHandler(async (req, res) => {
  const docs = await User.find({ _id: { $ne: req.user._id } }).sort({ createdAt: -1 });
  res.json(docs);
});

export const updateStaffPermissions = asyncHandler(async (req, res) => {
  const { permissions, role, isActive } = req.body;
  const doc = await User.findByIdAndUpdate(
    req.params.id,
    { permissions, role, isActive },
    { new: true }
  );
  res.json(doc);
});