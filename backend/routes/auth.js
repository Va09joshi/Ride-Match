const express = require('express');
const router = express.Router();
const auth = require('../middleware/authmiddleware'); // JWT auth middleware if needed
const User = require('../models/user');

// Import all controller functions
const {
  registerUser,
  loginUser,
  getUserProfile,
  sendOTP,
  verifyOTP,
  resetPassword
} = require('../controllers/authcontroller'); // Make sure filename matches

// ----------------- AUTH ROUTES -----------------
router.post('/register', registerUser);
router.post('/login', loginUser);
router.get('/me', auth, getUserProfile);



router.post('/forgot/send-otp', sendOTP);
router.post('/forgot/verify-otp', verifyOTP);
router.post('/forgot/reset-password', resetPassword);



// ----------------- GET ALL USERS -----------------

router.get('/users', async (req, res) => {
  try {
    const users = await User.find({}, '_id name email phone');
    res.json({ success: true, users });
  } catch (err) {
    res.status(500).json({ success: false, message: err.message });
  }
});

module.exports = router;
