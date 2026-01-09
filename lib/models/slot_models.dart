// ignore_for_file: curly_braces_in_flow_control_structures

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

  static String normalizeTime(String t) {
    final x = t.trim();
    if (!x.contains(":")) return x;

    final parts = x.split(":");
    final hh = parts[0].padLeft(2, "0");
    final mm = (parts.length > 1 ? parts[1] : "00").padLeft(2, "0");
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

    if ((parsedTime.isEmpty || parsedTime == "00:00") && sk.startsWith("MERGE_SLOT#")) {
      try {
        final parts = sk.split("#");
        if (parts.length > 1) parsedTime = normalizeTime(parts[1]);
      } catch (_) {}
    }

    final rawStatus = (m["status"] ?? "AVAILABLE").toString();

    // ✅ participants list safe parse
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

    return SlotItem(
      pk: pk,
      sk: sk,
      time: parsedTime,
      vehicleType: (m["vehicleType"] ?? "FULL").toString(),
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

  String get sessionLabel {
    final t = time.trim();
    if (t == "09:00") return "Morning";
    if (t == "12:30") return "Afternoon";
    if (t == "16:00") return "Evening";
    if (t == "20:00") return "Night";
    return "Morning";
  }

  int get slotIdNum {
    final t = time.trim();
    int base = 3001;

    if (t == "09:00") base = 3001;
    else if (t == "12:30") base = 3005;
    else if (t == "16:00") base = 3009;
    else if (t == "20:00") base = 3013;

    final p = (pos ?? "A").toUpperCase();
    int offset = 0;

    if (p == "A") offset = 0;
    if (p == "B") offset = 1;
    if (p == "C") offset = 2;
    if (p == "D") offset = 3;

    return base + offset;
  }

  String get slotIdLabel => slotIdNum.toString();
}
