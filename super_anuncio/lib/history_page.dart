part of 'main.dart';

enum _HistoryMetric { score, sold, periodSales, price, roas, adsSpend, adsGmv, rating, reviews }

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
                      final firstDelta = analyses.length > 1 ? r.score - analyses.first.result.score : 0;
                      final previousDelta = analyses.length > 1 ? r.score - analyses[analyses.length - 2].result.score : 0;
                      return Card(
                        child: InkWell(
                          borderRadius: BorderRadius.circular(16),
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => ProductHistoryDetailPage(
                                product: product,
                                onGenerated: onGenerated,
                                onFinalize: onFinalize,
                                onDeleteProduct: onDeleteProduct,
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
                                  Wrap(spacing: 8, runSpacing: 3, crossAxisAlignment: WrapCrossAlignment.center, children: [
                                    Text('Última nota: ${r.score}', style: TextStyle(color: scoreColorFor(r.score), fontWeight: FontWeight.w900)),
                                    if (analyses.length > 1) _DeltaInline(value: previousDelta, suffix: 'desde a última'),
                                    if (analyses.length > 2) _DeltaInline(value: firstDelta, suffix: 'desde a primeira'),
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

class _DeltaInline extends StatelessWidget {
  final int value;
  final String suffix;
  const _DeltaInline({required this.value, required this.suffix});

  @override
  Widget build(BuildContext context) {
    final color = value > 0 ? Colors.green : value < 0 ? Colors.red : Colors.grey;
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(value > 0 ? Icons.trending_up : value < 0 ? Icons.trending_down : Icons.trending_flat, size: 17, color: color),
      const SizedBox(width: 3),
      Text('${value > 0 ? '+' : ''}$value $suffix', style: Theme.of(context).textTheme.bodySmall),
    ]);
  }
}

class ProductHistoryDetailPage extends StatefulWidget {
  final ProductHistoryRecord product;
  final AnalysisGeneratedCallback onGenerated;
  final Future<List<AchievementDef>> Function(AnalysisResult) onFinalize;
  final Future<void> Function(AnalysisResult) onDeleteProduct;
  const ProductHistoryDetailPage({
    super.key,
    required this.product,
    required this.onGenerated,
    required this.onFinalize,
    required this.onDeleteProduct,
  });

  @override
  State<ProductHistoryDetailPage> createState() => _ProductHistoryDetailPageState();
}

class _ProductHistoryDetailPageState extends State<ProductHistoryDetailPage> {
  _HistoryMetric selectedMetric = _HistoryMetric.score;
  bool compareWithFirst = false;

  List<StoredAnalysis> get analyses => widget.product.analyses.where((a) => a.result.finalized).toList()
    ..sort((a, b) => a.createdAt.compareTo(b.createdAt));

  @override
  Widget build(BuildContext context) {
    final items = analyses;
    final latest = items.last;
    final previous = items.length > 1 ? items[items.length - 2] : null;
    final baseline = compareWithFirst && items.length > 1 ? items.first : previous;

    return Scaffold(
      appBar: AppBar(title: const Text('Evolução do anúncio')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
        children: [
          _ProductHeader(product: widget.product, latest: latest, count: items.length),
          const SizedBox(height: 14),
          if (items.length > 1) ...[
            SegmentedButton<bool>(
              segments: const [
                ButtonSegment(value: false, label: Text('Anterior'), icon: Icon(Icons.compare_arrows)),
                ButtonSegment(value: true, label: Text('Primeira'), icon: Icon(Icons.first_page)),
              ],
              selected: {compareWithFirst},
              onSelectionChanged: (value) => setState(() => compareWithFirst = value.first),
            ),
            const SizedBox(height: 14),
            _SummaryCard(current: latest, baseline: baseline!),
            const SizedBox(height: 14),
            _ComparisonTable(current: latest, baseline: baseline),
            const SizedBox(height: 18),
          ],
          Text('Evolução', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900)),
          const SizedBox(height: 8),
          _MetricSelector(
            selected: selectedMetric,
            available: _availableMetrics(items),
            onSelected: (metric) => setState(() => selectedMetric = metric),
          ),
          const SizedBox(height: 10),
          _HistoryChart(analyses: items, metric: selectedMetric),
          const SizedBox(height: 18),
          Text('Análises realizadas', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900)),
          const SizedBox(height: 8),
          ...items.reversed.map((stored) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _AnalysisTimelineCard(
                  stored: stored,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ResultPage(
                        result: stored.result,
                        onFinalize: widget.onFinalize,
                        onGenerated: widget.onGenerated,
                        fromHistory: true,
                        storedAnalysisId: stored.id,
                        onDelete: widget.onDeleteProduct,
                      ),
                    ),
                  ),
                ),
              )),
        ],
      ),
    );
  }
}

