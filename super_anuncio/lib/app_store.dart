part of 'main.dart';

typedef AnalysisGeneratedCallback = void Function(AnalysisResult result, String? previousAnalysisId);

/// Extensão do modelo coletado que preserva a galeria completa para a análise visual.
class RichShopeeProductData extends ShopeeProductData {
  final List<String> imageUrls;
  const RichShopeeProductData({
    required super.url,
    required super.shopId,
    required super.itemId,
    required super.title,
    required super.description,
    required super.category,
    required super.imageUrl,
    required super.price,
    required super.priceBeforeDiscount,
    super.priceMin,
    super.priceMax,
    super.bestSellingVariationName,
    super.bestSellingVariationPrice,
    super.bestSellingVariationSold,
    super.priceBasis,
    required super.rating,
    required super.reviewCount,
    required super.sold,
    required super.stock,
    required super.imageCount,
    required super.hasVideo,
    required super.attributesCount,
    required super.variationCount,
    this.imageUrls = const [],
  });
}

class StoredAnalysis {
  final String id;
  final DateTime createdAt;
  final AnalysisResult result;
  StoredAnalysis({required this.id, required this.createdAt, required this.result});

  factory StoredAnalysis.fromResult(AnalysisResult result) {
    final now = DateTime.now();
    final itemId = result.input.product?.itemId ?? '';
    return StoredAnalysis(
      id: '${itemId.isEmpty ? 'analysis' : itemId}_${now.microsecondsSinceEpoch}',
      createdAt: now,
      result: result,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'createdAt': createdAt.toIso8601String(),
        'result': _resultToJson(result),
      };

  static StoredAnalysis? fromJson(dynamic raw) {
    if (raw is! Map) return null;
    try {
      final m = Map<String, dynamic>.from(raw);
      final resultRaw = m['result'];
      if (resultRaw is! Map) return null;
      return StoredAnalysis(
        id: '${m['id'] ?? ''}',
        createdAt: DateTime.tryParse('${m['createdAt'] ?? ''}') ?? DateTime.now(),
        result: _resultFromJson(Map<String, dynamic>.from(resultRaw)),
      );
    } catch (_) {
      return null;
    }
  }
}

class ProductHistoryRecord {
  final String key;
  String url;
  String title;
  String? imageUrl;
  final List<StoredAnalysis> analyses;

  ProductHistoryRecord({
    required this.key,
    required this.url,
    required this.title,
    required this.imageUrl,
    List<StoredAnalysis>? analyses,
  }) : analyses = analyses ?? [];

  StoredAnalysis? get latest {
    if (analyses.isEmpty) return null;
    final copy = [...analyses]..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return copy.first;
  }

  StoredAnalysis? get first {
    if (analyses.isEmpty) return null;
    final copy = [...analyses]..sort((a, b) => a.createdAt.compareTo(b.createdAt));
    return copy.first;
  }

  int get scoreDelta {
    final a = first?.result.score;
    final b = latest?.result.score;
    if (a == null || b == null) return 0;
    return b - a;
  }

  Map<String, dynamic> toJson() => {
        'key': key,
        'url': url,
        'title': title,
        'imageUrl': imageUrl,
        'analyses': analyses.map((e) => e.toJson()).toList(),
      };

  static ProductHistoryRecord? fromJson(dynamic raw) {
    if (raw is! Map) return null;
    try {
      final m = Map<String, dynamic>.from(raw);
      final analyses = <StoredAnalysis>[];
      for (final a in (m['analyses'] as List? ?? const [])) {
        final parsed = StoredAnalysis.fromJson(a);
        if (parsed != null) analyses.add(parsed);
      }
      return ProductHistoryRecord(
        key: '${m['key'] ?? ''}',
        url: '${m['url'] ?? ''}',
        title: '${m['title'] ?? ''}',
        imageUrl: _nullableString(m['imageUrl']),
        analyses: analyses,
      );
    } catch (_) {
      return null;
    }
  }
}

class ReanalysisTask {
  final String id;
  final String productKey;
  final String sourceAnalysisId;
  final String title;
  final String url;
  final DateTime dueAt;
  DateTime? completedAt;
  String? completedAnalysisId;

  ReanalysisTask({
    required this.id,
    required this.productKey,
    required this.sourceAnalysisId,
    required this.title,
    required this.url,
    required this.dueAt,
    this.completedAt,
    this.completedAnalysisId,
  });

