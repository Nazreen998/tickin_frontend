// ignore_for_file: avoid_print
import '../api/http_client.dart' as api;

class OrdersFlowApi {
  final api.HttpClient client;
  OrdersFlowApi(this.client);

  static const String _b = "/api/orders";

  Future<Map<String, dynamic>> slotConfirmedOrders({required String date}) {
    return client.get("$_b/slot-confirmed", query: {"date": date});
  }

  Future<Map<String, dynamic>> getOrderFlowByKey(String flowKey) {
  print("🔥 FLOW API CALLED WITH => $flowKey");
  return client.get("$_b/flow/$flowKey");
}


  /// ✅ Vehicle Selected — TRY FLOWKEY, if route conflict then fallback ORDERID
  Future<Map<String, dynamic>> vehicleSelectedSmart({
  required String flowKey,
  required String orderId,
  required String vehicleNo,
}) async {
  try {
    return await client.post(
      "$_b/vehicle-selected/$flowKey",
      body: {"vehicleNo": vehicleNo, "vehicleType": vehicleNo},
    );
  } catch (e) {
    return await client.post(
      "$_b/vehicle-selected/$orderId",
      body: {"vehicleNo": vehicleNo, "vehicleType": vehicleNo},
    );
  }
}
  /// ✅ Loading Start
  Future<Map<String, dynamic>> loadingStart(String flowKey) async {
  return client.post(
    "/api/orders/loading-start",body:{"flowKey": flowKey});
}

  /// ✅ Loading End
 Future<Map<String, dynamic>> loadingEnd(String flowKey) async {
  return client.post(
    "/api/orders/loading-end",   // 🔥 FIXED
    body: {"flowKey": flowKey},
  );
}

  /// ✅ Assign Driver
  Future<Map<String, dynamic>> assignDriver({
    required String flowKey,
    required String driverId,
    String? vehicleNo,
  }) {
    return client.post("$_b/assign-driver", body: {
      "flowKey": flowKey,
      "driverId": driverId,
      if (vehicleNo != null) "vehicleNo": vehicleNo,
    });
  }
}
