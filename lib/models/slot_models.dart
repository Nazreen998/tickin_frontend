// ignore_for_file: curly_braces_in_flow_control_structures
import '../screens/slots/slot_generator.dart';

class SlotRules {
  final double maxAmount;
  final bool lastSlotEnabled;
  final String lastSlotOpenAfter;

  SlotRules({
    required this.maxAmount,
    required this.lastSlotEnabled,
    required this.lastSlotOpenAfter,
  });

  factory SlotRules.fromMap(Map<String, dynamic> m) {
    final raw = m["maxAmount"] ?? m["threshold"] ?? 80000;

    return SlotRules(
      maxAmount: (raw is num) ? raw.toDouble() : double.tryParse("$raw") ?? 80000,
      lastSlotEnabled: m["lastSlotEnabled"] == true,
      lastSlotOpenAfter: m["lastSlotOpenAfter"]?.toString() ?? "16:30",
    );
  }
}

class SlotItem {
  final String pk;
  final String sk;

  final String time;
  final String vehicleType; // FULL / HALF
  final String? pos;
  final String status;

  final String? orderId;

  final String? mergeKey;
  final double? totalAmount;
  final double? amount;
  final String? tripStatus;

  final double? lat;
  final double? lng;

  final bool blink;
  final String? userId;

  final String? distributorName;
  final String? distributorCode;
  final String? bookedBy;

  final String? locationId;
  final String? companyCode;
  final String? date;
  
  final List<Map<String, dynamic>> participants;
  final double? distanceKm;
  final int? bookingCount;

  SlotItem({
    required this.pk,
    required this.sk,
    required this.time,
    required this.vehicleType,
    required this.status,
    this.pos,
    this.locationId,
    this.orderId,
    this.amount,
    this.mergeKey,
    this.totalAmount,
    this.tripStatus,
    this.lat,
    this.lng,
    this.blink = false,
    this.userId,
    this.distributorName,
    this.distributorCode,
    this.bookedBy,
    this.companyCode,
    this.date,
    this.participants = const [],
    this.distanceKm,
    this.bookingCount,
  });
String get displayTime {
  if (isMerge) return "";
  return normalizeTime(time);
}

  /// ✅ FIX: normalizeTime MUST remove seconds too
  static String normalizeTime(String t) {
    final x = t.trim();
    if (!x.contains(":")) return x;

    final parts = x.split(":");
    final hh = parts[0].padLeft(2, "0");
    final mm = (parts.length > 1 ? parts[1] : "00").padLeft(2, "0");

    // ✅ ignore seconds if present (12:30:00 -> 12:30)
    return "$hh:$mm";
  }

  factory SlotItem.fromMap(Map<String, dynamic> m) {
    final pk = m["pk"]?.toString() ?? "";
    final sk = m["sk"]?.toString() ?? "";

    String? companyCode;
    String? date;

    try {
      final parts = pk.split("#");
      final cIdx = parts.indexOf("COMPANY");
      final dIdx = parts.indexOf("DATE");
      if (cIdx != -1 && cIdx + 1 < parts.length) companyCode = parts[cIdx + 1];
      if (dIdx != -1 && dIdx + 1 < parts.length) date = parts[dIdx + 1];
    } catch (_) {}

    final rawLat = m["lat"];
    final rawLng = m["lng"];

    final rawTime = (m["time"] ?? m["slotTime"] ?? m["slot_time"])?.toString() ?? "";
    var parsedTime = normalizeTime(rawTime);

    // ✅ MERGE SLOT time fallback
    if ((parsedTime.isEmpty || parsedTime == "00:00") && sk.startsWith("MERGE_SLOT#")) {
      try {
        final parts = sk.split("#");
        if (parts.length > 1) parsedTime = normalizeTime(parts[1]);
      } catch (_) {}
    }

    final rawStatus = (m["status"] ?? "AVAILABLE").toString();

    // ✅ participants safe parse
    final rawP = m["participants"];
    final participants = <Map<String, dynamic>>[];
    if (rawP is List) {
      for (final p in rawP) {
        if (p is Map) participants.add(Map<String, dynamic>.from(p));
      }
    }

    double? totalAmount;
    if (m["totalAmount"] is num) totalAmount = (m["totalAmount"] as num).toDouble();
    if (totalAmount == null && m["amount"] is num) totalAmount = (m["amount"] as num).toDouble();

    double? amount;
    if (m["amount"] is num) amount = (m["amount"] as num).toDouble();
    else amount = double.tryParse("${m["amount"]}");

    // ✅ FIX: vehicleType safe normalize
    final vt = (m["vehicleType"] ?? "FULL").toString().toUpperCase().trim();
    final finalVehicleType = (vt == "HALF") ? "HALF" : "FULL";

    return SlotItem(
      pk: pk,
      sk: sk,
      time: parsedTime,
      vehicleType: finalVehicleType,
      pos: m["pos"]?.toString(),
      status: rawStatus,
      orderId: m["orderId"]?.toString(),
      mergeKey: m["mergeKey"]?.toString(),
      totalAmount: totalAmount,
      amount: amount,
      tripStatus: m["tripStatus"]?.toString() ?? "PARTIAL",
      lat: (rawLat is num) ? rawLat.toDouble() : double.tryParse("$rawLat"),
      lng: (rawLng is num) ? rawLng.toDouble() : double.tryParse("$rawLng"),
      blink: m["blink"] == true,
      userId: m["userId"]?.toString(),
      distributorName: m["distributorName"]?.toString(),
      distributorCode: m["distributorCode"]?.toString(),
      bookedBy: m["bookedBy"]?.toString(),
      locationId: m["locationId"]?.toString(),
      companyCode: companyCode,
      date: date,
      participants: participants,
      distanceKm: (m["distanceKm"] is num)
          ? (m["distanceKm"] as num).toDouble()
          : double.tryParse("${m["distanceKm"]}"),
      bookingCount: (m["bookingCount"] is num)
          ? (m["bookingCount"] as num).toInt()
          : int.tryParse("${m["bookingCount"]}"),
    );
  }

  bool get isFull => vehicleType.toUpperCase() == "FULL";
  bool get isMerge => sk.startsWith("MERGE_SLOT#");

  String get normalizedStatus {
    final s = status.toUpperCase();
    if (s == "CONFIRMED") return "BOOKED";
    return s;
  }

  bool get isBooked => normalizedStatus == "BOOKED";
  bool get isAvailable => normalizedStatus == "AVAILABLE";

  /// ✅ FIX: sessionLabel now handles seconds and unexpected formats
String get sessionLabel {
  if (isMerge) return "";
  final t = normalizeTime(time);

  for (final e in sessionTimes.entries) {
    if (e.value.contains(t)) return e.key;
  }

  // fallback
  final h = int.tryParse(t.split(":")[0]) ?? 0;
  if (h >= 9 && h < 12) return "Morning";
  if (h >= 12 && h < 15) return "Afternoon";
  if (h >= 15 && h < 18) return "Evening";
  return "Night";
}

int get slotIdNum {
  // ONLY 4 slots per session → A B C D
  int base;

  switch (sessionLabel) {
    case "Morning":
      base = 3000;
      break;
    case "Afternoon":
      base = 3010;
      break;
    case "Evening":
      base = 3020;
      break;
    case "Night":
      base = 3030;
      break;
    default:
      base = 3000;
  }

  int posOffset = 0;
  final p = (pos ?? "A").toUpperCase();
  if (p == "B") posOffset = 1;
  else if (p == "C") posOffset = 2;
  else if (p == "D") posOffset = 3;

  return base + posOffset;
}
  String get slotIdLabel => slotIdNum.toString();
}