class _ProductHeader extends StatelessWidget {
  final ProductHistoryRecord product;
  final StoredAnalysis latest;
  final int count;
  const _ProductHeader({required this.product, required this.latest, required this.count});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(children: [
          if (product.imageUrl != null)
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: SizedBox(
                width: 74,
                height: 74,
                child: Image.network(product.imageUrl!, fit: BoxFit.cover, errorBuilder: (_, __, ___) => ScoreGauge(score: latest.result.score, size: 74)),
              ),
            )
          else
            ScoreGauge(score: latest.result.score, size: 74),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(product.title, maxLines: 3, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
              const SizedBox(height: 6),
              Text('$count análises • última em ${formatDate(latest.createdAt)}'),
              const SizedBox(height: 3),
              Text('Nota atual: ${latest.result.score}/100', style: TextStyle(color: scoreColorFor(latest.result.score), fontWeight: FontWeight.w900)),
            ]),
          ),
        ]),
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final StoredAnalysis current;
  final StoredAnalysis baseline;
  const _SummaryCard({required this.current, required this.baseline});

  @override
  Widget build(BuildContext context) {
    final messages = _comparisonMessages(current, baseline);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const Icon(Icons.auto_graph),
            const SizedBox(width: 8),
            Expanded(child: Text('O que mudou', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900))),
          ]),
          const SizedBox(height: 10),
          ...messages.map((m) => Padding(
                padding: const EdgeInsets.only(bottom: 7),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Icon(m.icon, size: 18, color: m.color),
                  const SizedBox(width: 8),
                  Expanded(child: Text(m.text)),
                ]),
              )),
        ]),
      ),
    );
  }
}

class _ComparisonTable extends StatelessWidget {
  final StoredAnalysis current;
  final StoredAnalysis baseline;
  const _ComparisonTable({required this.current, required this.baseline});

  @override
  Widget build(BuildContext context) {
    final rows = _comparisonRows(current, baseline);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Comparação', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900)),
          const SizedBox(height: 4),
          Text('${formatDate(baseline.createdAt)} → ${formatDate(current.createdAt)}', style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 12),
          Row(children: [
            const Expanded(flex: 5, child: Text('Indicador', style: TextStyle(fontWeight: FontWeight.w800))),
            Expanded(flex: 3, child: Text('Antes', textAlign: TextAlign.right, style: Theme.of(context).textTheme.bodySmall)),
            Expanded(flex: 3, child: Text('Agora', textAlign: TextAlign.right, style: Theme.of(context).textTheme.bodySmall)),
            Expanded(flex: 3, child: Text('Mudança', textAlign: TextAlign.right, style: Theme.of(context).textTheme.bodySmall)),
          ]),
          const Divider(),
          ...rows.map((row) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 7),
                child: Row(children: [
                  Expanded(flex: 5, child: Text(row.label, style: const TextStyle(fontWeight: FontWeight.w700))),
                  Expanded(flex: 3, child: Text(row.before, textAlign: TextAlign.right)),
                  Expanded(flex: 3, child: Text(row.now, textAlign: TextAlign.right)),
                  Expanded(
                    flex: 3,
                    child: Text(
                      row.delta,
                      textAlign: TextAlign.right,
                      style: TextStyle(color: row.deltaColor, fontWeight: FontWeight.w800),
                    ),
                  ),
                ]),
              )),
        ]),
      ),
    );
  }
}

