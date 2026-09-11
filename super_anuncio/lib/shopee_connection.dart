part of 'main.dart';

class ShopeeSession {
  static Future<bool> savedConnected() async {
    try {
      return await kShareChannel.invokeMethod<bool>('getShopeeConnected') ?? false;
    } catch (_) {
      return false;
    }
  }

  static Future<void> saveConnected(bool value) async {
    try {
      await kShareChannel.invokeMethod('setShopeeConnected', value);
    } catch (_) {}
  }

  static Future<void> disconnect() async {
    try {
      await WebViewCookieManager().clearCookies();
    } catch (_) {}
    await saveConnected(false);
  }
}

class ShopeeFirstUseGate extends StatelessWidget {
  final Future<void> Function() onConnected;
  final VoidCallback onSkip;
  const ShopeeFirstUseGate({super.key, required this.onConnected, required this.onSkip});

  Future<void> _connect(BuildContext context) async {
    final connected = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => const ShopeeConnectionPage()),
    );
    if (connected == true) await onConnected();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Column(
                children: [
                  const SaShield(size: 100),
                  const SizedBox(height: 18),
                  const SuperAnuncioLogo(fontSize: 30),
                  const SizedBox(height: 30),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(22),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(children: [
                            CircleAvatar(backgroundColor: cs.primaryContainer, child: Icon(Icons.shopping_bag_outlined, color: cs.primary)),
                            const SizedBox(width: 12),
                            const Expanded(child: Text('Conectar à Shopee', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900))),
                          ]),
                          const SizedBox(height: 14),
                          const Text('Para ler anúncios e pesquisar concorrentes automaticamente, entre na sua conta da Shopee dentro do navegador seguro do app.', style: TextStyle(fontSize: 16, height: 1.35)),
                          const SizedBox(height: 16),
                          const NoticeBox(icon: Icons.lock_outline, text: 'O login acontece diretamente no site oficial da Shopee. O Super Anúncio não recebe, não lê e não salva sua senha.'),
                          const SizedBox(height: 18),
                          FilledButton.icon(
                            onPressed: () => _connect(context),
                            icon: const Icon(Icons.login),
                            label: const Text('CONECTAR À SHOPEE'),
                            style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16), textStyle: const TextStyle(fontWeight: FontWeight.w900)),
                          ),
                          const SizedBox(height: 8),
                          TextButton(onPressed: onSkip, child: const Text('Agora não — continuar com preenchimento manual')),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class ShopeeConnectionPage extends StatefulWidget {
  final bool verifyOnly;
  final bool clearSessionFirst;
  const ShopeeConnectionPage({super.key, this.verifyOnly = false, this.clearSessionFirst = false});

  @override
  State<ShopeeConnectionPage> createState() => _ShopeeConnectionPageState();
}

class _ShopeeConnectionPageState extends State<ShopeeConnectionPage> {
  WebViewController? controller;
  bool connected = false;
  bool checking = false;
  bool loading = true;
  String status = 'Abrindo a Shopee...';
  String? accountLabel;

  @override
  void initState() {
    super.initState();
    _setup();
  }

