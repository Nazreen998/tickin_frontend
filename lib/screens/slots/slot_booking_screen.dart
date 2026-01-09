// ignore_for_file: deprecated_member_use, unused_element, curly_braces_in_flow_control_structures

import 'dart:convert';
import 'package:flutter/material.dart';

import '../../app_scope.dart';
import '../../models/slot_models.dart';
import '../../widgets/slot_grid.dart';
import '../../widgets/slot_rules_card.dart';

class SlotBookingScreen extends StatefulWidget {
  final String role; // SALES OFFICER / SALESMAN / DISTRIBUTOR / MANAGER / MASTER
  final String distributorCode;
  final String distributorName;

  // ✅ Only needed when booking from orders
  final String? orderId;
  final double? amount;

  // ✅ NEW: for strict auto merge
  final String? locationId;

  const SlotBookingScreen({
    super.key,
    required this.role,
    required this.distributorCode,
    required this.distributorName,
    this.orderId,
    this.amount,
    this.locationId,
  });

  @override
  State<SlotBookingScreen> createState() => _SlotBookingScreenState();
}

class _SlotBookingScreenState extends State<SlotBookingScreen> {
  bool loading = false;
  bool booking = false;

  String selectedDate = "";
  String selectedSession = "Morning";

  List<SlotItem> allSlots = [];
  SlotRules rules = SlotRules(
    maxAmount: 80000,
    lastSlotEnabled: false,
    lastSlotOpenAfter: "17:00",
  );

  String companyCode = "";

  bool get isManager => widget.role.toUpperCase() == "MANAGER";
  bool get isMaster => widget.role.toUpperCase() == "MASTER";

  bool get isSalesman =>
      widget.role.toUpperCase() == "SALESMAN" ||
      widget.role.toUpperCase() == "SALES OFFICER";

