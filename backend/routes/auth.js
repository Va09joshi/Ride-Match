const express = require('express');
const router = express.Router();
const auth = require('../middleware/authmiddleware');
const User = require('../models/user');

const {
  registerUser,
  loginUser,
  getUserProfile,
  updateUserProfile,
  sendOTP,
  verifyOTP,
  resetPassword
} = require('../controllers/authcontroller');

router.post('/signup', registerUser);
router.post('/register', registerUser);
router.post('/login', loginUser);
router.post('/forgot-password', sendOTP);
router.post('/verify-otp', verifyOTP);
router.post('/reset-password', resetPassword);

router.get('/me', auth, getUserProfile);
router.put('/update-profile', auth, updateUserProfile);

router.post('/forgot/send-otp', sendOTP);
router.post('/forgot/verify-otp', verifyOTP);
router.post('/forgot/reset-password', resetPassword);

router.get('/users', async (req, res) => {
  try {
    const users = await User.find({}, '_id name email phone');
    res.json({ success: true, users });
  } catch (err) {
    res.status(500).json({ success: false, message: err.message });
  }
});

module.exports = router;
