const crypto = require('crypto');
const bcrypt = require('bcryptjs');
const jwt = require('jsonwebtoken');
const User = require('../models/user');
const OTP = require('../models/otp');
const ResetToken = require('../models/Resettoken');
const { sendMail } = require('../config/mailer');

const EMAIL_REGEX = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
const OTP_EXPIRY_MINUTES = 5;

const normalizeEmail = (email = '') => email.trim().toLowerCase();
const normalizePhone = (phone = '') => phone.trim();

const isValidEmail = (email) => EMAIL_REGEX.test(email);

const createAuthToken = (user) => jwt.sign({ id: user._id }, process.env.JWT_SECRET, { expiresIn: '1d' });

const serializeUser = (user) => ({
  id: user._id,
  name: user.name,
  email: user.email,
  phone: user.phone,
  profileImage: user.profileImage,
  role: user.role || 'user',
  verification: user.verification || {},
  createdAt: user.createdAt,
});

const createNumericOtp = () => Math.floor(100000 + Math.random() * 900000).toString();

const sendPasswordResetOtpEmail = async (email, otp, name) => {
  const subject = 'RideMatch password reset OTP';
  const text = `Hi ${name},\n\nYour RideMatch password reset OTP is ${otp}. It expires in ${OTP_EXPIRY_MINUTES} minutes.\n\nIf you did not request this, you can ignore this email.`;
  const html = `
    <div style="font-family: Arial, sans-serif; line-height: 1.5; color: #1f2937;">
      <h2 style="margin-bottom: 8px;">RideMatch password reset</h2>
      <p>Hi ${name},</p>
      <p>Use the OTP below to reset your password:</p>
      <div style="font-size: 28px; font-weight: 700; letter-spacing: 6px; margin: 16px 0; color: #0A2647;">${otp}</div>
      <p>This OTP expires in ${OTP_EXPIRY_MINUTES} minutes.</p>
      <p>If you did not request a password reset, you can ignore this email.</p>
    </div>
  `;

  await sendMail({ to: email, subject, text, html });
};

const registerUser = async (req, res) => {
  const { name, email, password, phone } = req.body;

  try {
    const normalizedEmail = normalizeEmail(email);
    const normalizedPhone = normalizePhone(phone);

    if (!name?.trim() || !normalizedEmail || !normalizedPhone || !password?.trim()) {
      return res.status(400).json({ success: false, message: 'Full name, email, phone number, and password are required' });
    }

    if (!isValidEmail(normalizedEmail)) {
      return res.status(400).json({ success: false, message: 'Please enter a valid email address' });
    }

    if (password.trim().length < 6) {
      return res.status(400).json({ success: false, message: 'Password must be at least 6 characters long' });
    }

    const existingUser = await User.findOne({
      $or: [{ email: normalizedEmail }, { phone: normalizedPhone }],
    });

    if (existingUser?.email === normalizedEmail) {
      return res.status(409).json({ success: false, message: 'Email is already registered' });
    }

    if (existingUser?.phone === normalizedPhone) {
      return res.status(409).json({ success: false, message: 'Phone number is already registered' });
    }

    const salt = await bcrypt.genSalt(10);
    const hashedPassword = await bcrypt.hash(password.trim(), salt);

    const user = new User({
      name: name.trim(),
      email: normalizedEmail,
      password: hashedPassword,
      phone: normalizedPhone,
    });
    await user.save();

    const token = createAuthToken(user);

    res.status(201).json({
      success: true,
      message: 'User created successfully',
      token,
      user: serializeUser(user),
    });
  } catch (err) {
    res.status(500).json({ success: false, message: err.message });
  }
};

const loginUser = async (req, res) => {
  const { email, password } = req.body;

  try {
    const normalizedEmail = normalizeEmail(email);

    if (!normalizedEmail || !password?.trim()) {
      return res.status(400).json({ success: false, message: 'Email and password are required' });
    }

    const user = await User.findOne({ email: normalizedEmail });
    if (!user) return res.status(400).json({ success: false, message: 'Invalid credentials' });

    const isMatch = await bcrypt.compare(password, user.password);
    if (!isMatch) return res.status(400).json({ success: false, message: 'Invalid credentials' });

    const token = createAuthToken(user);

    res.json({
      success: true,
      message: 'Login successful',
      token,
      user: serializeUser(user),
    });
  } catch (err) {
    res.status(500).json({ success: false, message: err.message });
  }
};

const getUserProfile = async (req, res) => {
  try {
    const user = await User.findById(req.user.id).select('-password');
    if (!user) return res.status(404).json({ success: false, message: 'User not found' });

    res.json({
      success: true,
      user: serializeUser(user),
    });
  } catch (err) {
    console.error(err);
    res.status(500).json({ success: false, message: 'Server error' });
  }
};

