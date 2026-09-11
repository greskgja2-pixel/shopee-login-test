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
  bool showSplash = true;

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
      home: showSplash
          ? SplashPage(
              onDone: () {
                if (mounted) setState(() => showSplash = false);
              },
            )
          : HomePage(
              darkMode: darkMode,
              onDarkModeChanged: (value) => setState(() => darkMode = value),
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
  Timer? timer;

  @override
  void initState() {
    super.initState();
    controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 900))..forward();
    timer = Timer(const Duration(milliseconds: 1450), widget.onDone);
  }

  @override
  void dispose() {
    timer?.cancel();
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
            scale: Tween<double>(begin: .75, end: 1).animate(
              CurvedAnimation(parent: controller, curve: Curves.elasticOut),
            ),
            child: const Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SaShield(size: 150),
                SizedBox(height: 20),
                SuperAnuncioLogo(fontSize: 36),
                SizedBox(height: 10),
                Text(
                  'Analise. Otimize. Venda mais.',
                  style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700),
                ),
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
        if (!mounted) return;
        setState(() {
          sharedText = call.arguments as String;
          index = 0;
        });
      }
    });
    try {
      final value = await _shareChannel.invokeMethod<String>('initialSharedText');
      if (value != null && value.isNotEmpty && mounted) {
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

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
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

    final input = await Navigator.of(context).push<AnalysisInput>(
      MaterialPageRoute(builder: (_) => AnalysisSetupPage(url: url)),
    );
    if (input == null) return;

    setState(() => busy = true);
    await Future.delayed(const Duration(milliseconds: 700));
    final result = AnalysisResult.build(input);
    if (!mounted) return;
    setState(() => busy = false);
    widget.onResult(result);
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => CoachPage(result: result)),
    );
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
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      textStyle: const TextStyle(fontWeight: FontWeight.w900),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Você também pode compartilhar um link da Shopee diretamente para o Super Anúncio.',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
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
              FeatureChip(icon: Icons.groups_outlined, text: 'Concorrentes'),
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
                Icon(Icons.school, color: Colors.white, size: 38),
                SizedBox(width: 14),
                Expanded(
                  child: Text(
                    'Depois da análise, o app te ensina passo a passo o que mudar e já mostra uma solução pronta.',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 16),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class AnalysisSetupPage extends StatefulWidget {
  final String url;
  const AnalysisSetupPage({super.key, required this.url});

  @override
  State<AnalysisSetupPage> createState() => _AnalysisSetupPageState();
}

class _AnalysisSetupPageState extends State<AnalysisSetupPage> {
  static const _channel = MethodChannel('super_anuncio/share');
  int step = 0;
  final title = TextEditingController();
  final description = TextEditingController();
  final category = TextEditingController();
  final price = TextEditingController();

  String goal = 'Vender mais';
  String stage = 'Já vende';
  String issue = 'Poucas visitas';

  final competitorLinks = List.generate(3, (_) => TextEditingController());
  final competitorTitles = List.generate(3, (_) => TextEditingController());
  final competitorPrices = List.generate(3, (_) => TextEditingController());

  @override
  void dispose() {
    title.dispose();
    description.dispose();
    category.dispose();
    price.dispose();
    for (final c in competitorLinks) c.dispose();
    for (final c in competitorTitles) c.dispose();
    for (final c in competitorPrices) c.dispose();
    super.dispose();
  }

  double? _parsePrice(String raw) {
    var value = raw.trim().replaceAll(RegExp(r'[^0-9,\.]'), '');
    if (value.isEmpty) return null;
    if (value.contains(',')) {
      value = value.replaceAll('.', '').replaceAll(',', '.');
    }
    return double.tryParse(value);
  }

  String get searchQuery {
    final base = title.text.trim();
    if (base.isEmpty) return 'produto';
    final cleaned = base
        .replaceAll(RegExp(r'[^A-Za-zÀ-ÿ0-9 ]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    final words = cleaned.split(' ').where((e) => e.length > 2).take(7).toList();
    return words.isEmpty ? cleaned : words.join(' ');
  }

  Future<void> openCompetitorSearch() async {
    final url = 'https://shopee.com.br/search?keyword=${Uri.encodeComponent(searchQuery)}';
    try {
      await _channel.invokeMethod('openUrl', {'url': url});
    } catch (_) {
      if (!mounted) return;
      await Clipboard.setData(ClipboardData(text: url));
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Link de busca copiado. Abra no navegador.')),
      );
    }
  }

  void next() {
    if (step == 0 && title.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Informe o título atual para eu conseguir comparar e otimizar.')),
      );
      return;
    }
    if (step < 2) {
      setState(() => step++);
      return;
    }

    final competitors = <CompetitorData>[];
    for (var i = 0; i < 3; i++) {
      final link = competitorLinks[i].text.trim();
      final name = competitorTitles[i].text.trim();
      final p = _parsePrice(competitorPrices[i].text);
      if (link.isNotEmpty || name.isNotEmpty || p != null) {
        competitors.add(CompetitorData(title: name, price: p, link: link));
      }
    }

    Navigator.pop(
      context,
      AnalysisInput(
        url: widget.url,
        title: title.text.trim(),
        description: description.text.trim(),
        category: category.text.trim(),
        price: _parsePrice(price.text),
        goal: goal,
        stage: stage,
        issue: issue,
        competitors: competitors,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final progress = (step + 1) / 3;
    return Scaffold(
      appBar: AppBar(
        title: Text('Preparando análise • ${step + 1}/3'),
      ),
      body: Column(
        children: [
          LinearProgressIndicator(value: progress, minHeight: 6),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(18),
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 220),
                child: step == 0
                    ? _listingStep()
                    : step == 1
                        ? _goalStep()
                        : _competitorStep(),
              ),
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(18, 8, 18, 16),
              child: Row(
                children: [
                  if (step > 0)
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => setState(() => step--),
                        child: const Text('Voltar'),
                      ),
                    ),
                  if (step > 0) const SizedBox(width: 10),
                  Expanded(
                    flex: 2,
                    child: FilledButton(
                      onPressed: next,
                      child: Text(step == 2 ? 'GERAR ANÁLISE' : 'Continuar'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _listingStep() {
    return Column(
      key: const ValueKey('listing'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Primeiro, preciso conhecer o anúncio', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900)),
        const SizedBox(height: 8),
        const Text('Nesta versão, esses dados são guiados. Assim eu não invento informações que não consegui ler do anúncio.'),
        const SizedBox(height: 20),
        _field(title, 'Título atual *', Icons.title, maxLines: 2, onChanged: (_) => setState(() {})),
        const SizedBox(height: 12),
        _field(description, 'Descrição atual', Icons.description_outlined, maxLines: 6),
        const SizedBox(height: 12),
        _field(category, 'Categoria atual', Icons.category_outlined),
        const SizedBox(height: 12),
        _field(price, 'Preço atual', Icons.attach_money, keyboardType: TextInputType.number),
        const SizedBox(height: 18),
        InfoBox(
          icon: Icons.auto_awesome,
          title: 'Por que pedir isso?',
          text: 'Com os dados atuais eu consigo mostrar lado a lado: atual → otimizado, sem esconder a solução atrás de uma nota.',
        ),
      ],
    );
  }

  Widget _goalStep() {
    return Column(
      key: const ValueKey('goal'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('3 perguntas rápidas', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900)),
        const SizedBox(height: 8),
        const Text('Elas ajudam o app a priorizar o que realmente pode destravar o anúncio.'),
        const SizedBox(height: 20),
        _dropdown('1. Seu principal objetivo?', goal, ['Vender mais', 'Melhorar anúncio', 'Aumentar visitas'], (v) => setState(() => goal = v)),
        const SizedBox(height: 16),
        _dropdown('2. Como está o produto?', stage, ['Ainda não vende', 'Já vende', 'Vende bem'], (v) => setState(() => stage = v)),
        const SizedBox(height: 16),
        _dropdown('3. Maior problema hoje?', issue, ['Poucas visitas', 'Poucas vendas', 'Muita concorrência', 'Preço'], (v) => setState(() => issue = v)),
      ],
    );
  }

  Widget _competitorStep() {
    return Column(
      key: const ValueKey('competitors'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Conheça os concorrentes', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900)),
        const SizedBox(height: 8),
        const Text('O Super Anúncio já prepara uma busca usando o seu título. Escolha produtos realmente equivalentes e registre até 3.'),
        const SizedBox(height: 16),
        FilledButton.tonalIcon(
          onPressed: openCompetitorSearch,
          icon: const Icon(Icons.search),
          label: Text('Buscar “$searchQuery” na Shopee'),
        ),
        const SizedBox(height: 12),
        const InfoBox(
          icon: Icons.shield_outlined,
          title: 'Modo guiado, não chute automático',
          text: 'Concorrente bom é o mesmo tipo de produto, faixa e proposta. Nesta versão você confirma quem comparar; depois essa etapa pode ser automatizada com uma fonte online adequada.',
        ),
        const SizedBox(height: 18),
        for (var i = 0; i < 3; i++) ...[
          Text('Concorrente ${i + 1}', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
          const SizedBox(height: 8),
          _field(competitorTitles[i], 'Título ou nome', Icons.storefront_outlined),
          const SizedBox(height: 8),
          _field(competitorPrices[i], 'Preço', Icons.attach_money, keyboardType: TextInputType.number),
          const SizedBox(height: 8),
          _field(competitorLinks[i], 'Link', Icons.link, keyboardType: TextInputType.url),
          if (i < 2) const Divider(height: 28),
        ],
        const SizedBox(height: 10),
        Text('Você pode pular esta etapa. A análise continua, mas a comparação de preço ficará menos precisa.', style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }

  Widget _field(
    TextEditingController controller,
    String label,
    IconData icon, {
    int maxLines = 1,
    TextInputType? keyboardType,
    ValueChanged<String>? onChanged,
  }) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      keyboardType: keyboardType,
      onChanged: onChanged,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
        alignLabelWithHint: maxLines > 1,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
      ),
    );
  }

  Widget _dropdown(String label, String value, List<String> options, ValueChanged<String> onChanged) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.w800)),
        const SizedBox(height: 7),
        DropdownButtonFormField<String>(
          value: value,
          isExpanded: true,
          decoration: InputDecoration(border: OutlineInputBorder(borderRadius: BorderRadius.circular(16))),
          items: options.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
          onChanged: (v) {
            if (v != null) onChanged(v);
          },
        ),
      ],
    );
  }
}

class CoachPage extends StatefulWidget {
  final AnalysisResult result;
  const CoachPage({super.key, required this.result});

  @override
  State<CoachPage> createState() => _CoachPageState();
}

class _CoachPageState extends State<CoachPage> {
  final pageController = PageController();
  int page = 0;

  void showReport() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => ResultPage(result: widget.result)),
    );
  }

  void next() {
    if (page >= widget.result.lessons.length - 1) {
      showReport();
    } else {
      pageController.nextPage(duration: const Duration(milliseconds: 280), curve: Curves.easeOut);
    }
  }

  @override
  void dispose() {
    pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final total = widget.result.lessons.length;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Tutorial da análise'),
        actions: [TextButton(onPressed: showReport, child: const Text('Pular'))],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 10, 18, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Missão ${page + 1} de $total', style: const TextStyle(fontWeight: FontWeight.w900)),
                const SizedBox(height: 8),
                LinearProgressIndicator(value: (page + 1) / total, minHeight: 8, borderRadius: BorderRadius.circular(99)),
              ],
            ),
          ),
          Expanded(
            child: PageView.builder(
              controller: pageController,
              itemCount: total,
              onPageChanged: (v) => setState(() => page = v),
              itemBuilder: (_, i) => LessonView(lesson: widget.result.lessons[i]),
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(18, 8, 18, 16),
              child: FilledButton.icon(
                onPressed: next,
                icon: Icon(page == total - 1 ? Icons.flag : Icons.arrow_forward),
                label: Text(page == total - 1 ? 'VER RELATÓRIO COMPLETO' : 'ENTENDI, PRÓXIMO'),
                style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class LessonView extends StatelessWidget {
  final GuidedLesson lesson;
  const LessonView({super.key, required this.lesson});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(18),
      children: [
        Icon(lesson.icon, size: 58, color: Theme.of(context).colorScheme.primary),
        const SizedBox(height: 12),
        Text(lesson.title, textAlign: TextAlign.center, style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900)),
        const SizedBox(height: 20),
        BeforeAfterBox(current: lesson.current, optimized: lesson.optimized),
        const SizedBox(height: 14),
        InfoBox(icon: Icons.help_outline, title: 'Por que isso importa?', text: lesson.why),
        const SizedBox(height: 12),
        InfoBox(icon: Icons.build_outlined, title: 'Como melhorar', text: lesson.how),
        if (lesson.canCopy) ...[
          const SizedBox(height: 14),
          OutlinedButton.icon(
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: lesson.optimized));
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Versão otimizada copiada.')));
              }
            },
            icon: const Icon(Icons.copy),
            label: const Text('Copiar solução otimizada'),
          ),
        ],
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
          const SizedBox(height: 12),
          FilledButton.tonalIcon(
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => CoachPage(result: result))),
            icon: const Icon(Icons.school_outlined),
            label: const Text('Rever tutorial passo a passo'),
          ),
          const SizedBox(height: 20),
          Text('Soluções prontas', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900)),
          const SizedBox(height: 10),
          SolutionCard(
            icon: Icons.title,
            title: 'Título',
            current: result.input.title,
            optimized: result.optimizedTitle,
          ),
          const SizedBox(height: 10),
          SolutionCard(
            icon: Icons.description_outlined,
            title: 'Descrição',
            current: result.input.description.isEmpty ? 'Não informada' : result.input.description,
            optimized: result.optimizedDescription,
          ),
          const SizedBox(height: 10),
          SolutionCard(
            icon: Icons.category_outlined,
            title: 'Categoria',
            current: result.input.category.isEmpty ? 'Não informada' : result.input.category,
            optimized: result.suggestedCategory,
          ),
          const SizedBox(height: 20),
          Text('Concorrência e preço', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900)),
          const SizedBox(height: 10),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.groups_outlined),
                      const SizedBox(width: 8),
                      Text('${result.input.competitors.length} concorrente(s) informado(s)', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 17)),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(result.priceInsight),
                  if (result.competitorMedian != null) ...[
                    const SizedBox(height: 10),
                    Text('Mediana dos preços: ${money(result.competitorMedian!)}', style: const TextStyle(fontWeight: FontWeight.w800)),
                  ],
                  if (result.input.competitors.isNotEmpty) ...[
                    const Divider(height: 28),
                    for (final c in result.input.competitors)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Row(
                          children: [
                            const Icon(Icons.storefront_outlined, size: 18),
                            const SizedBox(width: 8),
                            Expanded(child: Text(c.title.isEmpty ? 'Concorrente' : c.title)),
                            if (c.price != null) Text(money(c.price!), style: const TextStyle(fontWeight: FontWeight.w800)),
                          ],
                        ),
                      ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          Text('Prioridades', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900)),
          const SizedBox(height: 10),
          for (var i = 0; i < result.suggestions.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Card(
                child: ListTile(
                  leading: CircleAvatar(child: Text('${i + 1}')),
                  title: Text(result.suggestions[i], style: const TextStyle(fontWeight: FontWeight.w700)),
                ),
              ),
            ),
          const SizedBox(height: 14),
          Text(
            'Observação: esta versão usa os dados informados por você para gerar as otimizações. Ela ainda não altera o anúncio automaticamente na Shopee.',
            style: Theme.of(context).textTheme.bodySmall,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class SolutionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String current;
  final String optimized;
  const SolutionCard({super.key, required this.icon, required this.title, required this.current, required this.optimized});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(icon),
                const SizedBox(width: 8),
                Text(title, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18)),
              ],
            ),
            const SizedBox(height: 14),
            BeforeAfterBox(current: current, optimized: optimized),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: () async {
                await Clipboard.setData(ClipboardData(text: optimized));
                if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$title otimizado copiado.')));
              },
              icon: const Icon(Icons.copy),
              label: const Text('Copiar otimizado'),
            ),
          ],
        ),
      ),
    );
  }
}

