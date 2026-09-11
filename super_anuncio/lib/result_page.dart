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
  AchievementDef? lastAchievement;

  Future<String?> _createShareImage({AchievementDef? achievement}) async {
    try {
      final cache = await kShareChannel.invokeMethod<String>('cacheDir');
      if (cache == null || cache.isEmpty) return null;
      const width = 1080.0;
      const height = 1350.0;
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      final bg = Paint()..color = const Color(0xFFFFF5F0);
      canvas.drawRect(const Rect.fromLTWH(0, 0, width, height), bg);

      final orange = Paint()..color = kOrange;
      canvas.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(55, 55, 970, 1240), const Radius.circular(48)), orange);
      final inner = Paint()..color = Colors.white;
      canvas.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(80, 80, 920, 1190), const Radius.circular(38)), inner);

      // Troféu estilizado + gráfico subindo.
      final gold = Paint()..color = const Color(0xFFFFC72C);
      final darkGold = Paint()..color = const Color(0xFFC88700);
      canvas.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(390, 190, 300, 260), const Radius.circular(48)), gold);
      canvas.drawCircle(const Offset(380, 300), 90, darkGold);
      canvas.drawCircle(const Offset(700, 300), 90, darkGold);
      canvas.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(430, 420, 220, 55), const Radius.circular(20)), darkGold);
      canvas.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(360, 470, 360, 65), const Radius.circular(22)), gold);
      final trend = Paint()..color = const Color(0xFF19A463)..strokeWidth = 24..style = PaintingStyle.stroke..strokeCap = StrokeCap.round..strokeJoin = StrokeJoin.round;
      final path = Path()..moveTo(430, 365)..lineTo(500, 315)..lineTo(565, 340)..lineTo(650, 245);
      canvas.drawPath(path, trend);
      canvas.drawLine(const Offset(650, 245), const Offset(650, 310), trend);
      canvas.drawLine(const Offset(650, 245), const Offset(590, 250), trend);

      void text(String value, double y, double size, FontWeight weight, Color color, {double maxWidth = 840, TextAlign align = TextAlign.center}) {
        final tp = TextPainter(
          text: TextSpan(text: value, style: TextStyle(fontSize: size, fontWeight: weight, color: color, height: 1.15)),
          textDirection: TextDirection.ltr,
          textAlign: align,
          maxLines: 4,
        )..layout(maxWidth: maxWidth);
        tp.paint(canvas, Offset((width - tp.width) / 2, y));
      }

      text('SUPER ANÚNCIO', 590, 58, FontWeight.w900, kOrange);
      text('CONQUISTA DESBLOQUEADA', 680, 36, FontWeight.w900, const Color(0xFF1D1D1F));
      text(achievement?.title ?? 'Anúncio em evolução', 750, 54, FontWeight.w900, const Color(0xFF1D1D1F));
      text('Nota ${widget.result.score}/100', 860, 46, FontWeight.w800, kOrange);
      text(widget.result.input.title, 945, 34, FontWeight.w700, const Color(0xFF444444), maxWidth: 820);
      text('Analise. Otimize. Venda mais. 📈', 1160, 30, FontWeight.w700, const Color(0xFF666666));

      final picture = recorder.endRecording();
      final image = await picture.toImage(width.toInt(), height.toInt());
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      if (data == null) return null;
      final file = File('$cache/super_anuncio_conquista_${DateTime.now().millisecondsSinceEpoch}.png');
      await file.writeAsBytes(data.buffer.asUint8List(), flush: true);
      return file.path;
    } catch (_) {
      return null;
    }
  }

  String _shareText() {
    final r = widget.result;
    final top = r.dimensions.where((d) => d.score < d.maxScore * .75).take(3).map((d) => '• ${d.name}: ${d.action}').join('\n');
    return 'SUPER ANÚNCIO — Auditoria\n${r.input.title}\nNota: ${r.score}/100\n\nPrincipais ações:\n$top\n\nReanalise após aplicar as melhorias.';
  }

  Future<void> _share({AchievementDef? achievement}) async {
    final text = _shareText();
    final path = await _createShareImage(achievement: achievement ?? lastAchievement);
    try {
      if (path != null) {
        await kShareChannel.invokeMethod('shareImage', {'path': path, 'text': text});
      } else {
        await kShareChannel.invokeMethod('shareText', text);
      }
    } catch (_) {
      await Clipboard.setData(ClipboardData(text: text));
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Resumo copiado.')));
    }
  }

  Future<void> _scheduleReminder() async {
    final due = widget.result.reanalyzeAt;
    if (due == null) return;
    try {
      await kShareChannel.invokeMethod('scheduleReanalysis', {
        'title': widget.result.input.title,
        'url': widget.result.input.url,
        'at': due.millisecondsSinceEpoch,
      });
    } catch (_) {}
  }

  Future<void> _finalize() async {
    if (finalizing) return;
    setState(() => finalizing = true);
    List<AchievementDef> unlocked = const [];
    if (!widget.result.finalized) {
      unlocked = await widget.onFinalize(widget.result);
      await _scheduleReminder();
    }
    if (!mounted) return;
    setState(() {
      finalizing = false;
      if (unlocked.isNotEmpty) lastAchievement = unlocked.first;
    });

    if (unlocked.isNotEmpty) {
      final first = unlocked.first;
      await showDialog<void>(
        context: context,
        builder: (_) => AlertDialog(
          icon: const Icon(Icons.emoji_events, color: Colors.amber, size: 52),
          title: const Text('Conquista desbloqueada!'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(unlocked.length == 1 ? first.title : '${first.title}\n\nE mais ${unlocked.length - 1} conquista(s).', textAlign: TextAlign.center),
              const SizedBox(height: 10),
              const Text('Seu cartão de conquista tem um troféu e gráfico de evolução 📈.', textAlign: TextAlign.center),
            ],
          ),
          actions: [
            TextButton.icon(onPressed: () => _share(achievement: first), icon: const Icon(Icons.share), label: const Text('Compartilhar conquista')),
            FilledButton(onPressed: () => Navigator.pop(context), child: const Text('Boa!')),
          ],
        ),
      );
    }

    if (!mounted) return;
    final due = widget.result.reanalyzeAt;
    if (due != null) {
      await showDialog<void>(
        context: context,
        builder: (_) => AlertDialog(
          icon: const Icon(Icons.notifications_active_outlined, size: 44),
          title: const Text('Tarefa criada para daqui a 7 dias'),
          content: Text('O Super Anúncio agendou uma notificação para ${formatDate(due)}. Ao tocar nela, o app abre com este anúncio pronto para reanálise.'),
          actions: [FilledButton(onPressed: () => Navigator.pop(context), child: const Text('Entendi'))],
        ),
      );
    }
    if (mounted) Navigator.popUntil(context, (route) => route.isFirst);
  }

  void _newAnalysis() {
    Navigator.popUntil(context, (route) => route.isFirst);
  }

  @override
  Widget build(BuildContext context) {
    final r = widget.result;
    final scoreColor = scoreColorFor(r.score);
    return Scaffold(
      appBar: AppBar(title: const Text('Resultado da análise')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 170),
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
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(children: [
              Expanded(child: OutlinedButton.icon(onPressed: _share, icon: const Icon(Icons.share_outlined), label: const Text('Compartilhar'))),
              const SizedBox(width: 10),
              Expanded(child: OutlinedButton.icon(onPressed: _newAnalysis, icon: const Icon(Icons.add_circle_outline), label: const Text('Nova análise'))),
            ]),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: finalizing ? null : _finalize,
                icon: const Icon(Icons.check_circle_outline),
                label: Text(finalizing ? 'Finalizando...' : 'FINALIZAR ANÁLISE'),
                style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 15), textStyle: const TextStyle(fontWeight: FontWeight.w900)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
