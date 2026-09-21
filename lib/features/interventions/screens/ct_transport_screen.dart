import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/services/api_service.dart';

/// Modèle léger pour une mission CT transport (TechnicalVisitBooking côté API)
class _CTMission {
  final String id;
  final String reference;
  final String providerStatus; // assigned | en_route | arrived | completed
  final String registrationNumber;
  final String vehicleBrand;
  final String vehicleModel;
  final String clientName;
  final String clientPhone;
  final String centerName;
  final String centerAddress;
  final double centerLat;
  final double centerLng;
  final String slotTime;

  const _CTMission({
    required this.id,
    required this.reference,
    required this.providerStatus,
    required this.registrationNumber,
    required this.vehicleBrand,
    required this.vehicleModel,
    required this.clientName,
    required this.clientPhone,
    required this.centerName,
    required this.centerAddress,
    required this.centerLat,
    required this.centerLng,
    required this.slotTime,
  });

  factory _CTMission.fromJson(Map<String, dynamic> j) => _CTMission(
        id:                 j['id']?.toString() ?? '',
        reference:          j['reference']?.toString() ?? '',
        providerStatus:     j['provider_status']?.toString() ?? 'assigned',
        registrationNumber: j['registration_number']?.toString() ?? '',
        vehicleBrand:       j['vehicle_brand']?.toString() ?? '',
        vehicleModel:       j['vehicle_model']?.toString() ?? '',
        clientName:         j['client_name']?.toString() ?? '',
        clientPhone:        j['client_phone']?.toString() ?? '',
        centerName:         j['center_name']?.toString() ?? '',
        centerAddress:      j['center_address']?.toString() ?? '',
        centerLat:          (j['center_lat'] as num?)?.toDouble() ?? 0.0,
        centerLng:          (j['center_lng'] as num?)?.toDouble() ?? 0.0,
        slotTime:           j['slot_time']?.toString() ?? '',
      );

  _CTMission copyWith({String? providerStatus}) => _CTMission(
        id:                 id,
        reference:          reference,
        providerStatus:     providerStatus ?? this.providerStatus,
        registrationNumber: registrationNumber,
        vehicleBrand:       vehicleBrand,
        vehicleModel:       vehicleModel,
        clientName:         clientName,
        clientPhone:        clientPhone,
        centerName:         centerName,
        centerAddress:      centerAddress,
        centerLat:          centerLat,
        centerLng:          centerLng,
        slotTime:           slotTime,
      );

  /// Phase 1 : en_route  — prestataire va chercher le véhicule
  /// Phase 2 : arrived   — véhicule déposé au centre CT
  bool get isEnRoute  => providerStatus == 'en_route';
  bool get isArrived  => providerStatus == 'arrived' || providerStatus == 'completed';
  bool get isPhase2   => isEnRoute; // navigation vers centre
}

/// Écran de mission CT Transport pour le remorqueur accrédité CT.
///
/// [missionId] = TechnicalVisitBooking.id
///
/// Flow:
///   assigned  → bouton "Démarrer" → PATCH status=en_route  → navigation vers client
///   en_route  → bouton "Arrivé au centre" → PATCH status=arrived → mission terminée
class CTTransportScreen extends StatefulWidget {
  final String interventionId; // reçu depuis le router, correspond au booking id
  const CTTransportScreen({super.key, required this.interventionId});

  @override
  State<CTTransportScreen> createState() => _CTTransportScreenState();
}

