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
import '../../auth/controllers/auth_controller.dart';

/// AVANT : cet écran embarquait un widget GoogleMap natif avec marqueurs
/// client/prestataire, qui faisait planter l'app (retour au splashscreen)
/// à l'ouverture. Plutôt que de continuer à deviner la cause exacte côté
/// SDK Maps natif (non diagnosticable sans device physique), on retire
/// complètement la carte intégrée : la navigation réelle passe par
/// l'app Google Maps externe (déjà en place via _openNavigation), qui le
/// fait de toute façon mieux qu'une carte intégrée statique. Ça élimine
/// toute la surface de plantage liée au rendu natif de la carte ici.
class ProviderNavigationScreen extends StatefulWidget {
  final String interventionId;
  const ProviderNavigationScreen({super.key, required this.interventionId});

  @override
  State<ProviderNavigationScreen> createState() => _ProviderNavigationScreenState();
}

class _ProviderNavigationScreenState extends State<ProviderNavigationScreen> {
  final _api      = ApiService.instance;
  final _realtime = RealtimeService.instance;

  InterventionModel?  _intervention;
  StreamSubscription? _wsSub;
  bool                _loadError = false;

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
          _loadError = false;
        });
      }
    } catch (e) {
      debugPrint('[NavScreen] Erreur chargement : $e');
      if (mounted) setState(() => _loadError = true);
    }
  }

  void _subscribeToUpdates() {
    final providerId = context.read<AuthController>().provider?.id ?? '';
    _wsSub = _realtime.subscribeToDispatch(providerId)
        .where((data) => data['id'] == widget.interventionId)
        .listen((data) {
          if (!mounted) return;
          // BUG CORRIGÉ : le payload WS ne contient qu'un sous-ensemble des
          // champs. Le repli InterventionModel.fromJson(data) sur ce
          // payload partiel plantait (champs obligatoires absents, ex.
          // user_id) si un message WS arrivait avant la fin du chargement
          // REST initial. On ignore simplement la mise à jour dans ce cas
          // rare — le chargement REST (déjà en cours) prendra le relais.
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

  Future<void> _openNavigation() async {
    final i = _intervention;
    if (i == null) return;
    final url = 'https://www.google.com/maps/dir/?api=1'
        '&destination=${i.userLatitude},${i.userLongitude}&travelmode=driving';
    await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
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
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.black87),
          onPressed: () => context.go('/provider/home'),
        ),
        title: const Text('Intervention',
            style: TextStyle(color: Colors.black87, fontWeight: FontWeight.w600)),
        actions: [
          if (i != null)
            IconButton(
              icon: const Icon(Icons.navigation, color: AppColors.primary),
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
                  _StatusChip(status: i.status),
                  const SizedBox(height: 20),

                  // ── Carte info client + service ──────────────────────────
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 10),
                      ],
                    ),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Row(children: [
                        Container(
                          width: 46, height: 46,
                          decoration: const BoxDecoration(
                              color: AppColors.primaryLight, shape: BoxShape.circle),
                          child: const Center(child: Text('👤', style: TextStyle(fontSize: 22))),
                        ),
                        const SizedBox(width: 12),
                        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          // BUG CORRIGÉ : affichait i.provider?.name (le nom
                          // du prestataire lui-même) au lieu du client.
                          Text(i.userName ?? 'Client',
                              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
                          Text('${i.serviceTypeName} — ${PriceCalculator.formatFcfa(i.totalPrice)}',
                              style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                        ])),
                      ]),
                      if (i.userAddress != null) ...[
                        const SizedBox(height: 12),
                        const Divider(height: 1),
                        const SizedBox(height: 12),
                        Row(children: [
                          const Icon(Icons.location_on_outlined,
                              size: 18, color: AppColors.textMuted),
                          const SizedBox(width: 8),
                          Expanded(child: Text(i.userAddress!,
                              style: const TextStyle(color: AppColors.textSecondary, fontSize: 13))),
                        ]),
                      ],
                    ]),
                  ),

                  const SizedBox(height: 16),

                  // ── Bouton navigation externe (principal) ────────────────
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: _openNavigation,
                      icon: const Icon(Icons.navigation),
                      label: const Text('Ouvrir l\'itinéraire dans Google Maps'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.primary,
                        side: const BorderSide(color: AppColors.primary),
                        minimumSize: const Size(0, 48),
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),

                  // ── Actions selon le statut ───────────────────────────────
                  if (i.isAccepted)
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () async {
                          final ok = await ctrl.startIntervention(i.id);
                          if (!ok && context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                                content: Text(ctrl.actionError ??
                                    'Erreur lors du démarrage.')));
                          }
                        },
                        icon: const Icon(Icons.build, size: 18),
                        label: const Text('Démarrer l\'intervention'),
                        style: ElevatedButton.styleFrom(minimumSize: const Size(0, 48)),
                      ),
                    ),

                  if (i.isInProgress)
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () async {
                          final ok = await showDialog<bool>(
                            context: context,
                            builder: (_) => AlertDialog(
                              title: const Text('Terminer l\'intervention ?'),
                              content: const Text('Le paiement sera déclenché.'),
                              actions: [
                                TextButton(onPressed: () => Navigator.pop(context, false),
                                    child: const Text('Non')),
                                ElevatedButton(onPressed: () => Navigator.pop(context, true),
                                    child: const Text('Oui, terminer')),
                              ],
                            ),
                          );
                          if (ok != true) return;
                          final success = await ctrl.completeIntervention(i.id);
                          if (!context.mounted) return;
                          if (success) {
                            context.go('/provider/home');
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
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

                  if (i.isCompleted)
                    Center(child: Column(children: [
                      const SizedBox(height: 20),
                      const Text('✅ Intervention terminée !',
                          style: TextStyle(color: AppColors.success, fontWeight: FontWeight.w600)),
                      TextButton(
                        onPressed: () => context.go('/provider/home'),
                        child: const Text('Retour à l\'accueil'),
                      ),
                    ])),
                ],
              ),
            ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final String status;
  const _StatusChip({required this.status});

  @override
  Widget build(BuildContext context) {
    final (label, color, icon) = switch (status) {
      'pending'     => ('En attente',              AppColors.warning, '⏳'),
      'dispatching' => ('Envoyée au client',        AppColors.warning, '📨'),
      'accepted'    => ('En route vers le client',  AppColors.primary, '🚗'),
      'in_progress' => ('Intervention en cours',    AppColors.success, '🔧'),
      'completed'   => ('Intervention terminée',    AppColors.success, '✅'),
      'cancelled'   => ('Annulée',                  AppColors.error,   '❌'),
      _             => ('En attente',               AppColors.warning, '⏳'),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Text(icon),
        const SizedBox(width: 6),
        Text(label, style: TextStyle(color: color, fontWeight: FontWeight.w600, fontSize: 13)),
      ]),
    );
  }
}
