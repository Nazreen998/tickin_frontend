import '../api/http_client.dart';
import '../config/api_config.dart';

class SlotsApi {
  final HttpClient client;
  SlotsApi(this.client);

  Future<Map<String, dynamic>> getGrid({
    required String companyCode,
    required String date,
  }) {
    return client.get(ApiConfig.slots, query: {
      "companyCode": companyCode,
      "date": date,
    });
  }

  Future<Map<String, dynamic>> book({
    required String companyCode,
    required String date,
    required String time,
    String? pos,
    required String distributorCode,
    required double amount,
    required String orderId,
    String? userId,
    double? lat,
    double? lng,
    String? distributorName,
    String? locationId,
  }) {
    // ✅ FORCE string trim (avoid null/empty confusion)
    String loc = (locationId ?? "").toString().trim();
loc = loc.replaceAll(RegExp(r'^(LOC#)+', caseSensitive: false), '');


    return client.post("${ApiConfig.slots}/book", body: {
      "companyCode": companyCode,
      "date": date,
      "time": time,
      if (pos != null) "pos": pos,
      "distributorCode": distributorCode,
      if (distributorName != null) "distributorName": distributorName,
      "amount": amount,
      "orderId": orderId,
      if (userId != null) "userId": userId,
      if (lat != null) "lat": lat,
      if (lng != null) "lng": lng,

      // ✅ IMPORTANT: send only when not empty
      if (loc.isNotEmpty) "locationId": loc,
    });
  }

  Future<Map<String, dynamic>> managerCancelBooking(Map<String, dynamic> body) =>
      client.post("${ApiConfig.slots}/manager/cancel-booking", body: body);

  Future<Map<String, dynamic>> managerDisableSlot(Map<String, dynamic> body) =>
      client.post("${ApiConfig.slots}/disable-slot", body: body);

  Future<Map<String, dynamic>> managerEnableSlot(Map<String, dynamic> body) =>
      client.post("${ApiConfig.slots}/enable-slot", body: body);

  Future<Map<String, dynamic>> managerConfirmMerge(Map<String, dynamic> body) =>
      client.post("${ApiConfig.slots}/merge/confirm", body: body);

  Future<Map<String, dynamic>> managerMoveMerge(Map<String, dynamic> body) =>
      client.post("${ApiConfig.slots}/merge/move", body: body);

Future<Map<String, dynamic>> managerConfirmDayMerge(
  Map<String, dynamic> body,
) =>
    client.post("${ApiConfig.slots}/merge/confirm-day", body: body);

  Future<Map<String, dynamic>> managerEditTime(Map<String, dynamic> body) =>
      client.post("${ApiConfig.slots}/edit-time", body: body);

  Future<Map<String, dynamic>> managerSetSlotMax(Map<String, dynamic> body) =>
      client.post("${ApiConfig.slots}/set-max", body: body);

  Future<Map<String, dynamic>> managerSetGlobalMax(Map<String, dynamic> body) =>
      client.post("${ApiConfig.slots}/set-global-max", body: body);

  Future<Map<String, dynamic>> toggleLastSlot(Map<String, dynamic> body) =>
      client.post("${ApiConfig.slots}/last-slot/toggle", body: body);

  /// ✅ FIX: correct manual merge endpoint (remove /manual)
  /// Backend usually expects: POST /api/slots/merge/orders
  Future<Map<String, dynamic>> managerMergeOrdersManual(Map<String, dynamic> body) =>
    client.post("${ApiConfig.slots}/merge/orders/manual", body: body);

  Future<Map<String, dynamic>> cancelConfirmedMerge(Map<String, dynamic> body) =>
      client.post("${ApiConfig.slots}/merge/cancel-confirmed", body: body);

  Future<Map<String, dynamic>> waitingHalfByDate({
  required String date,
}) {
  return client.get("${ApiConfig.slots}/waiting-half-by-date", query: {
    "date": date,
  });
}
      
Future<Map<String, dynamic>> availableFullTimes({required String date}) {
  return client.get("${ApiConfig.slots}/available-full-times", query: {
    "date": date,
  });
}

Future<Map<String, dynamic>> managerManualMergePickTime(Map<String, dynamic> body) {
  return client.post("${ApiConfig.slots}/merge/manual-pick-time", body: body);
}

    
}
