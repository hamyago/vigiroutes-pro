import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/models/models.dart';
import '../../../core/services/api_service.dart';
import '../../auth/controllers/auth_controller.dart';

class ProviderProfileScreen extends StatelessWidget {
  const ProviderProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth     = context.watch<AuthController>();
    final provider = auth.provider;
    final uid      = auth.provider?.id ?? '';

    return Scaffold(
      appBar: AppBar(title: const Text('Mon profil')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // Avatar
          _PhotoAvatar(uid: uid, photoUrl: provider?.photoUrl),
          const SizedBox(height: 24),

          // Infos de base
          _InfoCard(provider: provider),
          const SizedBox(height: 16),

          // KYC
          _KycCard(provider: provider, uid: uid),
          const SizedBox(height: 16),

          // Stats
          _StatsCard(provider: provider),
          const SizedBox(height: 16),

          // Abonnement (crédits de dépannage)
          _SubscriptionCard(onTap: () => context.push('/provider/subscription')),
          const SizedBox(height: 16),

          // ── Mes tarifs ────────────────────────────────────────────
          _RatesCard(onTap: () => context.push('/provider/rates')),
          const SizedBox(height: 24),

          // Déconnexion
          SizedBox(
            width: double.infinity,
            height: 48,
            child: OutlinedButton(
              onPressed: () async => await auth.signOut(),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.error,
                side: const BorderSide(color: AppColors.error),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('Se déconnecter'),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Rates Card ────────────────────────────────────────────────────────────────

class _RatesCard extends StatelessWidget {
  final VoidCallback onTap;
  const _RatesCard({required this.onTap});

  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 8,
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: AppColors.primaryLight,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Center(
                  child: Text('💰', style: TextStyle(fontSize: 24)),
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Mes tarifs',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    Text(
                      'Personnaliser mes prix par service',
                      style: TextStyle(
                          color: AppColors.textSecondary, fontSize: 12),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: AppColors.textMuted),
            ],
          ),
        ),
      );
}

// ── Photo Avatar ──────────────────────────────────────────────────────────────

class _PhotoAvatar extends StatefulWidget {
  final String uid;
  final String? photoUrl;
  const _PhotoAvatar({required this.uid, this.photoUrl});

  @override
  State<_PhotoAvatar> createState() => _PhotoAvatarState();
}

class _PhotoAvatarState extends State<_PhotoAvatar> {
  bool _loading  = false;
  int  _cacheKey = 0;

  Future<void> _pickPhoto() async {
    if (kIsWeb) return;
    final picker = ImagePicker();
    final file   = await picker.pickImage(
        source: ImageSource.gallery, imageQuality: 80);
    if (file == null) return;
    setState(() => _loading = true);
    try {
      await ApiService.instance.updateProvider({'photo_base64': 'photo'});
      setState(() => _cacheKey = DateTime.now().millisecondsSinceEpoch);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Photo mise à jour ✅'),
            backgroundColor: AppColors.success));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Erreur : $e')));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) => Center(
        child: GestureDetector(
          onTap: _pickPhoto,
          child: Stack(children: [
            CircleAvatar(
              radius: 52,
              backgroundColor: AppColors.primaryLight,
              backgroundImage: widget.photoUrl != null
                  ? NetworkImage('${widget.photoUrl}?v=$_cacheKey')
                  : null,
              child: widget.photoUrl == null
                  ? const Text('🔧', style: TextStyle(fontSize: 40))
                  : null,
            ),
            if (_loading)
              const Positioned.fill(
                child: CircleAvatar(
                    radius: 52,
                    backgroundColor: Colors.black26,
                    child: CircularProgressIndicator(color: Colors.white)),
              ),
            Positioned(
              bottom: 0,
              right: 0,
              child: Container(
                decoration: const BoxDecoration(
                    color: AppColors.primary, shape: BoxShape.circle),
                padding: const EdgeInsets.all(6),
                child: const Icon(Icons.camera_alt,
                    color: Colors.white, size: 16),
              ),
            ),
          ]),
        ),
      );
}

// ── Info Card ─────────────────────────────────────────────────────────────────

class _InfoCard extends StatelessWidget {
  final ProviderModel? provider;
  const _InfoCard({this.provider});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withValues(alpha: 0.05), blurRadius: 8)
          ],
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Informations',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
          const SizedBox(height: 12),
          _Row(icon: Icons.person_outline,
              label: 'Nom', value: provider?.name ?? '—'),
          _Row(icon: Icons.phone_outlined,
              label: 'Téléphone', value: provider?.phone ?? '—'),
          _Row(icon: Icons.star_outline,
              label: 'Note',
              value: '${(provider?.rating ?? 0.0).toStringAsFixed(1)} ★ (${provider?.ratingCount ?? 0} avis)'),
          _Row(
              icon: provider?.isAvailable == true
                  ? Icons.check_circle_outline
                  : Icons.cancel_outlined,
              label: 'Statut',
              value: provider?.isAvailable == true ? 'Disponible' : 'Indisponible',
              valueColor: provider?.isAvailable == true
                  ? AppColors.success : AppColors.error),
        ]),
      );
}

