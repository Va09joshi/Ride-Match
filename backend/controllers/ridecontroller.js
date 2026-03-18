const Ride = require('../models/Ride');
const RideRequest = require('../models/RideRequest');
const Booking = require('../models/Booking');
const mongoose = require("mongoose");
const {
  parseRideDepartureDate,
  syncRideLifecycles,
} = require('./rideLifecycle');
const { createNotification } = require('../helpers/notificationHelper');
const { createAndDispatchMessage } = require('../helpers/chatMessageHelper');

// Utility function to validate ObjectId
const isValidId = (id) =>
  id &&
  id !== "null" &&
  id !== "undefined" &&
  mongoose.Types.ObjectId.isValid(id);

const getRideDepartureDate = (ride) => {
  return parseRideDepartureDate(ride);
};

const isUpcomingRide = (ride) => {
  const departure = getRideDepartureDate(ride);
  if (!departure) return true;
  return departure.getTime() > Date.now();
};

const getRequestDepartureDate = (request) => {
  const rawDate = (request?.date || '').toString().trim();
  const rawTime = (request?.time || '').toString().trim();
  if (!rawDate || !rawTime) return null;

  const dateParts = rawDate.split(/[-/]/);
  if (dateParts.length !== 3) return null;

  const year = parseInt(dateParts[0], 10);
  const month = parseInt(dateParts[1], 10);
  const day = parseInt(dateParts[2], 10);
  const timeParts = rawTime.split(':');
  const hour = parseInt(timeParts[0], 10);
  const minute = timeParts.length > 1 ? parseInt(timeParts[1], 10) : 0;

  if ([year, month, day, hour, minute].some((n) => Number.isNaN(n))) {
    return null;
  }

  return new Date(year, month - 1, day, hour, minute);
};

const isUpcomingRequest = (request) => {
  const departure = getRequestDepartureDate(request);
  if (!departure) return true;
  return departure.getTime() > Date.now();
};

// -------------------------------------------------------
// CREATE RIDE
// -------------------------------------------------------
exports.createRide = async (req, res) => {
  try {
    const {
      driverId,
      from,
      to,
      date,
      time,
      availableSeats,
      amount,
      carDetails,
      location,
      pickupLocation,
      dropLocation,
      routeDistanceKm,
    } = req.body;

    if (!isValidId(driverId)) {
      return res.status(400).json({ success: false, message: "Invalid driverId" });
    }

    const ride = new Ride({
      driverId,
      from,
      to,
      date,
      time,
      availableSeats,
      amount,
      status: 'created',
      carDetails,
      location,
      pickupLocation,
      dropLocation,
      routeDistanceKm,
    });

    await ride.save();

    // Notify the driver that their ride has been posted
    createNotification({
      senderId: driverId,
      receiverId: driverId,
      type: 'ride_created',
      message: `Your ride from ${from} to ${to} has been posted successfully.`,
      relatedId: ride._id.toString(),
    });

    res.status(201).json({ message: 'Ride created successfully', ride });
  } catch (error) {
    console.error('Error creating ride:', error);
    res.status(500).json({ error: 'Failed to create ride', details: error.message });
  }
};

// -------------------------------------------------------
// GET ALL RIDES
// -------------------------------------------------------
exports.getRides = async (req, res) => {
  try {
    const { excludeUserId } = req.query;

    const query = {
      $or: [
        { status: { $in: ['created', 'active', 'in_progress'] } },
        { status: { $exists: false } },
        { status: null },
      ],
      availableSeats: { $gt: 0 },
    };
    if (isValidId(excludeUserId)) {
      query.driverId = { $ne: excludeUserId };
    }

    const rides = await Ride.find(query)
      .populate('driverId', 'name email phone profileImage')
      .sort({ createdAt: -1 });

    await syncRideLifecycles(rides);
    const filtered = rides.filter((ride) => isUpcomingRide(ride));
    res.status(200).json({ success: true, rides: filtered });
  } catch (error) {
    console.error('Error fetching rides:', error);
    res.status(500).json({ success: false, message: 'Server error', error });
  }
};

