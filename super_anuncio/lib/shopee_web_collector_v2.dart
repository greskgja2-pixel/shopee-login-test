part of 'main.dart';

class ShopeeWebCollectorV2 {
  static Future<ShopeeProductData?> collectProduct(BuildContext context, String url) async {
    final raw = await Navigator.of(context).push<Map<String, dynamic>>(
      MaterialPageRoute(
        builder: (_) => _ShopeeCollectorV2Page(
          mode: _CollectorV2Mode.product,
          targetUrl: url,
        ),
      ),
    );
    if (raw == null) return null;
    final title = '${raw['title'] ?? ''}'.trim();
    final shopId = '${raw['shopId'] ?? ''}'.trim();
    final itemId = '${raw['itemId'] ?? ''}'.trim();
    if (title.isEmpty || (shopId.isEmpty && itemId.isEmpty)) return null;
    return ShopeeProductData(
      url: '${raw['url'] ?? url}',
      shopId: shopId,
      itemId: itemId,
      title: title,
      description: '${raw['description'] ?? ''}'.trim(),
      category: '${raw['category'] ?? ''}'.trim(),
      imageUrl: _s(raw['imageUrl']),
      price: _d(raw['price']),
      priceBeforeDiscount: _d(raw['priceBeforeDiscount']),
      rating: _d(raw['rating']),
      reviewCount: _i(raw['reviewCount']),
      sold: _i(raw['sold']),
      stock: _i(raw['stock']),
      imageCount: _i(raw['imageCount']) ?? 0,
      hasVideo: raw['hasVideo'] == true,
      attributesCount: _i(raw['attributesCount']) ?? 0,
      variationCount: _i(raw['variationCount']) ?? 0,
    );
  }

  static Future<List<CompetitorCandidate>> searchCompetitors(
    BuildContext context,
    String title, {
    String? ownItemId,
  }) async {
    final query = title
        .replaceAll(RegExp(r'[^A-Za-z0-9À-ÖØ-öø-ÿ ]'), ' ')
        .split(RegExp(r'\s+'))
        .where((w) => w.length >= 3)
        .take(10)
        .join(' ');
    final url = 'https://shopee.com.br/search?keyword=${Uri.encodeQueryComponent(query)}';
    final raw = await Navigator.of(context).push<List<dynamic>>(
      MaterialPageRoute(
        builder: (_) => _ShopeeCollectorV2Page(
          mode: _CollectorV2Mode.search,
          targetUrl: url,
        ),
      ),
    );
    if (raw == null) return const [];

    final out = <CompetitorCandidate>[];
    final seen = <String>{};
    for (final value in raw) {
      if (value is! Map) continue;
      final m = Map<String, dynamic>.from(value);
      final t = '${m['title'] ?? ''}'.trim();
      final link = '${m['link'] ?? ''}'.trim();
      final itemId = '${m['itemId'] ?? ''}'.trim();
      if (t.length < 4 || link.isEmpty || itemId == ownItemId) continue;
      final key = itemId.isEmpty ? link : itemId;
      if (!seen.add(key)) continue;
      out.add(CompetitorCandidate(
        title: t,
        price: _d(m['price']),
        link: link,
        imageUrl: _s(m['imageUrl']),
        rating: _d(m['rating']),
        sold: _d(m['sold']),
        shopId: _s(m['shopId']),
        itemId: itemId.isEmpty ? link.hashCode.abs().toString() : itemId,
        description: '${m['description'] ?? ''}'.trim(),
        category: '${m['category'] ?? ''}'.trim(),
      ));
      if (out.length >= 20) break;
    }
    return out;
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

enum _CollectorV2Mode { product, search }

class _ShopeeCollectorV2Page extends StatefulWidget {
  final _CollectorV2Mode mode;
  final String targetUrl;
  const _ShopeeCollectorV2Page({required this.mode, required this.targetUrl});

  @override
  State<_ShopeeCollectorV2Page> createState() => _ShopeeCollectorV2PageState();
}

class _ShopeeCollectorV2PageState extends State<_ShopeeCollectorV2Page> {
  late final WebViewController controller;
  bool loading = true;
  bool running = false;
  bool blocked = false;
  int redirects = 0;
  int clearChallengeChecks = 0;
  Timer? verificationWatcher;
  String status = 'Abrindo a Shopee...';

  @override
  void initState() {
    super.initState();
    controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0xFFFFFFFF))
      ..setUserAgent('Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/151.0.0.0 Safari/537.36')
      ..addJavaScriptChannel('SuperAnuncioV2', onMessageReceived: _message)
      ..setNavigationDelegate(NavigationDelegate(
        onNavigationRequest: _navigation,
        onPageStarted: (_) {
          if (!mounted) return;
          verificationWatcher?.cancel();
          setState(() {
            loading = true;
            running = false;
            blocked = false;
            status = 'Carregando página da Shopee...';
          });
        },
        onPageFinished: (_) {
          if (!mounted) return;
          setState(() => loading = false);
          _fitPageToScreen();
          Future.delayed(const Duration(milliseconds: 1100), _run);
        },
        onWebResourceError: (error) {
          if (!mounted || error.isForMainFrame != true) return;
          final d = error.description.toLowerCase();
          if (d.contains('unknown_url_scheme')) return;
          setState(() {
            running = false;
            status = 'Não consegui carregar esta página da Shopee.';
          });
        },
      ))
      ..loadRequest(Uri.parse(widget.targetUrl));
  }

