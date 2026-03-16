const mongoose = require('mongoose');

const paymentMethodSchema = new mongoose.Schema(
  {
    userId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'User',
      required: true,
      index: true,
    },
    type: {
      type: String,
      enum: ['card', 'upi', 'bank', 'wallet'],
      required: true,
    },
    label: { type: String, required: true, trim: true },
    holderName: { type: String, default: '', trim: true },
    last4: { type: String, default: '' },
    isDefault: { type: Boolean, default: false },
    meta: { type: Object, default: {} },
  },
  { timestamps: true },
);

module.exports = mongoose.model('PaymentMethod', paymentMethodSchema);
