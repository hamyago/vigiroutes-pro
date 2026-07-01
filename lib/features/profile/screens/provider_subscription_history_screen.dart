import 'package:flutter/material.dart';
import '../../../core/services/api_service.dart';

/// Historique des souscriptions du prestataire (abonnements crédits passés).
class ProviderSubscriptionHistoryScreen extends StatefulWidget {
  const ProviderSubscriptionHistoryScreen({super.key});

  @override
  State<ProviderSubscriptionHistoryScreen> createState() =>
      _ProviderSubscriptionHistoryScreenState();
}

class _ProviderSubscriptionHistoryScreenState
    extends State<ProviderSubscriptionHistoryScreen> {
  late Future<List<dynamic>> _future;

  @override
  void initState() {
    super.initState();
    _future = ApiService.instance.getProviderSubscriptionHistory();
  }

  Future<void> _reload() async {
    setState(() {
      _future = ApiService.instance.getProviderSubscriptionHistory();
    });
    await _future;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Historique des souscriptions')),
      body: RefreshIndicator(
        onRefresh: _reload,
        child: FutureBuilder<List<dynamic>>(
          future: _future,
          builder: (context, snap) {
            if (snap.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snap.hasError) {
              return ListView(children: const [
                SizedBox(height: 120),
                Center(child: Text('Impossible de charger l\'historique.')),
              ]);
            }
            final subs = snap.data ?? const [];
            if (subs.isEmpty) {
              return ListView(children: const [
                SizedBox(height: 120),
                Center(child: Text('Aucune souscription pour le moment.')),
              ]);
            }
            return ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: subs.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (_, i) =>
                  _SubTile(sub: subs[i] as Map<String, dynamic>),
            );
          },
        ),
      ),
    );
  }
}

class _SubTile extends StatelessWidget {
  final Map<String, dynamic> sub;
  const _SubTile({required this.sub});

  static const _statusLabels = {
    'active': ('Actif', Colors.green),
    'exhausted': ('Épuisé', Colors.orange),
    'expired': ('Expiré', Colors.grey),
    'cancelled': ('Annulé', Colors.red),
  };

  String _fmtDate(dynamic v) {
    if (v == null) return '—';
    final d = DateTime.tryParse(v.toString());
    if (d == null) return '—';
    return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
  }

  double _toD(dynamic v) =>
      v == null ? 0 : (v is num ? v.toDouble() : double.tryParse(v.toString()) ?? 0);

  @override
  Widget build(BuildContext context) {
    final plan = sub['plan'] as Map<String, dynamic>?;
    final planName = plan?['name']?.toString() ?? 'Abonnement';
    final status = sub['status']?.toString() ?? '';
    final label = _statusLabels[status];
    final initial = _toD(sub['credit_initial']);
    final balance = _toD(sub['credit_balance']);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(planName,
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w700)),
              ),
              if (label != null)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: label.$2.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(label.$1,
                      style: TextStyle(
                          color: label.$2,
                          fontSize: 12,
                          fontWeight: FontWeight.w600)),
                ),
            ],
          ),
          const SizedBox(height: 10),
          _line('Crédit', '${balance.toStringAsFixed(0)} / ${initial.toStringAsFixed(0)} FCFA'),
          _line('Début', _fmtDate(sub['starts_at'])),
          _line('Expiration', _fmtDate(sub['expires_at'])),
        ],
      ),
    );
  }

  Widget _line(String k, String v) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(
          children: [
            Text(k, style: const TextStyle(color: Colors.grey)),
            const Spacer(),
            Text(v, style: const TextStyle(fontWeight: FontWeight.w600)),
          ],
        ),
      );
}
