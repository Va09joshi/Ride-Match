const express = require('express');
const router = express.Router();
const auth = require('../middleware/authmiddleware');
const User = require('../models/user');

router.get('/:id', auth, async (req, res) => {
  try {
    const user = await User.findById(req.params.id).select('name email phone profileImage');
    if (!user) {
      return res.status(404).json({ message: 'User not found' });
    }

    return res.status(200).json(user);
  } catch (error) {
    return res.status(500).json({ message: 'Server error' });
  }
});

module.exports = router;