class _CTTransportScreenState extends State<CTTransportScreen>
    with SingleTickerProviderStateMixin {
  final _api = ApiService.instance;

  _CTMission? _mission;
  bool _loadError  = false;
  bool _confirming = false;

  late AnimationController _fadeCtrl;
  late Animation<double>   _fade;

  @override
  void initState() {
    super.initState();
    _fadeCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 350));
    _fade = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeIn);
    _fadeCtrl.forward();
    _load();
  }

  @override
  void dispose() {
    _fadeCtrl.dispose();
    super.dispose();
  }

  // ── Chargement ───────────────────────────────────────────────────────────

  Future<void> _load() async {
    setState(() { _loadError = false; });
    try {
      final resp = await _api
          .get('/v1/ct/missions/${widget.interventionId}')
          .timeout(const Duration(seconds: 20));
      final data = resp['data'];
      if (mounted) {
        setState(() => _mission = _CTMission.fromJson(data as Map<String, dynamic>));
      }
    } catch (_) {
      if (mounted) setState(() => _loadError = true);
    }
  }

  // ── Navigation Google Maps ────────────────────────────────────────────────

  Future<void> _openNavigation() async {
    final m = _mission;
    if (m == null) return;

    // Phase 2 (en_route) → naviguer vers le centre CT
    // Phase 1 (assigned) → pas de coordonnées client dans ce modèle
    //   on ouvre quand même le centre CT comme destination par défaut
    final lat = m.centerLat;
    final lng = m.centerLng;
    if (lat == 0.0 && lng == 0.0) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Coordonnées du centre non disponibles')),
        );
      }
      return;
    }
    final url =
        'https://www.google.com/maps/dir/?api=1&destination=$lat,$lng&travelmode=driving';
    await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
  }

  Future<void> _callClient() async {
    final phone = _mission?.clientPhone ?? '';
    if (phone.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Numéro client non disponible')),
        );
      }
      return;
    }
    final uri = Uri.parse('tel:$phone');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  // ── Actions ───────────────────────────────────────────────────────────────

  /// Phase 1 → status = en_route (prestataire part chercher le véhicule)
  Future<void> _startMission() async {
    if (_mission == null || _confirming) return;

    final ok = await _showConfirmDialog(
      title:   'Démarrer la mission',
      content: 'Vous confirmez partir chercher le véhicule chez le client ?',
      cta:     'Démarrer',
      color:   AppColors.primary,
    );
    if (!ok || !mounted) return;

    await _patchStatus('en_route');

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Mission démarrée — naviguez vers le centre CT'),
          backgroundColor: Colors.green,
        ),
      );
      _fadeCtrl.reset();
      _fadeCtrl.forward();
    }
  }

  /// Phase 2 → status = arrived (véhicule déposé au centre)
  Future<void> _confirmArrived() async {
    final m = _mission;
    if (m == null || _confirming) return;

    final ok = await _showConfirmDialog(
      title:   'Confirmer la livraison',
      content: 'Vous confirmez avoir déposé le véhicule au centre\n${m.centerName} ?',
      cta:     'Confirmer',
      color:   Colors.green,
    );
    if (!ok || !mounted) return;

    await _patchStatus('arrived');

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Mission CT terminée avec succès !'),
          backgroundColor: Colors.green,
        ),
      );
      context.go('/provider/home');
    }
  }

  Future<void> _patchStatus(String status) async {
    setState(() => _confirming = true);
    try {
      await _api.patch(
        '/v1/ct/missions/${widget.interventionId}/status',
        data: {'status': status},
      );
      if (mounted) {
        setState(() {
          _mission   = _mission!.copyWith(providerStatus: status);
          _confirming = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _confirming = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur : ${e.toString().replaceAll('Exception: ', '')}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<bool> _showConfirmDialog({
    required String title,
    required String content,
    required String cta,
    required Color  color,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title:   Text(title),
        content: Text(content),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: color,
              foregroundColor: Colors.white,
            ),
            child: Text(cta),
          ),
        ],
      ),
    );
    return result == true;
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    if (_loadError) {
      return Scaffold(
        appBar: AppBar(title: const Text('Mission CT')),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 48, color: Colors.red),
              const SizedBox(height: 12),
              const Text('Impossible de charger la mission'),
              const SizedBox(height: 16),
              ElevatedButton(onPressed: _load, child: const Text('Réessayer')),
            ],
          ),
        ),
      );
    }

    final m = _mission;
    if (m == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator(color: AppColors.primary)),
      );
    }

    // assigned   → Phase 1 : démarrer / aller chercher
    // en_route   → Phase 2 : naviguer puis confirmer arrivée au centre
    // arrived/completed → mission terminée (ne devrait pas s'afficher normalement)
    final phase2    = m.isPhase2;    // en_route
    final isDone    = m.isArrived;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        title: Text('Mission CT — ${m.reference}'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _load),
        ],
      ),
      body: FadeTransition(
        opacity: _fade,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [

              // ── Indicateur de phase ───────────────────────────────────────
              _PhaseBanner(phase2: phase2, isDone: isDone),
              const SizedBox(height: 16),

              // ── Destination active ────────────────────────────────────────
              _DestinationCard(
                mission:    m,
                phase2:     phase2,
                onNavigate: _openNavigation,
              ),
              const SizedBox(height: 12),

              // ── Infos client & véhicule ───────────────────────────────────
              _ClientVehicleCard(mission: m, onCall: _callClient),
              const SizedBox(height: 12),

              // ── Centre CT ────────────────────────────────────────────────
              _CTCenterCard(mission: m),
              const SizedBox(height: 24),

              // ── CTA principal ─────────────────────────────────────────────
              if (!isDone) ...[
                if (!phase2)
                  _ActionButton(
                    label:    'Démarrer — aller au centre CT',
                    sublabel: 'Avec le véhicule du client',
                    icon:     Icons.directions_car,
                    color:    AppColors.primary,
                    loading:  _confirming,
                    onPressed: _startMission,
                  )
                else
                  _ActionButton(
                    label:    'Confirmer arrivée au centre',
                    sublabel: 'Le véhicule est déposé',
                    icon:     Icons.flag,
                    color:    Colors.green,
                    loading:  _confirming,
                    onPressed: _confirmArrived,
                  ),
              ] else
                _DoneCard(centerName: m.centerName),

              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Widgets ──────────────────────────────────────────────────────────────────

class _PhaseBanner extends StatelessWidget {
  final bool phase2;
  final bool isDone;
  const _PhaseBanner({required this.phase2, required this.isDone});

  @override
  Widget build(BuildContext context) {
    final activeColor = isDone ? Colors.green : AppColors.primary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: activeColor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: activeColor, width: 1.2),
      ),
      child: Row(
        children: [
          _Step(number: '1', label: 'En route', done: phase2 || isDone, active: !phase2 && !isDone),
          Expanded(
            child: Container(
              height: 2,
              margin: const EdgeInsets.symmetric(horizontal: 8),
              color: phase2 || isDone ? Colors.green : Colors.grey[300],
            ),
          ),
          _Step(number: '2', label: 'Arrivée CT', done: isDone, active: phase2 && !isDone),
        ],
      ),
    );
  }
}

