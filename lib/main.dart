import 'package:flutter/material.dart';

import 'app_scope.dart';
import 'theme/app_theme.dart';
import 'screens/login_screen.dart';

void main() {
  runApp(const Root());
}

class Root extends StatelessWidget {
  const Root({super.key});

  @override
  Widget build(BuildContext context) {
    // ✅ For now: no Provider() dependency here.
    // We'll re-add AuthProvider after we check its constructor.
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
      home: const LoginScreen(),
    );
  }
}
