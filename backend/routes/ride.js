const express = require('express');
const router = express.Router();
const auth = require('../middleware/authmiddleware');

const {
  createRide,
  getRides,
  getNearbyRides,
  getUserRides,
  requestRide,
  respondToRequest,
  getUserRequests,
  getNearbyRideRequests,
  getIncomingRequestsForDriver,
} = require('../controllers/ridecontroller');

// Create ride (Driver)
router.post('/', auth, createRide);

// All rides
router.get('/', getRides);

// Nearby rides for users
router.get('/nearby', getNearbyRides);

// Driver's own rides
router.get('/user/:userId', getUserRides);

// Send ride request
router.post('/:rideId/request', auth, requestRide);

// Accept / Reject request (Driver)
router.patch('/:rideId/respond', auth, respondToRequest);

// User's ride requests
router.get('/requests/:userId', auth, getUserRequests);

// Nearby ride requests list
router.get('/requests/nearby/list', auth, getNearbyRideRequests);

// Incoming requests for driver
router.get('/incoming/:driverId', auth, getIncomingRequestsForDriver);

module.exports = router;
