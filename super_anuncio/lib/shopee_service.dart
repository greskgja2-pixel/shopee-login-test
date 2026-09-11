part of 'main.dart';

class ShopeeService {
  static const _ua = 'Mozilla/5.0 (Linux; Android 15) AppleWebKit/537.36 Chrome/132.0 Mobile Safari/537.36';

  static Future<ShopeeProductData> fetchProduct(String rawUrl) async {
    var uri = Uri.parse(rawUrl.trim());
    var ids = _extractIds(uri.toString());
    if (ids == null) {
      try {
        uri = await _resolve(uri);
        ids = _extractIds(uri.toString());
      } catch (_) {}
    }
    if (ids == null) throw Exception('Não foi possível identificar item/shop no link.');
    final shopId = ids.$1;
    final itemId = ids.$2;

    Map<String, dynamic>? data;
    for (final endpoint in [
      'https://shopee.com.br/api/v4/item/get?itemid=$itemId&shopid=$shopId',
      'https://shopee.com.br/api/v4/pdp/get_pc?item_id=$itemId&shop_id=$shopId&tz_offset_minutes=-180&detail_level=0',
    ]) {
      try {
        final json = await _getJson(Uri.parse(endpoint));
        final dynamic root = json['data'];
        if (root is Map<String, dynamic>) {
          final item = root['item'];
          data = item is Map<String, dynamic> ? item : root;
          if (data.isNotEmpty) break;
        }
      } catch (_) {}
    }
    if (data == null) throw Exception('Shopee bloqueou a leitura automática.');
    return _productFromMap(data, rawUrl, shopId, itemId);
  }

  static Future<List<CompetitorCandidate>> searchCompetitors(String title, {String? ownItemId}) async {
    final query = _searchQuery(title);
    final uri = Uri.parse('https://shopee.com.br/api/v4/search/search_items?limit=30&newest=0&by=relevancy&keyword=${Uri.encodeQueryComponent(query)}&order=desc&page_type=search&scenario=PAGE_GLOBAL_SEARCH&version=2');
    final json = await _getJson(uri);
    final result = <CompetitorCandidate>[];
    final seen = <String>{};

    void visit(dynamic node) {
      if (node is Map) {
        final map = Map<String, dynamic>.from(node);
        final nested = map['item_basic'] is Map ? Map<String, dynamic>.from(map['item_basic']) : (map['item_card_full_item'] is Map ? Map<String, dynamic>.from(map['item_card_full_item']) : map);
        final candidate = _candidateFromMap(nested);
        if (candidate != null && candidate.itemId != ownItemId && seen.add(candidate.key)) result.add(candidate);
        for (final value in map.values) visit(value);
      } else if (node is List) {
        for (final value in node) visit(value);
      }
    }

    final items = json['items'];
    if (items is List) {
      for (final value in items) visit(value);
    } else {
      visit(json);
    }
    return result.take(30).toList();
  }

  static CompetitorCandidate? _candidateFromMap(Map<String, dynamic> map) {
    final itemId = _stringAny(map, ['itemid', 'item_id']);
    final shopId = _stringAny(map, ['shopid', 'shop_id']);
    final name = _stringAny(map, ['name', 'title']);
    if (itemId.isEmpty || shopId.isEmpty || name.length < 4) return null;
    final imageKey = _stringAny(map, ['image', 'image_id']);
    final rating = _nestedNumber(map, ['item_rating', 'rating_star']) ?? _numberAny(map, ['rating_star', 'rating']);
    final sold = _numberAny(map, ['sold', 'historical_sold', 'global_sold_count']);
    final price = _normalizePrice(_numberAny(map, ['price', 'price_min', 'current_price']));
    final desc = _stringAny(map, ['description']);
    final category = _categoryFrom(map);
    return CompetitorCandidate(
      title: name,
      price: price,
      link: 'https://shopee.com.br/product/$shopId/$itemId',
      imageUrl: imageKey.isEmpty ? null : _imageUrl(imageKey),
      rating: rating,
      sold: sold,
      shopId: shopId,
      itemId: itemId,
      description: desc,
      category: category,
    );
  }

