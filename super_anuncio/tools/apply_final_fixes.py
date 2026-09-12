from pathlib import Path

root = Path('build_super_anuncio/lib')

def replace(path, old, new):
    p = root / path
    text = p.read_text(encoding='utf-8')
    if old not in text:
        raise SystemExit(f'Padrao nao encontrado em {path}: {old[:80]!r}')
    p.write_text(text.replace(old, new, 1), encoding='utf-8')

# ROAS: regra operacional do app = custo informado + 20% do preco + R$ 4 por venda.
replace('roas_strategy.dart',
"""  double? margin;
  double? breakEven;
  if (price != null && price > 0 && cost != null && cost >= 0 && cost < price) {
    margin = (price - cost) / price;
    if (margin > 0) breakEven = 1 / margin;
  }

  // O custo informado pelo usuário é apenas o custo do produto. Taxas da
  // plataforma, impostos, embalagem, frete e outros custos variáveis podem
  // elevar o ROAS real de equilíbrio. Por isso a recomendação nunca trata
  // este número como margem de contribuição completa.
""",
"""  double? margin;
  double? breakEven;
  if (price != null && price > 0 && cost != null && cost >= 0) {
    const shopeePercentFee = 0.20;
    const shopeeFixedFeePerSale = 4.0;
    final contribution = price - cost - (price * shopeePercentFee) - shopeeFixedFeePerSale;
    margin = contribution / price;
    if (margin > 0) breakEven = 1 / margin;
  }

  // O ponto de equilibrio considera 20% sobre o preco + R$ 4 por venda,
  // alem do custo total informado pelo usuario. Outros custos que nao estejam
  // embutidos no campo de custo continuam fora da estimativa.
""")
replace('roas_strategy.dart',
"O cálculo ainda não inclui taxas, impostos, frete ou outros custos variáveis.",
"A estimativa já considera 20% da Shopee + R$ 4 por venda; outros custos não informados continuam fora da conta.")
replace('roas_strategy.dart',
"calculado apenas com preço e custo do produto. Subir a meta é mais prudente até você incluir os demais custos variáveis.",
"calculado com preço, custo informado, 20% da Shopee e R$ 4 por venda. Subir a meta é mais prudente se a rentabilidade estiver apertada.")

# Campo de custo: mensagem curta para lembrar produto, embalagem e materiais.
replace('wizard_screen.dart',
"subtitle: const Text('Preencha só se você souber o custo do produto.'),",
"subtitle: const Text('Informe, se possível, o custo total que você tem para preparar uma venda.'),")
replace('wizard_screen.dart',
"InputBox(controller: productCost, label: 'Custo do produto', icon: Icons.inventory_2_outlined, keyboardType: const TextInputType.numberWithOptions(decimal: true)),\n              const SizedBox(height: 10),\n              const Text('Esse valor ajuda o app a estimar um limite preliminar de rentabilidade para Ads. Taxas, impostos, frete, embalagem e outros custos variáveis não entram automaticamente nessa conta.', style: TextStyle(fontSize: 12)),",
"InputBox(controller: productCost, label: 'Custo total do produto', icon: Icons.inventory_2_outlined, keyboardType: const TextInputType.numberWithOptions(decimal: true)),\n              const SizedBox(height: 8),\n              const NoticeBox(icon: Icons.info_outline, text: 'Considere o que sai do seu bolso por venda: produto, embalagem, etiqueta, proteção e outros materiais. Não inclua aqui os 20% + R\\$ 4 da Shopee: o app já considera essas taxas automaticamente.'),")

# CAPTCHA: centraliza pelo centro real do elemento no viewport, sem zoom repetitivo.
old_center = """const r=target.getBoundingClientRect();
        const left=Math.max(0,window.scrollX+r.left-(innerWidth-r.width)/2);
        const top=Math.max(0,window.scrollY+r.top-(innerHeight-r.height)/2);
        window.scrollTo({left,top,behavior:'auto'});"""
new_center = """const r=target.getBoundingClientRect();
        const dx=r.left+(r.width/2)-(window.innerWidth/2);
        const dy=r.top+(r.height/2)-(window.innerHeight/2);
        window.scrollBy({left:dx,top:dy,behavior:'auto'});"""
replace('shopee_web_collector_v2.dart', old_center, new_center)

old_gate = """const r=target.getBoundingClientRect();
            const left=Math.max(0,window.scrollX+r.left-(window.innerWidth-r.width)/2);
            const top=Math.max(0,window.scrollY+r.top-(window.innerHeight-r.height)/2);
            window.scrollTo({left,top,behavior:'auto'});"""
new_gate = """const r=target.getBoundingClientRect();
            const dx=r.left+(r.width/2)-(window.innerWidth/2);
            const dy=r.top+(r.height/2)-(window.innerHeight/2);
            window.scrollBy({left:dx,top:dy,behavior:'auto'});"""
replace('shopee_verification_gate.dart', old_gate, new_gate)

print('Correcoes finais aplicadas ao build.')
