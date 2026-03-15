const Notification = require("../models/Notification");

exports.sendLikeNotification = async (req, res) => {
  try {
    const { senderId, receiverId, requestId, type } = req.body;

    const notification = await Notification.create({
      senderId,
      receiverId,
      requestId,
      type,
      message: type === "like"
        ? "liked your post"
        : "unliked your post"
    });

    res.json({ message: "Notification sent", notification });
  } catch (err) {
    res.status(500).json({ message: "Error sending notification", error: err.message });
  }
};

exports.getNotifications = async (req, res) => {
  try {
    const userId = req.params.userId;

    const notifications = await Notification.find({ receiverId: userId })
      .sort({ createdAt: -1 })
      .populate("senderId", "name profileImage");

    res.json({ notifications });
  } catch (err) {
    res.status(500).json({ message: "Error", error: err });
  }
};

exports.markAllAsRead = async (req, res) => {
  try {
    await Notification.updateMany(
      { receiverId: req.params.userId },
      { $set: { isRead: true } }
    );
    res.json({ message: "All marked as read" });
  } catch (err) {
    res.status(500).json({ message: "Error", error: err });
  }
};

exports.unreadCount = async (req, res) => {
  try {
    const count = await Notification.countDocuments({
      receiverId: req.params.userId,
      isRead: false
    });
    res.json({ count });
  } catch (err) {
    res.status(500).json({ message: "Error", error: err });
  }
};
