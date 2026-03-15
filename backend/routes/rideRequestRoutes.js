const express = require("express");
const router = express.Router();
const RideRequest = require("../models/RideRequest");

// LIKE
router.post("/like", async (req, res) => {
  const { userId, requestId } = req.body;

  try {
    const reqDoc = await RideRequest.findById(requestId);

    if (!reqDoc) {
      return res.status(404).json({ error: "Request not found" });
    }

    if (!reqDoc.likedBy.includes(userId)) {
      reqDoc.likedBy.push(userId);
      await reqDoc.save();
    }

    res.json({ success: true, likedBy: reqDoc.likedBy });
  } catch (e) {
    res.status(500).json({ error: e.message });
  }
});

// UNLIKE
router.post("/unlike", async (req, res) => {
  const { userId, requestId } = req.body;

  try {
    const reqDoc = await RideRequest.findById(requestId);

    if (!reqDoc) {
      return res.status(404).json({ error: "Request not found" });
    }

    reqDoc.likedBy = reqDoc.likedBy.filter(
      (id) => id.toString() !== userId
    );

    await reqDoc.save();

    res.json({ success: true, likedBy: reqDoc.likedBy });
  } catch (e) {
    res.status(500).json({ error: e.message });
  }
});

module.exports = router;
