import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../controllers/ct_controller.dart';
import '../../../core/constants/app_colors.dart';

class CtMissionReportScreen extends StatefulWidget {
  final String missionId;
  const CtMissionReportScreen({super.key, required this.missionId});

  @override
  State<CtMissionReportScreen> createState() => _CtMissionReportScreenState();
}

class _CtMissionReportScreenState extends State<CtMissionReportScreen> {
  final _formKey = GlobalKey<FormState>();
  String _result = 'FAVORABLE';
  final _pvCtrl = TextEditingController();
  final _obsCtrl = TextEditingController();
  DateTime? _nextDate;
  bool _submitting = false;

  @override
  void dispose() {
    _pvCtrl.dispose();
    _obsCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _submitting = true);
    final ok = await context.read<CtController>().submitReport(
      widget.missionId,
      _result,
      _pvCtrl.text.trim(),
      _obsCtrl.text.trim(),
      _nextDate,
    );
    if (!mounted) return;
    setState(() => _submitting = false);
    if (ok) {
      Navigator.of(context).pop(true);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Erreur lors de la soumission du rapport')),
      );
    }
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now().add(const Duration(days: 365)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365 * 5)),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.light(primary: AppColors.primary),
        ),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _nextDate = picked);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        leading: BackButton(style: ButtonStyle(iconColor: WidgetStatePropertyAll(AppColors.textPrimary))),
        title: const Text(
          'Rapport CT',
          style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w700, fontSize: 17),
        ),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            // ── Résultat ────────────────────────────────────────────────────
            const Text('Résultat de la visite', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: AppColors.textPrimary)),
            const SizedBox(height: 10),
            ...['FAVORABLE', 'DEFAVORABLE', 'CONTRE_VISITE'].map((v) {
              final labels = {'FAVORABLE': 'Favorable', 'DEFAVORABLE': 'Défavorable', 'CONTRE_VISITE': 'Contre-visite'};
              final colors = {'FAVORABLE': AppColors.success, 'DEFAVORABLE': AppColors.error, 'CONTRE_VISITE': AppColors.warning};
              final selected = _result == v;
              return GestureDetector(
                onTap: () => setState(() => _result = v),
                child: Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    color: selected ? colors[v]!.withValues(alpha: 0.1) : AppColors.surface,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: selected ? colors[v]! : AppColors.border, width: selected ? 2 : 1),
                  ),
                  child: Row(
                    children: [
                      Icon(selected ? Icons.radio_button_checked : Icons.radio_button_unchecked, color: selected ? colors[v] : AppColors.textMuted, size: 20),
                      const SizedBox(width: 12),
                      Text(labels[v]!, style: TextStyle(fontWeight: selected ? FontWeight.w700 : FontWeight.normal, color: selected ? colors[v] : AppColors.textPrimary, fontSize: 15)),
                    ],
                  ),
                ),
              );
            }),
            const SizedBox(height: 20),
            // ── N° PV ────────────────────────────────────────────────────────
            const Text('N° PV *', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: AppColors.textPrimary)),
            const SizedBox(height: 8),
            TextFormField(
              controller: _pvCtrl,
              decoration: InputDecoration(
                hintText: 'Ex: PV-2024-001234',
                filled: true,
                fillColor: AppColors.surface,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.border)),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.border)),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.primary, width: 2)),
              ),
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Le numéro de PV est requis' : null,
            ),
            const SizedBox(height: 20),
            // ── Observations ─────────────────────────────────────────────────
            const Text('Observations', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: AppColors.textPrimary)),
            const SizedBox(height: 8),
            TextFormField(
              controller: _obsCtrl,
              maxLines: 4,
              decoration: InputDecoration(
                hintText: 'Observations, non-conformités...',
                filled: true,
                fillColor: AppColors.surface,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.border)),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.border)),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.primary, width: 2)),
              ),
            ),
            const SizedBox(height: 20),
            // ── Prochaine VT ─────────────────────────────────────────────────
            const Text('Date prochaine VT', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: AppColors.textPrimary)),
            const SizedBox(height: 8),
            GestureDetector(
              onTap: _pickDate,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.border),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.calendar_today, color: AppColors.textMuted, size: 18),
                    const SizedBox(width: 10),
                    Text(
                      _nextDate == null
                          ? 'Sélectionner une date (optionnel)'
                          : '${_nextDate!.day.toString().padLeft(2, '0')}/${_nextDate!.month.toString().padLeft(2, '0')}/${_nextDate!.year}',
                      style: TextStyle(color: _nextDate == null ? AppColors.textMuted : AppColors.textPrimary, fontSize: 14),
                    ),
                    const Spacer(),
                    if (_nextDate != null)
                      GestureDetector(
                        onTap: () => setState(() => _nextDate = null),
                        child: const Icon(Icons.close, color: AppColors.textMuted, size: 18),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: _submitting ? null : _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: _submitting
                    ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                    : const Text('Soumettre le rapport', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
