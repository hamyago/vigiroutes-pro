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
  final Widget logo;
  final bool needsOtp;

  const _Operator({
    required this.code,
    required this.name,
    required this.logo,
    required this.needsOtp,
  });
}

final List<_Operator> _operators = [
  _Operator(
    code: 'ORANGE_MONEY_CI',
    name: 'Orange Money',
    needsOtp: true,
    logo: _OrangeLogo(),
  ),
  _Operator(
    code: 'MTN_MONEY_CI',
    name: 'MTN MoMo',
    needsOtp: false,
    logo: _MtnLogo(),
  ),
  _Operator(
    code: 'WAVE_MONEY_CI',
    name: 'Wave',
    needsOtp: false,
    logo: _WaveLogo(),
  ),
];

// ── Logos SVG inline ─────────────────────────────────────────────────────────

class _OrangeLogo extends StatelessWidget {
  const _OrangeLogo();
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: const Color(0xFFFF6600),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 22,
              height: 5,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(3),
              ),
            ),
            const SizedBox(height: 3),
            Container(
              width: 16,
              height: 5,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(3),
              ),
            ),
            const SizedBox(height: 3),
            Container(
              width: 10,
              height: 5,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(3),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MtnLogo extends StatelessWidget {
  const _MtnLogo();
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: const Color(0xFFFFCC00),
        borderRadius: BorderRadius.circular(10),
      ),
      child: const Center(
        child: Text(
          'MTN',
          style: TextStyle(
            color: Color(0xFF000000),
            fontWeight: FontWeight.w900,
            fontSize: 11,
            letterSpacing: 0.5,
          ),
        ),
      ),
    );
  }
}

class _WaveLogo extends StatelessWidget {
  const _WaveLogo();
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: const Color(0xFF1B9AF7),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Center(
        child: CustomPaint(
          size: const Size(26, 20),
          painter: _WaveIconPainter(),
        ),
      ),
    );
  }
}

