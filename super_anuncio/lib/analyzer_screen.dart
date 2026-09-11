part of 'main.dart';

class AnalyzerHome extends StatefulWidget {
  final String? sharedText;
  final ValueChanged<AnalysisResult> onGenerated;
  final Future<List<AchievementDef>> Function(AnalysisResult) onFinalize;
  const AnalyzerHome({super.key, this.sharedText, required this.onGenerated, required this.onFinalize});

  @override
  State<AnalyzerHome> createState() => _AnalyzerHomeState();
}

class _AnalyzerHomeState extends State<AnalyzerHome> {
  final link = TextEditingController();

  @override
  void initState() {
    super.initState();
    if (widget.sharedText != null) link.text = extractUrl(widget.sharedText!);
  }

  @override
  void didUpdateWidget(covariant AnalyzerHome oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.sharedText != null && widget.sharedText != oldWidget.sharedText) {
      link.text = extractUrl(widget.sharedText!);
    }
  }

  Future<void> _paste() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    if (data?.text != null) setState(() => link.text = extractUrl(data!.text!));
  }

  void _start() {
    final url = link.text.trim();
    if (url.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Cole primeiro o link do anúncio da Shopee.')));
      return;
    }
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => PreparationWizard(
        initialUrl: url,
        onGenerated: widget.onGenerated,
        onFinalize: widget.onFinalize,
      ),
    ));
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
              CircleAvatar(backgroundColor: cs.primaryContainer, child: Icon(Icons.auto_awesome, color: cs.primary)),
            ],
          ),
          const SizedBox(height: 28),
          Text('Auditoria completa do anúncio', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900)),
          const SizedBox(height: 8),
          const Text('Cole o link. O Super Anúncio tenta ler os dados automaticamente, encontra concorrentes e monta um plano de melhoria.'),
          const SizedBox(height: 22),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextField(
                    controller: link,
                    keyboardType: TextInputType.url,
                    decoration: InputDecoration(
                      labelText: 'Link do anúncio da Shopee',
                      hintText: 'https://shopee.com.br/...',
                      prefixIcon: const Icon(Icons.link),
                      suffixIcon: IconButton(onPressed: _paste, icon: const Icon(Icons.content_paste)),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                  ),
                  const SizedBox(height: 14),
                  FilledButton.icon(
                    onPressed: _start,
                    icon: const Icon(Icons.manage_search),
                    label: const Text('INICIAR AUDITORIA'),
                    style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16), textStyle: const TextStyle(fontWeight: FontWeight.w900)),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          Text('O que entra na nota', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900)),
          const SizedBox(height: 12),
          const Wrap(
            spacing: 9,
            runSpacing: 9,
            children: [
              FeatureChip(icon: Icons.title, text: 'Título'),
              FeatureChip(icon: Icons.description_outlined, text: 'Descrição'),
              FeatureChip(icon: Icons.image_outlined, text: 'Imagens'),
              FeatureChip(icon: Icons.play_circle_outline, text: 'Vídeo'),
              FeatureChip(icon: Icons.category_outlined, text: 'Categoria'),
              FeatureChip(icon: Icons.sell_outlined, text: 'Preço'),
              FeatureChip(icon: Icons.groups_outlined, text: 'Concorrentes'),
              FeatureChip(icon: Icons.star_outline, text: 'Avaliações'),
              FeatureChip(icon: Icons.inventory_2_outlined, text: 'Estoque/variações'),
              FeatureChip(icon: Icons.campaign_outlined, text: 'Ads/ROAS'),
            ],
          ),
        ],
      ),
    );
  }
}
