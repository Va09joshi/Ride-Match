const express = require("express");
const router = express.Router();

const {
  sendLikeNotification,
  getNotifications,
  markAllAsRead,
  markSingleAsRead,
  unreadCount
} = require("../controllers/notificationController");

router.post("/like", sendLikeNotification);
router.get("/unread/count/:userId", unreadCount);
router.get("/:userId", getNotifications);
router.put("/mark-read/:userId", markAllAsRead);
router.put("/:notificationId/read", markSingleAsRead);

module.exports = router;
