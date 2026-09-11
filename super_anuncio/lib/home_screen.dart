part of 'main.dart';

class HomePage extends StatefulWidget {
  final bool darkMode;
  final ValueChanged<bool> onDarkModeChanged;
  const HomePage({super.key, required this.darkMode, required this.onDarkModeChanged});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int index = 0;
  String? sharedText;
  final List<AnalysisResult> history = [];
  final Set<int> unlockedAchievements = {};
  int finalizedAnalyses = 0;
  int competitorSelections = 0;
  int adsAnalyses = 0;
  int bestScore = 0;

  @override
  void initState() {
    super.initState();
    _initShareReceiver();
  }

  void _openReminder(dynamic args) {
    if (args is! Map) return;
    final url = '${args['url'] ?? ''}'.trim();
    if (url.isEmpty) return;
    setState(() {
      sharedText = url;
      index = 0;
    });
  }

  Future<void> _initShareReceiver() async {
    kShareChannel.setMethodCallHandler((call) async {
      if (call.method == 'sharedText' && call.arguments is String) {
        setState(() {
          sharedText = call.arguments as String;
          index = 0;
        });
      } else if (call.method == 'reanalysisReminder') {
        _openReminder(call.arguments);
      }
    });
    try {
      final value = await kShareChannel.invokeMethod<String>('initialSharedText');
      if (value != null && value.trim().isNotEmpty) setState(() => sharedText = value);
    } catch (_) {}
    try {
      final reminder = await kShareChannel.invokeMethod<dynamic>('initialReanalysis');
      _openReminder(reminder);
    } catch (_) {}
  }

  void _onGenerated(AnalysisResult result) {
    setState(() => history.insert(0, result));
  }

  Future<List<AchievementDef>> _finalize(AnalysisResult result) async {
    if (result.finalized) return const [];
    final before = Set<int>.from(unlockedAchievements);
    setState(() {
      result.finalized = true;
      result.reanalyzeAt = DateTime.now().add(const Duration(days: 7));
      finalizedAnalyses += 1;
      competitorSelections += result.competitors.length;
      if (result.input.adsActive) adsAnalyses += 1;
      if (result.score > bestScore) bestScore = result.score;
      unlockedAchievements.addAll(AchievementEngine.unlockedIds(
        finalizedAnalyses: finalizedAnalyses,
        competitorSelections: competitorSelections,
        adsAnalyses: adsAnalyses,
        bestScore: bestScore,
      ));
    });
    final newIds = unlockedAchievements.difference(before);
    return AchievementEngine.all.where((a) => newIds.contains(a.id)).toList();
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      AnalyzerHome(
        sharedText: sharedText,
        onGenerated: _onGenerated,
        onFinalize: _finalize,
      ),
      HistoryPage(history: history, onFinalize: _finalize),
      AchievementsPage(unlocked: unlockedAchievements),
      SettingsPage(darkMode: widget.darkMode, onDarkModeChanged: widget.onDarkModeChanged),
    ];

    return Scaffold(
      body: IndexedStack(index: index, children: pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: index,
        onDestinationSelected: (value) => setState(() => index = value),
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
