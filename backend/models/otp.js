const mongoose = require("mongoose");

const otpSchema = new mongoose.Schema({
  email: { type: String, required: true, lowercase: true, trim: true },
  otp: { type: String, required: true },
  purpose: { type: String, default: 'password_reset' },
  createdAt: { type: Date, default: Date.now, expires: 300 }
});

module.exports = mongoose.model("OTP", otpSchema);