  bool get completed => completedAt != null;

  Map<String, dynamic> toJson() => {
        'id': id,
        'productKey': productKey,
        'sourceAnalysisId': sourceAnalysisId,
        'title': title,
        'url': url,
        'dueAt': dueAt.toIso8601String(),
        'completedAt': completedAt?.toIso8601String(),
        'completedAnalysisId': completedAnalysisId,
      };

  static ReanalysisTask? fromJson(dynamic raw) {
    if (raw is! Map) return null;
    try {
      final m = Map<String, dynamic>.from(raw);
      return ReanalysisTask(
        id: '${m['id'] ?? ''}',
        productKey: '${m['productKey'] ?? ''}',
        sourceAnalysisId: '${m['sourceAnalysisId'] ?? ''}',
        title: '${m['title'] ?? ''}',
        url: '${m['url'] ?? ''}',
        dueAt: DateTime.tryParse('${m['dueAt'] ?? ''}') ?? DateTime.now(),
        completedAt: DateTime.tryParse('${m['completedAt'] ?? ''}'),
        completedAnalysisId: _nullableString(m['completedAnalysisId']),
      );
    } catch (_) {
      return null;
    }
  }
}

class PersistedAppState {
  final List<ProductHistoryRecord> products;
  final List<ReanalysisTask> tasks;
  final Set<int> unlockedAchievements;
  int finalizedAnalyses;
  int competitorSelections;
  int adsAnalyses;
  int bestScore;
  int gameHighScore;
  bool gameHintDismissed;

  PersistedAppState({
    List<ProductHistoryRecord>? products,
    List<ReanalysisTask>? tasks,
    Set<int>? unlockedAchievements,
    this.finalizedAnalyses = 0,
    this.competitorSelections = 0,
    this.adsAnalyses = 0,
    this.bestScore = 0,
    this.gameHighScore = 0,
    this.gameHintDismissed = false,
  })  : products = products ?? [],
        tasks = tasks ?? [],
        unlockedAchievements = unlockedAchievements ?? <int>{};

  Map<String, dynamic> toJson() => {
        'schema': 3,
        'products': products.map((e) => e.toJson()).toList(),
        'tasks': tasks.map((e) => e.toJson()).toList(),
        'unlockedAchievements': unlockedAchievements.toList(),
        'finalizedAnalyses': finalizedAnalyses,
        'competitorSelections': competitorSelections,
        'adsAnalyses': adsAnalyses,
        'bestScore': bestScore,
        'gameHighScore': gameHighScore,
        'gameHintDismissed': gameHintDismissed,
      };

  static PersistedAppState fromJson(dynamic raw) {
    if (raw is! Map) return PersistedAppState();
    final m = Map<String, dynamic>.from(raw);
    final products = <ProductHistoryRecord>[];
    for (final p in (m['products'] as List? ?? const [])) {
      final parsed = ProductHistoryRecord.fromJson(p);
      if (parsed != null && parsed.key.isNotEmpty) products.add(parsed);
    }
    final tasks = <ReanalysisTask>[];
    for (final t in (m['tasks'] as List? ?? const [])) {
      final parsed = ReanalysisTask.fromJson(t);
      if (parsed != null && parsed.id.isNotEmpty) tasks.add(parsed);
    }
    final unlocked = <int>{};
    for (final id in (m['unlockedAchievements'] as List? ?? const [])) {
      if (id is num) unlocked.add(id.toInt());
    }
    return PersistedAppState(
      products: products,
      tasks: tasks,
      unlockedAchievements: unlocked,
      finalizedAnalyses: _asInt(m['finalizedAnalyses']) ?? 0,
      competitorSelections: _asInt(m['competitorSelections']) ?? 0,
      adsAnalyses: _asInt(m['adsAnalyses']) ?? 0,
      bestScore: _asInt(m['bestScore']) ?? 0,
      gameHighScore: _asInt(m['gameHighScore']) ?? 0,
      gameHintDismissed: m['gameHintDismissed'] == true,
    );
  }
}

class AppStore {
  static const _key = 'super_anuncio_state_v2';

  static Future<PersistedAppState> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_key);
      if (raw == null || raw.isEmpty) return PersistedAppState();
      return PersistedAppState.fromJson(jsonDecode(raw));
    } catch (_) {
      return PersistedAppState();
    }
  }

  static Future<void> save(PersistedAppState state) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_key, jsonEncode(state.toJson()));
    } catch (_) {}
  }
}

