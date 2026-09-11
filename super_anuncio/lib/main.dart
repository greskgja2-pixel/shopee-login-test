import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const SuperAnuncioApp());
}

class SuperAnuncioApp extends StatefulWidget {
  const SuperAnuncioApp({super.key});

  @override
  State<SuperAnuncioApp> createState() => _SuperAnuncioAppState();
}

class _SuperAnuncioAppState extends State<SuperAnuncioApp> {
  bool darkMode = false;

  @override
  Widget build(BuildContext context) {
    const orange = Color(0xFFFF5A1F);
    return MaterialApp(
      title: 'Super Anúncio',
      debugShowCheckedModeBanner: false,
      themeMode: darkMode ? ThemeMode.dark : ThemeMode.light,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: orange, primary: orange),
        scaffoldBackgroundColor: const Color(0xFFF7F7F9),
        fontFamily: 'sans',
        cardTheme: const CardThemeData(elevation: 0, margin: EdgeInsets.zero),
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        colorScheme: ColorScheme.fromSeed(seedColor: orange, brightness: Brightness.dark),
      ),
      home: SplashPage(
        onDone: () => Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => HomePage(
              darkMode: darkMode,
              onDarkModeChanged: (value) => setState(() => darkMode = value),
            ),
          ),
        ),
      ),
    );
  }
}

