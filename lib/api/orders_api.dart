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
  }) {
    return client.post(
      "$_b/create",
      body: {
        "distributorId": distributorId,
        "distributorName": distributorName,
        "items": items,
      },
    );
  }

  Future<Map<String, dynamic>> confirmDraft(String orderId) {
    return client.post("$_b/confirm-draft/$orderId");
  }

  Future<Map<String, dynamic>> confirmOrder({
    required String orderId,
    required String companyCode,
    Map<String, dynamic>? slot,
  }) {
    return client.post(
      "$_b/confirm/$orderId",
      body: {"companyCode": companyCode, if (slot != null) "slot": slot},
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

  Future<Map<String, dynamic>> all({String? status}) {
    return client.get(
      "$_b/all",
      query: status == null ? null : {"status": status},
    );
  }

  Future<Map<String, dynamic>> cancelSlotBooking({required String orderId}) {
    return client.post(
      "${ApiConfig.orders}/cancel-slot",
      body: {"orderId": orderId},
    );
  }

  Future<Map<String, dynamic>> my() {
    return client.get("$_b/my");
  }

  Future<Map<String, dynamic>> placePendingThenConfirmDraftIfAny({
    required String distributorId,
    required String distributorName,
    required List<Map<String, dynamic>> items,
    String? companyCode,
  }) async {
    // ✅ Debug: input snapshot
    print("🧾 placePendingThenConfirmDraftIfAny()");
    print("🧾 distributorId=$distributorId");
    print("🧾 distributorName=$distributorName");
    print("🧾 itemsCount=${items.length}");
    print("🧾 companyCode=${companyCode ?? "NULL"}");
    try {
      print("🟦 STEP 1: createOrder() start");

      final created = await createOrder(
        distributorId: distributorId,
        distributorName: distributorName,
        items: items,
      );

      print("🟦 STEP 1: createOrder() response => $created");

      if (created["ok"] == false) {
        print(
          "🟥 STEP 1: createOrder() ok=false message=${created["message"]}",
        );
        throw ApiException(created["message"] ?? "Create order failed");
      }

      final orderId = (created["orderId"] ?? "").toString();
      final status = (created["status"] ?? "").toString().toUpperCase();

      print("🧾 parsed orderId=$orderId status=$status");

      if (orderId.isEmpty) {
        print("🟥 orderId missing in createOrder response");
        throw ApiException("orderId missing");
      }

      if (status == "DRAFT") {
        print("🟨 STEP 2: confirmDraft($orderId) start");

        final confirmed = await confirmDraft(orderId);

        print("🟨 STEP 2: confirmDraft() response => $confirmed");

        if (confirmed["ok"] == false) {
          print(
            "🟥 STEP 2: confirmDraft() ok=false message=${confirmed["message"]}",
          );
          throw ApiException(confirmed["message"] ?? "Confirm draft failed");
        }

        print("✅ STEP 2: confirmDraft success -> returning CONFIRMED");
        return {...created, "status": "CONFIRMED"};
      }

      if (status == "PENDING") {
        print("🟧 STEP 2: status=PENDING -> confirmOrder path");

        if (companyCode == null || companyCode.isEmpty) {
          print("🟥 companyCode missing for confirmOrder");
          throw ApiException("companyCode missing");
        }

        print(
          "🟧 STEP 3: confirmOrder(orderId=$orderId, companyCode=$companyCode) start",
        );

        final confirmed = await confirmOrder(
          orderId: orderId,
          companyCode: companyCode,
        );

        print("🟧 STEP 3: confirmOrder() response => $confirmed");

        if (confirmed["ok"] == false) {
          print("🟥 STEP 3: confirmOrder() ok=false");
          throw ApiException("Confirm failed");
        }

        print("✅ STEP 3: confirmOrder success -> returning CONFIRMED");
        return {...created, "status": "CONFIRMED"};
      }

      print("ℹ️ status neither DRAFT nor PENDING -> returning created as-is");
      return created;
    } catch (e) {
      // ✅ Debug: identify which step throws (Access denied will come here)
      print("❌ placePendingThenConfirmDraftIfAny ERROR => $e");
      rethrow;
    }
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
