part of 'main.dart';

class SaShield extends StatelessWidget {
  final double size;
  const SaShield({super.key, required this.size});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Stack(alignment: Alignment.center, children: [
        Icon(Icons.shield_rounded, size: size, color: const Color(0xFFFFC928), shadows: const [Shadow(color: Colors.black26, offset: Offset(0, 5), blurRadius: 6)]),
        Positioned(top: size * .1, child: Icon(Icons.star, size: size * .19, color: Colors.deepOrange)),
        Positioned(bottom: size * .25, child: Text('SA', style: TextStyle(fontSize: size * .34, color: const Color(0xFF149DE3), fontWeight: FontWeight.w900, shadows: const [Shadow(color: Colors.black38, offset: Offset(2, 2))]))),
      ]),
    );
  }
}

class SuperAnuncioLogo extends StatelessWidget {
  final double fontSize;
  const SuperAnuncioLogo({super.key, required this.fontSize});

  @override
  Widget build(BuildContext context) {
    const letters = [
      ('S', Color(0xFF17A8F5)), ('U', Color(0xFFE94235)), ('P', Color(0xFFFFC928)), ('E', Color(0xFF20B95A)), ('R', Color(0xFFFFB21A)), (' ', Colors.transparent),
      ('A', Color(0xFFE94235)), ('N', Color(0xFFFFC928)), ('Ú', Color(0xFF17A8F5)), ('N', Color(0xFF20B95A)), ('C', Color(0xFFFFB21A)), ('I', Color(0xFFE94235)), ('O', Color(0xFF20B95A)),
    ];
    return FittedBox(
      fit: BoxFit.scaleDown,
      child: Row(mainAxisSize: MainAxisSize.min, children: letters.map((e) => Text(e.$1, style: TextStyle(color: e.$2, fontSize: fontSize, fontWeight: FontWeight.w900, letterSpacing: 1, shadows: const [Shadow(color: Colors.black45, offset: Offset(2, 3))]))).toList()),
    );
  }
}

InputDecoration inputDecoration(String label, IconData icon) => InputDecoration(labelText: label, prefixIcon: Icon(icon), border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)));
