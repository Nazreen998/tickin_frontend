// ignore_for_file: avoid_print
import '../api/http_client.dart';

class UsersApi {
  final HttpClient client;
  UsersApi(this.client);

  /// ✅ Get drivers list
  /// Backend working route: GET /drivers  (not /api/users/drivers)
  Future<Map<String, dynamic>> getDrivers() async {
    Exception? lastErr;

    // ✅ Try these endpoints in order (NO backend change needed)
    final tryPaths = <String>[
      "/drivers",                // ✅ WORKING (from backend endpoints list)
      "/api/drivers",            // fallback
      "/api/driver/drivers",     // fallback
      "/api/users/drivers",      // broken currently (QueryCommand bug)
    ];

    for (final p in tryPaths) {
      try {
        final res = await client.get(p);

        // ✅ normalize output
        if (res["drivers"] != null && res["drivers"] is List) return res;

        if (res["data"] != null && res["data"] is List) {
          return {"drivers": res["data"]};
        }

        if (res is Map<String, dynamic> && res.values.any((v) => v is List)) {
          // sometimes backend returns { users:[...] }
          final firstList = res.values.firstWhere((v) => v is List, orElse: () => []);
          return {"drivers": firstList};
        }

        return res;
      } catch (e) {
        lastErr = Exception("❌ $p => $e");
        print(lastErr);
      }
    }

    throw lastErr ?? Exception("No driver routes working");
  }

  /// alias if old code uses drivers()
  Future<Map<String, dynamic>> drivers() => getDrivers();
}
