// ignore_for_file: avoid_print

import 'dart:convert';
import 'package:http/http.dart' as http;
import '../storage/token_store.dart';
import '../config/api_config.dart';

class ApiException implements Exception {
  final String message;
  ApiException(this.message);
  @override
  String toString() => message;
}

class HttpClient {
  final TokenStore tokenStore;
  HttpClient(this.tokenStore);

  Uri _uri(String path, [Map<String, dynamic>? query]) {
    final u = Uri.parse(
      "${ApiConfig.baseUrl}$path",
    ).replace(queryParameters: query);
    print("🌐 HTTP => $u");
    return u;
  }

  Map<String, dynamic> _decodeJwt(String token) {
    try {
      final parts = token.split('.');
      if (parts.length != 3) return {};
      final payload = base64Url.normalize(parts[1]);
      final decoded = utf8.decode(base64Url.decode(payload));
      final map = jsonDecode(decoded);
      return map is Map<String, dynamic> ? map : {};
    } catch (_) {
      return {};
    }
  }

  Future<Map<String, String>> _headers() async {
    final token = await tokenStore.getToken();
    print("🔐 TOKEN => ${token == null ? "NULL" : token.substring(0, 25)}");

    final headers = <String, String>{"Content-Type": "application/json"};

    if (token != null && token.isNotEmpty) {
      final p = _decodeJwt(token);
      print("🪪 JWT role => ${p["role"]}");
      print("🪪 JWT mobile => ${p["mobile"]}");
      print("🪪 JWT distributorCode => ${p["distributorCode"]}");
      print("🪪 JWT allowedDistributors => ${p["allowedDistributors"]}");
      print("🪪 JWT companyId => ${p["companyId"]}");

      headers["Authorization"] = "Bearer $token";
    }

    return headers;
  }

  Future<Map<String, dynamic>> get(
    String path, {
    Map<String, dynamic>? query,
  }) async {
    final res = await http.get(_uri(path, query), headers: await _headers());
    return _handle(res);
  }

  Future<Map<String, dynamic>> post(
    String path, {
    Map<String, dynamic>? body,
  }) async {
    final h = await _headers();
    final u = _uri(path);

    print("➡️ POST $u");
    print("➡️ Headers hasAuth=${h.containsKey("Authorization")}");
    print("➡️ Body => ${jsonEncode(body ?? {})}");

    final res = await http.post(u, headers: h, body: jsonEncode(body ?? {}));
    return _handle(res);
  }

  Future<Map<String, dynamic>> patch(
    String path, {
    Map<String, dynamic>? body,
  }) async {
    final res = await http.patch(
      _uri(path),
      headers: await _headers(),
      body: jsonEncode(body ?? {}),
    );
    return _handle(res);
  }

  Future<Map<String, dynamic>> delete(String path) async {
    final res = await http.delete(_uri(path), headers: await _headers());
    return _handle(res);
  }

  Map<String, dynamic> _handle(http.Response res) {
    final body = res.body.isNotEmpty ? jsonDecode(res.body) : {};

    if (res.statusCode >= 200 && res.statusCode < 300) {
      return body is Map<String, dynamic> ? body : {"data": body};
    }

    print("❌ HTTP ERROR ${res.statusCode} => ${res.request?.url}");
    print("❌ BODY => ${res.body}");

    final msg = (body is Map)
        ? (body["message"] ?? body["error"] ?? "Request failed")
        : "Request failed";

    throw ApiException(msg.toString());
  }
}
