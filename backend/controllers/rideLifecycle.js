const AUTO_COMPLETE_AFTER_MS = 2 * 60 * 60 * 1000; // 2 hours

const parseRideDepartureDate = (ride) => {
  const rawDate = (ride?.date || '').toString().trim();
  const rawTime = (ride?.time || '').toString().trim();
  if (!rawDate || !rawTime) return null;

  const dateParts = rawDate.split(/[-/]/);
  const timeParts = rawTime.split(':');

  if (dateParts.length !== 3 || timeParts.length < 1) return null;

  const year = Number(dateParts[0]);
  const month = Number(dateParts[1]);
  const day = Number(dateParts[2]);
  const hour = Number(timeParts[0]);
  const minute = timeParts.length > 1 ? Number(timeParts[1]) : 0;

  if ([year, month, day, hour, minute].some((v) => Number.isNaN(v))) return null;
  return new Date(year, month - 1, day, hour, minute);
};

const deriveRideStatus = (ride, now = new Date()) => {
  const currentStatus = (ride?.status || 'created').toString().toLowerCase();

  if (currentStatus === 'cancelled' || currentStatus === 'completed') {
    return currentStatus;
  }

  const departure = parseRideDepartureDate(ride);
  if (!departure) {
    return currentStatus === 'active' || currentStatus === 'in_progress'
      ? currentStatus
      : 'created';
  }

  if (now.getTime() < departure.getTime()) {
    // Before departure, preserve created/active tracking.
    return currentStatus === 'active' ? 'active' : 'created';
  }

  const completedAt = departure.getTime() + AUTO_COMPLETE_AFTER_MS;
  if (now.getTime() >= completedAt) {
    return 'completed';
  }

  return 'in_progress';
};

const syncRideLifecycle = async (ride) => {
  if (!ride) return ride;

  const nextStatus = deriveRideStatus(ride);
  const currentStatus = (ride.status || 'created').toString().toLowerCase();

  if (nextStatus === currentStatus) return ride;

  ride.status = nextStatus;
  if (nextStatus === 'in_progress' && !ride.inProgressAt) {
    ride.inProgressAt = new Date();
  }
  if (nextStatus === 'completed' && !ride.completedAt) {
    ride.completedAt = new Date();
  }

  await ride.save();
  return ride;
};

const syncRideLifecycles = async (rides = []) => {
  await Promise.all(rides.map((ride) => syncRideLifecycle(ride)));
  return rides;
};

module.exports = {
  parseRideDepartureDate,
  deriveRideStatus,
  syncRideLifecycle,
  syncRideLifecycles,
};
