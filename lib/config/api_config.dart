class ApiConfig {
  /// 🔵 Base backend URL
  static const String baseUrl = "https://tickin-backend-8y4m.onrender.com";

  /// 🔐 Auth
  static const String auth = "/api/auth";

  /// 📦 Core modules (mounted directly)
  static const String orders = "/orders";
  static const String timeline = "/api/timeline";
  static const String products = "/products";
  static const String trips = "/trips";

  // ✅ NEW - only for manager flow routes
  static const String ordersApi = "/api/orders";
  static const String ordersRoot = "";

  /// ⚙️ API-prefixed modules
  static const String slots = "/api/slots";
  static const String driver = "/api/driver";
  static const String sales = "/api/sales";
  static const String distributors = "/api/distributors";
  static const String users = "/api/users";
  static const String vehicles = "/api/vehicles";

  // ✅ ATTENDANCE
  static const String attendance = "/api/attendance";
}