class _MetricSelector extends StatelessWidget {
  final _HistoryMetric selected;
  final List<_HistoryMetric> available;
  final ValueChanged<_HistoryMetric> onSelected;
  const _MetricSelector({required this.selected, required this.available, required this.onSelected});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: available.map((metric) {
          final isSelected = metric == selected;
          return Padding(
            padding: const EdgeInsets.only(right: 7),
            child: ChoiceChip(
              label: Text(_metricLabel(metric)),
              selected: isSelected,
              onSelected: (_) => onSelected(metric),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _HistoryChart extends StatelessWidget {
  final List<StoredAnalysis> analyses;
  final _HistoryMetric metric;
  const _HistoryChart({required this.analyses, required this.metric});

  @override
  Widget build(BuildContext context) {
    final points = <_ChartPoint>[];
    for (var i = 0; i < analyses.length; i++) {
      final value = _metricValue(analyses, i, metric);
      if (value != null) points.add(_ChartPoint(index: i, value: value));
    }
    if (points.isEmpty) {
      return const Card(child: Padding(padding: EdgeInsets.all(24), child: Center(child: Text('Sem dados suficientes para esta métrica.'))));
    }
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 14, 12, 12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(_metricLabel(metric), style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900)),
          const SizedBox(height: 4),
          Text(_metricHelp(metric), style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 14),
          SizedBox(
            height: 220,
            child: CustomPaint(
              painter: _TrendChartPainter(
                points: points,
                totalAnalyses: analyses.length,
                lineColor: Theme.of(context).colorScheme.primary,
                gridColor: Theme.of(context).dividerColor,
                textColor: Theme.of(context).colorScheme.onSurfaceVariant,
                formatter: (v) => _formatMetricValue(metric, v),
              ),
              child: const SizedBox.expand(),
            ),
          ),
        ]),
      ),
    );
  }
}