class _WaveIconPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0
      ..strokeCap = StrokeCap.round;

    final path = Path();
    path.moveTo(0, size.height * 0.5);
    path.cubicTo(
      size.width * 0.2, size.height * 0.1,
      size.width * 0.3, size.height * 0.1,
      size.width * 0.5, size.height * 0.5,
    );
    path.cubicTo(
      size.width * 0.7, size.height * 0.9,
      size.width * 0.8, size.height * 0.9,
      size.width, size.height * 0.5,
    );
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
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

  // ── helpers ────────────────────────────────────────────────────────────

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

  // ── chargement ─────────────────────────────────────────────────────────

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

  // ── polling ────────────────────────────────────────────────────────────

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

  // ── bottom sheet sélecteur opérateur ───────────────────────────────────

  void _showOperatorPicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => StatefulBuilder(
        builder: (ctx, setLocal) => Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Poignée
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.border,
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
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
                  ),
                  GestureDetector(
                    onTap: () => Navigator.pop(ctx),
                    child: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: AppColors.surfaceVariant,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.close, size: 18),
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
                        setLocal(() {});
                        setState(() => _selectedOperator = op);
                        Navigator.pop(ctx);
                      },
                      borderRadius: BorderRadius.circular(12),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        child: Row(
                          children: [
                            op.logo,
                            const SizedBox(width: 16),
                            Expanded(
                              child: Text(
                                op.name,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                            Container(
                              width: 24,
                              height: 24,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: selected
                                      ? AppColors.primary
                                      : AppColors.border,
                                  width: selected ? 0 : 2,
                                ),
                                color: selected
                                    ? AppColors.primary
                                    : Colors.transparent,
                              ),
                              child: selected
                                  ? const Icon(Icons.circle,
                                      color: Colors.white, size: 10)
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
    );
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
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Recharger mon compte'),
        backgroundColor: Colors.white,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
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
                    ),
                    child: Text(
                      'Recharger via ${_selectedOperator.name}',
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w600),
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
                      _BalanceCard(
                        subscription: _currentSubscription,
                        numHelper: _num,
                      ),
                      const SizedBox(height: 20),

                      // ── Explication ───────────────────────────────────
                      _CreditExplanationCard(),
                      const SizedBox(height: 24),

                      // ── Montant ───────────────────────────────────────
                      const Text(
                        'Choisissez un montant',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: _presets.map((amount) {
                          final selected =
                              !_useCustomAmount && _selectedPreset == amount;
                          return Expanded(
                            child: GestureDetector(
                              onTap: () => setState(() {
                                _useCustomAmount = false;
                                _selectedPreset = amount;
                              }),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 150),
                                margin: EdgeInsets.only(
                                    right: amount != _presets.last ? 8 : 0),
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                decoration: BoxDecoration(
                                  color: selected
                                      ? AppColors.primary
                                      : Colors.white,
                                  border: Border.all(
                                    color: selected
                                        ? AppColors.primary
                                        : AppColors.border,
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
                                      color: selected
                                          ? Colors.white
                                          : AppColors.textPrimary,
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
                        keyboardType:
                            const TextInputType.numberWithOptions(decimal: false),
                        onTap: () => setState(() => _useCustomAmount = true),
                        onChanged: (_) => setState(() => _useCustomAmount = true),
                        decoration: InputDecoration(
                          labelText: 'Autre montant',
                          suffixText: 'FCFA',
                          filled: true,
                          fillColor: _useCustomAmount
                              ? AppColors.primaryLight
                              : Colors.white,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide:
                                const BorderSide(color: AppColors.border),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide(
                              color: _useCustomAmount
                                  ? AppColors.primary
                                  : AppColors.border,
                              width: _useCustomAmount ? 2 : 1,
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: const BorderSide(
                                color: AppColors.primary, width: 2),
                          ),
                          hintText: 'Min. 2 000 FCFA',
                        ),
                      ),

                      const SizedBox(height: 24),

                      // ── Moyen de paiement ─────────────────────────────
                      const Text(
                        'Moyen de paiement',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 12),
                      GestureDetector(
                        onTap: _showOperatorPicker,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 14),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: AppColors.border),
                          ),
                          child: Row(
                            children: [
                              _selectedOperator.logo,
                              const SizedBox(width: 14),
                              Expanded(
                                child: Text(
                                  _selectedOperator.name,
                                  style: const TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                              const Icon(Icons.keyboard_arrow_down_rounded,
                                  color: AppColors.textSecondary),
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
                          prefixIcon: const Icon(Icons.phone_outlined,
                              color: AppColors.textSecondary),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide:
                                const BorderSide(color: AppColors.border),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide:
                                const BorderSide(color: AppColors.border),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: const BorderSide(
                                color: AppColors.primary, width: 2),
                          ),
                        ),
                      ),

                      // ── OTP Orange Money ──────────────────────────────
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
                            prefixIcon: const Icon(Icons.lock_outline,
                                color: AppColors.textSecondary),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide:
                                  const BorderSide(color: AppColors.border),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide:
                                  const BorderSide(color: AppColors.border),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: const BorderSide(
                                  color: AppColors.primary, width: 2),
                            ),
                          ),
                        ),
                        const Padding(
                          padding: EdgeInsets.only(top: 6, left: 4),
                          child: Text(
                            'Composez #144*391# pour obtenir votre code OTP.',
                            style: TextStyle(
                                fontSize: 12,
                                color: AppColors.textSecondary),
                          ),
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
                            border: Border.all(
                                color: const Color(0xFF90CAF9)),
                          ),
                          child: const Row(
                            children: [
                              Icon(Icons.info_outline,
                                  color: Color(0xFF1565C0), size: 20),
                              SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  'Vous serez redirigé vers l\'app Wave pour confirmer le paiement.',
                                  style: TextStyle(
                                      fontSize: 13,
                                      color: Color(0xFF1565C0)),
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

                // ── Overlay chargement ────────────────────────────────
                if (_recharging)
                  Positioned.fill(
                    child: Container(
                      color: Colors.black.withValues(alpha: 0.5),
                      child: Center(
                        child: Container(
                          margin:
                              const EdgeInsets.symmetric(horizontal: 40),
                          padding: const EdgeInsets.all(28),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              _selectedOperator.logo,
                              const SizedBox(height: 16),
                              const CircularProgressIndicator(),
                              const SizedBox(height: 16),
                              const Text(
                                'Paiement en cours…',
                                style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 15),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                _selectedOperator.code == 'WAVE_MONEY_CI'
                                    ? 'Confirmez dans l\'app Wave puis revenez ici.'
                                    : 'Validez sur votre téléphone puis patientez.',
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                    color: AppColors.textSecondary,
                                    fontSize: 13),
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

// ── Widget : carte solde ─────────────────────────────────────────────────────

class _BalanceCard extends StatelessWidget {
  final Map<String, dynamic>? subscription;
  final double Function(dynamic) numHelper;

  const _BalanceCard({required this.subscription, required this.numHelper});

  @override
  Widget build(BuildContext context) {
    final sub     = subscription?['subscription'] as Map<String, dynamic>?;
    final percent = (subscription?['credit_percent'] as num?)?.toInt() ?? 0;

    if (sub == null) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.primaryLight,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
              color: AppColors.primary.withValues(alpha: 0.3)),
        ),
        child: const Row(
          children: [
            Icon(Icons.account_balance_wallet_outlined,
                color: AppColors.primary),
            SizedBox(width: 12),
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
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.dark, AppColors.darkMedium],
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
              const Icon(Icons.account_balance_wallet_rounded,
                  color: Colors.white70, size: 18),
              const SizedBox(width: 6),
              const Text(
                'Solde crédit',
                style: TextStyle(color: Colors.white70, fontSize: 13),
              ),
              const Spacer(),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: status == 'exhausted'
                      ? AppColors.error.withValues(alpha: 0.3)
                      : AppColors.success.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  status == 'exhausted' ? 'Épuisé' : 'Actif',
                  style: TextStyle(
                    color: status == 'exhausted'
                        ? AppColors.error
                        : AppColors.success,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            '${balance.toStringAsFixed(0)} FCFA',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 28,
              fontWeight: FontWeight.w800,
            ),
          ),
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
              Text(
                'Rechargé : ${initial.toStringAsFixed(0)} F',
                style:
                    const TextStyle(color: Colors.white54, fontSize: 11),
              ),
              Text(
                '$percent% restant',
                style: TextStyle(
                    color: color,
                    fontSize: 11,
                    fontWeight: FontWeight.w600),
              ),
              Text(
                'Seuil : ${floor.toStringAsFixed(0)} F',
                style:
                    const TextStyle(color: Colors.white54, fontSize: 11),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Widget : explication ─────────────────────────────────────────────────────

class _CreditExplanationCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.primaryLight,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color: AppColors.primary.withValues(alpha: 0.3)),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.lightbulb_outline,
                  color: AppColors.primary, size: 18),
              SizedBox(width: 8),
              Text(
                'Comment fonctionne la recharge ?',
                style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                    color: AppColors.primary),
              ),
            ],
          ),
          SizedBox(height: 8),
          Text(
            '• Rechargez le montant de votre choix (min. 2 000 F)\n'
            '• 18% du montant de chaque intervention est déduit de votre solde\n'
            '• Quand le solde atteint le seuil, votre compte est épuisé\n'
            '• Rechargez à tout moment pour continuer à recevoir des missions',
            style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 12,
                height: 1.7),
          ),
        ],
      ),
    );
  }
}
