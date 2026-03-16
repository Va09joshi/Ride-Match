const express = require('express');
const mongoose = require('mongoose');
const cors = require('cors');
const http = require('http');
const { Server } = require('socket.io');
require('dotenv').config();

const { createAndDispatchMessage } = require('./helpers/chatMessageHelper');

// Socket manager (must be initialised before controllers that use it)
const socketManager = require('./config/socketManager');

// ROUTES
const authRoutes = require('./routes/auth');
const rideRoutes = require('./routes/ride');
const bookingRoutes = require('./routes/booking');
const notificationRoutes = require("./routes/notifications");
const profileRoutes = require('./routes/profileRoutes');
const chatRoutes = require('./routes/chats');
const chatHistoryRoutes = require('./routes/chathistory');
const likeRoutes = require("./routes/likeRoutes");
const messageRoutes = require('./routes/messageRoutes');
const userRoutes = require('./routes/users');
const paymentRoutes = require('./routes/payments');
const adminRoutes = require('./routes/admin');




const app = express();
app.use(cors());
app.use(express.json());

// API Routes
app.use('/api/auth', authRoutes);
app.use('/api/rides', rideRoutes);
app.use('/api/bookings', bookingRoutes);
app.use('/api/chat', chatRoutes);
app.use('/api/messages', messageRoutes);
app.use("/api/notifications", notificationRoutes);
app.use('/api/profile', profileRoutes);
app.use('/api/users', userRoutes);
app.use('/api/payments', paymentRoutes);
app.use('/api/admin', adminRoutes);
app.use("/api/chathistory", chatHistoryRoutes);
app.use("/api/like", likeRoutes);

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

// Expose io + users map to controllers
socketManager.setIO(io);
const users = socketManager.users;

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
      await createAndDispatchMessage({ senderId, receiverId, message });
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
