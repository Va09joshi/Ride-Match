const mongoose = require("mongoose");

const notificationSchema = new mongoose.Schema({
  senderId: { type: mongoose.Schema.Types.ObjectId, ref: "User", required: true },
  receiverId: { type: mongoose.Schema.Types.ObjectId, ref: "User", required: true },
  requestId: { type: mongoose.Schema.Types.ObjectId, ref: "RideRequest", required: true },

  type: { type: String, enum: ["like", "unlike"], required: true },

  message: { type: String },
  isRead: { type: Boolean, default: false },

  createdAt: { type: Date, default: Date.now }
});

module.exports = mongoose.model("Notification", notificationSchema);
