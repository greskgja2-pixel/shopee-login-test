part of 'main.dart';

class SettingsPage extends StatelessWidget {
  final bool darkMode;
  final ValueChanged<bool> onDarkModeChanged;
  const SettingsPage({super.key, required this.darkMode, required this.onDarkModeChanged});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ListView(padding: const EdgeInsets.all(18), children: [
        Text('Ajustes', style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w900)),
        const SizedBox(height: 14),
        Card(child: SwitchListTile(value: darkMode, onChanged: onDarkModeChanged, title: const Text('Modo escuro'), secondary: const Icon(Icons.dark_mode_outlined))),
        const SizedBox(height: 12),
        const NoticeBox(icon: Icons.security_outlined, text: 'O app tenta consultar dados públicos da Shopee diretamente. Se a Shopee bloquear a consulta, o preenchimento manual continua disponível para não travar a auditoria.'),
        const SizedBox(height: 12),
        const NoticeBox(icon: Icons.psychology_outlined, text: 'A versão atual usa um motor inteligente local de auditoria. Para uma IA generativa online escrever soluções ainda mais personalizadas, será necessária uma chave/API ou um backend seguro.'),
      ]),
    );
  }
}