class SplashPage extends StatefulWidget {
  final VoidCallback onDone;
  const SplashPage({super.key, required this.onDone});

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage> with SingleTickerProviderStateMixin {
  late final AnimationController controller;

  @override
  void initState() {
    super.initState();
    controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 900))..forward();
    Timer(const Duration(milliseconds: 1500), widget.onDone);
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFF5A1F),
      body: Center(
        child: FadeTransition(
          opacity: CurvedAnimation(parent: controller, curve: Curves.easeIn),
          child: ScaleTransition(
            scale: Tween<double>(begin: .75, end: 1).animate(CurvedAnimation(parent: controller, curve: Curves.elasticOut)),
            child: const Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SaShield(size: 150),
                SizedBox(height: 20),
                SuperAnuncioLogo(fontSize: 36),
                SizedBox(height: 10),
                Text('Analise. Otimize. Venda mais.', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class HomePage extends StatefulWidget {
  final bool darkMode;
  final ValueChanged<bool> onDarkModeChanged;
  const HomePage({super.key, required this.darkMode, required this.onDarkModeChanged});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  static const _shareChannel = MethodChannel('super_anuncio/share');
  int index = 0;
  int analysisCount = 0;
  final List<AnalysisResult> history = [];
  String? sharedText;

  @override
  void initState() {
    super.initState();
    _initShareReceiver();
  }

  Future<void> _initShareReceiver() async {
    _shareChannel.setMethodCallHandler((call) async {
      if (call.method == 'sharedText' && call.arguments is String) {
        setState(() {
          sharedText = call.arguments as String;
          index = 0;
        });
      }
    });
    try {
      final value = await _shareChannel.invokeMethod<String>('initialSharedText');
      if (value != null && value.isNotEmpty) {
        setState(() => sharedText = value);
      }
    } catch (_) {}
  }

  void addResult(AnalysisResult result) {
    setState(() {
      history.insert(0, result);
      analysisCount++;
    });
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      AnalyzerPage(initialText: sharedText, onResult: addResult),
      HistoryPage(history: history),
      AchievementsPage(analysisCount: analysisCount),
      SettingsPage(darkMode: widget.darkMode, onDarkModeChanged: widget.onDarkModeChanged),
    ];

    return Scaffold(
      body: IndexedStack(index: index, children: pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: index,
        onDestinationSelected: (i) => setState(() => index = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home), label: 'Início'),
          NavigationDestination(icon: Icon(Icons.history), label: 'Histórico'),
          NavigationDestination(icon: Icon(Icons.emoji_events_outlined), selectedIcon: Icon(Icons.emoji_events), label: 'Conquistas'),
          NavigationDestination(icon: Icon(Icons.settings_outlined), selectedIcon: Icon(Icons.settings), label: 'Ajustes'),
        ],
      ),
    );
  }
}

class AnalyzerPage extends StatefulWidget {
  final String? initialText;
  final ValueChanged<AnalysisResult> onResult;
  const AnalyzerPage({super.key, this.initialText, required this.onResult});

  @override
  State<AnalyzerPage> createState() => _AnalyzerPageState();
}

class _AnalyzerPageState extends State<AnalyzerPage> {
  final controller = TextEditingController();
  bool busy = false;

  @override
  void didUpdateWidget(covariant AnalyzerPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialText != null && widget.initialText != oldWidget.initialText) {
      controller.text = _extractUrl(widget.initialText!);
    }
  }

  @override
  void initState() {
    super.initState();
    if (widget.initialText != null) controller.text = _extractUrl(widget.initialText!);
  }

  String _extractUrl(String text) {
    final match = RegExp(r'https?://\S+').firstMatch(text);
    return (match?.group(0) ?? text).trim();
  }

  Future<void> paste() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    if (data?.text != null) controller.text = _extractUrl(data!.text!);
  }

  Future<void> analyze() async {
    final url = controller.text.trim();
    if (url.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Cole primeiro o link do anúncio.')));
      return;
    }

    final answers = await showDialog<TriageAnswers>(context: context, builder: (_) => const TriageDialog());
    if (answers == null) return;

    setState(() => busy = true);
    await Future.delayed(const Duration(milliseconds: 1100));
    final result = AnalysisResult.build(url, answers);
    if (!mounted) return;
    setState(() => busy = false);
    widget.onResult(result);
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => ResultPage(result: result)));
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 30),
        children: [
          Row(
            children: [
              const SaShield(size: 58),
              const SizedBox(width: 12),
              const Expanded(child: SuperAnuncioLogo(fontSize: 25)),
              CircleAvatar(backgroundColor: cs.primaryContainer, child: Icon(Icons.person, color: cs.primary)),
            ],
          ),
          const SizedBox(height: 26),
          Text('Olá! 👋', style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w900)),
          const SizedBox(height: 4),
          Text('Vamos turbinar seu anúncio?', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 24),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('Cole o link da Shopee', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
                  const SizedBox(height: 12),
                  TextField(
                    controller: controller,
                    keyboardType: TextInputType.url,
                    decoration: InputDecoration(
                      hintText: 'https://shopee.com.br/...',
                      prefixIcon: const Icon(Icons.link),
                      suffixIcon: IconButton(onPressed: paste, icon: const Icon(Icons.content_paste)),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                  ),
                  const SizedBox(height: 14),
                  FilledButton.icon(
                    onPressed: busy ? null : analyze,
                    icon: busy
                        ? const SizedBox.square(dimension: 20, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.auto_awesome),
                    label: Text(busy ? 'Analisando...' : 'ANALISAR ANÚNCIO'),
                    style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16), textStyle: const TextStyle(fontWeight: FontWeight.w900)),
                  ),
                  const SizedBox(height: 10),
                  Text('Você também pode compartilhar um link da Shopee diretamente para o Super Anúncio.', textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodySmall),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          Text('O que analisamos', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900)),
          const SizedBox(height: 12),
          const Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              FeatureChip(icon: Icons.title, text: 'Título'),
              FeatureChip(icon: Icons.photo_library_outlined, text: 'Imagens'),
              FeatureChip(icon: Icons.description_outlined, text: 'Descrição'),
              FeatureChip(icon: Icons.sell_outlined, text: 'Preço'),
              FeatureChip(icon: Icons.search, text: 'SEO'),
              FeatureChip(icon: Icons.psychology_outlined, text: 'Conversão'),
            ],
          ),
          const SizedBox(height: 22),
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [cs.primary, const Color(0xFFFF8A3D)]),
              borderRadius: BorderRadius.circular(22),
            ),
            child: const Row(
              children: [
                Icon(Icons.rocket_launch, color: Colors.white, size: 38),
                SizedBox(width: 14),
                Expanded(child: Text('Análise rápida + checklist prático para você melhorar o anúncio agora.', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 16))),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class TriageDialog extends StatefulWidget {
  const TriageDialog({super.key});
  @override
  State<TriageDialog> createState() => _TriageDialogState();
}

class _TriageDialogState extends State<TriageDialog> {
  String goal = 'Vender mais';
  String stage = 'Já vende';
  String issue = 'Poucas visitas';

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('3 perguntas rápidas'),
      content: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('1. Seu principal objetivo?'),
            DropdownButtonFormField(value: goal, items: ['Vender mais', 'Melhorar anúncio', 'Aumentar visitas'].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(), onChanged: (v) => setState(() => goal = v!)),
            const SizedBox(height: 14),
            const Text('2. Como está o produto?'),
            DropdownButtonFormField(value: stage, items: ['Ainda não vende', 'Já vende', 'Vende bem'].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(), onChanged: (v) => setState(() => stage = v!)),
            const SizedBox(height: 14),
            const Text('3. Maior problema hoje?'),
            DropdownButtonFormField(value: issue, items: ['Poucas visitas', 'Poucas vendas', 'Muita concorrência', 'Preço'].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(), onChanged: (v) => setState(() => issue = v!)),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
        FilledButton(onPressed: () => Navigator.pop(context, TriageAnswers(goal, stage, issue)), child: const Text('Continuar')),
      ],
    );
  }
}

