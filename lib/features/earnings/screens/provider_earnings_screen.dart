import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../home/controllers/provider_controller.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/utils/price_calculator.dart';
import '../../../core/constants/app_constants.dart';
import '../../../shared/widgets/provider_bottom_nav.dart';

class ProviderEarningsScreen extends StatelessWidget {
  const ProviderEarningsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final ctrl = context.watch<ProviderController>();
    final completed =
        ctrl.myInterventions.where((i) => i.isCompleted).toList();
    final totalGross =
        completed.fold(0.0, (sum, i) => sum + i.totalPrice);
    final totalCommission =
        completed.fold(0.0, (sum, i) => sum + i.commission);
    final totalNet = totalGross - totalCommission;

    return Scaffold(
      appBar: AppBar(title: const Text('Mes revenus'), automaticallyImplyLeading: false),
      bottomNavigationBar: const ProviderBottomNav(),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // Total card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [AppColors.success, Color(0xFF0D7A47)],
                ),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                children: [
                  const Text(
                    'Revenus nets totaux',
                    style: TextStyle(color: Colors.white70, fontSize: 14),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    PriceCalculator.formatFcfa(totalNet),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 32,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _MiniStat(
                        label: 'Brut',
                        value: PriceCalculator.formatFcfa(totalGross),
                      ),
                      Container(
                          height: 30,
                          width: 1,
                          color: Colors.white.withValues(alpha: 0.3)),
                      _MiniStat(
                        label: 'Commission (${(AppConstants.commissionRate * 100).toInt()}%)',
                        value: PriceCalculator.formatFcfa(totalCommission),
                      ),
                      Container(
                          height: 30,
                          width: 1,
                          color: Colors.white.withValues(alpha: 0.3)),
                      _MiniStat(
                        label: 'Interventions',
                        value: '${completed.length}',
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Daily breakdown
            const Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Détail des interventions',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
              ),
            ),
            const SizedBox(height: 12),

            ...completed.map(
              (i) => Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: AppColors.primaryLight,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Center(
                        child: Text(_icon(i.serviceTypeId)),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(i.serviceTypeName,
                              style: const TextStyle(
                                  fontWeight: FontWeight.w600)),
                          Text(
                            i.completedAt != null
                                ? _formatDate(i.completedAt!)
                                : '',
                            style: const TextStyle(
                              color: AppColors.textMuted,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          PriceCalculator.formatFcfa(
                              i.totalPrice - i.commission),
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            color: AppColors.success,
                          ),
                        ),
                        Text(
                          '-${PriceCalculator.formatFcfa(i.commission)} commission',
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppColors.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            if (completed.isEmpty)
              const Padding(
                padding: EdgeInsets.all(32),
                child: Center(
                  child: Text(
                    'Aucune intervention complétée.',
                    style: TextStyle(color: AppColors.textSecondary),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  String _icon(String id) {
    const icons = {
      'mechanic': '🔧',
      'towing': '🚛',
      'tire': '🔩',
      'electrical': '⚡',
      'battery': '🔋',
      'fuel': '⛽',
      'locksmith': '🔑',
    };
    return icons[id] ?? '🛠️';
  }

  String _formatDate(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
}

class _MiniStat extends StatelessWidget {
  final String label;
  final String value;
  const _MiniStat({required this.label, required this.value});

  @override
  Widget build(BuildContext context) => Column(
        children: [
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              fontSize: 13,
            ),
          ),
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.7),
              fontSize: 10,
            ),
          ),
        ],
      );
}
