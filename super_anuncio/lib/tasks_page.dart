part of 'main.dart';

class TasksPage extends StatelessWidget {
  final PersistedAppState state;
  final AnalysisGeneratedCallback onGenerated;
  final Future<List<AchievementDef>> Function(AnalysisResult) onFinalize;
  const TasksPage({super.key, required this.state, required this.onGenerated, required this.onFinalize});

  @override
  Widget build(BuildContext context) {
    final pending = state.tasks.where((t) => !t.completed).toList()..sort((a, b) => a.dueAt.compareTo(b.dueAt));
    final done = state.tasks.where((t) => t.completed).toList()..sort((a, b) => (b.completedAt ?? b.dueAt).compareTo(a.completedAt ?? a.dueAt));

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(18),
        children: [
          Text('Tarefas', style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w900)),
          const SizedBox(height: 4),
          const Text('Reanálises programadas e comparações depois das otimizações.'),
          const SizedBox(height: 18),
          _SectionTitle(icon: Icons.schedule, title: 'Próximas reanálises', count: pending.length),
          const SizedBox(height: 10),
          if (pending.isEmpty)
            const NoticeBox(icon: Icons.task_alt, text: 'Nenhuma reanálise pendente no momento.')
          else
            for (final task in pending) ...[
              _PendingTaskCard(task: task, state: state, onGenerated: onGenerated, onFinalize: onFinalize),
              const SizedBox(height: 10),
            ],
          const SizedBox(height: 24),
          _SectionTitle(icon: Icons.compare_arrows, title: 'Reanálises concluídas', count: done.length),
          const SizedBox(height: 10),
          if (done.isEmpty)
            const Text('Quando um anúncio for reanalisado, a evolução aparecerá aqui.')
          else
            for (final task in done) ...[
              _CompletedTaskCard(task: task, state: state),
              const SizedBox(height: 10),
            ],
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final IconData icon;
  final String title;
  final int count;
  const _SectionTitle({required this.icon, required this.title, required this.count});
  @override
  Widget build(BuildContext context) => Row(children: [
        Icon(icon),
        const SizedBox(width: 8),
        Expanded(child: Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900))),
        Chip(label: Text('$count')),
      ]);
}

class _PendingTaskCard extends StatelessWidget {
  final ReanalysisTask task;
  final PersistedAppState state;
  final AnalysisGeneratedCallback onGenerated;
  final Future<List<AchievementDef>> Function(AnalysisResult) onFinalize;
  const _PendingTaskCard({required this.task, required this.state, required this.onGenerated, required this.onFinalize});

  @override
  Widget build(BuildContext context) {
    final days = task.dueAt.difference(DateTime.now()).inDays;
    final label = days < 0 ? 'Atrasada' : days == 0 ? 'Hoje' : 'Em $days dia(s)';
    final previous = findStoredAnalysis(state, task.sourceAnalysisId)?.result.input;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(task.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w900)),
          const SizedBox(height: 6),
          Row(children: [
            Icon(Icons.event_repeat, size: 18, color: Theme.of(context).colorScheme.primary),
            const SizedBox(width: 6),
            Text('$label • ${formatDate(task.dueAt)}', style: const TextStyle(fontWeight: FontWeight.w700)),
          ]),
          if (previous?.roasTarget != null) ...[
            const SizedBox(height: 6),
            Text('Meta de ROAS anterior: ${previous!.roasTarget!.toStringAsFixed(2)}', style: Theme.of(context).textTheme.bodySmall),
          ],
          const SizedBox(height: 11),
          SizedBox(
            width: double.infinity,
            child: FilledButton.tonalIcon(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => PreparationWizard(
                    initialUrl: task.url,
                    previousAnalysisId: task.sourceAnalysisId,
                    previousInput: previous,
                    onGenerated: onGenerated,
                    onFinalize: onFinalize,
                  ),
                ),
              ),
              icon: const Icon(Icons.refresh),
              label: const Text('Reanalisar agora'),
            ),
          ),
        ]),
      ),
    );
  }
}