  @override
  void dispose() {
    verificationWatcher?.cancel();
    super.dispose();
  }

  NavigationDecision _navigation(NavigationRequest request) {
    final raw = request.url.trim();
    final uri = Uri.tryParse(raw);
    if (uri == null) return NavigationDecision.prevent;
    if (uri.scheme == 'http' || uri.scheme == 'https' || uri.scheme == 'about' || uri.scheme == 'data') {
      return NavigationDecision.navigate;
    }
    final recovered = _recoverWebUrl(raw);
    if (recovered != null && redirects < 8) {
      redirects++;
      if (mounted) {
        setState(() {
          loading = true;
          running = false;
          status = 'Convertendo o link compartilhado para a página web do produto...';
        });
      }
      Future.microtask(() => controller.loadRequest(Uri.parse(recovered)));
    }
    return NavigationDecision.prevent;
  }

  String? _recoverWebUrl(String raw) {
    final uri = Uri.tryParse(raw);
    if (uri == null) return null;
    if (uri.scheme == 'shopeebr' || uri.scheme == 'shopee') {
      for (final key in const ['navigate_url', 'url', 'redirect_url', 'target_url']) {
        final v = uri.queryParameters[key];
        if (v == null || v.isEmpty) continue;
        final decoded = _decode(v);
        if (decoded != null) return decoded;
      }
    }
    if (uri.scheme == 'intent') {
      final fallback = RegExp(r'S\.browser_fallback_url=([^;]+)').firstMatch(raw)?.group(1);
      if (fallback != null) {
        final decoded = _decode(fallback);
        if (decoded != null) return decoded;
      }
      final candidate = raw.replaceFirst(RegExp(r'^intent://', caseSensitive: false), 'https://').split('#Intent;').first;
      if (_isShopee(candidate)) return candidate;
    }
    return null;
  }

  String? _decode(String value) {
    var current = value.trim();
    for (var i = 0; i < 5; i++) {
      if (_isShopee(current)) return current;
      try {
        final next = Uri.decodeComponent(current);
        if (next == current) break;
        current = next;
      } catch (_) {
        break;
      }
    }
    return _isShopee(current) ? current : null;
  }

  bool _isShopee(String value) {
    final uri = Uri.tryParse(value);
    if (uri == null || (uri.scheme != 'http' && uri.scheme != 'https')) return false;
    final h = uri.host.toLowerCase();
    return h == 'shopee.com.br' || h.endsWith('.shopee.com.br') || h.endsWith('.shopee.com');
  }

  void _message(JavaScriptMessage message) {
    dynamic decoded;
    try { decoded = jsonDecode(message.message); } catch (_) { return; }
    if (decoded is! Map) return;
    final m = Map<String, dynamic>.from(decoded);
    final type = '${m['type'] ?? ''}';

    if (type == 'blocked') {
      setState(() {
        blocked = true;
        running = false;
        status = 'Verifique para continuar na Shopee. Responda ao desafio abaixo.';
      });
      _fitAndCenterVerification();
      _startVerificationWatcher();
      return;
    }
    if (type == 'navigate') {
      final url = '${m['url'] ?? ''}'.trim();
      if (_isShopee(url) && redirects < 8) {
        redirects++;
        setState(() {
          running = false;
          loading = true;
          status = 'Encontrei a página real do produto. Abrindo...';
        });
        controller.loadRequest(Uri.parse(url));
      }
      return;
    }
    if (type == 'progress') {
      setState(() => status = 'Pesquisando concorrentes... ${m['count'] ?? 0} encontrados');
      return;
    }
    if (type == 'product') {
      verificationWatcher?.cancel();
      final data = m['data'];
      if (data is Map) Navigator.pop(context, Map<String, dynamic>.from(data));
      return;
    }
    if (type == 'search') {
      verificationWatcher?.cancel();
      Navigator.pop(context, List<dynamic>.from(m['items'] as List? ?? const []));
      return;
    }
    if (type == 'error') {
      setState(() {
        running = false;
        status = '${m['message'] ?? 'Não consegui identificar o produto real.'}';
      });
    }
  }

