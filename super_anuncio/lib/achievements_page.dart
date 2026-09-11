part of 'main.dart';

class AchievementsPage extends StatelessWidget {
  final Set<int> unlocked;
  const AchievementsPage({super.key, required this.unlocked});

  @override
  Widget build(BuildContext context) {
    final all = AchievementEngine.all;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Conquistas', style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w900)),
          const SizedBox(height: 4),
          Text('${unlocked.length}/100 desbloqueadas'),
          const SizedBox(height: 12),
          Expanded(
            child: GridView.builder(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 3, crossAxisSpacing: 10, mainAxisSpacing: 10, childAspectRatio: .80),
              itemCount: all.length,
              itemBuilder: (_, i) {
                final a = all[i];
                final active = unlocked.contains(a.id);
                return Card(
                  child: Padding(
                    padding: const EdgeInsets.all(10),
                    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                      CircleAvatar(
                        radius: 27,
                        backgroundColor: active ? Colors.amber.withOpacity(.22) : Theme.of(context).colorScheme.surfaceContainerHighest,
                        child: Icon(active ? a.icon : Icons.lock_outline, color: active ? Colors.amber.shade800 : Colors.grey, size: 30),
                      ),
                      const SizedBox(height: 8),
                      Text(a.title, textAlign: TextAlign.center, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: active ? null : Colors.grey)),
                      const SizedBox(height: 3),
                      Text(active ? 'Desbloqueada' : a.hint, textAlign: TextAlign.center, maxLines: 2, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.bodySmall?.copyWith(fontSize: 9)),
                    ]),
                  ),
                );
              },
            ),
          ),
        ]),
      ),
    );
  }
}
