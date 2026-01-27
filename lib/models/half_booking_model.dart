class HalfBooking {
  final String orderId;
  final String agencyName;
  final double amount;
  final String time;
  final String mergeKey;

  HalfBooking({
    required this.orderId,
    required this.agencyName,
    required this.amount,
    required this.time,
    required this.mergeKey,
  });

  factory HalfBooking.fromJson(Map<String, dynamic> json) {
    return HalfBooking(
      orderId: json['orderId'],
      agencyName: json['agencyName'] ?? '',
      amount: (json['amount'] ?? 0).toDouble(),
      time: json['slotTime'],
      mergeKey: json['mergeKey'],
    );
  }
}
