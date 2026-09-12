part of 'main.dart';

class SecretAchievementEngine {
  static const List<AchievementDef> all = [
    AchievementDef(101, 'Código SA', 'Descubra o acesso secreto', Icons.lock_open_outlined),
    AchievementDef(102, 'Pausa estratégica', 'Jogue o minigame pela primeira vez', Icons.rocket_launch_outlined),
    AchievementDef(103, 'Auditor Cósmico', 'Faça 500 pontos no minigame', Icons.auto_awesome),
    AchievementDef(104, 'Sem desperdício', 'Faça 1.000 pontos no minigame', Icons.shield_outlined),
    AchievementDef(105, 'Mestre da conversão', 'Faça 2.000 pontos no minigame', Icons.workspace_premium_outlined),
  ];
}

class SaArcadePage extends StatefulWidget {
  final int highScore;
  final ValueChanged<int> onHighScore;
  final ValueChanged<Set<int>> onUnlock;
  const SaArcadePage({super.key, required this.highScore, required this.onHighScore, required this.onUnlock});

  @override
  State<SaArcadePage> createState() => _SaArcadePageState();
}

class _SaArcadePageState extends State<SaArcadePage> {
  final math.Random rng = math.Random();
  final List<_ArcadeBullet> bullets = [];
  final List<_ArcadeEnemy> enemies = [];
  Timer? loop;
  double shipX = .5;
  int score = 0;
  int lives = 3;
  int tick = 0;
  bool gameOver = false;
  bool muted = false;
  late int highScore;
  final _ArcadeAudio audio = _ArcadeAudio();

  @override
  void initState() {
    super.initState();
    highScore = widget.highScore;
    widget.onUnlock({102});
    _startAudio();
    _startLoop();
  }

  Future<void> _startAudio() async {
    if (!muted) await audio.startRockLoop();
  }

  void _startLoop() {
    loop?.cancel();
    loop = Timer.periodic(const Duration(milliseconds: 16), (_) => _update());
  }

  void _update() {
    if (!mounted || gameOver) return;
    tick++;
    if (tick % 44 == 0) {
      enemies.add(_ArcadeEnemy(x: .08 + rng.nextDouble() * .84, y: -.06, speed: .0024 + rng.nextDouble() * .0022));
    }

    for (final b in bullets) {
      b.y -= .014;
    }
    bullets.removeWhere((b) => b.y < -.08);

    for (final e in enemies) {
      e.y += e.speed;
      e.x += math.sin((tick + e.seed) / 28) * .0008;
    }

    final deadBullets = <_ArcadeBullet>{};
    final deadEnemies = <_ArcadeEnemy>{};
    for (final e in enemies) {
      for (final b in bullets) {
        if ((e.x - b.x).abs() < .045 && (e.y - b.y).abs() < .055) {
          deadBullets.add(b);
          deadEnemies.add(e);
          score += 10;
          if (!muted) audio.explosion();
          break;
        }
      }
    }
    bullets.removeWhere(deadBullets.contains);
    enemies.removeWhere(deadEnemies.contains);

    final escaped = enemies.where((e) => e.y > .93).toList();
    if (escaped.isNotEmpty) {
      enemies.removeWhere(escaped.contains);
      lives -= escaped.length;
      if (!muted) audio.explosion();
      if (lives <= 0) _finishGame();
    }

    if (score >= 500) widget.onUnlock({103});
    if (score >= 1000) widget.onUnlock({104});
    if (score >= 2000) widget.onUnlock({105});

    if (mounted) setState(() {});
  }

  void _shoot() {
    if (gameOver) return;
    bullets.add(_ArcadeBullet(x: shipX, y: .82));
    if (!muted) audio.shot();
  }

  void _move(double dx, double width) {
    if (gameOver || width <= 0) return;
    setState(() => shipX = (shipX + dx / width).clamp(.05, .95).toDouble());
  }

  void _finishGame() {
    gameOver = true;
    if (score > highScore) {
      highScore = score;
      widget.onHighScore(score);
    }
    setState(() {});
  }

  void _restart() {
    setState(() {
      bullets.clear();
      enemies.clear();
      score = 0;
      lives = 3;
      tick = 0;
      shipX = .5;
      gameOver = false;
    });
  }

  Future<void> _toggleMute() async {
    setState(() => muted = !muted);
    if (muted) {
      await audio.stopMusic();
    } else {
      await audio.startRockLoop();
    }
  }