class _CompletedTaskCard extends StatelessWidget {
  final ReanalysisTask task;
  final PersistedAppState state;
  const _CompletedTaskCard({required this.task, required this.state});

  @override
  Widget build(BuildContext context) {
    final before = findStoredAnalysis(state, task.sourceAnalysisId)?.result;
    final after = task.completedAnalysisId == null ? null : findStoredAnalysis(state, task.completedAnalysisId!)?.result;
    final scoreDelta = before == null || after == null ? null : after.score - before.score;
    final soldDelta = _numDelta(before?.input.product?.sold?.toDouble(), after?.input.product?.sold?.toDouble());
    final roasDelta = _numDelta(before?.input.roas7d, after?.input.roas7d);
    final roasTargetDelta = _numDelta(before?.input.roasTarget, after?.input.roasTarget);

    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: before == null || after == null
            ? null
            : () => Navigator.push(context, MaterialPageRoute(builder: (_) => TaskComparisonPage(task: task, state: state))),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(child: Text(task.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w900))),
              const Icon(Icons.chevron_right),
            ]),
            const SizedBox(height: 8),
            Wrap(spacing: 8, runSpacing: 8, children: [
              if (scoreDelta != null) _DeltaChip(label: 'Nota', delta: scoreDelta.toDouble(), decimals: 0),
              if (soldDelta != null) _DeltaChip(label: 'Vendidos', delta: soldDelta, decimals: 0),
              if (roasDelta != null) _DeltaChip(label: 'ROAS', delta: roasDelta, decimals: 2),
              if (roasTargetDelta != null) _DeltaChip(label: 'ROAS alvo', delta: roasTargetDelta, decimals: 2, neutralDirection: true),
            ]),
            if (task.completedAt != null) ...[
              const SizedBox(height: 7),
              Text('Reanalisado em ${formatDate(task.completedAt!)}', style: Theme.of(context).textTheme.bodySmall),
            ],
          ]),
        ),
      ),
    );
  }
}

class _DeltaChip extends StatelessWidget {
  final String label;
  final double delta;
  final int decimals;
  final bool neutralDirection;
  const _DeltaChip({required this.label, required this.delta, this.decimals = 1, this.neutralDirection = false});
  @override
  Widget build(BuildContext context) {
    final positive = delta > 0;
    final negative = delta < 0;
    final icon = positive ? Icons.trending_up : negative ? Icons.trending_down : Icons.trending_flat;
    final color = neutralDirection ? Theme.of(context).colorScheme.primary : positive ? Colors.green : negative ? Colors.red : Colors.grey;
    final sign = delta > 0 ? '+' : '';
    return Chip(
      avatar: Icon(icon, size: 17, color: color),
      label: Text('$label $sign${delta.toStringAsFixed(decimals)}'),
      side: BorderSide(color: color.withOpacity(.25)),
    );
  }
}

class TaskComparisonPage extends StatelessWidget {
  final ReanalysisTask task;
  final PersistedAppState state;
  const TaskComparisonPage({super.key, required this.task, required this.state});

