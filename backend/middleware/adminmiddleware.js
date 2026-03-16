const User = require('../models/user');

const adminAuth = async (req, res, next) => {
  try {
    if (!req.user?.id) {
      return res.status(401).json({ success: false, message: 'Unauthorized' });
    }

    const user = await User.findById(req.user.id).select('role');
    if (!user) {
      return res.status(401).json({ success: false, message: 'Unauthorized' });
    }

    if (user.role !== 'admin') {
      return res.status(403).json({ success: false, message: 'Admin access required' });
    }

    next();
  } catch (err) {
    return res.status(500).json({ success: false, message: 'Authorization failed' });
  }
};

module.exports = adminAuth;