class BeforeAfterBox extends StatelessWidget {
  final String current;
  final String optimized;
  const BeforeAfterBox({super.key, required this.current, required this.optimized});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(color: cs.surfaceContainerHighest.withValues(alpha: .55), borderRadius: BorderRadius.circular(16)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('ATUAL', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900)),
              const SizedBox(height: 6),
              SelectableText(current),
            ],
          ),
        ),
        const SizedBox(height: 9),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(color: cs.primaryContainer.withValues(alpha: .55), borderRadius: BorderRadius.circular(16)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [Icon(Icons.auto_awesome, size: 16, color: cs.primary), const SizedBox(width: 6), const Text('OTIMIZADO', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900))]),
              const SizedBox(height: 6),
              SelectableText(optimized),
            ],
          ),
        ),
      ],
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
            const SizedBox(height: 14),
            Expanded(
              child: history.isEmpty
                  ? const Center(child: Text('Suas análises desta sessão aparecerão aqui.'))
                  : ListView.separated(
                      itemCount: history.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (_, i) {
                        final r = history[i];
                        return Card(
                          child: ListTile(
                            leading: CircleAvatar(child: Text('${r.score}')),
                            title: Text(r.input.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w800)),
                            subtitle: Text(r.input.url, maxLines: 1, overflow: TextOverflow.ellipsis),
                            trailing: const Icon(Icons.chevron_right),
                            onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => ResultPage(result: r))),
                          ),
                        );
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
      ('Primeira análise', 'Complete 1 análise', analysisCount >= 1, Icons.bolt),
      ('Otimização em série', 'Complete 3 análises', analysisCount >= 3, Icons.rocket_launch),
      ('Caçador de anúncios', 'Complete 10 análises', analysisCount >= 10, Icons.emoji_events),
    ];
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(18),
        children: [
          Text('Conquistas', style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w900)),
          const SizedBox(height: 14),
          for (final item in items)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Card(
                child: ListTile(
                  leading: CircleAvatar(child: Icon(item.$4)),
                  title: Text(item.$1, style: const TextStyle(fontWeight: FontWeight.w800)),
                  subtitle: Text(item.$2),
                  trailing: Icon(item.$3 ? Icons.check_circle : Icons.lock_outline, color: item.$3 ? Colors.green : null),
                ),
              ),
            ),
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
          const SizedBox(height: 14),
          Card(
            child: SwitchListTile(
              value: darkMode,
              onChanged: onDarkModeChanged,
              secondary: const Icon(Icons.dark_mode_outlined),
              title: const Text('Modo escuro', style: TextStyle(fontWeight: FontWeight.w800)),
            ),
          ),
          const SizedBox(height: 12),
          const Card(
            child: ListTile(
              leading: Icon(Icons.info_outline),
              title: Text('Super Anúncio 1.1.0', style: TextStyle(fontWeight: FontWeight.w800)),
              subtitle: Text('Análise guiada + soluções atuais/otimizadas + concorrentes.'),
            ),
          ),
        ],
      ),
    );
  }
}

