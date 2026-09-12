from pathlib import Path
import re

p = Path('build_super_anuncio/lib/result_page.dart')
s = p.read_text()
new = r'''  Future<String?> _createShareImage({AchievementDef? achievement}) async {
    try {
      final cache = await kShareChannel.invokeMethod<String>('cacheDir');
      if (cache == null || cache.isEmpty) return null;
      const width = 1080.0;
      const height = 1350.0;
      final bytes = await rootBundle.load('assets/achievement_template.jpg');
      final template = await ui.decodeImageFromList(bytes.buffer.asUint8List());
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      canvas.drawImageRect(template, Rect.fromLTWH(0, 0, template.width.toDouble(), template.height.toDouble()), const Rect.fromLTWH(0, 0, width, height), Paint()..filterQuality = FilterQuality.high);

      void text(String value, double y, double size, FontWeight weight, Color color, {double maxWidth = 850, int maxLines = 3}) {
        final tp = TextPainter(
          text: TextSpan(text: value, style: TextStyle(fontSize: size, fontWeight: weight, color: color, height: 1.08)),
          textDirection: TextDirection.ltr,
          textAlign: TextAlign.center,
          maxLines: maxLines,
          ellipsis: '…',
        )..layout(maxWidth: maxWidth);
        tp.paint(canvas, Offset((width - tp.width) / 2, y));
      }

      text('SUPER ANÚNCIO', 570, 56, FontWeight.w900, const Color(0xFFE94A0B), maxLines: 1);
      text('CONQUISTA DESBLOQUEADA', 638, 29, FontWeight.w800, const Color(0xFF30343B), maxLines: 1);
      text(achievement?.title ?? 'Anúncio em evolução', 715, 48, FontWeight.w900, const Color(0xFF171B22), maxWidth: 830, maxLines: 2);
      canvas.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(335, 835, 410, 76), const Radius.circular(38)), Paint()..color = const Color(0xFFFFE8D7).withOpacity(.92));
      text('Nota ${widget.result.score}/100', 848, 40, FontWeight.w900, const Color(0xFFE94A0B), maxLines: 1);
      text(widget.result.input.title, 955, 29, FontWeight.w800, const Color(0xFF24272D), maxWidth: 820, maxLines: 3);
      text('Analise. Otimize. Venda mais.', 1090, 28, FontWeight.w600, const Color(0xFF50545B), maxLines: 1);
      canvas.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(395, 1160, 290, 58), const Radius.circular(29)), Paint()..color = const Color(0xFFFF5A1F));
      text('By Gresk 2026', 1171, 28, FontWeight.w700, Colors.white, maxWidth: 280, maxLines: 1);
      text('Que Deus e família seja sua prioridade. Gresk 2026', 1245, 19, FontWeight.w600, const Color(0xFF50545B), maxWidth: 850, maxLines: 1);

      final picture = recorder.endRecording();
      final image = await picture.toImage(width.toInt(), height.toInt());
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      template.dispose();
      if (data == null) return null;
      final file = File('$cache/super_anuncio_conquista_${DateTime.now().millisecondsSinceEpoch}.png');
      await file.writeAsBytes(data.buffer.asUint8List(), flush: true);
      return file.path;
    } catch (e) {
      debugPrint('Falha ao gerar arte da conquista: $e');
      return null;
    }
  }

'''
pattern = r"  Future<String\?> _createShareImage\(\{AchievementDef\? achievement\}\) async \{.*?\n  String _shareText\(\) \{"
out, n = re.subn(pattern, new + '  String _shareText() {', s, count=1, flags=re.S)
if n != 1:
    raise SystemExit('Nao foi possivel localizar _createShareImage')
p.write_text(out)
