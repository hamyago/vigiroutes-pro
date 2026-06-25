import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../controllers/auth_controller.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/services/location_service.dart';
import '../../../shared/widgets/custom_button.dart';

class ProfileSetupScreen extends StatefulWidget {
  final bool isProvider;
  const ProfileSetupScreen({super.key, this.isProvider = false});

  @override
  State<ProfileSetupScreen> createState() => _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends State<ProfileSetupScreen> {
  final _nameCtrl  = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _formKey   = GlobalKey<FormState>();
  final _locationService = LocationService();

  String? _selectedSector;
  bool _loadingLocation = false;
  double? _lat, _lng;

  static const _sectors = [
    {'value': 'mecanicien',       'label': '🔧 Mécanicien'},
    {'value': 'electricien_auto', 'label': '⚡ Électricien Auto'},
    {'value': 'vulcanisateur',    'label': '🔩 Vulcanisateur'},
    {'value': 'remorqueur',       'label': '🚛 Remorqueur'},
  ];

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    super.dispose();
  }

  Future<void> _getLocation() async {
    setState(() => _loadingLocation = true);
    final pos = await _locationService.getCurrentPosition();
    setState(() {
      _lat = pos?.latitude;
      _lng = pos?.longitude;
      _loadingLocation = false;
    });
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final auth = context.read<AuthController>();

    if (_selectedSector == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sélectionnez votre secteur d\'activité.')),
      );
      return;
    }
    if (_lat == null) {
      await _getLocation();
      if (_lat == null && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('La localisation est requise.')),
        );
        return;
      }
    }

    await auth.completeProviderProfile(
      name:         _nameCtrl.text.trim(),
      phone:        _phoneCtrl.text.trim(),
      sector:       _selectedSector!,
      serviceTypes: [],
      latitude:     _lat!,
      longitude:    _lng!,
    );

    if (!mounted) return;

    if (auth.error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(auth.error!),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    if (auth.state == AuthState.authenticated) {
      context.go('/provider/home');
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthController>();

    return Scaffold(
      appBar: AppBar(title: const Text('Créer mon profil')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 88,
                    height: 88,
                    decoration: BoxDecoration(
                      color: AppColors.primaryLight,
                      shape: BoxShape.circle,
                    ),
                    child: const Center(
                      child: Text('👤', style: TextStyle(fontSize: 40)),
                    ),
                  ),
                ),
                const SizedBox(height: 32),
                TextFormField(
                  controller: _nameCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Nom complet',
                    prefixIcon: Icon(Icons.person_outline),
                  ),
                  validator: (v) => v == null || v.isEmpty ? 'Champ requis' : null,
                  textCapitalization: TextCapitalization.words,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _phoneCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Numéro WhatsApp (optionnel)',
                    prefixIcon: Icon(Icons.chat_bubble_outline),
                    hintText: '+225...',
                  ),
                  keyboardType: TextInputType.phone,
                ),
                const SizedBox(height: 24),
                const Text(
                  'Secteur d\'activité',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _sectors.map((s) {
                    final selected = _selectedSector == s['value'];
                    return GestureDetector(
                      onTap: () => setState(() => _selectedSector = s['value']),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        decoration: BoxDecoration(
                          color: selected ? AppColors.primary : AppColors.surfaceVariant,
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(
                            color: selected ? AppColors.primary : AppColors.border,
                          ),
                        ),
                        child: Text(
                          s['label']!,
                          style: TextStyle(
                            color: selected ? Colors.white : AppColors.textPrimary,
                            fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 24),
                const Text(
                  'Votre localisation',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
                ),
                const SizedBox(height: 12),
                InkWell(
                  onTap: _getLocation,
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: _lat != null ? AppColors.successLight : AppColors.surfaceVariant,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: _lat != null ? AppColors.success : AppColors.border,
                      ),
                    ),
                    child: Row(children: [
                      Icon(
                        _lat != null ? Icons.check_circle : Icons.location_on_outlined,
                        color: _lat != null ? AppColors.success : AppColors.primary,
                      ),
                      const SizedBox(width: 12),
                      Text(
                        _loadingLocation
                            ? 'Localisation en cours...'
                            : _lat != null
                                ? 'Position enregistrée ✓'
                                : 'Appuyez pour détecter ma position',
                        style: TextStyle(
                          color: _lat != null ? AppColors.success : AppColors.textSecondary,
                        ),
                      ),
                      if (_loadingLocation) ...[
                        const Spacer(),
                        const SizedBox(
                          width: 16, height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      ],
                    ]),
                  ),
                ),
                if (auth.error != null) ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.errorLight,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(children: [
                      const Icon(Icons.error_outline, color: AppColors.error, size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          auth.error!,
                          style: const TextStyle(color: AppColors.error, fontSize: 13),
                        ),
                      ),
                    ]),
                  ),
                ],
                const SizedBox(height: 40),
                AppButton(
                  label: 'Créer mon compte',
                  isLoading: auth.isLoading,
                  enabled: !auth.isLoading,
                  onPressed: _submit,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
