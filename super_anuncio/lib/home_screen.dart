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
  PersistedAppState appState = PersistedAppState();
  bool stateLoaded = false;
  bool shopeeChecked = false;
  bool shopeeConnected = false;
  bool skippedConnectionThisSession = false;

  @override
  void initState() {
    super.initState();
    _initShareReceiver();
    _loadShopeeState();
    _loadState();
  }

  Future<void> _loadState() async {
    final loaded = await AppStore.load();
    if (!mounted) return;
    setState(() {
      appState = loaded;
      stateLoaded = true;
    });
  }

  Future<void> _persist() => AppStore.save(appState);

  Future<void> _loadShopeeState() async {
    final value = await ShopeeSession.savedConnected();
    if (!mounted) return;
    setState(() {
      shopeeConnected = value;
      shopeeChecked = true;
    });
  }

  Future<void> _setShopeeConnected(bool value) async {
    await ShopeeSession.saveConnected(value);
    if (!mounted) return;
    setState(() {
      shopeeConnected = value;
      shopeeChecked = true;
      if (value) skippedConnectionThisSession = false;
    });
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
        if (!mounted) return;
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
      if (value != null && value.trim().isNotEmpty && mounted) setState(() => sharedText = value);
    } catch (_) {}
    try {
      final reminder = await kShareChannel.invokeMethod<dynamic>('initialReanalysis');
      _openReminder(reminder);
    } catch (_) {}
  }

  void _onGenerated(AnalysisResult result, String? previousAnalysisId) {
    final stored = StoredAnalysis.fromResult(result);
    final key = productHistoryKey(result);
    ProductHistoryRecord? record;
    for (final p in appState.products) {
      if (p.key == key) {
        record = p;
        break;
      }
    }
    record ??= ProductHistoryRecord(
      key: key,
      url: result.input.url,
      title: result.input.title,
      imageUrl: result.input.product?.imageUrl,
    );
    if (!appState.products.contains(record)) appState.products.add(record);
    record.url = result.input.url;
    record.title = result.input.title;
    record.imageUrl = result.input.product?.imageUrl ?? record.imageUrl;
    record.analyses.add(stored);

    if (previousAnalysisId != null && previousAnalysisId.isNotEmpty) {
      for (final task in appState.tasks) {
        if (!task.completed && task.sourceAnalysisId == previousAnalysisId) {
          task.completedAt = DateTime.now();
          task.completedAnalysisId = stored.id;
          break;
        }
      }
    }

    if (mounted) setState(() {});
    _persist();
  }

  Future<List<AchievementDef>> _finalize(AnalysisResult result) async {
    if (result.finalized) return const [];
    final before = Set<int>.from(appState.unlockedAchievements);
    final now = DateTime.now();
    final stored = findStoredForResult(appState, result);
    final product = findProductForAnalysis(appState, result);

    setState(() {
      result.finalized = true;
      result.reanalyzeAt = now.add(const Duration(days: 7));
      appState.finalizedAnalyses += 1;
      appState.competitorSelections += result.competitors.length;
      if (result.input.adsActive) appState.adsAnalyses += 1;
      if (result.score > appState.bestScore) appState.bestScore = result.score;
      appState.unlockedAchievements.addAll(AchievementEngine.unlockedIds(
        finalizedAnalyses: appState.finalizedAnalyses,
        competitorSelections: appState.competitorSelections,
        adsAnalyses: appState.adsAnalyses,
        bestScore: appState.bestScore,
      ));

      if (stored != null && product != null && !appState.tasks.any((t) => !t.completed && t.sourceAnalysisId == stored.id)) {
        appState.tasks.add(ReanalysisTask(
          id: 'task_${stored.id}_${now.microsecondsSinceEpoch}',
          productKey: product.key,
          sourceAnalysisId: stored.id,
          title: result.input.title,
          url: result.input.url,
          dueAt: result.reanalyzeAt!,
        ));
      }
    });

    await _persist();
    final newIds = appState.unlockedAchievements.difference(before);
    return AchievementEngine.all.where((a) => newIds.contains(a.id)).toList();
  }

  Future<void> _deleteProductForResult(AnalysisResult result) async {
    final product = findProductForAnalysis(appState, result);
    if (product == null) return;
    setState(() {
      appState.products.remove(product);
      appState.tasks.removeWhere((t) => t.productKey == product.key);
    });
    await _persist();
  }

  void _dismissGameHint() {
    setState(() => appState.gameHintDismissed = true);
    _persist();
  }

  void _unlockSecret(Set<int> ids) {
    final fresh = ids.difference(appState.unlockedAchievements);
    if (fresh.isEmpty) return;
    setState(() => appState.unlockedAchievements.addAll(ids));
    _persist();
  }

  void _openGame() {
    _unlockSecret({101});
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => SaArcadePage(
        highScore: appState.gameHighScore,
        onHighScore: (score) {
          if (score <= appState.gameHighScore) return;
          setState(() => appState.gameHighScore = score);
          _persist();
        },
        onUnlock: _unlockSecret,
      ),
    ));
  }

  @override
  Widget build(BuildContext context) {
    if (!shopeeChecked || !stateLoaded) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (!shopeeConnected && !skippedConnectionThisSession) {
      return ShopeeFirstUseGate(
        onConnected: () async => _setShopeeConnected(true),
        onSkip: () => setState(() => skippedConnectionThisSession = true),
      );
    }

    final pages = [
      AnalyzerHome(
        sharedText: sharedText,
        shopeeConnected: shopeeConnected,
        onShopeeConnectionChanged: _setShopeeConnected,
        onGenerated: _onGenerated,
        onFinalize: _finalize,
        onOpenGame: _openGame,
        showGameHint: appState.finalizedAnalyses >= 3 && !appState.gameHintDismissed,
        onDismissGameHint: _dismissGameHint,
      ),
      HistoryPage(
        state: appState,
        onGenerated: _onGenerated,
        onFinalize: _finalize,
        onDeleteProduct: _deleteProductForResult,
      ),
      TasksPage(state: appState, onGenerated: _onGenerated, onFinalize: _finalize),
      AchievementsPage(unlocked: appState.unlockedAchievements),
      SettingsPage(
        darkMode: widget.darkMode,
        onDarkModeChanged: widget.onDarkModeChanged,
        shopeeConnected: shopeeConnected,
        onShopeeConnectionChanged: _setShopeeConnected,
      ),
    ];

    return Scaffold(
      body: IndexedStack(index: index, children: pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: index,
        onDestinationSelected: (value) => setState(() => index = value),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home), label: 'Início'),
          NavigationDestination(icon: Icon(Icons.history), label: 'Histórico'),
          NavigationDestination(icon: Icon(Icons.task_alt_outlined), selectedIcon: Icon(Icons.task_alt), label: 'Tarefas'),
          NavigationDestination(icon: Icon(Icons.emoji_events_outlined), selectedIcon: Icon(Icons.emoji_events), label: 'Conquistas'),
          NavigationDestination(icon: Icon(Icons.settings_outlined), selectedIcon: Icon(Icons.settings), label: 'Ajustes'),
        ],
      ),
    );
  }
}
