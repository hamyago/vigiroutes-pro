import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/models/models.dart';

/// Résultat du choix d'intervenant.
/// `assistantId == null` => "moi-même". Un retour `null` du sheet = annulé.
class AssistantChoice {
  final int? assistantId;
  const AssistantChoice(this.assistantId);
}

/// Feuille de sélection de l'intervenant.
/// Utilisée à deux moments :
///  - à l'acceptation d'une commande (title: "Qui va intervenir ?")
///  - pour réaffecter une commande déjà acceptée (title: "Changer l'intervenant")
Future<AssistantChoice?> showAssignAssistantSheet(
  BuildContext context, {
  required List<ProviderAssistant> assistants,
  int? currentAssistantId,
  String title = 'Qui va intervenir ?',
}) {
  final active = assistants.where((a) => a.isActive).toList();
  return showModalBottomSheet<AssistantChoice>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (_) => _AssignSheet(
      active: active,
      currentAssistantId: currentAssistantId,
      title: title,
    ),
  );
}

class _AssignSheet extends StatelessWidget {
  final List<ProviderAssistant> active;
  final int? currentAssistantId;
  final String title;
  const _AssignSheet({
    required this.active,
    required this.currentAssistantId,
    required this.title,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
      decoration: const BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(
          width: 40,
          height: 4,
          margin: const EdgeInsets.only(bottom: 16),
          decoration: BoxDecoration(
              color: AppColors.border, borderRadius: BorderRadius.circular(2)),
        ),
        Text(title,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
        const SizedBox(height: 16),

        // Moi-même
        _OptionTile(
          selected: currentAssistantId == null,
          leading: const CircleAvatar(
            radius: 22,
            backgroundColor: AppColors.primaryLight,
            child: Icon(Icons.person, color: AppColors.primary),
          ),
          title: 'Moi-même',
          subtitle: "J'interviens personnellement",
          onTap: () => Navigator.pop(context, const AssistantChoice(null)),
        ),

        if (active.isNotEmpty) const SizedBox(height: 4),
        ...active.map((a) => _OptionTile(
              selected: currentAssistantId == a.id,
              leading: CircleAvatar(
                radius: 22,
                backgroundColor: AppColors.primaryLight,
                backgroundImage:
                    (a.photoUrl != null && a.photoUrl!.isNotEmpty)
                        ? NetworkImage(a.photoUrl!)
                        : null,
                child: (a.photoUrl == null || a.photoUrl!.isEmpty)
                    ? const Text('🧑‍🔧', style: TextStyle(fontSize: 18))
                    : null,
              ),
              title: a.name,
              subtitle: a.phone?.isNotEmpty == true ? a.phone! : 'Assistant',
              onTap: () => Navigator.pop(context, AssistantChoice(a.id)),
            )),

        if (active.isEmpty) ...[
          const SizedBox(height: 8),
          const Text(
            "Vous n'avez pas encore d'assistant. Ajoutez-en depuis "
            '« Mon équipe » dans votre profil.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
          ),
        ],
      ]),
    );
  }
}

class _OptionTile extends StatelessWidget {
  final bool selected;
  final Widget leading;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  const _OptionTile({
    required this.selected,
    required this.leading,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: selected ? AppColors.primary : AppColors.border,
          width: selected ? 2 : 1,
        ),
      ),
      child: ListTile(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        leading: leading,
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(subtitle),
        trailing: selected
            ? const Icon(Icons.check_circle, color: AppColors.primary)
            : const Icon(Icons.radio_button_unchecked, color: AppColors.textMuted),
        onTap: onTap,
      ),
    );
  }
}
