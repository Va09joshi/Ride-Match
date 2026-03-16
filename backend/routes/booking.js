const express = require('express');
const router = express.Router();
const { bookRide, getMyBookings } = require('../controllers/bookingcontroller');
const auth = require('../middleware/authmiddleware');

router.post('/', auth, bookRide);
router.get('/me', auth, getMyBookings);

module.exports = router;
