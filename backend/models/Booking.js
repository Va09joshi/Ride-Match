const mongoose = require('mongoose');

const bookingSchema = new mongoose.Schema({
    bookingId: { type: String, required: true, unique: true, index: true },
    ride: { type: mongoose.Schema.Types.ObjectId, ref: 'Ride', required: true },
    user: { type: mongoose.Schema.Types.ObjectId, ref: 'User', required: true },
    driver: { type: mongoose.Schema.Types.ObjectId, ref: 'User', required: true },
    seatsBooked: { type: Number, required: true },
    totalPrice: { type: Number, required: true },
    from: { type: String, default: '' },
    to: { type: String, default: '' },
    date: { type: String, default: '' },
    time: { type: String, default: '' },
    status: {
        type: String,
        enum: ['booked', 'cancelled', 'completed'],
        default: 'booked',
    },
}, { timestamps: true });

module.exports = mongoose.model('Booking', bookingSchema);