  @override
  void dispose() {
    loop?.cancel();
    audio.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final hearts = List.filled(math.max(0, lives), '♥').join();
    return Scaffold(
      backgroundColor: const Color(0xFF070A18),
      appBar: AppBar(
        backgroundColor: const Color(0xFF070A18),
        foregroundColor: Colors.white,
        title: const Text('SA • Auditor Cósmico'),
        actions: [
          IconButton(onPressed: _toggleMute, icon: Icon(muted ? Icons.volume_off : Icons.volume_up)),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          return Stack(
            children: [
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onPanUpdate: (d) => _move(d.delta.dx, constraints.maxWidth),
                onTap: _shoot,
                child: CustomPaint(
                  size: Size.infinite,
                  painter: _ArcadePainter(shipX: shipX, bullets: bullets, enemies: enemies, tick: tick),
                ),
              ),
              Positioned(
                left: 14,
                right: 14,
                top: 12,
                child: Row(children: [
                  _ArcadeHud(label: 'PONTOS', value: '$score'),
                  const Spacer(),
                  _ArcadeHud(label: 'RECORDE', value: '$highScore'),
                  const SizedBox(width: 14),
                  _ArcadeHud(label: 'VIDAS', value: hearts),
                ]),
              ),
              Positioned(
                left: 18,
                right: 18,
                bottom: 22,
                child: Row(children: [
                  Expanded(child: Text('Arraste para mover • toque para atirar', style: TextStyle(color: Colors.white.withOpacity(.72), fontWeight: FontWeight.w700))),
                  const SizedBox(width: 10),
                  FilledButton.icon(onPressed: _shoot, icon: const Icon(Icons.flash_on), label: const Text('ATIRAR')),
                ]),
              ),
              if (gameOver)
                Positioned.fill(
                  child: ColoredBox(
                    color: Colors.black.withOpacity(.78),
                    child: Center(
                      child: Card(
                        margin: const EdgeInsets.all(26),
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Column(mainAxisSize: MainAxisSize.min, children: [
                            const Icon(Icons.rocket_launch, size: 54, color: kOrange),
                            const SizedBox(height: 12),
                            const Text('Fim da missão', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900)),
                            const SizedBox(height: 8),
                            Text('$score pontos', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
                            Text('Recorde: $highScore'),
                            const SizedBox(height: 18),
                            FilledButton.icon(onPressed: _restart, icon: const Icon(Icons.replay), label: const Text('Jogar novamente')),
                            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Voltar ao trabalho')),
                          ]),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _ArcadeHud extends StatelessWidget {
  final String label;
  final String value;
  const _ArcadeHud({required this.label, required this.value});
  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: TextStyle(fontSize: 9, color: Colors.white.withOpacity(.62), fontWeight: FontWeight.w900)),
        Text(value, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 16)),
      ]);
}

class _ArcadeBullet {
  double x;
  double y;
  _ArcadeBullet({required this.x, required this.y});
}

class _ArcadeEnemy {
  double x;
  double y;
  final double speed;
  final double seed = math.Random().nextDouble() * 1000;
  _ArcadeEnemy({required this.x, required this.y, required this.speed});
}

class _ArcadePainter extends CustomPainter {
  final double shipX;
  final List<_ArcadeBullet> bullets;
  final List<_ArcadeEnemy> enemies;
  final int tick;
  _ArcadePainter({required this.shipX, required this.bullets, required this.enemies, required this.tick});

  @override
  void paint(Canvas canvas, Size size) {
    final stars = Paint()..color = Colors.white.withOpacity(.55);
    for (var i = 0; i < 45; i++) {
      final x = ((i * 83 + tick * (i % 3 + 1) * .25) % size.width);
      final y = ((i * 137 + tick * (i % 4 + 1) * .45) % size.height);
      canvas.drawCircle(Offset(x, y), i % 6 == 0 ? 1.7 : .8, stars);
    }

    final ship = Path()
      ..moveTo(shipX * size.width, size.height * .80)
      ..lineTo(shipX * size.width - 24, size.height * .87)
      ..lineTo(shipX * size.width, size.height * .855)
      ..lineTo(shipX * size.width + 24, size.height * .87)
      ..close();
    canvas.drawPath(ship, Paint()..color = kOrange);
    canvas.drawCircle(Offset(shipX * size.width, size.height * .835), 9, Paint()..color = Colors.white);
    final flame = Path()
      ..moveTo(shipX * size.width - 8, size.height * .858)
      ..lineTo(shipX * size.width, size.height * (.89 + (tick % 5) * .002))
      ..lineTo(shipX * size.width + 8, size.height * .858)
      ..close();
    canvas.drawPath(flame, Paint()..color = Colors.amber);

    final bulletPaint = Paint()..color = Colors.lightGreenAccent..strokeWidth = 4..strokeCap = StrokeCap.round;
    for (final b in bullets) {
      final x = b.x * size.width;
      final y = b.y * size.height;
      canvas.drawLine(Offset(x, y), Offset(x, y - 15), bulletPaint);
    }

    for (final e in enemies) {
      final center = Offset(e.x * size.width, e.y * size.height);
      canvas.drawCircle(center, 19, Paint()..color = const Color(0xFF8E44AD));
      canvas.drawRect(Rect.fromCenter(center: center, width: 30, height: 10), Paint()..color = Colors.redAccent);
      final tp = TextPainter(
        text: const TextSpan(text: 'R$', style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w900)),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, center - Offset(tp.width / 2, tp.height / 2));
    }
  }

  @override
  bool shouldRepaint(covariant _ArcadePainter oldDelegate) => true;
}

class _ArcadeAudio {
  final AudioPlayer music = AudioPlayer();
  final AudioPlayer shotPlayer = AudioPlayer();
  final AudioPlayer boomPlayer = AudioPlayer();
  Uint8List? _musicBytes;
  Uint8List? _shotBytes;
  Uint8List? _boomBytes;

  Future<void> startRockLoop() async {
    try {
      _musicBytes ??= _SynthAudio.rockLoop();
      await music.stop();
      await music.setReleaseMode(ReleaseMode.loop);
      await music.setVolume(.28);
      await music.play(BytesSource(_musicBytes!));
    } catch (_) {}
  }

  Future<void> stopMusic() async {
    try { await music.stop(); } catch (_) {}
  }

  Future<void> shot() async {
    try {
      _shotBytes ??= _SynthAudio.shot();
      await shotPlayer.stop();
      await shotPlayer.setVolume(.35);
      await shotPlayer.play(BytesSource(_shotBytes!));
    } catch (_) {}
  }

  Future<void> explosion() async {
    try {
      _boomBytes ??= _SynthAudio.explosion();
      await boomPlayer.stop();
      await boomPlayer.setVolume(.45);
      await boomPlayer.play(BytesSource(_boomBytes!));
    } catch (_) {}
  }

  Future<void> dispose() async {
    await music.dispose();
    await shotPlayer.dispose();
    await boomPlayer.dispose();
  }
}

class _SynthAudio {
  static const int rate = 11025;

  static Uint8List rockLoop() {
    const seconds = 4.0;
    final count = (rate * seconds).round();
    final samples = Int16List(count);
    final notes = [110.0, 146.83, 164.81, 146.83, 110.0, 196.0, 164.81, 146.83];
    final rnd = math.Random(7);
    for (var i = 0; i < count; i++) {
      final t = i / rate;
      final step = ((t / .5).floor()) % notes.length;
      final f = notes[step];
      final guitar = math.sin(2 * math.pi * f * t) >= 0 ? .24 : -.24;
      final harmonic = math.sin(2 * math.pi * f * 2 * t) * .08;
      final beat = t % .5;
      final kick = beat < .10 ? math.sin(2 * math.pi * (72 - beat * 220) * t) * (.10 - beat) * 4.3 : 0.0;
      final snarePhase = t % 1.0;
      final snare = (snarePhase > .48 && snarePhase < .58) ? (rnd.nextDouble() * 2 - 1) * (.58 - snarePhase) * 2.6 : 0.0;
      final v = (guitar + harmonic + kick + snare).clamp(-.95, .95);
      samples[i] = (v * 32767).round();
    }
    return _wav(samples, rate);
  }

  static Uint8List shot() {
    final samples = Int16List((rate * .11).round());
    for (var i = 0; i < samples.length; i++) {
      final t = i / rate;
      final env = 1 - i / samples.length;
      final f = 1050 - 620 * (i / samples.length);
      samples[i] = (math.sin(2 * math.pi * f * t) * env * 25000).round();
    }
    return _wav(samples, rate);
  }

  static Uint8List explosion() {
    final rnd = math.Random();
    final samples = Int16List((rate * .32).round());
    double low = 0;
    for (var i = 0; i < samples.length; i++) {
      final env = math.pow(1 - i / samples.length, 2).toDouble();
      final noise = rnd.nextDouble() * 2 - 1;
      low = low * .72 + noise * .28;
      samples[i] = (low * env * 29000).round();
    }
    return _wav(samples, rate);
  }

  static Uint8List _wav(Int16List samples, int sampleRate) {
    final bytes = ByteData(44 + samples.length * 2);
    void s(int o, String v) {
      for (var i = 0; i < v.length; i++) bytes.setUint8(o + i, v.codeUnitAt(i));
    }
    s(0, 'RIFF');
    bytes.setUint32(4, 36 + samples.length * 2, Endian.little);
    s(8, 'WAVE');
    s(12, 'fmt ');
    bytes.setUint32(16, 16, Endian.little);
    bytes.setUint16(20, 1, Endian.little);
    bytes.setUint16(22, 1, Endian.little);
    bytes.setUint32(24, sampleRate, Endian.little);
    bytes.setUint32(28, sampleRate * 2, Endian.little);
    bytes.setUint16(32, 2, Endian.little);
    bytes.setUint16(34, 16, Endian.little);
    s(36, 'data');
    bytes.setUint32(40, samples.length * 2, Endian.little);
    for (var i = 0; i < samples.length; i++) {
      bytes.setInt16(44 + i * 2, samples[i], Endian.little);
    }
    return bytes.buffer.asUint8List();
  }
}