class _Step extends StatelessWidget {
  final String number;
  final String label;
  final bool done;
  final bool active;
  const _Step({required this.number, required this.label, required this.done, required this.active});

  @override
  Widget build(BuildContext context) {
    final color = done ? Colors.green : active ? AppColors.primary : Colors.grey[400]!;
    return Column(
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: done ? Colors.green : active ? AppColors.primary : Colors.grey[200],
          ),
          child: Center(
            child: done
                ? const Icon(Icons.check, color: Colors.white, size: 18)
                : Text(number,
                    style: TextStyle(
                      color: active ? Colors.white : Colors.grey,
                      fontWeight: FontWeight.bold,
                    )),
          ),
        ),
        const SizedBox(height: 4),
        Text(label,
            style: TextStyle(
              fontSize: 11,
              color: color,
              fontWeight: active || done ? FontWeight.bold : FontWeight.normal,
            )),
      ],
    );
  }
}

class _DestinationCard extends StatelessWidget {
  final _CTMission mission;
  final bool phase2;
  final VoidCallback onNavigate;
  const _DestinationCard({required this.mission, required this.phase2, required this.onNavigate});

  @override
  Widget build(BuildContext context) {
    final m       = mission;
    final title   = 'Centre de contrôle technique';
    final address = m.centerAddress.isNotEmpty ? m.centerAddress : m.centerName;
    final color   = phase2 ? Colors.green : AppColors.primary;

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Icon(Icons.business, color: color, size: 22),
              const SizedBox(width: 8),
              Expanded(
                child: Text(title,
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: color)),
              ),
            ]),
            const SizedBox(height: 8),
            Text(address, style: const TextStyle(fontSize: 14, color: Color(0xFF444444))),
            if (m.slotTime.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text('Créneau : ${m.slotTime}',
                  style: const TextStyle(fontSize: 12, color: Colors.grey)),
            ],
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              height: 46,
              child: ElevatedButton.icon(
                onPressed: onNavigate,
                icon: const Icon(Icons.navigation_outlined),
                label: const Text('Lancer la navigation'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: color,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ClientVehicleCard extends StatelessWidget {
  final _CTMission mission;
  final VoidCallback onCall;
  const _ClientVehicleCard({required this.mission, required this.onCall});

  @override
  Widget build(BuildContext context) {
    final m = mission;
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Client & véhicule',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            const Divider(height: 16),
            _InfoRow(label: 'Client',   value: m.clientName.isNotEmpty ? m.clientName : '—'),
            _InfoRow(label: 'Téléphone',value: m.clientPhone.isNotEmpty ? m.clientPhone : '—'),
            _InfoRow(label: 'Véhicule', value: '${m.vehicleBrand} ${m.vehicleModel}'.trim().isNotEmpty
                ? '${m.vehicleBrand} ${m.vehicleModel}'.trim()
                : '—'),
            _InfoRow(label: 'Immatriculation', value: m.registrationNumber.isNotEmpty ? m.registrationNumber : '—'),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: onCall,
              icon: const Icon(Icons.phone),
              label: const Text('Appeler le client'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.primary,
                side: const BorderSide(color: AppColors.primary),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CTCenterCard extends StatelessWidget {
  final _CTMission mission;
  const _CTCenterCard({required this.mission});

  @override
  Widget build(BuildContext context) {
    final m = mission;
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              const Icon(Icons.business_center, size: 18, color: Colors.grey),
              const SizedBox(width: 6),
              const Text('Centre de destination',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            ]),
            const Divider(height: 16),
            _InfoRow(label: 'Nom',     value: m.centerName.isNotEmpty ? m.centerName : '—'),
            _InfoRow(label: 'Adresse', value: m.centerAddress.isNotEmpty ? m.centerAddress : '—'),
          ],
        ),
      ),
    );
  }
}

