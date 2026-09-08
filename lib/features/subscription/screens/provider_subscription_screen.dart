import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/services/api_service.dart';

/// Écran "Recharger mon compte" — prestataire VigiRoutes Pro.
class ProviderSubscriptionScreen extends StatefulWidget {
  const ProviderSubscriptionScreen({super.key});

  @override
  State<ProviderSubscriptionScreen> createState() =>
      _ProviderSubscriptionScreenState();
}

class _ProviderSubscriptionScreenState
    extends State<ProviderSubscriptionScreen> {
  static const int _minAmount = AppConstants.minRecharge;
  static const List<int> _presets = [2000, 5000, 15000];

  int _selectedPreset = 2000;
  final _customAmountCtrl = TextEditingController();
  bool _useCustomAmount = false;

  String _operatorCode = 'ORANGE_MONEY_CI';
  final _phoneCtrl = TextEditingController();
  final _otpCtrl   = TextEditingController();

  bool _loading    = true;
  bool _recharging = false;
  Map<String, dynamic>? _currentSubscription;

  @override
  void initState() {
    super.initState();
    _loadCurrent();
  }

  @override
  void dispose() {
    _customAmountCtrl.dispose();
    _phoneCtrl.dispose();
    _otpCtrl.dispose();
    super.dispose();
  }

  // ── helpers ────────────────────────────────────────────────────────────

  bool get _needsOtp => _operatorCode == 'ORANGE_MONEY_CI';

  int? get _amountToCharge {
    if (_useCustomAmount) {
      return int.tryParse(_customAmountCtrl.text.trim().replaceAll(' ', ''));
    }
    return _selectedPreset;
  }

  /// Label lisible de l'opérateur sélectionné (sans emoji).
  String _operatorLabel() {
    switch (_operatorCode) {
      case 'ORANGE_MONEY_CI': return 'Orange Money';
      case 'MTN_MONEY_CI':    return 'MTN MoMo';
      case 'WAVE_MONEY_CI':   return 'Wave';
      default:                return 'Mobile Money';
    }
  }

  double _num(dynamic v) {
    if (v is num) return v.toDouble();
    return double.tryParse(v?.toString() ?? '') ?? 0;
  }

  void _snack(String msg, {Color? color}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: color),
    );
  }

  String _dioError(Object e) {
    if (e is DioException) {
      final d = e.response?.data;
      if (d is Map && d['message'] is String) return d['message'] as String;
    }
    return 'Une erreur est survenue. Réessayez.';
  }

  // ── chargement ─────────────────────────────────────────────────────────

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

  // ── polling statut ─────────────────────────────────────────────────────

  Future<String> _pollStatus(String reference) async {
    for (int i = 0; i < 20; i++) {
      await Future.delayed(const Duration(seconds: 3));
      try {
        final res = await ApiService.instance.getProviderRechargeStatus(reference);
        final status = res['status'] as String? ?? 'pending';
        if (status == 'success' || status == 'failed') return status;
      } catch (_) {}
    }
    return 'timeout';
  }

  // ── recharge ───────────────────────────────────────────────────────────

  Future<void> _recharge() async {
    final amount = _amountToCharge;
    if (amount == null || amount < _minAmount) {
      _snack('Le montant minimum est de $_minAmount FCFA.');
      return;
    }
    final phone = _phoneCtrl.text.trim();
    if (phone.length < 8) {
      _snack('Entrez le numéro Mobile Money qui effectue le paiement.');
      return;
    }
    if (_needsOtp && _otpCtrl.text.trim().isEmpty) {
      _snack('Un code OTP Orange Money est requis.');
      return;
    }

    setState(() => _recharging = true);
    String? reference;

    try {
      final init = await ApiService.instance.initiateProviderRecharge(
        amount:       amount,
        operatorCode: _operatorCode,
        payerPhone:   phone,
        otp:          _needsOtp ? _otpCtrl.text.trim() : null,
      );
      reference = init['reference'] as String?;

      final paymentUrl = init['payment_url'] as String?;
      if (paymentUrl != null && paymentUrl.isNotEmpty) {
        final uri = Uri.tryParse(paymentUrl);
        if (uri != null) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
        }
      }
    } catch (e) {
      setState(() => _recharging = false);
      _snack(_dioError(e), color: AppColors.error);
      return;
    }

    if (reference == null) {
      setState(() => _recharging = false);
      _snack('Réponse inattendue du serveur.', color: AppColors.error);
      return;
    }

    final status = await _pollStatus(reference);
    if (!mounted) return;
    setState(() => _recharging = false);

    if (status == 'success') {
      _otpCtrl.clear();
      _snack('Recharge confirmée ! Vos crédits sont disponibles.',
          color: AppColors.success);
      await _loadCurrent();
    } else if (status == 'failed') {
      _snack('Le paiement a échoué ou a été refusé.', color: AppColors.error);
    } else {
      _snack('Paiement en attente. Votre solde se mettra à jour sous peu.');
      await _loadCurrent();
    }
  }

  // ── build ──────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Recharger mon compte')),
      // Bouton fixé en bas — toujours visible
      bottomNavigationBar: _loading || _recharging
          ? null
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
                child: SizedBox(
                  height: 52,
                  child: ElevatedButton(
                    onPressed: _recharge,
                    child: Text('Recharger via ${_operatorLabel()}'),
                  ),
                ),
              ),
            ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Stack(
              children: [
                SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [

                      // ── Carte solde (toujours visible en haut) ────────
                      _BalanceCard(
                        subscription: _currentSubscription,
                        numHelper: _num,
                      ),
                      const SizedBox(height: 24),

                      _CreditExplanationCard(),
                      const SizedBox(height: 24),

                      // ── Montant ──────────────────────────────────────
                      const Text(
                        'Choisissez un montant',
                        style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 12),

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
                                '$amount F',
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

                      // ── Opérateur ─────────────────────────────────────
                      const Text(
                        'Opérateur Mobile Money',
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: AppConstants.operators.map((m) {
                          final code = m['code'] as String;
                          final selected = _operatorCode == code;
                          return GestureDetector(
                            onTap: () => setState(() => _operatorCode = code),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 150),
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                              decoration: BoxDecoration(
                                color: selected ? AppColors.primary : Colors.white,
                                border: Border.all(
                                    color: selected ? AppColors.primary : AppColors.border),
                                borderRadius: BorderRadius.circular(24),
                              ),
                              child: Text(
                                m['label'] as String,
                                style: TextStyle(
                                  color: selected ? Colors.white : AppColors.textPrimary,
                                  fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),

                      const SizedBox(height: 18),

                      // ── Numéro ────────────────────────────────────────
                      const Text(
                        'Numéro Mobile Money',
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _phoneCtrl,
                        keyboardType: TextInputType.phone,
                        decoration: InputDecoration(
                          hintText: 'Ex : 07 00 00 00 00',
                          filled: true,
                          fillColor: Colors.white,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: const BorderSide(color: AppColors.border),
                          ),
                        ),
                      ),

                      // ── OTP Orange Money ──────────────────────────────
                      if (_needsOtp) ...[
                        const SizedBox(height: 18),
                        const Text(
                          'Code OTP Orange Money',
                          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: _otpCtrl,
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            hintText: 'Code reçu sur votre téléphone',
                            filled: true,
                            fillColor: Colors.white,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: const BorderSide(color: AppColors.border),
                            ),
                          ),
                        ),
                        const Padding(
                          padding: EdgeInsets.only(top: 6, left: 4),
                          child: Text(
                            'Générez le code depuis le menu Orange Money de votre téléphone.',
                            style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                          ),
                        ),
                      ],

                      // ── Info Wave ─────────────────────────────────────
                      if (_operatorCode == 'WAVE_MONEY_CI') ...[
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFE3F2FD),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFF90CAF9)),
                          ),
                          child: const Row(
                            children: [
                              Text('🔵', style: TextStyle(fontSize: 18)),
                              SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  'Vous serez redirigé vers l\'app Wave pour confirmer le paiement.',
                                  style: TextStyle(fontSize: 13, color: Color(0xFF1565C0)),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],

                      // Espace pour le bouton fixé en bas
                      const SizedBox(height: 20),
                    ],
                  ),
                ),

                // ── Overlay chargement ────────────────────────────────
                if (_recharging)
                  Positioned.fill(
                    child: Container(
                      color: Colors.black.withValues(alpha: 0.45),
                      child: Center(
                        child: Container(
                          margin: const EdgeInsets.symmetric(horizontal: 40),
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const CircularProgressIndicator(),
                              const SizedBox(height: 16),
                              const Text(
                                'Paiement en cours…',
                                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                _operatorCode == 'WAVE_MONEY_CI'
                                    ? 'Confirmez le paiement dans l\'app Wave, puis revenez ici.'
                                    : 'Validez la demande sur votre téléphone si nécessaire, puis patientez.',
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                    color: AppColors.textSecondary, fontSize: 13),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
    );
  }
}

// ── Widget : carte solde (identique au Store) ────────────────────────────────

class _BalanceCard extends StatelessWidget {
  final Map<String, dynamic>? subscription;
  final double Function(dynamic) numHelper;

  const _BalanceCard({required this.subscription, required this.numHelper});

  @override
  Widget build(BuildContext context) {
    final sub     = subscription?['subscription'] as Map<String, dynamic>?;
    final percent = (subscription?['credit_percent'] as num?)?.toInt() ?? 0;

    if (sub == null) {
      // Pas encore de crédit
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.primaryLight,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
        ),
        child: const Row(
          children: [
            Icon(Icons.info_outline, color: AppColors.primary),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                'Aucun crédit actif. Effectuez votre première recharge pour recevoir des missions.',
                style: TextStyle(color: AppColors.primary, fontSize: 13),
              ),
            ),
          ],
        ),
      );
    }

    final balance = numHelper(sub['credit_balance']);
    final initial = numHelper(sub['credit_initial']);
    final floor   = numHelper(sub['credit_floor']);
    final status  = sub['status'] as String? ?? 'active';

    final color = status == 'exhausted'
        ? AppColors.error
        : percent > 50
            ? AppColors.success
            : percent > 20
                ? Colors.orange
                : AppColors.error;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                status == 'exhausted'
                    ? Icons.warning_rounded
                    : Icons.account_balance_wallet_rounded,
                color: color,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                status == 'exhausted' ? 'Crédits épuisés' : 'Solde actuel',
                style: TextStyle(fontWeight: FontWeight.w600, color: color),
              ),
              const Spacer(),
              Text(
                '${balance.toStringAsFixed(0)} F',
                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 18),
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
              Text(
                'Rechargé : ${initial.toStringAsFixed(0)} F',
                style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
              ),
              Text(
                'Seuil : ${floor.toStringAsFixed(0)} F',
                style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            '$percent% restant',
            style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.w600),
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
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('💡', style: TextStyle(fontSize: 16)),
              SizedBox(width: 8),
              Text(
                'Comment fonctionne la recharge ?',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
              ),
            ],
          ),
          SizedBox(height: 8),
          Text(
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
