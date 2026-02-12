// ignore_for_file: deprecated_member_use, unused_import, prefer_iterable_wheretype, avoid_print

import 'package:flutter/material.dart';
import '../app_scope.dart';
import '../api/driver_api.dart';
import 'DriverOrderFlowScreen.dart';

class DriverOrdersScreen extends StatefulWidget {
  const DriverOrdersScreen({super.key});

  @override
  State<DriverOrdersScreen> createState() => _DriverOrdersScreenState();
}

class _DriverOrdersScreenState extends State<DriverOrdersScreen> {
  bool loading = false;
  List<Map<String, dynamic>> orders = [];
  bool _loadedOnce = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_loadedOnce) {
      _loadedOnce = true;
      _load();
    }
  }

  void toast(String m) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));
  }

  Future<void> _load() async {
    setState(() => loading = true);

    try {
      final scope = TickinAppScope.of(context);
      final driverId = await scope.driverId;

      if (driverId.isEmpty) {
        throw Exception("DriverId missing from token");
      }

      final list = await scope.driverApi.getDriverOrders(driverId);

      final filtered = list.where((o) {
        final id = (o["orderId"] ?? o["id"] ?? "").toString().trim();
        return id.startsWith("ORD_FULL_"); // ✅ only FULL orders
      }).toList();

      setState(() {
        orders = filtered;
      });
    } catch (e) {
      print("❌ DRIVER LOAD ERROR => $e");
      toast("❌ Load failed");
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  String _safe(Map o, List<String> keys) {
    for (final k in keys) {
      if (o[k] != null && o[k].toString().isNotEmpty) {
        return o[k].toString();
      }
    }
    return "-";
  }

  num _num(dynamic v) {
    if (v == null) return 0;
    if (v is num) return v;
    return num.tryParse(v.toString()) ?? 0;
  }

  /// 🗑️ DELETE ORDER (ALWAYS ALLOWED)
  void _deleteOrder(int index, Map<String, dynamic> o) async {
    final orderId = _safe(o, ["orderId", "id"]);
    final scope = TickinAppScope.of(context);

    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Delete Order"),
        content: const Text("Remove this order from your list?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text("Delete"),
          ),
        ],
      ),
    );

    if (ok != true) return;

    try {
      final driverId = await scope.driverId;

      final res = await DriverApi(
        scope.httpClient,
      ).deleteOrder(orderId: orderId, driverId: driverId);

      if (res["ok"] != true) {
        throw Exception(res["message"] ?? "Delete failed");
      }

      setState(() => orders.removeAt(index));
      toast("🗑️ Order removed");
    } catch (e) {
      toast("❌ Delete failed");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("My Orders"),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _load),
        ],
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : orders.isEmpty
          ? const Center(child: Text("No orders found"))
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView.builder(
                itemCount: orders.length,
                itemBuilder: (_, i) {
                  final o = orders[i];

                  final orderId = _safe(o, ["orderId", "id"]);
                  final status = _safe(o, ["status"]);
                  final distributor = _safe(o, [
                    "distributorName",
                    "agencyName",
                    "distributorId",
                  ]);

                  final amount = _num(
                    o["amount"] ?? o["totalAmount"] ?? o["grandTotal"],
                  ).toDouble();

                  return Card(
                    margin: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    child: ListTile(
                      title: Text(
                        distributor,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Text("Order: $orderId\nStatus: $status"),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            "₹${amount.toStringAsFixed(0)}",
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(width: 10),
                          ElevatedButton.icon(
                            onPressed: () => _deleteOrder(i, o),
                            icon: const Icon(Icons.delete),
                            label: const Text("DELETE"),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.red,
                            ),
                          ),
                        ],
                      ),
                      onTap: () {
                        if (orderId.isEmpty || orderId == "-") {
                          toast("❌ OrderId missing");
                          return;
                        }

                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => DriverOrderFlowScreen(order: o),
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
}