  Future<void> _fitPageToScreen() async {
    try {
      await controller.runJavaScript(_fitPageScript);
    } catch (_) {}
  }

  Future<void> _fitAndCenterVerification() async {
    try {
      await controller.runJavaScript(_centerVerificationScript);
    } catch (_) {}
  }

  void _startVerificationWatcher() {
    verificationWatcher?.cancel();
    clearChallengeChecks = 0;
    verificationWatcher = Timer.periodic(const Duration(milliseconds: 900), (_) async {
      if (!mounted || !blocked) return;
      try {
        final raw = await controller.runJavaScriptReturningResult(_challengeStateScript);
        final text = raw.toString().toLowerCase();
        final hasChallenge = text.contains('true');
        if (hasChallenge) {
          clearChallengeChecks = 0;
          await _fitAndCenterVerification();
        } else {
          clearChallengeChecks++;
          if (clearChallengeChecks >= 2) {
            verificationWatcher?.cancel();
            if (!mounted) return;
            setState(() {
              blocked = false;
              status = 'Verificação concluída. Continuando...';
            });
            await Future.delayed(const Duration(milliseconds: 500));
            _run();
          }
        }
      } catch (_) {}
    });
  }

  Future<void> _run() async {
    if (!mounted || loading || running) return;
    setState(() {
      blocked = false;
      running = true;
      status = widget.mode == _CollectorV2Mode.product
          ? 'Identificando o produto real e coletando seus dados...'
          : 'Pesquisando produtos equivalentes na Shopee...';
    });
    try {
      await controller.runJavaScript(widget.mode == _CollectorV2Mode.product ? _productScript : _searchScript);
    } catch (e) {
      if (mounted) setState(() { running = false; status = 'Falha na coleta: $e'; });
    }
  }

  static const String _fitPageScript = r'''
(() => {
  let meta=document.querySelector('meta[name="viewport"]');
  if(!meta){meta=document.createElement('meta');meta.name='viewport';document.head?.appendChild(meta);}
  meta.setAttribute('content','width=device-width, initial-scale=1.0, minimum-scale=0.3, maximum-scale=3.0, user-scalable=yes');
  const pageWidth=Math.max(document.documentElement?.scrollWidth||0,document.body?.scrollWidth||0,1100);
  const scale=Math.max(.40,Math.min(.62,(innerWidth/pageWidth)*1.02));
  if(document.body){document.body.style.zoom=String(scale);document.body.style.transformOrigin='top left';}
  document.documentElement.style.overflowX='auto';
  window.scrollTo({left:0,top:0,behavior:'auto'});
  return true;
})();
''';

  static const String _challengeStateScript = r'''
(() => {
  const body=(document.body?.innerText||'').toLowerCase();
  const exact=/verifique\s+para\s+continuar|arraste\s+para\s+completar\s+o\s+quebra-cabe[cç]a|verifica[cç][aã]o\s+de\s+seguran[cç]a|deslize\s+para\s+completar|tente\s+novamente/;
  const sel='iframe[src*="captcha" i],iframe[src*="verify" i],iframe[src*="challenge" i],[class*="captcha" i],[id*="captcha" i],[class*="verify" i],[id*="verify" i],[class*="challenge" i],[id*="challenge" i]';
  return exact.test(body)||!!document.querySelector(sel)||/captcha|verify|challenge|traffic/.test(location.href.toLowerCase());
})();
''';