// -------------------------------------------------------
// GET NEARBY RIDES
// -------------------------------------------------------
exports.getNearbyRides = async (req, res) => {
  try {
    const { longitude, latitude, maxDistance = 40000, excludeUserId } = req.query;

    if (!longitude || !latitude) {
      return res.status(400).json({
        success: false,
        message: 'Longitude and latitude are required',
      });
    }

    const query = {
      $or: [
        { status: { $in: ['created', 'active', 'in_progress'] } },
        { status: { $exists: false } },
        { status: null },
      ],
      availableSeats: { $gt: 0 },
      location: {
        $near: {
          $geometry: { type: 'Point', coordinates: [parseFloat(longitude), parseFloat(latitude)] },
          $maxDistance: parseFloat(maxDistance),
        },
      },
    };

    if (isValidId(excludeUserId)) {
      query.driverId = { $ne: excludeUserId };
    }

    const rides = await Ride.find(query).populate('driverId', 'name email phone profileImage');

    await syncRideLifecycles(rides);
    const filtered = rides.filter((ride) => isUpcomingRide(ride));

    res.status(200).json({ success: true, rides: filtered });
  } catch (error) {
    console.error('Error fetching nearby rides:', error);
    res.status(500).json({ success: false, message: 'Server error', error });
  }
};

// -------------------------------------------------------
// GET USER RIDES (DRIVER RIDES)
// -------------------------------------------------------
exports.getUserRides = async (req, res) => {
  try {
    const { userId } = req.params;
    const { status } = req.query;

    if (!isValidId(userId)) {
      return res.status(400).json({ success: false, message: "Invalid userId" });
    }

    const query = { driverId: userId };
    if (status === 'active') {
      query.$or = [
        { status: { $in: ['created', 'active', 'in_progress'] } },
        { status: { $exists: false } },
        { status: null },
      ];
    } else if (['cancelled', 'completed'].includes(status)) {
      query.status = status;
    }

    const rides = await Ride.find(query)
      .sort({ createdAt: -1 })
      .populate('driverId', 'name email phone profileImage');

    await syncRideLifecycles(rides);

    res.status(200).json({
      success: true,
      count: rides.length,
      rides,
    });

  } catch (error) {
    console.error("Error fetching user's rides:", error);
    res.status(500).json({ success: false, message: 'Server error', error });
  }
};

// -------------------------------------------------------
// CANCEL RIDE (DRIVER)
// -------------------------------------------------------
exports.cancelRide = async (req, res) => {
  try {
    const { rideId } = req.params;
    const authUserId = req.user?.id;

    if (!isValidId(rideId)) {
      return res.status(400).json({ success: false, message: 'Invalid rideId' });
    }

    const ride = await Ride.findById(rideId);
    if (!ride) {
      return res.status(404).json({ success: false, message: 'Ride not found' });
    }

    if (!authUserId || ride.driverId.toString() !== authUserId.toString()) {
      return res.status(403).json({ success: false, message: 'Only the driver can cancel this ride' });
    }

    if (ride.status === 'cancelled') {
      return res.status(200).json({ success: true, message: 'Ride already cancelled', ride });
    }

    ride.status = 'cancelled';
    ride.cancelledAt = new Date();
    await ride.save();

    // Notify all passengers who booked this ride
    try {
      const bookings = await Booking.find({ ride: rideId, status: 'booked' });
      for (const booking of bookings) {
        createNotification({
          senderId: authUserId,
          receiverId: booking.user.toString(),
          type: 'ride_cancelled',
          message: `Your ride from ${ride.from} to ${ride.to} has been cancelled by the driver.`,
          relatedId: rideId,
        });
      }
    } catch (notifErr) {
      console.error('Error sending cancellation notifications:', notifErr.message);
    }

    return res.status(200).json({ success: true, message: 'Ride cancelled successfully', ride });
  } catch (error) {
    console.error('Error cancelling ride:', error);
    return res.status(500).json({ success: false, message: 'Server error' });
  }
};

// -------------------------------------------------------
// COMPLETE RIDE (DRIVER)
// -------------------------------------------------------
exports.completeRide = async (req, res) => {
  try {
    const { rideId } = req.params;
    const authUserId = req.user?.id;

    if (!isValidId(rideId)) {
      return res.status(400).json({ success: false, message: 'Invalid rideId' });
    }

    const ride = await Ride.findById(rideId);
    if (!ride) {
      return res.status(404).json({ success: false, message: 'Ride not found' });
    }

    if (!authUserId || ride.driverId.toString() !== authUserId.toString()) {
      return res.status(403).json({ success: false, message: 'Only the driver can complete this ride' });
    }

    if (ride.status === 'completed') {
      return res.status(200).json({ success: true, message: 'Ride already completed', ride });
    }

    ride.status = 'completed';
    ride.completedAt = new Date();
    await ride.save();

    return res.status(200).json({ success: true, message: 'Ride marked as completed', ride });
  } catch (error) {
    console.error('Error completing ride:', error);
    return res.status(500).json({ success: false, message: 'Server error' });
  }
};

