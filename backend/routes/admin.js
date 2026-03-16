const express = require('express');
const router = express.Router();
const auth = require('../middleware/authmiddleware');
const adminAuth = require('../middleware/adminmiddleware');
const admin = require('../controllers/admincontroller');

const secure = [auth, adminAuth];

// Users
router.get('/users', ...secure, admin.listUsers);
router.post('/users', ...secure, admin.createUser);
router.put('/users/:id', ...secure, admin.updateUser);
router.delete('/users/:id', ...secure, admin.deleteUser);

// Rides
router.get('/rides', ...secure, admin.listRides);
router.post('/rides', ...secure, admin.createRide);
router.put('/rides/:id', ...secure, admin.updateRide);
router.delete('/rides/:id', ...secure, admin.deleteRide);

// Ride requests
router.get('/ride-requests', ...secure, admin.listRideRequests);
router.post('/ride-requests', ...secure, admin.createRideRequest);
router.put('/ride-requests/:id', ...secure, admin.updateRideRequest);
router.delete('/ride-requests/:id', ...secure, admin.deleteRideRequest);

// Payment methods
router.get('/payment-methods', ...secure, admin.listPaymentMethods);
router.post('/payment-methods', ...secure, admin.createPaymentMethod);
router.put('/payment-methods/:id', ...secure, admin.updatePaymentMethod);
router.delete('/payment-methods/:id', ...secure, admin.deletePaymentMethod);

// Transactions / payments
router.get('/payments', ...secure, admin.listTransactions);
router.post('/payments', ...secure, admin.createTransaction);
router.put('/payments/:id', ...secure, admin.updateTransaction);
router.delete('/payments/:id', ...secure, admin.deleteTransaction);

// Notifications
router.get('/notifications', ...secure, admin.listNotifications);
router.post('/notifications', ...secure, admin.createNotification);
router.put('/notifications/:id', ...secure, admin.updateNotification);
router.delete('/notifications/:id', ...secure, admin.deleteNotification);

// Banners
router.get('/banners', ...secure, admin.listBanners);
router.post('/banners', ...secure, admin.createBanner);
router.put('/banners/:id', ...secure, admin.updateBanner);
router.delete('/banners/:id', ...secure, admin.deleteBanner);

// Terms and conditions
router.get('/terms', ...secure, admin.listTerms);
router.post('/terms', ...secure, admin.createTerms);
router.put('/terms/:id', ...secure, admin.updateTerms);
router.delete('/terms/:id', ...secure, admin.deleteTerms);

module.exports = router;
