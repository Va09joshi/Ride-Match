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

exports.uploadVerificationDocument = async (req, res) => {
  try {
    const userId = req.user.id;
    const { type, number } = req.body;

    if (!req.file) {
      return res.status(400).json({ success: false, message: 'No document file uploaded' });
    }

    const docType = (type || '').toString().trim().toLowerCase();
    if (!['aadhar', 'driving_license'].includes(docType)) {
      return res.status(400).json({ success: false, message: 'Invalid document type' });
    }

    const result = await imgbbUploader({
      apiKey: process.env.IMGBB_API_KEY,
      imagePath: req.file.path,
    });

    const updatePayload = {
      'verification.status': 'pending',
      'verification.submittedAt': new Date(),
    };

    if (docType === 'aadhar') {
      updatePayload['verification.aadharDocUrl'] = result.url;
      if (number !== undefined) updatePayload['verification.aadharNumber'] = number;
    } else {
      updatePayload['verification.drivingLicenseDocUrl'] = result.url;
      if (number !== undefined) updatePayload['verification.drivingLicenseNumber'] = number;
    }

    const updatedUser = await User.findByIdAndUpdate(userId, { $set: updatePayload }, { new: true });
    return res.status(200).json({ success: true, user: updatedUser });
  } catch (err) {
    console.error('Verification upload error', err);
    return res.status(500).json({ success: false, message: 'Server error' });
  }
};