class _AnalysisTimelineCard extends StatelessWidget {
  final StoredAnalysis stored;
  final VoidCallback onTap;
  const _AnalysisTimelineCard({required this.stored, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final r = stored.result;
    final p = r.input.product;
    final pieces = <String>[
      if (p?.sold != null) '${p!.sold} vendas acum.',
      if (r.input.price != null) money(r.input.price!),
      if (r.input.roas7d != null) 'ROAS ${r.input.roas7d!.toStringAsFixed(2)}',
    ];
    return Card(
      child: ListTile(
        onTap: onTap,
        leading: CircleAvatar(child: Text('${r.score}')),
        title: Text(formatDate(stored.createdAt), style: const TextStyle(fontWeight: FontWeight.w900)),
        subtitle: Text(pieces.isEmpty ? 'Toque para ver os detalhes desta análise.' : pieces.join(' • ')),
        trailing: const Icon(Icons.chevron_right),
      ),
    );
  }
}

class _ComparisonMessage {
  final String text;
  final IconData icon;
  final Color color;
  const _ComparisonMessage(this.text, this.icon, this.color);
}

class _ComparisonRow {
  final String label;
  final String before;
  final String now;
  final String delta;
  final Color deltaColor;
  const _ComparisonRow(this.label, this.before, this.now, this.delta, this.deltaColor);
}

List<_ComparisonMessage> _comparisonMessages(StoredAnalysis current, StoredAnalysis baseline) {
  final rows = _comparisonRows(current, baseline);
  if (rows.isEmpty) return [const _ComparisonMessage('Ainda não há métricas comparáveis suficientes.', Icons.info_outline, Colors.grey)];
  final prioritized = rows.where((r) => r.delta != '—' && r.delta != '0' && r.delta != '0,00').take(5).toList();
  if (prioritized.isEmpty) return [const _ComparisonMessage('As principais métricas ficaram estáveis entre as duas análises.', Icons.trending_flat, Colors.grey)];
  return prioritized.map((r) {
    final positive = r.deltaColor == Colors.green;
    final negative = r.deltaColor == Colors.red;
    return _ComparisonMessage(
      '${r.label}: ${r.before} → ${r.now} (${r.delta}).',
      positive ? Icons.trending_up : negative ? Icons.trending_down : Icons.trending_flat,
      r.deltaColor,
    );
  }).toList();
}

List<_ComparisonRow> _comparisonRows(StoredAnalysis current, StoredAnalysis baseline) {
  final c = current.result;
  final b = baseline.result;
  final rows = <_ComparisonRow>[];

  void addInt(String label, int? before, int? now, {bool higherIsBetter = true}) {
    if (before == null || now == null) return;
    final d = now - before;
    rows.add(_ComparisonRow(label, '$before', '$now', '${d > 0 ? '+' : ''}$d', _deltaColor(d.toDouble(), higherIsBetter)));
  }

  void addDouble(String label, double? before, double? now, {String Function(double)? format, bool? higherIsBetter = true}) {
    if (before == null || now == null) return;
    final d = now - before;
    final f = format ?? (v) => v.toStringAsFixed(2);
    rows.add(_ComparisonRow(label, f(before), f(now), '${d > 0 ? '+' : ''}${f(d)}', _deltaColor(d, higherIsBetter)));
  }

  addInt('Nota', b.score, c.score);
  addInt('Vendas acumuladas', b.input.product?.sold, c.input.product?.sold);
  if (b.input.product?.sold != null && c.input.product?.sold != null) {
    final periodSales = c.input.product!.sold! - b.input.product!.sold!;
    rows.add(_ComparisonRow('Vendas no período', '—', '$periodSales', periodSales > 0 ? '+$periodSales' : '$periodSales', _deltaColor(periodSales.toDouble(), true)));
  }
  addDouble('Preço', b.input.price, c.input.price, format: (v) => money(v), higherIsBetter: null);
  addDouble('ROAS 7d', b.input.roas7d, c.input.roas7d);
  addDouble('Meta ROAS', b.input.roasTarget, c.input.roasTarget);
  addDouble('Gasto Ads 7d', b.input.adsSpend7d, c.input.adsSpend7d, format: (v) => money(v), higherIsBetter: null);
  addDouble('GMV Ads estimado', _adsGmv(b), _adsGmv(c), format: (v) => money(v));
  addDouble('Avaliação', b.input.product?.rating, c.input.product?.rating, format: (v) => v.toStringAsFixed(2));
  addInt('Reviews', b.input.product?.reviewCount, c.input.product?.reviewCount);
  return rows;
}

Color _deltaColor(double delta, bool? higherIsBetter) {
  if (delta.abs() < 0.000001 || higherIsBetter == null) return Colors.grey;
  final improved = higherIsBetter ? delta > 0 : delta < 0;
  return improved ? Colors.green : Colors.red;
}

double? _adsGmv(AnalysisResult r) {
  final spend = r.input.adsSpend7d;
  final roas = r.input.roas7d;
  if (spend == null || roas == null) return null;
  return spend * roas;
}

List<_HistoryMetric> _availableMetrics(List<StoredAnalysis> analyses) {
  final result = <_HistoryMetric>[_HistoryMetric.score];
  bool any(_HistoryMetric metric) {
    for (var i = 0; i < analyses.length; i++) {
      if (_metricValue(analyses, i, metric) != null) return true;
    }
    return false;
  }
  for (final metric in _HistoryMetric.values) {
    if (metric == _HistoryMetric.score) continue;
    if (any(metric)) result.add(metric);
  }
  return result;
}

double? _metricValue(List<StoredAnalysis> analyses, int index, _HistoryMetric metric) {
  final r = analyses[index].result;
  switch (metric) {
    case _HistoryMetric.score:
      return r.score.toDouble();
    case _HistoryMetric.sold:
      return r.input.product?.sold?.toDouble();
    case _HistoryMetric.periodSales:
      if (index == 0) return null;
      final now = r.input.product?.sold;
      final before = analyses[index - 1].result.input.product?.sold;
      if (now == null || before == null) return null;
      return (now - before).toDouble();
    case _HistoryMetric.price:
      return r.input.price;
    case _HistoryMetric.roas:
      return r.input.roas7d;
    case _HistoryMetric.adsSpend:
      return r.input.adsSpend7d;
    case _HistoryMetric.adsGmv:
      return _adsGmv(r);
    case _HistoryMetric.rating:
      return r.input.product?.rating;
    case _HistoryMetric.reviews:
      return r.input.product?.reviewCount?.toDouble();
  }
}

String _metricLabel(_HistoryMetric metric) {
  switch (metric) {
    case _HistoryMetric.score: return 'Nota';
    case _HistoryMetric.sold: return 'Vendas';
    case _HistoryMetric.periodSales: return 'Vendas/período';
    case _HistoryMetric.price: return 'Preço';
    case _HistoryMetric.roas: return 'ROAS';
    case _HistoryMetric.adsSpend: return 'Gasto Ads';
    case _HistoryMetric.adsGmv: return 'GMV Ads';
    case _HistoryMetric.rating: return 'Avaliação';
    case _HistoryMetric.reviews: return 'Reviews';
  }
}

String _metricHelp(_HistoryMetric metric) {
  switch (metric) {
    case _HistoryMetric.periodSales: return 'Diferença das vendas acumuladas entre uma análise e a anterior.';
    case _HistoryMetric.adsGmv: return 'Estimativa calculada por gasto Ads × ROAS informado.';
    default: return 'Cada ponto representa uma análise finalizada deste produto.';
  }
}

String _formatMetricValue(_HistoryMetric metric, double value) {
  switch (metric) {
    case _HistoryMetric.price:
    case _HistoryMetric.adsSpend:
    case _HistoryMetric.adsGmv:
      return money(value);
    case _HistoryMetric.roas:
    case _HistoryMetric.rating:
      return value.toStringAsFixed(2);
    case _HistoryMetric.score:
    case _HistoryMetric.sold:
    case _HistoryMetric.periodSales:
    case _HistoryMetric.reviews:
      return value.round().toString();
  }
}

class _ChartPoint {
  final int index;
  final double value;
  const _ChartPoint({required this.index, required this.value});
}

class _TrendChartPainter extends CustomPainter {
  final List<_ChartPoint> points;
  final int totalAnalyses;
  final Color lineColor;
  final Color gridColor;
  final Color textColor;
  final String Function(double) formatter;
  const _TrendChartPainter({
    required this.points,
    required this.totalAnalyses,
    required this.lineColor,
    required this.gridColor,
    required this.textColor,
    required this.formatter,
  });

