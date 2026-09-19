import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../features/auth/controllers/auth_controller.dart';
import '../../features/ct/controllers/ct_controller.dart';

class ProviderBottomNav extends StatelessWidget {
  const ProviderBottomNav({super.key});

  @override
  Widget build(BuildContext context) {
    final location = GoRouterState.of(context).matchedLocation;
    final auth = context.watch<AuthController>();
    final isCT = auth.provider?.isCTAccredited ?? false;

    if (isCT) {
      return _buildWithCT(context, location);
    }
    return _buildDefault(context, location);
  }

  Widget _buildDefault(BuildContext context, String location) {
    return BottomNavigationBar(
      currentIndex: _index(location, hasCT: false),
      onTap: (i) => _navigate(context, i, hasCT: false),
      selectedItemColor: AppColors.primary,
      unselectedItemColor: AppColors.textMuted,
      type: BottomNavigationBarType.fixed,
      items: const [
        BottomNavigationBarItem(
          icon: Icon(Icons.home_outlined),
          activeIcon: Icon(Icons.home),
          label: 'Accueil',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.history_outlined),
          activeIcon: Icon(Icons.history),
          label: 'Interventions',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.account_balance_wallet_outlined),
          activeIcon: Icon(Icons.account_balance_wallet),
          label: 'Revenus',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.person_outline),
          activeIcon: Icon(Icons.person),
          label: 'Profil',
        ),
      ],
    );
  }

  Widget _buildWithCT(BuildContext context, String location) {
    final ctCtrl = context.watch<CtController>();
    final pendingCount = ctCtrl.pendingMissions.length;

    return BottomNavigationBar(
      currentIndex: _index(location, hasCT: true),
      onTap: (i) => _navigate(context, i, hasCT: true),
      selectedItemColor: AppColors.primary,
      unselectedItemColor: AppColors.textMuted,
      type: BottomNavigationBarType.fixed,
      items: [
        const BottomNavigationBarItem(
          icon: Icon(Icons.home_outlined),
          activeIcon: Icon(Icons.home),
          label: 'Accueil',
        ),
        const BottomNavigationBarItem(
          icon: Icon(Icons.history_outlined),
          activeIcon: Icon(Icons.history),
          label: 'Interventions',
        ),
        BottomNavigationBarItem(
          icon: Stack(
            clipBehavior: Clip.none,
            children: [
              const Icon(Icons.assignment_outlined),
              if (pendingCount > 0)
                Positioned(
                  right: -6,
                  top: -4,
                  child: Container(
                    padding: const EdgeInsets.all(2),
                    decoration: const BoxDecoration(
                      color: AppColors.primary,
                      shape: BoxShape.circle,
                    ),
                    constraints: const BoxConstraints(minWidth: 14, minHeight: 14),
                    child: Text(
                      '$pendingCount',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
            ],
          ),
          activeIcon: const Icon(Icons.assignment),
          label: 'CT',
        ),
        const BottomNavigationBarItem(
          icon: Icon(Icons.account_balance_wallet_outlined),
          activeIcon: Icon(Icons.account_balance_wallet),
          label: 'Revenus',
        ),
        const BottomNavigationBarItem(
          icon: Icon(Icons.person_outline),
          activeIcon: Icon(Icons.person),
          label: 'Profil',
        ),
      ],
    );
  }

  int _index(String location, {required bool hasCT}) {
    if (location.startsWith('/provider/home')) return 0;
    if (location.startsWith('/provider/history')) return 1;
    if (hasCT) {
      if (location.startsWith('/provider/ct')) return 2;
      if (location.startsWith('/provider/earnings')) return 3;
      if (location.startsWith('/provider/profile')) return 4;
    } else {
      if (location.startsWith('/provider/earnings')) return 2;
      if (location.startsWith('/provider/profile')) return 3;
    }
    return 0;
  }

  void _navigate(BuildContext context, int i, {required bool hasCT}) {
    const routesDefault = [
      '/provider/home',
      '/provider/history',
      '/provider/earnings',
      '/provider/profile',
    ];
    const routesWithCT = [
      '/provider/home',
      '/provider/history',
      '/provider/ct',
      '/provider/earnings',
      '/provider/profile',
    ];
    final routes = hasCT ? routesWithCT : routesDefault;
    if (i < routes.length) context.go(routes[i]);
  }
}
