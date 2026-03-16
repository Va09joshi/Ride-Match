// routes/profileRoutes.js
const express = require('express');
const router = express.Router();
const multer = require('multer');
const upload = multer({ dest: 'temp_uploads/' });  // temporary folder for uploads
const { uploadProfileImage, uploadVerificationDocument } = require('../controllers/imagecontroller');
const auth = require('../middleware/authmiddleware'); // import your auth middleware

// Define the route
router.post('/upload-profile', auth, upload.single('profile'), uploadProfileImage);
router.post('/upload-verification', auth, upload.single('document'), uploadVerificationDocument);

module.exports = router;
