import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/models/models.dart';
import '../../../core/services/api_service.dart';
import '../../../core/services/realtime_service.dart';
import '../../../core/utils/price_calculator.dart';
import '../../home/controllers/provider_controller.dart';
import '../../auth/controllers/auth_controller.dart';

class ProviderNavigationScreen extends StatefulWidget {
  final String interventionId;
  const ProviderNavigationScreen({super.key, required this.interventionId});

  @override
  State<ProviderNavigationScreen> createState() => _ProviderNavigationScreenState();
}

class _ProviderNavigationScreenState extends State<ProviderNavigationScreen> {
  final _api      = ApiService.instance;
  final _realtime = RealtimeService.instance;

  GoogleMapController? _mapCtrl;
  InterventionModel?   _intervention;
  StreamSubscription?  _wsSub;

  @override
  void initState() {
    super.initState();
    _loadIntervention();
    _subscribeToUpdates();
  }

  Future<void> _loadIntervention() async {
    try {
      final data = await _api.getIntervention(widget.interventionId);
      if (mounted) setState(() => _intervention = InterventionModel.fromJson(data));
      _fitCamera();
    } catch (e) {
      debugPrint('[NavScreen] Erreur chargement : $e');
    }
  }

  void _subscribeToUpdates() {
    final providerId = context.read<AuthController>().provider?.id ?? '';
    // Écouter les mises à jour via WebSocket (remplace watchIntervention Firestore)
    _wsSub = _realtime.subscribeToDispatch(providerId)
        .where((data) => data['id'] == widget.interventionId)
        .listen((data) {
          if (!mounted) return;
          setState(() {
            _intervention = _intervention?.copyWithWs(data)
                ?? InterventionModel.fromJson(data);
          });
          _fitCamera();
        });
  }

  void _fitCamera() {
    final i = _intervention;
    if (i == null || _mapCtrl == null) return;
    _mapCtrl!.animateCamera(CameraUpdate.newLatLngBounds(
      _bounds(LatLng(i.userLatitude, i.userLongitude),
          i.providerLatitude != null ? LatLng(i.providerLatitude!, i.providerLongitude!) : null),
      60,
    ));
  }

  @override
  void dispose() {
    _wsSub?.cancel();
    _mapCtrl?.dispose();
    super.dispose();
  }

  LatLngBounds _bounds(LatLng a, LatLng? b) {
    if (b == null) return LatLngBounds(
      southwest: LatLng(a.latitude - 0.01, a.longitude - 0.01),
      northeast: LatLng(a.latitude + 0.01, a.longitude + 0.01),
    );
    return LatLngBounds(
      southwest: LatLng(
        a.latitude  < b.latitude  ? a.latitude  - 0.005 : b.latitude  - 0.005,
        a.longitude < b.longitude ? a.longitude - 0.005 : b.longitude - 0.005,
      ),
      northeast: LatLng(
        a.latitude  > b.latitude  ? a.latitude  + 0.005 : b.latitude  + 0.005,
        a.longitude > b.longitude ? a.longitude + 0.005 : b.longitude + 0.005,
      ),
    );
  }

  Set<Marker> get _markers {
    final markers = <Marker>{};
    final i = _intervention;
    if (i == null) return markers;
    markers.add(Marker(
      markerId: const MarkerId('user'),
      position: LatLng(i.userLatitude, i.userLongitude),
      infoWindow: InfoWindow(title: '📍 Client', snippet: i.userAddress ?? ''),
      icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
    ));
    if (i.providerLatitude != null && i.providerLongitude != null) {
      markers.add(Marker(
        markerId: const MarkerId('provider'),
        position: LatLng(i.providerLatitude!, i.providerLongitude!),
        infoWindow: const InfoWindow(title: '🔧 Ma position'),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueOrange),
      ));
    }
    return markers;
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
      body: Stack(children: [
        // ── Carte ────────────────────────────────────────────────────────────
        GoogleMap(
          initialCameraPosition: CameraPosition(
            target: i != null ? LatLng(i.userLatitude, i.userLongitude) : const LatLng(5.3599517, -4.0082563),
            zoom: 14,
          ),
          onMapCreated: (c) {
            _mapCtrl = c;
            Future.delayed(const Duration(milliseconds: 500), _fitCamera);
          },
          markers: _markers,
          myLocationEnabled: true,
          myLocationButtonEnabled: true,
          zoomControlsEnabled: false,
        ),

        // ── Barre haute ──────────────────────────────────────────────────────
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(children: [
              _CircleBtn(icon: Icons.arrow_back_ios_new,
                  onTap: () => context.go('/provider/home')),
              const Spacer(),
              _CircleBtn(icon: Icons.navigation, color: AppColors.primary,
                  onTap: _openNavigation, tooltip: 'Google Maps'),
            ]),
          ),
        ),