class _DoneCard extends StatelessWidget {
  final String centerName;
  const _DoneCard({required this.centerName});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.green.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.green),
      ),
      child: Column(
        children: [
          const Icon(Icons.check_circle, color: Colors.green, size: 40),
          const SizedBox(height: 8),
          const Text('Mission terminée',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.green)),
          const SizedBox(height: 4),
          Text('Véhicule déposé au centre $centerName',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 13, color: Colors.grey)),
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final String label;
  final String sublabel;
  final IconData icon;
  final Color color;
  final bool loading;
  final VoidCallback onPressed;
  const _ActionButton({
    required this.label,
    required this.sublabel,
    required this.icon,
    required this.color,
    required this.loading,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: loading ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          disabledBackgroundColor: color.withValues(alpha: 0.5),
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          elevation: 2,
        ),
        child: loading
            ? const SizedBox(
                height: 22, width: 22,
                child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white)),
              )
            : Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, size: 26),
                  const SizedBox(height: 4),
                  Text(label,
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                  Text(sublabel,
                      style: const TextStyle(fontSize: 11, color: Colors.white70)),
                ],
              ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 130,
            child: Text(label,
                style: const TextStyle(fontSize: 12, color: Colors.grey)),
          ),
          Expanded(
            child: Text(value,
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
          ),
        ],
      ),
    );
  }
}
