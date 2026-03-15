const mongoose = require('mongoose');

const rideSchema = new mongoose.Schema({
  driverId: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'User',
    required: true,
  },
  from: {
    type: String,
    required: true,
  },
  to: {
    type: String,
    required: true,
  },
  date: {
    type: String,
    required: true,
  },
  time: {
    type: String,
    required: true,
  },
  availableSeats: {
    type: Number,
    required: true,
  },
  amount: {
    type: Number,
    required: true,
  },
  carDetails: {
    name: { type: String, required: true },
    number: { type: String, required: true },
    color: { type: String, required: true },
  },
  location: {
    type: {
      type: String,
      enum: ['Point'],
      default: 'Point',
    },
    coordinates: {
      type: [Number], // [longitude, latitude]
      required: false,
    },
  },
  createdAt: {
    type: Date,
    default: Date.now,
  },
});

rideSchema.index({ location: '2dsphere' });

module.exports = mongoose.model('Ride', rideSchema);
