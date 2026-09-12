part of 'main.dart';

class AnalysisInput {
  final String url;
  final String title;
  final String description;
  final String category;
  final double? price;
  final String goal;
  final String stage;
  final String issue;
  final bool adsActive;
  final double? roas7d;
  final double? roasTarget;
  final double? adsSpend7d;
  final double? productCost;
  final ShopeeProductData? product;
  final List<CompetitorCandidate> competitors;
  const AnalysisInput({
    required this.url,
    required this.title,
    required this.description,
    required this.category,
    required this.price,
    required this.goal,
    required this.stage,
    required this.issue,
    required this.adsActive,
    required this.roas7d,
    this.roasTarget,
    required this.adsSpend7d,
    this.productCost,
    required this.product,
    required this.competitors,
  });
}

class ShopeeProductData {
  final String url;
  final String shopId;
  final String itemId;
  final String title;
  final String description;
  final String category;
  final String? imageUrl;
  final double? price;
  final double? priceBeforeDiscount;
  final double? priceMin;
  final double? priceMax;
  final String? bestSellingVariationName;
  final double? bestSellingVariationPrice;
  final int? bestSellingVariationSold;
  final String? priceBasis;
  final double? rating;
  final int? reviewCount;
  final int? sold;
  final int? stock;
  final int imageCount;
  final bool hasVideo;
  final int attributesCount;
  final int variationCount;
  const ShopeeProductData({
    required this.url,
    required this.shopId,
    required this.itemId,
    required this.title,
    required this.description,
    required this.category,
    required this.imageUrl,
    required this.price,
    required this.priceBeforeDiscount,
    this.priceMin,
    this.priceMax,
    this.bestSellingVariationName,
    this.bestSellingVariationPrice,
    this.bestSellingVariationSold,
    this.priceBasis,
    required this.rating,
    required this.reviewCount,
    required this.sold,
    required this.stock,
    required this.imageCount,
    required this.hasVideo,
    required this.attributesCount,
    required this.variationCount,
  });
}

class CompetitorCandidate {
  final String title;
  final double? price;
  final double? priceMin;
  final double? priceMax;
  final String? bestSellingVariationName;
  final double? bestSellingVariationPrice;
  final double? bestSellingVariationSold;
  final String? priceBasis;
  final String link;
  final String? imageUrl;
  final double? rating;
  final double? sold;
  final String? shopId;
  final String itemId;
  final String description;
  final String category;
  const CompetitorCandidate({
    required this.title,
    required this.price,
    this.priceMin,
    this.priceMax,
    this.bestSellingVariationName,
    this.bestSellingVariationPrice,
    this.bestSellingVariationSold,
    this.priceBasis,
    required this.link,
    required this.imageUrl,
    required this.rating,
    required this.sold,
    required this.shopId,
    required this.itemId,
    required this.description,
    required this.category,
  });
  String get key => '${shopId ?? 'manual'}:$itemId';
}

class AuditDimension {
  final String name;
  final IconData icon;
  final int score;
  final int maxScore;
  final String reason;
  final String action;
  const AuditDimension({required this.name, required this.icon, required this.score, required this.maxScore, required this.reason, required this.action});
}

class GuidedLesson {
  final String title;
  final IconData icon;
  final String current;
  final String optimized;
  final String why;
  final String how;
  const GuidedLesson({required this.title, required this.icon, required this.current, required this.optimized, required this.why, required this.how});
}

class AnalysisResult {
  final AnalysisInput input;
  final int score;
  final String summary;
  final String optimizedTitle;
  final String optimizedDescription;
  final String suggestedCategory;
  final List<AuditDimension> dimensions;
  final List<GuidedLesson> lessons;
  final double? competitorMedian;
  final String priceInsight;
  final List<CompetitorCandidate> competitors;
  bool finalized;
  DateTime? reanalyzeAt;

