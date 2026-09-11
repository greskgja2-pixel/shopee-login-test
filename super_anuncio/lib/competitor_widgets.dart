part of 'main.dart';

class CompetitorCard extends StatelessWidget {
  final CompetitorCandidate candidate;
  final bool selected;
  final ValueChanged<bool> onChanged;
  const CompetitorCard({super.key, required this.candidate, required this.selected, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Card(
      color: selected ? cs.primaryContainer.withOpacity(.45) : null,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => onChanged(!selected),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: SizedBox(
                width: 76,
                height: 76,
                child: candidate.imageUrl == null ? const ColoredBox(color: Color(0x11000000), child: Icon(Icons.image_outlined)) : Image.network(candidate.imageUrl!, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const Icon(Icons.image_not_supported_outlined)),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(candidate.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w800)),
              const SizedBox(height: 5),
              if (candidate.price != null) Text(money(candidate.price!), style: TextStyle(color: cs.primary, fontWeight: FontWeight.w900, fontSize: 16)),
              if (candidate.rating != null) Text('⭐ ${candidate.rating!.toStringAsFixed(1)}${candidate.sold == null ? '' : '  •  ${candidate.sold!.toInt()} vendidos'}', style: Theme.of(context).textTheme.bodySmall),
            ])),
            Checkbox(value: selected, onChanged: (v) => onChanged(v ?? false)),
          ]),
        ),
      ),
    );
  }
}

class AutoFacts extends StatelessWidget {
  final ShopeeProductData product;
  const AutoFacts({super.key, required this.product});

  @override
  Widget build(BuildContext context) {
    final facts = <String>[
      '${product.imageCount} imagem(ns)',
      product.hasVideo ? 'Com vídeo' : 'Sem vídeo detectado',
      if (product.rating != null) '⭐ ${product.rating!.toStringAsFixed(1)}',
      if (product.reviewCount != null) '${product.reviewCount} avaliações',
      if (product.sold != null) '${product.sold} vendidos',
      if (product.stock != null) 'Estoque ${product.stock}',
      if (product.variationCount > 0) '${product.variationCount} variações',
    ];
    return Wrap(spacing: 8, runSpacing: 8, children: facts.map((e) => Chip(label: Text(e))).toList());
  }
}

class DimensionCard extends StatelessWidget {
  final AuditDimension dimension;
  const DimensionCard({super.key, required this.dimension});

  @override
  Widget build(BuildContext context) {
    final pct = dimension.score / dimension.maxScore;
    final color = pct >= .8 ? Colors.green : pct >= .55 ? Colors.orange : Colors.red;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Card(
        child: ExpansionTile(
          leading: CircleAvatar(backgroundColor: color.withOpacity(.14), child: Icon(dimension.icon, color: color)),
          title: Text(dimension.name, style: const TextStyle(fontWeight: FontWeight.w900)),
          subtitle: LinearProgressIndicator(value: pct, color: color, minHeight: 6, borderRadius: BorderRadius.circular(10)),
          trailing: Text('${dimension.score}/${dimension.maxScore}', style: TextStyle(fontWeight: FontWeight.w900, color: color)),
          children: [Padding(padding: const EdgeInsets.fromLTRB(18, 0, 18, 18), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(dimension.reason), const SizedBox(height: 8), Text('Como melhorar: ${dimension.action}', style: const TextStyle(fontWeight: FontWeight.w700))]))],
        ),
      ),
    );
  }
}

class CompetitiveSummary extends StatelessWidget {
  final AnalysisResult result;
  const CompetitiveSummary({super.key, required this.result});

  @override
  Widget build(BuildContext context) {
    final comps = result.competitors;
    final averageRating = average(comps.map((e) => e.rating).whereType<double>());
    final recurring = recurringTerms(result.input.title, comps);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Row(children: [Icon(Icons.groups_outlined), SizedBox(width: 8), Text('Comparação com concorrentes', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18))]),
          const SizedBox(height: 12),
          Text(result.priceInsight),
          if (result.competitorMedian != null) Padding(padding: const EdgeInsets.only(top: 8), child: Text('Mediana de preço: ${money(result.competitorMedian!)}', style: const TextStyle(fontWeight: FontWeight.w800))),
          if (averageRating != null) Padding(padding: const EdgeInsets.only(top: 5), child: Text('Média de avaliação dos selecionados: ${averageRating.toStringAsFixed(2)}')),
          if (recurring.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 5), child: Text('Termos recorrentes: ${recurring.join(', ')}')),
          if (comps.isEmpty) const Padding(padding: EdgeInsets.only(top: 8), child: Text('Nenhum concorrente foi selecionado; essa parte da auditoria fica menos precisa.')),
        ]),
      ),
    );
  }
}

class AdsSummary extends StatelessWidget {
  final AnalysisResult result;
  const AdsSummary({super.key, required this.result});

  @override
  Widget build(BuildContext context) {
    final ads = result.dimensions.firstWhere((d) => d.name == 'Ads e eficiência');
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Row(children: [Icon(Icons.campaign_outlined), SizedBox(width: 8), Text('Ads — últimos 7 dias', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18))]),
          const SizedBox(height: 10),
          Text(ads.reason),
          const SizedBox(height: 6),
          Text(ads.action, style: const TextStyle(fontWeight: FontWeight.w700)),
        ]),
      ),
    );
  }
}