class InfoBox extends StatelessWidget {
  final IconData icon;
  final String title;
  final String text;
  const InfoBox({super.key, required this.icon, required this.title, required this.text});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: cs.primaryContainer.withValues(alpha: .45),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: cs.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.w900)),
                const SizedBox(height: 4),
                Text(text),
              ],
            ),
          ),
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
    return Chip(avatar: Icon(icon, size: 18), label: Text(text));
  }
}

class SaShield extends StatelessWidget {
  final double size;
  const SaShield({super.key, required this.size});

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: size,
      child: CustomPaint(painter: ShieldPainter()),
    );
  }
}

class ShieldPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final shadow = Paint()..color = Colors.black.withValues(alpha: .22);
    final border = Paint()..color = const Color(0xFFC78908);
    final gold = Paint()..color = const Color(0xFFFFC62B);
    final path = Path()
      ..moveTo(w * .18, h * .22)
      ..lineTo(w * .82, h * .22)
      ..lineTo(w * .77, h * .72)
      ..quadraticBezierTo(w * .5, h * .92, w * .23, h * .72)
      ..close();
    canvas.save();
    canvas.translate(0, h * .05);
    canvas.drawPath(path, shadow);
    canvas.restore();
    canvas.drawPath(path, border);
    final inner = Path()
      ..moveTo(w * .26, h * .3)
      ..lineTo(w * .74, h * .3)
      ..lineTo(w * .7, h * .67)
      ..quadraticBezierTo(w * .5, h * .81, w * .3, h * .67)
      ..close();
    canvas.drawPath(inner, gold);
    final badge = Paint()..color = const Color(0xFFFFD94B);
    canvas.drawCircle(Offset(w * .5, h * .15), w * .12, badge);
    final star = Paint()..color = const Color(0xFFFF5A1F);
    final starPath = Path();
    for (var i = 0; i < 10; i++) {
      final r = i.isEven ? w * .07 : w * .03;
      final a = -math.pi / 2 + i * math.pi / 5;
      final p = Offset(w * .5 + math.cos(a) * r, h * .15 + math.sin(a) * r);
      if (i == 0) {
        starPath.moveTo(p.dx, p.dy);
      } else {
        starPath.lineTo(p.dx, p.dy);
      }
    }
    starPath.close();
    canvas.drawPath(starPath, star);
    final tp = TextPainter(
      text: TextSpan(
        text: 'SA',
        style: TextStyle(color: Colors.lightBlueAccent.shade700, fontWeight: FontWeight.w900, fontSize: w * .36, shadows: const [Shadow(color: Colors.black38, offset: Offset(2, 3))]),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset((w - tp.width) / 2, h * .37));
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class SuperAnuncioLogo extends StatelessWidget {
  final double fontSize;
  const SuperAnuncioLogo({super.key, required this.fontSize});

  @override
  Widget build(BuildContext context) {
    const letters = [
      ('S', Color(0xFF17A8F5)),
      ('U', Color(0xFFE94235)),
      ('P', Color(0xFFFFC928)),
      ('E', Color(0xFF20B95A)),
      ('R', Color(0xFFFFB21A)),
      (' ', Colors.transparent),
      ('A', Color(0xFFE94235)),
      ('N', Color(0xFFFFC928)),
      ('Ú', Color(0xFF17A8F5)),
      ('N', Color(0xFF20B95A)),
      ('C', Color(0xFFFFB21A)),
      ('I', Color(0xFFE94235)),
      ('O', Color(0xFF20B95A)),
    ];
    return FittedBox(
      fit: BoxFit.scaleDown,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: letters
            .map((e) => Text(
                  e.$1,
                  style: TextStyle(
                    color: e.$2,
                    fontSize: fontSize,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1,
                    shadows: const [Shadow(color: Colors.black45, offset: Offset(2, 3))],
                  ),
                ))
            .toList(),
      ),
    );
  }
}

