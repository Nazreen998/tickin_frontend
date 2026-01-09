// ignore_for_file: deprecated_member_use, unnecessary_to_list_in_spreads, unused_import

import 'package:flutter/material.dart';
import '../app_scope.dart';

import '../api/orders_flow_api.dart';
import '../api/users_api.dart';
import '../api/vehicles_api.dart';

class ManagerOrderFlowScreen extends StatefulWidget {
  final String flowKey;
  final String orderId; // display only

  const ManagerOrderFlowScreen({
    super.key,
    required this.flowKey,
    required this.orderId,
  });

  @override
  State<ManagerOrderFlowScreen> createState() => _ManagerOrderFlowScreenState();
}

class _ManagerOrderFlowScreenState extends State<ManagerOrderFlowScreen> {
  bool loading = false;

  Map<String, dynamic>? flowOrder; // flow["order"]
  String status = "";

  // dropdown states
  String? selectedVehicle;
  String? selectedDriverId;

  List<String> vehicles = [];
  List<Map<String, dynamic>> drivers = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadAll();
    });
  }

  void toast(String m) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));
  }

  num _num(dynamic v) {
    if (v == null) return 0;
    if (v is num) return v;
    return num.tryParse(v.toString()) ?? 0;
  }

  // ✅ tickin_users driver id field safe pick
 String _driverId(Map<String, dynamic> d) {
  final raw = d["pk"] ??
      d["driverId"] ??
      d["_id"] ??
      d["id"] ??
      d["userId"] ??
      d["mobile"] ??
      "";
  return raw.toString();
}
  String _driverName(Map<String, dynamic> d) {
    return (d["name"] ??
            d["fullName"] ??
            d["username"] ??
            d["mobile"] ??
            "Driver")
        .toString();
  }

  Future<void> _loadAll() async {
    setState(() => loading = true);
    try {
      final scope = TickinAppScope.of(context);

      final flowApi = OrdersFlowApi(scope.httpClient);
      final usersApi = UsersApi(scope.httpClient);
      final vehiclesApi = VehiclesApi(scope.httpClient);

      // ✅ FLOW IS SOURCE OF TRUTH
      final fRes = await flowApi.getOrderFlowByKey(widget.flowKey);

      final f = (fRes["order"] ??
              (fRes["data"]?["order"]) ??
              fRes["data"] ??
              fRes) as Map<String, dynamic>?;

      final st = (f?["status"] ?? "").toString();

      // ✅ Vehicles list
      final vList = await vehiclesApi.getAvailable();

      // ✅ Drivers list from tickin_users (role=DRIVER)
      final dRes = await usersApi.getDrivers();
      final dList = (dRes["drivers"] ?? []) as List;

      setState(() {
        flowOrder = f;
        status = st;

        vehicles = vList;
        drivers = dList.map((e) => Map<String, dynamic>.from(e)).toList();

        selectedVehicle =
            (flowOrder?["vehicleNo"] ?? flowOrder?["vehicleType"])?.toString();
        selectedDriverId = (flowOrder?["driverId"])?.toString();
      });
    } catch (e) {
      toast("❌ Load failed: $e");
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> _reloadFlow() async {
    try {
      final scope = TickinAppScope.of(context);
      final flowApi = OrdersFlowApi(scope.httpClient);

      final fRes = await flowApi.getOrderFlowByKey(widget.flowKey);

      final f = (fRes["order"] ??
              (fRes["data"]?["order"]) ??
              fRes["data"] ??
              fRes) as Map<String, dynamic>?;

      final st = (f?["status"] ?? "").toString();

      setState(() {
        flowOrder = f;
        status = st;
        selectedVehicle =
            (flowOrder?["vehicleNo"] ?? flowOrder?["vehicleType"])?.toString();
        selectedDriverId = (flowOrder?["driverId"])?.toString();
      });
    } catch (e) {
      toast("❌ Refresh failed: $e");
    }
  }

  Future<void> _vehicleSelected(String v) async {
    setState(() => loading = true);
    try {
      final scope = TickinAppScope.of(context);
      final flowApi = OrdersFlowApi(scope.httpClient);

      final res = await flowApi.vehicleSelected(widget.flowKey, v);
      if (res["ok"] == false) {
        throw Exception(res["message"] ?? "Vehicle select failed");
      }

      toast("✅ Vehicle Selected");
      setState(() => selectedVehicle = v);
      await _reloadFlow();
    } catch (e) {
      toast("❌ $e");
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> _loadingStart() async {
    if (selectedVehicle == null || selectedVehicle!.isEmpty) {
      toast("⚠️ Select vehicle first");
      return;
    }

    setState(() => loading = true);
    try {
      final scope = TickinAppScope.of(context);
      final flowApi = OrdersFlowApi(scope.httpClient);

      final res = await flowApi.loadingStart(widget.flowKey);
      if (res["ok"] == false) {
        throw Exception(res["message"] ?? "Loading Start failed");
      }

      toast("✅ Loading Started (Items Visible)");
      await _reloadFlow();
    } catch (e) {
      toast("❌ $e");
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> _loadingEnd() async {
    setState(() => loading = true);
    try {
      final scope = TickinAppScope.of(context);
      final flowApi = OrdersFlowApi(scope.httpClient);

      final res = await flowApi.loadingEnd(widget.flowKey);
      if (res["ok"] == false) {
        throw Exception(res["message"] ?? "Loading End failed");
      }

      toast("✅ Loading Ended");
      await _reloadFlow();
    } catch (e) {
      toast("❌ $e");
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> _assignDriver(String driverId) async {
    if (selectedVehicle == null || selectedVehicle!.isEmpty) {
      toast("⚠️ Select vehicle first");
      return;
    }

    setState(() => loading = true);
    try {
      final scope = TickinAppScope.of(context);
      final flowApi = OrdersFlowApi(scope.httpClient);

      final res = await flowApi.assignDriver(
        flowKey: widget.flowKey,
        driverId: driverId,
        vehicleNo: selectedVehicle,
      );

      if (res["ok"] == false) {
        throw Exception(res["message"] ?? "Assign Driver failed");
      }

      toast("✅ Driver Assigned");
      setState(() => selectedDriverId = driverId);
      await _reloadFlow();
    } catch (e) {
      toast("❌ $e");
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final orderIds = (flowOrder?["orderIds"] ?? []) as List;
    final items = (flowOrder?["items"] ?? []) as List;

    final totalQty = _num(flowOrder?["totalQty"]);
    final totalAmount = _num(flowOrder?["totalAmount"]);

    // ✅ Status logic: manager flow steps only until driver assigned
    final st = status.toUpperCase();
    final hasVehicle =
        selectedVehicle != null && selectedVehicle!.trim().isNotEmpty;

    final isConfirmed = st == "CONFIRMED";
    final isLoadingStarted = st == "LOADING_STARTED";
    final isLoadingDone = st == "LOADING_COMPLETED";
    final isDriverAssigned = st == "DRIVER_ASSIGNED";

    final canPickVehicle = isConfirmed && !isLoadingStarted && !isLoadingDone && !isDriverAssigned;
    final canStartLoading = isConfirmed && hasVehicle && !isLoadingStarted && !isLoadingDone && !isDriverAssigned;
    final canEndLoading = isLoadingStarted && !isLoadingDone && !isDriverAssigned;
    final canAssignDriver = isLoadingDone && !isDriverAssigned;

    final showItems = isLoadingStarted || isLoadingDone || isDriverAssigned;

    return Scaffold(
      appBar: AppBar(
        title: Text("Manager Flow (${orderIds.length} orders)"),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loadAll),
        ],
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : flowOrder == null
              ? const Center(child: Text("No Flow Data"))
              : ListView(
                  padding: const EdgeInsets.all(12),
                  children: [
                    _summaryCard(orderIds, totalQty, totalAmount),

                    const SizedBox(height: 12),

                    _vehicleDropdown(canPickVehicle),

                    const SizedBox(height: 12),

                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton(
                            onPressed: canStartLoading ? _loadingStart : null,
                            child: const Text("Loading Start"),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: canEndLoading ? _loadingEnd : null,
                            child: const Text("Loading End"),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 16),

                    // ✅ show items only after loading start
                    if (showItems) _itemsCard(items),

                    const SizedBox(height: 12),

                    // ✅ assign driver only after loading end
                    if (canAssignDriver) _driverDropdown(),

                    if (isDriverAssigned)
                      const Padding(
                        padding: EdgeInsets.only(top: 12),
                        child: Text(
                          "✅ Driver Assigned. Next steps will happen in Driver Login (Reached / Unload / Warehouse).",
                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                        ),
                      ),

                    const SizedBox(height: 20),

                    Text(
                      "Current Status: $status",
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
    );
  }

  Widget _summaryCard(List orderIds, num qty, num amount) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("FlowKey: ${widget.flowKey}",
                style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            Text("Orders: ${orderIds.join(", ")}"),
            const SizedBox(height: 6),
            Text("Total Qty: $qty"),
            const SizedBox(height: 6),
            Text("Total Amount: ₹$amount"),
            const SizedBox(height: 6),
            Text("Status: $status"),
          ],
        ),
      ),
    );
  }

  Widget _vehicleDropdown(bool enabled) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: DropdownButtonFormField<String>(
          value: selectedVehicle != null && vehicles.contains(selectedVehicle)
              ? selectedVehicle
              : null,
          decoration: const InputDecoration(
            labelText: "Select Vehicle",
            border: OutlineInputBorder(),
          ),
          items: vehicles
              .map((v) => DropdownMenuItem(value: v, child: Text(v)))
              .toList(),
          onChanged: enabled
              ? (v) {
                  if (v == null) return;
                  _vehicleSelected(v);
                }
              : null,
        ),
      ),
    );
  }

  Widget _driverDropdown() {
    // ✅ ensure drivers list exists
    if (drivers.isEmpty) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(12),
          child: Text("No drivers found (role=DRIVER)"),
        ),
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: DropdownButtonFormField<String>(
          value: selectedDriverId != null &&
                  drivers.any((d) => _driverId(d) == selectedDriverId)
              ? selectedDriverId
              : null,
          decoration: const InputDecoration(
            labelText: "Assign Driver",
            border: OutlineInputBorder(),
          ),
          items: drivers.map((d) {
            final id = _driverId(d);
            final name = _driverName(d);
            return DropdownMenuItem(value: id, child: Text(name));
          }).toList(),
          onChanged: (id) {
            if (id == null) return;
            _assignDriver(id);
          },
        ),
      ),
    );
  }

  Widget _itemsCard(List items) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("Loading Items",
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),

            if (items.isEmpty) const Text("No items"),

            ...items.map((e) {
              final m = e is Map ? e : {};
              final name = (m["itemName"] ?? m["name"] ?? "").toString();
              final qty = (m["qty"] ?? m["quantity"] ?? "").toString();
              final total = (m["total"] ?? m["amount"] ?? "").toString();
              final orderId = (m["orderId"] ?? "").toString();

              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: Text("$name\n$orderId")),
                    Text("x$qty"),
                    const SizedBox(width: 10),
                    Text("₹$total"),
                  ],
                ),
              );
            }).toList(),
          ],
        ),
      ),
    );
  }
}
