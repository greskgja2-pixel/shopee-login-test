part of 'main.dart';

/// Faz uma checagem rápida antes da coleta. Se a Shopee exibir CAPTCHA,
/// verificação de segurança ou login, a página é mostrada ao usuário com
/// zoom reduzido e tentativa de centralizar o desafio. Quando a verificação
/// desaparece, o fluxo continua automaticamente.
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
  String status = 'Verificando acesso à Shopee...';

  @override
  void initState() {
    super.initState();
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
            status = 'Carregando a Shopee...';
          });
        },
        onPageFinished: (_) {
          if (!mounted) return;
          setState(() => loading = false);
          Future.delayed(const Duration(milliseconds: 450), _inspect);
        },
        onWebResourceError: (error) {
          if (!mounted || error.isForMainFrame != true) return;
          if (error.description.toLowerCase().contains('unknown_url_scheme')) return;
          setState(() => status = 'Aguardando resposta da Shopee...');
        },
      ))
      ..loadRequest(Uri.parse(widget.targetUrl));

    poller = Timer.periodic(const Duration(milliseconds: 1200), (_) => _inspect());
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
        if (!challenge || loginRequired) {
          setState(() {
            challenge = true;
            loginRequired = false;
            status = 'Verificação da Shopee necessária';
          });
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
        if (clearChecks >= 2) {
          setState(() {
            challenge = false;
            loginRequired = false;
            status = 'Verificação concluída. Continuando...';
          });
          await _restorePage();
          await Future.delayed(const Duration(milliseconds: 650));
          _finish(true);
        }
      } else if (clearChecks >= 3) {
        _finish(true);
      }
    } catch (_) {
      // A página pode estar trocando de rota; a próxima checagem tenta novamente.
    }
  }

  Map<String, dynamic> _decodeJsResult(Object raw) {
    try {
      dynamic value = raw;
      if (value is String) {
        var text = value;
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
          const target=p?.closest('form,section,div')||p;
          if(target){target.scrollIntoView({behavior:'smooth',block:'center'});}
          return true;
        })();
      ''');
    } catch (_) {}
  }

  Future<void> _restorePage() async {
    try {
      await controller.runJavaScript(r'''
        (()=>{
          if(document.body) document.body.style.zoom='';
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
      const captchaSelector='iframe[src*="captcha" i],iframe[src*="verify" i],[class*="captcha" i],[id*="captcha" i],[class*="security-verification" i],[id*="security-verification" i],[data-testid*="captcha" i]';
      const captchaEl=document.querySelector(captchaSelector);
      const captchaText=/captcha|verificação de segurança|verificacao de seguranca|security verification|deslize para completar|arraste para completar|confirme que você não é um robô|confirme que voce nao e um robo|complete a verificação|complete a verificacao/.test(body);
      const captchaUrl=/captcha|verify|verification|traffic/.test(url);
      if(captchaEl||captchaText||captchaUrl) return JSON.stringify({type:'captcha'});

      const password=document.querySelector('input[type="password"]');
      const loginUrl=/\/login|signin|account\/login/.test(url);
      const loginText=/entrar na sua conta|faça login|faca login|login com senha/.test(body.slice(0,5000));
      if(password&&(loginUrl||loginText)) return JSON.stringify({type:'login'});
      return JSON.stringify({type:'clear'});
    })();
  ''';

  static const String _focusChallengeScript = r'''
    (()=>{
      let meta=document.querySelector('meta[name="viewport"]');
      if(!meta){meta=document.createElement('meta');meta.name='viewport';document.head?.appendChild(meta);}
      if(!meta.dataset.saOldViewport) meta.dataset.saOldViewport=meta.getAttribute('content')||'';
      meta.setAttribute('content','width=device-width, initial-scale=0.72, minimum-scale=0.45, maximum-scale=3.0, user-scalable=yes');
      if(document.body) document.body.style.zoom='0.78';

      const sels=[
        'iframe[src*="captcha" i]','iframe[src*="verify" i]',
        '[class*="captcha" i]','[id*="captcha" i]',
        '[class*="security-verification" i]','[id*="security-verification" i]',
        '[data-testid*="captcha" i]'
      ];
      let target=null;
      for(const s of sels){const el=document.querySelector(s);if(el){target=el;break;}}
      if(!target){
        const terms=/captcha|verificação de segurança|verificacao de seguranca|security verification|deslize para completar|arraste para completar|não é um robô|nao e um robo/;
        for(const el of [...document.querySelectorAll('section,main,div')]){
          const t=(el.innerText||'').toLowerCase().trim();
          const r=el.getBoundingClientRect();
          if(t.length>0&&t.length<1200&&terms.test(t)&&r.width>80&&r.height>40){target=el;break;}
        }
      }
      if(target){
        target.style.scrollMarginTop='90px';
        target.scrollIntoView({behavior:'smooth',block:'center',inline:'center'});
        setTimeout(()=>window.scrollBy(0,-35),250);
      }else{
        window.scrollTo({top:Math.max(0,document.documentElement.scrollHeight*0.28),behavior:'smooth'});
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
        appBar: AppBar(
          title: Text(needsAction ? 'Verificação da Shopee' : 'Preparando acesso à Shopee'),
        ),
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
                          const Text('Isso costuma levar só alguns segundos.', textAlign: TextAlign.center),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            if (needsAction)
              Positioned(
                left: 12,
                right: 12,
                top: 10,
                child: SafeArea(
                  child: Card(
                    elevation: 8,
                    color: Theme.of(context).colorScheme.surface,
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Row(
                            children: [
                              Icon(challenge ? Icons.verified_user_outlined : Icons.login, color: kOrange),
                              const SizedBox(width: 10),
                              Expanded(child: Text(status, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16))),
                            ],
                          ),
                          const SizedBox(height: 7),
                          Text(
                            challenge
                                ? 'Responda ao desafio abaixo. O app reduziu o zoom e tentou trazer a verificação para o centro. Assim que ela for concluída, a análise continua automaticamente.'
                                : 'Entre diretamente na Shopee nesta tela. O Super Anúncio não recebe sua senha.',
                            style: const TextStyle(fontSize: 13.5),
                          ),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              if (challenge)
                                Expanded(
                                  child: OutlinedButton.icon(
                                    onPressed: _focusChallenge,
                                    icon: const Icon(Icons.center_focus_strong),
                                    label: const Text('Centralizar desafio'),
                                  ),
                                ),
                              if (challenge) const SizedBox(width: 8),
                              Expanded(
                                child: FilledButton.icon(
                                  onPressed: _inspect,
                                  icon: const Icon(Icons.check_circle_outline),
                                  label: Text(challenge ? 'Já respondi' : 'Verificar login'),
                                ),
                              ),
                            ],
                          ),
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

/// Mantém o coletor que já funcionou no teste do usuário, acrescentando a
/// verificação visual antes das duas operações que podem disparar CAPTCHA.
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
