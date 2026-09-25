import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../home/controllers/provider_controller.dart';
import '../../auth/controllers/auth_controller.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/models/models.dart';
import '../../../core/utils/price_calculator.dart';
import '../../../shared/widgets/provider_bottom_nav.dart';
import '../../team/widgets/assign_assistant_sheet.dart';

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
        ctrl.initialize(auth.provider!);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final ctrl     = context.watch<ProviderController>();
    final auth     = context.watch<AuthController>();
    final provider = auth.provider;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Header ──────────────────────────────────────────────────
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
                  // Toggle disponibilité
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

              // ── Statistiques ─────────────────────────────────────────────
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
                      value: '${ctrl.myInterventions.where((i) => i.isCompleted).length}',
                      color: AppColors.primary,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 24),

              // ── Pièces auto ──────────────────────────────────────────────
              InkWell(
                onTap: () => context.push('/provider/parts'),
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [AppColors.primary, AppColors.primaryDark],
                    ),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 44, height: 44,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Center(
                            child: Text('🔩',
                                style: TextStyle(fontSize: 22))),
                      ),
                      const SizedBox(width: 14),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Pièces auto',
                                style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 15)),
                            Text('Commandez des pièces chez un magasin proche',
                                style:
                                    TextStyle(color: Colors.white70, fontSize: 12)),
                          ],
                        ),
                      ),
                      const Icon(Icons.chevron_right, color: Colors.white),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // ── Intervention active ───────────────────────────────────────
              if (ctrl.activeIntervention != null) ...[
                _ActiveInterventionCard(
                  intervention: ctrl.activeIntervention!,
                  ctrl: ctrl,
                ),
                const SizedBox(height: 24),
              ],

              // ── Demandes en attente ───────────────────────────────────────
              Row(
                children: [
                  const Text(
                    'Demandes en attente',
                    style: TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(width: 8),
                  if (ctrl.pendingRequests.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
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
                ...ctrl.pendingRequests.map((req) => _RequestCard(
                      request: req,
                      secondsLeft: ctrl.dispatchSecondsLeft(req.id),
                      onAccept: () async {
                        int? assistantId;
                        if (ctrl.assistants.isNotEmpty) {
                          final choice =
                              await showAssignAssistantSheet(
                            context,
                            assistants: ctrl.assistants,
                            currentAssistantId: null,
                            title: 'Qui va intervenir ?',
                          );
                          if (choice == null) return;
                          assistantId = choice.assistantId;
                        }
                        final ok = await ctrl.acceptIntervention(
                            req.id,
                            assignedAssistantId: assistantId);
                        if (!context.mounted) return;
                        if (ok) {
                          context.push(req.isCTTransport
                              ? '/provider/ct-transport/${req.ctBookingId ?? req.id}'
                              : '/provider/navigation/${req.id}');
                        } else {
                          ScaffoldMessenger.of(context)
                              .showSnackBar(SnackBar(
                                  content: Text(ctrl.actionError ??
                                      'Erreur lors de l\'acceptation.')));
                        }
                      },
                      onDecline: () async {
                        final ok =
                            await ctrl.declineIntervention(req.id);
                        if (!ok && context.mounted) {
                          ScaffoldMessenger.of(context)
                              .showSnackBar(SnackBar(
                                  content: Text(ctrl.actionError ??
                                      'Erreur lors du refus.')));
                        }
                      },
                    )),
            ],
          ),
        ),
      ),
      bottomNavigationBar: const ProviderBottomNav(),
    );
  }
}

// ── Widgets ────────────────────────────────────────────────────────────────────

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
            Text(value,
                style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                    color: color)),
            Text(label,
                style: const TextStyle(
                    color: AppColors.textMuted, fontSize: 12)),
          ],
        ),
      );
}

class _ActiveInterventionCard extends StatelessWidget {
  final InterventionModel intervention;
  final ProviderController ctrl;
  const _ActiveInterventionCard(
      {required this.intervention, required this.ctrl});

