part of 'main.dart';

class ScoreGauge extends StatelessWidget {
  final int score;
  final double size;
  const ScoreGauge({super.key, required this.score, this.size = 90});

  @override
  Widget build(BuildContext context) {
    return SizedBox(width: size, height: size, child: CustomPaint(painter: GaugePainter(score: score, background: Theme.of(context).colorScheme.surfaceContainerHighest), child: Center(child: Padding(padding: EdgeInsets.only(top: size * .12), child: Text('$score', style: TextStyle(fontSize: size * .25, fontWeight: FontWeight.w900, color: scoreColorFor(score)))))));
  }
}

class GaugePainter extends CustomPainter {
  final int score;
  final Color background;
  GaugePainter({required this.score, required this.background});
  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromLTWH(8, 8, size.width - 16, size.height - 16);
    final base = Paint()..color = background..style = PaintingStyle.stroke..strokeWidth = 9..strokeCap = StrokeCap.round;
    final value = Paint()..color = scoreColorFor(score)..style = PaintingStyle.stroke..strokeWidth = 9..strokeCap = StrokeCap.round;
    const start = math.pi * .75;
    const sweep = math.pi * 1.5;
    canvas.drawArc(rect, start, sweep, false, base);
    canvas.drawArc(rect, start, sweep * (score / 100), false, value);
  }
  @override
  bool shouldRepaint(covariant GaugePainter oldDelegate) => oldDelegate.score != score || oldDelegate.background != background;
}

class SolutionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String current;
  final String optimized;
  const SolutionCard({super.key, required this.icon, required this.title, required this.current, required this.optimized});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [Icon(icon), const SizedBox(width: 8), Text(title, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18))]),
          const SizedBox(height: 12),
          BeforeAfterBox(current: current, optimized: optimized),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: optimized));
              if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$title otimizado copiado.')));
            },
            icon: const Icon(Icons.copy),
            label: const Text('Copiar otimizado'),
          ),
        ]),
      ),
    );
  }
}

class BeforeAfterBox extends StatelessWidget {
  final String current;
  final String optimized;
  const BeforeAfterBox({super.key, required this.current, required this.optimized});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Container(padding: const EdgeInsets.all(13), decoration: BoxDecoration(color: cs.surfaceContainerHighest.withOpacity(.55), borderRadius: BorderRadius.circular(14)), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const Text('ATUAL', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900)), const SizedBox(height: 5), SelectableText(current)])),
      const SizedBox(height: 8),
      Container(padding: const EdgeInsets.all(13), decoration: BoxDecoration(color: cs.primaryContainer.withOpacity(.55), borderRadius: BorderRadius.circular(14)), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const Text('OTIMIZADO', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900)), const SizedBox(height: 5), SelectableText(optimized)])),
    ]);
  }
}

class LessonBox extends StatelessWidget {
  final String title;
  final String text;
  final IconData icon;
  const LessonBox({super.key, required this.title, required this.text, required this.icon});
  @override
  Widget build(BuildContext context) => Card(child: Padding(padding: const EdgeInsets.all(16), child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Icon(icon), const SizedBox(width: 10), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: const TextStyle(fontWeight: FontWeight.w900)), const SizedBox(height: 5), Text(text)]))])));
}

class FeatureChip extends StatelessWidget {
  final IconData icon;
  final String text;
  const FeatureChip({super.key, required this.icon, required this.text});
  @override
  Widget build(BuildContext context) => Chip(avatar: Icon(icon, size: 18), label: Text(text));
}

class NoticeBox extends StatelessWidget {
  final IconData icon;
  final String text;
  const NoticeBox({super.key, required this.icon, required this.text});
  @override
  Widget build(BuildContext context) => Container(padding: const EdgeInsets.all(14), decoration: BoxDecoration(color: Theme.of(context).colorScheme.primaryContainer.withOpacity(.35), borderRadius: BorderRadius.circular(16)), child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Icon(icon, color: Theme.of(context).colorScheme.primary), const SizedBox(width: 10), Expanded(child: Text(text))]));
}

class InputBox extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final IconData icon;
  final int maxLines;
  final TextInputType? keyboardType;
  const InputBox({super.key, required this.controller, required this.label, required this.icon, this.maxLines = 1, this.keyboardType});
  @override
  Widget build(BuildContext context) => TextField(controller: controller, maxLines: maxLines, keyboardType: keyboardType, decoration: inputDecoration(label, icon));
}
