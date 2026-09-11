part of 'main.dart';

class ResultPage extends StatefulWidget {
  final AnalysisResult result;
  final Future<List<AchievementDef>> Function(AnalysisResult) onFinalize;
  const ResultPage({super.key, required this.result, required this.onFinalize});

  @override
  State<ResultPage> createState() => _ResultPageState();
}

class _ResultPageState extends State<ResultPage> {
  bool finalizing = false;

  Future<void> _share() async {
    final r = widget.result;
    final top = r.dimensions.where((d) => d.score < d.maxScore * .75).take(3).map((d) => '• ${d.name}: ${d.action}').join('\n');
    final text = 'SUPER ANÚNCIO — Auditoria\n${r.input.title}\nNota: ${r.score}/100\n\nPrincipais ações:\n$top\n\nReanalise após aplicar as melhorias.';
    try {
      await kShareChannel.invokeMethod('shareText', text);
    } catch (_) {
      await Clipboard.setData(ClipboardData(text: text));
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Resumo copiado.')));
    }
  }

  Future<void> _finalize() async {
    if (widget.result.finalized) {
      Navigator.popUntil(context, (route) => route.isFirst);
      return;
    }
    setState(() => finalizing = true);
    final unlocked = await widget.onFinalize(widget.result);
    if (!mounted) return;
    setState(() => finalizing = false);
    if (unlocked.isNotEmpty) {
      final first = unlocked.first;
      await showDialog<void>(
        context: context,
        builder: (_) => AlertDialog(
          icon: const Icon(Icons.emoji_events, color: Colors.amber, size: 46),
          title: const Text('Conquista desbloqueada!'),
          content: Text(unlocked.length == 1 ? first.title : '${first.title}\n\nE mais ${unlocked.length - 1} conquista(s).'),
          actions: [FilledButton(onPressed: () => Navigator.pop(context), child: const Text('Boa!'))],
        ),
      );
    }
    if (!mounted) return;
    final due = widget.result.reanalyzeAt!;
    await showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        icon: const Icon(Icons.event_repeat, size: 42),
        title: const Text('Volte em 7 dias'),
        content: Text('Depois de aplicar as mudanças, reanalise este mesmo anúncio em ${formatDate(due)} para comparar a evolução da nota.'),
        actions: [FilledButton(onPressed: () => Navigator.pop(context), child: const Text('Entendi'))],
      ),
    );
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final r = widget.result;
    final scoreColor = scoreColorFor(r.score);
    return Scaffold(
      appBar: AppBar(title: const Text('Resultado da análise')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 120),
        children: [
          Card(
            color: Theme.of(context).colorScheme.primaryContainer.withOpacity(.25),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(children: [
                const SaShield(size: 65),
                const SizedBox(height: 10),
                Text('${r.score}/100', style: TextStyle(fontSize: 42, fontWeight: FontWeight.w900, color: scoreColor)),
                const Text('Pontuação geral', style: TextStyle(fontWeight: FontWeight.w800)),
                const SizedBox(height: 12),
                ScoreGauge(score: r.score, size: 120),
                const SizedBox(height: 10),
                Text(r.summary, textAlign: TextAlign.center),
              ]),
            ),
          ),
          const SizedBox(height: 16),
          FilledButton.tonalIcon(onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => CoachPage(result: r))), icon: const Icon(Icons.school_outlined), label: const Text('Rever tutorial passo a passo')),
          const SizedBox(height: 20),
          Text('Raio-X completo', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900)),
          const SizedBox(height: 10),
          for (final d in r.dimensions) DimensionCard(dimension: d),
          const SizedBox(height: 20),
          Text('Soluções prontas', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900)),
          const SizedBox(height: 10),
          SolutionCard(icon: Icons.title, title: 'Título', current: r.input.title, optimized: r.optimizedTitle),
          const SizedBox(height: 10),
          SolutionCard(icon: Icons.description_outlined, title: 'Descrição', current: r.input.description.isEmpty ? 'Não informada' : r.input.description, optimized: r.optimizedDescription),
          const SizedBox(height: 10),
          SolutionCard(icon: Icons.category_outlined, title: 'Categoria', current: r.input.category.isEmpty ? 'Não informada' : r.input.category, optimized: r.suggestedCategory),
          const SizedBox(height: 20),
          CompetitiveSummary(result: r),
          if (r.input.adsActive) ...[
            const SizedBox(height: 16),
            AdsSummary(result: r),
          ],
          if (r.finalized && r.reanalyzeAt != null) ...[
            const SizedBox(height: 18),
            NoticeBox(icon: Icons.event_repeat, text: 'Reanálise recomendada em ${formatDate(r.reanalyzeAt!)}.'),
          ],
        ],
      ),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(14, 8, 14, 12),
        child: Row(children: [
          Expanded(child: OutlinedButton.icon(onPressed: _share, icon: const Icon(Icons.share_outlined), label: const Text('Compartilhar'))),
          const SizedBox(width: 10),
          Expanded(
            child: FilledButton.icon(
              onPressed: finalizing ? null : _finalize,
              icon: Icon(r.finalized ? Icons.add_circle_outline : Icons.check_circle_outline),
              label: Text(r.finalized ? 'Nova análise' : 'Finalizar'),
            ),
          ),
        ]),
      ),
    );
  }
}
