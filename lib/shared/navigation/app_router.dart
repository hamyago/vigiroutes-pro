import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../features/auth/controllers/auth_controller.dart';
import '../../features/auth/screens/splash_screen.dart';
import '../../features/auth/screens/onboarding_screen.dart';
import '../../features/auth/screens/phone_auth_screen.dart';
import '../../features/auth/screens/otp_screen.dart';
import '../../features/auth/screens/profile_setup_screen.dart';
import '../../features/home/screens/provider_home_screen.dart';
import '../../features/interventions/screens/provider_navigation_screen.dart';
import '../../features/interventions/screens/ct_transport_screen.dart';
import '../../features/reviews/screens/review_client_screen.dart';
import '../../features/reviews/screens/provider_reviews_screen.dart';
import '../../features/parts/screens/parts_search_screen.dart';
import '../../features/parts/screens/store_detail_screen.dart';
import '../../features/parts/screens/part_orders_screen.dart';
import '../../features/earnings/screens/provider_earnings_screen.dart';
import '../../features/history/screens/provider_history_screen.dart';
import '../../features/profile/screens/provider_profile_screen.dart';
import '../../features/profile/screens/provider_info_screen.dart';
import '../../features/profile/screens/provider_subscription_history_screen.dart';
import '../../features/profile/screens/provider_rates_screen.dart';
import '../../features/team/screens/team_screen.dart';
import '../../features/subscription/screens/provider_subscription_screen.dart';
import '../../features/ct/screens/ct_missions_screen.dart';
import '../../features/ct/screens/ct_mission_detail_screen.dart';
import '../../features/ct/screens/ct_mission_report_screen.dart';
import '../../features/home/controllers/provider_controller.dart';

GoRouter buildProviderRouter(AuthController auth) => GoRouter(
      initialLocation: '/',
      refreshListenable: auth,
      redirect: (ctx, state) {
        final isAuth    = auth.state == AuthState.authenticated;
        final isLoading = auth.state == AuthState.unknown;
        final loc       = state.matchedLocation;
        final onSplash  = loc == '/';
        final onAuth    = loc.startsWith('/auth');
        final onProvider = loc.startsWith('/provider');

        if (onSplash) return null;
        if (onAuth)   return null;
        if (isLoading) return null;

        // FIX : ne jamais rediriger un prestataire authentifié depuis /provider/*
        // Évite la déconnexion apparente au bouton retour Android.
        if (isAuth && onProvider) return null;

        if (!isAuth && loc != '/onboarding') return '/onboarding';
        if (isAuth && loc == '/onboarding')  return '/provider/home';

        return null;
      },
      routes: [
        GoRoute(path: '/',           builder: (_, __) => const SplashScreen()),
        GoRoute(path: '/onboarding', builder: (_, __) => const OnboardingScreen()),
        GoRoute(path: '/auth/phone', builder: (ctx, s) =>
            const PhoneAuthScreen(isProvider: true)),
        GoRoute(path: '/auth/otp', builder: (ctx, s) {
          final e = s.extra as Map<String, dynamic>? ?? {};
          return OtpScreen(
            phone:      e['phone'] as String? ?? '',
            isProvider: true,
          );
        }),
        GoRoute(path: '/auth/profile-setup', builder: (ctx, s) =>
            const ProfileSetupScreen(isProvider: true)),

        ShellRoute(
          builder: (ctx, state, child) => _ProviderShell(child: child),
          routes: [
            GoRoute(path: '/provider/home',
                builder: (_, __) => const ProviderHomeScreen()),
            GoRoute(path: '/provider/history',
                builder: (_, __) => const ProviderHistoryScreen()),
            GoRoute(path: '/provider/earnings',
                builder: (_, __) => const ProviderEarningsScreen()),
            GoRoute(path: '/provider/profile',
                builder: (_, __) => const ProviderProfileScreen()),
          ],
        ),

        GoRoute(path: '/provider/navigation/:id', builder: (ctx, s) =>
            ProviderNavigationScreen(
                interventionId: s.pathParameters['id']!)),

        GoRoute(path: '/provider/ct-transport/:id', builder: (ctx, s) =>
            CTTransportScreen(
                interventionId: s.pathParameters['id']!)),

        GoRoute(path: '/provider/review/:id', builder: (ctx, s) =>
            ReviewClientScreen(
                interventionId: s.pathParameters['id']!)),

        GoRoute(path: '/provider/parts', builder: (ctx, s) =>
            const PartsSearchScreen()),
        GoRoute(path: '/provider/parts/store/:id', builder: (ctx, s) =>
            StoreDetailScreen(
              storeId: s.pathParameters['id']!,
              query: s.uri.queryParameters['q'],
            )),
        GoRoute(path: '/provider/parts/orders', builder: (ctx, s) =>
            const PartOrdersScreen()),

        GoRoute(path: '/provider/reviews', builder: (ctx, s) =>
            const ProviderReviewsScreen()),

        GoRoute(path: '/provider/subscription', builder: (ctx, s) =>
            const ProviderSubscriptionScreen()),

        GoRoute(path: '/provider/info', builder: (ctx, s) =>
            const ProviderInfoScreen()),
        GoRoute(path: '/provider/subscription/history', builder: (ctx, s) =>
            const ProviderSubscriptionHistoryScreen()),

        GoRoute(path: '/provider/rates', builder: (ctx, s) =>
            const ProviderRatesScreen()),

        GoRoute(path: '/provider/team', builder: (ctx, s) =>
            const TeamScreen()),

        GoRoute(path: '/provider/ct', builder: (_, __) =>
            const CtMissionsScreen()),
        GoRoute(path: '/provider/ct/:id', builder: (ctx, s) =>
            CtMissionDetailScreen(missionId: s.pathParameters['id']!)),
        GoRoute(path: '/provider/ct/:id/report', builder: (ctx, s) =>
            CtMissionReportScreen(missionId: s.pathParameters['id']!)),
      ],
    );

class _ProviderShell extends StatefulWidget {
  final Widget child;
  const _ProviderShell({required this.child});

  @override
  State<_ProviderShell> createState() => _ProviderShellState();
}

class _ProviderShellState extends State<_ProviderShell> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final auth     = context.read<AuthController>();
      final ctrl     = context.read<ProviderController>();
      final provider = auth.provider;
      if (provider != null) ctrl.initialize(provider);
    });
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
