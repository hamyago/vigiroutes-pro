import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/services/api_service.dart';
import '../../auth/controllers/auth_controller.dart';

/// Modèle d'un plan d'abonnement prestataire reçu depuis l'API.
class ProSubscriptionPlan {
  final String id;
  final String period;
  final String label;
  final int priceFcfa;
  final int deductionPercentPerOrder;
  final int creditFloorPercent;
  final double deductionPerOrderFcfa;
  final double floorAmountFcfa;

  const ProSubscriptionPlan({
    required this.id,
    required this.period,
    required this.label,
    required this.priceFcfa,
    required this.deductionPercentPerOrder,
    required this.creditFloorPercent,
    required this.deductionPerOrderFcfa,
    required this.floorAmountFcfa,
  });

  factory ProSubscriptionPlan.fromJson(Map<String, dynamic> json) =>
      ProSubscriptionPlan(
        id: json['id'] as String,
        period: json['period'] as String,
        label: json['label'] as String,
        priceFcfa: (json['price_fcfa'] as num).toInt(),
        deductionPercentPerOrder:
            (json['deduction_percent_per_order'] as num).toInt(),
        creditFloorPercent: (json['credit_floor_percent'] as num).toInt(),
        deductionPerOrderFcfa:
            (json['deduction_per_order_fcfa'] as num?)?.toDouble() ??
                (json['price_fcfa'] as num).toDouble() *
                    (json['deduction_percent_per_order'] as num).toDouble() /
                    100,
        floorAmountFcfa:
            (json['floor_amount_fcfa'] as num?)?.toDouble() ??
                (json['price_fcfa'] as num).toDouble() *
                    (json['credit_floor_percent'] as num).toDouble() /
                    100,
      );

  String get periodLabel => switch (period) {
        'monthly'   => 'Mensuel',
        'quarterly' => 'Trimestriel',
        'annual'    => 'Annuel',
        _           => period,
      };

  /// Nombre estimé de courses avant épuisement
  int get estimatedOrders {
    final usable = priceFcfa - floorAmountFcfa;
    if (deductionPerOrderFcfa <= 0) return 0;
    return (usable / deductionPerOrderFcfa).floor();
  }
}

class ProviderSubscriptionScreen extends StatefulWidget {
  const ProviderSubscriptionScreen({super.key});

  @override
  State<ProviderSubscriptionScreen> createState() =>
      _ProviderSubscriptionScreenState();
}

