const mongoose = require('mongoose');

const userSchema = new mongoose.Schema({
  name: { type: String, required: true, trim: true },
  email: { type: String, required: true, unique: true, lowercase: true, trim: true },
  password: { type: String, required: true },
  phone: { type: String, required: true, unique: true, trim: true },
  profileImage: { type: String, default: '' },
  role: { type: String, enum: ['user', 'admin'], default: 'user' },
  verification: {
    aadharNumber: { type: String, default: '' },
    aadharDocUrl: { type: String, default: '' },
    drivingLicenseNumber: { type: String, default: '' },
    drivingLicenseDocUrl: { type: String, default: '' },
    status: {
      type: String,
      enum: ['not_submitted', 'pending', 'verified', 'rejected'],
      default: 'not_submitted',
    },
    submittedAt: { type: Date, default: null },
  },
}, { timestamps: true });

module.exports = mongoose.model('User', userSchema);