class AnalysisInput {
  final String url;
  final String title;
  final String description;
  final String category;
  final double? price;
  final String goal;
  final String stage;
  final String issue;
  final List<CompetitorData> competitors;

  const AnalysisInput({
    required this.url,
    required this.title,
    required this.description,
    required this.category,
    required this.price,
    required this.goal,
    required this.stage,
    required this.issue,
    required this.competitors,
  });
}

class CompetitorData {
  final String title;
  final double? price;
  final String link;
  const CompetitorData({required this.title, required this.price, required this.link});
}

class GuidedLesson {
  final String title;
  final IconData icon;
  final String current;
  final String optimized;
  final String why;
  final String how;
  final bool canCopy;

  const GuidedLesson({
    required this.title,
    required this.icon,
    required this.current,
    required this.optimized,
    required this.why,
    required this.how,
    this.canCopy = true,
  });
}

class AnalysisResult {
  final AnalysisInput input;
  final int score;
  final String summary;
  final String optimizedTitle;
  final String optimizedDescription;
  final String suggestedCategory;
  final double? competitorMedian;
  final String priceInsight;
  final List<String> suggestions;
  final List<GuidedLesson> lessons;

  const AnalysisResult({
    required this.input,
    required this.score,
    required this.summary,
    required this.optimizedTitle,
    required this.optimizedDescription,
    required this.suggestedCategory,
    required this.competitorMedian,
    required this.priceInsight,
    required this.suggestions,
    required this.lessons,
  });

