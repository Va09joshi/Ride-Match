const express = require('express');
const router = express.Router();
const auth = require('../middleware/authmiddleware');
const {
  listPaymentMethods,
  addPaymentMethod,
  updatePaymentMethod,
  deletePaymentMethod,
  listTransactions,
  createTransaction,
} = require('../controllers/paymentcontroller');

router.get('/methods', auth, listPaymentMethods);
router.post('/methods', auth, addPaymentMethod);
router.put('/methods/:methodId', auth, updatePaymentMethod);
router.delete('/methods/:methodId', auth, deletePaymentMethod);

router.get('/transactions', auth, listTransactions);
router.post('/transactions', auth, createTransaction);

module.exports = router;
