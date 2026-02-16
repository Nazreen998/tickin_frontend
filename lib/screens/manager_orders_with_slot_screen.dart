// ignore_for_file: deprecated_member_use, unused_import, unused_local_variable

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../app_scope.dart';
import '../api/orders_flow_api.dart';

import 'manager_orders_flow_screen.dart';
import 'order_unified_tracking_screen.dart';

class ManagerOrdersWithSlotScreen extends StatefulWidget {
  const ManagerOrdersWithSlotScreen({super.key});

  @override
  State<ManagerOrdersWithSlotScreen> createState() =>
      _ManagerOrdersWithSlotScreenState();
}

class _ManagerOrdersWithSlotScreenState
    extends State<ManagerOrdersWithSlotScreen> {
  bool loading = false;
  bool loadedOnce = false;

  List<Map<String, dynamic>> flows = [];
  String selectedDate = DateFormat("yyyy-MM-dd").format(DateTime.now());

  void toast(String msg) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!loadedOnce) {
      loadedOnce = true;
      _load();
    }
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

  String safe(Map o, List<String> keys) {
    for (final k in keys) {
      final v = o[k];
      if (v != null && v.toString().trim().isNotEmpty) return v.toString();
    }
    return "-";
  }

  num numSafe(dynamic v) {
    if (v == null) return 0;
    if (v is num) return v;
    return num.tryParse(v.toString()) ?? 0;
  }

  /// ✅ Best orderId for tracking (prefer ORD_FULL)
  String _trackingOrderId(Map<String, dynamic> flow) {
    // 0) direct full
    final fullDirect = flow["fullOrderId"] ??
        flow["masterFullOrderId"] ??
        flow["masterOrderId"] ??
        flow["masterOrder"];

    if (fullDirect != null) {
      final s = fullDirect.toString().trim();
      if (s.isNotEmpty && s != "null") return s;
    }

    // 1) merged into
    final merged = flow["mergedIntoOrderId"] ??
        flow["mergedInto"] ??
        flow["finalOrderId"] ??
        flow["finalOrder"];

    if (merged != null) {
      final s = merged.toString().trim();
      if (s.isNotEmpty && s != "null") return s;
    }

    // 2) orders[] inside
    final orders =
        (flow["orders"] is List) ? (flow["orders"] as List) : const [];

    for (final o in orders) {
      if (o is Map) {
        final oid = (o["fullOrderId"] ??
                o["mergedIntoOrderId"] ??
                o["orderId"] ??
                o["id"])
            ?.toString()
            .trim();

        if (oid != null && oid.isNotEmpty && oid != "null") {
          if (oid.startsWith("ORD_FULL_")) return oid;
        }
      }
    }

    // 3) orderIds list
    final list = (flow["orderIds"] is List)
        ? (flow["orderIds"] as List)
            .map((e) => e.toString())
            .where((x) => x.trim().isNotEmpty && x != "null")
            .toList()
        : <String>[];

    for (final x in list) {
      final s = x.trim();
      if (s.startsWith("ORD_FULL_")) return s;
    }

    // 4) fallback
    final fk = flow["flowKey"] ?? flow["orderId"] ?? flow["id"];
    if (fk != null) {
      final s = fk.toString().trim();
      if (s.isNotEmpty && s != "null") return s;
    }

    return "-";
  }
