part of 'main.dart';

class ManualCompetitorDialog extends StatefulWidget {
  const ManualCompetitorDialog({super.key});
  @override
  State<ManualCompetitorDialog> createState() => _ManualCompetitorDialogState();
}

class _ManualCompetitorDialogState extends State<ManualCompetitorDialog> {
  final title = TextEditingController();
  final price = TextEditingController();
  final link = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Concorrente manual'),
      content: SingleChildScrollView(
        child: Column(children: [
          TextField(controller: title, decoration: const InputDecoration(labelText: 'Título/nome')),
          TextField(controller: price, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Preço')),
          TextField(controller: link, keyboardType: TextInputType.url, decoration: const InputDecoration(labelText: 'Link')),
        ]),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
        FilledButton(
          onPressed: () => Navigator.pop(context, CompetitorCandidate(title: title.text.trim().isEmpty ? 'Concorrente' : title.text.trim(), price: parseMoney(price.text), link: link.text.trim(), imageUrl: null, rating: null, sold: null, shopId: null, itemId: 'manual-${DateTime.now().millisecondsSinceEpoch}', description: '', category: '')),
          child: const Text('Adicionar'),
        ),
      ],
    );
  }
}