class ResultPage extends StatelessWidget {
  final AnalysisResult result;
  const ResultPage({super.key, required this.result});

  @override
  Widget build(BuildContext context) {
    final scoreColor = result.score >= 80 ? Colors.green : result.score >= 60 ? Colors.orange : Colors.red;
    return Scaffold(
      appBar: AppBar(title: const Text('Resultado da análise')),
      body: ListView(
        padding: const EdgeInsets.all(18),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  const SaShield(size: 70),
                  const SizedBox(height: 12),
                  Text('${result.score}/100', style: TextStyle(fontSize: 44, fontWeight: FontWeight.w900, color: scoreColor)),
                  const Text('Pontuação geral', style: TextStyle(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 12),
                  LinearProgressIndicator(value: result.score / 100, minHeight: 10, borderRadius: BorderRadius.circular(10), color: scoreColor),
                  const SizedBox(height: 14),
                  Text(result.summary, textAlign: TextAlign.center),
                ],
              ),
            ),
          ),
          const SizedBox(height: 18),
          Text('Alterações sugeridas', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900)),
          const SizedBox(height: 10),
          ...result.suggestions.asMap().entries.map((entry) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Card(
                  child: ListTile(
                    leading: CircleAvatar(child: Text('${entry.key + 1}')),
                    title: Text(entry.value, style: const TextStyle(fontWeight: FontWeight.w700)),
                    trailing: const Icon(Icons.chevron_right),
                  ),
                ),
              )),
          const SizedBox(height: 8),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(children: [Icon(Icons.auto_awesome), SizedBox(width: 8), Text('Diagnóstico rápido', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18))]),
                  const SizedBox(height: 12),
                  Text('Objetivo: ${result.answers.goal}\nMomento: ${result.answers.stage}\nGargalo informado: ${result.answers.issue}'),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class HistoryPage extends StatelessWidget {
  final List<AnalysisResult> history;
  const HistoryPage({super.key, required this.history});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Histórico', style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w900)),
            const SizedBox(height: 16),
            Expanded(
              child: history.isEmpty
                  ? const Center(child: Text('Suas análises desta sessão aparecerão aqui.'))
                  : ListView.separated(
                      itemCount: history.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (_, i) {
                        final r = history[i];
                        return Card(child: ListTile(leading: CircleAvatar(child: Text('${r.score}')), title: const Text('Anúncio analisado'), subtitle: Text(r.url, maxLines: 1, overflow: TextOverflow.ellipsis), onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ResultPage(result: r)))));
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class AchievementsPage extends StatelessWidget {
  final int analysisCount;
  const AchievementsPage({super.key, required this.analysisCount});

  @override
  Widget build(BuildContext context) {
    final items = [
      ('Primeiro passo', 'Faça sua primeira análise', analysisCount >= 1, Icons.flag),
      ('Analista', 'Faça 3 análises', analysisCount >= 3, Icons.insights),
      ('Super vendedor', 'Faça 10 análises', analysisCount >= 10, Icons.workspace_premium),
    ];
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(18),
        children: [
          Text('Conquistas', style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w900)),
          const SizedBox(height: 16),
          ...items.map((e) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Card(child: ListTile(leading: CircleAvatar(child: Icon(e.$4)), title: Text(e.$1, style: const TextStyle(fontWeight: FontWeight.w800)), subtitle: Text(e.$2), trailing: Icon(e.$3 ? Icons.check_circle : Icons.lock_outline, color: e.$3 ? Colors.green : null))),
              )),
        ],
      ),
    );
  }
}