String productHistoryKey(AnalysisResult result) {
  final itemId = result.input.product?.itemId.trim() ?? '';
  if (itemId.isNotEmpty) return 'item:$itemId';
  final uri = Uri.tryParse(result.input.url);
  if (uri != null) return 'url:${uri.host}${uri.path}'.toLowerCase();
  return 'url:${result.input.url.trim().toLowerCase()}';
}

StoredAnalysis? findStoredAnalysis(PersistedAppState state, String id) {
  for (final product in state.products) {
    for (final analysis in product.analyses) {
      if (analysis.id == id) return analysis;
    }
  }
  return null;
}

ProductHistoryRecord? findProductForAnalysis(PersistedAppState state, AnalysisResult result) {
  for (final product in state.products) {
    for (final analysis in product.analyses) {
      if (identical(analysis.result, result)) return product;
    }
  }
  final key = productHistoryKey(result);
  for (final product in state.products) {
    if (product.key == key) return product;
  }
  return null;
}

StoredAnalysis? findStoredForResult(PersistedAppState state, AnalysisResult result) {
  for (final product in state.products) {
    for (final analysis in product.analyses) {
      if (identical(analysis.result, result)) return analysis;
    }
  }
  return null;
}

Map<String, dynamic> _resultToJson(AnalysisResult r) => {
      'input': _inputToJson(r.input),
      'score': r.score,
      'summary': r.summary,
      'optimizedTitle': r.optimizedTitle,
      'optimizedDescription': r.optimizedDescription,
      'suggestedCategory': r.suggestedCategory,
      'dimensions': r.dimensions
          .map((d) => {
                'name': d.name,
                'score': d.score,
                'maxScore': d.maxScore,
                'reason': d.reason,
                'action': d.action,
              })
          .toList(),
      'lessons': r.lessons
          .map((l) => {
                'title': l.title,
                'current': l.current,
                'optimized': l.optimized,
                'why': l.why,
                'how': l.how,
              })
          .toList(),
      'competitorMedian': r.competitorMedian,
      'priceInsight': r.priceInsight,
      'competitors': r.competitors.map(_competitorToJson).toList(),
      'finalized': r.finalized,
      'reanalyzeAt': r.reanalyzeAt?.toIso8601String(),
    };

AnalysisResult _resultFromJson(Map<String, dynamic> m) {
  final input = _inputFromJson(Map<String, dynamic>.from(m['input'] as Map? ?? const {}));
  final dims = <AuditDimension>[];
  for (final raw in (m['dimensions'] as List? ?? const [])) {
    if (raw is! Map) continue;
    final d = Map<String, dynamic>.from(raw);
    final name = '${d['name'] ?? ''}';
    dims.add(AuditDimension(
      name: name,
      icon: _auditIcon(name),
      score: _asInt(d['score']) ?? 0,
      maxScore: _asInt(d['maxScore']) ?? 1,
      reason: '${d['reason'] ?? ''}',
      action: '${d['action'] ?? ''}',
    ));
  }
  final lessons = <GuidedLesson>[];
  for (final raw in (m['lessons'] as List? ?? const [])) {
    if (raw is! Map) continue;
    final l = Map<String, dynamic>.from(raw);
    final title = '${l['title'] ?? ''}';
    lessons.add(GuidedLesson(
      title: title,
      icon: _auditIcon(title),
      current: '${l['current'] ?? ''}',
      optimized: '${l['optimized'] ?? ''}',
      why: '${l['why'] ?? ''}',
      how: '${l['how'] ?? ''}',
    ));
  }
  final comps = <CompetitorCandidate>[];
  for (final raw in (m['competitors'] as List? ?? const [])) {
    final c = _competitorFromJson(raw);
    if (c != null) comps.add(c);
  }
  final local = AnalysisResult.build(input);
  return AnalysisResult(
    input: input,
    score: _asInt(m['score']) ?? local.score,
    summary: '${m['summary'] ?? local.summary}',
    optimizedTitle: '${m['optimizedTitle'] ?? local.optimizedTitle}',
    optimizedDescription: '${m['optimizedDescription'] ?? local.optimizedDescription}',
    suggestedCategory: '${m['suggestedCategory'] ?? local.suggestedCategory}',
    dimensions: dims.isEmpty ? local.dimensions : dims,
    lessons: lessons.isEmpty ? local.lessons : lessons,
    competitorMedian: _asDouble(m['competitorMedian']),
    priceInsight: '${m['priceInsight'] ?? local.priceInsight}',
    competitors: comps.isEmpty ? input.competitors : comps,
    finalized: m['finalized'] == true,
    reanalyzeAt: DateTime.tryParse('${m['reanalyzeAt'] ?? ''}'),
  );
}

