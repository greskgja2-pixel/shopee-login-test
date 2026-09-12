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
      final shortName = safe.isEmpty ? 'relatorio' : safe.substring(0, math.min(safe.length, 45));
      final filename = 'Super_Anuncio_${shortName}_${DateTime.now().millisecondsSinceEpoch}.pdf';
      final widgets = <pw.Widget>[];

      pw.Widget heading(String text, {double size = 15}) => pw.Padding(
            padding: const pw.EdgeInsets.only(top: 8, bottom: 6),
            child: pw.Text(text, style: pw.TextStyle(fontSize: size, fontWeight: pw.FontWeight.bold)),
          );

      pw.Widget label(String text) => pw.Padding(
            padding: const pw.EdgeInsets.only(top: 4, bottom: 3),
            child: pw.Text(text, style: pw.TextStyle(fontSize: 9, color: PdfColors.grey700, fontWeight: pw.FontWeight.bold)),
          );

      pw.Widget divider() => pw.Padding(
            padding: const pw.EdgeInsets.symmetric(vertical: 8),
            child: pw.Divider(color: PdfColors.grey300),
          );

      pw.Widget linkButton(String text, String url) {
        final valid = Uri.tryParse(url);
        if (valid == null || !valid.hasScheme) return pw.SizedBox();
        return pw.UrlLink(
          destination: url,
          child: pw.Container(
            padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: pw.BoxDecoration(
              color: PdfColors.deepOrange,
              borderRadius: pw.BorderRadius.circular(6),
            ),
            child: pw.Text(text, style: pw.TextStyle(color: PdfColors.white, fontWeight: pw.FontWeight.bold)),
          ),
        );
      }

      List<String> chunks(String value, {int max = 1500}) {
        final text = value.trim();
        if (text.isEmpty) return const ['Não informado'];
        final out = <String>[];
        var remaining = text;
        while (remaining.length > max) {
          var cut = remaining.lastIndexOf('\n', max);
          if (cut < max ~/ 2) cut = remaining.lastIndexOf(' ', max);
          if (cut < max ~/ 2) cut = max;
          out.add(remaining.substring(0, cut).trim());
          remaining = remaining.substring(cut).trimLeft();
        }
        if (remaining.isNotEmpty) out.add(remaining);
        return out;
      }

      void addTextBlocks(String text, {pw.TextStyle? style}) {
        for (final part in chunks(text)) {
          widgets.add(pw.Text(part, style: style));
          widgets.add(pw.SizedBox(height: 4));
        }
      }

      widgets.add(
        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            if (productImage != null)
              pw.Container(
                width: 92,
                height: 92,
                margin: const pw.EdgeInsets.only(right: 14),
                child: pw.Image(productImage, fit: pw.BoxFit.contain),
              ),
            pw.Expanded(
              child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                pw.Text('SUPER ANÚNCIO', style: pw.TextStyle(fontSize: 23, color: PdfColors.deepOrange, fontWeight: pw.FontWeight.bold)),
                pw.SizedBox(height: 4),
                pw.Text('Relatório de otimização', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
                pw.SizedBox(height: 7),
                pw.Text(result.input.title, maxLines: 4, style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
                pw.SizedBox(height: 5),
                pw.Text('Nota: ${result.score}/100'),
                pw.Text('Gerado em: ${formatDate(DateTime.now())}'),
              ]),
            ),
          ],
        ),
      );
      widgets.add(pw.SizedBox(height: 12));
      widgets.add(linkButton('Abrir anúncio analisado', result.input.url));
      widgets.add(pw.SizedBox(height: 4));
      widgets.add(pw.Text(result.input.url, style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700)));
      widgets.add(divider());

      widgets.add(heading('Resumo da auditoria'));
      addTextBlocks(result.summary);

      widgets.add(heading('Título'));
      widgets.add(label('ATUAL'));
      addTextBlocks(result.input.title);
      widgets.add(label('OTIMIZADO'));
      addTextBlocks(result.optimizedTitle, style: const pw.TextStyle(color: PdfColors.green800));
      widgets.add(divider());

      widgets.add(heading('Descrição'));
      widgets.add(label('ATUAL'));
      addTextBlocks(result.input.description.isEmpty ? 'Não informada' : result.input.description);
      widgets.add(label('OTIMIZADO'));
      addTextBlocks(result.optimizedDescription, style: const pw.TextStyle(color: PdfColors.green800));
      widgets.add(divider());

      widgets.add(heading('Categoria'));
      widgets.add(label('ATUAL'));
      addTextBlocks(result.input.category.isEmpty ? 'Não informada' : result.input.category);
      widgets.add(label('RECOMENDADA'));
      addTextBlocks(result.suggestedCategory);
      widgets.add(divider());

      final p = result.input.product;
      widgets.add(heading('Preço e concorrência'));
      widgets.add(pw.Text('Preço usado na análise: ${result.input.price == null ? 'Não informado' : money(result.input.price!)}'));
      if (p?.bestSellingVariationPrice != null) {
        widgets.add(pw.Text('Base: variação mais vendida${p!.bestSellingVariationName == null ? '' : ' - ${p.bestSellingVariationName}'}${p.bestSellingVariationSold == null ? '' : ' (${p.bestSellingVariationSold} vendidos)'}'));
      } else if ((p?.variationCount ?? 0) > 0) {
        widgets.add(pw.Text('Base: a Shopee não informou vendas por variação; foi usado o melhor preço confirmado disponível.'));
      }
      if (p?.priceMin != null && p?.priceMax != null && p!.priceMin != p.priceMax) {
        widgets.add(pw.Text('Faixa do anúncio: ${money(p.priceMin!)} a ${money(p.priceMax!)}'));
      }
      if (result.competitorMedian != null) widgets.add(pw.Text('Mediana dos concorrentes: ${money(result.competitorMedian!)}'));
      widgets.add(pw.SizedBox(height: 5));
      addTextBlocks(result.priceInsight);
      widgets.add(divider());

      widgets.add(heading('Raio-X por área'));
      for (final d in result.dimensions) {
        widgets.add(
          pw.Container(
            width: double.infinity,
            margin: const pw.EdgeInsets.only(bottom: 7),
            padding: const pw.EdgeInsets.all(9),
            decoration: pw.BoxDecoration(
              color: PdfColors.grey100,
              border: pw.Border.all(color: PdfColors.grey300),
              borderRadius: pw.BorderRadius.circular(6),
            ),
            child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
              pw.Text('${d.name} - ${d.score}/${d.maxScore}', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 3),
              pw.Text('Por que: ${d.reason}', maxLines: 8),
              pw.SizedBox(height: 3),
              pw.Text('Como melhorar: ${d.action}', maxLines: 8),
            ]),
          ),
        );
      }
      widgets.add(divider());

      if (p != null) {
        widgets.add(heading('Dados coletados do anúncio'));
        widgets.add(pw.Text('Imagens: ${p.imageCount}'));
        widgets.add(pw.Text('Vídeo: ${p.hasVideo ? 'Sim' : 'Não detectado'}'));
        if (p.rating != null) widgets.add(pw.Text('Avaliação: ${p.rating!.toStringAsFixed(1)}'));
        if (p.reviewCount != null) widgets.add(pw.Text('Avaliações: ${p.reviewCount}'));
        if (p.sold != null) widgets.add(pw.Text('Vendidos: ${p.sold}'));
        if (p.stock != null) widgets.add(pw.Text('Estoque: ${p.stock}'));
        widgets.add(pw.Text('Atributos identificados: ${p.attributesCount}'));
        widgets.add(pw.Text('Variações identificadas: ${p.variationCount}'));
        widgets.add(divider());
      }

      if (result.competitors.isNotEmpty) {
        widgets.add(heading('Concorrentes usados na comparação'));
        for (var i = 0; i < result.competitors.length; i++) {
          final c = result.competitors[i];
          widgets.add(pw.Text('${i + 1}. ${c.title}', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)));
          if (c.price != null) widgets.add(pw.Text('Preço usado: ${money(c.price!)}'));
          if (c.bestSellingVariationPrice != null) {
            widgets.add(pw.Text('Variação líder${c.bestSellingVariationName == null ? '' : ': ${c.bestSellingVariationName}'}${c.bestSellingVariationSold == null ? '' : ' - ${c.bestSellingVariationSold!.round()} vendidos'}'));
          }
          if (c.priceMin != null && c.priceMax != null && c.priceMin != c.priceMax) {
            widgets.add(pw.Text('Faixa: ${money(c.priceMin!)} a ${money(c.priceMax!)}'));
          }
          if (c.rating != null) widgets.add(pw.Text('Avaliação: ${c.rating!.toStringAsFixed(1)}'));
          widgets.add(pw.SizedBox(height: 5));
          widgets.add(linkButton('Abrir concorrente ${i + 1}', c.link));
          widgets.add(pw.SizedBox(height: 3));
          widgets.add(pw.Text(c.link, style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700)));
          widgets.add(pw.SizedBox(height: 10));
        }
        widgets.add(divider());
      }

      if (result.input.adsActive) {
        final advice = buildRoasStrategy(result.input);
        widgets.add(heading('Ads e ROAS'));
        widgets.add(pw.Text('ROAS atual: ${result.input.roas7d?.toStringAsFixed(2) ?? 'Não informado'}'));
        widgets.add(pw.Text('ROAS alvo atual: ${result.input.roasTarget?.toStringAsFixed(2) ?? 'Não informado'}'));
        widgets.add(pw.Text('Gasto em 7 dias: ${result.input.adsSpend7d == null ? 'Não informado' : money(result.input.adsSpend7d!)}'));
        widgets.add(pw.Text('Custo do produto: ${result.input.productCost == null ? 'Não informado' : money(result.input.productCost!)}'));
        if (advice.grossMarginPct != null) widgets.add(pw.Text('Margem bruta preliminar: ${advice.grossMarginPct!.toStringAsFixed(1)}%'));
        if (advice.preliminaryBreakEvenRoas != null) widgets.add(pw.Text('ROAS de equilíbrio preliminar: ${advice.preliminaryBreakEvenRoas!.toStringAsFixed(2)}'));
        if (advice.suggestedTarget != null) widgets.add(pw.Text('Teste de Meta de ROAS sugerido: cerca de ${advice.suggestedTarget!.toStringAsFixed(2)}', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)));
        widgets.add(pw.SizedBox(height: 6));
        widgets.add(pw.Text(advice.title, style: pw.TextStyle(fontWeight: pw.FontWeight.bold)));
        widgets.add(pw.SizedBox(height: 3));
        addTextBlocks(advice.message);
        if (result.input.productCost != null) {
          widgets.add(pw.Text('Importante: a estimativa de rentabilidade não inclui automaticamente taxas da plataforma, impostos, frete, embalagem e outros custos variáveis.', style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700)));
        }
        widgets.add(divider());
      }

      widgets.add(heading('Plano de ação'));
      for (final d in result.dimensions.where((d) => d.score < d.maxScore * .9)) {
        for (final part in chunks('${d.name}: ${d.action}', max: 900)) {
          widgets.add(pw.Padding(
            padding: const pw.EdgeInsets.only(bottom: 5),
            child: pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
              pw.Text('- ', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
              pw.Expanded(child: pw.Text(part)),
            ]),
          ));
        }
      }

      doc.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(34),
          footer: (context) => pw.Align(
            alignment: pw.Alignment.centerRight,
            child: pw.Text('Super Anúncio - página ${context.pageNumber}/${context.pagesCount}', style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600)),
          ),
          build: (_) => widgets,
        ),
      );

      final file = File('$cache/$filename');
      await file.writeAsBytes(await doc.save(), flush: true);
      return file.path;
    } catch (e, stack) {
      debugPrint('Falha ao gerar PDF do Super Anúncio: $e');
      debugPrintStack(stackTrace: stack);
      return null;
    }
  }

  static Future<pw.MemoryImage?> _loadImage(String? url) async {
    if (url == null || !url.startsWith('http')) return null;
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 7);
    try {
      final req = await client.getUrl(Uri.parse(url));
      req.headers.set(HttpHeaders.userAgentHeader, 'Mozilla/5.0');
      req.headers.set(HttpHeaders.refererHeader, 'https://shopee.com.br/');
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
