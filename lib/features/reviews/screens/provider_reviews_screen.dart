import 'package:flutter/material.dart';
import 'package:timeago/timeago.dart' as timeago;
import '../../../core/constants/app_colors.dart';
import '../../../core/models/models.dart';
import '../../../core/services/api_service.dart';

/// AJOUTÉ : aucun écran d'avis n'existait côté Pro (ni reçus des clients,
/// ni donnés aux clients) — seule la moyenne chiffrée était visible sur
/// le profil, sans jamais pouvoir lire les commentaires.
class ProviderReviewsScreen extends StatefulWidget {
  const ProviderReviewsScreen({super.key});

  @override
  State<ProviderReviewsScreen> createState() => _ProviderReviewsScreenState();
}

class _ProviderReviewsScreenState extends State<ProviderReviewsScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tab = TabController(length: 2, vsync: this);

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mes avis'),
        bottom: TabBar(
          controller: _tab,
          labelColor: AppColors.primary,
          unselectedLabelColor: AppColors.textSecondary,
          indicatorColor: AppColors.primary,
          tabs: const [
            Tab(text: 'Reçus des clients'),
            Tab(text: 'Donnés aux clients'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tab,
        children: [
          _ReviewsList(
            future: ApiService.instance.getReviews(),
            emptyTitle: 'Aucun avis reçu pour le moment',
            emptySubtitle: 'Les clients peuvent vous noter après une intervention.',
            headerLabel: 'avis de clients',
          ),
          _ReviewsList(
            future: ApiService.instance.getReviewsGiven(),
            emptyTitle: 'Vous n\'avez encore noté aucun client',
            emptySubtitle: 'Notez un client depuis l\'écran de fin d\'intervention.',
            headerLabel: 'avis donnés',
          ),
        ],
      ),
    );
  }
}

class _ReviewsList extends StatelessWidget {
  final Future<List<dynamic>> future;
  final String emptyTitle;
  final String emptySubtitle;
  final String headerLabel;

  const _ReviewsList({
    required this.future,
    required this.emptyTitle,
    required this.emptySubtitle,
    required this.headerLabel,
  });

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<dynamic>>(
      future: future,
      builder: (_, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snap.hasError) {
          return Center(child: Text('Erreur : ${snap.error}'));
        }
        final reviews = (snap.data ?? [])
            .map((e) {
              try { return ReviewModel.fromJson(e as Map<String, dynamic>); }
              catch (_) { return null; }
            })
            .whereType<ReviewModel>()
            .toList();

        if (reviews.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('⭐', style: TextStyle(fontSize: 48)),
                  const SizedBox(height: 12),
                  Text(emptyTitle,
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  Text(emptySubtitle,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: AppColors.textSecondary)),
                ],
              ),
            ),
          );
        }

        final avg = reviews.map((r) => r.rating).reduce((a, b) => a + b) / reviews.length;

        return ListView(padding: const EdgeInsets.all(16), children: [
          Container(
            padding: const EdgeInsets.all(20),
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [AppColors.primary, AppColors.primaryDark]),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(children: [
              const Text('⭐', style: TextStyle(fontSize: 36)),
              const SizedBox(width: 16),
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(avg.toStringAsFixed(1),
                    style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.w800)),
                Text('${reviews.length} $headerLabel',
                    style: const TextStyle(color: Colors.white70, fontSize: 13)),
              ]),
            ]),
          ),
          ...reviews.map((r) => _ReviewCard(review: r)),
        ]);
      },
    );
  }
}

class _ReviewCard extends StatelessWidget {
  final ReviewModel review;
  const _ReviewCard({required this.review});

  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 8)],
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Row(children: List.generate(5, (i) => Icon(
              i < review.rating ? Icons.star : Icons.star_border,
              color: AppColors.warning, size: 18))),
            Text(timeago.format(review.createdAt, locale: 'fr'),
                style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
          ]),
          if (review.comment != null && review.comment!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(review.comment!,
                style: const TextStyle(color: AppColors.textSecondary, fontSize: 14)),
          ],
        ]),
      );
}
