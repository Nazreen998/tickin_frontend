// ignore_for_file: deprecated_member_use, unnecessary_brace_in_string_interps, unrelated_type_equality_checks, unused_local_variable, unused_element, unnecessary_null_comparison, dead_code, avoid_print

import 'dart:convert';
import 'package:flutter/material.dart';
import '../slots/slot_generator.dart'; 
import '../../app_scope.dart';
import '../../models/slot_models.dart';
import '../../models/half_booking_model.dart';
import '../../widgets/slot_grid.dart';
import '../../widgets/slot_rules_card.dart';

class SlotBookingScreen extends StatefulWidget {
  final String role;
  final String distributorCode;
  final String distributorName;

  final String? orderId;
  final double? amount;

  /// ✅ IMPORTANT: locationId 1..5 for auto merge
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
    lastSlotOpenAfter: "16:30",
  );

  String companyCode = "";

  bool get isManager =>
      widget.role.toUpperCase() == "MANAGER" || widget.role.toUpperCase() == "MASTER";

  bool get isSales =>
      widget.role.toUpperCase() == "SALESMAN" ||
      widget.role.toUpperCase() == "SALES OFFICER" ||
      widget.role.toUpperCase() == "DISTRIBUTOR";

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
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));
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

List<String> _timesForSession(String session) {
  return sessionTimes[session] ?? const [];
}
List<SlotItem> get sessionFullSlots {
  final times = _timesForSession(selectedSession);

  final List<SlotItem> result = [];

  for (final t in times) {
    // FULL slots (A,B,C,D) 
    final slotsForTime = allSlots.where((s) {
      if (!s.isFull) return false;

      final nt = SlotItem.normalizeTime(s.time);
      if (nt != t) return false;

      if (!isManager && s.normalizedStatus == "DISABLED") return false;
      return true;
    }).toList();

    if (slotsForTime.isEmpty) continue;

    SlotItem pick = slotsForTime.first;
    final booked = slotsForTime.where((x) => x.isBooked).toList();
    if (booked.isNotEmpty) {
      pick = booked.first; // booked pos tile
    }

    result.add(pick);
  }

  // times order already correct (09:00, 09:30, ...)
  return result;
}
List<SlotItem> get sessionMergeSlots {
  final map = <String, SlotItem>{};

  for (final s in allSlots.where((x) => x.isMerge)) {
    final key = s.mergeKey ?? s.sk;

    if (!map.containsKey(key)) {
      map[key] = s;
    } else {
      final existing = map[key]!;
final mergedParticipants = <Map<String, dynamic>>[];
final seen = <String>{};

for (final p in [...existing.participants, ...s.participants]) {
  final oid = (p["orderId"] ?? "").toString();
  final uniqKey = oid.isNotEmpty ? oid : jsonEncode(p);
  if (seen.add(uniqKey)) mergedParticipants.add(p);
}
      final total = mergedParticipants.fold<double>(
        0,
        (sum, p) => sum + ((p["amount"] ?? 0) as num).toDouble(),
      );

      final status =
          mergedParticipants.length >= 2 && total >= rules.maxAmount
              ? "READY"
              : mergedParticipants.length >= 2
                  ? "WAITING"
                  : "PARTIAL";

      map[key] = existing.copyWith(
        participants: mergedParticipants,
        bookingCount: mergedParticipants.length,
        totalAmount: total,
        tripStatus: status,
      );
    }
  }

  // ❌ empty merge slots auto delete
  return map.values.where((s) => s.participants.isNotEmpty).toList();
}
Future<List<String>?> _pickOrdersToCancel(SlotItem mergeSlot) async {
  final scope = TickinAppScope.of(context);
  final mk = (mergeSlot.mergeKey ?? "").toString().trim();
  final t = (mergeSlot.time).toString().trim();

  if (mk.isEmpty || t.isEmpty) {
    toast("MergeKey / time missing");
    return null;
  }

  final bookings = await scope.slotsApi.getHalfBookingsRaw(
  date: selectedDate,
  mergeKey: mk,
  time: t,
);

if (bookings.isEmpty) {
  toast("No orders found");
  return null;
}

final selected = <String>{};

return showDialog<List<String>>(
  context: context,
  builder: (dialogCtx) {
    return AlertDialog(
      title: const Text("Select orders to cancel"),
      content: StatefulBuilder(
        builder: (ctx, setState) {
          return SizedBox(
            width: double.maxFinite,
            child: ListView(
              shrinkWrap: true,
              children: bookings.map((b) {
                final oid = (b["orderId"] ??
                        b["orderID"] ??
                        b["order_id"] ??
                        b["id"] ??
                        "")
                    .toString()
                    .trim();

                final agency = (b["agencyName"] ?? b["distributorName"] ?? "-")
                    .toString();

                final amt = (b["amount"] ?? 0);
                return CheckboxListTile(
                  value: selected.contains(oid),
                  title: Text(agency),
                  subtitle: Text("₹$amt • $oid"),
                  onChanged: oid.isEmpty
                      ? null
                      : (v) {
                          setState(() {
                            if (v == true) {
                              selected.add(oid);
                            } else {
                              selected.remove(oid);
                            }
                          });
                        },
                );
              }).toList(),
            ),
          );
        },
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogCtx),
          child: const Text("Close"),
        ),
        ElevatedButton(
          onPressed: () {
            if (selected.isEmpty) {
              ScaffoldMessenger.of(dialogCtx).showSnackBar(
                const SnackBar(content: Text("Select at least one order")),
              );
              return;
            }
            Navigator.pop(dialogCtx, selected.toList());
          },
          child: const Text("Cancel Selected"),
        ),
      ],
    );
  },
);
}
  /// ✅ VERY IMPORTANT FIX: flatten nested `slots: [fullSlots, mergeSlots]` :contentReference[oaicite:10]{index=10}
  Future<void> _loadGrid() async {
    setState(() => loading = true);

    try {
      final scope = TickinAppScope.of(context);
      if (companyCode.isEmpty) await _loadCompanyCode();

      final res = await scope.slotsApi.getGrid(
        companyCode: companyCode,
        date: selectedDate,
      );

      final rawSlots = (res["slots"] ?? []) as List; // [[],[]]
      final rawRules = (res["rules"] ?? {}) as Map;

      final List<Map<String, dynamic>> flattened = [];
      for (final block in rawSlots) {
        if (block is List) {
          for (final item in block) {
            if (item is Map) flattened.add(item.cast<String, dynamic>());
          }
        } else if (block is Map) {
          flattened.add(block.cast<String, dynamic>());
        }
      }

      final parsed = flattened.map((e) => SlotItem.fromMap(e)).toList();
      final unique = <String, SlotItem>{};
      for (final s in parsed) {
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

  /// ✅ booking (backend decides FULL / HALF based on amount threshold) :contentReference[oaicite:11]{index=11}
Future<void> _bookOrderSlot(SlotItem slot) async {
  if (booking) return;

  if (widget.orderId == null || widget.amount == null) {
    toast("❌ OrderId / Amount missing");
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
    );

    toast("✅ Booking success");
    await _loadGrid();
    if (!isManager && mounted) Navigator.pop(context, true);
  } catch (e) {
    toast("❌ Booking failed: $e");
  } finally {
    if (mounted) setState(() => booking = false);
  }
}
  /// ✅ FULL SLOT tap
  Future<void> _onFullSlotTap(SlotItem slot) async {
    if (booking) return;

    final st = slot.normalizedStatus;

    // MANAGER -> disable/enable/cancel/book
    if (isManager) {
      if (st == "DISABLED") {
        await _enableSlot(slot);
        return;
      }
if (slot.isBooked) {
  final act = await showDialog<String>(
    context: context,
    builder: (_) => AlertDialog(
      title: const Text("Slot Action"),
      content: Text("Slot ${slot.slotIdLabel} (${slot.sessionLabel})"),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, "cancel"),
          child: const Text("Cancel"),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, "rebook"),
          child: const Text("Rebook"),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text("Close"),
        ),
      ],
    ),
  );

  if (act == "cancel") {
    await _cancelFullSlot(slot);
  }

  if (act == "rebook") {
    await _cancelFullSlot(slot);
    await _loadGrid();
  }
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

    // SALES/DISTRIBUTOR -> only book if available
    if (!slot.isBooked && isSales) {
      final ok = await showDialog<bool>(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text("Confirm Slot Booking"),
          content: Text("Order: ${widget.orderId}\nSlot: ${slot.slotIdLabel} (${slot.sessionLabel})\nProceed booking?"),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("Cancel")),
            ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text("Book")),
          ],
        ),
      );
      if (ok == true) await _bookOrderSlot(slot);
      return;
    }
  }

  /// ✅ MERGE tile tap (manager confirm/manual merge)
  Future<void> _onMergeSlotTap(SlotItem mergeSlot) async {
    if (!isManager) return;

    final ts = (mergeSlot.tripStatus ?? "").toUpperCase();
    final canConfirm = ts.contains("READY"); // READY_FOR_CONFIRM

final act = await showDialog<String>(
  context: context,
  builder: (_) => AlertDialog(
    title: const Text("Merge Slot Action"),
    content: Text(
      "MergeKey: ${mergeSlot.mergeKey}\n"
      "Total: ₹${mergeSlot.totalAmount ?? 0}\n"
      "Status: ${mergeSlot.tripStatus}",
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context, "cancel"),
        child: const Text("Cancel Orders"),
      ),
      TextButton(
        onPressed: () => Navigator.pop(context, "rebook"),
        child: const Text("Rebook"),
      ),
      TextButton(
        onPressed: () => Navigator.pop(context, "manual"),
        child: const Text("Manual Merge"),
      ),
      if (canConfirm)
        ElevatedButton(
          onPressed: () => Navigator.pop(context, "confirm"),
          child: const Text("Confirm"),
        ),
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text("Close"),
      ),
    ],
  ),
);
if (act == "confirm") {
  await _confirmDayMerge(mergeSlot);
} else if (act == "manual") {
  await _manualMergeFlow(mergeSlot);
} else if (act == "cancel") {
  await _cancelHalfOrders(mergeSlot);
} else if (act == "rebook") {
  await _cancelHalfOrders(mergeSlot);
  await _loadGrid();
}
  }
