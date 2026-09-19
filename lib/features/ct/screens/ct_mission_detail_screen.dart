import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../controllers/ct_controller.dart';
import '../../../core/models/ct_mission_model.dart';
import '../../../core/constants/app_colors.dart';

class CtMissionDetailScreen extends StatelessWidget {
  final String missionId;
  const CtMissionDetailScreen({super.key, required this.missionId});

  @override
  Widget build(BuildContext context) {
    final ctrl = context.watch<CtController>();
    final mission = ctrl.missions.where((m) => m.id == missionId).firstOrNull;

    if (mission == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Mission CT'),
          leading: BackButton(onPressed: () => context.pop()),
        ),
        body: const Center(child: Text('Mission introuvable')),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        leading: BackButton(
          color: AppColors.textPrimary,
          onPressed: () => context.pop(),
        ),
        title: Text(
          mission.reference,
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w700,
            fontSize: 17,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _StatusBanner(mission: mission),
            const SizedBox(height: 20),
            _InfoCard(
              title: 'Véhicule',
              icon: Icons.directions_car,
              children: [
                _InfoRow('Marque / Modèle', '${mission.vehicleBrand} ${mission.vehicleModel}'),
                _InfoRow('Immatriculation', mission.registrationNumber),
                _InfoRow('Couleur', mission.vehicleColor),
              ],
            ),
            const SizedBox(height: 16),
            _InfoCard(
              title: 'Client',
              icon: Icons.person,
              children: [
                _InfoRow('Nom', mission.clientName),
                _InfoRow('Téléphone', mission.clientPhone),
              ],
            ),
            const SizedBox(height: 16),
            _CenterCard(mission: mission),
            const SizedBox(height: 16),
            if (mission.slotTime.isNotEmpty)
              _InfoCard(
                title: 'Créneau',
                icon: Icons.schedule,
                children: [_InfoRow('Heure prévue', mission.slotTime)],
              ),
            const SizedBox(height: 28),
            _ActionButtons(mission: mission),
          ],
        ),
      ),
    );
  }
}

class _StatusBanner extends StatelessWidget {
  final CtMissionModel mission;
  const _StatusBanner({required this.mission});

  Color get _color {
    if (mission.isPending) return AppColors.warning;
    if (mission.isEnRoute) return AppColors.blue;
    if (mission.isArrived) return AppColors.primary;
    if (mission.isCompleted) return AppColors.success;
    return AppColors.textMuted;
  }

  IconData get _icon {
    if (mission.isEnRoute) return Icons.navigation;
    if (mission.isArrived) return Icons.location_on;
    if (mission.isCompleted) return Icons.check_circle;
    return Icons.assignment;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _color.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Icon(_icon, color: _color, size: 28),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                mission.statusLabel,
                style: TextStyle(
                  color: _color,
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                ),
              ),
              if (mission.isCompleted && mission.completedAt != null)
                Text(
                  'Terminée le ${_formatDate(mission.completedAt!)}',
                  style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
                ),
            ],
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime dt) {
    return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year} à ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }
}

class _CenterCard extends StatelessWidget {
  final CtMissionModel mission;
  const _CenterCard({required this.mission});

  Future<void> _openMaps(BuildContext context) async {
    final lat = mission.centerLat;
    final lng = mission.centerLng;
    final encoded = Uri.encodeComponent(mission.centerName);
    final geoUri = Uri.parse('geo:$lat,$lng?q=$encoded');
    final gmapsUri = Uri.parse(
        'https://www.google.com/maps/search/?api=1&query=$lat,$lng');

    if (await canLaunchUrl(geoUri)) {
      await launchUrl(geoUri);
    } else if (await canLaunchUrl(gmapsUri)) {
      await launchUrl(gmapsUri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.business, size: 18, color: AppColors.primary),
              const SizedBox(width: 8),
              const Text(
                'Centre CT',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            mission.centerName,
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 15,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            mission.centerAddress,
            style: const TextStyle(color: AppColors.textSecondary, fontSize: 14),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => _openMaps(context),
              icon: const Icon(Icons.navigation, size: 18),
              label: const Text('Naviguer vers le centre'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.blue,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionButtons extends StatelessWidget {
  final CtMissionModel mission;
  const _ActionButtons({required this.mission});

  @override
  Widget build(BuildContext context) {
    final ctrl = context.read<CtController>();

    if (mission.isCompleted || mission.isCancelled) {
      return const SizedBox.shrink();
    }

    return Column(
      children: [
        if (mission.isPending) ...[
          _ActionBtn(
            label: 'Partir en route',
            icon: Icons.navigation,
            color: AppColors.blue,
            onTap: () async {
              final ok = await ctrl.updateStatus(mission.id, 'en_route');
              if (!ok && context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Erreur lors de la mise à jour')),
                );
              }
            },
          ),
        ],
        if (mission.isEnRoute) ...[
          _ActionBtn(
            label: 'Je suis arrivé',
            icon: Icons.location_on,
            color: AppColors.primary,
            onTap: () async {
              final ok = await ctrl.updateStatus(mission.id, 'arrived');
              if (!ok && context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Erreur lors de la mise à jour')),
                );
              }
            },
          ),
        ],
        if (mission.isArrived) ...[
          _ActionBtn(
            label: 'Soumettre le rapport CT',
            icon: Icons.assignment_turned_in,
            color: AppColors.success,
            onTap: () => context.push('/provider/ct/${mission.id}/report'),
          ),
        ],
      ],
    );
  }
}

class _ActionBtn extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  const _ActionBtn({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: onTap,
        icon: Icon(icon, size: 20),
        label: Text(label, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final List<Widget> children;
  const _InfoCard({required this.title, required this.icon, required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: AppColors.primary),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  const _InfoRow(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 130,
            child: Text(
              label,
              style: const TextStyle(color: AppColors.textMuted, fontSize: 13),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
