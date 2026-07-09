import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/models/models.dart';
import '../../home/controllers/provider_controller.dart';

/// Écran « Mon équipe » : le prestataire principal gère jusqu'à 3 intervenants
/// (assistants) de son garage. Ces personnes ne reçoivent pas de commandes ;
/// elles peuvent seulement être désignées comme intervenant sur une commande
/// que le prestataire a acceptée.
class TeamScreen extends StatefulWidget {
  const TeamScreen({super.key});

  @override
  State<TeamScreen> createState() => _TeamScreenState();
}

class _TeamScreenState extends State<TeamScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ProviderController>().loadAssistants();
    });
  }

  @override
  Widget build(BuildContext context) {
    final ctrl = context.watch<ProviderController>();
    final assistants = ctrl.assistants;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Mon équipe')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: ctrl.canAddAssistant
            ? () => _openForm(context)
            : () => ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Maximum de 3 assistants atteint.')),
                ),
        backgroundColor:
            ctrl.canAddAssistant ? AppColors.primary : AppColors.textMuted,
        icon: const Icon(Icons.person_add_alt_1),
        label: const Text('Ajouter'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 100),
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.primaryLight,
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Row(children: [
              Icon(Icons.info_outline, color: AppColors.primary, size: 20),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Vos assistants peuvent intervenir à votre place. '
                  'Les commandes vous sont toujours envoyées à vous : vous '
                  'choisissez ensuite qui intervient.',
                  style: TextStyle(fontSize: 12.5, color: AppColors.textSecondary),
                ),
              ),
            ]),
          ),
          const SizedBox(height: 20),
          Text('${assistants.length}/3 assistant(s)',
              style: const TextStyle(
                  fontWeight: FontWeight.w700, color: AppColors.textSecondary)),
          const SizedBox(height: 12),
          if (assistants.isEmpty)
            Container(
              padding: const EdgeInsets.all(28),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Column(children: [
                Text('👥', style: TextStyle(fontSize: 38)),
                SizedBox(height: 8),
                Text('Aucun assistant pour l\'instant',
                    style: TextStyle(color: AppColors.textSecondary)),
              ]),
            )
          else
            ...assistants.map((a) => _AssistantTile(
                  assistant: a,
                  onEdit: () => _openForm(context, existing: a),
                  onDelete: () => _confirmDelete(context, a),
                )),
        ],
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context, ProviderAssistant a) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Supprimer cet assistant ?'),
        content: Text('${a.name} ne pourra plus être désigné comme intervenant.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(c, false),
              child: const Text('Annuler')),
          ElevatedButton(
            onPressed: () => Navigator.pop(c, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    final done = await context.read<ProviderController>().removeAssistant(a.id);
    if (!done && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Suppression impossible. Réessayez.')));
    }
  }

  void _openForm(BuildContext context, {ProviderAssistant? existing}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _AssistantForm(existing: existing),
    );
  }
}

class _AssistantTile extends StatelessWidget {
  final ProviderAssistant assistant;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  const _AssistantTile(
      {required this.assistant, required this.onEdit, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 8)
        ],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        leading: CircleAvatar(
          radius: 26,
          backgroundColor: AppColors.primaryLight,
          backgroundImage:
              (assistant.photoUrl != null && assistant.photoUrl!.isNotEmpty)
                  ? NetworkImage(assistant.photoUrl!)
                  : null,
          child: (assistant.photoUrl == null || assistant.photoUrl!.isEmpty)
              ? const Text('🧑‍🔧', style: TextStyle(fontSize: 22))
              : null,
        ),
        title: Text(assistant.name,
            style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(assistant.phone?.isNotEmpty == true
            ? assistant.phone!
            : 'Pas de téléphone'),
        trailing: Row(mainAxisSize: MainAxisSize.min, children: [
          IconButton(
              icon: const Icon(Icons.edit_outlined, color: AppColors.textSecondary),
              onPressed: onEdit),
          IconButton(
              icon: const Icon(Icons.delete_outline, color: AppColors.error),
              onPressed: onDelete),
        ]),
      ),
    );
  }
}

