const mongoose = require("mongoose");

const resetTokenSchema = new mongoose.Schema({
  phone: { type: String, required: true },
  token: { type: String, required: true },
  createdAt: { type: Date, default: Date.now, expires: 600 } // expires after 10 min
});

module.exports = mongoose.model("ResetToken", resetTokenSchema);
