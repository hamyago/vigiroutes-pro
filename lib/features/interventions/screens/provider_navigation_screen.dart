import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/models/models.dart';
import '../../../core/services/api_service.dart';
import '../../../core/services/realtime_service.dart';
import '../../../core/utils/price_calculator.dart';
import '../../home/controllers/provider_controller.dart';
import '../../team/widgets/assign_assistant_sheet.dart';
import '../../auth/controllers/auth_controller.dart';

/// Écran d'intervention : navigation, démarrage, finalisation, notation.
///
/// La carte Google Maps intégrée a été retirée (causait des crashs non
/// diagnostiquables sans device physique). La navigation réelle passe par
/// Google Maps externe via `_openNavigation()`.
class ProviderNavigationScreen extends StatefulWidget {
  final String interventionId;
  const ProviderNavigationScreen(
      {super.key, required this.interventionId});

  @override
  State<ProviderNavigationScreen> createState() =>
      _ProviderNavigationScreenState();
}

class _ProviderNavigationScreenState
    extends State<ProviderNavigationScreen> {
  final _api      = ApiService.instance;
  final _realtime = RealtimeService.instance;

  InterventionModel? _intervention;
  StreamSubscription? _wsSub;
  bool _loadError = false;

  @override
  void initState() {
    super.initState();
    _loadIntervention();
    _subscribeToUpdates();
  }

  Future<void> _loadIntervention() async {
    try {
      final data = await _api
          .getIntervention(widget.interventionId)
          .timeout(const Duration(seconds: 30));
      if (mounted) {
        setState(() {
          _intervention = InterventionModel.fromJson(data);
          _loadError    = false;
        });
      }
    } catch (e) {
      debugPrint('[NavScreen] Erreur chargement : $e');
      if (mounted) setState(() => _loadError = true);
    }
  }

  void _subscribeToUpdates() {
    final providerId =
        context.read<AuthController>().provider?.id ?? '';
    _wsSub = _realtime
        .subscribeToDispatch(providerId)
        .where((data) => data['id'] == widget.interventionId)
        .listen((data) {
      if (!mounted) return;
      // Si le chargement REST n'est pas encore terminé, on ignore
      // la mise à jour WS partielle pour éviter un crash sur les
      // champs obligatoires manquants.
      if (_intervention == null) return;
      setState(() {
        _intervention = _intervention!.copyWithWs(data);
      });
    });
  }

  @override
  void dispose() {
    _wsSub?.cancel();
    super.dispose();
  }

  Future<void> _changeAssignee(InterventionModel i) async {
    final ctrl = context.read<ProviderController>();
    final choice = await showAssignAssistantSheet(
      context,
      assistants: ctrl.assistants,
      currentAssistantId: i.assignedAssistant?.id,
      title: 'Changer l\'intervenant',
    );
    if (choice == null || !mounted) return;
    final ok = await ctrl.assignAssistant(i.id, choice.assistantId);
    if (!mounted) return;
    if (ok) {
      await _loadIntervention();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(
              ctrl.actionError ?? 'Réaffectation impossible.')));
    }
  }

  Future<void> _openNavigation() async {
    final i = _intervention;
    if (i == null) return;
    final url = 'https://www.google.com/maps/dir/?api=1'
        '&destination=${i.userLatitude},${i.userLongitude}'
        '&travelmode=driving';
    await launchUrl(Uri.parse(url),
        mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    final i    = _intervention;
    final ctrl = context.read<ProviderController>();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new,
              color: Colors.black87),
          onPressed: () => context.go('/provider/home'),
        ),
        title: const Text('Intervention',
            style: TextStyle(
                color: Colors.black87, fontWeight: FontWeight.w600)),
        actions: [
          if (i != null)
            IconButton(
              icon:
                  const Icon(Icons.navigation, color: AppColors.primary),
              tooltip: 'Ouvrir Google Maps',
              onPressed: _openNavigation,
            ),
        ],
      ),
      body: i == null
          ? Center(
              child: _loadError
                  ? Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.error_outline,
                              color: AppColors.error, size: 48),
                          const SizedBox(height: 12),
                          const Text(
                            'Impossible de charger cette intervention.',
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 16),
                          ElevatedButton(
                            onPressed: _loadIntervention,
                            child: const Text('Réessayer'),
                          ),
                        ],
                      ),
                    )
                  : const CircularProgressIndicator(),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // CORRECTION : le StatusChip affichait
                  // 'dispatching' → "Envoyée au client" — c'est
                  // le backend qui dispatche VERS le prestataire.
                  // Label corrigé : "Demande reçue".
                  _StatusChip(status: i.status),
                  const SizedBox(height: 20),

                  // ── Carte info client ──────────────────────────────────
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.06),
                          blurRadius: 10,
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(children: [
                          Container(
                            width: 46, height: 46,
                            decoration: const BoxDecoration(
                                color: AppColors.primaryLight,
                                shape: BoxShape.circle),
                            child: const Center(
                                child: Text('👤',
                                    style: TextStyle(fontSize: 22))),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment:
                                  CrossAxisAlignment.start,
                              children: [
                                Text(i.userName ?? 'Client',
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w600,
                                        fontSize: 16)),
                                Text(
                                  '${i.serviceTypeName} — ${PriceCalculator.formatFcfa(i.totalPrice)}',
                                  style: const TextStyle(
                                      color: AppColors.textSecondary,
                                      fontSize: 13),
                                ),
                              ],
                            ),
                          ),
                        ]),
                        if (i.userAddress != null) ...[
                          const SizedBox(height: 12),
                          const Divider(height: 1),
                          const SizedBox(height: 12),
                          Row(children: [
                            const Icon(Icons.location_on_outlined,
                                size: 18, color: AppColors.textMuted),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(i.userAddress!,
                                  style: const TextStyle(
                                      color: AppColors.textSecondary,
                                      fontSize: 13)),
                            ),
                          ]),
                        ],
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // ── Intervenant affecté ────────────────────────────────
                  if (i.isAccepted || i.isInProgress) ...[
                    _AssigneeCard(
                      intervention: i,
                      onChange: () => _changeAssignee(i),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // ── Navigation externe ─────────────────────────────────
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: _openNavigation,
                      icon: const Icon(Icons.navigation),
                      label: const Text(
                          'Ouvrir l\'itinéraire dans Google Maps'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.primary,
                        side: const BorderSide(
                            color: AppColors.primary),
                        minimumSize: const Size(0, 48),
                      ),
                    ),
                  ),

                  // ── Commander des pièces pendant l'intervention ────────
                  if (i.isAccepted || i.isInProgress) ...[
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: () =>
                            context.push('/provider/parts'),
                        icon: const Icon(
                            Icons.build_circle_outlined),
                        label: const Text('Commander des pièces'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.textPrimary,
                          side: const BorderSide(
                              color: AppColors.border),
                          minimumSize: const Size(0, 48),
                        ),
                      ),
                    ),
                  ],

                  const SizedBox(height: 24),

                  // ── Actions selon le statut ────────────────────────────
                  if (i.isAccepted)
                    Column(
                      children: [
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: () async {
                              final ok =
                                  await ctrl.startIntervention(i.id);
                              if (!ok && context.mounted) {
                                ScaffoldMessenger.of(context)
                                    .showSnackBar(SnackBar(
                                        content: Text(ctrl.actionError ??
                                            'Erreur lors du démarrage.')));
                              }
                            },
                            icon: const Icon(Icons.build, size: 18),
                            label: const Text('Démarrer l\'intervention'),
                            style: ElevatedButton.styleFrom(
                                minimumSize: const Size(0, 48)),
                          ),
                        ),
                        const SizedBox(height: 10),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed: () =>
                                _confirmCancel(context, ctrl, i.id),
                            icon: const Icon(Icons.cancel_outlined,
                                size: 18, color: AppColors.error),
                            label: const Text('Annuler la commande',
                                style: TextStyle(color: AppColors.error)),
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(color: AppColors.error),
                              minimumSize: const Size(0, 48),
                            ),
                          ),
                        ),
                      ],
                    ),

                  if (i.isInProgress)
                    Column(
                      children: [
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: () async {
                              final finalAmount = await _askFinalAmount(
                                  context, i.totalPrice);
                              if (finalAmount == null) return;

                              final success =
                                  await ctrl.completeIntervention(
                                      i.id,
                                      finalAmount: finalAmount);
                              if (!context.mounted) return;
                              if (success) {
                                context.go('/provider/review/${i.id}');
                              } else {
                                ScaffoldMessenger.of(context)
                                    .showSnackBar(SnackBar(
                                        content: Text(ctrl.actionError ??
                                            'Erreur lors de la finalisation.')));
                              }
                            },
                            icon: const Icon(Icons.check_circle, size: 18),
                            label: const Text('Terminer l\'intervention'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.success,
                              minimumSize: const Size(0, 48),
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed: () =>
                                _confirmCancel(context, ctrl, i.id),
                            icon: const Icon(Icons.cancel_outlined,
                                size: 18, color: AppColors.error),
                            label: const Text('Annuler la commande',
                                style: TextStyle(color: AppColors.error)),
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(color: AppColors.error),
                              minimumSize: const Size(0, 48),
                            ),
                          ),
                        ),
                      ],
                    ),

                  if (i.isCompleted)
                    Center(
                      child: Column(children: [
                        const SizedBox(height: 20),
                        const Text('✅ Intervention terminée !',
                            style: TextStyle(
                                color: AppColors.success,
                                fontWeight: FontWeight.w600)),
                        const SizedBox(height: 12),
                        ElevatedButton.icon(
                          onPressed: () =>
                              context.push('/provider/review/${i.id}'),
                          icon: const Icon(Icons.star_rounded,
                              size: 18),
                          label: const Text('Noter le client'),
                        ),
                        TextButton(
                          onPressed: () =>
                              context.go('/provider/home'),
                          child:
                              const Text('Retour à l\'accueil'),
                        ),
                      ]),
                    ),
                ],
              ),
            ),
    );
  }
}