  factory AnalysisResult.build(AnalysisInput input) {
    final optimizedTitle = optimizeTitle(input.title, input.category);
    final optimizedDescription = optimizeDescription(input.title, input.description);
    final suggestedCategory = suggestCategory(input.title, input.category);
    final median = medianPrice(input.competitors);
    final priceInsight = buildPriceInsight(input.price, median, input.competitors.length);

    var score = 35;
    final titleLen = input.title.trim().length;
    if (titleLen >= 35 && titleLen <= 110) {
      score += 18;
    } else if (titleLen >= 20) {
      score += 10;
    } else {
      score += 4;
    }
    final descLen = input.description.trim().length;
    if (descLen >= 300) {
      score += 18;
    } else if (descLen >= 120) {
      score += 12;
    } else if (descLen > 0) {
      score += 5;
    }
    if (input.category.trim().isNotEmpty) score += 10;
    if (input.price != null && input.price! > 0) score += 7;
    if (input.competitors.length >= 2) {
      score += 12;
    } else if (input.competitors.length == 1) {
      score += 5;
    }
    score = score.clamp(0, 100);

    final summary = score >= 80
        ? 'Boa base. Agora o foco é ganhar clareza, diferenciação e consistência contra os concorrentes.'
        : score >= 60
            ? 'Há uma base utilizável, mas alguns pontos ainda podem estar reduzindo descoberta e conversão.'
            : 'O anúncio precisa de ajustes importantes antes de competir melhor. A boa notícia: abaixo já estão as mudanças prioritárias.';

    final suggestions = <String>[
      if (optimizedTitle != input.title) 'Trocar o título atual pela versão otimizada e manter apenas termos realmente ligados ao produto.',
      if (input.description.length < 300) 'Estruturar a descrição para responder dúvidas práticas antes da compra.',
      if (suggestedCategory != input.category) 'Revisar a categoria e priorizar a subcategoria mais específica para o produto.',
      if (input.competitors.length < 2) 'Mapear pelo menos 2 concorrentes equivalentes para calibrar preço e posicionamento.',
      priceInsight,
    ];

    final competitorCurrent = input.competitors.isEmpty
        ? 'Nenhum concorrente registrado.'
        : '${input.competitors.length} concorrente(s) registrado(s)${median == null ? '' : ', mediana ${money(median)}'}.';

    final lessons = <GuidedLesson>[
      GuidedLesson(
        title: 'Título que explica e encontra',
        icon: Icons.title,
        current: input.title,
        optimized: optimizedTitle,
        why: 'O título precisa ajudar a pessoa a reconhecer o produto rapidamente e também concentrar os termos principais da busca. Repetição, excesso de símbolos e palavras vagas atrapalham leitura.',
        how: 'Use produto + característica principal + modelo/uso quando isso existir de verdade. Evite inventar atributos. O app remove repetições e organiza o que você informou.',
      ),
      GuidedLesson(
        title: 'Descrição que tira dúvidas',
        icon: Icons.description_outlined,
        current: input.description.isEmpty ? 'Descrição não informada.' : input.description,
        optimized: optimizedDescription,
        why: 'Uma descrição clara reduz dúvidas antes da compra. O objetivo não é encher de texto, e sim organizar as informações que o cliente precisa conferir.',
        how: 'Mantenha o que já é verdadeiro e complete os campos marcados entre colchetes. Assim você melhora o anúncio sem inventar especificações.',
      ),
      GuidedLesson(
        title: 'Categoria certa, público certo',
        icon: Icons.category_outlined,
        current: input.category.isEmpty ? 'Categoria não informada.' : input.category,
        optimized: suggestedCategory,
        why: 'Categoria influencia filtros, navegação e o tipo de concorrente com quem o anúncio é comparado. Uma categoria ampla demais pode misturar o produto com itens que não são equivalentes.',
        how: 'Use a categoria mais específica que descreva o produto. A sugestão local abaixo é um ponto de partida e deve ser validada na árvore de categorias da Shopee.',
      ),
      GuidedLesson(
        title: 'Concorrentes antes de mexer no preço',
        icon: Icons.groups_outlined,
        current: competitorCurrent,
        optimized: priceInsight,
        why: 'Preço sozinho não diz se o anúncio está caro ou barato. É preciso comparar com produtos realmente equivalentes, não com qualquer resultado da busca.',
        how: 'Compare pelo menos 2 ou 3 itens parecidos em produto, proposta, quantidade e condição. Use a mediana como referência e só depois decida se o problema é preço ou valor percebido.',
        canCopy: false,
      ),
    ];

    return AnalysisResult(
      input: input,
      score: score,
      summary: summary,
      optimizedTitle: optimizedTitle,
      optimizedDescription: optimizedDescription,
      suggestedCategory: suggestedCategory,
      competitorMedian: median,
      priceInsight: priceInsight,
      suggestions: suggestions,
      lessons: lessons,
    );
  }
}

