/**
 * notificationHelper.js
 * Central helper for creating persisted notifications and delivering them
 * in real-time via Socket.IO when the recipient is online.
 */
const Notification = require('../models/Notification');
const { getIO, users } = require('../config/socketManager');

/**
 * Create a notification document and, if the recipient is connected via
 * Socket.IO, emit a `new_notification` event to them immediately.
 *
 * @param {object} opts
 * @param {string|null}  opts.senderId    - The user who triggered this event (null for system)
 * @param {string}       opts.receiverId  - The user who should receive it
 * @param {string}       opts.type        - Notification type (see Notification model enum)
 * @param {string}       opts.message     - Human-readable message
 * @param {string|null}  opts.relatedId   - Optional rideId / bookingId / etc.
 * @returns {Promise<object>} The saved Notification document
 */
async function createNotification({ senderId, receiverId, type, message, relatedId = null }) {
  try {
    if (!receiverId) return null;

    const notifData = {
      receiverId,
      type,
      message,
      relatedId,
      isRead: false,
    };
    if (senderId) notifData.senderId = senderId;

    const notification = await Notification.create(notifData);

    // Real-time delivery
    const io = getIO();
    if (io) {
      const receiverSocket = users[receiverId.toString()];
      if (receiverSocket) {
        io.to(receiverSocket).emit('new_notification', {
          _id: notification._id,
          type,
          message,
          senderId: senderId || null,
          relatedId,
          createdAt: notification.createdAt,
          isRead: false,
        });
      }
    }

    return notification;
  } catch (err) {
    // Notification failures must never break the main request flow
    console.error('⚠️  createNotification error:', err.message);
    return null;
  }
}

module.exports = { createNotification };
