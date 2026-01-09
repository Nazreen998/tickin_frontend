// ignore_for_file: deprecated_member_use, unused_import

import 'dart:convert';
import 'package:flutter/material.dart';

import '../app_scope.dart';
import 'order_details_screen.dart';
import 'slots/slot_booking_screen.dart';

class MyOrdersScreen extends StatefulWidget {
  const MyOrdersScreen({super.key});

  @override
  State<MyOrdersScreen> createState() => _MyOrdersScreenState();
}

class _MyOrdersScreenState extends State<MyOrdersScreen> {
  bool loading = false;
  bool _loadedOnce = false;

  List<Map<String, dynamic>> orders = [];

  String role = "";
  String selectedStatus = "CONFIRMED";

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_loadedOnce) {
      _loadedOnce = true;
      _initAndLoad();
    }
  }

  bool get isManager =>
      role.contains("MANAGER") || role.contains("MASTER");

  void toast(String m) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(m)));
  }

  Future<void> _initAndLoad() async {
    try {
      final scope = TickinAppScope.of(context);
      final userJson = await scope.tokenStore.getUserJson();
      if (userJson != null && userJson.isNotEmpty) {
        final u = jsonDecode(userJson);
        role = (u["role"] ?? u["userRole"] ?? "")
            .toString()
            .toUpperCase();
      }
    } catch (_) {}
    await _load();
  }

  Future<void> _load() async {
    setState(() => loading = true);
    try {
      final scope = TickinAppScope.of(context);

      final res = isManager
          ? await scope.ordersApi.all(status: selectedStatus)
          : await scope.ordersApi.my();

      dynamic raw = res["orders"] ?? res["items"] ?? res["data"] ?? res;
      if (raw is Map) {
        raw = raw["orders"] ?? raw["items"] ?? raw["data"] ?? [];
      }

      setState(() {
        orders = (raw is List
                ? raw
                : [])
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
      });
    } catch (e) {
      toast("❌ Load failed: $e");
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  String _safe(Map o, List<String> keys) {
    for (final k in keys) {
      final v = o[k];
      if (v != null && v.toString().isNotEmpty) return v.toString();
    }
    return "-";
  }

  num _num(dynamic v) {
    if (v == null) return 0;
    if (v is num) return v;
    return num.tryParse(v.toString()) ?? 0;
  }
Future<void> _openSlotBooking(Map<String, dynamic> o) async {
  final orderId = _safe(o, ["orderId", "id"]);
  final distCode = _safe(o, ["distributorId", "distributorCode"]);
  final distName = _safe(o, ["distributorName", "agencyName"]);
  final amount = _num(o["amount"] ?? o["totalAmount"] ?? o["grandTotal"]).toDouble();

  await Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) => SlotBookingScreen(
        role: role, // ✅ MANAGER / MASTER / SALES / SALESMAN
        distributorCode: distCode,
        distributorName: distName,
        orderId: orderId,  // ✅ pass even for manager
        amount: amount,    // ✅ pass even for manager
      ),
    ),
  );

  await _load();
}

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(isManager ? "All Orders" : "My Orders"),
        actions: [
          IconButton(onPressed: _load, icon: const Icon(Icons.refresh))
        ],
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : ListView.builder(
              itemCount: orders.length,
              itemBuilder: (_, i) {
                final o = orders[i];

                final orderId = _safe(o, ["orderId", "id"]);
                final dist = _safe(o, [
                  "distributorName",
                  "agencyName",
                  "distributorId"
                ]);
                final amount = _num(o["amount"] ??
                    o["totalAmount"] ??
                    o["grandTotal"]);

                return Card(
                  margin: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 6),
                  child: ListTile(
                    title: Text(dist),
                    subtitle: Text("Order: $orderId"),
                    trailing: Text(
                      "₹${amount.toStringAsFixed(0)}",
                      style: const TextStyle(
                          fontWeight: FontWeight.bold),
                    ),
                    onTap: () => _openSlotBooking(o),
                  ),
                );
              },
            ),
    );
  }
}
