import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/services/api_service.dart';

// ── Données opérateurs ───────────────────────────────────────────────────────

class _Operator {
  final String code;
  final String name;
  final String logoAsset;
  final bool needsOtp;
  final Color bgColor;

  const _Operator({
    required this.code,
    required this.name,
    required this.logoAsset,
    required this.needsOtp,
    required this.bgColor,
  });
}

final List<_Operator> _operators = [
  _Operator(
    code: 'ORANGE_MONEY_CI',
    name: 'Orange Money',
    needsOtp: true,
    bgColor: Colors.black,
    logoAsset: 'assets/images/logo_orange_money.jpg',
  ),
  _Operator(
    code: 'MTN_MONEY_CI',
    name: 'MTN MoMo',
    needsOtp: false,
    bgColor: const Color(0xFFFFCC00),
    logoAsset: 'assets/images/logo_mtn.png',
  ),
  _Operator(
    code: 'WAVE_MONEY_CI',
    name: 'Wave',
    needsOtp: false,
    bgColor: const Color(0xFF00BFFF),
    logoAsset: 'assets/images/logo_wave.png',
  ),
];

Widget _buildLogo(_Operator op) {
  return ClipRRect(
    borderRadius: BorderRadius.circular(12),
    child: Image.asset(
      op.logoAsset,
      width: 48,
      height: 48,
      fit: BoxFit.cover,
    ),
  );
}

