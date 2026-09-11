part of 'main.dart';

class ShopeeWebCollector {
  static Future<ShopeeProductData?> collectProduct(BuildContext context, String url) async {
    final raw = await Navigator.of(context).push<Map<String, dynamic>>(
      MaterialPageRoute(
        builder: (_) => _ShopeeCollectorPage(
          mode: _CollectorMode.product,
          targetUrl: url,
        ),
      ),
    );
    if (raw == null) return null;
    return _productFromMap(raw, url);
  }

  static Future<List<CompetitorCandidate>> searchCompetitors(
    BuildContext context,
    String title, {
    String? ownItemId,
  }) async {
    final url = 'https://shopee.com.br/search?keyword=${Uri.encodeQueryComponent(_query(title))}';
    final raw = await Navigator.of(context).push<List<dynamic>>(
      MaterialPageRoute(
        builder: (_) => _ShopeeCollectorPage(
          mode: _CollectorMode.search,
          targetUrl: url,
        ),
      ),
    );
    if (raw == null) return const [];

    final out = <CompetitorCandidate>[];
    final seen = <String>{};
    for (final value in raw) {
      if (value is! Map) continue;
      final map = Map<String, dynamic>.from(value);
      final item = _competitorFromMap(map);
      if (item == null || item.itemId == ownItemId || !seen.add(item.key)) continue;
      out.add(item);
      if (out.length >= 20) break;
    }
    return out;
  }

  static String _query(String title) {
    final words = title
        .replaceAll(RegExp(r'[^A-Za-z0-9À-ÖØ-öø-ÿ ]'), ' ')
        .split(RegExp(r'\s+'))
        .where((w) => w.length >= 3)
        .take(10)
        .toList();
    return words.join(' ');
  }

  static ShopeeProductData _productFromMap(Map<String, dynamic> map, String url) {
    return ShopeeProductData(
      url: url,
      shopId: '${map['shopId'] ?? ''}',
      itemId: '${map['itemId'] ?? ''}',
      title: '${map['title'] ?? ''}'.trim(),
      description: '${map['description'] ?? ''}'.trim(),
      category: '${map['category'] ?? ''}'.trim(),
      imageUrl: _s(map['imageUrl']),
      price: _d(map['price']),
      priceBeforeDiscount: _d(map['priceBeforeDiscount']),
      rating: _d(map['rating']),
      reviewCount: _i(map['reviewCount']),
      sold: _i(map['sold']),
      stock: _i(map['stock']),
      imageCount: _i(map['imageCount']) ?? 0,
      hasVideo: map['hasVideo'] == true,
      attributesCount: _i(map['attributesCount']) ?? 0,
      variationCount: _i(map['variationCount']) ?? 0,
    );
  }

  static CompetitorCandidate? _competitorFromMap(Map<String, dynamic> map) {
    final title = '${map['title'] ?? ''}'.trim();
    final itemId = '${map['itemId'] ?? ''}'.trim();
    final shopId = '${map['shopId'] ?? ''}'.trim();
    final link = '${map['link'] ?? ''}'.trim();
    if (title.length < 4 || link.isEmpty) return null;

    return CompetitorCandidate(
      title: title,
      price: _d(map['price']),
      link: link,
      imageUrl: _s(map['imageUrl']),
      rating: _d(map['rating']),
      sold: _d(map['sold']),
      shopId: shopId.isEmpty ? null : shopId,
      itemId: itemId.isEmpty ? link.hashCode.abs().toString() : itemId,
      description: '${map['description'] ?? ''}'.trim(),
      category: '${map['category'] ?? ''}'.trim(),
    );
  }

  static String? _s(dynamic v) {
    final s = v is String ? v.trim() : '';
    return s.isEmpty ? null : s;
  }

  static double? _d(dynamic v) {
    if (v is num) return v.toDouble();
    return double.tryParse('$v');
  }

  static int? _i(dynamic v) {
    if (v is num) return v.round();
    return int.tryParse('$v');
  }
}

enum _CollectorMode { product, search }

