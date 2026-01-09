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
    final u = Uri.parse("${ApiConfig.baseUrl}$path")
        .replace(queryParameters: query);
    print("🌐 HTTP => $u");
    return u;
  }

  Future<Map<String, String>> _headers() async {
    final token = await tokenStore.getToken();
    print("🔐 TOKEN => ${token == null ? "NULL" : token.substring(0, 25)}");

    final headers = <String, String>{
      "Content-Type": "application/json",
    };

    if (token != null && token.isNotEmpty) {
      headers["Authorization"] = "Bearer $token";
    }

    return headers;
  }

  Future<Map<String, dynamic>> get(String path, {Map<String, dynamic>? query}) async {
    final res = await http.get(_uri(path, query), headers: await _headers());
    return _handle(res);
  }

  Future<Map<String, dynamic>> post(String path, {Map<String, dynamic>? body}) async {
    final res = await http.post(
      _uri(path),
      headers: await _headers(),
      body: jsonEncode(body ?? {}),
    );
    return _handle(res);
  }

  Future<Map<String, dynamic>> patch(String path, {Map<String, dynamic>? body}) async {
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
