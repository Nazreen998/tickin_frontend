import '../api/http_client.dart';
import '../config/api_config.dart';

class DriverApi {
  final HttpClient client;
  DriverApi(this.client);

  String _cleanDriverId(String id) {
    return id.replaceAll("USER#", "");
  }

  /// 🚚 Driver active orders (card list)
  String normalizeDriverId(String id) {
  if (id.startsWith("USER#")) return id;
  return "USER#$id";
}

Future<List<Map<String, dynamic>>> getDriverOrders(String driverId) async {
  if (driverId.isEmpty) {
    throw Exception("DriverId is empty");
  }

  final id = driverId.startsWith("USER#")
      ? driverId
      : "USER#$driverId";

  final res = await client.get("${ApiConfig.driver}/$id/orders");

  final List list = (res["orders"] is List) ? res["orders"] : [];
  return list.map((e) => Map<String, dynamic>.from(e)).toList();
}

  /// 🔁 Update driver order status
  Future<Map<String, dynamic>> updateStatus({
    required String orderId,
    required String nextStatus,
    double? lat,
    double? lng,
    bool force = false,
  }) {
    return client.post(
      "${ApiConfig.driver}/order/$orderId/status",
      body: {
        "nextStatus": nextStatus,
        if (lat != null) "currentLat": lat,
        if (lng != null) "currentLng": lng,
        "force": force,
      },
    );
  }

  Future<Map<String, dynamic>> deleteOrder({
    required String orderId,
    required String driverId,
  }) {
    return client.post(
      "${ApiConfig.driver}/order/$orderId/delete",
      body: {
        "driverId": _cleanDriverId(driverId),
      },
    );
  }

  /// 📍 Optional: validate reach
  Future<Map<String, dynamic>> validateReach({
    required String orderId,
    required double lat,
    required double lng,
  }) {
    return client.post(
      "${ApiConfig.driver}/order/$orderId/validate-reach",
      body: {"currentLat": lat, "currentLng": lng},
    );
  }
}
