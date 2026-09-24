import 'dart:isolate';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'core/services/alert_service.dart';
import 'core/services/api_service.dart';
import 'core/services/service_type_service.dart';
import 'features/auth/controllers/auth_controller.dart';
import 'features/home/controllers/provider_controller.dart';
import 'features/ct/controllers/ct_controller.dart';
import 'core/theme/theme_controller.dart';
import 'shared/navigation/app_router.dart';

// ── Canal Android haute priorité pour les alertes de dispatch ──────────────

const AndroidNotificationChannel _dispatchChannel = AndroidNotificationChannel(
  'dispatch_alerts',           // id (doit correspondre au channel côté serveur)
  'Nouvelles courses',         // nom affiché dans les paramètres
  description : 'Alertes de nouvelles demandes d\'intervention',
  importance  : Importance.max,
  playSound   : true,
  enableVibration: true,
);

final FlutterLocalNotificationsPlugin _localNotifications =
    FlutterLocalNotificationsPlugin();

// ── Handler background / terminated ───────────────────────────────────────
//
// IMPORTANT : ce handler tourne dans un isolate séparé. On ne peut PAS
// utiliser ProviderAlertService ici (AudioPlayer / FlutterTts ne sont pas
// disponibles hors de l'isolate principal). On affiche donc une notification
// locale haute priorité via flutter_local_notifications — Android la montre
// avec vibration + son système, et l'utilisateur tape dessus pour ouvrir
// l'app (qui relancera l'alarme via _bootstrapDispatch dans ProviderController).
@pragma('vm:entry-point')
Future<void> _bgHandler(RemoteMessage message) async {
  await Firebase.initializeApp();

  final data = message.data;
  final type = data['type'] as String?;

  // FIX bug 2 : gérer dispatch_alert ET new_order (les deux types envoyés
  // par le backend pour alerter d'une nouvelle course).
  if (type != 'dispatch_alert' && type != 'new_order') return;

  // FIX bug 2 : initialiser flutter_local_notifications dans cet isolate
  // ET créer explicitement le canal avant d'appeler show().
  // Sans cette création, la notification tombe dans le canal "default"
  // (importance normale, pas de son d'alarme).
  final plugin = FlutterLocalNotificationsPlugin();
  await plugin.initialize(
    const InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      iOS    : DarwinInitializationSettings(),
    ),
  );

  // Créer le canal haute priorité dans l'isolate background
  await plugin
      .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>()
      ?.createNotificationChannel(_dispatchChannel);

  final clientName  = data['client_name']     as String? ?? 'Client';
  final serviceType = data['service_type']    as String? ?? '';
  final address     = data['address']         as String? ?? '';

  final body = [
    if (serviceType.isNotEmpty) serviceType,
    if (address.isNotEmpty) address,
  ].join(' · ');

  await plugin.show(
    0,
    '🆕 Nouvelle course — $clientName',
    body.isNotEmpty ? body : 'Appuyez pour voir la demande',
    NotificationDetails(
      android: AndroidNotificationDetails(
        'dispatch_alerts',
        'Nouvelles courses',
        channelDescription: 'Alertes de nouvelles demandes d\'intervention',
        importance     : Importance.max,
        priority       : Priority.high,
        fullScreenIntent: true,      // affiche même si l'écran est verrouillé
        playSound      : true,
        enableVibration: true,
        ticker         : 'Nouvelle course',
      ),
      iOS: const DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      ),
    ),
  );
}

// ── Entrée principale ─────────────────────────────────────────────────────

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // En release, une erreur de build affiche un écran gris muet. On la rend
  // lisible à l'écran pour pouvoir diagnostiquer sans câble/logcat.
  ErrorWidget.builder = (FlutterErrorDetails details) => Material(
        color: const Color(0xFF8B0000),
        child: Container(
          padding: const EdgeInsets.fromLTRB(20, 60, 20, 20),
          alignment: Alignment.topLeft,
          child: SingleChildScrollView(
            child: Text(
              'ERREUR UI:\n\n${details.exceptionAsString()}',
              style: const TextStyle(color: Colors.white, fontSize: 13),
            ),
          ),
        ),
      );

  await Firebase.initializeApp();

  // ── Crashlytics ────────────────────────────────────────────────────────
  await FirebaseCrashlytics.instance.setCrashlyticsCollectionEnabled(!kDebugMode);
  FlutterError.onError = FirebaseCrashlytics.instance.recordFlutterFatalError;
  PlatformDispatcher.instance.onError = (error, stack) {
    FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
    return true;
  };
  Isolate.current.addErrorListener(RawReceivePort((pair) async {
    final list = pair as List<dynamic>;
    await FirebaseCrashlytics.instance.recordError(
      list.first, list.last as StackTrace?, fatal: true,
    );
  }).sendPort);

  // ── FCM background handler ─────────────────────────────────────────────
  FirebaseMessaging.onBackgroundMessage(_bgHandler);

  // ── Permissions FCM ────────────────────────────────────────────────────
  // FIX bug 2 : requestPermission() peut bloquer indéfiniment sur iOS si
  // Firebase n'est pas encore prêt. On l'enveloppe dans un timeout non-bloquant.
  FirebaseMessaging.instance.requestPermission(
    alert: true, sound: true, badge: true,
  ).timeout(const Duration(seconds: 10), onTimeout: () {
    debugPrint('[FCM] requestPermission timeout — continuing anyway');
    return const NotificationSettings(
      authorizationStatus: AuthorizationStatus.notDetermined,
      alert: AppleNotificationSetting.notSupported,
      announcement: AppleNotificationSetting.notSupported,
      badge: AppleNotificationSetting.notSupported,
      carPlay: AppleNotificationSetting.notSupported,
      criticalAlert: AppleNotificationSetting.notSupported,
      lockScreen: AppleNotificationSetting.notSupported,
      notificationCenter: AppleNotificationSetting.notSupported,
      showPreviews: AppleShowPreviewSetting.never,
      timeSensitive: AppleNotificationSetting.notSupported,
      sound: AppleNotificationSetting.notSupported,
    );
  }).ignore();

  // ── flutter_local_notifications — canal Android haute priorité ────────
  await _localNotifications.initialize(
    const InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      iOS    : DarwinInitializationSettings(
        requestAlertPermission: false, // déjà demandé via FCM ci-dessus
        requestSoundPermission: false,
        requestBadgePermission: false,
      ),
    ),
  );

  // Créer le canal Android (no-op si déjà créé)
  await _localNotifications
      .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
      ?.createNotificationChannel(_dispatchChannel);

  // ── Pré-initialiser le TTS (warm-up) ──────────────────────────────────
  await ProviderAlertService.instance.init();

  // ── Services ───────────────────────────────────────────────────────────
  ApiService.instance.init();
  ServiceTypeService.instance.load();

  runApp(const AutoSosProviderApp());
}

// ─────────────────────────────────────────────────────────────────────────────

class AutoSosProviderApp extends StatelessWidget {
  const AutoSosProviderApp({super.key});

  @override
  Widget build(BuildContext context) => MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => AuthController()),
          ChangeNotifierProvider(create: (_) => ThemeController()),
          ChangeNotifierProvider(create: (_) => ProviderController()),
          ChangeNotifierProvider(create: (_) => CtController()),
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
