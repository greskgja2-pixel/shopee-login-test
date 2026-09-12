part of 'main.dart';

class HistoryPage extends StatelessWidget {
  final PersistedAppState state;
  final AnalysisGeneratedCallback onGenerated;
  final Future<List<AchievementDef>> Function(AnalysisResult) onFinalize;
  final Future<void> Function(AnalysisResult) onDeleteProduct;
  const HistoryPage({
    super.key,
    required this.state,
    required this.onGenerated,
    required this.onFinalize,
    required this.onDeleteProduct,
  });

  List<StoredAnalysis> _finalized(ProductHistoryRecord product) {
    final items = product.analyses.where((a) => a.result.finalized).toList()
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
    return items;
  }

  @override
  Widget build(BuildContext context) {
    final products = state.products.where((p) => _finalized(p).isNotEmpty).toList()
      ..sort((a, b) => _finalized(b).last.createdAt.compareTo(_finalized(a).last.createdAt));

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Histórico', style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w900)),
          const SizedBox(height: 4),
          const Text('Cada produto mantém todas as auditorias e reanálises finalizadas ao longo do tempo.'),
          const SizedBox(height: 14),
          Expanded(
            child: products.isEmpty
                ? const Center(child: Text('Suas análises finalizadas aparecerão aqui.'))
                : ListView.separated(
                    itemCount: products.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (_, i) {
                      final product = products[i];
                      final analyses = _finalized(product);
                      final stored = analyses.last;
                      final r = stored.result;
                      final delta = analyses.length > 1 ? r.score - analyses.first.result.score : 0;
                      return Card(
                        child: InkWell(
                          borderRadius: BorderRadius.circular(16),
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => ResultPage(
                                result: r,
                                onFinalize: onFinalize,
                                onGenerated: onGenerated,
                                fromHistory: true,
                                storedAnalysisId: stored.id,
                                onDelete: onDeleteProduct,
                              ),
                            ),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(14),
                            child: Row(children: [
                              if (product.imageUrl != null)
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(12),
                                  child: SizedBox(
                                    width: 72,
                                    height: 72,
                                    child: Image.network(product.imageUrl!, fit: BoxFit.cover, errorBuilder: (_, __, ___) => ScoreGauge(score: r.score, size: 72)),
                                  ),
                                )
                              else
                                ScoreGauge(score: r.score, size: 72),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                  Text(product.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w900)),
                                  const SizedBox(height: 6),
                                  Row(children: [
                                    Text('Última nota: ${r.score}', style: TextStyle(color: scoreColorFor(r.score), fontWeight: FontWeight.w900)),
                                    if (analyses.length > 1) ...[
                                      const SizedBox(width: 8),
                                      Icon(delta > 0 ? Icons.trending_up : delta < 0 ? Icons.trending_down : Icons.trending_flat, size: 17, color: delta > 0 ? Colors.green : delta < 0 ? Colors.red : Colors.grey),
                                      const SizedBox(width: 3),
                                      Text('${delta > 0 ? '+' : ''}$delta desde a primeira', style: Theme.of(context).textTheme.bodySmall),
                                    ],
                                  ]),
                                  const SizedBox(height: 3),
                                  Text('${analyses.length} análise(s) finalizada(s) • ${formatDate(stored.createdAt)}', style: Theme.of(context).textTheme.bodySmall),
                                  if (r.reanalyzeAt != null) Text('Próxima revisão: ${formatDate(r.reanalyzeAt!)}', style: Theme.of(context).textTheme.bodySmall),
                                ]),
                              ),
                              const Icon(Icons.chevron_right),
                            ]),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ]),
      ),
    );
  }
}