// -------------------------------------------------------
// START RIDE (DRIVER)
// -------------------------------------------------------
exports.startRide = async (req, res) => {
  try {
    const { rideId } = req.params;
    const authUserId = req.user?.id;

    if (!isValidId(rideId)) {
      return res.status(400).json({ success: false, message: 'Invalid rideId' });
    }

    const ride = await Ride.findById(rideId);
    if (!ride) {
      return res.status(404).json({ success: false, message: 'Ride not found' });
    }

    if (!authUserId || ride.driverId.toString() !== authUserId.toString()) {
      return res.status(403).json({ success: false, message: 'Only the driver can start this ride' });
    }

    if (ride.status === 'in_progress') {
      return res.status(200).json({ success: true, message: 'Ride already in progress', ride });
    }

    ride.status = 'in_progress';
    ride.startedAt = new Date();
    await ride.save();

    return res.status(200).json({ success: true, message: 'Ride started successfully', ride });
  } catch (error) {
    console.error('Error starting ride:', error);
    return res.status(500).json({ success: false, message: 'Server error' });
  }
};

// -------------------------------------------------------
// CREATE RIDE REQUEST
// -------------------------------------------------------
exports.requestRide = async (req, res) => {
  try {
    const { rideId } = req.params;
    const { userId, from, to, date, time, note, location } = req.body;
    const authUserId = req.user?.id;

    if (!isValidId(rideId) || !isValidId(userId)) {
      return res.status(400).json({ success: false, message: "Invalid rideId or userId" });
    }

    if (!authUserId || authUserId.toString() !== userId.toString()) {
      return res.status(403).json({ success: false, message: 'You can only create requests for your own account' });
    }

    if (!from || !to || !date || !time || !location?.coordinates) {
      return res.status(400).json({
        success: false,
        message: "Missing required fields"
      });
    }

    const ride = await Ride.findById(rideId);
    if (!ride) return res.status(404).json({ success: false, message: "Ride not found" });

    if (ride.availableSeats <= 0)
      return res.status(400).json({ success: false, message: "No seats available" });

    const existing = await RideRequest.findOne({ rideId, userId });
    if (existing)
      return res.status(400).json({ success: false, message: "Already requested" });

    const request = new RideRequest({
      rideId,
      userId,
      from,
      to,
      date,
      time,
      note,
      location,
      status: "requested"
    });

    await request.save();

    res.status(201).json({ success: true, message: "Ride request created", request });
  } catch (err) {
    console.error("Request Error:", err);
    res.status(500).json({ success: false, message: "Server error", error: err.message });
  }
};

// -------------------------------------------------------
// DRIVER ACCEPT / REJECT REQUEST
// -------------------------------------------------------
exports.respondToRequest = async (req, res) => {
  try {
    const { rideId } = req.params;
    const { userId, status } = req.body;
    const authUserId = req.user?.id;

    if (!isValidId(rideId) || !isValidId(userId)) {
      return res.status(400).json({ success: false, message: "Invalid rideId or userId" });
    }

    const normalizedStatus = (status || '').toString().toLowerCase();
    if (!['accepted', 'rejected'].includes(normalizedStatus)) {
      return res.status(400).json({ success: false, message: 'Status must be accepted or rejected' });
    }

    const ride = await Ride.findById(rideId).populate('driverId', 'name');
    if (!ride) {
      return res.status(404).json({ success: false, message: 'Ride not found' });
    }

    if (!authUserId || ride.driverId?._id?.toString() !== authUserId.toString()) {
      return res.status(403).json({ success: false, message: 'Only the ride driver can respond to requests' });
    }

    const request = await RideRequest.findOne({ rideId, userId });
    if (!request)
      return res.status(404).json({ success: false, message: "Request not found" });

    if (normalizedStatus === 'rejected') {
      // Permanent removal for rejected requests.
      await RideRequest.deleteOne({ _id: request._id });

      createNotification({
        senderId: req.user?.id || null,
        receiverId: userId,
        type: 'ride_request_declined',
        message: 'Your ride request has been declined by the driver.',
        relatedId: rideId,
      });

      return res.status(200).json({
        success: true,
        message: 'Request rejected and removed permanently',
        removed: true,
      });
    }

    request.status = normalizedStatus;
    await request.save();

    const defaultMessage = `Hi! Your ride request from ${request.from} to ${request.to} has been accepted. We can coordinate pickup details here.`;
    await createAndDispatchMessage({
      senderId: ride.driverId._id.toString(),
      receiverId: userId.toString(),
      message: defaultMessage,
    });

    // Notify the requester of the driver's decision
    createNotification({
      senderId: req.user?.id || null,
      receiverId: userId,
      type: 'ride_request_accepted',
      message: 'Your ride request has been accepted by the driver.',
      relatedId: rideId,
    });

    res.status(200).json({
      success: true,
      message: 'Request accepted successfully',
      request
    });

  } catch (error) {
    console.error('Error updating request:', error);
    res.status(500).json({ success: false, message: 'Server error', error });
  }
};

