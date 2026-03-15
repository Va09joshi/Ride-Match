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

    let type = "";
    if (alreadyLiked) {
      // UNLIKE
      request.likedBy.pull(userId);
      type = "unlike";
    } else {
      // LIKE
      request.likedBy.push(userId);
      type = "like";
    }

    await request.save();

    // Create notification
    await Notification.create({
      senderId: userId,
      receiverId: request.userId,
      requestId,
      type,
      message: type === "like" ? "liked your post" : "unliked your post"
    });

    return res.json({
      message: type === "like" ? "Post liked" : "Post unliked",
      type
    });

  } catch (err) {
    res.status(500).json({ message: "Error", error: err.message });
  }
};
