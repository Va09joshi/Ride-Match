const mongoose = require('mongoose');

const termsAndConditionsSchema = new mongoose.Schema(
  {
    title: { type: String, default: 'Terms & Conditions', trim: true },
    content: { type: String, required: true },
    version: { type: String, default: '1.0.0' },
    isActive: { type: Boolean, default: true },
  },
  { timestamps: true },
);

module.exports = mongoose.model('TermsAndConditions', termsAndConditionsSchema);
