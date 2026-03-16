const PaymentMethod = require('../models/PaymentMethod');
const Transaction = require('../models/Transaction');

exports.listPaymentMethods = async (req, res) => {
  try {
    const methods = await PaymentMethod.find({ userId: req.user.id }).sort({ createdAt: -1 });
    return res.status(200).json({ success: true, methods });
  } catch (err) {
    return res.status(500).json({ success: false, message: err.message });
  }
};

exports.addPaymentMethod = async (req, res) => {
  try {
    const { type, label, holderName = '', last4 = '', isDefault = false, meta = {} } = req.body;

    if (!type || !label) {
      return res.status(400).json({ success: false, message: 'type and label are required' });
    }

    if (isDefault) {
      await PaymentMethod.updateMany({ userId: req.user.id }, { $set: { isDefault: false } });
    }

    const method = await PaymentMethod.create({
      userId: req.user.id,
      type,
      label,
      holderName,
      last4,
      isDefault,
      meta,
    });

    return res.status(201).json({ success: true, method });
  } catch (err) {
    return res.status(500).json({ success: false, message: err.message });
  }
};

exports.updatePaymentMethod = async (req, res) => {
  try {
    const { methodId } = req.params;
    const { type, label, holderName, last4, isDefault, meta } = req.body;

    const method = await PaymentMethod.findOne({ _id: methodId, userId: req.user.id });
    if (!method) {
      return res.status(404).json({ success: false, message: 'Payment method not found' });
    }

    if (typeof isDefault === 'boolean' && isDefault) {
      await PaymentMethod.updateMany({ userId: req.user.id }, { $set: { isDefault: false } });
    }

    if (type) method.type = type;
    if (label) method.label = label;
    if (holderName !== undefined) method.holderName = holderName;
    if (last4 !== undefined) method.last4 = last4;
    if (typeof isDefault === 'boolean') method.isDefault = isDefault;
    if (meta !== undefined) method.meta = meta;

    await method.save();
    return res.status(200).json({ success: true, method });
  } catch (err) {
    return res.status(500).json({ success: false, message: err.message });
  }
};

exports.deletePaymentMethod = async (req, res) => {
  try {
    const { methodId } = req.params;
    const result = await PaymentMethod.deleteOne({ _id: methodId, userId: req.user.id });
    if (!result.deletedCount) {
      return res.status(404).json({ success: false, message: 'Payment method not found' });
    }
    return res.status(200).json({ success: true, message: 'Payment method deleted' });
  } catch (err) {
    return res.status(500).json({ success: false, message: err.message });
  }
};

exports.listTransactions = async (req, res) => {
  try {
    const transactions = await Transaction.find({ userId: req.user.id })
      .populate('paymentMethodId')
      .sort({ createdAt: -1 });

    return res.status(200).json({ success: true, transactions });
  } catch (err) {
    return res.status(500).json({ success: false, message: err.message });
  }
};

exports.createTransaction = async (req, res) => {
  try {
    const {
      paymentMethodId = null,
      type = 'ride_booking',
      amount,
      currency = 'INR',
      status = 'success',
      referenceId = '',
      description = '',
    } = req.body;

    if (amount === undefined || Number.isNaN(Number(amount))) {
      return res.status(400).json({ success: false, message: 'amount is required' });
    }

    const transaction = await Transaction.create({
      userId: req.user.id,
      paymentMethodId,
      type,
      amount: Number(amount),
      currency,
      status,
      referenceId,
      description,
    });

    return res.status(201).json({ success: true, transaction });
  } catch (err) {
    return res.status(500).json({ success: false, message: err.message });
  }
};
