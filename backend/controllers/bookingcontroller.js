const Booking = require('../models/Booking');
const Ride = require('../models/Ride');
const { syncRideLifecycle } = require('./rideLifecycle');
const { createNotification } = require('../helpers/notificationHelper');

const generateBookingId = () => {
    const stamp = Date.now().toString(36).toUpperCase();
    const random = Math.random().toString(36).substring(2, 6).toUpperCase();
    return `RID-${stamp}-${random}`;
};

const parseDepartureDate = (ride) => {
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

const bookRide = async (req, res) => {
    const { rideId, seatsBooked = 1 } = req.body;
    try {
        if (!rideId) {
            return res.status(400).json({ success: false, message: 'rideId is required' });
        }

        const seats = Number(seatsBooked);
        if (!Number.isInteger(seats) || seats <= 0) {
            return res.status(400).json({ success: false, message: 'seatsBooked must be a positive integer' });
        }

        const ride = await Ride.findById(rideId);
        if (!ride) return res.status(404).json({ success: false, message: 'Ride not found' });

        await syncRideLifecycle(ride);

        if (ride.status === 'cancelled') {
            return res.status(400).json({ success: false, message: 'This ride is cancelled' });
        }

        if (ride.status === 'completed') {
            return res.status(400).json({ success: false, message: 'This ride is already completed' });
        }

        if (ride.status === 'in_progress') {
            return res.status(400).json({ success: false, message: 'This ride is already in progress' });
        }

        const departure = parseDepartureDate(ride);
        if (departure && departure.getTime() <= Date.now()) {
            return res.status(400).json({ success: false, message: 'Ride departure time has passed' });
        }

        if ((ride.availableSeats || 0) < seats) {
            return res.status(400).json({ success: false, message: 'Not enough seats available' });
        }

        const existingBooking = await Booking.findOne({
            ride: rideId,
            user: req.user.id,
            status: 'booked',
        });
        if (existingBooking) {
            return res.status(400).json({ success: false, message: 'You already booked this ride', booking: existingBooking });
        }

        const booking = new Booking({
            bookingId: generateBookingId(),
            ride: rideId,
            user: req.user.id,
            driver: ride.driverId,
            seatsBooked: seats,
            totalPrice: Number(ride.amount || 0) * seats,
            from: ride.from,
            to: ride.to,
            date: ride.date,
            time: ride.time,
            status: 'booked',
        });
        await booking.save();

        ride.availableSeats = Number(ride.availableSeats || 0) - seats;
        if (ride.availableSeats <= 0) {
            ride.availableSeats = 0;
        }
        if (ride.status === 'created') {
            ride.status = 'active';
        }
        await ride.save();

        const populated = await Booking.findById(booking._id)
            .populate('ride')
            .populate('user', 'name email phone profileImage')
            .populate('driver', 'name email phone profileImage');

        res.status(201).json({
            success: true,
            message: 'Ride booked successfully',
            booking: populated,
        });

        // Notify the driver that someone booked their ride (fire-and-forget)
        createNotification({
            senderId: req.user.id,
            receiverId: ride.driverId.toString(),
            type: 'ride_booked',
            message: `Someone booked your ride from ${ride.from} to ${ride.to}.`,
            relatedId: booking._id.toString(),
        });

        // Notify the passenger (booking confirmation)
        createNotification({
            senderId: ride.driverId.toString(),
            receiverId: req.user.id,
            type: 'ride_booked',
            message: `Your booking for the ride from ${ride.from} to ${ride.to} is confirmed! Booking ID: ${booking.bookingId}`,
            relatedId: booking._id.toString(),
        });
    } catch (err) {
        res.status(500).json({ success: false, message: err.message });
    }
}

const getMyBookings = async (req, res) => {
    try {
        const bookings = await Booking.find({ user: req.user.id })
            .sort({ createdAt: -1 })
            .populate('ride')
            .populate('driver', 'name email phone profileImage')
            .populate('user', 'name email phone profileImage');

        for (const booking of bookings) {
            if (booking.ride) {
                await syncRideLifecycle(booking.ride);
            }
        }

        const summary = {
            total: bookings.length,
            created: 0,
            active: 0,
            inProgress: 0,
            completed: 0,
            cancelled: 0,
        };

        bookings.forEach((booking) => {
            const rideStatus = (booking.ride?.status || '').toString().toLowerCase();
            if (rideStatus === 'created') summary.created += 1;
            else if (rideStatus === 'active') summary.active += 1;
            else if (rideStatus === 'in_progress') summary.inProgress += 1;
            else if (rideStatus === 'completed') summary.completed += 1;
            else if (rideStatus === 'cancelled') summary.cancelled += 1;
        });

        return res.status(200).json({
            success: true,
            bookings,
            summary,
        });
    } catch (err) {
        return res.status(500).json({ success: false, message: err.message });
    }
};

module.exports = { bookRide, getMyBookings };
