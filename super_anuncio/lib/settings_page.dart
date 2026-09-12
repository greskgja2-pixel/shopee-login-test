part of 'main.dart';

class SettingsPage extends StatelessWidget {
  final bool darkMode;
  final ValueChanged<bool> onDarkModeChanged;
  final bool shopeeConnected;
  final Future<void> Function(bool) onShopeeConnectionChanged;
  const SettingsPage({super.key, required this.darkMode, required this.onDarkModeChanged, required this.shopeeConnected, required this.onShopeeConnectionChanged});

  Future<void> _openConnection(BuildContext context, {bool verifyOnly = false, bool clearFirst = false}) async {
    final connected = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => ShopeeConnectionPage(verifyOnly: verifyOnly, clearSessionFirst: clearFirst)),
    );
    if (connected == true) await onShopeeConnectionChanged(true);
  }

  Future<void> _disconnect(BuildContext context) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Sair da Shopee neste aparelho?'),
        content: const Text('Isso apaga os cookies da sessão usada pelo Super Anúncio. Sua conta e senha da Shopee não são alteradas.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Sair')),
        ],
      ),
    );
    if (confirm != true) return;
    await ShopeeSession.disconnect();
    await onShopeeConnectionChanged(false);
    if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Sessão da Shopee removida deste aparelho.')));
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return SafeArea(
      child: ListView(padding: const EdgeInsets.all(18), children: [
        Text('Ajustes', style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w900)),
        const SizedBox(height: 14),
        Card(child: SwitchListTile(value: darkMode, onChanged: onDarkModeChanged, title: const Text('Modo escuro'), secondary: const Icon(Icons.dark_mode_outlined))),
        const SizedBox(height: 18),
        Text('Conta Shopee', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900)),
        const SizedBox(height: 10),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(children: [
                  Icon(shopeeConnected ? Icons.check_circle : Icons.link_off, color: shopeeConnected ? Colors.green.shade700 : cs.error),
                  const SizedBox(width: 10),
                  Expanded(child: Text(shopeeConnected ? 'Shopee conectada' : 'Shopee não conectada', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 17))),
                ]),
                const SizedBox(height: 8),
                Text(shopeeConnected ? 'A sessão do navegador interno está disponível para leitura dos anúncios e pesquisa de concorrentes.' : 'Conecte uma conta da Shopee para tornar a coleta automática mais confiável.'),
                const SizedBox(height: 14),
                if (!shopeeConnected)
                  FilledButton.icon(onPressed: () => _openConnection(context), icon: const Icon(Icons.login), label: const Text('Conectar à Shopee')),
                if (shopeeConnected) ...[
                  OutlinedButton.icon(onPressed: () => _openConnection(context, verifyOnly: true), icon: const Icon(Icons.verified_user_outlined), label: const Text('Verificar conexão')),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(onPressed: () => _openConnection(context, clearFirst: true), icon: const Icon(Icons.switch_account_outlined), label: const Text('Trocar conta')),
                  const SizedBox(height: 8),
                  TextButton.icon(onPressed: () => _disconnect(context), icon: const Icon(Icons.logout), label: const Text('Sair da Shopee')),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        const NoticeBox(icon: Icons.security_outlined, text: 'O login acontece dentro do site oficial da Shopee em uma WebView. O Super Anúncio não recebe nem armazena sua senha; ele apenas reutiliza a sessão/cookies salvos no aparelho.'),
        const SizedBox(height: 12),
        const NoticeBox(icon: Icons.psychology_outlined, text: 'A auditoria inteligente é processada pelos sistemas do Super Anúncio. As credenciais e integrações ficam protegidas no servidor e não são gravadas dentro do APK.'),
        const SizedBox(height: 20),
        Card(
          color: cs.primaryContainer.withOpacity(.22),
          child: const Padding(
            padding: EdgeInsets.symmetric(horizontal: 18, vertical: 20),
            child: Column(children: [
              SaShield(size: 54),
              SizedBox(height: 10),
              Text('By Gresk 2026', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900)),
              SizedBox(height: 8),
              Text('Que Deus e família seja sua prioridade.', textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.w700)),
              SizedBox(height: 3),
              Text('Gresk 2026', style: TextStyle(fontWeight: FontWeight.w700)),
            ]),
          ),
        ),
        const SizedBox(height: 18),
      ]),
    );
  }
}
