part of 'main.dart';

class GeminiService {
  static const String endpoint = 'https://auditor-ia-oficial.vercel.app/api/mobile-analysis';

  static Future<AnalysisResult?> analyze(AnalysisInput input) async {
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 12);
    try {
      final req = await client.postUrl(Uri.parse(endpoint));
      req.headers.contentType = ContentType.json;
      req.headers.set(HttpHeaders.acceptHeader, 'application/json');
      final p = input.product;
      final gallery = p is RichShopeeProductData
          ? p.imageUrls.take(8).toList()
          : <String>[if (p?.imageUrl != null) p!.imageUrl!];
      final payload = {
        'product': {
          'url': input.url,
          'title': input.title,
          'description': input.description,
          'category': input.category,
          'price': input.price,
          'imageUrl': p?.imageUrl,
          'imageUrls': gallery,
          'priceBeforeDiscount': p?.priceBeforeDiscount,
          'rating': p?.rating,
          'reviewCount': p?.reviewCount,
          'sold': p?.sold,
          'stock': p?.stock,
          'imageCount': p?.imageCount,
          'hasVideo': p?.hasVideo,
          'attributesCount': p?.attributesCount,
          'variationCount': p?.variationCount,
        },
        'competitors': input.competitors.map((c) => {
          'title': c.title,
          'description': c.description,
          'category': c.category,
          'price': c.price,
          'rating': c.rating,
          'sold': c.sold,
          'imageUrl': c.imageUrl,
          'link': c.link,
        }).toList(),
        'context': {
          'goal': input.goal,
          'stage': input.stage,
          'issue': input.issue,
          'adsActive': input.adsActive,
          'roas7d': input.roas7d,
          'adsSpend7d': input.adsSpend7d,
        },
      };
      req.write(jsonEncode(payload));
      final response = await req.close().timeout(const Duration(seconds: 55));
      final text = await utf8.decoder.bind(response).join();
      if (response.statusCode < 200 || response.statusCode >= 300) return null;
      final decoded = jsonDecode(text);
      if (decoded is! Map) return null;
      return _fromMap(input, Map<String, dynamic>.from(decoded));
    } catch (_) {
      return null;
    } finally {
      client.close(force: true);
    }
  }

  static AnalysisResult _fromMap(AnalysisInput input, Map<String, dynamic> map) {
    final local = AnalysisResult.build(input);
    final dimensions = <AuditDimension>[];
    final rawDims = map['dimensions'];
    if (rawDims is List) {
      for (final raw in rawDims) {
        if (raw is! Map) continue;
        final d = Map<String, dynamic>.from(raw);
        final name = '${d['name'] ?? ''}'.trim();
        final max = _int(d['maxScore']) ?? _maxFor(name);
        final score = (_int(d['score']) ?? 0).clamp(0, max);
        dimensions.add(AuditDimension(
          name: name.isEmpty ? 'Auditoria' : name,
          icon: _iconFor(name),
          score: score,
          maxScore: max,
          reason: '${d['reason'] ?? ''}'.trim(),
          action: '${d['action'] ?? ''}'.trim(),
        ));
      }
    }
    final finalDims = dimensions.length == 9 ? dimensions : local.dimensions;
    final total = finalDims.fold<int>(0, (s, d) => s + d.score).clamp(0, 100);
    final optimizedTitle = _str(map['optimizedTitle']) ?? local.optimizedTitle;
    final optimizedDescription = _str(map['optimizedDescription']) ?? local.optimizedDescription;
    final suggestedCategory = _str(map['suggestedCategory']) ?? local.suggestedCategory;
    final priceInsight = _str(map['priceInsight']) ?? local.priceInsight;
    final summary = _str(map['summary']) ?? local.summary;

    final lessons = finalDims.where((d) => d.score < d.maxScore * .9).map((d) {
      String current = d.reason;
      String optimized = d.action;
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

    return AnalysisResult(
      input: input,
      score: total,
      summary: summary,
      optimizedTitle: optimizedTitle,
      optimizedDescription: optimizedDescription,
      suggestedCategory: suggestedCategory,
      dimensions: finalDims,
      lessons: lessons.isEmpty ? local.lessons : lessons,
      competitorMedian: medianPrice(input.competitors),
      priceInsight: priceInsight,
      competitors: input.competitors,
    );
  }

  static String? _str(dynamic value) {
    final s = value is String ? value.trim() : '';
    return s.isEmpty ? null : s;
  }

  static int? _int(dynamic value) {
    if (value is num) return value.round();
    return int.tryParse('$value');
  }

  static int _maxFor(String name) {
    switch (name) {
      case 'Título': return 12;
      case 'Descrição': return 12;
      case 'Imagens': return 15;
      case 'Vídeo': return 8;
      case 'Categoria': return 8;
      case 'Preço e concorrência': return 15;
      case 'Prova social': return 10;
      case 'Atributos, estoque e variações': return 8;
      case 'Ads e eficiência': return 12;
      default: return 10;
    }
  }

  static IconData _iconFor(String name) {
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
}
