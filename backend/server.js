const express = require('express');
const mongoose = require('mongoose');
const cors = require('cors');
const http = require('http');
const { Server } = require('socket.io');
require('dotenv').config();

// MODELS
const Message = require('./models/Message');
const User = require('./models/user');
const Chat = require('./models/chat'); // <-- IMPORTANT

// ROUTES
const authRoutes = require('./routes/auth');
const rideRoutes = require('./routes/ride');
const bookingRoutes = require('./routes/booking');
const notificationRoutes = require("./routes/notifications");
const profileRoutes = require('./routes/profileRoutes');
const chatRoutes = require('./routes/chats');
const chatHistoryRoutes = require('./routes/chathistory');
const likeRoutes = require("./routes/likeRoutes");




const app = express();
app.use(cors());
app.use(express.json());

// API Routes
app.use('/api/auth', authRoutes);
app.use('/api/rides', rideRoutes);
app.use('/api/bookings', bookingRoutes);
app.use('/api/chat', chatRoutes);
app.use("/api/notifications", notificationRoutes);
app.use('/api/profile', profileRoutes);
app.use("/api/chathistory", chatHistoryRoutes);
app.use("/api/like", likeRoutes);
app.use("/api/notifications", notificationRoutes);

app.use("/api/ride-request", require("./routes/rideRequestRoutes"));



app.get('/', (req, res) => {
    res.send('Carpool Backend Running');
});

// MongoDB Connection
mongoose.connect(process.env.MONGO_URI, { useNewUrlParser: true, useUnifiedTopology: true })
.then(() => console.log('✅ MongoDB Connected'))
.catch(err => console.log(err));

// HTTP + WebSocket Server
const server = http.createServer(app);
const io = new Server(server, {
    cors: {
        origin: '*',
        methods: ['GET', 'POST']
    }
});

const users = {}; // Track online users

io.on('connection', (socket) => {
  console.log('🟢 User connected:', socket.id);

  // Register users
  socket.on('register', (userId) => {
    users[userId] = socket.id;
    console.log(`✅ User ${userId} registered`);
  });

  //  MESSAGE SENDING LOGIC
  // ------------------------
  socket.on('sendMessage', async (data) => {
    const { senderId, receiverId, message } = data;
    console.log(`💬 ${senderId} -> ${receiverId}: ${message}`);

    try {
      // Fetch sender and receiver
      const sender = await User.findById(senderId);
      const receiver = await User.findById(receiverId);

      if (!sender || !receiver) {
        console.log('❌ Sender or receiver not found');
        return;
      }

      // 1️ Save message to DB
      const newMessage = await Message.create({
        senderId,
        senderName: sender.name,
        receiverId,
        receiverName: receiver.name,
        message,
      });

      // 2️ FIND OR CREATE CHAT
      let chat = await Chat.findOne({
        users: { $all: [senderId, receiverId] }
      });

      if (!chat) {
        chat = new Chat({
          users: [senderId, receiverId],
          unreadCount: {
            [senderId]: 0,
            [receiverId]: 0
          }
        });
      }

      //  UPDATE CHAT SUMMARY
      chat.lastMessage = message;
      chat.lastMessageTime = new Date();

      // Increase unread count for receiver
      chat.unreadCount.set(receiverId, (chat.unreadCount.get(receiverId) || 0) + 1);

      await chat.save();

      // 4️ Send message to receiver if online
      const receiverSocket = users[receiverId];
      if (receiverSocket) {
        io.to(receiverSocket).emit('receiveMessage', {
          senderId,
          senderName: sender.name,
          receiverName: receiver.name,
          message,
          timestamp: newMessage.createdAt,
        });
      }

    } catch (err) {
      console.error('Error saving message:', err);
    }
  });

  // Handle disconnect
  socket.on('disconnect', () => {
    console.log('🔴 User disconnected:', socket.id);
    Object.keys(users).forEach(uid => {
      if (users[uid] === socket.id) delete users[uid];
    });
  });
});

// Start server
const PORT = process.env.PORT || 5000;
server.listen(PORT, "0.0.0.0", () => {
    console.log(`🚀 Server running with WebSocket at http://192.168.29.206:${PORT}`);
});
