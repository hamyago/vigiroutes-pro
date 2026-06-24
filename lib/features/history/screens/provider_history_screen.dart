import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:timeago/timeago.dart' as timeago;
import '../../../core/constants/app_colors.dart';
import '../../../core/models/models.dart';
import '../../../core/utils/price_calculator.dart';
import '../../../shared/widgets/provider_bottom_nav.dart';
import '../../home/controllers/provider_controller.dart';

class ProviderHistoryScreen extends StatelessWidget {
  const ProviderHistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Les interventions sont déjà chargées dans ProviderController via l'API
    final ctrl = context.watch<ProviderController>();
    final list = ctrl.myInterventions;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mes interventions'),
        automaticallyImplyLeading: false,
      ),
      bottomNavigationBar: const ProviderBottomNav(),
      body: list.isEmpty
          ? const _Empty()
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: list.length,
              itemBuilder: (_, i) => _InterventionTile(intervention: list[i]),
            ),
    );
  }
}

class _InterventionTile extends StatelessWidget {
  final InterventionModel intervention;
  const _InterventionTile({required this.intervention});

  @override
  Widget build(BuildContext context) {
    final (statusLabel, statusColor) = _statusInfo(intervention.status);
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 8)
        ],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Row(children: [
            Text(_serviceIcon(intervention.serviceTypeId),
                style: const TextStyle(fontSize: 22)),
            const SizedBox(width: 10),
            Text(intervention.serviceTypeName,
                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
          ]),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(statusLabel,
                style: TextStyle(
                    color: statusColor,
                    fontSize: 12,
                    fontWeight: FontWeight.w600)),
          ),
        ]),
        const SizedBox(height: 10),
        Row(children: [
          _Info(icon: Icons.attach_money,
              label: PriceCalculator.formatFcfa(intervention.totalPrice)),
          const SizedBox(width: 16),
          _Info(icon: Icons.route,
              label: '${intervention.distanceKm.toStringAsFixed(1)} km'),
          const SizedBox(width: 16),
          _Info(icon: Icons.access_time,
              label: timeago.format(intervention.createdAt, locale: 'fr')),
        ]),
        if (intervention.commission > 0) ...[
          const SizedBox(height: 6),
          Row(children: [
            _Info(icon: Icons.trending_down,
                label: 'Commission : ${PriceCalculator.formatFcfa(intervention.commission)}'),
            const SizedBox(width: 16),
            _Info(icon: Icons.account_balance_wallet,
                label: 'Net : ${PriceCalculator.formatFcfa(intervention.totalPrice - intervention.commission)}'),
          ]),
        ],
      ]),
    );
  }

  String _serviceIcon(String id) => const {
    'mechanic': '🔧', 'towing': '🚛', 'tire': '🔩',
    'electrical': '⚡', 'battery': '🔋', 'fuel': '⛽',
    'locksmith': '🔑', 'other': '🛠️',
  }[id] ?? '🛠️';

  (String, Color) _statusInfo(String status) => switch (status) {
    'pending'     => ('En attente', AppColors.warning),
    'accepted'    => ('Acceptée',   AppColors.primary),
    'in_progress' => ('En cours',   AppColors.success),
    'completed'   => ('Terminée',   AppColors.success),
    'cancelled'   => ('Annulée',    AppColors.error),
    _             => ('Inconnu',    AppColors.textMuted),
  };
}

class _Info extends StatelessWidget {
  final IconData icon;
  final String label;
  const _Info({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) => Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 14, color: AppColors.textMuted),
        const SizedBox(width: 4),
        Flexible(
          child: Text(label,
              style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
              overflow: TextOverflow.ellipsis),
        ),
      ]);
}

class _Empty extends StatelessWidget {
  const _Empty();

  @override
  Widget build(BuildContext context) => const Center(
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Text('🔧', style: TextStyle(fontSize: 64)),
          SizedBox(height: 16),
          Text('Aucune intervention',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
          SizedBox(height: 8),
          Text('Vos interventions effectuées apparaîtront ici.',
              style: TextStyle(color: AppColors.textSecondary),
              textAlign: TextAlign.center),
        ]),
      );
}