  Future<void> _setup() async {
    if (widget.clearSessionFirst) await ShopeeSession.disconnect();
    final c = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0xFFFFFFFF))
      ..addJavaScriptChannel('SuperAnuncio', onMessageReceived: _message)
      ..setNavigationDelegate(NavigationDelegate(
        onPageStarted: (_) {
          if (mounted) setState(() { loading = true; status = 'Carregando página oficial da Shopee...'; });
        },
        onPageFinished: (_) {
          if (!mounted) return;
          setState(() => loading = false);
          Future.delayed(const Duration(milliseconds: 700), _checkSession);
        },
        onWebResourceError: (error) {
          if (mounted && error.isForMainFrame == true) setState(() => status = 'Não consegui abrir a Shopee. Verifique sua internet e tente novamente.');
        },
      ));
    if (mounted) setState(() => controller = c);
    final start = widget.verifyOnly ? 'https://shopee.com.br/' : 'https://shopee.com.br/buyer/login?next=https%3A%2F%2Fshopee.com.br%2F';
    await c.loadRequest(Uri.parse(start));
  }

  void _message(JavaScriptMessage message) {
    dynamic decoded;
    try { decoded = jsonDecode(message.message); } catch (_) { return; }
    if (decoded is! Map) return;
    final map = Map<String, dynamic>.from(decoded);
    if ('${map['type']}' != 'session') return;
    final ok = map['connected'] == true;
    final label = '${map['label'] ?? ''}'.trim();
    if (!mounted) return;
    setState(() {
      connected = ok;
      checking = false;
      accountLabel = label.isEmpty ? null : label;
      status = ok ? 'Shopee conectada. A sessão ficará salva neste aparelho.' : 'Ainda não identifiquei uma sessão conectada. Entre na sua conta da Shopee abaixo.';
    });
    ShopeeSession.saveConnected(ok);
  }

  Future<void> _checkSession() async {
    final c = controller;
    if (!mounted || c == null || loading || checking) return;
    setState(() { checking = true; status = 'Verificando sua sessão da Shopee...'; });
    const script = r'''(async()=>{
      const post=(x)=>SuperAnuncio.postMessage(JSON.stringify(x));
      let ok=false,label='';
      const endpoints=['/api/v4/account/basic/get_account_info','/api/v4/account/basic/get_user_info'];
      for(const url of endpoints){
        try{
          const r=await fetch(url,{credentials:'include',headers:{'accept':'application/json,text/plain,*/*','x-api-source':'pc'}});
          if(!r.ok) continue;
          const j=await r.json();
          const d=j?.data||j||{};
          const user=d?.userid??d?.user_id??d?.user?.userid??d?.user?.user_id??d?.account?.userid;
          if(user){ok=true;label=String(d?.username??d?.user?.username??d?.account?.username??'');break;}
        }catch(_){ }
      }
      if(!ok){
        const text=String(document.body?.innerText||'').toLowerCase();
        const hasAccount=/minhas compras|minha conta|minhas moedas|sair/.test(text);
        const clearlyLogin=/entrar com|faça login|iniciar sessão|login com/.test(text);
        if(hasAccount&&!clearlyLogin) ok=true;
      }
      post({type:'session',connected:ok,label});
      return ok;
    })()''';
    try {
      await c.runJavaScript(script);
    } catch (_) {
      if (mounted) setState(() { checking = false; status = 'Não consegui verificar automaticamente. Você pode tentar novamente.'; });
    }
  }

  Future<void> _finish() async {
    await ShopeeSession.saveConnected(true);
    if (mounted) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final c = controller;
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.verifyOnly ? 'Verificar Shopee' : 'Conectar à Shopee'),
        actions: [IconButton(onPressed: c == null ? null : _checkSession, icon: const Icon(Icons.refresh), tooltip: 'Verificar conexão')],
      ),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            color: connected ? const Color(0xFFE5F7EA) : cs.primaryContainer,
            child: Row(children: [
              Icon(connected ? Icons.check_circle : Icons.lock_outline, color: connected ? Colors.green.shade700 : cs.primary),
              const SizedBox(width: 10),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(status, style: const TextStyle(fontWeight: FontWeight.w800)),
                if (accountLabel != null) Text('Conta: $accountLabel'),
                const Text('Sua senha é digitada somente no site oficial da Shopee.', style: TextStyle(fontSize: 12)),
              ])),
              if (loading || checking) const Padding(padding: EdgeInsets.only(left: 8), child: SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2))),
            ]),
          ),
          Expanded(child: c == null ? const Center(child: CircularProgressIndicator()) : WebViewWidget(controller: c)),
          SafeArea(
            minimum: const EdgeInsets.fromLTRB(14, 8, 14, 12),
            child: Row(children: [
              Expanded(child: OutlinedButton.icon(onPressed: c == null ? null : _checkSession, icon: const Icon(Icons.verified_user_outlined), label: const Text('Verificar'))),
              const SizedBox(width: 10),
              Expanded(child: FilledButton.icon(onPressed: connected ? _finish : null, icon: const Icon(Icons.check), label: const Text('CONCLUIR'))),
            ]),
          ),
        ],
      ),
    );
  }
}