  static const String _centerVerificationScript = r'''
(() => {
  const norm=s=>String(s||'').toLowerCase().replace(/\s+/g,' ').trim();
  let meta=document.querySelector('meta[name="viewport"]');
  if(!meta){meta=document.createElement('meta');meta.name='viewport';document.head?.appendChild(meta);}
  meta.setAttribute('content','width=device-width, initial-scale=1.0, minimum-scale=0.3, maximum-scale=3.0, user-scalable=yes');
  const pageWidth=Math.max(document.documentElement?.scrollWidth||0,document.body?.scrollWidth||0,1100);
  const scale=Math.max(.40,Math.min(.58,(innerWidth/pageWidth)*1.02));
  if(document.body){document.body.style.zoom=String(scale);document.body.style.transformOrigin='top left';}
  document.documentElement.style.overflowX='auto';

  const exact=/verifique para continuar|arraste para completar o quebra-cabe[cç]a|verifica[cç][aã]o de seguran[cç]a|deslize para completar|tente novamente/;
  const visible=el=>{if(!el)return false;const s=getComputedStyle(el),r=el.getBoundingClientRect();return s.display!=='none'&&s.visibility!=='hidden'&&r.width>70&&r.height>30;};
  let matches=[];
  for(const el of document.querySelectorAll('main,section,article,div,h1,h2,h3,h4,p,span')){
    if(!visible(el))continue;
    const t=norm(el.innerText||el.textContent||'');
    if(t&&t.length<1800&&exact.test(t)){
      const r=el.getBoundingClientRect();
      matches.push({el,area:r.width*r.height});
    }
  }
  matches.sort((a,b)=>a.area-b.area);
  let target=matches[0]?.el||null;
  if(!target){
    const sels=['iframe[src*="captcha" i]','iframe[src*="verify" i]','iframe[src*="challenge" i]','[class*="captcha" i]','[id*="captcha" i]','[class*="verify" i]','[id*="verify" i]','[class*="challenge" i]','[id*="challenge" i]'];
    for(const s of sels){const e=document.querySelector(s);if(visible(e)){target=e;break;}}
  }
  if(!target){
    const frames=[...document.querySelectorAll('iframe')].filter(visible);
    target=frames.sort((a,b)=>{const ra=a.getBoundingClientRect(),rb=b.getBoundingClientRect();return (rb.width*rb.height)-(ra.width*ra.height);})[0]||null;
  }
  if(target){
    target.scrollIntoView({behavior:'auto',block:'center',inline:'center'});
    setTimeout(()=>{
      const r=target.getBoundingClientRect();
      const left=Math.max(0,window.scrollX+r.left-(innerWidth-r.width)/2);
      const top=Math.max(0,window.scrollY+r.top-(innerHeight-r.height)/2);
      window.scrollTo({left,top,behavior:'smooth'});
    },120);
  }else{
    const left=Math.max(0,(document.documentElement.scrollWidth-innerWidth)/2);
    window.scrollTo({left,top:Math.max(0,document.documentElement.scrollHeight*.12),behavior:'smooth'});
  }
  return true;
})();
''';

