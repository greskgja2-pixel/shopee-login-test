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
    final targetDay = now.add(const Duration(days: 7));
    final reanalysisDue = DateTime(targetDay.year, targetDay.month, targetDay.day, 8);
    final stored = findStoredForResult(appState, result);
    final product = findProductForAnalysis(appState, result);

    setState(() {
      result.finalized = true;
      result.reanalyzeAt = reanalysisDue;
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

  Future<void> _exportBackup() async {
    try {
      final payload = <String, dynamic>{
        'format': 'super_anuncio_backup',
        'backupVersion': 1,
        'appVersion': '1.5.10',
        'exportedAt': DateTime.now().toIso8601String(),
        'state': appState.toJson(),
      };
      final cache = await kShareChannel.invokeMethod<String>('cacheDir');
      if (cache == null || cache.isEmpty) throw Exception('Pasta temporária indisponível.');
      final now = DateTime.now();
      String two(int v) => v.toString().padLeft(2, '0');
      final name = 'Super-Anuncio-backup_${now.year}-${two(now.month)}-${two(now.day)}_${two(now.hour)}-${two(now.minute)}.json';
      final file = File('$cache/$name');
      await file.writeAsString(const JsonEncoder.withIndent('  ').convert(payload), flush: true);
      await kShareChannel.invokeMethod('shareFile', {
        'path': file.path,
        'mime': 'application/json',
        'title': 'Salvar backup do Super Anúncio',
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Backup criado. Salve o arquivo em Downloads, Drive ou outro local seguro.'),
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Não foi possível exportar o backup: $e')));
      }
    }
  }

  Future<void> _importBackup() async {
    try {
      final raw = await kShareChannel.invokeMethod<String>('pickBackupFile');
      if (raw == null || raw.trim().isEmpty || !mounted) return;
      final decoded = jsonDecode(raw);
      if (decoded is! Map) throw const FormatException('Arquivo de backup inválido.');
      final map = Map<String, dynamic>.from(decoded);
      dynamic stateRaw;
      if (map['format'] == 'super_anuncio_backup') {
        stateRaw = map['state'];
      } else if (map.containsKey('products') || map.containsKey('tasks')) {
        stateRaw = map;
      } else {
        throw const FormatException('Este arquivo não parece ser um backup do Super Anúncio.');
      }
      final imported = PersistedAppState.fromJson(stateRaw);
      final totalAnalyses = imported.products.fold<int>(0, (sum, p) => sum + p.analyses.length);
      if (imported.products.isEmpty && imported.tasks.isEmpty && totalAnalyses == 0) {
        throw const FormatException('O backup não contém dados para importar.');
      }

      final action = await showDialog<String>(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Como deseja importar?'),
          content: Text(
            'O backup contém ${imported.products.length} produto(s) e $totalAnalyses análise(s).\n\n'
            'Mesclar mantém os dados atuais e adiciona o que estiver faltando. '
            'Substituir apaga os dados locais atuais e usa somente o backup.',
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
            OutlinedButton(onPressed: () => Navigator.pop(context, 'replace'), child: const Text('Substituir')),
            FilledButton(onPressed: () => Navigator.pop(context, 'merge'), child: const Text('Mesclar')),
          ],
        ),
      );
      if (action == null || !mounted) return;

      final next = action == 'replace' ? imported : _mergeImportedState(appState, imported);
      setState(() => appState = next);
      await AppStore.save(appState);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(action == 'replace' ? 'Backup restaurado com sucesso.' : 'Backup mesclado com sucesso.'),
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Não foi possível importar o backup: $e')));
      }
    }
  }

  PersistedAppState _mergeImportedState(PersistedAppState current, PersistedAppState imported) {
    final merged = PersistedAppState.fromJson(current.toJson());
    for (final incoming in imported.products) {
      ProductHistoryRecord? target;
      for (final p in merged.products) {
        if (p.key == incoming.key) {
          target = p;
          break;
        }
      }
      if (target == null) {
        final copy = ProductHistoryRecord.fromJson(incoming.toJson());
        if (copy != null) merged.products.add(copy);
        continue;
      }
      if (incoming.url.isNotEmpty) target.url = incoming.url;
      if (incoming.title.isNotEmpty) target.title = incoming.title;
      target.imageUrl ??= incoming.imageUrl;
      final known = target.analyses.map((a) => a.id).toSet();
      for (final analysis in incoming.analyses) {
        if (known.add(analysis.id)) {
          final copy = StoredAnalysis.fromJson(analysis.toJson());
          if (copy != null) target.analyses.add(copy);
        }
      }
    }

    final taskIds = merged.tasks.map((t) => t.id).toSet();
    for (final task in imported.tasks) {
      if (taskIds.add(task.id)) {
        final copy = ReanalysisTask.fromJson(task.toJson());
        if (copy != null) merged.tasks.add(copy);
      }
    }
    merged.unlockedAchievements.addAll(imported.unlockedAchievements);
    merged.finalizedAnalyses = math.max(merged.finalizedAnalyses, imported.finalizedAnalyses);
    merged.competitorSelections = math.max(merged.competitorSelections, imported.competitorSelections);
    merged.adsAnalyses = math.max(merged.adsAnalyses, imported.adsAnalyses);
    merged.bestScore = math.max(merged.bestScore, imported.bestScore);
    merged.gameHighScore = math.max(merged.gameHighScore, imported.gameHighScore);
    merged.gameHintDismissed = merged.gameHintDismissed || imported.gameHintDismissed;
    return merged;
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
        onExportBackup: _exportBackup,
        onImportBackup: _importBackup,
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
