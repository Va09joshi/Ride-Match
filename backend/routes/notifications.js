const express = require("express");
const router = express.Router();

const {
  sendLikeNotification,
  getNotifications,
  markAllAsRead,
  unreadCount
} = require("../controllers/notificationController");

router.post("/like", sendLikeNotification);
router.get("/:userId", getNotifications);
router.put("/mark-read/:userId", markAllAsRead);
router.get("/unread/count/:userId", unreadCount);

module.exports = router;
