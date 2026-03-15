const User = require('../models/user');
const OTP = require('../models/otp'); // new OTP model
const bcrypt = require('bcryptjs');
const jwt = require('jsonwebtoken');
const client = require('../config/twilio'); // Twilio config

// ----------------- REGISTER -----------------
const registerUser = async (req, res) => {
  const { name, email, password, phone } = req.body;
  try {
    let user = await User.findOne({ email });
    if (user) return res.status(400).json({ success: false, message: 'User already exists' });

    const salt = await bcrypt.genSalt(10);
    const hashedPassword = await bcrypt.hash(password, salt);

    user = new User({ name, email, password: hashedPassword, phone });
    await user.save();

    const token = jwt.sign({ id: user._id }, process.env.JWT_SECRET, { expiresIn: '1d' });

    res.status(201).json({
      success: true,
      message: 'User created successfully',
      token,
      user: { id: user._id, name: user.name, email: user.email, phone: user.phone },
    });
  } catch (err) {
    res.status(500).json({ success: false, message: err.message });
  }
};

// ----------------- LOGIN -----------------
const loginUser = async (req, res) => {
  const { email, password } = req.body;
  try {
    const user = await User.findOne({ email });
    if (!user) return res.status(400).json({ success: false, message: 'Invalid credentials' });

    const isMatch = await bcrypt.compare(password, user.password);
    if (!isMatch) return res.status(400).json({ success: false, message: 'Invalid credentials' });

    const token = jwt.sign({ id: user._id }, process.env.JWT_SECRET, { expiresIn: '1d' });

    res.json({
      success: true,
      message: 'Login successful',
      token,
      user: { id: user._id, name: user.name, email: user.email, phone: user.phone },
    });
  } catch (err) {
    res.status(500).json({ success: false, message: err.message });
  }
};

// ----------------- GET USER PROFILE -----------------
const getUserProfile = async (req, res) => {
  try {
    const user = await User.findById(req.user.id).select('-password');
    if (!user) return res.status(404).json({ success: false, message: 'User not found' });

    res.json({
      success: true,
      user: { id: user._id, name: user.name, email: user.email, phone: user.phone },
    });
  } catch (err) {
    console.error(err);
    res.status(500).json({ success: false, message: 'Server error' });
  }
};

// ----------------- SEND OTP FOR FORGET PASSWORD -----------------
const sendOTP = async (req, res) => {
  const { phone } = req.body;
  try {
    const user = await User.findOne({ phone });
    if (!user) return res.status(404).json({ success: false, message: "User not found" });

    const otp = Math.floor(100000 + Math.random() * 900000).toString();
    await OTP.create({ phone, otp });

    await client.messages.create({
      body: `Your OTP for password reset is ${otp}`,
      messagingServiceSid: process.env.TWILIO_MESSAGING_SERVICE_SID,
      to: phone
    });

    res.status(200).json({ success: true, message: "OTP sent successfully" });
  } catch (err) {
    console.error(err);
    res.status(500).json({ success: false, message: "Failed to send OTP" });
  }
};

// ----------------- VERIFY OTP -----------------
const verifyOTP = async (req, res) => {
  const { phone, otp } = req.body;
  try {
    const record = await OTP.findOne({ phone }).sort({ createdAt: -1 });
    if (!record) return res.status(400).json({ success: false, message: "OTP expired or not found" });
    if (record.otp !== otp) return res.status(400).json({ success: false, message: "Invalid OTP" });

    res.status(200).json({ success: true, message: "OTP verified successfully" });
  } catch (err) {
    console.error(err);
    res.status(500).json({ success: false, message: "OTP verification failed" });
  }
};

// ----------------- RESET PASSWORD -----------------
const resetPassword = async (req, res) => {
  const { phone, newPassword } = req.body;
  try {
    const user = await User.findOne({ phone });
    if (!user) return res.status(404).json({ success: false, message: "User not found" });

    const salt = await bcrypt.genSalt(10);
    user.password = await bcrypt.hash(newPassword, salt);
    await user.save();

    res.status(200).json({ success: true, message: "Password reset successfully" });
  } catch (err) {
    console.error(err);
    res.status(500).json({ success: false, message: "Password reset failed" });
  }
};

module.exports = { 
  registerUser, 
  loginUser, 
  getUserProfile, 
  sendOTP, 
  verifyOTP, 
  resetPassword 
};
