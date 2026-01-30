import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'dart:convert';

class TokenStore {
  static const _kToken = "token";
  static const _kUser = "user_json";

  final FlutterSecureStorage _storage =
      const FlutterSecureStorage();

  // ✅ SAVE TOKEN
  Future<void> saveToken(String token) async {
    await _storage.write(key: _kToken, value: token);
  }

  // ✅ GET TOKEN
  Future<String?> getToken() async {
    return _storage.read(key: _kToken);
  }

  // ✅ SAVE USER JSON
  Future<void> saveUserJson(String json) async {
    await _storage.write(key: _kUser, value: json);
  }

  // ✅ GET USER JSON
  Future<String?> getUserJson() async {
    return _storage.read(key: _kUser);
  }

  // ✅ DRIVER ID (FINAL & CORRECT)
  Future<String?> get userId async {
  final jsonStr = await getUserJson();
  if (jsonStr == null || jsonStr.isEmpty) return null;

  final map = jsonDecode(jsonStr);
  return (map["id"] ?? map["phone"] ?? "").toString();
}
  // ✅ CLEAR ALL
  Future<void> clear() async {
    await _storage.deleteAll();
  }
}
