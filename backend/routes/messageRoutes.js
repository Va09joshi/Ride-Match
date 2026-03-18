const express = require('express');
const router = express.Router();
const Message = require('../models/Message');
const User = require('../models/user');
const { createAndDispatchMessage } = require('../helpers/chatMessageHelper');

router.post('/send', async (req, res) => {
  try {
    const { senderId, receiverId, message } = req.body;

    const data = await createAndDispatchMessage({ senderId, receiverId, message });

    res.json({
      success: true,
      message: 'Message sent successfully',
      data,
    });
  } catch (err) {
    const statusCode = err.message?.includes('required') ? 400 : 500;
    res.status(statusCode).json({ success: false, message: err.message });
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

    const [sender, receiver] = await Promise.all([
      User.findById(userId).select('name'),
      User.findById(receiverId).select('name'),
    ]);

    const payload = messages.map((m) => ({
      _id: m._id,
      senderId: m.senderId,
      receiverId: m.receiverId,
      message: m.message,
      createdAt: m.createdAt,
      senderName: m.senderId.toString() === userId ? (sender?.name || 'User') : (receiver?.name || 'User'),
      receiverName: m.receiverId.toString() === userId ? (sender?.name || 'User') : (receiver?.name || 'User'),
    }));

    res.json(payload);
  } catch (err) {
    res.status(500).json({ success: false, message: err.message });
  }
});

module.exports = router;
