import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:ridematch/services/API.dart';
import 'package:ridematch/utils/app_constant.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  String? _token;
  bool _loading = true;
  Map<String, int> _counts = {};

  final Map<String, String> _resources = {
    'Users': AppEndpoints.adminUsers,
    'Rides': AppEndpoints.adminRides,
    'Ride Requests': AppEndpoints.adminRideRequests,
    'Payments': AppEndpoints.adminPayments,
    'Payment Methods': AppEndpoints.adminPaymentMethods,
    'Notifications': AppEndpoints.adminNotifications,
    'App Banners': AppEndpoints.adminBanners,
    'Terms & Conditions': AppEndpoints.adminTerms,
  };

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    final prefs = await SharedPreferences.getInstance();
    _token = prefs.getString('token');
    await _loadCounts();
  }

  Future<void> _loadCounts() async {
    if (_token == null || _token!.isEmpty) {
      if (!mounted) return;
      setState(() => _loading = false);
      return;
    }

    if (mounted) setState(() => _loading = true);
    final newCounts = <String, int>{};

    for (final entry in _resources.entries) {
      try {
        final res = await http.get(
          AppApi.uri(entry.value, queryParameters: {'page': 1, 'limit': 1}),
          headers: {'Authorization': 'Bearer $_token'},
        );
        if (res.statusCode == 200) {
          final data = jsonDecode(res.body);
          newCounts[entry.key] = (data['total'] ?? 0) as int;
        } else {
          newCounts[entry.key] = 0;
        }
      } catch (_) {
        newCounts[entry.key] = 0;
      }
    }

    if (!mounted) return;
    setState(() {
      _counts = newCounts;
      _loading = false;
    });
  }

  Future<void> _openResource(String title, String endpoint) async {
    final records = await _fetchRecords(endpoint);
    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => FractionallySizedBox(
        heightFactor: 0.9,
        child: StatefulBuilder(
          builder: (context, setSheetState) {
            Future<void> refresh() async {
              final fresh = await _fetchRecords(endpoint);
              setSheetState(() {
                records
                  ..clear()
                  ..addAll(fresh);
              });
              await _loadCounts();
            }

            return Scaffold(
              appBar: AppBar(
                title: Text(title),
                actions: [
                  IconButton(
                    icon: const Icon(Icons.add),
                    onPressed: () async {
                      final body = await _jsonInputDialog(
                        context,
                        '{}',
                        'Create $title',
                      );
                      if (body == null) return;
                      await _createRecord(endpoint, body);
                      await refresh();
                    },
                  ),
                ],
              ),
              body: records.isEmpty
                  ? const Center(child: Text('No records found'))
                  : ListView.builder(
                      itemCount: records.length,
                      itemBuilder: (context, index) {
                        final item = records[index];
                        final id = (item['_id'] ?? '').toString();
                        return Card(
                          margin: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          child: ListTile(
                            title: Text(
                              item['title']?.toString() ??
                                  item['name']?.toString() ??
                                  id,
                            ),
                            subtitle: Text(
                              const JsonEncoder.withIndent('  ').convert(item),
                              maxLines: 6,
                              overflow: TextOverflow.ellipsis,
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.edit_outlined),
                                  onPressed: () async {
                                    final updated = await _jsonInputDialog(
                                      context,
                                      const JsonEncoder.withIndent(
                                        '  ',
                                      ).convert(item),
                                      'Update $title',
                                    );
                                    if (updated == null) return;
                                    await _updateRecord(endpoint, id, updated);
                                    await refresh();
                                  },
                                ),
                                IconButton(
                                  icon: const Icon(
                                    Icons.delete_outline,
                                    color: Colors.red,
                                  ),
                                  onPressed: () async {
                                    await _deleteRecord(endpoint, id);
                                    await refresh();
                                  },
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            );
          },
        ),
      ),
    );
  }

  Future<List<Map<String, dynamic>>> _fetchRecords(String endpoint) async {
    if (_token == null) return [];
    final res = await http.get(
      AppApi.uri(endpoint, queryParameters: {'page': 1, 'limit': 100}),
      headers: {'Authorization': 'Bearer $_token'},
    );
    if (res.statusCode != 200) return [];
    final data = jsonDecode(res.body);
    return List<Map<String, dynamic>>.from(data['items'] ?? []);
  }

  Future<void> _createRecord(String endpoint, Map<String, dynamic> body) async {
    if (_token == null) return;
    await http.post(
      AppApi.uri(endpoint),
      headers: {
        'Authorization': 'Bearer $_token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode(body),
    );
  }

  Future<void> _updateRecord(
    String endpoint,
    String id,
    Map<String, dynamic> body,
  ) async {
    if (_token == null || id.isEmpty) return;
    await http.put(
      AppApi.uri('$endpoint/$id'),
      headers: {
        'Authorization': 'Bearer $_token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode(body),
    );
  }

  Future<void> _deleteRecord(String endpoint, String id) async {
    if (_token == null || id.isEmpty) return;
    await http.delete(
      AppApi.uri('$endpoint/$id'),
      headers: {'Authorization': 'Bearer $_token'},
    );
  }

  Future<Map<String, dynamic>?> _jsonInputDialog(
    BuildContext context,
    String initial,
    String title,
  ) async {
    final controller = TextEditingController(text: initial);
    return showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(title),
        content: SizedBox(
          width: 480,
          child: TextField(
            controller: controller,
            maxLines: 16,
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              hintText: 'Enter valid JSON',
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              try {
                final parsed = jsonDecode(controller.text);
                if (parsed is Map<String, dynamic>) {
                  Navigator.pop(context, parsed);
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('JSON must be an object')),
                  );
                }
              } catch (_) {
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(const SnackBar(content: Text('Invalid JSON')));
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Dashboard'),
        backgroundColor: const Color(0xff113F67),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadCounts,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: _resources.entries.map((entry) {
                  final title = entry.key;
                  final endpoint = entry.value;
                  final count = _counts[title] ?? 0;
                  return Card(
                    child: ListTile(
                      title: Text(title),
                      subtitle: Text('Total: $count'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => _openResource(title, endpoint),
                    ),
                  );
                }).toList(),
              ),
            ),
    );
  }
}