/// Formulaire d'ajout / édition, en bottom sheet.
class _AssistantForm extends StatefulWidget {
  final ProviderAssistant? existing;
  const _AssistantForm({this.existing});

  @override
  State<_AssistantForm> createState() => _AssistantFormState();
}

class _AssistantFormState extends State<_AssistantForm> {
  late final TextEditingController _name;
  late final TextEditingController _phone;
  String? _photoBase64;          // nouvelle photo choisie (data URI)
  String? _existingPhotoUrl;     // photo déjà enregistrée
  bool _saving = false;

  bool get _isEdit => widget.existing != null;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.existing?.name ?? '');
    _phone = TextEditingController(text: widget.existing?.phone ?? '');
    _existingPhotoUrl = widget.existing?.photoUrl;
  }

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    super.dispose();
  }

  Future<void> _pickPhoto() async {
    if (kIsWeb) return;
    final file = await ImagePicker()
        .pickImage(source: ImageSource.gallery, imageQuality: 80, maxWidth: 800);
    if (file == null) return;
    final bytes = await File(file.path).readAsBytes();
    final ext = file.path.split('.').last.toLowerCase();
    setState(() =>
        _photoBase64 = 'data:image/$ext;base64,${base64Encode(bytes)}');
  }

  Future<void> _save() async {
    final name = _name.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Le nom est obligatoire.')));
      return;
    }
    setState(() => _saving = true);
    final ctrl = context.read<ProviderController>();
    final phone = _phone.text.trim();

    final err = _isEdit
        ? await ctrl.updateAssistant(widget.existing!.id,
            name: name,
            phone: phone,
            photoBase64: _photoBase64)
        : await ctrl.addAssistant(
            name: name,
            phone: phone.isEmpty ? null : phone,
            photoBase64: _photoBase64);

    if (!mounted) return;
    setState(() => _saving = false);
    if (err == null) {
      Navigator.pop(context);
    } else {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(err)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    ImageProvider? avatar;
    if (_photoBase64 != null) {
      avatar = MemoryImage(base64Decode(_photoBase64!.split(',').last));
    } else if (_existingPhotoUrl != null && _existingPhotoUrl!.isNotEmpty) {
      avatar = NetworkImage(_existingPhotoUrl!);
    }

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: const BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(2)),
          ),
          const SizedBox(height: 20),
          Text(_isEdit ? 'Modifier l\'assistant' : 'Nouvel assistant',
              style: const TextStyle(
                  fontSize: 18, fontWeight: FontWeight.w700)),
          const SizedBox(height: 20),
          GestureDetector(
            onTap: _pickPhoto,
            child: Stack(children: [
              CircleAvatar(
                radius: 44,
                backgroundColor: AppColors.primaryLight,
                backgroundImage: avatar,
                child: avatar == null
                    ? const Icon(Icons.add_a_photo_outlined,
                        color: AppColors.primary)
                    : null,
              ),
              const Positioned(
                bottom: 0,
                right: 0,
                child: CircleAvatar(
                  radius: 14,
                  backgroundColor: AppColors.primary,
                  child: Icon(Icons.camera_alt, size: 14, color: Colors.white),
                ),
              ),
            ]),
          ),
          const SizedBox(height: 20),
          TextField(
            controller: _name,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(
              labelText: 'Nom complet',
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _phone,
            keyboardType: TextInputType.phone,
            decoration: const InputDecoration(
              labelText: 'Téléphone (optionnel)',
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 22),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed: _saving ? null : _save,
              child: _saving
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : Text(_isEdit ? 'Enregistrer' : 'Ajouter l\'assistant'),
            ),
          ),
          const SizedBox(height: 8),
        ]),
      ),
    );
  }
}
