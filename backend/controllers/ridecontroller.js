const Ride = require('../models/Ride');
const RideRequest = require('../models/RideRequest');
const mongoose = require("mongoose");

// Utility function to validate ObjectId
const isValidId = (id) =>
  id &&
  id !== "null" &&
  id !== "undefined" &&
  mongoose.Types.ObjectId.isValid(id);

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
      carDetails,
      location,
    });

    await ride.save();
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
    const rides = await Ride.find().populate('driverId', 'name email');
    res.status(200).json({ success: true, rides });
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
    const { longitude, latitude, maxDistance = 10000 } = req.query;

    if (!longitude || !latitude) {
      return res.status(400).json({
        success: false,
        message: 'Longitude and latitude are required',
      });
    }

    const rides = await Ride.find({
      location: {
        $near: {
          $geometry: { type: 'Point', coordinates: [parseFloat(longitude), parseFloat(latitude)] },
          $maxDistance: parseFloat(maxDistance),
        },
      },
    });

    res.status(200).json({ success: true, rides });
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

    if (!isValidId(userId)) {
      return res.status(400).json({ success: false, message: "Invalid userId" });
    }

    const rides = await Ride.find({ driverId: userId })
      .sort({ createdAt: -1 })
      .populate('driverId', 'name email');

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
// CREATE RIDE REQUEST
// -------------------------------------------------------
exports.requestRide = async (req, res) => {
  try {
    const { rideId } = req.params;
    const { userId, from, to, date, time, note, location } = req.body;

    if (!isValidId(rideId) || !isValidId(userId)) {
      return res.status(400).json({ success: false, message: "Invalid rideId or userId" });
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

    if (!isValidId(rideId) || !isValidId(userId)) {
      return res.status(400).json({ success: false, message: "Invalid rideId or userId" });
    }

    const request = await RideRequest.findOne({ rideId, userId });
    if (!request)
      return res.status(404).json({ success: false, message: "Request not found" });

    request.status = status;
    await request.save();

    res.status(200).json({
      success: true,
      message: `Request ${status} successfully`,
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
      .populate("userId", "name email");

    res.status(200).json({ success: true, count: requests.length, requests });

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
    const { longitude, latitude, maxDistance = 15000 } = req.query;

    if (!longitude || !latitude)
      return res.status(400).json({ success: false, message: "Longitude & Latitude required" });

    const requests = await RideRequest.find({
      location: {
        $near: {
          $geometry: { type: "Point", coordinates: [parseFloat(longitude), parseFloat(latitude)] },
          $maxDistance: parseFloat(maxDistance),
        },
      },
    })
      .populate("rideId")
      .populate("userId", "name email");

    res.status(200).json({ success: true, requests });

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

    if (!isValidId(driverId)) {
      return res.status(400).json({ success: false, message: "Invalid driverId" });
    }

    const rides = await Ride.find({ driverId });

    const rideIds = rides.map(r => r._id);

    const requests = await RideRequest.find({ rideId: { $in: rideIds } })
      .populate("rideId")
      .populate("userId", "name email");

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
