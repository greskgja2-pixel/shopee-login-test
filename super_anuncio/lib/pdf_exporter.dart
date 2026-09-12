part of 'main.dart';

class PdfExporter {
  static Future<String?> create(AnalysisResult result) async {
    try {
      final cache = await kShareChannel.invokeMethod<String>('cacheDir');
      if (cache == null || cache.isEmpty) return null;
      final doc = pw.Document();
      final productImage = await _loadImage(result.input.product?.imageUrl);
      final safe = result.input.title
          .replaceAll(RegExp(r'[^A-Za-z0-9À-ÖØ-öø-ÿ _-]'), '')
          .trim()
          .replaceAll(RegExp(r'\s+'), '_');
      final filename = 'Super_Anuncio_${safe.isEmpty ? 'relatorio' : safe.substring(0, math.min(safe.length, 45))}_${DateTime.now().millisecondsSinceEpoch}.pdf';

      pw.Widget section(String title, pw.Widget child) => pw.Container(
            margin: const pw.EdgeInsets.only(bottom: 12),
            padding: const pw.EdgeInsets.all(12),
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: PdfColors.grey300),
              borderRadius: pw.BorderRadius.circular(8),
            ),
            child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
              pw.Text(title, style: pw.TextStyle(fontSize: 15, fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 7),
              child,
            ]),
          );

      pw.Widget currentOptimized(String current, String optimized) => pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text('ATUAL', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: PdfColors.grey700)),
              pw.SizedBox(height: 3),
              pw.Text(current.isEmpty ? 'Não informado' : current),
              pw.SizedBox(height: 8),
              pw.Text('OTIMIZADO', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: PdfColors.green700)),
              pw.SizedBox(height: 3),
              pw.Text(optimized.isEmpty ? 'Sem alteração sugerida' : optimized),
            ],
          );

      pw.Widget linkButton(String label, String url) {
        return pw.UrlLink(
          destination: url,
          child: pw.Container(
            padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: pw.BoxDecoration(color: PdfColors.deepOrange, borderRadius: pw.BorderRadius.circular(6)),
            child: pw.Text(label, style: pw.TextStyle(color: PdfColors.white, fontWeight: pw.FontWeight.bold)),
          ),
        );
      }

      doc.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(34),
          footer: (context) => pw.Align(
            alignment: pw.Alignment.centerRight,
            child: pw.Text('Super Anúncio • página ${context.pageNumber}/${context.pagesCount}', style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600)),
          ),
          build: (context) => [
            pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                if (productImage != null)
                  pw.Container(
                    width: 100,
                    height: 100,
                    margin: const pw.EdgeInsets.only(right: 16),
                    child: pw.Image(productImage, fit: pw.BoxFit.contain),
                  ),
                pw.Expanded(
                  child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                    pw.Text('SUPER ANÚNCIO', style: pw.TextStyle(fontSize: 24, color: PdfColors.deepOrange, fontWeight: pw.FontWeight.bold)),
                    pw.SizedBox(height: 5),
                    pw.Text('Relatório de otimização', style: pw.TextStyle(fontSize: 15, fontWeight: pw.FontWeight.bold)),
                    pw.SizedBox(height: 8),
                    pw.Text(result.input.title, style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold)),
                    pw.SizedBox(height: 6),
                    pw.Text('Nota atual: ${result.score}/100'),
                    pw.Text('Gerado em: ${formatDate(DateTime.now())}'),
                  ]),
                ),
              ],
            ),
            pw.SizedBox(height: 14),
            linkButton('Abrir anúncio analisado', result.input.url),
            pw.SizedBox(height: 4),
            pw.Text(result.input.url, style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700)),
            pw.SizedBox(height: 16),
            section('Resumo da auditoria', pw.Text(result.summary)),
            section('Título', currentOptimized(result.input.title, result.optimizedTitle)),
            section('Descrição', currentOptimized(result.input.description, result.optimizedDescription)),
            section('Categoria', currentOptimized(result.input.category, result.suggestedCategory)),
            section(
              'Preço e concorrência',
              pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                pw.Text('Preço atual: ${result.input.price == null ? 'Não informado' : money(result.input.price!)}'),
                if (result.competitorMedian != null) pw.Text('Mediana dos concorrentes: ${money(result.competitorMedian!)}'),
                pw.SizedBox(height: 5),
                pw.Text(result.priceInsight),
              ]),
            ),
            section(
              'Raio-X por área',
              pw.Column(
                children: result.dimensions
                    .map((d) => pw.Container(
                          width: double.infinity,
                          margin: const pw.EdgeInsets.only(bottom: 8),
                          padding: const pw.EdgeInsets.all(9),
                          decoration: const pw.BoxDecoration(color: PdfColors.grey100),
                          child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                            pw.Text('${d.name} — ${d.score}/${d.maxScore}', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                            pw.SizedBox(height: 3),
                            pw.Text('Por que: ${d.reason}'),
                            pw.SizedBox(height: 3),
                            pw.Text('Como melhorar: ${d.action}'),
                          ]),
                        ))
                    .toList(),
              ),
            ),
            if (result.input.product != null)
              section(
                'Dados coletados do anúncio',
                pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                  pw.Text('Imagens: ${result.input.product!.imageCount}'),
                  pw.Text('Vídeo: ${result.input.product!.hasVideo ? 'Sim' : 'Não detectado'}'),
                  if (result.input.product!.rating != null) pw.Text('Avaliação: ${result.input.product!.rating!.toStringAsFixed(1)}'),
                  if (result.input.product!.reviewCount != null) pw.Text('Avaliações: ${result.input.product!.reviewCount}'),
                  if (result.input.product!.sold != null) pw.Text('Vendidos: ${result.input.product!.sold}'),
                  if (result.input.product!.stock != null) pw.Text('Estoque: ${result.input.product!.stock}'),
                  pw.Text('Atributos identificados: ${result.input.product!.attributesCount}'),
                  pw.Text('Variações identificadas: ${result.input.product!.variationCount}'),
                ]),
              ),
            if (result.competitors.isNotEmpty) ...[
              pw.Text('CONCORRENTES USADOS NA COMPARAÇÃO', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 8),
              for (var i = 0; i < result.competitors.length; i++)
                pw.Container(
                  margin: const pw.EdgeInsets.only(bottom: 10),
                  padding: const pw.EdgeInsets.all(10),
                  decoration: pw.BoxDecoration(border: pw.Border.all(color: PdfColors.grey300), borderRadius: pw.BorderRadius.circular(7)),
                  child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                    pw.Text('${i + 1}. ${result.competitors[i].title}', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                    if (result.competitors[i].price != null) pw.Text('Preço: ${money(result.competitors[i].price!)}'),
                    if (result.competitors[i].rating != null) pw.Text('Avaliação: ${result.competitors[i].rating!.toStringAsFixed(1)}'),
                    pw.SizedBox(height: 6),
                    linkButton('Abrir concorrente ${i + 1}', result.competitors[i].link),
                    pw.SizedBox(height: 3),
                    pw.Text(result.competitors[i].link, style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700)),
                  ]),
                ),
            ],
            if (result.input.adsActive)
              section(
                'Ads — últimos 7 dias',
                pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                  pw.Text('ROAS: ${result.input.roas7d?.toStringAsFixed(2) ?? 'Não informado'}'),
                  pw.Text('Gasto: ${result.input.adsSpend7d == null ? 'Não informado' : money(result.input.adsSpend7d!)}'),
                ]),
              ),
            pw.SizedBox(height: 10),
            pw.Text('Plano de ação', style: pw.TextStyle(fontSize: 15, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 6),
            ...result.dimensions
                .where((d) => d.score < d.maxScore * .9)
                .map((d) => pw.Padding(
                      padding: const pw.EdgeInsets.only(bottom: 5),
                      child: pw.Text('• ${d.name}: ${d.action}'),
                    )),
          ],
        ),
      );

      final file = File('$cache/$filename');
      await file.writeAsBytes(await doc.save(), flush: true);
      return file.path;
    } catch (_) {
      return null;
    }
  }

  static Future<pw.MemoryImage?> _loadImage(String? url) async {
    if (url == null || !url.startsWith('http')) return null;
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 7);
    try {
      final req = await client.getUrl(Uri.parse(url));
      final res = await req.close().timeout(const Duration(seconds: 8));
      if (res.statusCode < 200 || res.statusCode >= 300) return null;
      final bytes = await consolidateHttpClientResponseBytes(res);
      if (bytes.length > 4 * 1024 * 1024) return null;
      return pw.MemoryImage(bytes);
    } catch (_) {
      return null;
    } finally {
      client.close(force: true);
    }
  }
}