  @override
  Widget build(BuildContext context) {
    final isCT = intervention.isCTTransport;
    final route = isCT
        ? '/provider/ct-transport/${intervention.ctBookingId ?? intervention.id}'
        : '/provider/navigation/${intervention.id}';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isCT
              ? [Colors.green.shade600, Colors.green.shade800]
              : [AppColors.primary, AppColors.primaryDark],
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  isCT
                      ? '🚗 Mission CT en cours'
                      : '🔧 Intervention en cours',
                  style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 15),
                ),
              ),
              GestureDetector(
                onTap: () => _confirmCancel(context),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text('Annuler',
                      style:
                          TextStyle(color: Colors.white70, fontSize: 12)),
                ),
              ),
            ],
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
                  onPressed: () => context.push(route),
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
                  onPressed: () => context.push(route),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: AppColors.primary,
                    minimumSize: const Size(0, 40),
                  ),
                  child: Text(isCT ? 'Continuer' : 'Terminer'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _confirmCancel(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Annuler l\'intervention ?'),
        content: const Text(
          'Le client sera informé. Cette action ne peut pas être annulée.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Non'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(
                foregroundColor: AppColors.error),
            child: const Text('Oui, annuler'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    final ok = await ctrl.cancelIntervention(intervention.id);
    if (!context.mounted) return;
    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content:
            Text(ctrl.actionError ?? 'Impossible d\'annuler.'),
      ));
    }
  }
}

/// Carte de demande avec compte à rebours dynamique intégré.
class _RequestCard extends StatefulWidget {
  final InterventionModel request;
  final int?              secondsLeft;
  final VoidCallback      onAccept;
  final VoidCallback      onDecline;

  const _RequestCard({
    required this.request,
    required this.secondsLeft,
    required this.onAccept,
    required this.onDecline,
  });

  @override
  State<_RequestCard> createState() => _RequestCardState();
}

class _RequestCardState extends State<_RequestCard> {
  @override
  Widget build(BuildContext context) {
    final sLeft = widget.secondsLeft;
    // Couleur du compte à rebours : vert → orange → rouge
    final Color timerColor = sLeft == null
        ? AppColors.textMuted
        : sLeft > 15
            ? AppColors.success
            : sLeft > 7
                ? AppColors.warning
                : AppColors.error;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: sLeft != null && sLeft <= 7
              ? AppColors.error.withValues(alpha: 0.5)
              : AppColors.border,
        ),
      ),
      child: Column(
        children: [
          // Barre de progression du temps restant
          if (sLeft != null)
            ClipRRect(
              borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(15)),
              child: LinearProgressIndicator(
                value: sLeft / kDispatchTimeoutSeconds,
                minHeight: 4,
                backgroundColor: AppColors.border,
                color: timerColor,
              ),
            ),

          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      _icon(widget.request.serviceTypeId),
                      style: const TextStyle(fontSize: 24),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.request.serviceTypeName,
                            style: const TextStyle(
                                fontWeight: FontWeight.w600),
                          ),
                          Text(
                            '${widget.request.distanceKm.toStringAsFixed(1)} km — '
                            '${PriceCalculator.formatFcfa(widget.request.totalPrice)}',
                            style: const TextStyle(
                              color: AppColors.primary,
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Compte à rebours
                    if (sLeft != null)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: timerColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '⏱ ${sLeft}s',
                          style: TextStyle(
                            color: timerColor,
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                          ),
                        ),
                      )
                    else
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.warningLight,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text(
                          '⏳ Nouvelle',
                          style: TextStyle(
                              fontSize: 11,
                              color: AppColors.warning),
                        ),
                      ),
                  ],
                ),

                if (widget.request.userAddress != null) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(Icons.location_on_outlined,
                          size: 14, color: AppColors.textMuted),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          widget.request.userAddress!,
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
                        onPressed: widget.onDecline,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.error,
                          side: const BorderSide(
                              color: AppColors.error),
                          minimumSize: const Size(0, 40),
                        ),
                        child: const Text('Refuser'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: widget.onAccept,
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
          ),
        ],
      ),
    );
  }

  String _icon(String id) {
    const icons = {
      'mechanic':   '🔧',
      'towing':     '🚛',
      'tire':       '🔩',
      'electrical': '⚡',
      'battery':    '🔋',
      'fuel':       '⛽',
      'locksmith':  '🔑',
      'other':      '🛠️',
    };
    return icons[id] ?? '🛠️';
  }
}