        // ── Panneau bas ──────────────────────────────────────────────────────
        Align(
          alignment: Alignment.bottomCenter,
          child: Container(
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha:0.12), blurRadius: 20)],
            ),
            child: i == null
                ? const Center(child: CircularProgressIndicator())
                : Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
                    _StatusChip(status: i.status),
                    const SizedBox(height: 14),
                    Row(children: [
                      Container(
                        width: 44, height: 44,
                        decoration: BoxDecoration(color: AppColors.primaryLight, shape: BoxShape.circle),
                        child: const Center(child: Text('👤', style: TextStyle(fontSize: 22))),
                      ),
                      const SizedBox(width: 12),
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(i.provider?.name ?? 'Client',
                            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
                        Text('${i.serviceTypeName} — ${PriceCalculator.formatFcfa(i.totalPrice)}',
                            style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                        if (i.userAddress != null)
                          Text(i.userAddress!,
                              style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
                              maxLines: 1, overflow: TextOverflow.ellipsis),
                      ])),
                    ]),
                    const SizedBox(height: 16),
                    const Divider(height: 1),
                    const SizedBox(height: 16),

                    if (i.isAccepted)
                      Row(children: [
                        Expanded(child: OutlinedButton.icon(
                          onPressed: _openNavigation,
                          icon: const Icon(Icons.navigation, size: 16),
                          label: const Text('Naviguer'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.primary,
                            side: const BorderSide(color: AppColors.primary),
                            minimumSize: const Size(0, 44),
                          ),
                        )),
                        const SizedBox(width: 10),
                        Expanded(child: ElevatedButton.icon(
                          onPressed: () => ctrl.startIntervention(i.id),
                          icon: const Icon(Icons.build, size: 16),
                          label: const Text('Démarrer'),
                          style: ElevatedButton.styleFrom(minimumSize: const Size(0, 44)),
                        )),
                      ]),

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
                            if (ok == true) {
                              await ctrl.completeIntervention(i.id);
                              if (context.mounted) context.go('/provider/home');
                            }
                          },
                          icon: const Icon(Icons.check_circle, size: 16),
                          label: const Text('Terminer l\'intervention'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.success,
                            minimumSize: const Size(0, 48),
                          ),
                        ),
                      ),

                    if (i.isCompleted)
                      Center(child: Column(children: [
                        const Text('✅ Intervention terminée !',
                            style: TextStyle(color: AppColors.success, fontWeight: FontWeight.w600)),
                        TextButton(
                          onPressed: () => context.go('/provider/home'),
                          child: const Text('Retour à l\'accueil'),
                        ),
                      ])),
                  ]),
          ),
        ),
      ]),
    );
  }
}

class _CircleBtn extends StatelessWidget {
  final IconData icon;
  final Color? color;
  final VoidCallback onTap;
  final String? tooltip;
  const _CircleBtn({required this.icon, required this.onTap, this.color, this.tooltip});

  @override
  Widget build(BuildContext context) => Tooltip(
        message: tooltip ?? '',
        child: GestureDetector(
          onTap: onTap,
          child: Container(
            width: 42, height: 42,
            decoration: BoxDecoration(
              color: color ?? Colors.white,
              shape: BoxShape.circle,
              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha:0.12), blurRadius: 8)],
            ),
            child: Icon(icon, size: 18, color: color != null ? Colors.white : Colors.black87),
          ),
        ),
      );
}

class _StatusChip extends StatelessWidget {
  final String status;
  const _StatusChip({required this.status});

  @override
  Widget build(BuildContext context) {
    final (label, color, icon) = switch (status) {
      'accepted'    => ('En route vers le client', AppColors.primary,  '🚗'),
      'in_progress' => ('Intervention en cours',   AppColors.success,  '🔧'),
      'completed'   => ('Intervention terminée',   AppColors.success,  '✅'),
      'cancelled'   => ('Annulée',                 AppColors.error,    '❌'),
      _             => ('En attente',              AppColors.warning,  '⏳'),
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
