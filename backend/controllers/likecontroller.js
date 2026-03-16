const RideRequest = require("../models/RideRequest");
const Notification = require("../models/Notification");

exports.likeRequest = async (req, res) => {
  try {
    const { userId, requestId } = req.body;

    const request = await RideRequest.findById(requestId);
    if (!request) {
      return res.status(404).json({ message: "Request not found" });
    }

    const alreadyLiked = request.likedBy.includes(userId);

    if (alreadyLiked) {
      // Already liked, do nothing
      return res.json({
        message: "Already liked",
        type: "like"
      });
    }
    // LIKE
    request.likedBy.push(userId);
    await request.save();

    // Create notification
    await Notification.create({
      senderId: userId,
      receiverId: request.userId,
      requestId,
      type: "like",
      message: "liked your post"
    });

    return res.json({
      message: "Post liked",
      type: "like"
    });

  } catch (err) {
    res.status(500).json({ message: "Error", error: err.message });
  }
};
