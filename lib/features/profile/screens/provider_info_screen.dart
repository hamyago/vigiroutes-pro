import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/models/models.dart';
import '../../auth/controllers/auth_controller.dart';

/// Écran « Informations sur le prestataire » : récapitulatif lisible du profil.
class ProviderInfoScreen extends StatelessWidget {
  const ProviderInfoScreen({super.key});

  static const _serviceLabels = {
    'depannage': '🔧 Dépannage',
    'pneu': '🔩 Pneu',
    'remorquage': '🚛 Remorquage',
    'electricite': '⚡ Électricité',
  };

  @override
  Widget build(BuildContext context) {
    final ProviderModel? p = context.watch<AuthController>().provider;

    return Scaffold(
      appBar: AppBar(title: const Text('Informations prestataire')),
      body: p == null
          ? const Center(child: Text('Profil indisponible'))
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Center(
                  child: Column(
                    children: [
                      CircleAvatar(
                        radius: 44,
                        backgroundImage: (p.photoUrl != null &&
                                p.photoUrl!.isNotEmpty)
                            ? NetworkImage(p.photoUrl!)
                            : null,
                        child: (p.photoUrl == null || p.photoUrl!.isEmpty)
                            ? Text(
                                p.name.isNotEmpty
                                    ? p.name[0].toUpperCase()
                                    : '?',
                                style: const TextStyle(fontSize: 32))
                            : null,
                      ),
                      const SizedBox(height: 12),
                      Text(p.name,
                          style: const TextStyle(
                              fontSize: 20, fontWeight: FontWeight.w800)),
                      const SizedBox(height: 4),
                      _VerifiedBadge(verified: p.isVerified),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                _Row(icon: Icons.phone, label: 'Téléphone', value: p.phone),
                _Row(
                    icon: Icons.circle,
                    label: 'Disponibilité',
                    value: p.isAvailable ? 'En ligne' : 'Hors ligne',
                    valueColor: p.isAvailable ? Colors.green : Colors.grey),
                _Row(
                    icon: Icons.star,
                    label: 'Note',
                    value: p.ratingCount == 0
                        ? 'Pas encore noté'
                        : '${p.rating.toStringAsFixed(1)} (${p.ratingCount})'),
                _Row(
                    icon: Icons.check_circle_outline,
                    label: 'Interventions',
                    value: '${p.totalInterventions}'),
                const SizedBox(height: 16),
                const Text('Services proposés',
                    style: TextStyle(fontWeight: FontWeight.w700)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: p.serviceTypes.isEmpty
                      ? [const Text('Aucun service renseigné')]
                      : p.serviceTypes
                          .map((s) => Chip(
                              label: Text(_serviceLabels[s] ?? s)))
                          .toList(),
                ),
                const SizedBox(height: 16),
                const Text('Documents',
                    style: TextStyle(fontWeight: FontWeight.w700)),
                const SizedBox(height: 8),
                _Row(
                    icon: Icons.badge,
                    label: "Pièce d'identité",
                    value: (p.idCardUrl?.isNotEmpty ?? false)
                        ? 'Soumis ✅'
                        : 'Non soumis'),
                _Row(
                    icon: Icons.workspace_premium,
                    label: 'Licence pro',
                    value: (p.proLicenseUrl?.isNotEmpty ?? false)
                        ? 'Soumis ✅'
                        : 'Non soumis'),
              ],
            ),
    );
  }
}

class _VerifiedBadge extends StatelessWidget {
  final bool verified;
  const _VerifiedBadge({required this.verified});
  @override
  Widget build(BuildContext context) {
    final c = verified ? Colors.green : Colors.orange;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(verified ? '✅ Vérifié' : '⏳ En attente de vérification',
          style: TextStyle(color: c, fontWeight: FontWeight.w600)),
    );
  }
}

class _Row extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color? valueColor;
  const _Row(
      {required this.icon,
      required this.label,
      required this.value,
      this.valueColor});
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Icon(icon, size: 20, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 14),
          Text(label, style: const TextStyle(color: Colors.grey)),
          const Spacer(),
          Flexible(
            child: Text(value,
                textAlign: TextAlign.right,
                style: TextStyle(
                    fontWeight: FontWeight.w600, color: valueColor)),
          ),
        ],
      ),
    );
  }
}