class _Row extends StatelessWidget {
  final IconData icon;
  final String   label;
  final String   value;
  final Color?   valueColor;
  const _Row({required this.icon, required this.label,
      required this.value, this.valueColor});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(children: [
          Icon(icon, size: 18, color: AppColors.textSecondary),
          const SizedBox(width: 8),
          Text('$label : ',
              style: const TextStyle(color: AppColors.textSecondary)),
          Expanded(
              child: Text(value,
                  style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: valueColor ?? AppColors.textPrimary))),
        ]),
      );
}

// ── KYC Card ──────────────────────────────────────────────────────────────────

class _KycCard extends StatefulWidget {
  final ProviderModel? provider;
  final String uid;
  const _KycCard({this.provider, required this.uid});

  @override
  State<_KycCard> createState() => _KycCardState();
}

class _KycCardState extends State<_KycCard> {
  bool _loading = false;

  Future<void> _uploadDoc(String field, String label) async {
    if (kIsWeb) return;
    final picker = ImagePicker();
    final file   = await picker.pickImage(
        source: ImageSource.gallery, imageQuality: 85);
    if (file == null) return;
    setState(() => _loading = true);
    try {
      await ApiService.instance
          .updateProvider({field: 'uploaded', 'field_name': field});
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('$label envoyé ✅'),
            backgroundColor: AppColors.success));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Erreur : $e')));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withValues(alpha: 0.05), blurRadius: 8)
          ],
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Documents KYC',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
          const SizedBox(height: 4),
          const Text('Soumettez vos documents pour être vérifié par Oyop MT.',
              style: TextStyle(
                  color: AppColors.textSecondary, fontSize: 13)),
          const SizedBox(height: 16),
          _DocRow(
            label: "Pièce d'identité",
            status: widget.provider?.photoUrl != null
                ? 'Soumis ✅' : 'Non soumis',
            statusColor: widget.provider?.photoUrl != null
                ? AppColors.success : AppColors.warning,
            onUpload: _loading
                ? null
                : () => _uploadDoc('id_card_url', "Pièce d'identité"),
          ),
          const SizedBox(height: 8),
          _DocRow(
            label: 'Licence professionnelle',
            status: widget.provider?.isVerified == true
                ? 'Vérifié ✅' : 'Non soumis',
            statusColor: widget.provider?.isVerified == true
                ? AppColors.success : AppColors.warning,
            onUpload: _loading
                ? null
                : () => _uploadDoc(
                    'pro_license_url', 'Licence professionnelle'),
          ),
        ]),
      );
}

class _DocRow extends StatelessWidget {
  final String    label;
  final String    status;
  final Color     statusColor;
  final VoidCallback? onUpload;
  const _DocRow({required this.label, required this.status,
      required this.statusColor, this.onUpload});

  @override
  Widget build(BuildContext context) => Row(children: [
        Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start,
                children: [
              Text(label,
                  style: const TextStyle(fontWeight: FontWeight.w600)),
              Text(status,
                  style: TextStyle(color: statusColor, fontSize: 12)),
            ])),
        TextButton.icon(
          onPressed: onUpload,
          icon: const Icon(Icons.upload_file, size: 16),
          label: const Text('Envoyer'),
        ),
      ]);
}

// ── Stats Card ────────────────────────────────────────────────────────────────

class _StatsCard extends StatelessWidget {
  final ProviderModel? provider;
  const _StatsCard({this.provider});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withValues(alpha: 0.05), blurRadius: 8)
          ],
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Statistiques',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
          const SizedBox(height: 12),
          Row(children: [
            _StatBox(
                label: 'Interventions',
                value: '${provider?.totalInterventions ?? 0}'),
            const SizedBox(width: 12),
            _StatBox(
                label: 'Gains totaux',
                value: '${(provider?.totalEarnings ?? 0).toStringAsFixed(0)} F'),
          ]),
        ]),
      );
}

class _StatBox extends StatelessWidget {
  final String label;
  final String value;
  const _StatBox({required this.label, required this.value});

  @override
  Widget build(BuildContext context) => Expanded(
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.primaryLight,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(children: [
            Text(value,
                style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 20,
                    color: AppColors.primary)),
            const SizedBox(height: 4),
            Text(label,
                style: const TextStyle(
                    color: AppColors.textSecondary, fontSize: 12)),
          ]),
        ),
      );
}

// ── Subscription Card ─────────────────────────────────────────────────────────

class _SubscriptionCard extends StatelessWidget {
  final VoidCallback onTap;
  const _SubscriptionCard({required this.onTap});

  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [AppColors.primary, AppColors.primaryDark],
            ),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(children: [
            const Text('💳', style: TextStyle(fontSize: 28)),
            const SizedBox(width: 12),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Mon abonnement',
                      style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 16)),
                  Text('Voir mes crédits et renouveler mon offre',
                      style: TextStyle(
                          color: Colors.white70, fontSize: 12)),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: Colors.white),
          ]),
        ),
      );
}