Future<void> _cancelHalfOrders(SlotItem mergeSlot) async {
  try {
    final scope = TickinAppScope.of(context);

    final selectedOrderIds = await _pickOrdersToCancel(mergeSlot);
    print("✅ selectedOrderIds => $selectedOrderIds");

    if (selectedOrderIds == null || selectedOrderIds.isEmpty) return;

    for (final oid in selectedOrderIds) {
      final out = await scope.slotsApi.managerCancelBooking({
        "companyCode": companyCode,
        "date": selectedDate,
        "time": mergeSlot.time,
        "mergeKey": mergeSlot.mergeKey,
        "orderId": oid,
      });
      print("✅ cancel out => $out");
    }

    toast("✅ Selected HALF bookings cancelled");
    await _loadGrid();
  } catch (e) {
    toast("❌ HALF cancel failed: $e");
  }
}
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
Future<void> _confirmDayMerge(SlotItem mergeSlot) async {
  try {
    final scope = TickinAppScope.of(context);
    final managerId = await _managerId();

    // 1️⃣ get available FULL times
    final avail = await scope.slotsApi.availableFullTimes(
      date: selectedDate,
    );

    final rawTimes = avail["times"];
    final List<String> times = (rawTimes is List)
        ? rawTimes.map((e) => e.toString()).toList()
        : <String>[];

    if (times.isEmpty) {
      toast("❌ No FULL slots available");
      return;
    }

    // 2️⃣ ask manager to pick time
    final targetTime = await showDialog<String>(
      context: context,
      builder: (_) => SimpleDialog(
        title: const Text("Select FULL slot time"),
        children: times
            .map(
              (t) => SimpleDialogOption(
                onPressed: () => Navigator.pop(context, t),
                child: Text(t),
              ),
            )
            .toList(),
      ),
    );

    if (targetTime == null) return;

    // 3️⃣ call DATE-level merge confirm API
    await scope.slotsApi.managerConfirmDayMerge({
      "companyCode": companyCode,
      "date": selectedDate,
      "mergeKey": mergeSlot.mergeKey,
      "targetTime": targetTime,
      "managerId": managerId,
    });

    toast("✅ Merge confirmed → FULL booked");
    await _loadGrid();
  } catch (e) {
    toast("❌ Confirm failed: $e");
  }
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

  /// ✅ Manual merge dropdown -> Eligible bookings (time wise)
Future<void> _manualMergeFlow(SlotItem mergeSlot) async {
  try {
    final scope = TickinAppScope.of(context);

    // ✅ same date - get ALL waiting HALF (no time filter)
    final res = await scope.slotsApi.waitingHalfByDate(date: selectedDate);

    final listRaw = (res["bookings"] ?? res["data"] ?? []) as List;

    final allBookings = listRaw
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .where((b) {
          final vt = (b["vehicleType"] ?? "").toString().toUpperCase();
          final st = (b["status"] ?? "").toString().toUpperCase();
          return vt == "HALF" && (st.contains("PENDING") || st.contains("WAIT"));
        })
        .toList();

    if (allBookings.isEmpty) {
      toast("No waiting HALF bookings for this date");
      return;
    }

    // ✅ optional: sort by time so it's easy
    allBookings.sort((a, b) {
      final ta = (a["slotTime"] ?? a["time"] ?? "").toString();
final tb = (b["slotTime"] ?? b["time"] ?? "").toString();
      return ta.compareTo(tb);
    });

    final selectedBookingSks = await showDialog<List<String>>(
  context: context,
  builder: (_) => _MultiSelectOrdersDialog(bookings: allBookings),
);

if (selectedBookingSks == null || selectedBookingSks.length < 2) {
  toast("Select at least 2 orders");
  return;
}

// 1) fetch available full times
final avail = await scope.slotsApi.availableFullTimes(date: selectedDate);
final rawTimes = avail["times"];
final List<String> times = (rawTimes is List)
    ? rawTimes.map((e) => e.toString()).toList()
    : <String>[];


if (times.isEmpty) {
  toast("No FULL slots available for this date");
  return;
}

// 2) ask manager to pick time
final targetTime = await showDialog<String>(
  context: context,
  builder: (_) {
    final List<Widget> children = times.map<Widget>((t) {
      return SimpleDialogOption(
        onPressed: () => Navigator.pop(context, t),
        child: Text(t),
      );
    }).toList();

    return SimpleDialog(
      title: const Text("Select Available Time"),
      children: children,
    );
  },
);

if (targetTime == null) return;

// 3) call new backend endpoint
await scope.slotsApi.managerManualMergePickTime({
  "date": selectedDate,
  "targetTime": targetTime,
  "bookingSks": selectedBookingSks,
});

toast("✅ Manual merge done");
await _loadGrid();

  } catch (e) {
    toast("❌ Manual merge failed: $e");
  }
}
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

    if (slot.pos == null) {
      toast("Cancel requires slot position");
      return;
    }

    await scope.slotsApi.managerCancelBooking({
      "companyCode": companyCode,
      "date": selectedDate,
      "time": slot.time,
      "pos": slot.pos,
      if (slot.orderId != null) "orderId": slot.orderId,
    });

    toast("✅ Booking cancelled");
    await _loadGrid();
  } catch (e) {
    toast("❌ Cancel failed: $e");
  }
}

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
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: isSel ? Colors.blue : Colors.white,
                  foregroundColor: isSel ? Colors.white : Colors.black87,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                onPressed: () => setState(() => selectedSession = s),
                child: Text(s),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _datePicker() {
    return DropdownButton<String>(
      value: selectedDate,
      dropdownColor: Colors.black87,
      items: allowedDates()
          .map((d) => DropdownMenuItem(value: d, child: Text(d, style: const TextStyle(color: Colors.white))))
          .toList(),
      onChanged: (v) async {
        if (v == null) return;
        setState(() => selectedDate = v);
        await _loadGrid();
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final full = sessionFullSlots;
    final merge = sessionMergeSlots;

    return Scaffold(
      backgroundColor: const Color(0xFF061522),
      appBar: AppBar(
        backgroundColor: const Color(0xFF061522),
        title: const Text("Manager Slot Dashboard"),
        actions: [
          _datePicker(),
          const SizedBox(width: 10),
          IconButton(
            onPressed: _loadGrid,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                SlotRulesCard(
                  rules: rules,
                  isManager: isManager,
                  onEditThreshold: _editThreshold,
                  onToggleNightSlot: _toggleNightSlot,
                ),
                _sessionTabs(),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    children: [
                      Text("FULL Slots (${selectedSession})", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 10),
                      SizedBox(
                        height: 360,
                        child: SlotGrid(
                          slots: full,
                          role: widget.role,
                          myDistributorCode: widget.distributorCode,
                          onSlotTap: _onFullSlotTap,
                        ),
                      ),
                      const SizedBox(height: 18),
                      Text("HALF Merge Slots (${selectedSession})", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 10),
                      SizedBox(
                        height: 260,
                        child: SlotGrid(
                          slots: merge,
                          role: widget.role,
                          myDistributorCode: widget.distributorCode,
                          onSlotTap: _onMergeSlotTap,
                        ),
                      ),
                      const SizedBox(height: 30),
                    ],
                  ),
                ),
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
  final selected = <String>{};

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text("Select Orders (2+)"),
      content: SizedBox(
        width: double.maxFinite,
        height: 350,
        child: ListView.builder(
          itemCount: widget.bookings.length,
          itemBuilder: (_, i) {
            final b = widget.bookings[i];
            final oid = (b["orderId"] ?? "").toString();
            final dn = (b["distributorName"] ?? "-").toString();
            final amt = (b["amount"] ?? 0);
            final numAmt = (amt is num) ? amt : num.tryParse("$amt") ?? 0;
 // ✅ FIX: define time
  final time = (b["time"] ?? b["slotTime"] ?? b["bookingTime"] ?? "-").toString();
  final bookingSk = (b["sk"] ?? b["bookingSk"] ?? "").toString();
return CheckboxListTile(
  value: selected.contains(bookingSk),
  onChanged: (v) {
    setState(() {
      if (v == true) {
        selected.add(bookingSk);
      } else {
        selected.remove(bookingSk);
      }
    });
  },
  title: Text("$dn | ₹${numAmt.toStringAsFixed(0)}"),
  subtitle: Text("Time: $time   |   Order: $oid"),
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
