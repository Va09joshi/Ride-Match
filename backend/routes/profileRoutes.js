// routes/profileRoutes.js
const express = require('express');
const router = express.Router();
const multer = require('multer');
const upload = multer({ dest: 'temp_uploads/' });  // temporary folder for uploads
const { uploadProfileImage } = require('../controllers/imagecontroller');
const auth = require('../middleware/authmiddleware'); // import your auth middleware

// Define the route
router.post('/upload-profile', auth, upload.single('profile'), uploadProfileImage);

module.exports = router;
