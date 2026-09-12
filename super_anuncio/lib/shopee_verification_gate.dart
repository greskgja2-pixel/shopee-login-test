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
  bool challengeFocused = false;
  bool finished = false;
  int clearChecks = 0;
  int redirects = 0;
  late DateTime pageStartedAt;
  String status = 'Verificando acesso à Shopee...';

  @override
  void initState() {
    super.initState();
    pageStartedAt = DateTime.now();
    controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0xFFFFFFFF))
      ..setUserAgent('Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/151.0.0.0 Safari/537.36')
      ..setNavigationDelegate(NavigationDelegate(
        onNavigationRequest: _navigation,
        onPageStarted: (_) {
          pageStartedAt = DateTime.now();
          challengeFocused = false;
          clearChecks = 0;
          if (!mounted) return;
          setState(() {
            loading = true;
            status = 'Carregando a Shopee...';
          });
        },
        onPageFinished: (_) {
          if (!mounted) return;
          setState(() => loading = false);
          Future.delayed(const Duration(milliseconds: 280), _inspect);
        },
        onWebResourceError: (error) {
          if (!mounted || error.isForMainFrame != true) return;
          if (error.description.toLowerCase().contains('unknown_url_scheme')) return;
          setState(() => status = 'Aguardando resposta da Shopee...');
        },
      ))
      ..loadRequest(Uri.parse(widget.targetUrl));

    poller = Timer.periodic(const Duration(milliseconds: 650), (_) => _inspect());
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
        if (!challenge || loginRequired) {
          setState(() {
            challenge = true;
            loginRequired = false;
            status = 'Resolva o CAPTCHA para continuar';
          });
        }
        if (!challengeFocused) {
          challengeFocused = true;
          await _focusChallengeOnce();
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
        if (clearChecks >= 2) {
          setState(() {
            challenge = false;
            loginRequired = false;
            status = 'Verificação concluída. Continuando...';
          });
          await _restorePage();
          await Future.delayed(const Duration(milliseconds: 420));
          _finish(true);
        }
        return;
      }

      final elapsed = DateTime.now().difference(pageStartedAt);
      if (elapsed < const Duration(seconds: 4)) {
        if (status != 'Verificando se a Shopee precisa de alguma confirmação...') {
          setState(() => status = 'Verificando se a Shopee precisa de alguma confirmação...');
        }
        return;
      }
      if (clearChecks >= 3) _finish(true);
    } catch (_) {}
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

  Future<void> _focusChallengeOnce() async {
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
          window.__SA_CAPTCHA_FOCUSED__=false;
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
      const exact=/verifique\s+para\s+continuar|arraste\s+para\s+completar\s+o\s+quebra[- ]cabeça|arraste\s+para\s+completar\s+o\s+quebra[- ]cabeca/;
      if(exact.test(body)) return JSON.stringify({type:'captcha',reason:'exact-text'});

      const visible=el=>{
        if(!el)return false;
        const s=getComputedStyle(el),r=el.getBoundingClientRect();
        return s.display!=='none'&&s.visibility!=='hidden'&&Number(s.opacity||1)>0&&r.width>70&&r.height>40;
      };
      const selectors=[
        'iframe[src*="captcha" i]','iframe[src*="verify" i]','iframe[src*="security" i]',
        'iframe[src*="challenge" i]','iframe[src*="geetest" i]','iframe[src*="hcaptcha" i]',
        '[class*="captcha" i]','[id*="captcha" i]','[class*="verify" i]','[id*="verify" i]',
        '[class*="challenge" i]','[id*="challenge" i]'
      ];
      for(const s of selectors){const el=document.querySelector(s);if(visible(el))return JSON.stringify({type:'captcha',reason:'selector'});}
      if(/captcha|verify|verification|traffic|challenge/.test(url)) return JSON.stringify({type:'captcha',reason:'url'});
      if(/verificação de segurança|verificacao de seguranca|deslize para completar|tente novamente/.test(body.slice(0,12000))) return JSON.stringify({type:'captcha',reason:'text'});

      const password=document.querySelector('input[type="password"]');
      const loginUrl=/\/login|signin|account\/login/.test(url);
      const loginText=/entrar na sua conta|faça login|faca login|login com senha/.test(body.slice(0,5000));
      if(password&&(loginUrl||loginText)) return JSON.stringify({type:'login'});
      return JSON.stringify({type:'clear'});
    })();
  ''';

  static const String _focusChallengeScript = r'''
    (()=>{
      if(window.__SA_CAPTCHA_FOCUSED__) return true;
      window.__SA_CAPTCHA_FOCUSED__=true;
      const visible=el=>{
        if(!el)return false;
        const s=getComputedStyle(el),r=el.getBoundingClientRect();
        return s.display!=='none'&&s.visibility!=='hidden'&&Number(s.opacity||1)>0&&r.width>60&&r.height>35;
      };
      const exact=/verifique\s+para\s+continuar|arraste\s+para\s+completar\s+o\s+quebra[- ]cabeça|arraste\s+para\s+completar\s+o\s+quebra[- ]cabeca/;
      let target=null;
      const candidates=[...document.querySelectorAll('main,section,article,div')].filter(visible);
      const matches=candidates.filter(el=>{
        const t=(el.innerText||'').toLowerCase().replace(/\s+/g,' ').trim();
        return t.length>0&&t.length<1800&&exact.test(t);
      });
      if(matches.length){
        matches.sort((a,b)=>{
          const ar=a.getBoundingClientRect(),br=b.getBoundingClientRect();
          return ar.width*ar.height-br.width*br.height;
        });
        target=matches[0];
      }
      if(!target){
        const sels=['iframe[src*="captcha" i]','iframe[src*="verify" i]','iframe[src*="challenge" i]','[class*="captcha" i]','[id*="captcha" i]','[class*="verify" i]','[id*="verify" i]'];
        for(const s of sels){const el=document.querySelector(s);if(visible(el)){target=el;break;}}
      }
      if(!target){
        const frames=[...document.querySelectorAll('iframe')].filter(visible);
        target=frames.find(f=>{const r=f.getBoundingClientRect();return r.width>180&&r.height>120;})||null;
      }

      const viewportWidth=Math.max(320,window.innerWidth||360);
      const pageWidth=Math.max(viewportWidth,document.documentElement?.scrollWidth||viewportWidth,document.body?.scrollWidth||viewportWidth);
      const scale=Math.max(.42,Math.min(.82,(viewportWidth/pageWidth)*.96));
      if(document.body){
        document.body.style.zoom=String(scale);
        document.body.style.transformOrigin='top left';
      }
      document.documentElement.style.overflowX='auto';

      setTimeout(()=>{
        if(target){
          target.style.scrollMargin='90px';
          target.scrollIntoView({behavior:'auto',block:'center',inline:'center'});
          setTimeout(()=>{
            const r=target.getBoundingClientRect();
            const left=Math.max(0,window.scrollX+r.left-(window.innerWidth-r.width)/2);
            const top=Math.max(0,window.scrollY+r.top-(window.innerHeight-r.height)/2);
            window.scrollTo({left,top,behavior:'auto'});
          },70);
        }else{
          window.scrollTo({left:Math.max(0,(document.documentElement.scrollWidth-window.innerWidth)/2),top:0,behavior:'auto'});
        }
      },90);
      return true;
    })();
  ''';

  @override
  Widget build(BuildContext context) {
    final needsAction = challenge || loginRequired;
    return Scaffold(
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
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      const CircularProgressIndicator(),
                      const SizedBox(height: 18),
                      Text(status, textAlign: TextAlign.center, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
                    ]),
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
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      Row(children: [
                        Icon(challenge ? Icons.verified_user_outlined : Icons.login, color: kOrange),
                        const SizedBox(width: 9),
                        Expanded(child: Text(status, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16))),
                      ]),
                      const SizedBox(height: 6),
                      Text(
                        challenge
                            ? 'Resolva a verificação da Shopee abaixo. O app ajustou o enquadramento uma única vez e continuará automaticamente quando o CAPTCHA desaparecer.'
                            : 'Entre diretamente na Shopee nesta tela. O Super Anúncio não recebe sua senha.',
                        style: const TextStyle(fontSize: 13),
                      ),
                      const SizedBox(height: 9),
                      Row(children: [
                        if (challenge)
                          Expanded(child: OutlinedButton.icon(onPressed: _focusChallengeOnce, icon: const Icon(Icons.center_focus_strong), label: const Text('Centralizar'))),
                        if (challenge) const SizedBox(width: 8),
                        Expanded(child: FilledButton.icon(onPressed: _inspect, icon: const Icon(Icons.check_circle_outline), label: Text(challenge ? 'Já respondi' : 'Verificar login'))),
                      ]),
                    ]),
                  ),
                ),
              ),
            ),
        ],
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