Map<String, dynamic> _inputToJson(AnalysisInput i) => {
      'url': i.url,
      'title': i.title,
      'description': i.description,
      'category': i.category,
      'price': i.price,
      'goal': i.goal,
      'stage': i.stage,
      'issue': i.issue,
      'adsActive': i.adsActive,
      'roas7d': i.roas7d,
      'roasTarget': i.roasTarget,
      'adsSpend7d': i.adsSpend7d,
      'productCost': i.productCost,
      'variationCosts': i.variationCosts,
      'product': _productToJson(i.product),
      'competitors': i.competitors.map(_competitorToJson).toList(),
    };

AnalysisInput _inputFromJson(Map<String, dynamic> m) {
  final comps = <CompetitorCandidate>[];
  for (final raw in (m['competitors'] as List? ?? const [])) {
    final c = _competitorFromJson(raw);
    if (c != null) comps.add(c);
  }
  return AnalysisInput(
    url: '${m['url'] ?? ''}',
    title: '${m['title'] ?? ''}',
    description: '${m['description'] ?? ''}',
    category: '${m['category'] ?? ''}',
    price: _asDouble(m['price']),
    goal: '${m['goal'] ?? 'Vender mais'}',
    stage: '${m['stage'] ?? 'Já vende'}',
    issue: '${m['issue'] ?? 'Poucas visitas'}',
    adsActive: m['adsActive'] == true,
    roas7d: _asDouble(m['roas7d']),
    roasTarget: _asDouble(m['roasTarget']),
    adsSpend7d: _asDouble(m['adsSpend7d']),
    productCost: _asDouble(m['productCost']),
    variationCosts: (m['variationCosts'] is Map)
        ? Map<String, double>.fromEntries(
            Map<String, dynamic>.from(m['variationCosts'] as Map)
                .entries
                .map((e) => MapEntry(e.key, _asDouble(e.value)))
                .where((e) => e.value != null)
                .map((e) => MapEntry(e.key, e.value!)),
          )
        : const {},
    product: _productFromJson(m['product']),
    competitors: comps,
  );
}

Map<String, dynamic>? _productToJson(ShopeeProductData? p) {
  if (p == null) return null;
  return {
    'url': p.url,
    'shopId': p.shopId,
    'itemId': p.itemId,
    'title': p.title,
    'description': p.description,
    'category': p.category,
    'imageUrl': p.imageUrl,
    'imageUrls': p is RichShopeeProductData ? p.imageUrls : <String>[if (p.imageUrl != null) p.imageUrl!],
    'price': p.price,
    'priceBeforeDiscount': p.priceBeforeDiscount,
    'priceMin': p.priceMin,
    'priceMax': p.priceMax,
    'bestSellingVariationName': p.bestSellingVariationName,
    'bestSellingVariationPrice': p.bestSellingVariationPrice,
    'bestSellingVariationSold': p.bestSellingVariationSold,
    'priceBasis': p.priceBasis,
    'rating': p.rating,
    'reviewCount': p.reviewCount,
    'sold': p.sold,
    'stock': p.stock,
    'imageCount': p.imageCount,
    'hasVideo': p.hasVideo,
    'attributesCount': p.attributesCount,
    'variationCount': p.variationCount,
    'variations': p.variations
        .map((v) => {'name': v.name, 'price': v.price, 'sold': v.sold})
        .toList(),
  };
}