class _ProviderSubscriptionScreenState
    extends State<ProviderSubscriptionScreen> {
  List<ProSubscriptionPlan> _plans = [];
  String? _selectedPlanId;
  String _paymentMethod = 'orange_money';
  bool _loadingPlans = true;
  bool _loadingSubscribe = false;
  Map<String, dynamic>? _currentSubscription;

  final List<Map<String, String>> _paymentMethods = [
    {'id': 'orange_money',  'label': 'Orange Money',  'icon': '🟠'},
    {'id': 'wave',          'label': 'Wave',           'icon': '🔵'},
    {'id': 'mtn_money',     'label': 'MTN Money',      'icon': '🟡'},
    {'id': 'moov_money',    'label': 'Moov Money',     'icon': '🟢'},
  ];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _loadingPlans = true);
    try {
      // Charger les plans et l'abonnement actuel en parallèle
      final results = await Future.wait([
        ApiService.instance.getProviderSubscriptionPlans(),
        ApiService.instance.getProviderCurrentSubscription(),
      ]);

      final plansData = results[0] as List<dynamic>;
      final subData = results[1] as Map<String, dynamic>?;

      setState(() {
        _plans = plansData
            .map((p) => ProSubscriptionPlan.fromJson(p as Map<String, dynamic>))
            .toList();
        _currentSubscription = subData;
        if (_plans.isNotEmpty) _selectedPlanId = _plans.first.id;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur chargement : $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _loadingPlans = false);
    }
  }

  Future<void> _subscribe() async {
    if (_selectedPlanId == null) return;
    setState(() => _loadingSubscribe = true);
    try {
      await ApiService.instance.subscribeProvider({
        'plan_id':        _selectedPlanId,
        'payment_method': _paymentMethod,
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Abonnement activé ! Vos crédits sont disponibles.'),
            backgroundColor: AppColors.success,
          ),
        );
        await _loadData(); // Rafraîchir
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur : $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _loadingSubscribe = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Abonnement VigiRoutes Pro')),
      body: _loadingPlans
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Abonnement actif ──────────────────────────────────
                  if (_currentSubscription?['has_subscription'] == true) ...[
                    _ActiveSubscriptionCard(data: _currentSubscription!),
                    const SizedBox(height: 24),
                  ],

                  // ── Explication système de crédits ────────────────────
                  _CreditExplanationCard(),
                  const SizedBox(height: 24),

                  // ── Titre section plans ───────────────────────────────
                  const Text(
                    'Choisissez votre formule',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 12),

                  // ── Plans d'abonnement ────────────────────────────────
                  if (_plans.isEmpty)
                    const Center(
                      child: Text(
                        'Aucun plan disponible pour votre secteur.',
                        style: TextStyle(color: AppColors.textSecondary),
                      ),
                    )
                  else
                    ..._plans.map(
                      (plan) => _PlanCard(
                        plan: plan,
                        selected: _selectedPlanId == plan.id,
                        onTap: () =>
                            setState(() => _selectedPlanId = plan.id),
                      ),
                    ),

                  const SizedBox(height: 24),

                  // ── Mode de paiement ──────────────────────────────────
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
                              onTap: () =>
                                  setState(() => _paymentMethod = m['id']!),
                            ))
                        .toList(),
                  ),

                  const SizedBox(height: 32),

                  // ── Bouton souscrire ──────────────────────────────────
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      onPressed:
                          (_loadingSubscribe || _selectedPlanId == null)
                              ? null
                              : _subscribe,
                      child: _loadingSubscribe
                          ? const CircularProgressIndicator(
                              color: Colors.white)
                          : Text(
                              'Souscrire via ${_paymentMethods.firstWhere((m) => m['id'] == _paymentMethod)['label']}',
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

// ── Widget : carte abonnement actif ──────────────────────────────────────────

class _ActiveSubscriptionCard extends StatelessWidget {
  final Map<String, dynamic> data;
  const _ActiveSubscriptionCard({required this.data});

  @override
  Widget build(BuildContext context) {
    final sub = data['subscription'] as Map<String, dynamic>?;
    if (sub == null) return const SizedBox.shrink();

    final creditInitial = (sub['credit_initial'] as num?)?.toDouble() ?? 0;
    final creditBalance = (sub['credit_balance'] as num?)?.toDouble() ?? 0;
    final creditFloor   = (sub['credit_floor'] as num?)?.toDouble() ?? 0;
    final percent       = data['credit_percent'] as int? ?? 0;
    final status        = sub['status'] as String? ?? 'active';
    final expiresAt     = sub['expires_at'] != null
        ? DateTime.tryParse(sub['expires_at'] as String)
        : null;

    final usableBalance = creditBalance - creditFloor;
    final color = status == 'exhausted'
        ? AppColors.error
        : percent > 50
            ? AppColors.success
            : Colors.orange;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                status == 'exhausted'
                    ? Icons.warning_rounded
                    : Icons.check_circle_rounded,
                color: color,
              ),
              const SizedBox(width: 8),
              Text(
                status == 'exhausted'
                    ? 'Crédits épuisés'
                    : 'Abonnement actif',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: color,
                  fontSize: 15,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Barre de progression des crédits
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: percent / 100,
              minHeight: 10,
              backgroundColor: AppColors.border,
              valueColor: AlwaysStoppedAnimation<Color>(color),
            ),
          ),
          const SizedBox(height: 8),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Solde : ${creditBalance.toStringAsFixed(0)} F',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              Text(
                '$percent% restant',
                style: TextStyle(color: color, fontWeight: FontWeight.w600),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Initial : ${creditInitial.toStringAsFixed(0)} F  ·  Seuil : ${creditFloor.toStringAsFixed(0)} F',
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 12,
            ),
          ),
          if (expiresAt != null) ...[
            const SizedBox(height: 4),
            Text(
              'Expire le ${expiresAt.day}/${expiresAt.month}/${expiresAt.year}',
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 12,
              ),
            ),
          ],
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
        border: Border.all(color: AppColors.primary.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('💡', style: TextStyle(fontSize: 16)),
              const SizedBox(width: 8),
              const Text(
                'Comment fonctionnent les crédits ?',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '• Votre abonnement = crédit de dépannage\n'
            '• Après chaque course effectuée : 18% du montant initial est déduit\n'
            '• Quand le solde atteint le seuil (18% du montant initial), l\'abonnement est épuisé\n'
            '• Renouvelez pour continuer à recevoir des missions',
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 13,
              height: 1.6,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Widget : carte plan d'abonnement ─────────────────────────────────────────

class _PlanCard extends StatelessWidget {
  final ProSubscriptionPlan plan;
  final bool selected;
  final VoidCallback onTap;

  const _PlanCard({
    required this.plan,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: selected ? AppColors.primaryLight : Colors.white,
          border: Border.all(
            color: selected ? AppColors.primary : AppColors.border,
            width: selected ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Radio<String>(
                  value: plan.id,
                  groupValue: selected ? plan.id : '',
                  onChanged: (_) => onTap(),
                  activeColor: AppColors.primary,
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        plan.periodLabel,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 16,
                        ),
                      ),
                      Text(
                        plan.label,
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  '${plan.priceFcfa} F',
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    color: AppColors.primary,
                    fontSize: 18,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Divider(height: 1),
            const SizedBox(height: 10),
            // Détails crédits
            Row(
              children: [
                _CreditInfo(
                  icon: '⬇️',
                  label: 'Déduction / course',
                  value: '${plan.deductionPerOrderFcfa.toStringAsFixed(0)} F (${plan.deductionPercentPerOrder}%)',
                ),
                const SizedBox(width: 16),
                _CreditInfo(
                  icon: '🔋',
                  label: '~${plan.estimatedOrders} courses',
                  value: 'avant épuisement',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _CreditInfo extends StatelessWidget {
  final String icon;
  final String label;
  final String value;

  const _CreditInfo({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$icon $label',
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 11,
            ),
          ),
          Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
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

  const _PaymentChip({
    required this.method,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? AppColors.primary : Colors.white,
          border: Border.all(
            color: selected ? AppColors.primary : AppColors.border,
          ),
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