class _ShopeeCollectorPage extends StatefulWidget {
  final _CollectorMode mode;
  final String targetUrl;

  const _ShopeeCollectorPage({
    required this.mode,
    required this.targetUrl,
  });

  @override
  State<_ShopeeCollectorPage> createState() => _ShopeeCollectorPageState();
}

class _ShopeeCollectorPageState extends State<_ShopeeCollectorPage> {
  late final WebViewController controller;
  bool loading = true;
  bool blocked = false;
  bool running = false;
  String status = 'Abrindo a Shopee...';

  @override
  void initState() {
    super.initState();
    controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0xFFFFFFFF))
      ..setUserAgent('Mozilla/5.0 (Linux; Android 15; Mobile) AppleWebKit/537.36 Chrome/151 Mobile Safari/537.36')
      ..addJavaScriptChannel('SuperAnuncio', onMessageReceived: _message)
      ..setNavigationDelegate(
        NavigationDelegate(
          onNavigationRequest: _handleNavigation,
          onPageStarted: (_) {
            if (mounted) {
              setState(() {
                loading = true;
                status = 'Carregando página da Shopee...';
              });
            }
          },
          onPageFinished: (_) {
            if (!mounted) return;
            setState(() => loading = false);
            Future.delayed(const Duration(milliseconds: 900), _run);
          },
          onWebResourceError: (error) {
            if (mounted && error.isForMainFrame == true) {
              final description = error.description.toLowerCase();
              if (description.contains('unknown_url_scheme')) return;
              setState(() => status = 'Falha ao abrir a Shopee. Tente novamente.');
            }
          },
        ),
      )
      ..loadRequest(Uri.parse(widget.targetUrl));
  }

  NavigationDecision _handleNavigation(NavigationRequest request) {
    final raw = request.url.trim();
    final uri = Uri.tryParse(raw);
    if (uri == null) return NavigationDecision.prevent;

    if (uri.scheme == 'http' || uri.scheme == 'https' || uri.scheme == 'about' || uri.scheme == 'data') {
      return NavigationDecision.navigate;
    }

    final recovered = _recoverWebUrl(raw);
    if (recovered != null) {
      if (mounted) {
        setState(() {
          loading = true;
          running = false;
          status = 'Abrindo o anúncio pela versão web da Shopee...';
        });
      }
      Future.microtask(() => controller.loadRequest(Uri.parse(recovered)));
    } else if (mounted) {
      setState(() {
        running = false;
        status = 'A Shopee tentou abrir o aplicativo externo. Mantendo a navegação dentro do Super Anúncio.';
      });
    }
    return NavigationDecision.prevent;
  }

  String? _recoverWebUrl(String raw) {
    final uri = Uri.tryParse(raw);
    if (uri == null) return null;

    if (uri.scheme == 'shopeebr' || uri.scheme == 'shopee') {
      for (final key in const ['navigate_url', 'url', 'redirect_url', 'target_url']) {
        final value = uri.queryParameters[key];
        if (value == null || value.trim().isEmpty) continue;
        final candidate = _decodeUrl(value);
        if (candidate != null) return candidate;
      }
    }

    if (uri.scheme == 'intent') {
      final match = RegExp(r'S\.browser_fallback_url=([^;]+)').firstMatch(raw);
      if (match != null) {
        final candidate = _decodeUrl(match.group(1)!);
        if (candidate != null) return candidate;
      }
      final httpsCandidate = raw
          .replaceFirst(RegExp(r'^intent://', caseSensitive: false), 'https://')
          .split('#Intent;')
          .first;
      if (_isShopeeWebUrl(httpsCandidate)) return httpsCandidate;
    }

    final embedded = RegExp(r'https%3A%2F%2F[^&;]+', caseSensitive: false).firstMatch(raw);
    if (embedded != null) {
      final candidate = _decodeUrl(embedded.group(0)!);
      if (candidate != null) return candidate;
    }
    return null;
  }

  String? _decodeUrl(String value) {
    var candidate = value.trim();
    for (var i = 0; i < 3; i++) {
      if (_isShopeeWebUrl(candidate)) return candidate;
      try {
        final decoded = Uri.decodeComponent(candidate);
        if (decoded == candidate) break;
        candidate = decoded;
      } catch (_) {
        break;
      }
    }
    return _isShopeeWebUrl(candidate) ? candidate : null;
  }

  bool _isShopeeWebUrl(String value) {
    final uri = Uri.tryParse(value);
    if (uri == null || (uri.scheme != 'http' && uri.scheme != 'https')) return false;
    final host = uri.host.toLowerCase();
    return host == 'shopee.com.br' || host.endsWith('.shopee.com.br') || host.endsWith('.shopee.com');
  }

  void _message(JavaScriptMessage message) {
    dynamic decoded;
    try {
      decoded = jsonDecode(message.message);
    } catch (_) {
      return;
    }
    if (decoded is! Map) return;

    final map = Map<String, dynamic>.from(decoded);
    final type = '${map['type'] ?? ''}';

    if (type == 'blocked') {
      setState(() {
        blocked = true;
        running = false;
        status = 'A Shopee pediu login/verificação. Faça isso abaixo e toque em Continuar.';
      });
      return;
    }

    if (type == 'progress') {
      setState(() => status = 'Lendo resultados... ${map['count'] ?? 0} encontrados');
      return;
    }

    if (type == 'product') {
      final data = map['data'];
      if (data is Map) {
        Navigator.pop(context, Map<String, dynamic>.from(data));
      }
      return;
    }

    if (type == 'search') {
      Navigator.pop(context, List<dynamic>.from(map['items'] as List? ?? const []));
      return;
    }

    if (type == 'error') {
      setState(() {
        running = false;
        status = '${map['message'] ?? 'Não consegui coletar os dados.'}';
      });
    }
  }

  Future<void> _run() async {
    if (!mounted || running || loading) return;
    setState(() {
      blocked = false;
      running = true;
      status = widget.mode == _CollectorMode.product
          ? 'Lendo dados do anúncio...'
          : 'Pesquisando concorrentes...';
    });

    try {
      await controller.runJavaScript(
        widget.mode == _CollectorMode.product ? _productScript : _searchScript,
      );
    } catch (e) {
      if (mounted) {
        setState(() {
          running = false;
          status = 'Falha na coleta: $e';
        });
      }
    }
  }

  String get _commonJs => r'''
const SA={
 clean:s=>String(s||'').replace(/\s+/g,' ').trim(),
 post:(x)=>SuperAnuncio.postMessage(JSON.stringify(x)),
 blocked:()=>{
   const u=location.href.toLowerCase();
   const b=String(document.body?.innerText||'').toLowerCase();
   return /captcha|verify|traffic/.test(u)
     || !!document.querySelector('iframe[src*="captcha" i],[class*="captcha" i],[id*="captcha" i]')
     || (!!document.querySelector('input[type="password"]') && /entrar|login|senha/.test(b.slice(0,1800)));
 },
 ids:()=>{
   let m=location.href.match(/-i\.(\d+)\.(\d+)/);
   if(!m)m=location.href.match(/\/product\/(\d+)\/(\d+)/);
   return m?{shopId:m[1],itemId:m[2]}:null;
 },
 img:k=>!k?null:(String(k).startsWith('http')?String(k):`https://down-br.img.susercontent.com/file/${k}`),
 price:v=>{
   const n=Number(v);
   if(!Number.isFinite(n)||n<=0)return null;
   return n>10000?n/100000:n;
 },
 cat:item=>{
   const a=item?.fe_categories||item?.categories||[];
   if(!Array.isArray(a))return String(item?.category_name||item?.category||'');
   return a.map(x=>x?.display_name||x?.name||x?.catname).filter(Boolean).join(' > ');
 },
 detail:async(shopId,itemId)=>{
   try{
     const path='/api/v4/item/get?itemid='+encodeURIComponent(itemId)+'&shopid='+encodeURIComponent(shopId);
     const r=await fetch(path,{credentials:'include',headers:{'accept':'application/json,text/plain,*/*','x-api-source':'pc'}});
     if(!r.ok)return null;
     const j=await r.json();
     return j?.data?.item||j?.data||null;
   }catch(_){return null;}
 },
 product:(item,url,ids)=>{
   const images=Array.isArray(item?.images)?item.images:[];
   const rating=Number(item?.item_rating?.rating_star??item?.rating_star);
   const models=Array.isArray(item?.models)?item.models:[];
   const tiers=Array.isArray(item?.tier_variations)?item.tier_variations:[];
   const video=(Array.isArray(item?.video_info_list)&&item.video_info_list.length>0)||!!item?.video_info;
   return {
     url,
     shopId:String(ids?.shopId||item?.shopid||''),
     itemId:String(ids?.itemId||item?.itemid||''),
     title:String(item?.name||item?.title||''),
     description:String(item?.description||''),
     category:SA.cat(item),
     imageUrl:SA.img(item?.image||item?.image_id||images[0]),
     price:SA.price(item?.price??item?.price_min??item?.current_price),
     priceBeforeDiscount:SA.price(item?.price_before_discount??item?.price_min_before_discount),
     rating:Number.isFinite(rating)?rating:null,
     reviewCount:Number(item?.cmt_count??item?.rating_count??item?.review_count)||null,
     sold:Number(item?.sold??item?.historical_sold??item?.global_sold_count)||null,
     stock:Number(item?.stock)||null,
     imageCount:images.length||(item?.image?1:0),
     hasVideo:video,
     attributesCount:Array.isArray(item?.attributes)?item.attributes.length:0,
     variationCount:models.length||tiers.length
   };
 }
};
''';

  String get _productScript => _commonJs + r'''
(async()=>{
 if(window.__SA_RUNNING__)return true;
 window.__SA_RUNNING__=1;
 try{
   if(SA.blocked()){SA.post({type:'blocked'});return true;}
   const ids=SA.ids();
   if(ids){
     const item=await SA.detail(ids.shopId,ids.itemId);
     if(item){
       SA.post({type:'product',data:SA.product(item,location.href,ids)});
       return true;
     }
   }
   const h1=SA.clean(document.querySelector('h1')?.innerText||document.title);
   const body=SA.clean(document.body?.innerText||'');
   const pm=body.match(/R\$\s*([0-9][0-9.]*(?:,[0-9]{1,2})?)(?=\s|$)/);
   const p=pm?Number(pm[1].replace(/\./g,'').replace(',','.')):null;
   const imgs=[...document.querySelectorAll('img')]
     .map(x=>x.currentSrc||x.src)
     .filter(x=>/susercontent|shopee/i.test(x||''));
   if(h1){
     SA.post({type:'product',data:{
       url:location.href,
       shopId:ids?.shopId||'',
       itemId:ids?.itemId||'',
       title:h1,
       description:'',
       category:'',
       imageUrl:imgs[0]||null,
       price:p,
       priceBeforeDiscount:null,
       rating:null,
       reviewCount:null,
       sold:null,
       stock:null,
       imageCount:new Set(imgs).size,
       hasVideo:!!document.querySelector('video'),
       attributesCount:0,
       variationCount:0
     }});
     return true;
   }
   SA.post({type:'error',message:'A página abriu, mas não consegui identificar o anúncio.'});
 }catch(e){
   SA.post({type:'error',message:String(e?.message||e)});
 }finally{
   window.__SA_RUNNING__=0;
 }
 return true;
})()
''';

  String get _searchScript => _commonJs + r'''
(async()=>{
 if(window.__SA_RUNNING__)return true;
 window.__SA_RUNNING__=1;
 const sleep=ms=>new Promise(r=>setTimeout(r,ms));
 const sold=t=>{
   const m=String(t||'').toLowerCase().match(/([0-9]+(?:[.,][0-9]+)?)\s*(mil|k)?\s+vendid/);
   if(!m)return null;
   let n=Number(m[1].replace(',','.'));
   if(m[2])n*=1000;
   return Math.round(n);
 };
 const parse=()=>{
   const anchors=[...document.querySelectorAll('a[href*="-i."],a[href*="/product/"]')];
   const out=new Map();
   for(const link of anchors){
     let card=link;
     for(let i=0;i<8&&card;i++,card=card.parentElement){
       const t=SA.clean(card?.innerText||'');
       if(t.length>20&&/R\$|vendid/i.test(t))break;
     }
     if(!card)card=link.parentElement||link;
     const raw=SA.clean(card?.innerText||'');
     const href=link.href||'';
     let m=href.match(/-i\.(\d+)\.(\d+)/);
     if(!m)m=href.match(/\/product\/(\d+)\/(\d+)/);
     const img=card.querySelector('img');
     let title=SA.clean(
       card.querySelector('[data-sqe="name"],[class*="name"],[class*="title"]')?.innerText
       ||img?.alt
       ||link.getAttribute('aria-label')
       ||''
     );
     if(title.length<4)title=raw.split(/R\$/)[0].slice(0,220);
     const pm=raw.match(/R\$\s*([0-9][0-9.]*(?:,[0-9]{1,2})?)(?=\s|$)/);
     const price=pm?Number(pm[1].replace(/\./g,'').replace(',','.')):null;
     if(!href||title.length<4||!(price>0))continue;
     const itemId=m?.[2]||href;
     if(out.has(itemId))continue;
     out.set(itemId,{
       title,
       price,
       link:href,
       imageUrl:img?.currentSrc||img?.src||null,
       rating:null,
       sold:sold(raw),
       shopId:m?.[1]||'',
       itemId:m?.[2]||'',
       description:'',
       category:''
     });
     if(out.size>=20)break;
   }
   return [...out.values()];
 };
 try{
   if(SA.blocked()){SA.post({type:'blocked'});return true;}
   let items=[],last=-1,stable=0;
   for(let round=0;round<14;round++){
     items=parse();
     SA.post({type:'progress',count:items.length});
     stable=items.length===last?stable+1:0;
     last=items.length;
     const bottom=window.scrollY+window.innerHeight>=document.documentElement.scrollHeight-220;
     if(items.length>=15&&(stable>=2||bottom))break;
     window.scrollBy({top:Math.max(500,Math.floor(window.innerHeight*.8)),behavior:'smooth'});
     await sleep(650);
     if(SA.blocked()){SA.post({type:'blocked'});return true;}
   }
   items=parse();
   for(let i=0;i<Math.min(items.length,15);i++){
     const x=items[i];
     if(!x.shopId||!x.itemId)continue;
     const d=await SA.detail(x.shopId,x.itemId);
     if(!d)continue;
     x.description=String(d.description||'');
     x.category=SA.cat(d);
     x.rating=Number(d?.item_rating?.rating_star??d?.rating_star)||x.rating;
     x.sold=Number(d?.sold??d?.historical_sold??d?.global_sold_count)||x.sold;
     x.price=SA.price(d?.price??d?.price_min)||x.price;
     x.imageUrl=SA.img(d?.image||d?.image_id)||x.imageUrl;
     await sleep(90);
   }
   SA.post({type:'search',items});
 }catch(e){
   SA.post({type:'error',message:String(e?.message||e)});
 }finally{
   window.__SA_RUNNING__=0;
 }
 return true;
})()
''';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.mode == _CollectorMode.product
              ? 'Lendo anúncio na Shopee'
              : 'Buscando concorrentes',
        ),
        actions: [
          IconButton(onPressed: _run, icon: const Icon(Icons.refresh)),
        ],
      ),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            color: blocked
                ? Theme.of(context).colorScheme.errorContainer
                : Theme.of(context).colorScheme.primaryContainer,
            child: Row(
              children: [
                if (loading || running) ...[
                  const SizedBox(width: 4),
                  const SizedBox(
                    width: 22,
                    height: 22,
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
                if (blocked)
                  FilledButton(
                    onPressed: _run,
                    child: const Text('Continuar'),
                  ),
              ],
            ),
          ),
          Expanded(child: WebViewWidget(controller: controller)),
        ],
      ),
    );
  }
}
