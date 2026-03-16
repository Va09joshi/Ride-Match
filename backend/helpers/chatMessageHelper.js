const Message = require('../models/Message');
const User = require('../models/user');
const Chat = require('../models/chat');
const { getIO, users } = require('../config/socketManager');
const { createNotification } = require('./notificationHelper');

const createAndDispatchMessage = async ({ senderId, receiverId, message }) => {
  if (!senderId || !receiverId || !message) {
    throw new Error('senderId, receiverId and message are required');
  }

  const senderIdStr = senderId.toString();
  const receiverIdStr = receiverId.toString();
  const trimmedMessage = message.toString().trim();
  if (!trimmedMessage) {
    throw new Error('message is required');
  }

  const [sender, receiver] = await Promise.all([
    User.findById(senderIdStr).select('name'),
    User.findById(receiverIdStr).select('name'),
  ]);

  if (!sender || !receiver) {
    throw new Error('Sender or receiver not found');
  }

  const newMessage = await Message.create({
    senderId: senderIdStr,
    senderName: sender.name,
    receiverId: receiverIdStr,
    receiverName: receiver.name,
    message: trimmedMessage,
  });

  let chat = await Chat.findOne({
    users: { $all: [senderIdStr, receiverIdStr] },
  });

  if (!chat) {
    chat = new Chat({
      users: [senderIdStr, receiverIdStr],
      unreadCount: {
        [senderIdStr]: 0,
        [receiverIdStr]: 0,
      },
    });
  }

  chat.lastMessage = trimmedMessage;
  chat.lastMessageTime = new Date();
  chat.unreadCount.set(
    receiverIdStr,
    (chat.unreadCount.get(receiverIdStr) || 0) + 1,
  );
  await chat.save();

  // Create push/in-app notification for receiver.
  createNotification({
    senderId: senderIdStr,
    receiverId: receiverIdStr,
    type: 'message_received',
    message: `${sender.name} sent you a message`,
    relatedId: newMessage._id.toString(),
  });

  const io = getIO();
  const receiverSocket = users[receiverIdStr];
  if (io && receiverSocket) {
    io.to(receiverSocket).emit('receiveMessage', {
      senderId: senderIdStr,
      senderName: sender.name,
      receiverId: receiverIdStr,
      receiverName: receiver.name,
      message: trimmedMessage,
      timestamp: newMessage.createdAt,
    });
  }

  return {
    _id: newMessage._id,
    senderId: senderIdStr,
    receiverId: receiverIdStr,
    message: trimmedMessage,
    createdAt: newMessage.createdAt,
    senderName: sender.name,
    receiverName: receiver.name,
  };
};

module.exports = { createAndDispatchMessage };
