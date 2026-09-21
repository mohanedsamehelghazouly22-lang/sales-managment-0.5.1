import 'package:flutter/material.dart';
import 'config/app_config.dart';
import 'services/supabase_service.dart';
import 'theme/app_theme.dart';
import 'widgets/aurora_background.dart';
import 'screens/app_shell.dart';
import 'screens/login.dart';
import 'screens/business_gate.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SupabaseService.initialize();
  runApp(const SalesManagerApp());
}

class SalesManagerApp extends StatelessWidget {
  const SalesManagerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Sales Manager',
      theme: AppTheme.dark(),
      // الخلفية المتدرجة بتتحط مرة واحدة هنا وبتفضل خلف كل شاشة في التطبيق.
      builder: (context, child) => AuroraBackground(child: child ?? const SizedBox.shrink()),
      home: const AuthGate(),
    );
  }
}

/// البوابة الوحيدة للتطبيق: دخول ← اختيار النشاط ← الشاشة الرئيسية.
/// بتفضل موجودة طول الوقت، فأول ما الجلسة تنتهي (تسجيل خروج) بترجع
/// لشاشة الدخول تلقائيًا.
class AuthGate extends StatefulWidget {
  const AuthGate({super.key});
  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  String? _businessId;

  @override
  Widget build(BuildContext context) {
    final client = SupabaseService.client!;
    return StreamBuilder(
      stream: client.auth.onAuthStateChange,
      builder: (context, snapshot) {
        if (client.auth.currentSession == null) {
          _businessId = null;
          return const LoginPage();
        }
        final id = _businessId;
        if (id == null) {
          return BusinessGate(onOpen: (v) => setState(() => _businessId = v));
        }
        return AppShell(key: ValueKey(id), businessId: id);
      },
    );
  }
}