  @override
  void paint(Canvas canvas, Size size) {
    const left = 52.0;
    const right = 14.0;
    const top = 12.0;
    const bottom = 34.0;
    final chartW = math.max(1.0, size.width - left - right);
    final chartH = math.max(1.0, size.height - top - bottom);
    var minV = points.map((p) => p.value).reduce(math.min);
    var maxV = points.map((p) => p.value).reduce(math.max);
    if ((maxV - minV).abs() < 0.0001) {
      minV -= 1;
      maxV += 1;
    } else {
      final pad = (maxV - minV) * .12;
      minV -= pad;
      maxV += pad;
    }

    final gridPaint = Paint()..color = gridColor.withValues(alpha: .55)..strokeWidth = 1;
    final linePaint = Paint()..color = lineColor..strokeWidth = 3..style = PaintingStyle.stroke..strokeCap = StrokeCap.round;
    final dotPaint = Paint()..color = lineColor..style = PaintingStyle.fill;
    final labelStyle = TextStyle(color: textColor, fontSize: 10, fontWeight: FontWeight.w600);

    for (var i = 0; i <= 4; i++) {
      final y = top + chartH * i / 4;
      canvas.drawLine(Offset(left, y), Offset(left + chartW, y), gridPaint);
      final value = maxV - (maxV - minV) * i / 4;
      final tp = TextPainter(text: TextSpan(text: formatter(value), style: labelStyle), textDirection: TextDirection.ltr)..layout(maxWidth: left - 6);
      tp.paint(canvas, Offset(left - tp.width - 6, y - tp.height / 2));
    }

    double xFor(int analysisIndex) {
      if (totalAnalyses <= 1) return left + chartW / 2;
      return left + chartW * analysisIndex / (totalAnalyses - 1);
    }
    double yFor(double value) => top + chartH * (maxV - value) / (maxV - minV);

    if (points.length > 1) {
      final path = Path();
      for (var i = 0; i < points.length; i++) {
        final o = Offset(xFor(points[i].index), yFor(points[i].value));
        if (i == 0) path.moveTo(o.dx, o.dy); else path.lineTo(o.dx, o.dy);
      }
      canvas.drawPath(path, linePaint);
    }

    for (final p in points) {
      final o = Offset(xFor(p.index), yFor(p.value));
      canvas.drawCircle(o, 4.5, dotPaint);
      final label = 'A${p.index + 1}';
      final tp = TextPainter(text: TextSpan(text: label, style: labelStyle), textDirection: TextDirection.ltr)..layout();
      tp.paint(canvas, Offset(o.dx - tp.width / 2, top + chartH + 9));
    }
  }

  @override
  bool shouldRepaint(covariant _TrendChartPainter oldDelegate) {
    return oldDelegate.points != points || oldDelegate.lineColor != lineColor || oldDelegate.gridColor != gridColor || oldDelegate.textColor != textColor;
  }
}