  AnalysisResult({required this.input, required this.score, required this.summary, required this.optimizedTitle, required this.optimizedDescription, required this.suggestedCategory, required this.dimensions, required this.lessons, required this.competitorMedian, required this.priceInsight, required this.competitors, this.finalized = false, this.reanalyzeAt});

  factory AnalysisResult.build(AnalysisInput input) {
    final competitors = input.competitors;
    final median = medianPrice(competitors);
    final priceInsight = buildPriceInsight(input.price, median, competitors.length);
    final optimizedTitle = optimizeTitle(input.title, competitors);
    final optimizedDescription = optimizeDescription(input.title, input.description, competitors);
    final suggestedCategory = suggestCategory(input.category, competitors);
    final p = input.product;

    final dimensions = <AuditDimension>[];

    final titleLength = input.title.length;
    final duplicatePenalty = duplicateWordCount(input.title);
    int titleScore = titleLength >= 40 && titleLength <= 120 ? 12 : titleLength >= 25 ? 9 : 5;
    titleScore = (titleScore - (duplicatePenalty > 3 ? 3 : duplicatePenalty)).clamp(3, 12).toInt();
    dimensions.add(AuditDimension(name: 'Título', icon: Icons.title, score: titleScore, maxScore: 12, reason: titleScore >= 10 ? 'O título tem boa densidade e tamanho para leitura.' : 'O título pode ganhar clareza, prioridade de palavras e menos repetição.', action: optimizedTitle == input.title ? 'Mantenha o título e valide os termos usados pelos concorrentes.' : 'Teste o título otimizado mostrado abaixo.'));

    final descLen = input.description.length;
    final descScore = descLen >= 500 ? 12 : descLen >= 250 ? 10 : descLen >= 100 ? 7 : descLen > 0 ? 4 : 2;
    dimensions.add(AuditDimension(name: 'Descrição', icon: Icons.description_outlined, score: descScore, maxScore: 12, reason: descScore >= 10 ? 'A descrição tem volume suficiente para organizar benefícios e dúvidas.' : 'A descrição está curta ou pouco estruturada para responder dúvidas antes da compra.', action: 'Use a versão estruturada e complete apenas informações verdadeiras.'));

    final imageCount = p?.imageCount ?? 0;
    final imageScore = imageCount >= 7 ? 15 : imageCount >= 5 ? 12 : imageCount >= 3 ? 9 : imageCount > 0 ? 6 : 7;
    dimensions.add(AuditDimension(name: 'Imagens', icon: Icons.image_outlined, score: imageScore, maxScore: 15, reason: p == null ? 'Não consegui confirmar automaticamente a quantidade de imagens.' : 'Foram identificadas $imageCount imagem(ns) no anúncio.', action: imageCount >= 7 ? 'Mantenha variedade visual: capa, detalhes, escala, uso e diferenciais.' : 'Tente chegar a 7+ imagens úteis, sem repetir a mesma informação.'));

    final hasVideo = p?.hasVideo ?? false;
    final videoScore = hasVideo ? 8 : (p == null ? 4 : 2);
    dimensions.add(AuditDimension(name: 'Vídeo', icon: Icons.play_circle_outline, score: videoScore, maxScore: 8, reason: p == null ? 'Não consegui confirmar automaticamente se existe vídeo.' : (hasVideo ? 'O anúncio possui vídeo.' : 'Não identifiquei vídeo no anúncio.'), action: hasVideo ? 'Use o vídeo para demonstrar uso, tamanho e benefício real.' : 'Adicione um vídeo curto mostrando o produto em uso ou os principais diferenciais.'));

    final categoryScore = input.category.isNotEmpty ? 8 : 3;
    dimensions.add(AuditDimension(name: 'Categoria', icon: Icons.category_outlined, score: categoryScore, maxScore: 8, reason: input.category.isNotEmpty ? 'Há uma categoria identificada para validar contra os concorrentes.' : 'A categoria não pôde ser confirmada.', action: 'Use a subcategoria mais específica que represente o produto.'));

    int competitionScore = competitors.length >= 3 ? 8 : competitors.length == 2 ? 6 : competitors.length == 1 ? 4 : 2;
    if (input.price != null && median != null) {
      final diff = ((input.price! - median) / median).abs();
      competitionScore += diff <= .10 ? 7 : diff <= .20 ? 5 : 3;
    } else {
      competitionScore += 3;
    }
    dimensions.add(AuditDimension(name: 'Preço e concorrência', icon: Icons.groups_outlined, score: competitionScore.clamp(0, 15).toInt(), maxScore: 15, reason: priceInsight, action: competitors.length < 3 ? 'Compare com 3 produtos equivalentes antes de mexer no preço.' : 'Use preço junto de reputação, conteúdo e diferenciais — não baixe preço automaticamente.'));

    final rating = p?.rating;
    final reviews = p?.reviewCount;
    int proofScore = 5;
    if (rating != null) proofScore += rating >= 4.8 ? 3 : rating >= 4.5 ? 2 : 1;
    if (reviews != null) proofScore += reviews >= 100 ? 2 : reviews >= 20 ? 1 : 0;
    dimensions.add(AuditDimension(name: 'Prova social', icon: Icons.star_outline, score: proofScore.clamp(0, 10).toInt(), maxScore: 10, reason: rating == null ? 'Avaliações não ficaram disponíveis na leitura pública.' : 'Avaliação identificada: ${rating.toStringAsFixed(1)}${reviews == null ? '' : ' em $reviews avaliação(ões)'}.' , action: 'Reforce confiança com fotos reais, respostas claras e consistência de entrega.'));

    int structureScore = 4;
    if ((p?.attributesCount ?? 0) >= 5) structureScore += 2;
    if ((p?.variationCount ?? 0) > 0) structureScore += 1;
    if ((p?.stock ?? 0) > 0) structureScore += 1;
    dimensions.add(AuditDimension(name: 'Atributos, estoque e variações', icon: Icons.inventory_2_outlined, score: structureScore.clamp(0, 8).toInt(), maxScore: 8, reason: p == null ? 'Parte desses dados não ficou disponível automaticamente.' : 'Atributos: ${p.attributesCount} • Variações: ${p.variationCount}${p.stock == null ? '' : ' • Estoque: ${p.stock}'}', action: 'Preencha atributos relevantes e mantenha variações claras para evitar dúvida na escolha.'));

    int adsScore = 8;
    String adsReason = 'Ads não informado como ativo; a nota não penaliza o anúncio por isso.';
    String adsAction = 'Se ativar Ads, compare ROAS e gasto por pelo menos 7 dias antes de concluir que o problema é o anúncio.';
    if (input.adsActive) {
      final roas = input.roas7d;
      if (roas == null) {
        adsScore = 6;
        adsReason = 'Ads ativo, mas o ROAS de 7 dias não foi informado.';
        adsAction = 'Informe ROAS e gasto para separar problema de tráfego de problema de conversão.';
      } else {
        adsScore = roas >= 5 ? 12 : roas >= 3 ? 10 : roas >= 2 ? 7 : 4;
        final targetPart = input.roasTarget == null ? '' : ' • Meta de ROAS ${input.roasTarget!.toStringAsFixed(2)}';
        adsReason = 'ROAS informado: ${roas.toStringAsFixed(2)}$targetPart${input.adsSpend7d == null ? '' : ' • gasto ${money(input.adsSpend7d!)} em 7 dias'}.';
        adsAction = roas < 2 ? 'Antes de aumentar orçamento, revise oferta, preço, criativo e conversão do anúncio.' : 'O Ads está gerando retorno; preserve o que funciona e teste melhorias sem mudanças bruscas.';
      }
    }
    dimensions.add(AuditDimension(name: 'Ads e eficiência', icon: Icons.campaign_outlined, score: adsScore.clamp(0, 12).toInt(), maxScore: 12, reason: adsReason, action: adsAction));

    final score = dimensions.fold<int>(0, (sum, d) => sum + d.score).clamp(0, 100).toInt();
    final summary = score >= 85 ? 'Anúncio forte. O foco agora é refinamento e vantagem competitiva.' : score >= 70 ? 'Boa base, com oportunidades claras para ganhar conversão e competitividade.' : score >= 55 ? 'O anúncio tem base utilizável, mas há pontos importantes limitando o desempenho.' : 'O anúncio precisa de ajustes relevantes. O plano abaixo prioriza o que mais pode destravar resultado.';

    final lessons = dimensions.where((d) => d.score < d.maxScore * .85).map((d) {
      String current = '';
      String optimized = '';
      if (d.name == 'Título') {
        current = input.title;
        optimized = optimizedTitle;
      } else if (d.name == 'Descrição') {
        current = input.description.isEmpty ? 'Descrição não informada.' : input.description;
        optimized = optimizedDescription;
      } else if (d.name == 'Categoria') {
        current = input.category.isEmpty ? 'Categoria não confirmada.' : input.category;
        optimized = suggestedCategory;
      } else if (d.name == 'Preço e concorrência') {
        current = input.price == null ? 'Preço não informado.' : money(input.price!);
        optimized = priceInsight;
      }
      return GuidedLesson(title: d.name, icon: d.icon, current: current, optimized: optimized, why: d.reason, how: d.action);
    }).toList();
    if (lessons.isEmpty) {
      lessons.add(const GuidedLesson(
        title: 'Refinamento final',
        icon: Icons.auto_awesome,
        current: 'Seu anúncio já está forte.',
        optimized: 'Teste uma melhoria por vez e reanalise em 7 dias.',
        why: 'Quando a base está boa, mudanças grandes podem piorar algo que já funciona.',
        how: 'Use os concorrentes como referência, faça testes pequenos e acompanhe resultado.',
      ));
    }

    return AnalysisResult(input: input, score: score, summary: summary, optimizedTitle: optimizedTitle, optimizedDescription: optimizedDescription, suggestedCategory: suggestedCategory, dimensions: dimensions, lessons: lessons, competitorMedian: median, priceInsight: priceInsight, competitors: competitors);
  }
}