  String get _common => r'''
const SA2={
 post:x=>SuperAnuncioV2.postMessage(JSON.stringify(x)),
 clean:s=>String(s||'').replace(/\s+/g,' ').trim(),
 blocked:()=>{
   const u=location.href.toLowerCase();
   const b=String(document.body?.innerText||'').toLowerCase();
   const exact=/verifique\s+para\s+continuar|arraste\s+para\s+completar\s+o\s+quebra-cabe[cç]a|verifica[cç][aã]o\s+de\s+seguran[cç]a|deslize\s+para\s+completar|tente\s+novamente/;
   return exact.test(b)||/captcha|verify|traffic|challenge/.test(u)||!!document.querySelector('iframe[src*="captcha" i],iframe[src*="verify" i],iframe[src*="challenge" i],[class*="captcha" i],[id*="captcha" i],[class*="verify" i],[id*="verify" i],[class*="challenge" i],[id*="challenge" i]')||(!!document.querySelector('input[type="password"]')&&/entrar|login|senha/.test(b.slice(0,2000)));
 },
 decode:s=>{let x=String(s||'');for(let i=0;i<4;i++){try{const y=decodeURIComponent(x);if(y===x)break;x=y}catch(_){break}}return x},
 idsFrom:s=>{
   const x=SA2.decode(s);
   let m=x.match(/-i\.(\d+)\.(\d+)/i); if(m)return {shopId:m[1],itemId:m[2]};
   m=x.match(/\/product\/(\d+)\/(\d+)/i); if(m)return {shopId:m[1],itemId:m[2]};
   return null;
 },
 candidates:()=>{
   const out=[location.href];
   for(const sel of ['link[rel="canonical"]','meta[property="og:url"]','meta[name="twitter:url"]']){
     const e=document.querySelector(sel); if(e)out.push(e.href||e.content||'');
   }
   for(const a of [...document.querySelectorAll('a[href]')].slice(0,500))out.push(a.href||'');
   return out.filter(Boolean);
 },
 findIds:()=>{
   for(const c of SA2.candidates()){const ids=SA2.idsFrom(c);if(ids)return ids;}
   const html=document.documentElement?.innerHTML||'';
   let m=html.match(/-i\.(\d+)\.(\d+)/i); if(m)return {shopId:m[1],itemId:m[2]};
   m=html.match(/\\?"shopid\\?"\s*:\s*\\?"?(\d+)\\?"?[\s\S]{0,600}?\\?"itemid\\?"\s*:\s*\\?"?(\d+)/i); if(m)return {shopId:m[1],itemId:m[2]};
   m=html.match(/\\?"itemid\\?"\s*:\s*\\?"?(\d+)\\?"?[\s\S]{0,600}?\\?"shopid\\?"\s*:\s*\\?"?(\d+)/i); if(m)return {shopId:m[2],itemId:m[1]};
   return null;
 },
 findProductUrl:()=>{
   for(const c of SA2.candidates()){if(SA2.idsFrom(c))return SA2.decode(c);}
   const html=document.documentElement?.innerHTML||'';
   let m=html.match(/https?:\\?\/\\?\/[^\"'<>\s]*shopee\.com\.br[^\"'<>\s]*-i\.\d+\.\d+/i);
   if(m)return SA2.decode(m[0].replace(/\\\//g,'/'));
   m=html.match(/https%3A%2F%2F[^\"'<>\s&]+-i%2E\d+%2E\d+/i);
   if(m)return SA2.decode(m[0]);
   return null;
 },
 price:v=>{const n=Number(v);if(!Number.isFinite(n)||n<=0)return null;return n>10000?n/100000:n;},
 img:k=>!k?null:(String(k).startsWith('http')?String(k):'https://down-br.img.susercontent.com/file/'+k),
 cat:item=>{const a=item?.fe_categories||item?.categories||[];if(!Array.isArray(a))return String(item?.category_name||item?.category||'');return a.map(x=>x?.display_name||x?.name||x?.catname).filter(Boolean).join(' > ');},
 detail:async ids=>{
   try{
     const p='/api/v4/item/get?itemid='+encodeURIComponent(ids.itemId)+'&shopid='+encodeURIComponent(ids.shopId);
     const r=await fetch(p,{credentials:'include',headers:{accept:'application/json,text/plain,*/*','x-api-source':'pc'}});
     if(!r.ok)return null;const j=await r.json();return j?.data?.item||j?.data||null;
   }catch(_){return null}
 },
 product:(item,ids)=>{
   const images=Array.isArray(item?.images)?item.images:[];
   const rating=Number(item?.item_rating?.rating_star??item?.rating_star);
   const models=Array.isArray(item?.models)?item.models:[];
   const tiers=Array.isArray(item?.tier_variations)?item.tier_variations:[];
   return {url:location.href,shopId:String(ids.shopId),itemId:String(ids.itemId),title:String(item?.name||item?.title||''),description:String(item?.description||''),category:SA2.cat(item),imageUrl:SA2.img(item?.image||item?.image_id||images[0]),price:SA2.price(item?.price??item?.price_min??item?.current_price),priceBeforeDiscount:SA2.price(item?.price_before_discount??item?.price_min_before_discount),rating:Number.isFinite(rating)?rating:null,reviewCount:Number(item?.cmt_count??item?.rating_count??item?.review_count)||null,sold:Number(item?.sold??item?.historical_sold??item?.global_sold_count)||null,stock:Number(item?.stock)||null,imageCount:images.length,hasVideo:(Array.isArray(item?.video_info_list)&&item.video_info_list.length>0)||!!item?.video_info,attributesCount:Array.isArray(item?.attributes)?item.attributes.length:0,variationCount:models.length||tiers.length};
 }
};
''';

  String get _productScript => _common + r'''
(async()=>{
 if(window.__SA2_RUNNING__)return true;window.__SA2_RUNNING__=1;
 try{
   if(SA2.blocked()){SA2.post({type:'blocked'});return true;}
   for(let attempt=0;attempt<4;attempt++){
     const ids=SA2.findIds();
     if(ids){
       const item=await SA2.detail(ids);
       if(item&&String(item?.name||'').trim().length>3){SA2.post({type:'product',data:SA2.product(item,ids)});return true;}
     }
     const u=SA2.findProductUrl();
     if(u&&u!==location.href&&SA2.idsFrom(u)){SA2.post({type:'navigate',url:u});return true;}
     await new Promise(r=>setTimeout(r,850));
   }
   SA2.post({type:'error',message:'A Shopee abriu uma página genérica, mas ainda não encontrei o produto real. Não vou preencher dados incorretos.'});
 }catch(e){SA2.post({type:'error',message:String(e?.message||e)})}
 finally{window.__SA2_RUNNING__=0}return true;
})()
''';

