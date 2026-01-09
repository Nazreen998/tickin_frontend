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
    print("🔥 OrdersFlowApi.getOrderFlowByKey => $flowKey");
    return client.get("$_b/flow/$flowKey");
  }

  Future<Map<String, dynamic>> vehicleSelected(String flowKey, String vehicleType) {
    return client.post("$_b/vehicle-selected/$flowKey", body: {
      "vehicleType": vehicleType,
    });
  }

  Future<Map<String, dynamic>> loadingStart(String flowKey) {
    return client.post("$_b/loading-start", body: {"flowKey": flowKey});
  }

  Future<Map<String, dynamic>> loadingEnd(String flowKey) {
    return client.post("$_b/loading-end", body: {"flowKey": flowKey});
  }

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
