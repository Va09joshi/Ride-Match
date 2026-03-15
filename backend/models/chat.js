const mongoose = require("mongoose");

const chatSchema = new mongoose.Schema({
  users: [
    {
      type: mongoose.Schema.Types.ObjectId,
      ref: "User",
    },
  ],
  lastMessage: { type: String, default: "" },
  lastMessageTime: { type: Date, default: null },

  unreadCount: {
    type: Map,
    of: Number, // { userId: count }
    default: {},
  },
});

module.exports = mongoose.model("Chat", chatSchema);