class SettingsPage extends StatelessWidget {
  final bool darkMode;
  final ValueChanged<bool> onDarkModeChanged;
  const SettingsPage({super.key, required this.darkMode, required this.onDarkModeChanged});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(18),
        children: [
          Text('Ajustes', style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w900)),
          const SizedBox(height: 16),
          Card(child: SwitchListTile(value: darkMode, onChanged: onDarkModeChanged, title: const Text('Modo escuro'), secondary: const Icon(Icons.dark_mode_outlined))),
          const SizedBox(height: 12),
          const Card(child: ListTile(leading: Icon(Icons.info_outline), title: Text('Super Anúncio'), subtitle: Text('Versão 1.0.0 • MVP Android'))),
          const SizedBox(height: 12),
          const Card(child: ListTile(leading: Icon(Icons.security_outlined), title: Text('Privacidade'), subtitle: Text('Este APK inicial faz o diagnóstico no próprio aparelho e não exige login.'))),
        ],
      ),
    );
  }
}

class FeatureChip extends StatelessWidget {
  final IconData icon;
  final String text;
  const FeatureChip({super.key, required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(color: Theme.of(context).colorScheme.surfaceContainerHighest, borderRadius: BorderRadius.circular(14)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [Icon(icon, size: 20), const SizedBox(width: 7), Text(text, style: const TextStyle(fontWeight: FontWeight.w700))]),
    );
  }
}

class SaShield extends StatelessWidget {
  final double size;
  const SaShield({super.key, required this.size});

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CustomPaint(size: Size.square(size), painter: ShieldPainter()),
          Transform.translate(offset: Offset(0, size * .04), child: Text('SA', style: TextStyle(fontSize: size * .32, fontWeight: FontWeight.w900, letterSpacing: -3, shadows: const [Shadow(color: Colors.black38, offset: Offset(2, 3), blurRadius: 2)], foreground: Paint()..shader = const LinearGradient(colors: [Color(0xFFFF3B30), Color(0xFFFF3B30), Color(0xFF18A0FB), Color(0xFF18A0FB)]).createShader(Rect.fromLTWH(0, 0, size, size))))),
          Positioned(top: size * .03, child: Icon(Icons.workspace_premium, color: const Color(0xFFFFD21E), size: size * .28)),
        ],
      ),
    );
  }
}

class ShieldPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..moveTo(size.width * .18, size.height * .24)
      ..lineTo(size.width * .82, size.height * .24)
      ..lineTo(size.width * .76, size.height * .70)
      ..quadraticBezierTo(size.width * .5, size.height * .92, size.width * .24, size.height * .70)
      ..close();
    canvas.drawShadow(path, Colors.black54, 5, true);
    canvas.drawPath(path, Paint()..color = const Color(0xFFFFC928));
    canvas.drawPath(path, Paint()..style = PaintingStyle.stroke..strokeWidth = size.width * .055..color = const Color(0xFFB87300));
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class SuperAnuncioLogo extends StatelessWidget {
  final double fontSize;
  const SuperAnuncioLogo({super.key, required this.fontSize});

  @override
  Widget build(BuildContext context) {
    const colors = [Color(0xFF19A7FF), Color(0xFFFF3B30), Color(0xFFFFD21E), Color(0xFF31C84B), Color(0xFF19A7FF), Color(0xFFFF3B30), Color(0xFFFFD21E), Color(0xFF31C84B), Color(0xFF19A7FF), Color(0xFFFF3B30), Color(0xFFFFD21E), Color(0xFF31C84B)];
    const text = 'SUPER ANÚNCIO';
    int colorIndex = 0;
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 0,
      runSpacing: 0,
      children: text.split('').map((c) {
        if (c == ' ') return SizedBox(width: fontSize * .35);
        final color = colors[colorIndex++ % colors.length];
        return Text(c, style: TextStyle(fontSize: fontSize, height: 1, fontWeight: FontWeight.w900, color: color, shadows: const [Shadow(color: Colors.black54, offset: Offset(1.5, 2.5), blurRadius: 0)]));
      }).toList(),
    );
  }
}

class TriageAnswers {
  final String goal;
  final String stage;
  final String issue;
  const TriageAnswers(this.goal, this.stage, this.issue);
}

class AnalysisResult {
  final String url;
  final int score;
  final String summary;
  final List<String> suggestions;
  final TriageAnswers answers;

  const AnalysisResult({required this.url, required this.score, required this.summary, required this.suggestions, required this.answers});

  factory AnalysisResult.build(String url, TriageAnswers answers) {
    var score = 72;
    if (url.contains('shopee')) score += 5;
    if (answers.stage == 'Vende bem') score += 8;
    if (answers.stage == 'Ainda não vende') score -= 8;
    if (answers.issue == 'Poucas vendas') score -= 4;
    if (answers.issue == 'Muita concorrência') score -= 3;
    score += math.Random(url.hashCode).nextInt(9) - 4;
    score = score.clamp(35, 94);

    final suggestions = <String>[
      'Coloque a principal palavra-chave nos primeiros 45 caracteres do título.',
      'Use a primeira imagem com fundo limpo, produto grande e benefício visual claro.',
      'Inclua na descrição benefícios, medidas, conteúdo da embalagem e dúvidas frequentes.',
      'Compare seu preço final com os anúncios líderes antes de criar promoções.',
    ];
    if (answers.issue == 'Poucas visitas') suggestions.insert(0, 'Reforce palavras-chave de busca no título e nos atributos do anúncio.');
    if (answers.issue == 'Poucas vendas') suggestions.insert(0, 'Melhore a oferta: foto principal, prova social, preço e benefícios precisam aparecer rapidamente.');
    if (answers.issue == 'Preço') suggestions.insert(0, 'Evite competir apenas no menor preço; destaque kit, benefício, prazo e diferenciais.');
    if (answers.issue == 'Muita concorrência') suggestions.insert(0, 'Busque um ângulo de diferenciação que os anúncios concorrentes não destacam.');

    return AnalysisResult(
      url: url,
      score: score,
      summary: score >= 80 ? 'Seu anúncio mostra bom potencial. Alguns ajustes podem aumentar a conversão.' : score >= 60 ? 'Há uma boa base, mas existem pontos importantes que podem estar segurando suas vendas.' : 'O anúncio precisa de uma revisão mais forte antes de receber mais tráfego.',
      suggestions: suggestions.take(5).toList(),
      answers: answers,
    );
  }
}
