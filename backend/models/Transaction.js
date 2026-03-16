const mongoose = require('mongoose');

const transactionSchema = new mongoose.Schema(
  {
    userId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'User',
      required: true,
      index: true,
    },
    paymentMethodId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'PaymentMethod',
      default: null,
    },
    type: {
      type: String,
      enum: ['ride_booking', 'wallet_topup', 'refund', 'other'],
      default: 'ride_booking',
    },
    amount: { type: Number, required: true, min: 0 },
    currency: { type: String, default: 'INR' },
    status: {
      type: String,
      enum: ['pending', 'success', 'failed', 'refunded'],
      default: 'success',
    },
    referenceId: { type: String, default: '' },
    description: { type: String, default: '' },
  },
  { timestamps: true },
);

module.exports = mongoose.model('Transaction', transactionSchema);
