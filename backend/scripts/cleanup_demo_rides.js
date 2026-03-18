/**
 * Aggressive cleanup: remove ALL rides except those created in the last 24 hours.
 * This wipes out all demo/test data including "Rahul Sharma" rides.
 * Run: node scripts/cleanup_demo_rides.js
 */
require('dotenv').config({ path: require('path').join(__dirname, '..', '.env') });
const mongoose = require('mongoose');
const Ride = require('../models/Ride');
const Booking = require('../models/Booking');
const RideRequest = require('../models/RideRequest');

async function main() {
  const mongoUri = process.env.MONGO_URI || process.env.MONGODB_URI;
  if (!mongoUri) {
    console.error('No MONGO_URI found in .env');
    process.exit(1);
  }

  await mongoose.connect(mongoUri);
  console.log('Connected to MongoDB');

  // Remove ALL rides older than 24 hours (wipes demo data like Rahul Sharma)
  const oneDayAgo = new Date(Date.now() - 24 * 60 * 60 * 1000);

  const oldRides = await Ride.find({ createdAt: { $lt: oneDayAgo } });
  console.log(`Found ${oldRides.length} old rides to remove`);

  for (const ride of oldRides) {
    await Booking.deleteMany({ ride: ride._id });
    await RideRequest.deleteMany({ rideId: ride._id });
    await Ride.deleteOne({ _id: ride._id });
    const driverName = ride.driverId ? ride.driverId.toString() : 'unknown';
    console.log(`  Deleted ride ${ride._id} (${ride.from} -> ${ride.to}) by driver ${driverName}`);
  }

  // Also delete completed and cancelled rides regardless of age
  const finishedRides = await Ride.find({ status: { $in: ['completed', 'cancelled'] } });
  for (const ride of finishedRides) {
    await Booking.deleteMany({ ride: ride._id });
    await RideRequest.deleteMany({ rideId: ride._id });
    await Ride.deleteOne({ _id: ride._id });
  }
  console.log(`Removed ${finishedRides.length} completed/cancelled rides`);

  const remaining = await Ride.countDocuments();
  console.log(`Done! ${remaining} rides remaining in database.`);

  await mongoose.disconnect();
  process.exit(0);
}

main().catch((err) => {
  console.error('Cleanup error:', err);
  process.exit(1);
});
