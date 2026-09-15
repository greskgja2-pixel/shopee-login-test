part of 'main.dart';

class ShopeeCompetitorPicker {
  static Future<List<CompetitorCandidate>> pick(
    BuildContext context,
    String title, {
    String? ownItemId,
  }) async {
    final query = title.trim();
    if (query.isEmpty) return const [];

    final url =
        'https://shopee.com.br/search?keyword=${Uri.encodeQueryComponent(query)}';
    final raw = await Navigator.of(context).push<List<dynamic>>(
      MaterialPageRoute(
        builder: (_) => _ShopeeCompetitorPickerPage(
          targetUrl: url,
          ownItemId: ownItemId,
        ),
      ),
    );
    if (raw == null) return const [];

    final out = <CompetitorCandidate>[];
    final seen = <String>{};

    for (final value in raw) {
      if (value is! Map) continue;
      final m = Map<String, dynamic>.from(value);
      final itemId = '${m['itemId'] ?? ''}'.trim();
      final shopId = '${m['shopId'] ?? ''}'.trim();
      final link = '${m['link'] ?? ''}'.trim();
      final title = '${m['title'] ?? ''}'.trim();

      if (title.length < 4 || link.isEmpty || itemId == ownItemId) continue;
      final key = itemId.isNotEmpty ? itemId : link;
      if (!seen.add(key)) continue;

      final price = _d(m['price']) ?? _d(m['priceMin']);
      out.add(
        CompetitorCandidate(
          title: title,
          price: price,
          priceMin: _d(m['priceMin']) ?? price,
          priceMax: _d(m['priceMax']) ?? price,
          bestSellingVariationName: _s(m['bestSellingVariationName']),
          bestSellingVariationPrice: _d(m['bestSellingVariationPrice']),
          bestSellingVariationSold: _d(m['bestSellingVariationSold']),
          priceBasis: _s(m['priceBasis']) ?? 'manual_search_selection',
          link: link,
          imageUrl: _s(m['imageUrl']),
          rating: _d(m['rating']),
          sold: _d(m['sold']),
          shopId: shopId.isEmpty ? null : shopId,
          itemId: itemId.isEmpty ? link.hashCode.abs().toString() : itemId,
          description: '${m['description'] ?? ''}'.trim(),
          category: '${m['category'] ?? ''}'.trim(),
        ),
      );
    }

    return out.take(3).toList();
  }

  static String? _s(dynamic v) {
    final text = v == null ? '' : '$v'.trim();
    return text.isEmpty ? null : text;
  }

  static double? _d(dynamic v) {
    if (v is num) return v.toDouble();
    return double.tryParse('$v');
  }
}

class _ShopeeCompetitorPickerPage extends StatefulWidget {
  final String targetUrl;
  final String? ownItemId;

  const _ShopeeCompetitorPickerPage({
    required this.targetUrl,
    this.ownItemId,
  });

  @override
  State<_ShopeeCompetitorPickerPage> createState() =>
      _ShopeeCompetitorPickerPageState();
}

