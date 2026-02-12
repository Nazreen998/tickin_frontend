import 'dart:convert';
import 'package:http/http.dart' as http;

class Api {
  static const String baseUrl = "https://tickin-backend.onrender.com";

  // ✅ Common POST JSON helper
  static Future<Map<String, dynamic>> postJson(
    String path,
    Map<String, dynamic> body,
  ) async {
    final url = Uri.parse("$baseUrl$path");

    final res = await http.post(
      url,
      headers: {"Content-Type": "application/json"},
      body: jsonEncode(body),
    );

    final decoded = jsonDecode(res.body) as Map<String, dynamic>;

    if (res.statusCode == 200) return decoded;
    throw Exception(decoded["message"] ?? "Error");
  }

  static Future<Map<String, dynamic>> getProducts() async {
    final url = Uri.parse("$baseUrl/api/products");
    final res = await http.get(url);

    final body = jsonDecode(res.body) as Map<String, dynamic>;
    if (res.statusCode == 200) return body;

    throw Exception(body["message"] ?? "Error");
  }

  static Future<Map<String, dynamic>> getQrItem(String qrName) async {
    final url = Uri.parse("$baseUrl/qr/$qrName");
    final res = await http.get(url);

    final body = jsonDecode(res.body) as Map<String, dynamic>;
    if (res.statusCode == 200) return body;

    throw Exception(body["message"] ?? "Error");
  }

  static Future<Map<String, dynamic>> takeStock({
    required String qrName,
    required int takenQty,
    required String user,
  }) async {
    return await postJson("/qr/take", {
      "qrName": qrName,
      "takenQty": takenQty,
      "user": user,
    });
  }

  static Future<Map<String, dynamic>> addNewBatch({
    required String qrName,
    required int totalQty,
    required String itemName,
    required int ml,
    required String mfgDate,
    required String expiryDate,
    required String user,
  }) async {
    return await postJson("/qr/add", {
      "qrName": qrName,
      "totalQty": totalQty,
      "itemName": itemName,
      "ml": ml,
      "mfgDate": mfgDate,
      "expiryDate": expiryDate,
      "user": user,
    });
  }

  static Future<Map<String, dynamic>> getQrHistory() async {
    final url = Uri.parse("$baseUrl/qr/history/list");
    final res = await http.get(url);

    final body = jsonDecode(res.body) as Map<String, dynamic>;
    if (res.statusCode == 200) return body;

    throw Exception(body["message"] ?? "Error");
  }
}
