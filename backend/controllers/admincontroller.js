const User = require('../models/user');
const Ride = require('../models/Ride');
const RideRequest = require('../models/RideRequest');
const PaymentMethod = require('../models/PaymentMethod');
const Transaction = require('../models/Transaction');
const Notification = require('../models/Notification');
const Banner = require('../models/Banner');
const TermsAndConditions = require('../models/TermsAndConditions');

const toNumber = (val, fallback) => {
  const parsed = Number(val);
  return Number.isFinite(parsed) ? parsed : fallback;
};

const listFactory = (Model, populate = null) => async (req, res) => {
  try {
    const page = Math.max(1, toNumber(req.query.page, 1));
    const limit = Math.min(100, Math.max(1, toNumber(req.query.limit, 20)));
    const skip = (page - 1) * limit;

    let query = Model.find({}).sort({ createdAt: -1 }).skip(skip).limit(limit);
    if (populate) query = query.populate(populate);

    const [items, total] = await Promise.all([query, Model.countDocuments({})]);
    return res.status(200).json({ success: true, total, page, limit, items });
  } catch (err) {
    return res.status(500).json({ success: false, message: err.message });
  }
};

const createFactory = (Model) => async (req, res) => {
  try {
    const item = await Model.create(req.body || {});
    return res.status(201).json({ success: true, item });
  } catch (err) {
    return res.status(500).json({ success: false, message: err.message });
  }
};

const updateFactory = (Model) => async (req, res) => {
  try {
    const { id } = req.params;
    const item = await Model.findByIdAndUpdate(id, req.body || {}, { new: true });
    if (!item) {
      return res.status(404).json({ success: false, message: 'Record not found' });
    }
    return res.status(200).json({ success: true, item });
  } catch (err) {
    return res.status(500).json({ success: false, message: err.message });
  }
};

const deleteFactory = (Model) => async (req, res) => {
  try {
    const { id } = req.params;
    const result = await Model.deleteOne({ _id: id });
    if (!result.deletedCount) {
      return res.status(404).json({ success: false, message: 'Record not found' });
    }
    return res.status(200).json({ success: true, message: 'Deleted successfully' });
  } catch (err) {
    return res.status(500).json({ success: false, message: err.message });
  }
};

module.exports = {
  listUsers: listFactory(User),
  createUser: createFactory(User),
  updateUser: updateFactory(User),
  deleteUser: deleteFactory(User),

  listRides: listFactory(Ride, 'driverId'),
  createRide: createFactory(Ride),
  updateRide: updateFactory(Ride),
  deleteRide: deleteFactory(Ride),

  listRideRequests: listFactory(RideRequest, ['rideId', 'userId']),
  createRideRequest: createFactory(RideRequest),
  updateRideRequest: updateFactory(RideRequest),
  deleteRideRequest: deleteFactory(RideRequest),

  listPaymentMethods: listFactory(PaymentMethod, 'userId'),
  createPaymentMethod: createFactory(PaymentMethod),
  updatePaymentMethod: updateFactory(PaymentMethod),
  deletePaymentMethod: deleteFactory(PaymentMethod),

  listTransactions: listFactory(Transaction, ['userId', 'paymentMethodId']),
  createTransaction: createFactory(Transaction),
  updateTransaction: updateFactory(Transaction),
  deleteTransaction: deleteFactory(Transaction),

  listNotifications: listFactory(Notification, ['senderId', 'receiverId']),
  createNotification: createFactory(Notification),
  updateNotification: updateFactory(Notification),
  deleteNotification: deleteFactory(Notification),

  listBanners: listFactory(Banner),
  createBanner: createFactory(Banner),
  updateBanner: updateFactory(Banner),
  deleteBanner: deleteFactory(Banner),

  listTerms: listFactory(TermsAndConditions),
  createTerms: createFactory(TermsAndConditions),
  updateTerms: updateFactory(TermsAndConditions),
  deleteTerms: deleteFactory(TermsAndConditions),
};