  bool get canBook => !isMaster;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (selectedDate.isEmpty) {
      selectedDate = _today();
      _init();
    }
  }

  String _today() {
    final now = DateTime.now();
    return "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";
  }

  String _tomorrow() {
    final now = DateTime.now().add(const Duration(days: 1));
    return "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";
  }

  List<String> allowedDates() => [_today(), _tomorrow()];

  void toast(String m) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(m)),
    );
  }

  Future<void> _init() async {
    await _loadCompanyCode();
    await _loadGrid();
  }

  Future<void> _loadCompanyCode() async {
    try {
      final scope = TickinAppScope.of(context);
      final userJson = await scope.tokenStore.getUserJson();
      if (userJson != null && userJson.isNotEmpty) {
        final u = jsonDecode(userJson) as Map<String, dynamic>;
        final cid = (u["companyId"] ?? u["companyCode"] ?? "").toString();
        companyCode = cid.contains("#") ? cid.split("#").last : cid;
      }
    } catch (_) {}

    companyCode = companyCode.isEmpty ? "VAGR_IT" : companyCode;
  }

  String _timeFromSession(String session) {
    if (session == "Morning") return "09:00";
    if (session == "Afternoon") return "12:30";
    if (session == "Evening") return "16:00";
    return "20:00";
  }

  List<SlotItem> get sessionFullSlots {
    final time = _timeFromSession(selectedSession);

    return allSlots.where((s) {
      if (!s.isFull) return false;
      if (s.time != time) return false;
      if (!isManager && s.normalizedStatus == "DISABLED") return false;
      return true;
    }).toList();
  }

  List<SlotItem> get sessionMergeSlots {
    final time = _timeFromSession(selectedSession);

    return allSlots.where((s) {
      if (!s.isMerge) return false;
      if (s.time != time) return false;
      if ((s.tripStatus ?? "").toUpperCase() == "FULL") return false;
      return true;
    }).toList();
  }

  Future<void> _loadGrid() async {
    setState(() => loading = true);

    try {
      final scope = TickinAppScope.of(context);
      if (companyCode.isEmpty) await _loadCompanyCode();

      final res = await scope.slotsApi.getGrid(
        companyCode: companyCode,
        date: selectedDate,
      );

      final rawSlots = (res["slots"] ?? []) as List;
      final rawRules = (res["rules"] ?? {}) as Map;

      final parsedSlots = rawSlots
          .whereType<Map>()
          .map((e) => SlotItem.fromMap(e.cast<String, dynamic>()))
          .toList();

      final unique = <String, SlotItem>{};
      for (final s in parsedSlots) {
        unique[s.sk] = s;
      }

      setState(() {
        allSlots = unique.values.toList();
        rules = SlotRules.fromMap(rawRules.cast<String, dynamic>());
      });
    } catch (e) {
      toast("❌ Grid load failed: $e");
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  /* =====================================================
      ✅ BOOK SLOT
  ====================================================== */
  Future<void> _bookOrderSlot(SlotItem slot) async {
    if (booking) return;

    if (widget.orderId == null || widget.amount == null) {
      toast("❌ OrderId / Amount missing. Booking must start from Orders screen.");
      return;
    }

    setState(() => booking = true);

    try {
      final scope = TickinAppScope.of(context);

      await scope.slotsApi.book(
        companyCode: companyCode,
        date: selectedDate,
        time: slot.time,
        pos: slot.pos,
        distributorCode: widget.distributorCode,
        distributorName: widget.distributorName,
        amount: widget.amount!,
        orderId: widget.orderId!,
        locationId: widget.locationId, // ✅ FIXED
      );

      toast("✅ Booking success (backend decides FULL/HALF)");
      await _loadGrid();

      if (!isManager && mounted) Navigator.pop(context, true);
    } catch (e) {
      toast("❌ Booking failed: $e");
    } finally {
      if (mounted) setState(() => booking = false);
    }
  }

  /* =====================================================
      ✅ FULL SLOT TAP HANDLER
  ====================================================== */
  Future<void> _onFullSlotTap(SlotItem slot) async {
    if (!canBook) return;
    if (booking) return;

    final st = slot.normalizedStatus;

    if (isManager) {
      if (st == "DISABLED") {
        await _enableSlot(slot);
        return;
      }

      if (slot.isBooked) {
        final ok = await showDialog<bool>(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text("Cancel Booking?"),
            content: Text("Slot ${slot.slotIdLabel} already booked.\nCancel it?"),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("No")),
              ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text("Yes Cancel")),
            ],
          ),
        );

        if (ok == true) await _cancelFullSlot(slot);
        return;
      }

      final act = await showDialog<String>(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text("Manager Action"),
          content: Text("Slot ${slot.slotIdLabel} (${slot.sessionLabel})"),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, "disable"), child: const Text("Disable")),
            ElevatedButton(onPressed: () => Navigator.pop(context, "book"), child: const Text("Book")),
          ],
        ),
      );

      if (act == "disable") await _disableSlot(slot);
      if (act == "book") await _bookOrderSlot(slot);

      return;
    }

    if (isSalesman) {
      if (slot.isBooked) return;

      final ok = await showDialog<bool>(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text("Confirm Slot Booking"),
          content: Text(
            "Order: ${widget.orderId}\nSlot: ${slot.slotIdLabel} (${slot.sessionLabel})\nProceed booking?",
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("Cancel")),
            ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text("Book")),
          ],
        ),
      );

      if (ok == true) await _bookOrderSlot(slot);
      return;
    }

    toast("⚠️ Booking not allowed for this role");
  }

  /* =====================================================
      ✅ MANAGER: ENABLE / DISABLE / CANCEL FULL
  ====================================================== */
  Future<void> _disableSlot(SlotItem slot) async {
    try {
      final scope = TickinAppScope.of(context);
      await scope.slotsApi.managerDisableSlot({
        "companyCode": companyCode,
        "date": selectedDate,
        "time": slot.time,
        "pos": slot.pos,
        "vehicleType": "FULL",
      });
      toast("✅ Slot disabled");
      await _loadGrid();
    } catch (e) {
      toast("❌ Disable failed: $e");
    }
  }

  Future<void> _enableSlot(SlotItem slot) async {
    try {
      final scope = TickinAppScope.of(context);
      await scope.slotsApi.managerEnableSlot({
        "companyCode": companyCode,
        "date": selectedDate,
        "time": slot.time,
        "pos": slot.pos,
        "vehicleType": "FULL",
      });
      toast("✅ Slot enabled");
      await _loadGrid();
    } catch (e) {
      toast("❌ Enable failed: $e");
    }
  }

  Future<void> _cancelFullSlot(SlotItem slot) async {
    try {
      final scope = TickinAppScope.of(context);

      if (slot.pos == null || slot.userId == null) {
        toast("Cancel requires pos + userId");
        return;
      }

      await scope.slotsApi.managerCancelBooking({
        "companyCode": companyCode,
        "date": selectedDate,
        "time": slot.time,
        "pos": slot.pos,
        "userId": slot.userId,

        // ✅ IMPORTANT: send orderId if exists (lock delete)
        if (slot.orderId != null) "orderId": slot.orderId,
      });

      toast("✅ Booking cancelled");
      await _loadGrid();
    } catch (e) {
      toast("❌ Cancel failed: $e");
    }
  }

  /* =====================================================
      ✅ MANAGER: MERGE CONFIRM / MANUAL MERGE
  ====================================================== */

  Future<String> _managerId() async {
    try {
      final scope = TickinAppScope.of(context);
      final userJson = await scope.tokenStore.getUserJson();
      if (userJson != null && userJson.isNotEmpty) {
        final u = jsonDecode(userJson);
        return (u["userId"] ?? u["id"] ?? u["sk"] ?? "MANAGER").toString();
      }
    } catch (_) {}
    return "MANAGER";
  }

  Future<void> _confirmMerge(SlotItem mergeSlot) async {
    try {
      final scope = TickinAppScope.of(context);
      final managerId = await _managerId();

      await scope.slotsApi.managerConfirmMerge({
        "companyCode": companyCode,
        "date": selectedDate,
        "time": mergeSlot.time,
        "mergeKey": mergeSlot.mergeKey,
        "managerId": managerId,
      });

      toast("✅ Merge Confirmed → FULL slot booked");
      await _loadGrid();
    } catch (e) {
      toast("❌ Confirm merge failed: $e");
    }
  }

  Future<void> _manualMergeFlow(SlotItem mergeSlot) async {
    try {
      final scope = TickinAppScope.of(context);
      final managerId = await _managerId();

      final eligible = await scope.httpClient.get(
        "/api/slots/eligible-half-bookings",
        query: {
          "date": selectedDate,
          "time": mergeSlot.time,
        },
      );

      final listRaw = (eligible["bookings"] ?? eligible["items"] ?? []) as List;
      final bookings = listRaw
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();

      if (bookings.isEmpty) {
        toast("No eligible HALF bookings");
        return;
      }

      final selected = await showDialog<List<String>>(
        context: context,
        builder: (_) => _MultiSelectOrdersDialog(bookings: bookings),
      );

      if (selected == null || selected.length < 2) {
        toast("Select at least 2 orders");
        return;
      }

      await scope.slotsApi.managerMergeOrdersManual({
        "companyCode": companyCode,
        "date": selectedDate,
        "time": mergeSlot.time,
        "orderIds": selected,
        "targetMergeKey": mergeSlot.mergeKey,
        "managerId": managerId,
      });

      toast("✅ Manual merge done");
      await _loadGrid();
    } catch (e) {
      toast("❌ Manual merge failed: $e");
    }
  }

  /* =====================================================
      ✅ RULES ACTIONS
  ====================================================== */

  Future<void> _editThreshold() async {
    final ctrl = TextEditingController(text: rules.maxAmount.toStringAsFixed(0));
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Update Threshold"),
        content: TextField(
          controller: ctrl,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(hintText: "Enter new threshold"),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("Cancel")),
          ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text("Update")),
        ],
      ),
    );

    if (ok != true) return;

    try {
      final scope = TickinAppScope.of(context);
      final val = double.tryParse(ctrl.text.trim()) ?? rules.maxAmount;

      await scope.slotsApi.managerSetGlobalMax({
        "companyCode": companyCode,
        "maxAmount": val,
      });

      toast("✅ Threshold Updated");
      await _loadGrid();
    } catch (e) {
      toast("❌ Threshold update failed: $e");
    }
  }

  Future<void> _toggleNightSlot() async {
    try {
      final scope = TickinAppScope.of(context);

      await scope.slotsApi.toggleLastSlot({
        "companyCode": companyCode,
        "enabled": !rules.lastSlotEnabled,
        "openAfter": rules.lastSlotOpenAfter,
      });

      toast("✅ Night slot updated");
      await _loadGrid();
    } catch (e) {
      toast("❌ Night slot toggle failed: $e");
    }
  }

  /* =====================================================
      ✅ UI Widgets
  ====================================================== */

  Widget _sessionTabs() {
    final sessions = ["Morning", "Afternoon", "Evening", "Night"];
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        children: sessions.map((s) {
          final isSel = selectedSession == s;
          return Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: InkWell(
                onTap: () => setState(() => selectedSession = s),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    color: isSel ? Colors.blue.shade700 : Colors.grey.shade200,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Center(
                    child: Text(
                      s,
                      style: TextStyle(
                        color: isSel ? Colors.white : Colors.black87,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _mergeBottomGrid() {
    final merge = sessionMergeSlots;

    if (merge.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(12),
        child: Text("No merge slots", style: TextStyle(color: Colors.white70)),
      );
    }

    return SizedBox(
      height: 260,
      child: SlotGrid(
        slots: merge,
        role: widget.role,
        myDistributorCode: widget.distributorCode,
        onSlotTap: (s) async {
          if (!isManager) return;

          final ts = (s.tripStatus ?? "PARTIAL").toUpperCase();
          final ready = ts.contains("READY");

          final act = await showDialog<String>(
            context: context,
            builder: (_) => AlertDialog(
              title: const Text("Merge Action"),
              content: Text(
                "Merge: ${s.mergeKey}\nTrip: $ts\nTotal: ₹${(s.totalAmount ?? 0).toStringAsFixed(0)}",
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, "manual"),
                  child: const Text("Manual Merge"),
                ),
                ElevatedButton(
                  onPressed: ready ? () => Navigator.pop(context, "confirm") : null,
                  child: const Text("Confirm Merge"),
                ),
              ],
            ),
          );

          if (act == "manual") await _manualMergeFlow(s);
          if (act == "confirm") {
            final ok = await showDialog<bool>(
              context: context,
              builder: (_) => AlertDialog(
                title: const Text("Confirm Merge?"),
                content: Text("Confirm merge: ${s.mergeKey}?"),
                actions: [
                  TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("No")),
                  ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text("Yes Confirm")),
                ],
              ),
            );

            if (ok == true) await _confirmMerge(s);
          }
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final full = sessionFullSlots;

    return Scaffold(
      backgroundColor: const Color(0xFF06121F),
      appBar: AppBar(
        title: Text(isManager ? "Manager Slot Dashboard" : "Slot Booking"),
        actions: [
          DropdownButton<String>(
            value: selectedDate,
            dropdownColor: Colors.black,
            underline: const SizedBox(),
            items: allowedDates()
                .map((d) => DropdownMenuItem(value: d, child: Text(d)))
                .toList(),
            onChanged: (v) async {
              if (v == null) return;
              setState(() => selectedDate = v);
              await _loadGrid();
            },
          ),
          IconButton(onPressed: _loadGrid, icon: const Icon(Icons.refresh)),
        ],
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : booking
              ? const Center(child: CircularProgressIndicator())
              : ListView(
                  children: [
                    SlotRulesCard(
                      rules: rules,
                      isManager: isManager,
                      onEditThreshold: _editThreshold,
                      onToggleNightSlot: _toggleNightSlot,
                    ),
                    _sessionTabs(),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      child: Text(
                        "FULL Slots ($selectedSession)",
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                    ),
                    SizedBox(
                      height: 260,
                      child: SlotGrid(
                        slots: full,
                        role: widget.role,
                        myDistributorCode: widget.distributorCode,
                        onSlotTap: _onFullSlotTap,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      child: Text(
                        "HALF Merge Slots ($selectedSession)",
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                    ),
                    _mergeBottomGrid(),
                    const SizedBox(height: 16),
                  ],
                ),
    );
  }
}

class _MultiSelectOrdersDialog extends StatefulWidget {
  final List<Map<String, dynamic>> bookings;
  const _MultiSelectOrdersDialog({required this.bookings});

  @override
  State<_MultiSelectOrdersDialog> createState() => _MultiSelectOrdersDialogState();
}

class _MultiSelectOrdersDialogState extends State<_MultiSelectOrdersDialog> {
  final Set<String> selected = {};

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text("Select 2+ HALF bookings"),
      content: SizedBox(
        width: double.maxFinite,
        height: 320,
        child: ListView.builder(
          itemCount: widget.bookings.length,
          itemBuilder: (_, i) {
            final b = widget.bookings[i];
            final oid = (b["orderId"] ?? "").toString();
            final dn = (b["distributorName"] ?? "").toString();
            final amt = (b["amount"] ?? 0).toString();
            final checked = selected.contains(oid);

            return CheckboxListTile(
              value: checked,
              title: Text(dn.isEmpty ? "-" : dn),
              subtitle: Text("Order: $oid | ₹$amt"),
              onChanged: (v) {
                setState(() {
                  if (v == true) selected.add(oid);
                  else selected.remove(oid);
                });
              },
            );
          },
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
        ElevatedButton(
          onPressed: () => Navigator.pop(context, selected.toList()),
          child: const Text("Merge"),
        ),
      ],
    );
  }
}
