// ignore_for_file: unused_import, unused_local_variable, dead_code

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:book_yours/screens/driver_dashboard_screen.dart';
import '../app_scope.dart';
import 'manager_dashboard_screen.dart';
import 'slots/slot_booking_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _userCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  bool _showPwd = false;
  bool _loading = false;

  Future<void> _doLogin() async {
    final mobile = _userCtrl.text.trim();
    final password = _passCtrl.text;

    if (mobile.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Enter username & password")),
      );
      return;
    }

    setState(() => _loading = true);

    try {
      final scope = TickinAppScope.of(context);

      // ✅ IMPORTANT: Change this to your real endpoint if different
      final res = await scope.httpClient.post(
        "/api/auth/login",
        body: {"mobile": mobile, "password": password},
      );

      final token = (res["token"] ?? res["accessToken"] ?? "").toString();
      final userMapRaw = (res["user"] ?? res["profile"] ?? res["data"] ?? res);

      if (token.isEmpty) throw Exception("Token missing in login response");
      if (userMapRaw is! Map) throw Exception("User object missing in response");

      final userMap = userMapRaw.cast<String, dynamic>();

      // ✅ SAVE TOKEN + USER JSON (THIS FIXES 'Token missing' in slot booking)
      await scope.authProvider.setSession(token: token, userMap: userMap);

      if (!mounted) return;

      final role = (userMap["role"] ?? "").toString().toUpperCase();
      final distCode =
          (userMap["distributorCode"] ?? userMap["distributorId"] ?? "D001")
              .toString();
      final distName =
          (userMap["distributorName"] ?? userMap["agencyName"] ?? "Distributor")
              .toString();
      final locId = (userMap["locationId"] ?? "LOC1").toString();

      if (role == "MANAGER" || role == "MASTER" || role == "SALES OFFICER") {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const ManagerDashboardScreen()),
        );
      } else {
      }
      if (role == "DRIVER" || role == "LOADMAN") {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const DriverDashboardScreen()),
        );
      } else {}
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text("❌ Login failed: $e")));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Login")),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.lock_outline, size: 48),
                  const SizedBox(height: 16),

                  TextField(
                    controller: _userCtrl,
                    decoration: const InputDecoration(
                      labelText: "Username",
                      prefixIcon: Icon(Icons.person),
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),

                  TextField(
                    controller: _passCtrl,
                    obscureText: !_showPwd,
                    decoration: InputDecoration(
                      labelText: "Password",
                      prefixIcon: const Icon(Icons.lock),
                      border: const OutlineInputBorder(),
                      suffixIcon: IconButton(
                        icon: Icon(_showPwd ? Icons.visibility : Icons.visibility_off),
                        onPressed: () => setState(() => _showPwd = !_showPwd),
                      ),
                    ),
                  ),

                  const SizedBox(height: 18),

                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _loading ? null : _doLogin,
                      child: _loading
                          ? const SizedBox(
                              height: 18,
                              width: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text("Login"),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