class _ShopeeCompetitorPickerPageState
    extends State<_ShopeeCompetitorPickerPage> {
  late final WebViewController controller;
  final Map<String, Map<String, dynamic>> selected = {};
  Timer? injector;
  Timer? finishFallback;
  bool loading = true;
  bool finalizing = false;
  String status =
      'Abrindo a pesquisa da Shopee. Selecione exatamente 3 concorrentes.';

  @override
  void initState() {
    super.initState();

    controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0xFFFFFFFF))
      ..setUserAgent(
        'Mozilla/5.0 (Windows NT 10.0; Win64; x64) '
        'AppleWebKit/537.36 (KHTML, like Gecko) '
        'Chrome/151.0.0.0 Safari/537.36',
      )
      ..addJavaScriptChannel(
        'CompetitorPicker',
        onMessageReceived: _onMessage,
      )
      ..setNavigationDelegate(
        NavigationDelegate(
          onNavigationRequest: _onNavigation,
          onPageStarted: (_) {
            injector?.cancel();
            if (!mounted) return;
            setState(() {
              loading = true;
              status =
                  'Carregando resultados da Shopee. Aguarde os botões Selecionar.';
            });
          },
          onPageFinished: (_) {
            if (!mounted) return;
            setState(() {
              loading = false;
              status =
                  'Toque em Selecionar nos 3 anúncios que você considera concorrentes.';
            });
            Future.delayed(
              const Duration(milliseconds: 450),
              _injectPicker,
            );
            injector = Timer.periodic(
              const Duration(milliseconds: 1300),
              (_) => _injectPicker(),
            );
          },
          onWebResourceError: (error) {
            if (!mounted || error.isForMainFrame != true) return;
            if (error.description
                .toLowerCase()
                .contains('unknown_url_scheme')) {
              return;
            }
            setState(() {
              loading = false;
              status =
                  'A Shopee não terminou de carregar. Use atualizar e tente novamente.';
            });
          },
        ),
      )
      ..loadRequest(Uri.parse(widget.targetUrl));
  }

  @override
  void dispose() {
    injector?.cancel();
    finishFallback?.cancel();
    super.dispose();
  }

  NavigationDecision _onNavigation(NavigationRequest request) {
    final uri = Uri.tryParse(request.url);
    if (uri == null) return NavigationDecision.prevent;

    if (uri.scheme != 'http' &&
        uri.scheme != 'https' &&
        uri.scheme != 'about' &&
        uri.scheme != 'data') {
      return NavigationDecision.prevent;
    }

    if (_isProductUrl(request.url)) return NavigationDecision.prevent;
    return NavigationDecision.navigate;
  }

  bool _isProductUrl(String url) {
    return RegExp(r'-i\.\d+\.\d+').hasMatch(url) ||
        RegExp(r'/product/\d+/\d+').hasMatch(url);
  }

  void _onMessage(JavaScriptMessage message) {
    dynamic decoded;
    try {
      decoded = jsonDecode(message.message);
    } catch (_) {
      return;
    }
    if (decoded is! Map || !mounted) return;

    final data = Map<String, dynamic>.from(decoded);
    final type = '${data['type'] ?? ''}';

    if (type == 'toggle') {
      final rawItem = data['item'];
      if (rawItem is! Map) return;
      final item = Map<String, dynamic>.from(rawItem);
      final itemId = '${item['itemId'] ?? ''}'.trim();
      final link = '${item['link'] ?? ''}'.trim();
      final key = itemId.isNotEmpty ? itemId : link;
      if (key.isEmpty || itemId == widget.ownItemId) return;

      if (selected.containsKey(key)) {
        setState(() => selected.remove(key));
      } else if (selected.length < 3) {
        setState(() => selected[key] = item);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Você já escolheu 3 concorrentes. Desmarque um para trocar.',
            ),
          ),
        );
      }
      _syncSelection();
      return;
    }

    if (type == 'done') {
      final items = data['items'];
      if (items is List) {
        _complete(List<dynamic>.from(items));
      } else {
        _complete(selected.values.toList());
      }
      return;
    }

    if (type == 'ready' && !loading) {
      setState(() {
        status =
            'Escolha 3 concorrentes. Os selecionados ficam destacados em laranja.';
      });
    }
  }

  Future<void> _injectPicker() async {
    if (!mounted || loading || finalizing) return;
    try {
      await controller.runJavaScript(_pickerScript);
      await _syncSelection();
    } catch (_) {}
  }

  Future<void> _syncSelection() async {
    if (!mounted) return;
    final ids = selected.values
        .map((e) => '${e['itemId'] ?? ''}'.trim())
        .where((e) => e.isNotEmpty)
        .toList();
    try {
      await controller.runJavaScript(
        'window.__GS_PICKER_SET_SELECTED__ && '
        'window.__GS_PICKER_SET_SELECTED__(${jsonEncode(ids)});',
      );
    } catch (_) {}
  }

  Future<void> _finishSelection() async {
    if (selected.length != 3 || finalizing) return;

    injector?.cancel();
    setState(() {
      finalizing = true;
      status = 'Importando os dados dos 3 concorrentes selecionados...';
    });

    final raw = selected.values.toList();
    finishFallback?.cancel();
    finishFallback = Timer(
      const Duration(seconds: 8),
      () => _complete(raw),
    );

    try {
      await controller.runJavaScript(
        'window.__GS_PICKER_FINALIZE__ && '
        'window.__GS_PICKER_FINALIZE__(${jsonEncode(raw)});',
      );
    } catch (_) {
      _complete(raw);
    }
  }

  void _complete(List<dynamic> items) {
    if (!mounted || !finalizing) return;
    finishFallback?.cancel();
    finalizing = false;
    Navigator.of(context).pop(items);
  }

  String get _pickerScript {
    final ownItemId = jsonEncode(widget.ownItemId ?? '');
    return r'''
(() => {
  const OWN_ITEM_ID = ''' +
        ownItemId +
        r''';
  const CHANNEL = window.CompetitorPicker;
  if (!CHANNEL || !CHANNEL.postMessage) return false;

  const clean = s => String(s || '').replace(/\s+/g, ' ').trim();
  const idsFrom = url => {
    let m = String(url || '').match(/-i\.(\d+)\.(\d+)/);
    if (!m) m = String(url || '').match(/\/product\/(\d+)\/(\d+)/);
    return m ? {shopId: m[1], itemId: m[2]} : null;
  };
  const brl = raw => {
    const m = String(raw || '').match(/R\$\s*([0-9][0-9.]*(?:,[0-9]{1,2})?)/);
    if (!m) return null;
    const n = Number(m[1].replace(/\./g, '').replace(',', '.'));
    return Number.isFinite(n) && n > 0 ? n : null;
  };
  const sold = raw => {
    const m = String(raw || '').toLowerCase()
      .match(/([0-9]+(?:[.,][0-9]+)?)\s*(mil|k)?\s+vendid/);
    if (!m) return null;
    let n = Number(m[1].replace(',', '.'));
    if (!Number.isFinite(n)) return null;
    if (m[2]) n *= 1000;
    return Math.round(n);
  };
  const findCard = a => {
    const preferred = a.closest(
      '[data-sqe="item"],.shopee-search-item-result__item,' +
      '[class*="search-item-result__item"],[class*="product-card"]'
    );
    if (preferred) return preferred;
    let el = a;
    for (let i = 0; i < 8 && el; i++, el = el.parentElement) {
      const text = clean(el.innerText || '');
      if (text.length > 20 && /R\$/.test(text) && el.querySelector('img')) {
        return el;
      }
    }
    return a.parentElement || a;
  };
  const itemFrom = (a, card, ids) => {
    const raw = clean(card.innerText || '');
    const img = card.querySelector('img');
    let title = clean(
      card.querySelector(
        '[data-sqe="name"],[class*="name"],[class*="title"]'
      )?.innerText ||
      img?.alt ||
      a.getAttribute('aria-label') ||
      ''
    );
    if (title.length < 4) {
      title = clean(raw.split(/R\$/)[0]).slice(0, 220);
    }
    return {
      title,
      price: brl(raw),
      priceMin: brl(raw),
      priceMax: brl(raw),
      priceBasis: 'manual_search_card',
      link: a.href,
      imageUrl: img?.currentSrc || img?.src || null,
      rating: null,
      sold: sold(raw),
      shopId: ids.shopId,
      itemId: ids.itemId,
      description: '',
      category: ''
    };
  };

  if (!document.getElementById('gs-competitor-picker-style')) {
    const style = document.createElement('style');
    style.id = 'gs-competitor-picker-style';
    style.textContent = `
      .gs-picker-card { position: relative !important; }
      .gs-picker-card.gs-picker-selected {
        outline: 4px solid #ff5a1f !important;
        outline-offset: -4px !important;
        border-radius: 10px !important;
      }
      .gs-picker-btn {
        position: absolute !important;
        right: 7px !important;
        top: 7px !important;
        z-index: 2147483647 !important;
        border: 0 !important;
        border-radius: 999px !important;
        padding: 9px 12px !important;
        background: #ffffff !important;
        color: #ff5a1f !important;
        box-shadow: 0 2px 10px rgba(0,0,0,.28) !important;
        font: 700 13px Arial,sans-serif !important;
        cursor: pointer !important;
      }
      .gs-picker-btn.gs-picker-btn-selected {
        background: #ff5a1f !important;
        color: #ffffff !important;
      }
    `;
    document.head.appendChild(style);
  }

  window.__GS_PICKER_SELECTED__ = window.__GS_PICKER_SELECTED__ || new Set();

  const refresh = () => {
    document.querySelectorAll('.gs-picker-btn[data-item-id]').forEach(btn => {
      const id = String(btn.dataset.itemId || '');
      const active = window.__GS_PICKER_SELECTED__.has(id);
      btn.textContent = active ? '✓ Selecionado' : 'Selecionar';
      btn.classList.toggle('gs-picker-btn-selected', active);
      btn.closest('.gs-picker-card')?.classList.toggle(
        'gs-picker-selected',
        active
      );
    });
  };

  window.__GS_PICKER_SET_SELECTED__ = ids => {
    window.__GS_PICKER_SELECTED__ = new Set(
      (Array.isArray(ids) ? ids : []).map(String)
    );
    refresh();
  };

  const decorate = () => {
    const used = new Set();
    const anchors = [
      ...document.querySelectorAll(
        'a[href*="-i."],a[href*="/product/"]'
      )
    ];

    for (const a of anchors) {
      const ids = idsFrom(a.href || '');
      if (!ids || ids.itemId === String(OWN_ITEM_ID || '')) continue;
      if (used.has(ids.itemId)) continue;

      const card = findCard(a);
      if (!card) continue;
      used.add(ids.itemId);

      if (
        document.querySelector(
          '.gs-picker-btn[data-item-id="' + ids.itemId + '"]'
        )
      ) continue;

      const item = itemFrom(a, card, ids);
      if (!item.title || item.title.length < 4) continue;

      card.classList.add('gs-picker-card');
      const btn = document.createElement('button');
      btn.type = 'button';
      btn.className = 'gs-picker-btn';
      btn.dataset.itemId = ids.itemId;
      btn.textContent = 'Selecionar';

      btn.addEventListener('click', ev => {
        ev.preventDefault();
        ev.stopPropagation();
        if (ev.stopImmediatePropagation) ev.stopImmediatePropagation();
        CHANNEL.postMessage(JSON.stringify({type: 'toggle', item}));
      }, true);

      card.appendChild(btn);
    }
    refresh();
    CHANNEL.postMessage(JSON.stringify({type: 'ready'}));
  };

  const price = v => {
    const n = Number(v);
    if (!Number.isFinite(n) || n <= 0) return null;
    return n > 10000 ? n / 100000 : n;
  };
  const imgUrl = key => {
    if (!key) return null;
    const s = String(key);
    return s.startsWith('http')
      ? s
      : 'https://down-br.img.susercontent.com/file/' + s;
  };
  const category = item => {
    const cats = item?.fe_categories || item?.categories || [];
    if (!Array.isArray(cats)) {
      return String(item?.category_name || item?.category || '');
    }
    return cats
      .map(x => x?.display_name || x?.name || x?.catname)
      .filter(Boolean)
      .join(' > ');
  };
  const detail = async base => {
    try {
      const p =
        '/api/v4/item/get?itemid=' +
        encodeURIComponent(base.itemId) +
        '&shopid=' +
        encodeURIComponent(base.shopId);
      const r = await fetch(p, {
        credentials: 'include',
        headers: {
          accept: 'application/json,text/plain,*/*',
          'x-api-source': 'pc'
        }
      });
      if (!r.ok) return base;
      const j = await r.json();
      const item = j?.data?.item || j?.data;
      if (!item) return base;

      const models = Array.isArray(item?.models) ? item.models : [];
      const modelPrices = models
        .map(m => price(m?.price ?? m?.price_stock ?? m?.price_before_discount))
        .filter(v => Number.isFinite(v) && v > 0);
      const minModel = modelPrices.length ? Math.min(...modelPrices) : null;
      const maxModel = modelPrices.length ? Math.max(...modelPrices) : null;

      let bestModel = null;
      let bestSold = -1;
      for (const m of models) {
        const s = Number(
          m?.sold ?? m?.historical_sold ?? m?.sales ?? m?.stock_sold
        );
        if (Number.isFinite(s) && s > bestSold) {
          bestSold = s;
          bestModel = m;
        }
      }

      const rating = Number(
        item?.item_rating?.rating_star ?? item?.rating_star
      );
      const basePrice =
        price(item?.price ?? item?.price_min ?? item?.current_price) ||
        minModel ||
        base.price;

      return {
        ...base,
        title: String(item?.name || base.title || ''),
        description: String(item?.description || ''),
        category: category(item),
        imageUrl: imgUrl(item?.image || item?.image_id) || base.imageUrl,
        rating: Number.isFinite(rating) ? rating : base.rating,
        sold: Number(
          item?.sold ??
          item?.historical_sold ??
          item?.global_sold_count ??
          base.sold
        ) || base.sold,
        price: bestModel
          ? (price(bestModel?.price ?? bestModel?.price_stock) || basePrice)
          : basePrice,
        priceMin:
          price(item?.price_min) || minModel || base.priceMin || basePrice,
        priceMax:
          price(item?.price_max) || maxModel || base.priceMax || basePrice,
        bestSellingVariationName: bestModel
          ? String(bestModel?.name || bestModel?.model_name || '')
          : null,
        bestSellingVariationPrice: bestModel
          ? price(bestModel?.price ?? bestModel?.price_stock)
          : null,
        bestSellingVariationSold:
          bestModel && bestSold >= 0 ? bestSold : null,
        priceBasis: bestModel
          ? 'selected_best_selling_variation'
          : 'selected_product_detail'
      };
    } catch (_) {
      return base;
    }
  };

  window.__GS_PICKER_FINALIZE__ = async items => {
    const source = Array.isArray(items) ? items.slice(0, 3) : [];
    const out = [];
    for (const item of source) out.push(await detail(item));
    CHANNEL.postMessage(JSON.stringify({type: 'done', items: out}));
  };

  decorate();

  if (!window.__GS_PICKER_OBSERVER__) {
    let timer = null;
    window.__GS_PICKER_OBSERVER__ = new MutationObserver(() => {
      clearTimeout(timer);
      timer = setTimeout(decorate, 180);
    });
    window.__GS_PICKER_OBSERVER__.observe(
      document.documentElement,
      {subtree: true, childList: true}
    );
  }
  return true;
})();
''';
  }

  @override
  Widget build(BuildContext context) {
    final count = selected.length;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Selecione 3 concorrentes'),
        actions: [
          IconButton(
            tooltip: 'Atualizar pesquisa',
            onPressed: finalizing
                ? null
                : () => controller.reload(),
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
            color: Theme.of(context).colorScheme.primaryContainer,
            child: Row(
              children: [
                if (loading || finalizing) ...[
                  const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  const SizedBox(width: 10),
                ],
                Expanded(
                  child: Text(
                    status,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '$count/3',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),
          Expanded(child: WebViewWidget(controller: controller)),
        ],
      ),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(14, 8, 14, 12),
        child: FilledButton.icon(
          onPressed: count == 3 && !finalizing ? _finishSelection : null,
          icon: finalizing
              ? const SizedBox(
                  width: 19,
                  height: 19,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Icon(Icons.arrow_back),
          label: Text(
            finalizing
                ? 'IMPORTANDO CONCORRENTES...'
                : 'VOLTAR PARA ANÁLISE ($count/3)',
          ),
          style: FilledButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 15),
            textStyle: const TextStyle(fontWeight: FontWeight.w900),
          ),
        ),
      ),
    );
  }
}
