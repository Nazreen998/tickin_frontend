// ignore_for_file: avoid_print
import 'dart:convert';
import '../storage/token_store.dart';

class AuthProvider {
  final TokenStore tokenStore;

  AuthProvider(this.tokenStore);

  // ✅ DRIVER ID (this is what we need)
  Future<String?> get userId => tokenStore.userId;

  // ✅ LOGIN SESSION SAVE
  Future<void> setSession({
    required String token,
    required Map<String, dynamic> userMap,
  }) async {
    // SAVE TOKEN
    await tokenStore.saveToken(token);

    // SAVE USER JSON
    await tokenStore.saveUserJson(jsonEncode(userMap));

    // DEBUG
    final check = await tokenStore.getToken();
    print(
      "✅ TOKEN SAVED CHECK => ${check == null ? "NULL" : check.substring(0, 25)}",
    );
  }

  // ✅ LOGOUT
  Future<void> logout() async {
    await tokenStore.clear();
  }
}
