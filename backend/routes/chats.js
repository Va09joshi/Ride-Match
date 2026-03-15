const express = require('express');
const router = express.Router();
const Message = require('../models/Message');
const User = require('../models/user');

// GET chat between two users
router.get('/:userA/:userB', async (req, res) => {
  const { userA, userB } = req.params;

  try {
    const messages = await Message.find({
      $or: [
        { senderId: userA, receiverId: userB },
        { senderId: userB, receiverId: userA }
      ]
    }).sort({ timestamp: 1 });

    // Fetch both users
    const user1 = await User.findById(userA);
    const user2 = await User.findById(userB);

    const senderNameA = user1?.name || "Unknown";
    const senderNameB = user2?.name || "Unknown";

    // Send populated messages
    const formatted = messages.map(msg => ({
  ...msg._doc,
  senderName: msg.senderId.toString() === userA ? user1.name : user2.name,
  receiverName: msg.receiverId.toString() === userA ? user1.name : user2.name
}));


    res.json(formatted);

  } catch (err) {
    res.status(500).json({ error: 'Error fetching chat history' });
  }
});

module.exports = router;