// ── Widgets internes ──────────────────────────────────────────────────────────

class _AssigneeCard extends StatelessWidget {
  final InterventionModel intervention;
  final VoidCallback onChange;
  const _AssigneeCard(
      {required this.intervention, required this.onChange});

  @override
  Widget build(BuildContext context) {
    final a      = intervention.assignedAssistant;
    final isSelf = a == null;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
            color: AppColors.primary.withValues(alpha: 0.25)),
      ),
      child: Row(children: [
        CircleAvatar(
          radius: 22,
          backgroundColor: AppColors.primaryLight,
          backgroundImage: (!isSelf &&
                  a.photoUrl != null &&
                  a.photoUrl!.isNotEmpty)
              ? NetworkImage(a.photoUrl!)
              : null,
          child: (isSelf ||
                  a.photoUrl == null ||
                  a.photoUrl!.isEmpty)
              ? Text(isSelf ? '🧑' : '🧑‍🔧',
                  style: const TextStyle(fontSize: 20))
              : null,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Intervenant',
                  style: TextStyle(
                      color: AppColors.textMuted,
                      fontSize: 11.5)),
              const SizedBox(height: 2),
              Text(isSelf ? 'Moi-même' : a.name,
                  style: const TextStyle(
                      fontWeight: FontWeight.w700, fontSize: 15)),
            ],
          ),
        ),
        TextButton.icon(
          onPressed: onChange,
          icon: const Icon(Icons.swap_horiz, size: 18),
          label: const Text('Changer'),
        ),
      ]),
    );
  }
}

