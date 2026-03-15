const express = require("express");
const router = express.Router();
const Chat = require("../models/chat");
const User = require("../models/user");

// Get chat history list for one user
router.get("/:userId", async (req, res) => {
  try {
    // FIX: trim to remove hidden newline (\n)
    const userId = req.params.userId.trim();

    // Now MongoDB can match
    const chats = await Chat.find({ users: userId }).sort({ lastMessageTime: -1 });

    const result = [];

    for (let chat of chats) {
      const otherUserId = chat.users.find(u => u.toString() !== userId);

      const otherUser = await User.findById(otherUserId);

      result.push({
        _id: chat._id,
        receiverId: otherUserId,
        receiverName: otherUser?.name || "Unknown",
        receiverProfile: otherUser?.profile || "https://i.pravatar.cc/150?img=3",
        lastMessage: chat.lastMessage || "",
        lastMessageTime: chat.lastMessageTime || "",
        unreadCount: chat.unreadCount.get(userId) || 0
      });
    }

    res.json(result);

  } catch (err) {
    console.log("Chat history error:", err);
    res.status(500).json({ error: "Failed to load chats" });
  }
});

module.exports = router;
