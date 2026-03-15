const express = require("express");
const router = express.Router();
const { likeRequest } = require("../controllers/likecontroller");

router.post("/toggle", likeRequest);

module.exports = router;