  static ShopeeProductData _productFromMap(Map<String, dynamic> map, String url, String shopId, String itemId) {
    final title = _stringAny(map, ['name', 'title']);
    final description = _stringAny(map, ['description']);
    final imageKey = _stringAny(map, ['image', 'image_id']);
    final images = map['images'];
    final imageCount = images is List ? images.length : (imageKey.isNotEmpty ? 1 : 0);
    final rating = _nestedNumber(map, ['item_rating', 'rating_star']) ?? _numberAny(map, ['rating_star', 'rating']);
    final reviews = _numberAny(map, ['cmt_count', 'rating_count', 'review_count']);
    final sold = _numberAny(map, ['sold', 'historical_sold', 'global_sold_count']);
    final stock = _numberAny(map, ['stock']);
    final price = _normalizePrice(_numberAny(map, ['price', 'price_min', 'current_price']));
    final before = _normalizePrice(_numberAny(map, ['price_before_discount', 'price_min_before_discount']));
    final videoList = map['video_info_list'];
    final hasVideo = (videoList is List && videoList.isNotEmpty) || map['video_info'] != null;
    final attributes = map['attributes'];
    final models = map['models'];
    final tiers = map['tier_variations'];
    return ShopeeProductData(
      url: url,
      shopId: shopId,
      itemId: itemId,
      title: title,
      description: description,
      category: _categoryFrom(map),
      imageUrl: imageKey.isEmpty ? null : _imageUrl(imageKey),
      price: price,
      priceBeforeDiscount: before,
      rating: rating,
      reviewCount: reviews?.toInt(),
      sold: sold?.toInt(),
      stock: stock?.toInt(),
      imageCount: imageCount,
      hasVideo: hasVideo,
      attributesCount: attributes is List ? attributes.length : 0,
      variationCount: models is List ? models.length : (tiers is List ? tiers.length : 0),
    );
  }

  static Future<Uri> _resolve(Uri uri) async {
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 12);
    try {
      final request = await client.getUrl(uri);
      request.headers.set(HttpHeaders.userAgentHeader, _ua);
      request.followRedirects = true;
      request.maxRedirects = 6;
      final response = await request.close().timeout(const Duration(seconds: 15));
      await response.drain();
      if (response.redirects.isNotEmpty) {
        final last = response.redirects.last.location;
        return last.hasScheme ? last : uri.resolveUri(last);
      }
      return uri;
    } finally {
      client.close(force: true);
    }
  }

  static Future<Map<String, dynamic>> _getJson(Uri uri) async {
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 12);
    try {
      final request = await client.getUrl(uri);
      request.headers.set(HttpHeaders.userAgentHeader, _ua);
      request.headers.set(HttpHeaders.acceptHeader, 'application/json,text/plain,*/*');
      request.headers.set(HttpHeaders.refererHeader, 'https://shopee.com.br/');
      request.headers.set('x-api-source', 'pc');
      final response = await request.close().timeout(const Duration(seconds: 18));
      final body = await utf8.decoder.bind(response).join();
      if (response.statusCode < 200 || response.statusCode >= 300) throw HttpException('HTTP ${response.statusCode}');
      final decoded = jsonDecode(body);
      if (decoded is! Map) throw const FormatException('Resposta inválida');
      return Map<String, dynamic>.from(decoded);
    } finally {
      client.close(force: true);
    }
  }

  static (String, String)? _extractIds(String url) {
    for (final reg in [RegExp(r'i\.(\d+)\.(\d+)'), RegExp(r'/product/(\d+)/(\d+)'), RegExp(r'shopid=(\d+).*itemid=(\d+)'), RegExp(r'shop_id=(\d+).*item_id=(\d+)')]) {
      final m = reg.firstMatch(url);
      if (m != null) return (m.group(1)!, m.group(2)!);
    }
    return null;
  }

  static String _searchQuery(String title) {
    final words = title.replaceAll(RegExp(r'[^A-Za-z0-9À-ÖØ-öø-ÿ ]'), ' ').split(RegExp(r'\s+')).where((w) => w.length >= 3).take(10).toList();
    return words.join(' ');
  }

  static String _imageUrl(String key) => key.startsWith('http') ? key : 'https://down-br.img.susercontent.com/file/$key';

  static String _stringAny(Map<String, dynamic> map, List<String> keys) {
    for (final key in keys) {
      final v = map[key];
      if (v is String && v.trim().isNotEmpty) return v.trim();
      if (v is num) return v.toString();
    }
    return '';
  }

  static double? _numberAny(Map<String, dynamic> map, List<String> keys) {
    for (final key in keys) {
      final v = map[key];
      if (v is num) return v.toDouble();
      if (v is String) {
        final d = double.tryParse(v);
        if (d != null) return d;
      }
    }
    return null;
  }

  static double? _nestedNumber(Map<String, dynamic> map, List<String> path) {
    dynamic current = map;
    for (final key in path) {
      if (current is Map && current[key] != null) {
        current = current[key];
      } else {
        return null;
      }
    }
    if (current is num) return current.toDouble();
    return double.tryParse('$current');
  }

  static double? _normalizePrice(double? value) {
    if (value == null || value <= 0) return null;
    return value > 10000 ? value / 100000 : value;
  }

  static String _categoryFrom(Map<String, dynamic> map) {
    final cats = map['fe_categories'] ?? map['categories'];
    if (cats is List) {
      final names = <String>[];
      for (final c in cats) {
        if (c is Map) {
          final name = _stringAny(Map<String, dynamic>.from(c), ['display_name', 'name', 'catname']);
          if (name.isNotEmpty) names.add(name);
        }
      }
      if (names.isNotEmpty) return names.join(' > ');
    }
    return _stringAny(map, ['category', 'category_name']);
  }
}
