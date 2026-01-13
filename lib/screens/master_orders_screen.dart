import 'dart:convert';
import 'package:flutter/material.dart';
import '../app_scope.dart';

enum MasterOrderType { today, pending }

class MasterOrdersScreen extends StatefulWidget {
  final MasterOrderType type;

  const MasterOrdersScreen({super.key, required this.type});

  @override
  State<MasterOrdersScreen> createState() => _MasterOrdersScreenState();
}

class _MasterOrdersScreenState extends State<MasterOrdersScreen> {
  bool loading = false;
  bool _loadedOnce = false;

  String role = ""; // MASTER / MANAGER
  List<Map<String, dynamic>> orders = [];

  /// 🔹 Pending reasons
  final List<String> pendingReasons = const [
    "VEHICLE NOT AVAILABLE",
    "DRIVER NOT AVAILABLE",
    "PAYMENT ISSUE",
    "STOCK NOT AVAILABLE",
    "CUSTOMER REQUEST",
  ];

  // ================= ROLE HELPERS =================
  bool get isManager => role.contains("MANAGER");
  bool get isMaster => role.contains("MASTER");

  // ================= INIT =================
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_loadedOnce) {
      _loadedOnce = true;
      _initRoleAndLoad();
    }
  }

  Future<void> _initRoleAndLoad() async {
    try {
      final scope = TickinAppScope.of(context);
      final userJson = await scope.tokenStore.getUserJson();

      if (userJson != null && userJson.isNotEmpty) {
        final u = jsonDecode(userJson);
        role = (u["role"] ?? u["userRole"] ?? "").toString().toUpperCase();
      }
    } catch (_) {}

    await _load();
  }

  // ================= LOAD ORDERS =================
  Future<void> _load() async {
    setState(() => loading = true);
    try {
      final scope = TickinAppScope.of(context);

      final res = widget.type == MasterOrderType.today
          ? await scope.ordersApi.today()
          : await scope.ordersApi.pending();

      dynamic raw = res["orders"] ?? res["data"] ?? res;

      setState(() {
        orders = (raw is List ? raw : [])
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("❌ Load failed: $e")));
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  // ================= UI =================
  @override
  Widget build(BuildContext context) {
    final title = widget.type == MasterOrderType.today
        ? "Today Orders"
        : "Pending Orders";

    final isPendingScreen = widget.type == MasterOrderType.pending;

    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : orders.isEmpty
          ? const Center(child: Text("No orders found"))
          : ListView.builder(
              itemCount: orders.length,
              itemBuilder: (_, i) {
                final o = orders[i];

                final orderId = o["orderId"] ?? o["id"] ?? "-";
                final distributor =
                    o["distributorName"] ?? o["agencyName"] ?? "-";
                final amount =
                    o["amount"] ?? o["totalAmount"] ?? o["grandTotal"] ?? 0;

                /// 🔥 IMPORTANT FIX
                /// pendingReason = dropdown value
                /// _reasonCommitted = saved to DB or not
                final String? selectedReason = o["pendingReason"];
                final bool reasonCommitted =
                    (o["pendingReason"] != null &&
                    o["pendingReason"].toString().isNotEmpty);

                return Card(
                  margin: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // ---------- BASIC INFO ----------
                        Text(
                          distributor,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text("Order ID: $orderId"),
                        const SizedBox(height: 4),
                        Text(
                          "₹$amount",
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),

                        // =================================================
                        // 🔥 MANAGER ONLY – SELECT + SAVE (UNTIL COMMITTED)
                        // =================================================
                        if (isPendingScreen &&
                            isManager &&
                            !isMaster &&
                            !reasonCommitted) ...[
                          const SizedBox(height: 12),

                          DropdownButtonFormField<String>(
                            value: selectedReason,
                            hint: const Text("Select pending reason"),
                            items: pendingReasons
                                .map(
                                  (r) => DropdownMenuItem(
                                    value: r,
                                    child: Text(r),
                                  ),
                                )
                                .toList(),
                            onChanged: (val) {
                              setState(() {
                                // ❗ only selection, NOT saved
                                o["pendingReason"] = val;
                              });
                            },
                          ),
                          const SizedBox(height: 8),

                          ElevatedButton(
                            onPressed: o["pendingReason"] == null
                                ? null
                                : () async {
                                    try {
                                      final scope = TickinAppScope.of(context);

                                      await scope.ordersApi.updatePendingReason(
                                        orderId: orderId.toString(),
                                        reason: o["pendingReason"],
                                      );

                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        const SnackBar(
                                          content: Text("✅ Reason saved"),
                                        ),
                                      );

                                      // 🔥 IMPORTANT: reload from backend
                                      await _load();
                                    } catch (e) {
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        SnackBar(content: Text("❌ Failed: $e")),
                                      );
                                    }
                                  },
                            child: const Text("SAVE"),
                          ),
                        ],

                        // =================================================
                        // 🔒 READ ONLY – MASTER + MANAGER (AFTER SAVE)
                        // =================================================
                        if (isPendingScreen && reasonCommitted) ...[
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              const Icon(
                                Icons.info,
                                size: 16,
                                color: Colors.red,
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  "Reason: $selectedReason",
                                  style: const TextStyle(
                                    color: Colors.red,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}