// -------------------------------------------------------
// GET USER'S OWN REQUESTS
// -------------------------------------------------------
exports.getUserRequests = async (req, res) => {
  try {
    const { userId } = req.params;

    if (!isValidId(userId)) {
      return res.status(400).json({ success: false, message: "Invalid userId" });
    }

    const requests = await RideRequest.find({ userId })
      .populate("rideId")
      .populate("userId", "name email profileImage")
      .sort({ createdAt: -1 });

    const upcomingRequests = requests.filter((request) => isUpcomingRequest(request));

    res.status(200).json({ success: true, count: upcomingRequests.length, requests: upcomingRequests });

  } catch (error) {
    console.error('Error fetching user requests:', error);
    res.status(500).json({ success: false, message: 'Server error', error });
  }
};

// -------------------------------------------------------
// GET NEARBY RIDE REQUESTS
// -------------------------------------------------------
exports.getNearbyRideRequests = async (req, res) => {
  try {
    const { longitude, latitude, maxDistance = 40000 } = req.query;

    if (!longitude || !latitude)
      return res.status(400).json({ success: false, message: "Longitude & Latitude required" });

    const requests = await RideRequest.find({
      status: 'requested',
      location: {
        $near: {
          $geometry: { type: "Point", coordinates: [parseFloat(longitude), parseFloat(latitude)] },
          $maxDistance: parseFloat(maxDistance),
        },
      },
    })
      .sort({ createdAt: -1 })
      .populate("rideId")
      .populate("userId", "name email profileImage");

    const upcomingRequests = requests.filter((request) => isUpcomingRequest(request));

    const expiredRequestedIds = requests
      .filter((request) => !isUpcomingRequest(request))
      .map((request) => request._id);

    if (expiredRequestedIds.length > 0) {
      await RideRequest.deleteMany({ _id: { $in: expiredRequestedIds }, status: 'requested' });
    }

    res.status(200).json({ success: true, requests: upcomingRequests });

  } catch (err) {
    console.error("Nearby Request Error:", err);
    res.status(500).json({ success: false, message: "Server error" });
  }
};

// -------------------------------------------------------
// GET INCOMING REQUESTS FOR DRIVER
// -------------------------------------------------------
exports.getIncomingRequestsForDriver = async (req, res) => {
  try {
    const { driverId } = req.params;
    const authUserId = req.user?.id;

    if (!isValidId(driverId)) {
      return res.status(400).json({ success: false, message: "Invalid driverId" });
    }

    if (!authUserId || authUserId.toString() !== driverId.toString()) {
      return res.status(403).json({ success: false, message: 'Unauthorized access' });
    }

    const rides = await Ride.find({
      driverId,
      $or: [
        { status: { $in: ['created', 'active', 'in_progress'] } },
        { status: { $exists: false } },
        { status: null },
      ],
    });

    const rideIds = rides.map(r => r._id);

    const requests = await RideRequest.find({
      rideId: { $in: rideIds },
      status: 'requested',
    })
      .sort({ createdAt: -1 })
      .populate("rideId", "from to date time amount availableSeats status")
      .populate("userId", "name email phone profileImage");

    res.status(200).json({ success: true, count: requests.length, requests });

  } catch (err) {
    console.error("Driver Requests Error:", err);
    res.status(500).json({ success: false, message: "Server error" });
  }
};


exports.toggleLike = async (req, res) => {
  try {
    const { requestId, userId } = req.body;

    let request = await RideRequest.findById(requestId);

    if (!request) {
      return res.status(404).json({ message: "Request not found" });
    }

    const alreadyLiked = request.likedBy.includes(userId);

    if (alreadyLiked) {
      // UNLIKE
      request.likedBy.pull(userId);
    } else {
      // LIKE
      request.likedBy.push(userId);
    }

    await request.save();

    return res.status(200).json({
      liked: !alreadyLiked,
      likedBy: request.likedBy.length
    });

  } catch (e) {
    console.log(e);
    res.status(500).json({ message: "Server error" });
  }
};
