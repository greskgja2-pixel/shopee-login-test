part of 'main.dart';

String extractUrl(String text) {
  final match = RegExp(r'https?://\S+').firstMatch(text);
  return (match?.group(0) ?? text).trim();
}

double? parseNumber(String raw) {
  var cleaned = raw.trim().replaceAll(RegExp(r'[^0-9,\.]'), '');
  if (cleaned.contains(',') && cleaned.contains('.')) {
    cleaned = cleaned.replaceAll('.', '').replaceAll(',', '.');
  } else if (cleaned.contains(',')) {
    cleaned = cleaned.replaceAll(',', '.');
  }
  return double.tryParse(cleaned);
}

double? parseMoney(String raw) {
  var cleaned = raw.replaceAll(RegExp(r'[^0-9,\.]'), '');
  if (cleaned.contains(',') && cleaned.contains('.')) {
    cleaned = cleaned.replaceAll('.', '').replaceAll(',', '.');
  } else if (cleaned.contains(',')) {
    cleaned = cleaned.replaceAll(',', '.');
  }
  return double.tryParse(cleaned);
}

String money(double value) => 'R\$ ${value.toStringAsFixed(2).replaceAll('.', ',')}';

Color scoreColorFor(int score) => score >= 80 ? Colors.green : score >= 60 ? Colors.orange : Colors.red;

String formatDate(DateTime d) => '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

double? medianPrice(List<CompetitorCandidate> comps) {
  final values = comps.map((e) => e.price).whereType<double>().where((e) => e > 0).toList()..sort();
  if (values.isEmpty) return null;
  final mid = values.length ~/ 2;
  return values.length.isOdd ? values[mid] : (values[mid - 1] + values[mid]) / 2;
}

String buildPriceInsight(double? current, double? median, int count) {
  if (count == 0) return 'Sem concorrentes selecionados, não dá para concluir se o preço está competitivo.';
  if (current == null || median == null) return 'Há concorrentes selecionados, mas faltam preços suficientes para uma comparação segura.';
  final diff = (current - median) / median;
  if (diff > .15) return 'Seu preço está cerca de ${(diff * 100).round()}% acima da mediana dos concorrentes selecionados. Verifique se o anúncio comunica valor suficiente para justificar a diferença.';
  if (diff < -.15) return 'Seu preço está cerca de ${(diff.abs() * 100).round()}% abaixo da mediana. Antes de reduzir mais, avalie margem e se um preço muito baixo pode estar destruindo valor percebido.';
  return 'Seu preço está próximo da faixa dos concorrentes selecionados. O ganho deve vir mais de conteúdo, confiança e diferenciação do que de desconto.';
}

int duplicateWordCount(String text) {
  final words = text.toLowerCase().split(RegExp(r'\s+')).where((e) => e.length > 2).toList();
  final seen = <String>{};
  var dup = 0;
  for (final w in words) if (!seen.add(w)) dup++;
  return dup;
}

String optimizeTitle(String current, List<CompetitorCandidate> competitors) {
  final original = current.replaceAll(RegExp(r'\s+'), ' ').trim();
  if (original.isEmpty) return 'Produto + principal característica + modelo/uso';
  final words = original.split(' ');
  final seen = <String>{};
  final clean = <String>[];
  for (final word in words) {
    final key = word.toLowerCase().replaceAll(RegExp(r'[^A-Za-z0-9À-ÖØ-öø-ÿ]'), '');
    if (key.length <= 2 || seen.add(key)) clean.add(word);
  }
  final competitorText = competitors.map((e) => e.title.toLowerCase()).join(' ');
  final boosted = <String>[];
  final rest = <String>[];
  for (final word in clean) {
    final key = word.toLowerCase().replaceAll(RegExp(r'[^A-Za-z0-9À-ÖØ-öø-ÿ]'), '');
    if (key.length >= 4 && RegExp('\\b${RegExp.escape(key)}\\b').allMatches(competitorText).length >= 2) {
      boosted.add(word);
    } else {
      rest.add(word);
    }
  }
  final result = [...boosted.take(4), ...rest].join(' ').replaceAll(RegExp(r'\s+'), ' ').trim();
  return result.length <= 120 ? result : result.substring(0, 120).trim();
}

String optimizeDescription(String title, String current, List<CompetitorCandidate> competitors) {
  final base = current.trim();
  final recurring = recurringTerms(title, competitors);
  final buffer = StringBuffer();
  buffer.writeln('✅ $title');
  buffer.writeln();
  buffer.writeln('Principais benefícios:');
  buffer.writeln('• [benefício real 1]');
  buffer.writeln('• [benefício real 2]');
  buffer.writeln('• [benefício real 3]');
  buffer.writeln();
  buffer.writeln('Informações importantes:');
  buffer.writeln('• Material/modelo: [preencher]');
  buffer.writeln('• Medidas/compatibilidade: [preencher]');
  buffer.writeln('• Conteúdo da embalagem: [preencher]');
  if (recurring.isNotEmpty) buffer.writeln('• Termos para validar no anúncio: ${recurring.join(', ')}');
  if (base.isNotEmpty) {
    buffer.writeln();
    buffer.writeln('Descrição original para aproveitar informações verdadeiras:');
    buffer.writeln(base);
  }
  return buffer.toString().trim();
}

String suggestCategory(String current, List<CompetitorCandidate> competitors) {
  final categories = competitors.map((e) => e.category.trim()).where((e) => e.isNotEmpty).toList();
  if (categories.isNotEmpty) {
    final counts = <String, int>{};
    for (final c in categories) counts[c] = (counts[c] ?? 0) + 1;
    final best = counts.entries.reduce((a, b) => a.value >= b.value ? a : b).key;
    if (best.isNotEmpty) return best;
  }
  return current.isEmpty ? 'Validar a subcategoria mais específica na Shopee' : current;
}

List<String> recurringTerms(String ownTitle, List<CompetitorCandidate> comps) {
  final stop = {'para', 'com', 'sem', 'uma', 'das', 'dos', 'por', 'que', 'de', 'do', 'da', 'em', 'e', 'a', 'o'};
  final counts = <String, int>{};
  for (final c in comps) {
    final unique = c.title.toLowerCase().replaceAll(RegExp(r'[^A-Za-z0-9À-ÖØ-öø-ÿ ]'), ' ').split(RegExp(r'\s+')).where((w) => w.length >= 4 && !stop.contains(w)).toSet();
    for (final w in unique) counts[w] = (counts[w] ?? 0) + 1;
  }
  final entries = counts.entries.where((e) => e.value >= 2).toList()..sort((a, b) => b.value.compareTo(a.value));
  return entries.take(6).map((e) => e.key).toList();
}

double? average(Iterable<double> values) {
  final list = values.toList();
  if (list.isEmpty) return null;
  return list.reduce((a, b) => a + b) / list.length;
}