String optimizeTitle(String raw, String category) {
  var cleaned = raw
      .replaceAll(RegExp(r'[|_/\\]+'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
  final seen = <String>{};
  final words = <String>[];
  for (final word in cleaned.split(' ')) {
    final key = word.toLowerCase();
    if (key.length <= 1 || seen.add(key)) words.add(word);
  }
  cleaned = words.join(' ');

  String cap(String w) {
    if (w.isEmpty) return w;
    if (RegExp(r'^[A-Z0-9-]{2,}$').hasMatch(w)) return w;
    return '${w[0].toUpperCase()}${w.substring(1).toLowerCase()}';
  }

  var result = cleaned.split(' ').map(cap).join(' ');
  final categoryTail = category.split('>').last.trim();
  if (categoryTail.isNotEmpty && !result.toLowerCase().contains(categoryTail.toLowerCase()) && result.length < 85) {
    result = '$result - $categoryTail';
  }
  if (result.length > 115) result = result.substring(0, 115).trim();
  return result;
}

String optimizeDescription(String title, String current) {
  final body = current.trim().isEmpty ? 'Descreva aqui os principais detalhes reais do produto.' : current.trim();
  return '''${title.trim()}

$body

INFORMAÇÕES IMPORTANTES
• Material: [preencher]
• Medidas/tamanho: [preencher]
• Conteúdo da embalagem: [preencher]
• Compatibilidade ou variações: [preencher]

ANTES DE COMPRAR
Confira as medidas, variações e compatibilidade informadas no anúncio.''';
}

String suggestCategory(String title, String current) {
  final t = title.toLowerCase();
  if (RegExp(r'caderno|colorir|agenda|planner|papelaria').hasMatch(t)) return 'Papelaria > Cadernos e Blocos';
  if (RegExp(r'fone|carregador|cabo usb|película|pelicula|capa celular|smartphone').hasMatch(t)) return 'Celulares e Acessórios > Acessórios';
  if (RegExp(r'controle remoto|adaptador|bluetooth|hdmi').hasMatch(t)) return 'Eletrônicos > Acessórios e Peças';
  if (RegExp(r'camiseta|blusa|vestido|calça|calca|short|bermuda').hasMatch(t)) return 'Moda > Roupas';
  if (RegExp(r'brinquedo|boneca|carrinho|lego|quebra-cabeça|quebra cabeca').hasMatch(t)) return 'Brinquedos e Hobbies';
  if (RegExp(r'panela|cozinha|pote|organizador|casa').hasMatch(t)) return 'Casa e Decoração';
  if (current.trim().isNotEmpty) return current.trim();
  return 'Validar a subcategoria mais específica na Shopee';
}

double? medianPrice(List<CompetitorData> competitors) {
  final prices = competitors.map((e) => e.price).whereType<double>().where((e) => e > 0).toList()..sort();
  if (prices.isEmpty) return null;
  final middle = prices.length ~/ 2;
  if (prices.length.isOdd) return prices[middle];
  return (prices[middle - 1] + prices[middle]) / 2;
}

String buildPriceInsight(double? own, double? median, int competitors) {
  if (competitors == 0) return 'Cadastre 2 ou 3 concorrentes equivalentes antes de tomar uma decisão de preço.';
  if (median == null) return 'Os concorrentes foram registrados, mas faltam preços para calcular uma referência.';
  if (own == null || own <= 0) return 'A mediana dos concorrentes é ${money(median)}. Informe seu preço para comparar a posição do anúncio.';
  final diff = ((own - median) / median) * 100;
  if (diff.abs() <= 5) return 'Seu preço está alinhado com a mediana dos concorrentes (${money(median)}). Foque também em título, imagem, descrição e valor percebido.';
  if (diff > 0) return 'Seu preço está aproximadamente ${diff.abs().toStringAsFixed(1)}% acima da mediana (${money(median)}). Antes de baixar, confirme se o anúncio comunica benefícios que justifiquem a diferença.';
  return 'Seu preço está aproximadamente ${diff.abs().toStringAsFixed(1)}% abaixo da mediana (${money(median)}). Isso pode ser competitivo, mas confira margem e percepção de qualidade antes de reduzir mais.';
}

String money(double value) => 'R\$ ${value.toStringAsFixed(2).replaceAll('.', ',')}';