ShopeeProductData? _productFromJson(dynamic raw) {
  if (raw is! Map) return null;
  final m = Map<String, dynamic>.from(raw);
  final images = (m['imageUrls'] as List? ?? const []).map((e) => '$e').where((e) => e.startsWith('http')).toList();
  return RichShopeeProductData(
    url: '${m['url'] ?? ''}',
    shopId: '${m['shopId'] ?? ''}',
    itemId: '${m['itemId'] ?? ''}',
    title: '${m['title'] ?? ''}',
    description: '${m['description'] ?? ''}',
    category: '${m['category'] ?? ''}',
    imageUrl: _nullableString(m['imageUrl']),
    imageUrls: images,
    price: _asDouble(m['price']),
    priceBeforeDiscount: _asDouble(m['priceBeforeDiscount']),
    priceMin: _asDouble(m['priceMin']),
    priceMax: _asDouble(m['priceMax']),
    bestSellingVariationName: _nullableString(m['bestSellingVariationName']),
    bestSellingVariationPrice: _asDouble(m['bestSellingVariationPrice']),
    bestSellingVariationSold: _asInt(m['bestSellingVariationSold']),
    priceBasis: _nullableString(m['priceBasis']),
    rating: _asDouble(m['rating']),
    reviewCount: _asInt(m['reviewCount']),
    sold: _asInt(m['sold']),
    stock: _asInt(m['stock']),
    imageCount: _asInt(m['imageCount']) ?? images.length,
    hasVideo: m['hasVideo'] == true,
    attributesCount: _asInt(m['attributesCount']) ?? 0,
    variationCount: _asInt(m['variationCount']) ?? 0,
    variations: (m['variations'] as List? ?? const [])
        .whereType<Map>()
        .map((raw) {
          final v = Map<String, dynamic>.from(raw);
          return ProductVariationData(
            name: '${v['name'] ?? ''}'.trim(),
            price: _asDouble(v['price']),
            sold: _asInt(v['sold']),
          );
        })
        .where((v) => v.name.isNotEmpty)
        .toList(),
  );
}

Map<String, dynamic> _competitorToJson(CompetitorCandidate c) => {
      'title': c.title,
      'price': c.price,
      'priceMin': c.priceMin,
      'priceMax': c.priceMax,
      'bestSellingVariationName': c.bestSellingVariationName,
      'bestSellingVariationPrice': c.bestSellingVariationPrice,
      'bestSellingVariationSold': c.bestSellingVariationSold,
      'priceBasis': c.priceBasis,
      'link': c.link,
      'imageUrl': c.imageUrl,
      'rating': c.rating,
      'sold': c.sold,
      'shopId': c.shopId,
      'itemId': c.itemId,
      'description': c.description,
      'category': c.category,
    };

CompetitorCandidate? _competitorFromJson(dynamic raw) {
  if (raw is! Map) return null;
  final m = Map<String, dynamic>.from(raw);
  return CompetitorCandidate(
    title: '${m['title'] ?? ''}',
    price: _asDouble(m['price']),
    priceMin: _asDouble(m['priceMin']),
    priceMax: _asDouble(m['priceMax']),
    bestSellingVariationName: _nullableString(m['bestSellingVariationName']),
    bestSellingVariationPrice: _asDouble(m['bestSellingVariationPrice']),
    bestSellingVariationSold: _asDouble(m['bestSellingVariationSold']),
    priceBasis: _nullableString(m['priceBasis']),
    link: '${m['link'] ?? ''}',
    imageUrl: _nullableString(m['imageUrl']),
    rating: _asDouble(m['rating']),
    sold: _asDouble(m['sold']),
    shopId: _nullableString(m['shopId']),
    itemId: '${m['itemId'] ?? ''}',
    description: '${m['description'] ?? ''}',
    category: '${m['category'] ?? ''}',
  );
}

IconData _auditIcon(String name) {
  switch (name) {
    case 'Título': return Icons.title;
    case 'Descrição': return Icons.description_outlined;
    case 'Imagens': return Icons.image_outlined;
    case 'Vídeo': return Icons.play_circle_outline;
    case 'Categoria': return Icons.category_outlined;
    case 'Preço e concorrência': return Icons.groups_outlined;
    case 'Prova social': return Icons.star_outline;
    case 'Atributos, estoque e variações': return Icons.inventory_2_outlined;
    case 'Ads e eficiência': return Icons.campaign_outlined;
    default: return Icons.auto_awesome;
  }
}

String? _nullableString(dynamic value) {
  final s = value is String ? value.trim() : '';
  return s.isEmpty || s == 'null' ? null : s;
}

int? _asInt(dynamic value) {
  if (value is num) return value.round();
  return int.tryParse('$value');
}

double? _asDouble(dynamic value) {
  if (value is num) return value.toDouble();
  return double.tryParse('$value');
}
