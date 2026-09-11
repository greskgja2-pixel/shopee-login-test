part of 'main.dart';

class PreparationWizard extends StatefulWidget {
  final String initialUrl;
  final ValueChanged<AnalysisResult> onGenerated;
  final Future<List<AchievementDef>> Function(AnalysisResult) onFinalize;
  const PreparationWizard({super.key, required this.initialUrl, required this.onGenerated, required this.onFinalize});

  @override
  State<PreparationWizard> createState() => _PreparationWizardState();
}

class _PreparationWizardState extends State<PreparationWizard> {
  int step = 0;
  bool loadingProduct = true;
  bool loadingCompetitors = false;
  String? autoError;
  ShopeeProductData? autoProduct;
  final title = TextEditingController();
  final description = TextEditingController();
  final category = TextEditingController();
  final price = TextEditingController();
  String goal = 'Vender mais';
  String stage = 'Já vende';
  String issue = 'Poucas visitas';
  bool adsActive = false;
  final roas = TextEditingController();
  final adsSpend = TextEditingController();
  List<CompetitorCandidate> candidates = [];
  final Set<String> selectedIds = {};
  final List<CompetitorCandidate> manualCompetitors = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadProduct());
  }

  Future<void> _loadProduct() async {
    if (!mounted) return;
    setState(() {
      loadingProduct = true;
      autoError = null;
    });
    try {
      final product = await ShopeeWebCollectorV2.collectProduct(context, widget.initialUrl);
      if (!mounted) return;
      if (product == null || product.title.trim().isEmpty) {
        setState(() {
          autoError = 'Não consegui identificar o produto real na Shopee. Para evitar informações erradas, nenhum dado genérico foi importado.';
          loadingProduct = false;
        });
        return;
      }
      setState(() {
        autoProduct = product;
        title.text = product.title;
        description.text = product.description;
        category.text = product.category;
        if (product.price != null) price.text = product.price!.toStringAsFixed(2).replaceAll('.', ',');
        loadingProduct = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        autoError = 'A leitura automática foi interrompida. O app não vai preencher dados até confirmar o produto correto.';
        loadingProduct = false;
      });
    }
  }

  Future<void> _searchCompetitors() async {
    if (title.text.trim().isEmpty || !mounted) return;
    setState(() {
      loadingCompetitors = true;
      candidates = [];
      selectedIds.clear();
    });
    try {
      final found = await ShopeeWebCollectorV2.searchCompetitors(context, title.text.trim(), ownItemId: autoProduct?.itemId);
      if (!mounted) return;
      setState(() {
        candidates = found.take(15).toList();
        loadingCompetitors = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => loadingCompetitors = false);
    }
  }

  Future<void> _manualCompetitor() async {
    final result = await showDialog<CompetitorCandidate>(context: context, builder: (_) => const ManualCompetitorDialog());
    if (result != null && mounted) {
      setState(() {
        manualCompetitors.add(result);
        selectedIds.add(result.key);
      });
    }
  }

  void _next() {
    if (step == 0 && title.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Preciso pelo menos do título do anúncio.')));
      return;
    }
    if (step == 1) {
      setState(() => step = 2);
      _searchCompetitors();
      return;
    }
    setState(() => step += 1);
  }

  void _back() {
    if (step == 0) {
      Navigator.pop(context);
    } else {
      setState(() => step -= 1);
    }
  }

  Future<void> _generate() async {
    final selected = <CompetitorCandidate>[
      ...candidates.where((c) => selectedIds.contains(c.key)),
      ...manualCompetitors.where((c) => selectedIds.contains(c.key)),
    ].take(3).toList();
    final input = AnalysisInput(
      url: widget.initialUrl,
      title: title.text.trim(),
      description: description.text.trim(),
      category: category.text.trim(),
      price: parseMoney(price.text),
      goal: goal,
      stage: stage,
      issue: issue,
      adsActive: adsActive,
      roas7d: adsActive ? parseNumber(roas.text) : null,
      adsSpend7d: adsActive ? parseMoney(adsSpend.text) : null,
      product: autoProduct,
      competitors: selected,
    );

    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const AlertDialog(
        content: Row(children: [CircularProgressIndicator(), SizedBox(width: 18), Expanded(child: Text('Gemini está comparando seu anúncio com os concorrentes e montando as soluções...'))]),
      ),
    );

    final intelligent = await GeminiService.analyze(input);
    final result = intelligent ?? AnalysisResult.build(input);
    if (!mounted) return;
    Navigator.of(context, rootNavigator: true).pop();
    widget.onGenerated(result);
    await Navigator.of(context).pushReplacement(MaterialPageRoute(
      builder: (_) => ResultPage(result: result, onFinalize: widget.onFinalize),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(onPressed: _back, icon: const Icon(Icons.arrow_back)),
        title: Text('Preparando análise • ${step + 1}/3'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(5),
          child: LinearProgressIndicator(value: (step + 1) / 3, minHeight: 5),
        ),
      ),
      body: IndexedStack(index: step, children: [_stepProduct(), _stepGoals(), _stepCompetitors()]),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(18, 8, 18, 14),
        child: Row(
          children: [
            if (step > 0) ...[
              Expanded(child: OutlinedButton(onPressed: _back, child: const Text('Voltar'))),
              const SizedBox(width: 12),
            ],
            Expanded(
              flex: 2,
              child: FilledButton(
                onPressed: loadingProduct ? null : (step == 2 ? _generate : _next),
                child: Text(step == 2 ? 'GERAR ANÁLISE' : 'Continuar'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _stepProduct() {
    if (loadingProduct) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(30),
          child: Column(mainAxisSize: MainAxisSize.min, children: [CircularProgressIndicator(), SizedBox(height: 16), Text('Preparando leitura do anúncio...')]),
        ),
      );
    }
    return ListView(
      padding: const EdgeInsets.all(18),
      children: [
        Text('Primeiro, eu leio o anúncio', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900)),
        const SizedBox(height: 8),
        Text(autoProduct != null ? 'Produto real identificado na Shopee. Confira e corrija apenas se algo estiver diferente.' : 'A leitura automática não confirmou o produto. Nenhum dado genérico será usado.'),
        if (autoError != null) ...[
          const SizedBox(height: 12),
          NoticeBox(icon: Icons.warning_amber_rounded, text: autoError!),
          const SizedBox(height: 8),
          OutlinedButton.icon(onPressed: _loadProduct, icon: const Icon(Icons.refresh), label: const Text('Tentar leitura automática novamente')),
        ],
        if (autoProduct?.imageUrl != null) ...[
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: AspectRatio(aspectRatio: 16 / 9, child: Image.network(autoProduct!.imageUrl!, fit: BoxFit.contain, errorBuilder: (_, __, ___) => const SizedBox.shrink())),
          ),
        ],
        const SizedBox(height: 16),
        InputBox(controller: title, label: 'Título atual *', icon: Icons.title),
        const SizedBox(height: 12),
        InputBox(controller: description, label: 'Descrição atual', icon: Icons.description_outlined, maxLines: 6),
        const SizedBox(height: 12),
        InputBox(controller: category, label: 'Categoria atual', icon: Icons.category_outlined),
        const SizedBox(height: 12),
        InputBox(controller: price, label: 'Preço atual', icon: Icons.attach_money, keyboardType: TextInputType.number),
        if (autoProduct != null) ...[
          const SizedBox(height: 16),
          AutoFacts(product: autoProduct!),
        ],
      ],
    );
  }

  Widget _stepGoals() {
    return ListView(
      padding: const EdgeInsets.all(18),
      children: [
        Text('Contexto da análise', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900)),
        const SizedBox(height: 8),
        const Text('Essas perguntas ajudam a Gemini a separar problema de tráfego de problema de conversão.'),
        const SizedBox(height: 18),
        DropdownButtonFormField<String>(initialValue: goal, decoration: inputDecoration('Principal objetivo', Icons.flag_outlined), items: ['Vender mais', 'Melhorar anúncio', 'Aumentar visitas'].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(), onChanged: (v) => setState(() => goal = v!)),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(initialValue: stage, decoration: inputDecoration('Como está o produto?', Icons.trending_up), items: ['Ainda não vende', 'Já vende', 'Vende bem'].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(), onChanged: (v) => setState(() => stage = v!)),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(initialValue: issue, decoration: inputDecoration('Maior problema hoje', Icons.report_problem_outlined), items: ['Poucas visitas', 'Poucas vendas', 'Muita concorrência', 'Preço'].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(), onChanged: (v) => setState(() => issue = v!)),
        const SizedBox(height: 18),
        Card(
          child: SwitchListTile(
            value: adsActive,
            onChanged: (v) => setState(() => adsActive = v),
            title: const Text('Este anúncio está com Ads ativo?', style: TextStyle(fontWeight: FontWeight.w800)),
            subtitle: const Text('Opcional. Se estiver, use os dados dos últimos 7 dias.'),
          ),
        ),
        if (adsActive) ...[
          const SizedBox(height: 12),
          InputBox(controller: roas, label: 'ROAS dos últimos 7 dias', icon: Icons.query_stats, keyboardType: const TextInputType.numberWithOptions(decimal: true)),
          const SizedBox(height: 12),
          InputBox(controller: adsSpend, label: 'Gasto com Ads nos últimos 7 dias', icon: Icons.payments_outlined, keyboardType: const TextInputType.numberWithOptions(decimal: true)),
        ],
      ],
    );
  }

  Widget _stepCompetitors() {
    final all = [...candidates, ...manualCompetitors];
    return ListView(
      padding: const EdgeInsets.all(18),
      children: [
        Row(
          children: [
            Expanded(child: Text('Escolha até 3 concorrentes', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900))),
            Text('${selectedIds.length}/3', style: const TextStyle(fontWeight: FontWeight.w900)),
          ],
        ),
        const SizedBox(height: 8),
        const Text('A busca é feita dentro da Shopee usando o título real do seu anúncio. Só resultados com ID de produto confirmado entram na lista.'),
        const SizedBox(height: 14),
        if (loadingCompetitors) const LinearProgressIndicator(),
        if (!loadingCompetitors && candidates.isEmpty)
          NoticeBox(icon: Icons.search_off, text: 'Nenhum produto confirmado foi coletado. Tente novamente; se a Shopee pedir login ou verificação, conclua dentro da tela de busca.'),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(child: OutlinedButton.icon(onPressed: loadingCompetitors ? null : _searchCompetitors, icon: const Icon(Icons.refresh), label: const Text('Buscar novamente'))),
            const SizedBox(width: 10),
            Expanded(child: OutlinedButton.icon(onPressed: selectedIds.length >= 3 ? null : _manualCompetitor, icon: const Icon(Icons.add), label: const Text('Adicionar manual'))),
          ],
        ),
        const SizedBox(height: 14),
        for (final c in all)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: CompetitorCard(
              candidate: c,
              selected: selectedIds.contains(c.key),
              onChanged: (value) {
                setState(() {
                  if (value) {
                    if (selectedIds.length < 3) selectedIds.add(c.key);
                  } else {
                    selectedIds.remove(c.key);
                  }
                });
              },
            ),
          ),
      ],
    );
  }
}
