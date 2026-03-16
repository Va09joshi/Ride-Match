import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:ridematch/services/API.dart';
import 'package:ridematch/utils/app_constant.dart';
import 'package:shared_preferences/shared_preferences.dart';

class PaymentPage extends StatefulWidget {
  const PaymentPage({super.key});

  @override
  _PaymentPageState createState() => _PaymentPageState();
}

class _PaymentPageState extends State<PaymentPage> {
  List<Map<String, dynamic>> _methods = [];
  List<Map<String, dynamic>> _transactions = [];
  bool _loading = true;
  String? _token;

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    final prefs = await SharedPreferences.getInstance();
    _token = prefs.getString('token');
    await _loadData();
  }

  Future<void> _loadData() async {
    if (_token == null || _token!.isEmpty) {
      if (!mounted) return;
      setState(() => _loading = false);
      return;
    }

    if (mounted) setState(() => _loading = true);
    try {
      final methodsRes = await http.get(
        AppApi.uri(AppEndpoints.paymentMethods),
        headers: {'Authorization': 'Bearer $_token'},
      );
      final txRes = await http.get(
        AppApi.uri(AppEndpoints.paymentTransactions),
        headers: {'Authorization': 'Bearer $_token'},
      );

      if (!mounted) return;
      setState(() {
        _methods = methodsRes.statusCode == 200
            ? List<Map<String, dynamic>>.from(
                jsonDecode(methodsRes.body)['methods'] ?? [],
              )
            : [];
        _transactions = txRes.statusCode == 200
            ? List<Map<String, dynamic>>.from(
                jsonDecode(txRes.body)['transactions'] ?? [],
              )
            : [];
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _methods = [];
        _transactions = [];
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _addPaymentMethod() async {
    final labelController = TextEditingController();
    final typeController = TextEditingController(text: 'upi');
    final holderController = TextEditingController();
    final last4Controller = TextEditingController();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Payment Method'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: typeController,
                decoration: const InputDecoration(
                  labelText: 'Type (upi/card/bank/wallet)',
                ),
              ),
              TextField(
                controller: labelController,
                decoration: const InputDecoration(labelText: 'Label'),
              ),
              TextField(
                controller: holderController,
                decoration: const InputDecoration(labelText: 'Holder Name'),
              ),
              TextField(
                controller: last4Controller,
                decoration: const InputDecoration(labelText: 'Last 4'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (confirmed != true || _token == null) return;
    await http.post(
      AppApi.uri(AppEndpoints.paymentMethods),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $_token',
      },
      body: jsonEncode({
        'type': typeController.text.trim(),
        'label': labelController.text.trim(),
        'holderName': holderController.text.trim(),
        'last4': last4Controller.text.trim(),
      }),
    );
    await _loadData();
  }

  Future<void> _deleteMethod(String id) async {
    if (_token == null) return;
    await http.delete(
      AppApi.uri('${AppEndpoints.paymentMethods}/$id'),
      headers: {'Authorization': 'Bearer $_token'},
    );
    await _loadData();
  }

  Future<void> _addDummyTransaction() async {
    if (_token == null) return;
    await http.post(
      AppApi.uri(AppEndpoints.paymentTransactions),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $_token',
      },
      body: jsonEncode({
        'amount': 199,
        'type': 'ride_booking',
        'status': 'success',
        'description': 'Ride payment',
        'referenceId': DateTime.now().millisecondsSinceEpoch.toString(),
      }),
    );
    await _loadData();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Payments"),
        backgroundColor: const Color(0xff113F67),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadData,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'Saved Payment Methods',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 16,
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: _addPaymentMethod,
                        icon: const Icon(Icons.add_circle_outline),
                      ),
                    ],
                  ),
                  if (_methods.isEmpty)
                    const Card(
                      child: Padding(
                        padding: EdgeInsets.all(12),
                        child: Text('No saved payment methods.'),
                      ),
                    )
                  else
                    ..._methods.map(
                      (m) => Card(
                        child: ListTile(
                          title: Text((m['label'] ?? 'Method').toString()),
                          subtitle: Text(
                            '${m['type']} ${m['last4'] ?? ''}'.trim(),
                          ),
                          trailing: IconButton(
                            icon: const Icon(
                              Icons.delete_outline,
                              color: Colors.red,
                            ),
                            onPressed: () =>
                                _deleteMethod((m['_id'] ?? '').toString()),
                          ),
                        ),
                      ),
                    ),
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'Previous Transactions',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 16,
                          ),
                        ),
                      ),
                      TextButton(
                        onPressed: _addDummyTransaction,
                        child: const Text('Add Sample'),
                      ),
                    ],
                  ),
                  if (_transactions.isEmpty)
                    const Card(
                      child: Padding(
                        padding: EdgeInsets.all(12),
                        child: Text('No transactions yet.'),
                      ),
                    )
                  else
                    ..._transactions.map(
                      (t) => Card(
                        child: ListTile(
                          title: Text('₹${(t['amount'] ?? 0).toString()}'),
                          subtitle: Text(
                            (t['description'] ?? t['type'] ?? '').toString(),
                          ),
                          trailing: Text(
                            (t['status'] ?? '').toString().toUpperCase(),
                            style: TextStyle(
                              color: (t['status'] == 'success')
                                  ? Colors.green
                                  : Colors.orange,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
    );
  }
}
