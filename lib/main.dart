import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'core/services/api_service.dart';
import 'core/services/service_type_service.dart';
import 'features/auth/controllers/auth_controller.dart';
import 'core/theme/theme_controller.dart';
import 'shared/navigation/app_router.dart';

@pragma('vm:entry-point')
Future<void> _bgHandler(RemoteMessage message) async {}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  FirebaseMessaging.onBackgroundMessage(_bgHandler);
  await FirebaseMessaging.instance.requestPermission(
    alert: true, sound: true, badge: true,
  );
  ApiService.instance.init();
  ServiceTypeService.instance.load();
  runApp(const AutoSosProviderApp());
}

class AutoSosProviderApp extends StatelessWidget {
  const AutoSosProviderApp({super.key});

  @override
  Widget build(BuildContext context) => MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => AuthController()),
          ChangeNotifierProvider(create: (_) => ThemeController()),
        ],
        child: const _AppRouter(),
      );
}

class _AppRouter extends StatefulWidget {
  const _AppRouter();

  @override
  State<_AppRouter> createState() => _AppRouterState();
}

class _AppRouterState extends State<_AppRouter> {
  late final GoRouter _router;

  @override
  void initState() {
    super.initState();
    final auth = context.read<AuthController>();
    _router = buildProviderRouter(auth);
  }

  @override
  Widget build(BuildContext context) {
    final themeCtrl = context.watch<ThemeController>();
    return MaterialApp.router(
      title: 'VigiRoutes Pro',
      debugShowCheckedModeBanner: false,
      themeMode: themeCtrl.mode,
      theme: ThemeData(
        colorSchemeSeed: const Color(0xFFFF6B35),
        useMaterial3: true,
        fontFamily: 'Poppins',
        brightness: Brightness.light,
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            minimumSize: const Size(double.infinity, 52),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14)),
          ),
        ),
      ),
      darkTheme: ThemeData(
        colorSchemeSeed: const Color(0xFFFF6B35),
        useMaterial3: true,
        fontFamily: 'Poppins',
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF121212),
        cardColor: const Color(0xFF1E1E1E),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            minimumSize: const Size(double.infinity, 52),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14)),
          ),
        ),
      ),
      routerConfig: _router,
    );
  }
}
