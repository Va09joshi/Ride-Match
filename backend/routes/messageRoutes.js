const express = require('express');
const router = express.Router();
const Message = require('../models/Message');

router.post('/send', async (req, res) => {
  try {
    const { senderId, receiverId, message } = req.body;

    const newMessage = new Message({ senderId, receiverId, message });
    await newMessage.save();

    res.json({ success: true, message: "Message sent successfully" });
  } catch (err) {
    res.status(500).json({ success: false, message: err.message });
  }
});

router.get('/:userId/:receiverId', async (req, res) => {
  try {
    const { userId, receiverId } = req.params;

    const messages = await Message.find({
      $or: [
        { senderId: userId, receiverId },
        { senderId: receiverId, receiverId: userId }
      ]
    }).sort({ createdAt: 1 });

    res.json({ success: true, messages });
  } catch (err) {
    res.status(500).json({ success: false, message: err.message });
  }
});

module.exports = router;
