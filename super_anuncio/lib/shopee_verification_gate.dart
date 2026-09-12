part of 'main.dart';

class ShopeeVerificationGate {
  static Future<bool> ensureReady(BuildContext context, String url) async {
    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => _ShopeeVerificationPage(targetUrl: url)),
    );
    return result ?? false;
  }
}

class _ShopeeVerificationPage extends StatefulWidget {
  final String targetUrl;
  const _ShopeeVerificationPage({required this.targetUrl});

  @override
  State<_ShopeeVerificationPage> createState() => _ShopeeVerificationPageState();
}

class _ShopeeVerificationPageState extends State<_ShopeeVerificationPage> {
  late final WebViewController controller;
  Timer? poller;
  bool loading = true;
  bool challenge = false;
  bool loginRequired = false;
  bool finished = false;
  int clearChecks = 0;
  int redirects = 0;
  int focusTicks = 0;
  late DateTime startedAt;
  String status = 'Verificando acesso à Shopee...';

  @override
  void initState() {
    super.initState();
    startedAt = DateTime.now();
    controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0xFFFFFFFF))
      ..setUserAgent('Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/151.0.0.0 Safari/537.36')
      ..setNavigationDelegate(NavigationDelegate(
        onNavigationRequest: _navigation,
        onPageStarted: (_) {
          if (!mounted) return;
          setState(() {
            loading = true;
            clearChecks = 0;
            focusTicks = 0;
            status = 'Carregando a Shopee...';
          });
        },
        onPageFinished: (_) {
          if (!mounted) return;
          setState(() => loading = false);
          Future.delayed(const Duration(milliseconds: 250), _inspect);
        },
        onWebResourceError: (error) {
          if (!mounted || error.isForMainFrame != true) return;
          if (error.description.toLowerCase().contains('unknown_url_scheme')) return;
          setState(() => status = 'Aguardando resposta da Shopee...');
        },
      ))
      ..loadRequest(Uri.parse(widget.targetUrl));

    poller = Timer.periodic(const Duration(milliseconds: 700), (_) => _inspect());
  }

  @override
  void dispose() {
    poller?.cancel();
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
      Future.microtask(() => controller.loadRequest(Uri.parse(recovered)));
    }
    return NavigationDecision.prevent;
  }

  String? _recoverWebUrl(String raw) {
    final uri = Uri.tryParse(raw);
    if (uri == null) return null;
    if (uri.scheme == 'shopeebr' || uri.scheme == 'shopee') {
      for (final key in const ['navigate_url', 'url', 'redirect_url', 'target_url']) {
        final value = uri.queryParameters[key];
        if (value == null || value.isEmpty) continue;
        final decoded = _decode(value);
        if (decoded != null) return decoded;
      }
    }
    if (uri.scheme == 'intent') {
      final fallback = RegExp(r'S\.browser_fallback_url=([^;]+)').firstMatch(raw)?.group(1);
      if (fallback != null) {
        final decoded = _decode(fallback);
        if (decoded != null) return decoded;
      }
      final candidate = raw
          .replaceFirst(RegExp(r'^intent://', caseSensitive: false), 'https://')
          .split('#Intent;')
          .first;
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
    final host = uri.host.toLowerCase();
    return host == 'shopee.com.br' || host.endsWith('.shopee.com.br') || host.endsWith('.shopee.com');
  }

  Future<void> _inspect() async {
    if (!mounted || finished || loading) return;
    try {
      final raw = await controller.runJavaScriptReturningResult(_inspectionScript);
      final data = _decodeJsResult(raw);
      final type = '${data['type'] ?? 'clear'}';

      if (type == 'captcha') {
        clearChecks = 0;
        focusTicks++;
        if (!challenge || loginRequired) {
          setState(() {
            challenge = true;
            loginRequired = false;
            status = 'A Shopee pediu uma verificação de segurança';
          });
        }
        if (focusTicks == 1 || focusTicks % 4 == 0) {
          await _focusChallenge();
        }
        return;
      }

      if (type == 'login') {
        clearChecks = 0;
        if (!loginRequired || challenge) {
          setState(() {
            loginRequired = true;
            challenge = false;
            status = 'A Shopee pediu que você entre na sua conta';
          });
          await _focusLogin();
        }
        return;
      }

      clearChecks += 1;
      if (challenge || loginRequired) {
        if (clearChecks >= 3) {
          setState(() {
            challenge = false;
            loginRequired = false;
            status = 'Verificação concluída. Continuando...';
          });
          await _restorePage();
          await Future.delayed(const Duration(milliseconds: 700));
          _finish(true);
        }
        return;
      }

      // Não libera cedo demais: alguns desafios da Shopee aparecem alguns
      // segundos depois do primeiro carregamento.
      final elapsed = DateTime.now().difference(startedAt);
      if (elapsed < const Duration(seconds: 7)) {
        if (mounted && status != 'Aguardando possíveis verificações da Shopee...') {
          setState(() => status = 'Aguardando possíveis verificações da Shopee...');
        }
        return;
      }
      if (clearChecks >= 4) _finish(true);
    } catch (_) {
      // A página pode estar mudando de rota. A próxima checagem tenta de novo.
    }
  }

  Map<String, dynamic> _decodeJsResult(Object raw) {
    try {
      if (raw is String) {
        var text = raw;
        if (text.startsWith('"') && text.endsWith('"')) {
          final unquoted = jsonDecode(text);
          if (unquoted is String) text = unquoted;
        }
        final decoded = jsonDecode(text);
        if (decoded is Map) return Map<String, dynamic>.from(decoded);
      }
    } catch (_) {}
    return const {'type': 'clear'};
  }

  Future<void> _focusChallenge() async {
    try {
      await controller.runJavaScript(_focusChallengeScript);
    } catch (_) {}
  }

  Future<void> _focusLogin() async {
    try {
      await controller.runJavaScript(r'''
        (()=>{
          const p=document.querySelector('input[type="password"]');
          const target=p?.closest('form,section,main,div')||p;
          if(target) target.scrollIntoView({behavior:'smooth',block:'center',inline:'center'});
          return true;
        })();
      ''');
    } catch (_) {}
  }

  Future<void> _restorePage() async {
    try {
      await controller.runJavaScript(r'''
        (()=>{
          if(document.body){document.body.style.zoom='';document.body.style.transformOrigin='';}
          document.documentElement.style.overflowX='';
          const meta=document.querySelector('meta[name="viewport"]');
          if(meta && meta.dataset.saOldViewport){meta.setAttribute('content',meta.dataset.saOldViewport);delete meta.dataset.saOldViewport;}
          return true;
        })();
      ''');
    } catch (_) {}
  }

  void _finish(bool value) {
    if (!mounted || finished) return;
    finished = true;
    poller?.cancel();
    Navigator.of(context).pop(value);
  }

  static const String _inspectionScript = r'''
    (()=>{
      const url=location.href.toLowerCase();
      const body=(document.body?.innerText||'').toLowerCase();
      const visible=el=>{
        if(!el)return false;
        const s=getComputedStyle(el),r=el.getBoundingClientRect();
        return s.display!=='none'&&s.visibility!=='hidden'&&Number(s.opacity||1)>0&&r.width>80&&r.height>45;
      };
      const clue=/captcha|verifique|verificação|verificacao|segurança|seguranca|security|challenge|robô|robo|humano|arraste|deslize|tente novamente|prove que você|prove que voce/;
      const selectors=[
        'iframe[src*="captcha" i]','iframe[src*="verify" i]','iframe[src*="security" i]',
        'iframe[src*="challenge" i]','iframe[src*="arkose" i]','iframe[src*="geetest" i]',
        'iframe[src*="hcaptcha" i]','iframe[src*="recaptcha" i]',
        '[class*="captcha" i]','[id*="captcha" i]','[class*="verify" i]','[id*="verify" i]',
        '[class*="challenge" i]','[id*="challenge" i]','[class*="security" i]','[id*="security" i]',
        '[data-testid*="captcha" i]','[data-testid*="verify" i]'
      ];
      for(const s of selectors){const el=document.querySelector(s);if(visible(el))return JSON.stringify({type:'captcha',reason:'selector'});}

      const frames=[...document.querySelectorAll('iframe')].filter(visible);
      for(const f of frames){
        const r=f.getBoundingClientRect();
        const meta=((f.src||'')+' '+(f.id||'')+' '+(f.className||'')+' '+(f.name||'')).toLowerCase();
        const looksSecurity=clue.test(meta);
        const bigPanel=r.width>=220&&r.height>=160;
        const offToRight=r.left>innerWidth*.55||r.right>innerWidth*1.08;
        if(looksSecurity||(bigPanel&&offToRight)) return JSON.stringify({type:'captcha',reason:'iframe'});
      }

      if(clue.test(body.slice(0,12000))) {
        const strong=/verifique|verificação|verificacao|captcha|arraste|deslize|não sou um robô|nao sou um robo|security verification|tente novamente/.test(body.slice(0,12000));
        if(strong) return JSON.stringify({type:'captcha',reason:'text'});
      }
      if(/captcha|verify|verification|traffic|challenge/.test(url)) return JSON.stringify({type:'captcha',reason:'url'});

      // Heurística para a tela branca de desafio que a Shopee posiciona fora da
      // largura visível quando usamos identidade de navegador desktop.
      const dw=Math.max(document.documentElement?.scrollWidth||0,document.body?.scrollWidth||0);
      const mostlyWhite=body.length<3500;
      if(dw>innerWidth*1.45&&frames.some(f=>{const r=f.getBoundingClientRect();return r.width>180&&r.height>130;})&&mostlyWhite){
        return JSON.stringify({type:'captcha',reason:'overflow'});
      }

      const password=document.querySelector('input[type="password"]');
      const loginUrl=/\/login|signin|account\/login/.test(url);
      const loginText=/entrar na sua conta|faça login|faca login|login com senha/.test(body.slice(0,5000));
      if(password&&(loginUrl||loginText)) return JSON.stringify({type:'login'});
      return JSON.stringify({type:'clear'});
    })();
  ''';

  static const String _focusChallengeScript = r'''
    (()=>{
      const visible=el=>{
        if(!el)return false;
        const s=getComputedStyle(el),r=el.getBoundingClientRect();
        return s.display!=='none'&&s.visibility!=='hidden'&&Number(s.opacity||1)>0&&r.width>80&&r.height>45;
      };
      const clue=/captcha|verify|verification|security|challenge|arkose|geetest|hcaptcha|recaptcha/;
      let target=null;
      const selectors=[
        'iframe[src*="captcha" i]','iframe[src*="verify" i]','iframe[src*="security" i]',
        'iframe[src*="challenge" i]','iframe[src*="arkose" i]','iframe[src*="geetest" i]',
        '[class*="captcha" i]','[id*="captcha" i]','[class*="verify" i]','[id*="verify" i]',
        '[class*="challenge" i]','[id*="challenge" i]','[class*="security" i]','[id*="security" i]'
      ];
      for(const s of selectors){const el=document.querySelector(s);if(visible(el)){target=el;break;}}
      if(!target){
        const frames=[...document.querySelectorAll('iframe')].filter(visible);
        target=frames.find(f=>clue.test(((f.src||'')+' '+(f.id||'')+' '+(f.className||'')).toLowerCase()))||
               frames.find(f=>{const r=f.getBoundingClientRect();return r.width>=220&&r.height>=160&&(r.left>innerWidth*.45||r.right>innerWidth);})||null;
      }
      if(!target){
        const terms=/verifique|verificação|verificacao|captcha|arraste|deslize|security|tente novamente/;
        for(const el of [...document.querySelectorAll('main,section,div')]){
          if(!visible(el))continue;
          const t=(el.innerText||'').toLowerCase().trim(),r=el.getBoundingClientRect();
          if(t.length>0&&t.length<1600&&terms.test(t)&&r.width>160&&r.height>100){target=el;break;}
        }
      }

      let meta=document.querySelector('meta[name="viewport"]');
      if(!meta){meta=document.createElement('meta');meta.name='viewport';document.head?.appendChild(meta);}
      if(!meta.dataset.saOldViewport)meta.dataset.saOldViewport=meta.getAttribute('content')||'';
      meta.setAttribute('content','width=device-width, initial-scale=0.55, minimum-scale=0.35, maximum-scale=3.0, user-scalable=yes');
      const pageWidth=Math.max(document.documentElement?.scrollWidth||980,980);
      const scale=Math.max(.38,Math.min(.68,(innerWidth/pageWidth)*1.12));
      if(document.body){document.body.style.zoom=String(scale);document.body.style.transformOrigin='top left';}
      document.documentElement.style.overflowX='auto';

      if(target){
        target.style.scrollMargin='110px';
        target.scrollIntoView({behavior:'auto',block:'center',inline:'center'});
        setTimeout(()=>{
          const r=target.getBoundingClientRect();
          const left=Math.max(0,window.scrollX+r.left-(innerWidth-r.width)/2);
          const top=Math.max(0,window.scrollY+r.top-(innerHeight-r.height)/2);
          window.scrollTo({left,top,behavior:'smooth'});
        },180);
      }else{
        const left=Math.max(0,(document.documentElement.scrollWidth-innerWidth)/2);
        window.scrollTo({left,top:Math.max(0,document.documentElement.scrollHeight*.18),behavior:'smooth'});
      }
      return true;
    })();
  ''';

  @override
  Widget build(BuildContext context) {
    final needsAction = challenge || loginRequired;
    return PopScope(
      canPop: true,
      child: Scaffold(
        appBar: AppBar(title: Text(needsAction ? 'Verificação da Shopee' : 'Preparando acesso à Shopee')),
        body: Stack(
          children: [
            Positioned.fill(child: WebViewWidget(controller: controller)),
            if (!needsAction)
              Positioned.fill(
                child: ColoredBox(
                  color: Theme.of(context).scaffoldBackgroundColor,
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.all(28),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const CircularProgressIndicator(),
                          const SizedBox(height: 18),
                          Text(status, textAlign: TextAlign.center, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
                          const SizedBox(height: 8),
                          const Text('A Shopee às vezes pede uma verificação antes de liberar a leitura.', textAlign: TextAlign.center),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            if (needsAction)
              Positioned(
                left: 10,
                right: 10,
                top: 8,
                child: SafeArea(
                  child: Card(
                    elevation: 8,
                    child: Padding(
                      padding: const EdgeInsets.all(13),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Row(children: [
                            Icon(challenge ? Icons.verified_user_outlined : Icons.login, color: kOrange),
                            const SizedBox(width: 9),
                            Expanded(child: Text(status, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16))),
                          ]),
                          const SizedBox(height: 6),
                          Text(
                            challenge
                                ? 'Responda ao desafio da Shopee abaixo. O app reduziu a página e está tentando manter a verificação no centro da tela.'
                                : 'Entre diretamente na Shopee nesta tela. O Super Anúncio não recebe sua senha.',
                            style: const TextStyle(fontSize: 13),
                          ),
                          const SizedBox(height: 9),
                          Row(children: [
                            if (challenge)
                              Expanded(child: OutlinedButton.icon(onPressed: _focusChallenge, icon: const Icon(Icons.center_focus_strong), label: const Text('Centralizar'))),
                            if (challenge) const SizedBox(width: 8),
                            Expanded(child: FilledButton.icon(onPressed: _inspect, icon: const Icon(Icons.check_circle_outline), label: Text(challenge ? 'Já respondi' : 'Verificar login'))),
                          ]),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class ShopeeWebCollectorV3 {
  static Future<ShopeeProductData?> collectProduct(BuildContext context, String url) async {
    final ready = await ShopeeVerificationGate.ensureReady(context, url);
    if (!ready || !context.mounted) return null;
    return ShopeeWebCollectorV2.collectProduct(context, url);
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
    final searchUrl = 'https://shopee.com.br/search?keyword=${Uri.encodeQueryComponent(query)}';
    final ready = await ShopeeVerificationGate.ensureReady(context, searchUrl);
    if (!ready || !context.mounted) return const [];
    return ShopeeWebCollectorV2.searchCompetitors(context, title, ownItemId: ownItemId);
  }
}