const updateUserProfile = async (req, res) => {
  const { name, email, phone, password } = req.body;

  try {
    const user = await User.findById(req.user.id);
    if (!user) {
      return res.status(404).json({ success: false, message: 'User not found' });
    }

    const normalizedEmail = typeof email === 'string' ? normalizeEmail(email) : undefined;
    const normalizedPhone = typeof phone === 'string' ? normalizePhone(phone) : undefined;

    if (normalizedEmail && normalizedEmail !== user.email) {
      if (!isValidEmail(normalizedEmail)) {
        return res.status(400).json({ success: false, message: 'Please enter a valid email address' });
      }

      const existing = await User.findOne({ email: normalizedEmail });
      if (existing && existing._id.toString() !== user._id.toString()) {
        return res.status(400).json({ success: false, message: 'Email already in use' });
      }
      user.email = normalizedEmail;
    }

    if (normalizedPhone && normalizedPhone !== user.phone) {
      const existingPhone = await User.findOne({ phone: normalizedPhone });
      if (existingPhone && existingPhone._id.toString() !== user._id.toString()) {
        return res.status(400).json({ success: false, message: 'Phone number already in use' });
      }
      user.phone = normalizedPhone;
    }

    if (typeof name === 'string' && name.trim()) user.name = name.trim();

    if (typeof password === 'string' && password.trim().length > 0) {
      if (password.trim().length < 6) {
        return res.status(400).json({ success: false, message: 'Password must be at least 6 characters long' });
      }

      const salt = await bcrypt.genSalt(10);
      user.password = await bcrypt.hash(password.trim(), salt);
    }

    await user.save();

    return res.status(200).json({
      success: true,
      message: 'Profile updated successfully',
      user: serializeUser(user),
    });
  } catch (err) {
    console.error(err);
    return res.status(500).json({ success: false, message: 'Failed to update profile' });
  }
};

const sendOTP = async (req, res) => {
  const normalizedEmail = normalizeEmail(req.body.email);

  try {
    if (!normalizedEmail) {
      return res.status(400).json({ success: false, message: 'Email is required' });
    }

    if (!isValidEmail(normalizedEmail)) {
      return res.status(400).json({ success: false, message: 'Please enter a valid email address' });
    }

    const user = await User.findOne({ email: normalizedEmail });
    if (!user) return res.status(404).json({ success: false, message: "User not found" });

    const rawOtp = createNumericOtp();
    const hashedOtp = await bcrypt.hash(rawOtp, 10);

    await OTP.deleteMany({ email: normalizedEmail, purpose: 'password_reset' });
    await ResetToken.deleteMany({ email: normalizedEmail });
    await OTP.create({ email: normalizedEmail, otp: hashedOtp, purpose: 'password_reset' });

    // Try sending with retry (reset transporter cache on first failure)
    let lastErr;
    for (let attempt = 0; attempt < 2; attempt++) {
      try {
        await sendPasswordResetOtpEmail(normalizedEmail, rawOtp, user.name);
        return res.status(200).json({ success: true, message: "OTP sent successfully" });
      } catch (sendErr) {
        lastErr = sendErr;
        console.error(`Email send attempt ${attempt + 1} failed:`, sendErr.message || sendErr.code);
        // Reset the transporter cache so next attempt creates fresh connection
        try { require('../config/mailer').resetTransporter?.(); } catch (_) {}
      }
    }

    // Both attempts failed
    console.error('All email attempts failed:', lastErr);
    const transportErrorCodes = ['ENETUNREACH', 'ETIMEDOUT', 'ESOCKET', 'ECONNECTION', 'ECONNREFUSED'];
    const isTransportError = transportErrorCodes.includes(lastErr?.code);
    const message = isTransportError
      ? 'Email service is temporarily unavailable. Please try again in a few minutes.'
      : (lastErr?.message || 'Failed to send OTP');

    res.status(500).json({ success: false, message });
  } catch (err) {
    console.error('sendOTP error:', err);
    res.status(500).json({ success: false, message: err?.message || 'Failed to send OTP' });
  }
};

const verifyOTP = async (req, res) => {
  const normalizedEmail = normalizeEmail(req.body.email);
  const submittedOtp = req.body.otp?.trim();

  try {
    if (!normalizedEmail || !submittedOtp) {
      return res.status(400).json({ success: false, message: 'Email and OTP are required' });
    }

    const record = await OTP.findOne({ email: normalizedEmail, purpose: 'password_reset' }).sort({ createdAt: -1 });
    if (!record) return res.status(400).json({ success: false, message: "OTP expired or not found" });

    const isValidOtp = await bcrypt.compare(submittedOtp, record.otp);
    if (!isValidOtp) return res.status(400).json({ success: false, message: "Invalid OTP" });

    const resetToken = crypto.randomBytes(32).toString('hex');
    await ResetToken.deleteMany({ email: normalizedEmail });
    await ResetToken.create({ email: normalizedEmail, token: resetToken });
    await OTP.deleteMany({ email: normalizedEmail, purpose: 'password_reset' });

    res.status(200).json({
      success: true,
      message: "OTP verified successfully",
      resetToken,
    });
  } catch (err) {
    console.error(err);
    res.status(500).json({ success: false, message: "OTP verification failed" });
  }
};

const resetPassword = async (req, res) => {
  const normalizedEmail = normalizeEmail(req.body.email);
  const newPassword = req.body.newPassword?.trim();
  const resetToken = req.body.resetToken?.trim();

  try {
    if (!normalizedEmail || !newPassword || !resetToken) {
      return res.status(400).json({ success: false, message: 'Email, reset token, and new password are required' });
    }

    if (newPassword.length < 6) {
      return res.status(400).json({ success: false, message: 'Password must be at least 6 characters long' });
    }

    const user = await User.findOne({ email: normalizedEmail });
    if (!user) return res.status(404).json({ success: false, message: "User not found" });

    const storedResetToken = await ResetToken.findOne({ email: normalizedEmail, token: resetToken });
    if (!storedResetToken) {
      return res.status(400).json({ success: false, message: 'Reset session expired or invalid. Verify the OTP again.' });
    }

    const salt = await bcrypt.genSalt(10);
    user.password = await bcrypt.hash(newPassword, salt);
    await user.save();
    await ResetToken.deleteMany({ email: normalizedEmail });
    await OTP.deleteMany({ email: normalizedEmail, purpose: 'password_reset' });

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
  updateUserProfile,
  sendOTP, 
  verifyOTP, 
  resetPassword 
};
