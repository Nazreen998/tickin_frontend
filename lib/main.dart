import 'dart:convert';
import 'package:flutter/material.dart';

import 'app_scope.dart';
import 'theme/app_theme.dart';
import 'screens/login_screen.dart';
import 'screens/manager_dashboard_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const Root());
}

class Root extends StatelessWidget {
  const Root({super.key});

  @override
  Widget build(BuildContext context) {
    return TickinAppScope(
      child: const TickinApp(),
    );
  }
}

class TickinApp extends StatelessWidget {
  const TickinApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark,
      home: const AuthGate(),
    );
  }
}

/// ✅ Reads saved token + userJson, routes without logout (WhatsApp style)
class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  Future<Widget>? _future;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _future ??= _decideHome();
  }

  Future<Widget> _decideHome() async {
    final scope = TickinAppScope.of(context);

    final token = await scope.tokenStore.getToken();
    if (token == null || token.trim().isEmpty) {
      return const LoginScreen();
    }

    final userJson = await scope.tokenStore.getUserJson();
    if (userJson == null || userJson.trim().isEmpty) {
      // token இருந்தாலும் userJson இல்லனா safe-aa login
      return const LoginScreen();
    }

    try {
      final userMap = jsonDecode(userJson) as Map<String, dynamic>;
      final role = (userMap["role"] ?? "").toString().toUpperCase();
      final userRole = mapRole(role); // ✅ from login_screen.dart

      return ManagerDashboardScreen(role: userRole);
    } catch (_) {
      return const LoginScreen();
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Widget>(
      future: _future,
      builder: (context, snap) {
        if (!snap.hasData) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        return snap.data!;
      },
    );
  }
}
