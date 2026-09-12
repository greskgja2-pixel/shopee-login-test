part of 'main.dart';

class PreparationWizard extends StatefulWidget {
  final String initialUrl;
  final String? previousAnalysisId;
  final AnalysisInput? previousInput;
  final AnalysisGeneratedCallback onGenerated;
  final Future<List<AchievementDef>> Function(AnalysisResult) onFinalize;
  const PreparationWizard({
    super.key,
    required this.initialUrl,
    this.previousAnalysisId,
    this.previousInput,
    required this.onGenerated,
    required this.onFinalize,
  });

  @override
  State<PreparationWizard> createState() => _PreparationWizardState();
}

class _PreparationWizardState extends State<PreparationWizard> {
  int step = 0;
  bool loadingProduct = true;
  bool loadingCompetitors = false;
  bool editingProduct = false;
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
  final roasTarget = TextEditingController();
  final adsSpend = TextEditingController();
  final productCost = TextEditingController();
  List<CompetitorCandidate> candidates = [];
  final Set<String> selectedIds = {};
  final List<CompetitorCandidate> manualCompetitors = [];

  @override
  void initState() {
    super.initState();
    final previous = widget.previousInput;
    if (previous != null) {
      goal = previous.goal;
      stage = previous.stage;
      issue = previous.issue;
      adsActive = previous.adsActive;
      if (previous.roas7d != null) roas.text = previous.roas7d!.toStringAsFixed(2).replaceAll('.', ',');
      if (previous.roasTarget != null) roasTarget.text = previous.roasTarget!.toStringAsFixed(2).replaceAll('.', ',');
      if (previous.adsSpend7d != null) adsSpend.text = previous.adsSpend7d!.toStringAsFixed(2).replaceAll('.', ',');
      if (previous.productCost != null) productCost.text = previous.productCost!.toStringAsFixed(2).replaceAll('.', ',');
    }
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadProduct());
  }

  Future<void> _loadProduct() async {
    if (!mounted) return;
    setState(() {
      loadingProduct = true;
      autoError = null;
    });
    try {
      final product = await ShopeeWebCollectorV3.collectProduct(context, widget.initialUrl);
      if (!mounted) return;
      if (product == null || product.title.trim().isEmpty) {
        setState(() {
          autoError = 'Não consegui confirmar o produto automaticamente. Nenhum dado genérico foi importado.';
          loadingProduct = false;
          editingProduct = true;
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
        editingProduct = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        autoError = 'A leitura automática foi interrompida. Você pode tentar novamente ou preencher apenas o que faltar.';
        loadingProduct = false;
        editingProduct = true;
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
      final found = await ShopeeWebCollectorV3.searchCompetitors(context, title.text.trim(), ownItemId: autoProduct?.itemId);
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
      roasTarget: adsActive ? parseNumber(roasTarget.text) : null,
      adsSpend7d: adsActive ? parseMoney(adsSpend.text) : null,
      productCost: parseMoney(productCost.text),
      product: autoProduct,
      competitors: selected,
    );

    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const AlertDialog(
        content: Row(
          children: [
            CircularProgressIndicator(),
            SizedBox(width: 18),
            Expanded(child: Text('Nossos sistemas estão analisando seu anúncio, comparando com os concorrentes e preparando as melhores soluções...')),
          ],
        ),
      ),
    );

    final intelligent = await GeminiService.analyze(input);
    final result = intelligent ?? AnalysisResult.build(input);
    if (!mounted) return;
    Navigator.of(context, rootNavigator: true).pop();
    widget.onGenerated(result, widget.previousAnalysisId);
    await Navigator.of(context).pushReplacement(MaterialPageRoute(
      builder: (_) => ResultPage(
        result: result,
        onFinalize: widget.onFinalize,
        onGenerated: widget.onGenerated,
      ),
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
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Coletando informações do anúncio...', style: TextStyle(fontWeight: FontWeight.w800)),
          ]),
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.all(18),
      children: [
        Row(children: [
          Expanded(child: Text('Informações captadas', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900))),
          if (autoProduct != null) const Icon(Icons.verified, color: Colors.green),
        ]),
        const SizedBox(height: 7),
        Text(autoProduct != null ? 'Confira rapidamente. Se algo estiver diferente, toque em Corrigir dados.' : 'A leitura automática não confirmou o produto. Preencha apenas o necessário.'),
        if (autoError != null) ...[
          const SizedBox(height: 12),
          NoticeBox(icon: Icons.warning_amber_rounded, text: autoError!),
          const SizedBox(height: 8),
          OutlinedButton.icon(onPressed: _loadProduct, icon: const Icon(Icons.refresh), label: const Text('Tentar leitura automática novamente')),
        ],
        if (autoProduct != null) ...[
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  if (autoProduct!.imageUrl != null)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: SizedBox(width: 92, height: 92, child: Image.network(autoProduct!.imageUrl!, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const Icon(Icons.image_not_supported_outlined))),
                    ),
                  if (autoProduct!.imageUrl != null) const SizedBox(width: 12),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(title.text, maxLines: 3, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
                    const SizedBox(height: 5),
                    if (price.text.isNotEmpty) Text('R\$ ${price.text}', style: TextStyle(color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.w900)),
                    if (category.text.isNotEmpty) Text(category.text, maxLines: 2, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.bodySmall),
                  ])),
                ]),
                const SizedBox(height: 12),
                AutoFacts(product: autoProduct!),
                if (autoProduct!.bestSellingVariationPrice != null) ...[
                  const SizedBox(height: 10),
                  NoticeBox(
                    icon: Icons.leaderboard_outlined,
                    text: 'Preço usado na análise: ${money(autoProduct!.bestSellingVariationPrice!)} — variação mais vendida${autoProduct!.bestSellingVariationName == null ? '' : ': ${autoProduct!.bestSellingVariationName}'}${autoProduct!.bestSellingVariationSold == null ? '' : ' • ${autoProduct!.bestSellingVariationSold} vendidos nesta variação'}.',
                  ),
                ] else if (autoProduct!.variationCount > 0) ...[
                  const SizedBox(height: 10),
                  const NoticeBox(
                    icon: Icons.info_outline,
                    text: 'O anúncio tem variações, mas a Shopee não informou vendas por variação nesta leitura. O app usará o melhor preço confirmado disponível e deixará isso explícito na comparação.',
                  ),
                ],
                if (autoProduct!.priceMin != null && autoProduct!.priceMax != null && autoProduct!.priceMin != autoProduct!.priceMax) ...[
                  const SizedBox(height: 7),
                  Text('Faixa de preços do anúncio: ${money(autoProduct!.priceMin!)} a ${money(autoProduct!.priceMax!)}', style: Theme.of(context).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w700)),
                ],
                if (description.text.isNotEmpty) ...[
                  const Divider(height: 24),
                  const Text('Descrição', style: TextStyle(fontWeight: FontWeight.w900)),
                  const SizedBox(height: 5),
                  Text(description.text, maxLines: 4, overflow: TextOverflow.ellipsis),
                ],
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(onPressed: () => showExpertTips(context, 'Imagens'), icon: const Icon(Icons.lightbulb_outline), label: const Text('Dicas de anúncio')),
                ),
              ]),
            ),
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: () => setState(() => editingProduct = !editingProduct),
            icon: Icon(editingProduct ? Icons.expand_less : Icons.edit_outlined),
            label: Text(editingProduct ? 'Ocultar correção' : 'Corrigir dados'),
          ),
        ],
        if (editingProduct || autoProduct == null) ...[
          const SizedBox(height: 14),
          InputBox(controller: title, label: 'Título atual *', icon: Icons.title),
          const SizedBox(height: 12),
          InputBox(controller: description, label: 'Descrição atual', icon: Icons.description_outlined, maxLines: 6),
          const SizedBox(height: 12),
          InputBox(controller: category, label: 'Categoria atual', icon: Icons.category_outlined),
          const SizedBox(height: 12),
          InputBox(controller: price, label: 'Preço usado na análise', icon: Icons.attach_money, keyboardType: const TextInputType.numberWithOptions(decimal: true)),
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
        const Text('Essas perguntas ajudam nossos sistemas a separar problema de tráfego de problema de conversão.'),
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
          InputBox(controller: roasTarget, label: 'ROAS Alvo atual', icon: Icons.track_changes_outlined, keyboardType: const TextInputType.numberWithOptions(decimal: true)),
          const SizedBox(height: 12),
          InputBox(controller: adsSpend, label: 'Gasto com Ads nos últimos 7 dias', icon: Icons.payments_outlined, keyboardType: const TextInputType.numberWithOptions(decimal: true)),
        ],
        const SizedBox(height: 14),
        Card(
          child: ExpansionTile(
            leading: const Icon(Icons.account_balance_wallet_outlined),
            title: const Text('Custos e margem (opcional)', style: TextStyle(fontWeight: FontWeight.w800)),
            subtitle: const Text('Preencha só se você souber o custo do produto.'),
            childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            children: [
              InputBox(controller: productCost, label: 'Custo do produto', icon: Icons.inventory_2_outlined, keyboardType: const TextInputType.numberWithOptions(decimal: true)),
              const SizedBox(height: 10),
              const Text('Esse valor ajuda o app a estimar um limite preliminar de rentabilidade para Ads. Taxas, impostos, frete, embalagem e outros custos variáveis não entram automaticamente nessa conta.', style: TextStyle(fontSize: 12)),
            ],
          ),
        ),
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
        const Text('A busca usa o título real do seu anúncio. Quando a Shopee disponibiliza vendas por variação, o app usa a variação líder também nos concorrentes para deixar a comparação de preço mais justa.'),
        const SizedBox(height: 14),
        if (loadingCompetitors) const LinearProgressIndicator(),
        if (!loadingCompetitors && candidates.isEmpty)
          const NoticeBox(icon: Icons.search_off, text: 'Nenhum produto confirmado foi coletado. Tente novamente ou adicione um concorrente manualmente.'),
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
