import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/services/api_service.dart';

/// Écran "Recharger mon compte".
///
/// REMPLACE COMPLÈTEMENT l'ancien système de formules figées
/// (mensuel/trimestriel/annuel). Le prestataire choisit désormais un
/// montant libre (paliers suggérés ou saisie personnalisée, minimum
/// 2000 FCFA), qui devient son crédit de dépannage. 18% du montant de
/// chaque intervention terminée est déduit de ce crédit ; quand le solde
/// atteint 18% du montant initial rechargé, le compte est épuisé et le
/// prestataire ne reçoit plus de nouvelles demandes tant qu'il n'a pas
/// rechargé à nouveau.
class ProviderSubscriptionScreen extends StatefulWidget {
  const ProviderSubscriptionScreen({super.key});

  @override
  State<ProviderSubscriptionScreen> createState() =>
      _ProviderSubscriptionScreenState();
}

class _ProviderSubscriptionScreenState
    extends State<ProviderSubscriptionScreen> {
  static const double _minAmount = 2000;
  static const List<double> _presets = [2000, 5000, 15000];

  double? _selectedPreset = 2000;
  final _customAmountCtrl = TextEditingController();
  bool _useCustomAmount = false;

  String _paymentMethod = 'orange_money';
  bool _loading = true;
  bool _recharging = false;
  Map<String, dynamic>? _currentSubscription;

  final List<Map<String, String>> _paymentMethods = const [
    {'id': 'orange_money', 'label': 'Orange Money', 'icon': '🟠'},
    {'id': 'wave',         'label': 'Wave',          'icon': '🔵'},
    {'id': 'mtn_money',    'label': 'MTN Money',     'icon': '🟡'},
    {'id': 'moov_money',   'label': 'Moov Money',    'icon': '🟢'},
  ];

  @override
  void initState() {
    super.initState();
    _loadCurrent();
  }

  @override
  void dispose() {
    _customAmountCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadCurrent() async {
    setState(() => _loading = true);
    try {
      final sub = await ApiService.instance.getProviderCurrentSubscription();
      if (mounted) setState(() => _currentSubscription = sub);
    } catch (e) {
      debugPrint('[ProviderSubscriptionScreen] $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  double? get _amountToCharge {
    if (_useCustomAmount) {
      final v = double.tryParse(_customAmountCtrl.text.trim().replaceAll(' ', ''));
      return v;
    }
    return _selectedPreset;
  }

  Future<void> _recharge() async {
    final amount = _amountToCharge;
    if (amount == null || amount < _minAmount) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Le montant minimum est de ${_minAmount.toStringAsFixed(0)} FCFA.')));
      return;
    }

    setState(() => _recharging = true);
    try {
      // Paiement Wave/Orange Money/etc. : SIMULÉ pour l'instant, pas
      // d'intégration réelle de passerelle de paiement à ce stade.
      await ApiService.instance.rechargeProvider(
        amount: amount,
        paymentMethod: _paymentMethod,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Recharge effectuée ! Vos crédits sont disponibles.'),
          backgroundColor: AppColors.success,
        ));
        await _loadCurrent();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Erreur lors de la recharge : $e'),
          backgroundColor: AppColors.error,
        ));
      }
    } finally {
      if (mounted) setState(() => _recharging = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Recharger mon compte')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (_currentSubscription?['has_subscription'] == true) ...[
                    _ActiveCreditCard(data: _currentSubscription!),
                    const SizedBox(height: 24),
                  ],

                  _CreditExplanationCard(),
                  const SizedBox(height: 24),

                  const Text(
                    'Choisissez un montant',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 12),

                  // ── Paliers proposés ──────────────────────────────────
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: _presets.map((amount) {
                      final selected = !_useCustomAmount && _selectedPreset == amount;
                      return GestureDetector(
                        onTap: () => setState(() {
                          _useCustomAmount = false;
                          _selectedPreset = amount;
                        }),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                          decoration: BoxDecoration(
                            color: selected ? AppColors.primary : Colors.white,
                            border: Border.all(
                                color: selected ? AppColors.primary : AppColors.border,
                                width: selected ? 2 : 1),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Text(
                            '${amount.toStringAsFixed(0)} F',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 16,
                              color: selected ? Colors.white : AppColors.textPrimary,
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),

                  const SizedBox(height: 16),

                  // ── Montant personnalisé ──────────────────────────────
                  GestureDetector(
                    onTap: () => setState(() => _useCustomAmount = true),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                      decoration: BoxDecoration(
                        color: _useCustomAmount ? AppColors.primaryLight : Colors.white,
                        border: Border.all(
                            color: _useCustomAmount ? AppColors.primary : AppColors.border,
                            width: _useCustomAmount ? 2 : 1),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: TextField(
                        controller: _customAmountCtrl,
                        keyboardType: const TextInputType.numberWithOptions(decimal: false),
                        onTap: () => setState(() => _useCustomAmount = true),
                        onChanged: (_) => setState(() => _useCustomAmount = true),
                        decoration: const InputDecoration(
                          labelText: 'Autre montant',
                          suffixText: 'FCFA',
                          border: InputBorder.none,
                        ),
                      ),
                    ),
                  ),
                  const Padding(
                    padding: EdgeInsets.only(top: 6, left: 4),
                    child: Text(
                      'Minimum 2 000 FCFA',
                      style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
                    ),
                  ),

                  const SizedBox(height: 28),

                  const Text(
                    'Mode de paiement',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _paymentMethods
                        .map((m) => _PaymentChip(
                              method: m,
                              selected: _paymentMethod == m['id'],
                              onTap: () => setState(() => _paymentMethod = m['id']!),
                            ))
                        .toList(),
                  ),

                  const SizedBox(height: 32),

                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      onPressed: _recharging ? null : _recharge,
                      child: _recharging
                          ? const CircularProgressIndicator(color: Colors.white)
                          : Text(
                              'Recharger via ${_paymentMethods.firstWhere((m) => m['id'] == _paymentMethod)['label']}',
                            ),
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
    );
  }
}

// ── Widget : carte crédit actif ──────────────────────────────────────────────

class _ActiveCreditCard extends StatelessWidget {
  final Map<String, dynamic> data;
  const _ActiveCreditCard({required this.data});

  @override
  Widget build(BuildContext context) {
    final sub = data['subscription'] as Map<String, dynamic>?;
    if (sub == null) return const SizedBox.shrink();

    final creditInitial = (sub['credit_initial'] as num?)?.toDouble() ?? 0;
    final creditBalance = (sub['credit_balance'] as num?)?.toDouble() ?? 0;
    final creditFloor   = (sub['credit_floor'] as num?)?.toDouble() ?? 0;
    final percent       = data['credit_percent'] as int? ?? 0;
    final status        = sub['status'] as String? ?? 'active';

    final color = status == 'exhausted'
        ? AppColors.error
        : percent > 50
            ? AppColors.success
            : Colors.orange;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                status == 'exhausted' ? Icons.warning_rounded : Icons.check_circle_rounded,
                color: color,
              ),
              const SizedBox(width: 8),
              Text(
                status == 'exhausted' ? 'Crédits épuisés' : 'Crédit actif',
                style: TextStyle(fontWeight: FontWeight.w700, color: color, fontSize: 15),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: (percent / 100).clamp(0, 1),
              minHeight: 10,
              backgroundColor: AppColors.border,
              valueColor: AlwaysStoppedAnimation<Color>(color),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Solde : ${creditBalance.toStringAsFixed(0)} F',
                  style: const TextStyle(fontWeight: FontWeight.w600)),
              Text('$percent% restant',
                  style: TextStyle(color: color, fontWeight: FontWeight.w600)),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Rechargé : ${creditInitial.toStringAsFixed(0)} F  ·  Seuil : ${creditFloor.toStringAsFixed(0)} F',
            style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

// ── Widget : explication du système de crédits ───────────────────────────────

class _CreditExplanationCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.primaryLight,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('💡', style: TextStyle(fontSize: 16)),
              const SizedBox(width: 8),
              const Text(
                'Comment fonctionne la recharge ?',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            '• Rechargez le montant de votre choix (minimum 2 000 F)\n'
            '• Après chaque intervention terminée : 18% du montant payé par le client est déduit de votre solde\n'
            '• Quand le solde atteint 18% du montant rechargé, votre compte est épuisé\n'
            '• Rechargez à nouveau à tout moment pour continuer à recevoir des missions',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 13, height: 1.6),
          ),
        ],
      ),
    );
  }
}

// ── Widget : chip mode de paiement ───────────────────────────────────────────

class _PaymentChip extends StatelessWidget {
  final Map<String, String> method;
  final bool selected;
  final VoidCallback onTap;

  const _PaymentChip({required this.method, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? AppColors.primary : Colors.white,
          border: Border.all(color: selected ? AppColors.primary : AppColors.border),
          borderRadius: BorderRadius.circular(24),
        ),
        child: Text(
          '${method['icon']} ${method['label']}',
          style: TextStyle(
            color: selected ? Colors.white : AppColors.textPrimary,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
            fontSize: 13,
          ),
        ),
      ),
    );
  }
}