// ── Écran principal ──────────────────────────────────────────────────────────

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

  _Operator _selectedOperator = _operators[0];
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

  int? get _amountToCharge {
    if (_useCustomAmount) {
      return int.tryParse(_customAmountCtrl.text.trim().replaceAll(' ', ''));
    }
    return _selectedPreset;
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

  Future<void> _loadCurrent() async {
    setState(() => _loading = true);
    try {
      final sub = await ApiService.instance.getProviderCurrentSubscription();
      if (mounted) setState(() => _currentSubscription = sub);
    } catch (_) {}
    finally {
      if (mounted) setState(() => _loading = false);
    }
  }

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

  void _showOperatorPicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => StatefulBuilder(
        builder: (ctx, setLocal) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40, height: 4,
                    decoration: BoxDecoration(
                      color: const Color(0xFFE5E7EB),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Sélectionnez votre\nmoyen de paiement',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: Colors.black,
                      ),
                    ),
                    GestureDetector(
                      onTap: () => Navigator.pop(ctx),
                      child: Container(
                        width: 36, height: 36,
                        decoration: const BoxDecoration(
                          color: Color(0xFFF0F1F5),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.close, size: 18, color: Colors.black87),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                ..._operators.map((op) {
                  final selected = _selectedOperator.code == op.code;
                  return Column(
                    children: [
                      InkWell(
                        onTap: () {
                          setState(() => _selectedOperator = op);
                          Navigator.pop(ctx);
                        },
                        borderRadius: BorderRadius.circular(12),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          child: Row(
                            children: [
                              _buildLogo(op),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Text(
                                  op.name,
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w500,
                                    color: Colors.black87,
                                  ),
                                ),
                              ),
                              Container(
                                width: 24, height: 24,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: selected ? AppColors.primary : const Color(0xFFD1D5DB),
                                    width: 2,
                                  ),
                                  color: selected ? AppColors.primary : Colors.transparent,
                                ),
                                child: selected
                                    ? const Center(
                                        child: Icon(Icons.circle, color: Colors.white, size: 10),
                                      )
                                    : null,
                              ),
                            ],
                          ),
                        ),
                      ),
                      if (op != _operators.last)
                        const Divider(height: 1, color: Color(0xFFF3F4F6)),
                    ],
                  );
                }),
              ],
            ),
          ),
        ),
      ),
    );
  }

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
    if (_selectedOperator.needsOtp && _otpCtrl.text.trim().isEmpty) {
      _snack('Un code OTP Orange Money est requis.');
      return;
    }

    setState(() => _recharging = true);
    String? reference;

    try {
      final init = await ApiService.instance.initiateProviderRecharge(
        amount:       amount,
        operatorCode: _selectedOperator.code,
        payerPhone:   phone,
        otp: _selectedOperator.needsOtp ? _otpCtrl.text.trim() : null,
      );
      reference = init['reference'] as String?;

      final paymentUrl = init['payment_url'] as String?;
      if (paymentUrl != null && paymentUrl.isNotEmpty) {
        final uri = Uri.tryParse(paymentUrl);
        if (uri != null) await launchUrl(uri, mode: LaunchMode.externalApplication);
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
      _snack('Recharge confirmée ! Vos crédits sont disponibles.', color: AppColors.success);
      await _loadCurrent();
    } else if (status == 'failed') {
      _snack('Le paiement a échoué ou a été refusé.', color: AppColors.error);
    } else {
      _snack('Paiement en attente. Votre solde se mettra à jour sous peu.');
      await _loadCurrent();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Recharger mon compte'),
        backgroundColor: Colors.white,
        foregroundColor: AppColors.textPrimary,
        elevation: 0.5,
      ),
      bottomNavigationBar: _loading || _recharging
          ? null
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
                child: SizedBox(
                  height: 52,
                  child: ElevatedButton(
                    onPressed: _recharge,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      elevation: 0,
                    ),
                    child: Text(
                      'Recharger via ${_selectedOperator.name}',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
              ),
            ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Stack(
              children: [
                SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [

                      // ── Carte solde ───────────────────────────────────
                      _buildBalanceCard(),
                      const SizedBox(height: 20),

                      // ── Explication ───────────────────────────────────
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: AppColors.primaryLight,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
                        ),
                        child: const Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(children: [
                              Icon(Icons.lightbulb_outline, color: AppColors.primary, size: 18),
                              SizedBox(width: 8),
                              Text('Comment fonctionne la recharge ?',
                                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: AppColors.primary)),
                            ]),
                            SizedBox(height: 8),
                            Text(
                              '• Rechargez le montant de votre choix (min. 2 000 F)\n'
                              '• 18% du montant de chaque intervention est déduit de votre solde\n'
                              '• Quand le solde atteint le seuil, votre compte est épuisé\n'
                              '• Rechargez à tout moment pour continuer à recevoir des missions',
                              style: TextStyle(color: AppColors.textSecondary, fontSize: 12, height: 1.7),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),

                      // ── Montant ───────────────────────────────────────
                      const Text('Choisissez un montant',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.black87)),
                      const SizedBox(height: 12),
                      Row(
                        children: _presets.map((amount) {
                          final selected = !_useCustomAmount && _selectedPreset == amount;
                          return Expanded(
                            child: GestureDetector(
                              onTap: () => setState(() {
                                _useCustomAmount = false;
                                _selectedPreset = amount;
                              }),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 150),
                                margin: EdgeInsets.only(right: amount != _presets.last ? 8 : 0),
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                decoration: BoxDecoration(
                                  color: selected ? AppColors.primary : Colors.white,
                                  border: Border.all(
                                    color: selected ? AppColors.primary : AppColors.border,
                                    width: selected ? 2 : 1,
                                  ),
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                child: Center(
                                  child: Text(
                                    '${amount ~/ 1000}k F',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 15,
                                      color: selected ? Colors.white : AppColors.textPrimary,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _customAmountCtrl,
                        keyboardType: const TextInputType.numberWithOptions(decimal: false),
                        onTap: () => setState(() => _useCustomAmount = true),
                        onChanged: (_) => setState(() => _useCustomAmount = true),
                        decoration: InputDecoration(
                          labelText: 'Autre montant',
                          suffixText: 'FCFA',
                          hintText: 'Min. 2 000 FCFA',
                          filled: true,
                          fillColor: Colors.white,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: AppColors.border)),
                          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: _useCustomAmount ? AppColors.primary : AppColors.border, width: _useCustomAmount ? 2 : 1)),
                          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: AppColors.primary, width: 2)),
                        ),
                      ),

                      const SizedBox(height: 24),

                      // ── Moyen de paiement ─────────────────────────────
                      const Text('Moyen de paiement',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.black87)),
                      const SizedBox(height: 12),
                      GestureDetector(
                        onTap: _showOperatorPicker,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: AppColors.border),
                          ),
                          child: Row(
                            children: [
                              _buildLogo(_selectedOperator),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Text(_selectedOperator.name,
                                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: Colors.black87)),
                              ),
                              const Icon(Icons.keyboard_arrow_down_rounded, color: AppColors.textSecondary),
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(height: 16),

                      // ── Numéro ────────────────────────────────────────
                      TextField(
                        controller: _phoneCtrl,
                        keyboardType: TextInputType.phone,
                        decoration: InputDecoration(
                          labelText: 'Numéro Mobile Money',
                          hintText: 'Ex : 07 00 00 00 00',
                          filled: true,
                          fillColor: Colors.white,
                          prefixIcon: const Icon(Icons.phone_outlined, color: AppColors.textSecondary),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: AppColors.border)),
                          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: AppColors.border)),
                          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: AppColors.primary, width: 2)),
                        ),
                      ),

                      // ── OTP ───────────────────────────────────────────
                      if (_selectedOperator.needsOtp) ...[
                        const SizedBox(height: 12),
                        TextField(
                          controller: _otpCtrl,
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            labelText: 'Code OTP Orange Money',
                            hintText: 'Code reçu sur votre téléphone',
                            filled: true,
                            fillColor: Colors.white,
                            prefixIcon: const Icon(Icons.lock_outline, color: AppColors.textSecondary),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: AppColors.border)),
                            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: AppColors.border)),
                            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: AppColors.primary, width: 2)),
                          ),
                        ),
                        const Padding(
                          padding: EdgeInsets.only(top: 6, left: 4),
                          child: Text('Composez #144*391# pour obtenir votre code OTP.',
                              style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                        ),
                      ],

                      // ── Info Wave ─────────────────────────────────────
                      if (_selectedOperator.code == 'WAVE_MONEY_CI') ...[
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: const Color(0xFFE3F2FD),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFF90CAF9)),
                          ),
                          child: const Row(
                            children: [
                              Icon(Icons.info_outline, color: Color(0xFF1565C0), size: 20),
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

                      const SizedBox(height: 24),
                    ],
                  ),
                ),

                // ── Overlay loading ───────────────────────────────────
                if (_recharging)
                  Positioned.fill(
                    child: Container(
                      color: Colors.black.withValues(alpha: 0.5),
                      child: Center(
                        child: Container(
                          margin: const EdgeInsets.symmetric(horizontal: 40),
                          padding: const EdgeInsets.all(28),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              _buildLogo(_selectedOperator),
                              const SizedBox(height: 16),
                              const CircularProgressIndicator(),
                              const SizedBox(height: 16),
                              const Text('Paiement en cours…',
                                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                              const SizedBox(height: 6),
                              Text(
                                _selectedOperator.code == 'WAVE_MONEY_CI'
                                    ? 'Confirmez dans l\'app Wave puis revenez ici.'
                                    : 'Validez sur votre téléphone puis patientez.',
                                textAlign: TextAlign.center,
                                style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
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

  Widget _buildBalanceCard() {
    final sub     = _currentSubscription?['subscription'] as Map<String, dynamic>?;
    final percent = (_currentSubscription?['credit_percent'] as num?)?.toInt() ?? 0;

    if (sub == null) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.primaryLight,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
        ),
        child: const Row(
          children: [
            Icon(Icons.account_balance_wallet_outlined, color: AppColors.primary),
            SizedBox(width: 12),
            Expanded(child: Text(
              'Aucun crédit actif. Effectuez votre première recharge pour recevoir des missions.',
              style: TextStyle(color: AppColors.primary, fontSize: 13),
            )),
          ],
        ),
      );
    }

    final balance = _num(sub['credit_balance']);
    final initial = _num(sub['credit_initial']);
    final floor   = _num(sub['credit_floor']);
    final status  = sub['status'] as String? ?? 'active';

    final color = status == 'exhausted'
        ? AppColors.error
        : percent > 50 ? AppColors.success
        : percent > 20 ? Colors.orange
        : AppColors.error;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1A1A2E), Color(0xFF16213E)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.account_balance_wallet_rounded, color: Colors.white70, size: 18),
              const SizedBox(width: 6),
              const Text('Solde crédit', style: TextStyle(color: Colors.white70, fontSize: 13)),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: status == 'exhausted'
                      ? AppColors.error.withValues(alpha: 0.3)
                      : AppColors.success.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  status == 'exhausted' ? 'Épuisé' : 'Actif',
                  style: TextStyle(
                    color: status == 'exhausted' ? AppColors.error : AppColors.success,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text('${balance.toStringAsFixed(0)} FCFA',
              style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w800)),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: (percent / 100).clamp(0, 1),
              minHeight: 6,
              backgroundColor: Colors.white24,
              valueColor: AlwaysStoppedAnimation<Color>(color),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Rechargé : ${initial.toStringAsFixed(0)} F',
                  style: const TextStyle(color: Colors.white54, fontSize: 11)),
              Text('$percent% restant',
                  style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w600)),
              Text('Seuil : ${floor.toStringAsFixed(0)} F',
                  style: const TextStyle(color: Colors.white54, fontSize: 11)),
            ],
          ),
        ],
      ),
    );
  }
}
