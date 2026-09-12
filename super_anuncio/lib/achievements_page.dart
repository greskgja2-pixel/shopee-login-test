part of 'main.dart';

class AchievementsPage extends StatelessWidget {
  final Set<int> unlocked;
  const AchievementsPage({super.key, required this.unlocked});

  @override
  Widget build(BuildContext context) {
    final main = AchievementEngine.all;
    final secret = SecretAchievementEngine.all;
    final all = [...main, ...secret];
    final mainUnlocked = unlocked.where((id) => id <= 100).length;
    final secretUnlocked = unlocked.where((id) => id > 100).length;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Conquistas', style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w900)),
          const SizedBox(height: 4),
          Text('$mainUnlocked/100 principais • $secretUnlocked/${secret.length} secretas'),
          const SizedBox(height: 12),
          Expanded(
            child: GridView.builder(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 3, crossAxisSpacing: 10, mainAxisSpacing: 10, childAspectRatio: .76),
              itemCount: all.length,
              itemBuilder: (_, i) {
                final a = all[i];
                final active = unlocked.contains(a.id);
                final isSecret = a.id > 100;
                return Container(
                  decoration: BoxDecoration(
                    color: active ? const Color(0xFFFFF8F1) : Theme.of(context).cardColor,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: active ? kOrange : Theme.of(context).dividerColor.withOpacity(.25), width: active ? 2 : 1),
                    boxShadow: active
                        ? [BoxShadow(color: kOrange.withOpacity(.08), blurRadius: 8, offset: const Offset(0, 3))]
                        : null,
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(9),
                    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                      if (active)
                        Stack(
                          alignment: Alignment.topCenter,
                          clipBehavior: Clip.none,
                          children: [
                            const Padding(padding: EdgeInsets.only(top: 8), child: SaShield(size: 48)),
                            Positioned(top: -7, child: Icon(Icons.workspace_premium, color: Colors.amber.shade700, size: 24)),
                          ],
                        )
                      else
                        CircleAvatar(
                          radius: 25,
                          backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
                          child: Icon(isSecret ? Icons.question_mark : Icons.lock_outline, color: Colors.grey, size: 28),
                        ),
                      const SizedBox(height: 9),
                      Text(
                        active || !isSecret ? a.title : '???',
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: active ? const Color(0xFF262626) : Colors.grey),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        active ? 'CONQUISTA DESBLOQUEADA' : isSecret ? 'Conquista secreta' : a.hint,
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(fontSize: 8.5, color: active ? kOrange : null, fontWeight: active ? FontWeight.w800 : FontWeight.normal),
                      ),
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
