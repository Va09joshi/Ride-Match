const imgbbUploader = require('imgbb-uploader');
const User = require('../models/user');

exports.uploadProfileImage = async (req, res) => {
  try {
    // Get user ID from the decoded JWT
    const userId = req.user.id;   // <-- use `id` from token payload
    if (!req.file) {
      return res.status(400).json({ message: 'No image file uploaded' });
    }

    // Upload to ImgBB
    const result = await imgbbUploader({
      apiKey: process.env.IMGBB_API_KEY,
      imagePath: req.file.path
    });

    const imageUrl = result.url;

    // Update user profile
    const updatedUser = await User.findByIdAndUpdate(
      userId,
      { profileImage: imageUrl },
      { new: true }
    );

    return res.status(200).json({ success: true, user: updatedUser });
  } catch (err) {
    console.error('ImgBB upload error', err);
    return res.status(500).json({ success: false, message: 'Server error' });
  }
};
