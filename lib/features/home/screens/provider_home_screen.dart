import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../home/controllers/provider_controller.dart';
import '../../auth/controllers/auth_controller.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/utils/price_calculator.dart';
import '../../../shared/widgets/provider_bottom_nav.dart';

class ProviderHomeScreen extends StatefulWidget {
  const ProviderHomeScreen({super.key});

  @override
  State<ProviderHomeScreen> createState() => _ProviderHomeScreenState();
}

class _ProviderHomeScreenState extends State<ProviderHomeScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final auth = context.read<AuthController>();
      final ctrl = context.read<ProviderController>();
      if (auth.provider != null) {
        // initialize() est idempotent — safe à appeler plusieurs fois
        ctrl.initialize(auth.provider!);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final ctrl = context.watch<ProviderController>();
    final auth = context.watch<AuthController>();
    final provider = auth.provider;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Bonjour, ${provider?.name.split(' ').first ?? 'Prestataire'} 👋',
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Text(
                          provider?.isVerified == true
                              ? '✅ Compte vérifié'
                              : '⏳ Vérification en attente',
                          style: TextStyle(
                            color: provider?.isVerified == true
                                ? AppColors.success
                                : AppColors.warning,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Availability toggle
                  Column(
                    children: [
                      Switch(
                        value: ctrl.isAvailable,
                        onChanged: (_) => ctrl.toggleAvailability(),
                        activeThumbColor: AppColors.success,
                      ),
                      Text(
                        ctrl.isAvailable ? 'Disponible' : 'Indisponible',
                        style: TextStyle(
                          fontSize: 11,
                          color: ctrl.isAvailable
                              ? AppColors.success
                              : AppColors.textMuted,
                        ),
                      ),
                    ],
                  ),
                ],
              ),

              const SizedBox(height: 24),

              // Stats row
              Row(
                children: [
                  Expanded(
                    child: _StatCard(
                      emoji: '💰',
                      label: "Aujourd'hui",
                      value: PriceCalculator.formatFcfa(ctrl.todayEarnings),
                      color: AppColors.success,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _StatCard(
                      emoji: '🔧',
                      label: 'Terminées',
                      value:
                          '${ctrl.myInterventions.where((i) => i.isCompleted).length}',
                      color: AppColors.primary,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 24),

              // Active intervention
              if (ctrl.activeIntervention != null) ...[
                _ActiveInterventionCard(
                  intervention: ctrl.activeIntervention!,
                  ctrl: ctrl,
                ),
                const SizedBox(height: 24),
              ],

              // Pending requests
              Row(
                children: [
                  const Text(
                    'Demandes en attente',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(width: 8),
                  if (ctrl.pendingRequests.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.accent,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '${ctrl.pendingRequests.length}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 12),

              if (ctrl.pendingRequests.isEmpty)
                Container(
                  padding: const EdgeInsets.all(32),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Center(
                    child: Column(
                      children: [
                        Text('😴', style: TextStyle(fontSize: 40)),
                        SizedBox(height: 8),
                        Text(
                          'Aucune demande pour l\'instant',
                          style: TextStyle(color: AppColors.textSecondary),
                        ),
                      ],
                    ),
                  ),
                )
              else
                ...ctrl.pendingRequests
                    .map((req) => _RequestCard(
                          request: req,
                          onAccept: () async {
                            await ctrl.acceptIntervention(req.id);
                            if (context.mounted) {
                              context.push('/provider/navigation/${req.id}');
                            }
                          },
                          onDecline: () => ctrl.declineIntervention(req.id),
                        ))
                    ,
            ],
          ),
        ),
      ),
      bottomNavigationBar: const ProviderBottomNav(),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String emoji;
  final String label;
  final String value;
  final Color color;
  const _StatCard({
    required this.emoji,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 8,
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(emoji, style: const TextStyle(fontSize: 24)),
            const SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 15,
                color: color,
              ),
            ),
            Text(
              label,
              style: const TextStyle(
                color: AppColors.textMuted,
                fontSize: 12,
              ),
            ),
          ],
        ),
      );
}

class _ActiveInterventionCard extends StatelessWidget {
  final dynamic intervention;
  final ProviderController ctrl;
  const _ActiveInterventionCard(
      {required this.intervention, required this.ctrl});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [AppColors.primary, AppColors.primaryDark],
          ),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '🔧 Intervention en cours',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 15,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '${intervention.serviceTypeName} — ${intervention.userName ?? "Client"}',
              style: TextStyle(color: Colors.white.withValues(alpha: 0.9)),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => context.push('/provider/navigation/${intervention.id}'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      side: const BorderSide(color: Colors.white),
                      minimumSize: const Size(0, 40),
                    ),
                    child: const Text('Démarrer'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => context.push('/provider/navigation/${intervention.id}'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: AppColors.primary,
                      minimumSize: const Size(0, 40),
                    ),
                    child: const Text('Terminer'),
                  ),
                ),
              ],
            ),
          ],
        ),
      );
}

class _RequestCard extends StatelessWidget {
  final dynamic request;
  final VoidCallback onAccept;
  final VoidCallback onDecline;
  const _RequestCard({
    required this.request,
    required this.onAccept,
    required this.onDecline,
  });

  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  _icon(request.serviceTypeId),
                  style: const TextStyle(fontSize: 24),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        request.serviceTypeName,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      Text(
                        '${request.distanceKm.toStringAsFixed(1)} km — ${PriceCalculator.formatFcfa(request.totalPrice)}',
                        style: const TextStyle(
                          color: AppColors.primary,
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.warningLight,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    '⏳ Nouvelle',
                    style: TextStyle(fontSize: 11, color: AppColors.warning),
                  ),
                ),
              ],
            ),
            if (request.userAddress != null) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(Icons.location_on_outlined,
                      size: 14, color: AppColors.textMuted),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      request.userAddress!,
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 13,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: onDecline,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.error,
                      side: const BorderSide(color: AppColors.error),
                      minimumSize: const Size(0, 40),
                    ),
                    child: const Text('Refuser'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton(
                    onPressed: onAccept,
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size(0, 40),
                    ),
                    child: const Text('Accepter'),
                  ),
                ),
              ],
            ),
          ],
        ),
      );

  String _icon(String id) {
    const icons = {
      'mechanic': '🔧',
      'towing': '🚛',
      'tire': '🔩',
      'electrical': '⚡',
      'battery': '🔋',
      'fuel': '⛽',
      'locksmith': '🔑',
      'other': '🛠️',
    };
    return icons[id] ?? '🛠️';
  }
}

