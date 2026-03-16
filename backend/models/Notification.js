const mongoose = require("mongoose");

const notificationSchema = new mongoose.Schema({
  // The user who triggered the event (optional for system-generated notifications)
  senderId: { type: mongoose.Schema.Types.ObjectId, ref: "User" },

  // The user who will receive this notification
  receiverId: { type: mongoose.Schema.Types.ObjectId, ref: "User", required: true },

  // Optional foreign-key references (kept for backward compat with like notifications)
  requestId: { type: mongoose.Schema.Types.ObjectId, ref: "RideRequest" },

  // Flexible related-resource id (rideId, bookingId, messageId …)
  relatedId: { type: String, default: null },

  type: {
    type: String,
    enum: [
      "like",
      "unlike",
      "ride_created",
      "ride_booked",
      "ride_cancelled",
      "ride_request_accepted",
      "ride_request_declined",
      "message_received",
    ],
    required: true,
  },

  message: { type: String },
  isRead: { type: Boolean, default: false },

  createdAt: { type: Date, default: Date.now },
});

module.exports = mongoose.model("Notification", notificationSchema);
