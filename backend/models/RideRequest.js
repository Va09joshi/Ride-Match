const mongoose = require('mongoose');

const rideRequestSchema = new mongoose.Schema({
  rideId: {
    type: mongoose.Schema.Types.ObjectId,
    ref: "Ride",
    required: true,
  },
  userId: {
    type: mongoose.Schema.Types.ObjectId,
    ref: "User",
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
  note: {
    type: String,
  },

  location: {
    type: {
      type: String,
      enum: ['Point'],
      default: 'Point',
    },
    coordinates: {
      type: [Number], // [longitude, latitude]
      required: true,
    },
  },

  status: {
    type: String,
    enum: ['requested', 'accepted', 'completed', 'cancelled'],
    default: 'requested',
  },

  matchedRide: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'Ride',
  },

  // ⭐ ADD THIS FIELD FOR LIKES ⭐
  likedBy: [
    {
      type: mongoose.Schema.Types.ObjectId,
      ref: "User",
    }
  ],

  createdAt: {
    type: Date,
    default: Date.now,
  },
});

rideRequestSchema.index({ location: '2dsphere' });

module.exports = mongoose.model('RideRequest', rideRequestSchema);
