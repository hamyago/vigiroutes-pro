import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_colors.dart';
import '../../../features/auth/controllers/auth_controller.dart';
import '../../../core/services/api_service.dart';

class ProviderRatesScreen extends StatefulWidget {
  const ProviderRatesScreen({super.key});

  @override
  State<ProviderRatesScreen> createState() => _ProviderRatesScreenState();
}

class _ProviderRatesScreenState extends State<ProviderRatesScreen> {
  List<Map<String, dynamic>> _rates = [];
  bool _isLoading = true;
  bool _isSaving  = false;
  String? _error;

  // Contrôleurs pour chaque service
  final Map<String, TextEditingController> _basePriceControllers  = {};
  final Map<String, TextEditingController> _pricePerKmControllers = {};

  @override
  void initState() {
    super.initState();
    _loadRates();
  }

  @override
  void dispose() {
    for (final c in _basePriceControllers.values)  c.dispose();
    for (final c in _pricePerKmControllers.values) c.dispose();
    super.dispose();
  }

  Future<void> _loadRates() async {
    try {
      final res = await ApiService.instance.get('/provider/rates');
      final rates = (res.data['rates'] as List)
          .map((e) => e as Map<String, dynamic>)
          .toList();

      setState(() {
        _rates     = rates;
        _isLoading = false;
      });

      // Initialiser les contrôleurs
      for (final rate in rates) {
        final id = rate['service_type_id'] as String;
        _basePriceControllers[id] = TextEditingController(
            text: (rate['base_price'] as num).toInt().toString());
        _pricePerKmControllers[id] = TextEditingController(
            text: (rate['price_per_km'] as num).toInt().toString());
      }
    } catch (e) {
      setState(() {
        _error = 'Erreur: \';
        _isLoading = false;
      });
    }
  }

  Future<void> _saveRates() async {
    setState(() => _isSaving = true);

    final ratesToSave = _rates.map((rate) {
      final id = rate['service_type_id'] as String;
      return {
        'service_type_id': id,
        'base_price':
            double.tryParse(_basePriceControllers[id]?.text ?? '0') ?? 0,
        'price_per_km':
            double.tryParse(_pricePerKmControllers[id]?.text ?? '0') ?? 0,
      };
    }).toList();

    try {
      await ApiService.instance.post('/provider/rates', data: {'rates': ratesToSave});
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Tarifs enregistrés avec succès'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Erreur: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  String _emojiFromSlug(String slug) {
    switch (slug) {
      case 'depannage':  return '🔧';
      case 'remorquage': return '🚛';
      case 'pneu':       return '🔩';
      case 'batterie':   return '🔋';
      case 'carburant':  return '⛽';
      case 'serrurier':  return '🔑';
      default:           return '🛠️';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mes tarifs',
            style: TextStyle(fontWeight: FontWeight.w700)),
        actions: [
          if (!_isLoading && _rates.isNotEmpty)
            TextButton(
              onPressed: _isSaving ? null : _saveRates,
              child: _isSaving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('Enregistrer',
                      style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: AppColors.primary)),
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error_outline,
                          color: AppColors.error, size: 48),
                      const SizedBox(height: 16),
                      Text(_error!),
                      const SizedBox(height: 16),
                      ElevatedButton(
                          onPressed: _loadRates,
                          child: const Text('Réessayer')),
                    ],
                  ),
                )
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Info banner
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppColors.primaryLight,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.info_outline,
                                color: AppColors.primary),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                'Vous pouvez personnaliser vos tarifs. '
                                'Les minimums fixés par VigiRoutes '
                                'sont indiqués sous chaque champ.',
                                style: TextStyle(
                                  color: AppColors.primary,
                                  fontSize: 13,
                                  height: 1.4,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Liste des services
                      ..._rates.map((rate) => _ServiceRateCard(
                            rate:              rate,
                            emoji:             _emojiFromSlug(
                                rate['service_type_slug'] as String? ?? ''),
                            basePriceCtrl:
                                _basePriceControllers[
                                    rate['service_type_id']]!,
                            pricePerKmCtrl:
                                _pricePerKmControllers[
                                    rate['service_type_id']]!,
                          )),
                    ],
                  ),
                ),
    );
  }
}

class _ServiceRateCard extends StatelessWidget {
  final Map<String, dynamic> rate;
  final String emoji;
  final TextEditingController basePriceCtrl;
  final TextEditingController pricePerKmCtrl;

  const _ServiceRateCard({
    required this.rate,
    required this.emoji,
    required this.basePriceCtrl,
    required this.pricePerKmCtrl,
  });

  @override
  Widget build(BuildContext context) {
    final minBase  = (rate['min_base_price']   as num).toInt();
    final minPerKm = (rate['min_price_per_km'] as num).toInt();
    final hasCustom = rate['has_custom_rate'] as bool? ?? false;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Text(emoji, style: const TextStyle(fontSize: 28)),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        rate['service_type_name'] as String,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      if (hasCustom)
                        Container(
                          margin: const EdgeInsets.only(top: 4),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.successLight,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text(
                            'Tarif personnalisé',
                            style: TextStyle(
                              fontSize: 11,
                              color: AppColors.success,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Divider(height: 1),
            const SizedBox(height: 16),

            // Champs de tarifs
            Row(
              children: [
                // Prix de base
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Prix de base',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: basePriceCtrl,
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly
                        ],
                        decoration: InputDecoration(
                          suffixText: 'FCFA',
                          filled: true,
                          fillColor: AppColors.surfaceVariant,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide.none,
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 10),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Min: $minBase FCFA',
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),

                // Prix par km
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Prix par km',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: pricePerKmCtrl,
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly
                        ],
                        decoration: InputDecoration(
                          suffixText: 'FCFA',
                          filled: true,
                          fillColor: AppColors.surfaceVariant,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide.none,
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 10),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Min: $minPerKm FCFA/km',
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
