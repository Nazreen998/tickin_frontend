// ignore_for_file: deprecated_member_use, unused_local_variable, unused_import

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../app_scope.dart';
import 'manager_orders_flow_screen.dart';
import '../api/orders_flow_api.dart';

class ManagerOrdersWithSlotScreen extends StatefulWidget {
  const ManagerOrdersWithSlotScreen({super.key});

  @override
  State<ManagerOrdersWithSlotScreen> createState() =>
      _ManagerOrdersWithSlotScreenState();
}

class _ManagerOrdersWithSlotScreenState
    extends State<ManagerOrdersWithSlotScreen> {
  bool loading = false;
  bool _loadedOnce = false;

  List<Map<String, dynamic>> flows = [];

  // ✅ Default today
  String selectedDate = DateFormat("yyyy-MM-dd").format(DateTime.now());

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_loadedOnce) {
      _loadedOnce = true;
      _load();
    }
  }

void toast(String msg) {
  WidgetsBinding.instance.addPostFrameCallback((_) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg)),
    );
  });
}
  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.parse(selectedDate),
      firstDate: now.subtract(const Duration(days: 30)),
      lastDate: now.add(const Duration(days: 30)),
    );
    if (picked == null) return;

    setState(() {
      selectedDate = DateFormat("yyyy-MM-dd").format(picked);
    });
    await _load();
  }

  Future<void> _load() async {
    setState(() => loading = true);
    try {
      final scope = TickinAppScope.of(context);
      final flowApi = OrdersFlowApi(scope.httpClient);

      final res = await flowApi.slotConfirmedOrders(date: selectedDate);

      final list = (res["orders"] ?? res["data"] ?? []) as List;

      setState(() {
        flows = list.whereType<Map>().map((e) => e.cast<String, dynamic>()).toList();

        // Sort by slotTime
        flows.sort((a, b) {
          final atA = (a["slotTime"] ?? "").toString();
          final atB = (b["slotTime"] ?? "").toString();
          return atA.compareTo(atB);
        });
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
      if (v != null && v.toString().trim().isNotEmpty) return v.toString();
    }
    return "-";
  }

  num _num(dynamic v) {
    if (v == null) return 0;
    if (v is num) return v;
    return num.tryParse(v.toString()) ?? 0;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Manager Slot Flows"),
        actions: [
          IconButton(onPressed: _pickDate, icon: const Icon(Icons.calendar_month)),
          IconButton(onPressed: _load, icon: const Icon(Icons.refresh)),
        ],
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : flows.isEmpty
              ? const Center(child: Text("No Slot Confirmed Flows"))
              : ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: flows.length,
                  itemBuilder: (_, i) {
                    final f = flows[i];

                    final flowKey = _safe(f, ["flowKey"]);
                    final slotTime = _safe(f, ["slotTime"]);
                    final vType = _safe(f, ["vehicleType"]);
                    final status = _safe(f, ["status"]);

                    final orderIds = (f["orderIds"] ?? []) as List;
                    final distributors = (f["distributors"] ?? []) as List;

                    final totalQty = _num(f["totalQty"]);
                    final grand = _num(f["grandAmount"]);

                    final mainDist = distributors.isNotEmpty
                        ? (distributors.first is Map
                            ? (distributors.first["distributorName"] ?? "-").toString()
                            : "-")
                        : "-";

                    // ✅ pick first orderId for display only
                    final firstOrderId = orderIds.isNotEmpty ? orderIds.first.toString() : "-";

                    return Card(
                      elevation: 2,
                      child: ListTile(
                        title: Text(
                          "Slot: $slotTime  |  Orders: ${orderIds.length}",
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Text(
                          "Distributor: $mainDist\nVehicleType: $vType | Qty: $totalQty | Amount: ₹$grand\nStatus: $status\nFlowKey: $flowKey",
                        ),
                        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                        onTap: () {
                          if (flowKey == "-" || flowKey.isEmpty) {
                            toast("FlowKey missing");
                            return;
                          }

                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => ManagerOrderFlowScreen(
                                flowKey: flowKey,
                                // display-only id (flow fetch will use flowKey)
                                orderId: firstOrderId,
                              ),
                            ),
                          );
                        },
                      ),
                    );
                  },
                ),
    );
  }
}
