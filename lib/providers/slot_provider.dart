import 'dart:convert';
import 'package:flutter/material.dart';
import '../../app_scope.dart';
import '../models/slot_models.dart';

class SlotProvider extends ChangeNotifier {
  final BuildContext context;
  SlotProvider(this.context);

  bool loading = false;
  bool booking = false;

  String selectedDate = "";
  String companyCode = "";

  List<SlotItem> allSlots = [];
  SlotRules rules = SlotRules(maxAmount: 80000, lastSlotEnabled: false, lastSlotOpenAfter: "17:00");

  // session tabs
  String selectedSession = "Morning";

  // ✅ Helpers
  String sessionFromTime(String time) {
    switch (time.trim()) {
      case "09:00":
        return "Morning";
      case "12:30":
        return "Afternoon";
      case "16:00":
        return "Evening";
      case "20:00":
        return "Night";
      default:
        return "Morning";
    }
  }

  List<SlotItem> get fullSlots {
    final list = allSlots.where((s) => s.isFull && s.normalizedStatus != "DISABLED").toList();
    return _uniqueBySk(list);
  }

  List<SlotItem> get mergeSlots {
    final list = allSlots.where((s) => s.isMerge).toList();
    return _uniqueBySk(list);
  }

  // ✅ Filtered FULL slots for UI by session
  List<SlotItem> get sessionFullSlots {
    final sess = selectedSession;
    return fullSlots.where((s) => sessionFromTime(s.time) == sess).toList()
      ..sort((a, b) => a.slotIdNum.compareTo(b.slotIdNum));
  }

  // ✅ Filtered HALF merge cards for UI by session
  List<SlotItem> get sessionMergeSlots {
    final sess = selectedSession;
    return mergeSlots.where((s) => sessionFromTime(s.time) == sess).toList();
  }

  List<SlotItem> _uniqueBySk(List<SlotItem> list) {
    final map = <String, SlotItem>{};
    for (final s in list) {
      map[s.sk] = s;
    }
    return map.values.toList();
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

  Future<void> initIfNeeded() async {
    if (selectedDate.isEmpty) {
      selectedDate = _today();
      await _loadCompanyCode();
      await loadGrid();
    }
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

  Future<void> loadGrid() async {
    loading = true;
    notifyListeners();
    try {
      final scope = TickinAppScope.of(context);
      if (companyCode.isEmpty) await _loadCompanyCode();

      final res = await scope.slotsApi.getGrid(companyCode: companyCode, date: selectedDate);

      final rawSlots = (res["slots"] ?? []) as List;
      final rawRules = (res["rules"] ?? {}) as Map;

      final parsed = rawSlots.whereType<Map>().map((e) => SlotItem.fromMap(e.cast<String, dynamic>())).toList();

      // ✅ Duplicate fix: Unique by SK
      final unique = <String, SlotItem>{};
      for (final s in parsed) {
        unique[s.sk] = s;
      }

      allSlots = unique.values.toList();
      rules = SlotRules.fromMap(rawRules.cast<String, dynamic>());
    } catch (_) {
      allSlots = [];
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  Future<bool> bookFullSlot({
    required SlotItem slot,
    required String distributorCode,
    required String distributorName,
    required String orderId,
    required double amount,
  }) async {
    booking = true;
    notifyListeners();

    try {
      final scope = TickinAppScope.of(context);

      await scope.slotsApi.book(
        companyCode: companyCode,
        date: selectedDate,
        time: slot.time,
        pos: slot.pos, // backend needs pos but UI won't show
        distributorCode: distributorCode,
        distributorName: distributorName,
        amount: amount,
        orderId: orderId,
      );

      await loadGrid();
      return true;
    } catch (_) {
      return false;
    } finally {
      booking = false;
      notifyListeners();
    }
  }

  void setSession(String s) {
    selectedSession = s;
    notifyListeners();
  }

  void setDate(String d) {
    selectedDate = d;
    notifyListeners();
  }
}
