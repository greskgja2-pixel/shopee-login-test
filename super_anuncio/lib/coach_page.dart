part of 'main.dart';

class CoachPage extends StatefulWidget {
  final AnalysisResult result;
  const CoachPage({super.key, required this.result});

  @override
  State<CoachPage> createState() => _CoachPageState();
}

class _CoachPageState extends State<CoachPage> {
  int page = 0;

  @override
  Widget build(BuildContext context) {
    final lessons = widget.result.lessons;
    final lesson = lessons[page];
    return Scaffold(
      appBar: AppBar(title: Text('Missão ${page + 1} de ${lessons.length}')),
      body: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          LinearProgressIndicator(value: (page + 1) / lessons.length),
          const SizedBox(height: 24),
          Icon(lesson.icon, size: 58, color: Theme.of(context).colorScheme.primary),
          const SizedBox(height: 14),
          Text(lesson.title, textAlign: TextAlign.center, style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900)),
          const SizedBox(height: 18),
          Expanded(
            child: ListView(children: [
              LessonBox(title: 'Por que isso importa?', text: lesson.why, icon: Icons.lightbulb_outline),
              const SizedBox(height: 10),
              LessonBox(title: 'Como melhorar', text: lesson.how, icon: Icons.build_outlined),
              if (lesson.current.isNotEmpty || lesson.optimized.isNotEmpty) ...[
                const SizedBox(height: 10),
                BeforeAfterBox(current: lesson.current, optimized: lesson.optimized),
              ],
            ]),
          ),
          const SizedBox(height: 12),
          Row(children: [
            if (page > 0) Expanded(child: OutlinedButton(onPressed: () => setState(() => page -= 1), child: const Text('Voltar'))),
            if (page > 0) const SizedBox(width: 10),
            Expanded(
              flex: 2,
              child: FilledButton(
                onPressed: () {
                  if (page == lessons.length - 1) {
                    Navigator.pop(context);
                  } else {
                    setState(() => page += 1);
                  }
                },
                child: Text(page == lessons.length - 1 ? 'Concluir tutorial' : 'Próxima missão'),
              ),
            ),
          ]),
        ]),
      ),
    );
  }
}
