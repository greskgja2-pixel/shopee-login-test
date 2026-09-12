part of 'main.dart';

class ResultPage extends StatefulWidget {
  final AnalysisResult result;
  final Future<List<AchievementDef>> Function(AnalysisResult) onFinalize;
  final AnalysisGeneratedCallback onGenerated;
  final bool fromHistory;
  final String? storedAnalysisId;
  final Future<void> Function(AnalysisResult)? onDelete;
  const ResultPage({
    super.key,
    required this.result,
    required this.onFinalize,
    required this.onGenerated,
    this.fromHistory = false,
    this.storedAnalysisId,
    this.onDelete,
  });

  @override
  State<ResultPage> createState() => _ResultPageState();
}

class _ResultPageState extends State<ResultPage> {
  bool finalizing = false;
  bool exporting = false;
  AchievementDef? lastAchievement;

  Future<String?> _createShareImage({AchievementDef? achievement}) async {
    try {
      final cache = await kShareChannel.invokeMethod<String>('cacheDir');
      if (cache == null || cache.isEmpty) return null;
      const width = 1080.0;
      const height = 1350.0;
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);

      final background = Paint()..color = const Color(0xFFFFF8F1);
      canvas.drawRect(const Rect.fromLTWH(0, 0, width, height), background);

      final border = Paint()
        ..color = kOrange
        ..style = PaintingStyle.stroke
        ..strokeWidth = 28;
      canvas.drawRRect(
        RRect.fromRectAndRadius(const Rect.fromLTWH(45, 45, 990, 1260), const Radius.circular(52)),
        border,
      );

      final innerGlow = Paint()
        ..color = const Color(0xFFFFE7D6)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 5;
      canvas.drawRRect(
        RRect.fromRectAndRadius(const Rect.fromLTWH(75, 75, 930, 1200), const Radius.circular(42)),
        innerGlow,
      );

      final gold = Paint()..color = const Color(0xFFFFB21A);
      final darkGold = Paint()..color = const Color(0xFFC77D00);
      final shield = Path()
        ..moveTo(540, 185)
        ..lineTo(690, 235)
        ..lineTo(670, 430)
        ..quadraticBezierTo(620, 505, 540, 545)
        ..quadraticBezierTo(460, 505, 410, 430)
        ..lineTo(390, 235)
        ..close();
      canvas.drawPath(shield, Paint()..color = const Color(0xFFCF3F08));
      canvas.drawPath(
        shield,
        Paint()
          ..color = gold.color
          ..style = PaintingStyle.stroke
          ..strokeWidth = 18,
      );

      final crown = Path()
        ..moveTo(455, 190)
        ..lineTo(480, 125)
        ..lineTo(525, 170)
        ..lineTo(560, 105)
        ..lineTo(600, 170)
        ..lineTo(640, 125)
        ..lineTo(665, 190)
        ..close();
      canvas.drawPath(crown, gold);
      canvas.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(460, 182, 200, 28), const Radius.circular(10)), darkGold);
      for (final x in [480.0, 560.0, 640.0]) {
        canvas.drawCircle(Offset(x, x == 560 ? 105 : 125), 12, gold);
      }

      for (var i = 0; i < 5; i++) {
        final y = 265.0 + i * 48;
        final leftLeaf = Path()
          ..moveTo(330, y)
          ..quadraticBezierTo(290, y - 22, 272, y + 8)
          ..quadraticBezierTo(305, y + 32, 330, y)
          ..close();
        final rightLeaf = Path()
          ..moveTo(750, y)
          ..quadraticBezierTo(790, y - 22, 808, y + 8)
          ..quadraticBezierTo(775, y + 32, 750, y)
          ..close();
        canvas.drawPath(leftLeaf, gold);
        canvas.drawPath(rightLeaf, gold);
      }

      final ribbon = RRect.fromRectAndRadius(const Rect.fromLTWH(380, 500, 320, 62), const Radius.circular(16));
      canvas.drawRRect(ribbon, gold);
      canvas.drawCircle(const Offset(540, 531), 18, darkGold);

      void text(
        String value,
        double y,
        double size,
        FontWeight weight,
        Color color, {
        double maxWidth = 860,
        int maxLines = 4,
      }) {
        final tp = TextPainter(
          text: TextSpan(text: value, style: TextStyle(fontSize: size, fontWeight: weight, color: color, height: 1.12)),
          textDirection: TextDirection.ltr,
          textAlign: TextAlign.center,
          maxLines: maxLines,
          ellipsis: '…',
        )..layout(maxWidth: maxWidth);
        tp.paint(canvas, Offset((width - tp.width) / 2, y));
      }

      text('SA', 275, 112, FontWeight.w900, const Color(0xFFFFF3D1), maxWidth: 300, maxLines: 1);
      text('SUPER ANÚNCIO', 600, 58, FontWeight.w900, kOrange, maxLines: 1);
      text('CONQUISTA DESBLOQUEADA', 674, 34, FontWeight.w800, const Color(0xFF262626), maxLines: 1);
      text(achievement?.title ?? 'Anúncio em evolução', 780, 54, FontWeight.w900, const Color(0xFF171717), maxWidth: 850, maxLines: 2);

      final scoreBox = Paint()..color = const Color(0xFFFFEADB);
      canvas.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(340, 895, 400, 76), const Radius.circular(38)), scoreBox);
      text('Nota ${widget.result.score}/100', 906, 42, FontWeight.w900, const Color(0xFFE7470A), maxLines: 1);

      text(widget.result.input.title, 1010, 30, FontWeight.w800, const Color(0xFF262626), maxWidth: 820, maxLines: 3);
      text('Analise. Otimize. Venda mais.', 1132, 30, FontWeight.w600, const Color(0xFF5B5B5B), maxLines: 1);

      final creditBg = Paint()..color = kOrange;
      canvas.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(405, 1192, 270, 54), const Radius.circular(27)), creditBg);
      text('By Gresk 2026', 1200, 28, FontWeight.w700, Colors.white, maxWidth: 260, maxLines: 1);
      text('Que Deus e família seja sua prioridade.', 1260, 20, FontWeight.w600, const Color(0xFF505050), maxWidth: 820, maxLines: 1);
      text('Gresk 2026', 1290, 18, FontWeight.w600, const Color(0xFF6A6A6A), maxLines: 1);

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

  Future<void> _exportPdf() async {
    if (exporting) return;
    setState(() => exporting = true);
    final path = await PdfExporter.create(widget.result);
    if (!mounted) return;
    setState(() => exporting = false);
    if (path == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Não consegui gerar o PDF agora.')));
      return;
    }
    try {
      await kShareChannel.invokeMethod('shareFile', {
        'path': path,
        'mime': 'application/pdf',
        'title': 'Exportar relatório do Super Anúncio',
      });
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('PDF criado, mas não consegui abrir o compartilhamento.')));
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
              const Text('O cartão de conquista segue o novo visual dourado do Super Anúncio.', textAlign: TextAlign.center),
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
          content: Text('O Super Anúncio agendou uma notificação para ${formatDate(due)}. A tarefa também ficou salva na nova aba Tarefas.'),
          actions: [FilledButton(onPressed: () => Navigator.pop(context), child: const Text('Entendi'))],
        ),
      );
    }
    if (mounted) Navigator.popUntil(context, (route) => route.isFirst);
  }

  void _newAnalysis() {
    Navigator.popUntil(context, (route) => route.isFirst);
  }

  void _reanalyze() {
    Navigator.of(context).pushReplacement(MaterialPageRoute(
      builder: (_) => PreparationWizard(
        initialUrl: widget.result.input.url,
        previousAnalysisId: widget.storedAnalysisId,
        onGenerated: widget.onGenerated,
        onFinalize: widget.onFinalize,
      ),
    ));
  }

  Future<void> _delete() async {
    if (widget.onDelete == null) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Apagar análise?'),
        content: const Text('Isso apaga o histórico deste produto e as tarefas de reanálise ligadas a ele neste aparelho.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Apagar')),
        ],
      ),
    );
    if (ok != true) return;
    await widget.onDelete!(widget.result);
    if (mounted) Navigator.popUntil(context, (route) => route.isFirst);
  }

  @override
  Widget build(BuildContext context) {
    final r = widget.result;
    final scoreColor = scoreColorFor(r.score);
    return Scaffold(
      appBar: AppBar(title: const Text('Resultado da análise')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 220),
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
          const SizedBox(height: 5),
          Text('Toque em uma categoria para ver por que recebeu a nota, como melhorar e dicas práticas.', style: Theme.of(context).textTheme.bodySmall),
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
              Expanded(child: OutlinedButton.icon(onPressed: exporting ? null : _exportPdf, icon: const Icon(Icons.picture_as_pdf_outlined), label: Text(exporting ? 'Gerando...' : 'Exportar'))),
            ]),
            const SizedBox(height: 8),
            if (widget.fromHistory) ...[
              Row(children: [
                Expanded(child: OutlinedButton.icon(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close), label: const Text('Fechar'))),
                const SizedBox(width: 8),
                Expanded(child: FilledButton.tonalIcon(onPressed: _reanalyze, icon: const Icon(Icons.refresh), label: const Text('Reanalisar'))),
              ]),
              const SizedBox(height: 8),
              SizedBox(width: double.infinity, child: TextButton.icon(onPressed: _delete, icon: const Icon(Icons.delete_outline), label: const Text('Apagar'))),
            ] else ...[
              SizedBox(width: double.infinity, child: OutlinedButton.icon(onPressed: _newAnalysis, icon: const Icon(Icons.add_circle_outline), label: const Text('Nova análise'))),
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
          ],
        ),
      ),
    );
  }
}