class AchievementDef {
  final int id;
  final String title;
  final String hint;
  final IconData icon;
  const AchievementDef(this.id, this.title, this.hint, this.icon);
}

class AchievementEngine {
  static final List<AchievementDef> all = _build();

  static List<AchievementDef> _build() {
    final list = <AchievementDef>[];
    for (var i = 1; i <= 25; i++) {
      list.add(AchievementDef(i, i == 1 ? 'Primeira auditoria' : 'Auditor $i', 'Finalize $i análise(s)', Icons.fact_check_outlined));
    }
    for (var i = 0; i < 25; i++) {
      final threshold = 50 + i * 2;
      list.add(AchievementDef(26 + i, 'Nota $threshold+', 'Alcance $threshold pontos', Icons.speed));
    }
    for (var i = 1; i <= 25; i++) {
      list.add(AchievementDef(50 + i, 'Radar $i', 'Selecione $i concorrente(s)', Icons.radar));
    }
    for (var i = 1; i <= 25; i++) {
      list.add(AchievementDef(75 + i, 'Ads $i', 'Finalize $i análise(s) com Ads', Icons.campaign_outlined));
    }
    return list;
  }

  static Set<int> unlockedIds({required int finalizedAnalyses, required int competitorSelections, required int adsAnalyses, required int bestScore}) {
    final ids = <int>{};
    for (var i = 1; i <= 25; i++) if (finalizedAnalyses >= i) ids.add(i);
    for (var i = 0; i < 25; i++) if (bestScore >= 50 + i * 2) ids.add(26 + i);
    for (var i = 1; i <= 25; i++) if (competitorSelections >= i) ids.add(50 + i);
    for (var i = 1; i <= 25; i++) if (adsAnalyses >= i) ids.add(75 + i);
    return ids;
  }
}
