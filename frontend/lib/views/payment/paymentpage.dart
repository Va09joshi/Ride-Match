import 'package:flutter/material.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';

class PaymentPage extends StatefulWidget {
  const PaymentPage({super.key});

  @override
  _PaymentPageState createState() => _PaymentPageState();
}

class _PaymentPageState extends State<PaymentPage> {
  late Razorpay _razorpay;

  @override
  void initState() {
    super.initState();
    _razorpay = Razorpay();

    // Event listeners
    _razorpay.on(Razorpay.EVENT_PAYMENT_SUCCESS, _handlePaymentSuccess);
    _razorpay.on(Razorpay.EVENT_PAYMENT_ERROR, _handlePaymentError);
    _razorpay.on(Razorpay.EVENT_EXTERNAL_WALLET, _handleExternalWallet);
  }

  @override
  void dispose() {
    _razorpay.clear(); // Removes all listeners
    super.dispose();
  }

  // Success
  void _handlePaymentSuccess(PaymentSuccessResponse response) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("Payment Successful! ID: ${response.paymentId}")),
    );
    print("Payment Success: ${response.paymentId}");
  }

  // Failure
  void _handlePaymentError(PaymentFailureResponse response) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("Payment Failed: ${response.message}")),
    );
    print("Payment Failed: ${response.code} - ${response.message}");
  }

  // External wallet
  void _handleExternalWallet(ExternalWalletResponse response) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("External Wallet Selected: ${response.walletName}")),
    );
    print("External Wallet: ${response.walletName}");
  }

  // Open Razorpay checkout
  void openCheckout() {
    var options = {
      'key': 'rzp_test_7efDroWAFlHu1z', // your Razorpay test key
      'amount': 50000, // Amount in paise (₹500)
      'name': 'Ride Payment',
      'description': 'Pay for your ride',
      'prefill': {
        'contact': '9876543210',
        'email': 'test@example.com',
      },
      'theme': {'color': '#0A3D62'},
      'method': {
        'upi': true,       // enable UPI
        'card': false,     // disable card
        'netbanking': false,
        'wallet': false,
      },
      'external': {
        'wallets': ['paytm'] // optional
      },
    };

    try {
      _razorpay.open(options);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error opening Razorpay: $e")),
      );
      print("Error opening Razorpay: $e");
    }
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Razorpay Payment"),
        backgroundColor: const Color(0xff113F67),
      ),
      body: Center(
        child: ElevatedButton(
          onPressed: openCheckout,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xff113F67),
            padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 15),
          ),
          child: const Text(
            "Pay ₹500",
            style: TextStyle(fontSize: 16, color: Colors.white),
          ),
        ),
      ),
    );
  }
}
