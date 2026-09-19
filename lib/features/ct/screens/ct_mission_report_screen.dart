import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
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
  String _result = 'favorable';
  final _notesCtrl = TextEditingController();
  final _pvNumberCtrl = TextEditingController();
  final _nextVtDateCtrl = TextEditingController();
  bool _isSubmitting = false;

  @override
  void dispose() {
    _notesCtrl.dispose();
    _pvNumberCtrl.dispose();
    _nextVtDateCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);

    final ctrl = context.read<CtController>();
    final ok = await ctrl.submitReport(widget.missionId, {
      'vt_result': _result,
      'vt_report_notes': _notesCtrl.text.trim(),
      'pv_number': _pvNumberCtrl.text.trim(),
      if (_nextVtDateCtrl.text.trim().isNotEmpty)
        'next_vt_due_date': _nextVtDateCtrl.text.trim(),
    });

    setState(() => _isSubmitting = false);

    if (!mounted) return;
    if (ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Rapport soumis avec succès'),
          backgroundColor: AppColors.success,
        ),
      );
      // Pop back to missions list
      context.go('/provider/ct');
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Erreur lors de la soumission du rapport'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        leading: BackButton(
          color: AppColors.textPrimary,
          onPressed: () => context.pop(),
        ),
        title: const Text(
          'Rapport CT',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w700,
            fontSize: 18,
          ),
        ),
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Résultat
              const Text(
                'Résultat de la visite',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 12),
              _ResultSelector(
                value: _result,
                onChanged: (v) => setState(() => _result = v),
              ),
              const SizedBox(height: 24),

              // N° de PV
              const Text(
                'Numéro de PV',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _pvNumberCtrl,
                decoration: _inputDecoration('Ex: PV-2026-001234'),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Champ obligatoire' : null,
              ),
              const SizedBox(height: 20),

              // Notes
              const Text(
                'Observations / Points de non-conformité',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _notesCtrl,
                maxLines: 4,
                decoration: _inputDecoration('Décrivez les observations...'),
              ),
              const SizedBox(height: 20),

              // Prochaine visite
              const Text(
                'Date prochaine visite technique',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _nextVtDateCtrl,
                readOnly: true,
                decoration: _inputDecoration('JJ/MM/AAAA').copyWith(
                  suffixIcon: const Icon(Icons.calendar_today, size: 20),
                ),
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: DateTime.now().add(const Duration(days: 365)),
                    firstDate: DateTime.now(),
                    lastDate: DateTime.now().add(const Duration(days: 365 * 5)),
                    builder: (context, child) => Theme(
                      data: Theme.of(context).copyWith(
                        colorScheme: const ColorScheme.light(primary: AppColors.primary),
                      ),
                      child: child!,
                    ),
                  );
                  if (picked != null) {
                    _nextVtDateCtrl.text =
                        '${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}';
                  }
                },
              ),
              const SizedBox(height: 36),

              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isSubmitting ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: _isSubmitting
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : const Text(
                          'Soumettre le rapport',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  InputDecoration _inputDecoration(String hint) => InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: AppColors.textMuted),
        filled: true,
        fillColor: AppColors.surface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      );
}

class _ResultSelector extends StatelessWidget {
  final String value;
  final ValueChanged<String> onChanged;
  const _ResultSelector({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _ResultChip(
          label: 'Favorable',
          color: AppColors.success,
          icon: Icons.check_circle,
          selected: value == 'favorable',
          onTap: () => onChanged('favorable'),
        ),
        const SizedBox(width: 10),
        _ResultChip(
          label: 'Défavorable',
          color: AppColors.error,
          icon: Icons.cancel,
          selected: value == 'defavorable',
          onTap: () => onChanged('defavorable'),
        ),
        const SizedBox(width: 10),
        _ResultChip(
          label: 'Contre-visite',
          color: AppColors.warning,
          icon: Icons.warning,
          selected: value == 'contre_visite',
          onTap: () => onChanged('contre_visite'),
        ),
      ],
    );
  }
}

class _ResultChip extends StatelessWidget {
  final String label;
  final Color color;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;
  const _ResultChip({
    required this.label,
    required this.color,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
          decoration: BoxDecoration(
            color: selected ? color.withOpacity(0.12) : AppColors.surface,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: selected ? color : AppColors.border,
              width: selected ? 2 : 1,
            ),
          ),
          child: Column(
            children: [
              Icon(icon, color: selected ? color : AppColors.textMuted, size: 22),
              const SizedBox(height: 4),
              Text(
                label,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: selected ? color : AppColors.textMuted,
                  fontSize: 11,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