Future<void> _openTrackingFromFlow(Map<String, dynamic> flow) async {
  try {
    final fk = safe(flow, ["flowKey"]);
    if (fk == "-" || fk.isEmpty) {
      toast("FlowKey missing");
      return;
    }

    final scope = TickinAppScope.of(context);
    final api = OrdersFlowApi(scope.httpClient);

    final fRes = await api.getOrderFlowByKey(fk);

    final raw = (fRes["order"] ??
            (fRes["data"]?["order"]) ??
            fRes["data"] ??
            fRes);

    // parse as map safely
    final Map<String, dynamic>? fullFlow =
        (raw is Map) ? Map<String, dynamic>.from(raw) : null;

    final ordFull = (fullFlow?["orderId"] ??
            fullFlow?["fullOrderId"] ??
            "").toString().trim();

    final trackingId = (ordFull.isNotEmpty && ordFull != "null")
        ? ordFull
        : fk; // fallback

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => OrderUnifiedTrackingScreen(orderId: trackingId),
      ),
    );
  } catch (e) {
    toast("❌ Tracking failed: $e");
  }
}

  Future<void> _load() async {
    setState(() => loading = true);
    try {
      final scope = TickinAppScope.of(context);
      final api = OrdersFlowApi(scope.httpClient);

      final res = await api.slotConfirmedOrders(date: selectedDate);
      final list = (res["orders"] ?? res["data"] ?? []) as List;

      final parsed = list
          .whereType<Map>()
          .map((e) => e.cast<String, dynamic>())
          .toList();

      // ✅ DO NOT REMOVE SINGLE ORDER FLOWS
      final cleaned = parsed.where((f) {
  final fk = (f["flowKey"] ?? f["orderId"] ?? "").toString().trim();
  if (fk.isEmpty) return false;
  
  return true;
}).toList();
      cleaned.sort((a, b) {
        final atA = (a["slotTime"] ?? "").toString();
        final atB = (b["slotTime"] ?? "").toString();
        return atA.compareTo(atB);
      });

      setState(() => flows = cleaned);
    } catch (e) {
      toast("❌ Load failed: $e");
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Slot Confirmed Orders"),
        actions: [
          IconButton(
            icon: const Icon(Icons.calendar_month),
            onPressed: _pickDate,
          ),
          IconButton(icon: const Icon(Icons.refresh), onPressed: _load),
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

                    final flowKey = safe(f, ["flowKey"]);

                    final slotTime = safe(f, ["slotTime"]);
                    final vType = safe(f, ["vehicleType"]);

                    final orderIds = (f["orderIds"] ?? []) as List;
                    final distributors = (f["distributors"] ?? []) as List;

                    final totalQty = numSafe(f["totalQty"]);

                    // ✅ For manager screen
                    final firstOrderId = _trackingOrderId(f);

                    // ✅ For tracking icon (same id)
                    final trackingId = _trackingOrderId(f);

                    final distNames = <String>[];
                    for (final d in distributors) {
                      if (d is Map) {
                        final name =
                            (d["distributorName"] ?? d["name"] ?? "")
                                .toString();
                        if (name.trim().isNotEmpty) distNames.add(name);
                      } else if (d != null) {
                        final name = d.toString();
                        if (name.trim().isNotEmpty) distNames.add(name);
                      }
                    }

                    final mainDist = distNames.isNotEmpty
                        ? distNames.asMap().entries
                            .map((e) => "D${e.key + 1}: ${e.value}")
                            .join(" | ")
                        : "-";

                    return Card(
                      elevation: 2,
                      child: ListTile(
                        title: Text(
                          "Slot: $slotTime | Orders: ${orderIds.length}",
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Text(
                          "Distributor: $mainDist\n"
                          "VehicleType: $vType | Qty: $totalQty | "
                      
                          "FlowKey: $trackingId",
                        ),
                        trailing: Wrap(
                          spacing: 8,
                          children: [
                            IconButton(
                              tooltip: "Tracking",
                              icon: const Icon(Icons.track_changes),
                              onPressed: () =>_openTrackingFromFlow(f),
                            ),
                            const Icon(Icons.arrow_forward_ios, size: 16),
                          ],
                        ),
                        onTap: () {
                          if (flowKey == "-" || flowKey.isEmpty) {
                            toast("FlowKey missing");
                            return;
                          }

                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => ManagerOrderFlowScreen(
                                flowKey: flowKey, // backend flowKey
                                orderId: firstOrderId, // ORD_FULL if available
                                slotTime: slotTime,
                                distributors: distNames,
                                totalQty: totalQty,
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