/// Chip de statut — libellés corrigés pour refléter le flux réel.
/// 'dispatching' = demande reçue par le prestataire (pas "envoyée au client").
class _StatusChip extends StatelessWidget {
  final String status;
  const _StatusChip({required this.status});

  @override
  Widget build(BuildContext context) {
    final (label, color, icon) = switch (status) {
      'pending'     => ('Demande reçue',              AppColors.warning, '📩'),
      'dispatching' => ('Demande reçue',              AppColors.warning, '📩'),
      'accepted'    => ('En route vers le client',    AppColors.primary, '🚗'),
      'in_progress' => ('Intervention en cours',      AppColors.success, '🔧'),
      'completed'   => ('Intervention terminée',      AppColors.success, '✅'),
      'cancelled'   => ('Annulée',                    AppColors.error,   '❌'),
      _             => ('En attente',                 AppColors.warning, '⏳'),
    };
    return Container(
      padding:
          const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Text(icon),
        const SizedBox(width: 6),
        Text(label,
            style: TextStyle(
                color: color,
                fontWeight: FontWeight.w600,
                fontSize: 13)),
      ]),
    );
  }
}

/// Demande confirmation avant d'annuler une intervention acceptée/en cours.
Future<void> _confirmCancel(
    BuildContext context, ProviderController ctrl, String id) async {
  final confirm = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Annuler la commande ?'),
      content: const Text(
        'Le client sera notifié de l\'annulation.\n\n'
        'Cette action ne peut pas être annulée. '
        'Des annulations répétées peuvent affecter votre note.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text('Retour'),
        ),
        ElevatedButton(
          onPressed: () => Navigator.pop(ctx, true),
          style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error),
          child: const Text('Confirmer l\'annulation',
              style: TextStyle(color: Colors.white)),
        ),
      ],
    ),
  );

  if (confirm != true || !context.mounted) return;
  final ok = await ctrl.cancelIntervention(id);
  if (!context.mounted) return;
  if (ok) {
    context.go('/provider/home');
  } else {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
          content: Text(
              ctrl.actionError ?? 'Impossible d\'annuler. Réessayez.')),
    );
  }
}

/// Popup de saisie du montant final avant de terminer l'intervention.
Future<double?> _askFinalAmount(
    BuildContext context, double defaultAmount) {
  final ctrl = TextEditingController(
      text: defaultAmount.toStringAsFixed(0));
  String? error;

  return showDialog<double>(
    context: context,
    barrierDismissible: false,
    builder: (dialogContext) => StatefulBuilder(
      builder: (dialogContext, setState) => AlertDialog(
        title:
            const Text('Montant final de l\'intervention'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Saisissez le montant réellement payé par le client. '
              'Ce montant servira de base au calcul de la commission.',
              style: TextStyle(
                  fontSize: 13,
                  color: AppColors.textSecondary),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: ctrl,
              autofocus: true,
              keyboardType: const TextInputType.numberWithOptions(
                  decimal: false),
              decoration: InputDecoration(
                labelText: 'Montant (FCFA)',
                suffixText: 'FCFA',
                border: const OutlineInputBorder(),
                errorText: error,
              ),
              onChanged: (_) {
                if (error != null) {
                  setState(() => error = null);
                }
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () {
              final value = double.tryParse(
                  ctrl.text.trim().replaceAll(' ', ''));
              if (value == null || value < 500) {
                setState(() => error =
                    'Montant invalide (minimum 500 FCFA)');
                return;
              }
              Navigator.pop(dialogContext, value);
            },
            child: const Text('Confirmer et terminer'),
          ),
        ],
      ),
    ),
  );
}
