const Booking = require('../models/Booking');
const Ride = require('../models/Ride');

const bookRide = async (req, res) => {
    const { rideId, seatsBooked } = req.body;
    try {
        const ride = await Ride.findById(rideId);
        if (!ride) return res.status(404).json({ message: 'Ride not found' });
        if (ride.seatsAvailable < seatsBooked) return res.status(400).json({ message: 'Not enough seats' });

        const booking = new Booking({ ride: rideId, user: req.user.id, seatsBooked });
        await booking.save();

        ride.seatsAvailable -= seatsBooked;
        await ride.save();

        res.status(201).json(booking);
    } catch (err) {
        res.status(500).json({ message: err.message });
    }
}

module.exports = { bookRide };
