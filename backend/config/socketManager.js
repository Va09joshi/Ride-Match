/**
 * socketManager.js
 * Singleton store for the Socket.IO server instance and connected user map.
 * Import this wherever you need to emit events from controllers.
 */
let _io = null;

// Map of  userId (string) → socket.id
const users = {};

module.exports = {
  setIO(io) {
    _io = io;
  },

  getIO() {
    return _io;
  },

  users,
};
