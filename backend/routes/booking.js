const express = require('express');
const router = express.Router();
const { bookRide, getMyBookings, getRideBookings } = require('../controllers/bookingcontroller');
const auth = require('../middleware/authmiddleware');

router.post('/', auth, bookRide);
router.get('/me', auth, getMyBookings);
router.get('/ride/:rideId', auth, getRideBookings);

module.exports = router;