  String get _searchScript => _common + r'''
(async()=>{
 if(window.__SA2_RUNNING__)return true;window.__SA2_RUNNING__=1;
 const sleep=ms=>new Promise(r=>setTimeout(r,ms));
 const sold=t=>{const m=String(t||'').toLowerCase().match(/([0-9]+(?:[.,][0-9]+)?)\s*(mil|k)?\s+vendid/);if(!m)return null;let n=Number(m[1].replace(',','.'));if(m[2])n*=1000;return Math.round(n)};
 const parse=()=>{
   const out=new Map();
   for(const a of [...document.querySelectorAll('a[href*="-i."],a[href*="/product/"]')]){
     const ids=SA2.idsFrom(a.href||'');if(!ids)continue;
     let card=a;for(let i=0;i<9&&card;i++,card=card.parentElement){const t=SA2.clean(card?.innerText||'');if(t.length>20&&/R\$|vendid/i.test(t))break;}
     if(!card)continue;
     const raw=SA2.clean(card.innerText||'');const img=card.querySelector('img');
     let title=SA2.clean(card.querySelector('[data-sqe="name"],[class*="name"],[class*="title"]')?.innerText||img?.alt||a.getAttribute('aria-label')||'');
     if(title.length<4)title=raw.split(/R\$/)[0].slice(0,220);
     const pm=raw.match(/R\$\s*([0-9][0-9.]*(?:,[0-9]{1,2})?)/);const price=pm?Number(pm[1].replace(/\./g,'').replace(',','.')):null;
     if(title.length<4||!(price>0))continue;
     if(!out.has(ids.itemId))out.set(ids.itemId,{title,price,link:a.href,imageUrl:img?.currentSrc||img?.src||null,rating:null,sold:sold(raw),shopId:ids.shopId,itemId:ids.itemId,description:'',category:''});
     if(out.size>=20)break;
   }
   return [...out.values()];
 };
 try{
   if(SA2.blocked()){SA2.post({type:'blocked'});return true;}
   let items=[];
   for(let r=0;r<12;r++){
     items=parse();SA2.post({type:'progress',count:items.length});if(items.length>=15)break;
     window.scrollBy({top:Math.max(600,Math.floor(window.innerHeight*.85)),behavior:'smooth'});await sleep(650);
   }
   items=parse();
   for(let i=0;i<Math.min(items.length,15);i++){
     const x=items[i],d=await SA2.detail({shopId:x.shopId,itemId:x.itemId});if(!d)continue;
     x.title=String(d?.name||x.title);x.description=String(d?.description||'');x.category=SA2.cat(d);x.rating=Number(d?.item_rating?.rating_star??d?.rating_star)||null;x.sold=Number(d?.sold??d?.historical_sold??d?.global_sold_count)||x.sold;x.price=SA2.price(d?.price??d?.price_min)||x.price;x.imageUrl=SA2.img(d?.image||d?.image_id)||x.imageUrl;
   }
   SA2.post({type:'search',items});
 }catch(e){SA2.post({type:'error',message:String(e?.message||e)})}
 finally{window.__SA2_RUNNING__=0}return true;
})()
''';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.mode == _CollectorV2Mode.product ? 'Lendo anúncio na Shopee' : 'Buscando concorrentes'),
        actions: [IconButton(onPressed: _run, icon: const Icon(Icons.refresh))],
      ),
      body: Column(children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          color: blocked ? Theme.of(context).colorScheme.errorContainer : Theme.of(context).colorScheme.primaryContainer,
          child: Row(children: [
            if (loading || running) ...[
              const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2)),
              const SizedBox(width: 10),
            ],
            Expanded(child: Text(status, style: const TextStyle(fontWeight: FontWeight.w700))),
            if (blocked) ...[
              const SizedBox(width: 8),
              OutlinedButton(onPressed: _fitAndCenterVerification, child: const Text('Centralizar')),
              const SizedBox(width: 6),
              FilledButton(onPressed: _run, child: const Text('Continuar')),
            ],
          ]),
        ),
        Expanded(child: WebViewWidget(controller: controller)),
      ]),
    );
  }
}
