import '../api/http_client.dart';
import '../config/api_config.dart';

class OrdersApi {
  final HttpClient client;
  OrdersApi(this.client);

  static const String _b = "/api/orders";

  Future<Map<String, dynamic>> createOrder({
    required String distributorId,
    required String distributorName,
    required List<Map<String, dynamic>> items,
    String? companyCode, // ✅ ADD THIS
  }) async {
    return client.post(
      "$_b/create",
      body: {
        "distributorId": distributorId,
        "distributorName": distributorName,
        "items": items,
        if (companyCode != null) "companyCode": companyCode,
      },
    );
  }

  Future<Map<String, dynamic>> confirmDraft(String orderId) {
    return client.post("$_b/confirm-draft/$orderId");
  }

  Future<Map<String, dynamic>> confirmOrder({
    required String orderId,
    required String companyCode,
  }) async {
    return client.post(
      "$_b/confirm/$orderId",
      body: {
        "companyCode": companyCode, // ✅ THIS IS ENOUGH
      },
    );
  }

  Future<Map<String, dynamic>> updateItems({
    required String orderId,
    required List<Map<String, dynamic>> items,
  }) {
    return client.patch("$_b/update/$orderId", body: {"items": items});
  }

  /// ✅ DELETE order
  Future<Map<String, dynamic>> deleteOrder(String orderId) {
    return client.delete("$_b/$orderId");
  }

  Future<Map<String, dynamic>> getOrderById(String orderId) {
    return client.get("$_b/$orderId");
  }

  Future<Map<String, dynamic>> pending() {
    return client.get("$_b/pending");
  }

  Future<Map<String, dynamic>> today() {
    return client.get("$_b/today");
  }

  Future<Map<String, dynamic>> delivery() {
    return client.get("$_b/delivery");
  }

  Future<Map<String, dynamic>> all({
    String? status,
    String? date, // yyyy-MM-dd
  }) {
    return client.get(
      "$_b/all",
      query: {
        if (status != null && status.isNotEmpty) "status": status,
        if (date != null && date.isNotEmpty) "date": date,
      },
    );
  }

  Future<Map<String, dynamic>> cancelSlotBooking({required String orderId}) {
    return client.post(
      "${ApiConfig.orders}/cancel-slot",
      body: {"orderId": orderId},
    );
  }

  Future<Map<String, dynamic>> my({
    String? status,
    String? date, // yyyy-MM-dd
  }) {
    return client.get(
      "$_b/my",
      query: {
        if (status != null && status.isNotEmpty) "status": status,
        if (date != null && date.isNotEmpty) "date": date,
      },
    );
  }

  Future<Map<String, dynamic>> placePendingThenConfirmDraftIfAny({
    required String distributorId,
    required String distributorName,
    required List<Map<String, dynamic>> items,
    String? companyCode,
  }) async {
    final created = await createOrder(
      distributorId: distributorId,
      distributorName: distributorName,
      items: items,
      companyCode: companyCode,
    );

    // ✅ treat missing ok as success
    if (created.containsKey("ok") && created["ok"] == false) {
      throw ApiException(created["message"] ?? "Create order failed");
    }

    final orderId = (created["orderId"] ?? "").toString();
    final status = (created["status"] ?? "").toString().toUpperCase();

    if (orderId.isEmpty) {
      throw ApiException("orderId missing");
    }

    // ✅ ONLY call confirm APIs when needed
    if (status == "DRAFT") {
      final confirmed = await confirmDraft(orderId);

      if (confirmed.containsKey("ok") && confirmed["ok"] == false) {
        throw ApiException(confirmed["message"] ?? "Confirm draft failed");
      }

      return {...created, "status": "CONFIRMED"};
    }

    if (status == "PENDING") {
      // 🔥 companyCode illatti CONFIRM call skip pannu
      if (companyCode == null || companyCode.isEmpty) {
        // Order is valid, just not auto-confirmed
        return created; // ✅ NO ERROR
      }

      final confirmed = await confirmOrder(
        orderId: orderId,
        companyCode: companyCode,
      );

      if (confirmed.containsKey("ok") && confirmed["ok"] == false) {
        throw ApiException(confirmed["message"] ?? "Confirm failed");
      }

      return {...created, "status": "CONFIRMED"};
    }
    // ✅ CONFIRMED already → just return
    return created;
  }

  /// 🚚 Driver - Assigned orders
  Future<Map<String, dynamic>> getDriverAssignedOrders() {
    return client.get("$_b/driver/assigned");
  }

  // ✅ Update Pending Reason (Manager only)
  Future<Map<String, dynamic>> updatePendingReason({
    required String orderId,
    required String reason,
  }) {
    return client.patch("$_b/$orderId/reason", body: {"reason": reason});
  }
}