  @override
  Widget build(BuildContext context) {
    final before = findStoredAnalysis(state, task.sourceAnalysisId)?.result;
    final after = task.completedAnalysisId == null ? null : findStoredAnalysis(state, task.completedAnalysisId!)?.result;
    if (before == null || after == null) {
      return const Scaffold(body: Center(child: Text('Comparação indisponível.')));
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Antes × depois')),
      body: ListView(
        padding: const EdgeInsets.all(18),
        children: [
          Text(task.title, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900)),
          const SizedBox(height: 6),
          const Text('Veja o que mudou desde a análise anterior.'),
          const SizedBox(height: 18),
          _CompareMetric(title: 'Pontuação geral', before: '${before.score}', after: '${after.score}', delta: (after.score - before.score).toDouble()),
          _CompareMetric(title: 'Preço', before: before.input.price == null ? '—' : money(before.input.price!), after: after.input.price == null ? '—' : money(after.input.price!), delta: _numDelta(before.input.price, after.input.price)),
          _CompareMetric(title: 'Vendidos', before: '${before.input.product?.sold ?? '—'}', after: '${after.input.product?.sold ?? '—'}', delta: _numDelta(before.input.product?.sold?.toDouble(), after.input.product?.sold?.toDouble())),
          _CompareMetric(title: 'Avaliação', before: before.input.product?.rating?.toStringAsFixed(1) ?? '—', after: after.input.product?.rating?.toStringAsFixed(1) ?? '—', delta: _numDelta(before.input.product?.rating, after.input.product?.rating)),
          _CompareMetric(title: 'ROAS', before: before.input.roas7d?.toStringAsFixed(2) ?? '—', after: after.input.roas7d?.toStringAsFixed(2) ?? '—', delta: _numDelta(before.input.roas7d, after.input.roas7d)),
          _CompareMetric(title: 'ROAS alvo', before: before.input.roasTarget?.toStringAsFixed(2) ?? '—', after: after.input.roasTarget?.toStringAsFixed(2) ?? '—', delta: _numDelta(before.input.roasTarget, after.input.roasTarget), neutralDirection: true),
          _CompareMetric(title: 'Gasto em Ads', before: before.input.adsSpend7d == null ? '—' : money(before.input.adsSpend7d!), after: after.input.adsSpend7d == null ? '—' : money(after.input.adsSpend7d!), delta: _numDelta(before.input.adsSpend7d, after.input.adsSpend7d), lowerIsBetter: true),
          if (before.input.productCost != null || after.input.productCost != null)
            _CompareMetric(title: 'Custo do produto', before: before.input.productCost == null ? '—' : money(before.input.productCost!), after: after.input.productCost == null ? '—' : money(after.input.productCost!), delta: _numDelta(before.input.productCost, after.input.productCost), lowerIsBetter: true),
          const SizedBox(height: 20),
          Text('Histórico deste produto', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900)),
          const SizedBox(height: 10),
          ..._timelineFor(state, task.productKey).map((a) => Card(
                child: ListTile(
                  leading: ScoreGauge(score: a.result.score, size: 58),
                  title: Text(formatDate(a.createdAt), style: const TextStyle(fontWeight: FontWeight.w800)),
                  subtitle: Text(a.result.summary, maxLines: 2, overflow: TextOverflow.ellipsis),
                ),
              )),
        ],
      ),
    );
  }

  List<StoredAnalysis> _timelineFor(PersistedAppState state, String key) {
    for (final product in state.products) {
      if (product.key == key) {
        final copy = [...product.analyses]..sort((a, b) => b.createdAt.compareTo(a.createdAt));
        return copy;
      }
    }
    return const [];
  }
}

class _CompareMetric extends StatelessWidget {
  final String title;
  final String before;
  final String after;
  final double? delta;
  final bool lowerIsBetter;
  final bool neutralDirection;
  const _CompareMetric({required this.title, required this.before, required this.after, required this.delta, this.lowerIsBetter = false, this.neutralDirection = false});

  @override
  Widget build(BuildContext context) {
    final d = delta;
    final better = neutralDirection || d == null || d == 0 ? null : lowerIsBetter ? d < 0 : d > 0;
    final color = neutralDirection ? Theme.of(context).colorScheme.primary : better == null ? Colors.grey : better ? Colors.green : Colors.red;
    final icon = d == null || d == 0 ? Icons.trending_flat : d > 0 ? Icons.trending_up : Icons.trending_down;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(children: [
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.w900)),
            const SizedBox(height: 6),
            Text('$before  →  $after'),
          ])),
          Icon(icon, color: color),
        ]),
      ),
    );
  }
}

double? _numDelta(double? before, double? after) {
  if (before == null || after == null) return null;
  return after - before;
}
