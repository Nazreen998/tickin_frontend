// ignore_for_file: dead_code, unnecessary_null_comparison, unnecessary_to_list_in_spreads

import 'package:flutter/material.dart';
import '../models/slot_models.dart';

class SlotGrid extends StatelessWidget {
  final List<SlotItem> slots;
  final void Function(SlotItem slot) onSlotTap;

  final String role;
  final String? myDistributorCode;

  const SlotGrid({
    super.key,
    required this.slots,
    required this.onSlotTap,
    required this.role,
    this.myDistributorCode,
  });

  bool get isManager =>
      role.toUpperCase() == "MANAGER" || role.toUpperCase() == "MASTER";

  int _mergeSlotId(SlotItem s) {
    final mk = (s.mergeKey ?? "0").toString();
    final hash = mk.codeUnits.fold<int>(0, (p, c) => p + c);
    return 5000 + (hash % 1000);
  }

  @override
  Widget build(BuildContext context) {
    if (slots.isEmpty) {
      return const Center(
        child: Text("No slots", style: TextStyle(color: Colors.white70)),
      );
    }

    /// ✅ Remove duplicates by key (FULL pos, MERGE mergeKey)
    final map = <String, SlotItem>{};
    for (final s in slots) {
      final key = s.isMerge
          ? "MERGE#${s.time}#${s.mergeKey ?? s.sk}"
          : "FULL#${s.time}#${s.pos ?? ''}";
      map[key] = s;
    }

    final list = map.values.toList();

    /// ✅ sort by slotId
    list.sort((a, b) {
      final aKey = a.isMerge ? _mergeSlotId(a) : a.slotIdNum;
      final bKey = b.isMerge ? _mergeSlotId(b) : b.slotIdNum;
      return aKey.compareTo(bKey);
    });

    return GridView.builder(
      itemCount: list.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 1.05,
      ),
      itemBuilder: (_, i) {
        final slot = list[i];
        return _SlotTile(
          slot: slot,
          role: role,
          myDistributorCode: myDistributorCode,
          mergeId: slot.isMerge ? _mergeSlotId(slot) : null,
          onTap: () => onSlotTap(slot),
        );
      },
    );
  }
}

class _SlotTile extends StatelessWidget {
  final SlotItem slot;
  final VoidCallback onTap;
  final String role;
  final String? myDistributorCode;
  final int? mergeId;

  const _SlotTile({
    required this.slot,
    required this.onTap,
    required this.role,
    required this.myDistributorCode,
    required this.mergeId,
  });

  bool get isManager =>
      role.toUpperCase() == "MANAGER" || role.toUpperCase() == "MASTER";

  Color _bg() {
    final st = slot.normalizedStatus;

    if (st == "DISABLED") return Colors.grey.shade700;
    if (st == "BOOKED") return Colors.red.shade700;

    if (slot.isMerge) {
      final ts = (slot.tripStatus ?? "").toUpperCase();
      if (ts.contains("READY")) return Colors.orange.shade700;
      if (ts.contains("PARTIAL")) return Colors.orange.shade700;
      if (ts.contains("FULL")) return Colors.red.shade700;
    }

    if (st.contains("PENDING") || st.contains("WAIT")) {
      return Colors.orange.shade700;
    }

    return Colors.green.shade700;
  }

  String _label() {
    final st = slot.normalizedStatus;

    if (st == "DISABLED") return "DISABLED";
    if (st == "BOOKED") return "BOOKED";

    if (slot.isMerge && slot.tripStatus != null) {
      final ts = slot.tripStatus!.toUpperCase();
      if (ts.contains("READY")) return "READY";
      if (ts.contains("PARTIAL")) return "WAITING";
      if (ts.contains("FULL")) return "BOOKED";
    }

    if (st.contains("PENDING") || st.contains("WAIT")) return "WAITING";

    return "AVAILABLE";
  }

  bool _canShowDistributor() {
    if (isManager) return true;

    if (myDistributorCode == null) return false;
    return slot.distributorCode == myDistributorCode;
  }

  /// ✅ For FULL slot: amount = slot.amount
  /// ✅ For MERGE slot: amount = slot.totalAmount
  String _amountText() {
    final num val = slot.isMerge ? (slot.totalAmount ?? 0) : (slot.amount ?? 0);
    return "₹${val.toStringAsFixed(0)}";
  }

  /// ✅ Merge tile extra info
  String _mergeCountText() {
    if (!slot.isMerge) return "";
    final c = slot.bookingCount ?? (slot.participants.length);
    return c > 0 ? "$c Orders" : "";
  }

  String _fullDistributorName() {
    return (slot.distributorName ?? "").trim();
  }

  /// ✅ Participants list safe conversion
  List<Map<String, dynamic>> _participantsList() {
    final p = slot.participants;
    if (p == null) return [];
    return p.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
  }

  @override
  Widget build(BuildContext context) {
    final label = _label();
    final canShowDist = _canShowDistributor();

    /// ✅ show details always for MERGE or booked/waiting full
    final showDetails = slot.isMerge || label != "AVAILABLE";

    final title =
        slot.isMerge ? "Merge ${mergeId ?? "-"}" : "Slot ${slot.slotIdLabel}";
    final session = slot.sessionLabel;
    final mergeCount = _mergeCountText();

    final participants = _participantsList();

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: _bg(),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              title,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),

            Text(
              session,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),

            const SizedBox(height: 6),

            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),

            /// ✅ Merge count
            if (slot.isMerge && mergeCount.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                mergeCount,
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],

            /// ✅ DETAILS SECTION
            if (showDetails && canShowDist) ...[
              const SizedBox(height: 8),

              /// ✅ MERGE SLOT: always show participants + total
              if (slot.isMerge) ...[
                ...(() {
                  final list = participants.where((x) {
                    final dn =
                        (x["distributorName"] ?? "").toString().trim();
                    return dn.isNotEmpty;
                  }).toList();

                  if (list.isEmpty) {
                    return [
                      const Text(
                        "-",
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                        ),
                      )
                    ];
                  }

                  return list.take(2).map((p) {
                    final dn =
                        (p["distributorName"] ?? "-").toString().trim();
                    final amt = p["amount"];
                    final amtNum =
                        (amt is num) ? amt : num.tryParse("$amt") ?? 0;

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 3),
                      child: Text(
                        "$dn | ₹${amtNum.toStringAsFixed(0)}",
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    );
                  }).toList();
                })(),
                const SizedBox(height: 2),
                Text(
                  "Total: ${_amountText()}",
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ]

              /// ✅ FULL SLOT: show distributor + amount
              else ...[
                Text(
                  _fullDistributorName().isEmpty ? "-" : _fullDistributorName(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _amountText(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }
}
