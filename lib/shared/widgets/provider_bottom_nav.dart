import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/app_colors.dart';

class ProviderBottomNav extends StatelessWidget {
  const ProviderBottomNav({super.key});

  @override
  Widget build(BuildContext context) {
    final location = GoRouterState.of(context).matchedLocation;

    return BottomNavigationBar(
      currentIndex: _index(location),
      onTap: (i) => _navigate(context, i),
      selectedItemColor:   AppColors.primary,
      unselectedItemColor: AppColors.textMuted,
      type: BottomNavigationBarType.fixed,
      items: const [
        BottomNavigationBarItem(icon: Icon(Icons.home_outlined),    activeIcon: Icon(Icons.home),            label: 'Accueil'),
        BottomNavigationBarItem(icon: Icon(Icons.history_outlined),  activeIcon: Icon(Icons.history),         label: 'Interventions'),
        BottomNavigationBarItem(icon: Icon(Icons.account_balance_wallet_outlined), activeIcon: Icon(Icons.account_balance_wallet), label: 'Revenus'),
        BottomNavigationBarItem(icon: Icon(Icons.person_outline),   activeIcon: Icon(Icons.person),          label: 'Profil'),
      ],
    );
  }

  int _index(String location) {
    if (location.startsWith('/provider/home'))     return 0;
    if (location.startsWith('/provider/history'))  return 1;
    if (location.startsWith('/provider/earnings')) return 2;
    if (location.startsWith('/provider/profile'))  return 3;
    return 0;
  }

  void _navigate(BuildContext context, int i) {
    const routes = [
      '/provider/home',
      '/provider/history',
      '/provider/earnings',
      '/provider/profile',
    ];
    context.go(routes[i]);
  }
}
