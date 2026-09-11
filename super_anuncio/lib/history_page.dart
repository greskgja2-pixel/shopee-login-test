part of 'main.dart';

class HistoryPage extends StatelessWidget {
  final List<AnalysisResult> history;
  final Future<List<AchievementDef>> Function(AnalysisResult) onFinalize;
  const HistoryPage({super.key, required this.history, required this.onFinalize});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Histórico', style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w900)),
          const SizedBox(height: 4),
          const Text('Acompanhe a nota de cada anúncio e a data da próxima reanálise.'),
          const SizedBox(height: 14),
          Expanded(
            child: history.isEmpty
                ? const Center(child: Text('Suas análises aparecerão aqui.'))
                : ListView.separated(
                    itemCount: history.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (_, i) {
                      final r = history[i];
                      return Card(
                        child: InkWell(
                          borderRadius: BorderRadius.circular(16),
                          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ResultPage(result: r, onFinalize: onFinalize))),
                          child: Padding(
                            padding: const EdgeInsets.all(14),
                            child: Row(children: [
                              ScoreGauge(score: r.score, size: 78),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                  Text(r.input.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w900)),
                                  const SizedBox(height: 5),
                                  Text(r.finalized ? 'Finalizada' : 'Em andamento', style: TextStyle(color: r.finalized ? Colors.green : Colors.orange, fontWeight: FontWeight.w700)),
                                  if (r.reanalyzeAt != null) Text('Reanalisar: ${formatDate(r.reanalyzeAt!)}', style: Theme.of(context).textTheme.bodySmall),
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
