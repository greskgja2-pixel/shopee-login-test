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
              if (candidate.bestSellingVariationPrice != null)
                Text(
                  'Variação líder${candidate.bestSellingVariationName == null ? '' : ': ${candidate.bestSellingVariationName}'}${candidate.bestSellingVariationSold == null ? '' : ' • ${candidate.bestSellingVariationSold!.round()} vendidos'}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w700),
                ),
              if (candidate.priceMin != null && candidate.priceMax != null && candidate.priceMin != candidate.priceMax)
                Text('Faixa ${money(candidate.priceMin!)} - ${money(candidate.priceMax!)}', style: Theme.of(context).textTheme.bodySmall),
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
      if (product.bestSellingVariationPrice != null) 'Preço pela variação líder',
    ];
    return Wrap(spacing: 8, runSpacing: 8, children: facts.map((e) => Chip(label: Text(e))).toList());
  }
}

class DimensionCard extends StatefulWidget {
  final AuditDimension dimension;
  const DimensionCard({super.key, required this.dimension});

  @override
  State<DimensionCard> createState() => _DimensionCardState();
}

class _DimensionCardState extends State<DimensionCard> {
  bool expanded = false;

  @override
  Widget build(BuildContext context) {
    final dimension = widget.dimension;
    final pct = dimension.score / dimension.maxScore;
    final color = pct >= .8 ? Colors.green : pct >= .55 ? Colors.orange : Colors.red;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Card(
        child: ExpansionTile(
          onExpansionChanged: (value) => setState(() => expanded = value),
          leading: CircleAvatar(backgroundColor: color.withOpacity(.14), child: Icon(dimension.icon, color: color)),
          title: Row(children: [
            Expanded(child: Text(dimension.name, style: const TextStyle(fontWeight: FontWeight.w900))),
            Text('${dimension.score}/${dimension.maxScore}', style: TextStyle(fontWeight: FontWeight.w900, color: color)),
            const SizedBox(width: 7),
            AnimatedRotation(
              turns: expanded ? .5 : 0,
              duration: const Duration(milliseconds: 180),
              child: const Icon(Icons.keyboard_arrow_down_rounded),
            ),
          ]),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 8),
            child: LinearProgressIndicator(value: pct, color: color, minHeight: 6, borderRadius: BorderRadius.circular(10)),
          ),
          trailing: const SizedBox.shrink(),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 2, 18, 18),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                _DimensionDetailBlock(
                  icon: Icons.help_outline,
                  title: 'Por que recebeu essa nota',
                  text: dimension.reason,
                ),
                const SizedBox(height: 9),
                _DimensionDetailBlock(
                  icon: Icons.build_circle_outlined,
                  title: 'Como melhorar',
                  text: dimension.action,
                ),
                const SizedBox(height: 9),
                ExpertTipsPanel(dimensionName: dimension.name),
              ]),
            ),
          ],
        ),
      ),
    );
  }
}

class _DimensionDetailBlock extends StatelessWidget {
  final IconData icon;
  final String title;
  final String text;
  const _DimensionDetailBlock({required this.icon, required this.title, required this.text});

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(13),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(.45),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [Icon(icon, size: 19), const SizedBox(width: 7), Text(title, style: const TextStyle(fontWeight: FontWeight.w900))]),
          const SizedBox(height: 6),
          Text(text),
        ]),
      );
}

class CompetitiveSummary extends StatelessWidget {
  final AnalysisResult result;
  const CompetitiveSummary({super.key, required this.result});

  @override
  Widget build(BuildContext context) {
    final comps = result.competitors;
    final averageRating = average(comps.map((e) => e.rating).whereType<double>());
    final recurring = recurringTerms(result.input.title, comps);
    final p = result.input.product;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Row(children: [Icon(Icons.groups_outlined), SizedBox(width: 8), Text('Comparação com concorrentes', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18))]),
          const SizedBox(height: 12),
          if (p?.bestSellingVariationPrice != null) ...[
            Text(
              'Preço do seu anúncio usado na comparação: ${money(p!.bestSellingVariationPrice!)}${p.bestSellingVariationName == null ? '' : ' (${p.bestSellingVariationName})'}.',
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 7),
          ],
          Text(result.priceInsight),
          if (result.competitorMedian != null) Padding(padding: const EdgeInsets.only(top: 8), child: Text('Mediana de preço: ${money(result.competitorMedian!)}', style: const TextStyle(fontWeight: FontWeight.w800))),
          if (averageRating != null) Padding(padding: const EdgeInsets.only(top: 5), child: Text('Média de avaliação dos selecionados: ${averageRating.toStringAsFixed(2)}')),
          if (recurring.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 5), child: Text('Termos recorrentes: ${recurring.join(', ')}')),
          if (comps.any((c) => c.bestSellingVariationPrice != null))
            const Padding(
              padding: EdgeInsets.only(top: 7),
              child: Text('Nos concorrentes em que a Shopee informou vendas por variação, a comparação também usa a variação líder.', style: TextStyle(fontWeight: FontWeight.w600)),
            ),
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
    final input = result.input;
    final advice = buildRoasStrategy(input);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Row(children: [Icon(Icons.campaign_outlined), SizedBox(width: 8), Text('Ads — últimos 7 dias', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18))]),
          const SizedBox(height: 12),
          Wrap(spacing: 8, runSpacing: 8, children: [
            if (input.roas7d != null) Chip(label: Text('ROAS ${input.roas7d!.toStringAsFixed(2)}')),
            if (input.roasTarget != null) Chip(label: Text('ROAS alvo ${input.roasTarget!.toStringAsFixed(2)}')),
            if (input.adsSpend7d != null) Chip(label: Text('Gasto ${money(input.adsSpend7d!)}')),
            if (input.productCost != null) Chip(label: Text('Custo ${money(input.productCost!)}')),
          ]),
          const SizedBox(height: 10),
          Text(ads.reason),
          const SizedBox(height: 6),
          Text(ads.action, style: const TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 14),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primaryContainer.withOpacity(.35),
              borderRadius: BorderRadius.circular(15),
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                const Icon(Icons.auto_graph_outlined),
                const SizedBox(width: 8),
                Expanded(child: Text(advice.title, style: const TextStyle(fontWeight: FontWeight.w900))),
              ]),
              const SizedBox(height: 7),
              Text(advice.message),
              if (advice.grossMarginPct != null) ...[
                const SizedBox(height: 8),
                Text('Margem bruta preliminar pelo custo informado: ${advice.grossMarginPct!.toStringAsFixed(1)}%', style: const TextStyle(fontWeight: FontWeight.w800)),
              ],
              if (advice.preliminaryBreakEvenRoas != null)
                Text('ROAS de equilíbrio preliminar: ${advice.preliminaryBreakEvenRoas!.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.w800)),
              if (advice.suggestedTarget != null) ...[
                const SizedBox(height: 6),
                Text('Teste de Meta de ROAS sugerido: cerca de ${advice.suggestedTarget!.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.w900)),
              ],
              if (input.productCost != null) ...[
                const SizedBox(height: 7),
                const Text('Estimativa preliminar: taxas da plataforma, impostos, frete, embalagem e outros custos variáveis podem aumentar o ROAS mínimo real.', style: TextStyle(fontSize: 12)),
              ],
            ]),
          ),
          const SizedBox(height: 9),
          Text('Orientação baseada em boas práticas oficiais da Shopee Ads para Meta de ROAS e GMV Max. Mudanças devem ser graduais e avaliadas por vários dias.', style: Theme.of(context).textTheme.bodySmall),
        ]),
      ),
    );
  }
}
