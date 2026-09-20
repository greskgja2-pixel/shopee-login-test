part of 'main.dart';

class RoasStrategyAdvice {
  final String title;
  final String message;
  final double? grossMarginPct;
  final double? preliminaryBreakEvenRoas;
  final double? suggestedTarget;

  const RoasStrategyAdvice({
    required this.title,
    required this.message,
    this.grossMarginPct,
    this.preliminaryBreakEvenRoas,
    this.suggestedTarget,
  });
}

RoasStrategyAdvice buildRoasStrategy(AnalysisInput input) {
  final currentRoas = input.roas7d;
  final target = input.roasTarget;
  final price = input.price;
  final cost = input.effectiveProductCost;

  // Premissa comercial adotada pelo Super Anúncio conforme configuração do projeto:
  // 20% sobre o valor da venda + R$ 4,00 por item vendido.
  // O custo informado pelo usuário deve representar o custo total próprio da venda
  // (produto, embalagem e outros custos que ele queira considerar), sem somar novamente
  // a comissão e a tarifa fixa abaixo.
  const shopeeCommissionRate = 0.20;
  const shopeeFixedFee = 4.00;

  double? margin;
  double? breakEven;
  if (price != null && price > 0 && cost != null && cost >= 0) {
    final shopeeFees = (price * shopeeCommissionRate) + shopeeFixedFee;
    final contributionBeforeAds = price - cost - shopeeFees;
    margin = contributionBeforeAds / price;
    if (margin > 0) breakEven = 1 / margin;
  }

  // Reserva de 15% acima do ROAS de equilíbrio estimado para evitar sugerir
  // uma meta exatamente no limite calculado.
  final double? safeFloor = breakEven == null ? null : breakEven * 1.15;

  if (margin != null && margin <= 0) {
    return RoasStrategyAdvice(
      title: 'A venda não deixa margem para Ads',
      message: 'Com o preço e o custo informados, após considerar 20% da Shopee + R\$ 4 por venda, não sobra margem estimada para publicidade. Revise preço e custos antes de reduzir a Meta de ROAS ou buscar mais volume.',
      grossMarginPct: margin * 100,
    );
  }

  if (breakEven != null && currentRoas != null && currentRoas < breakEven) {
    return RoasStrategyAdvice(
      title: 'Proteja a margem antes de buscar mais volume',
      message: 'Considerando o custo informado, 20% da Shopee e R\$ 4 por venda, o ROAS atual está abaixo do ponto de equilíbrio estimado. Não recomendamos reduzir a Meta de ROAS agora. Revise preço, custos, criativo e conversão antes de aumentar a agressividade dos anúncios.',
      grossMarginPct: margin! * 100,
      preliminaryBreakEvenRoas: breakEven,
    );
  }

  if (breakEven != null && target != null && target < breakEven) {
    return RoasStrategyAdvice(
      title: 'Meta de ROAS abaixo do limite estimado',
      message: 'A Meta de ROAS informada está abaixo do ponto de equilíbrio estimado considerando custo, 20% da Shopee e R\$ 4 por venda. Subir a meta é mais prudente para proteger a margem. Evite alterações frequentes durante a fase de aprendizado da campanha.',
      grossMarginPct: margin! * 100,
      preliminaryBreakEvenRoas: breakEven,
      suggestedTarget: safeFloor,
    );
  }

  if (target != null && currentRoas != null) {
    final double fulfillment = target <= 0 ? 0.0 : currentRoas / target;

    if (fulfillment >= 1.05) {
      double? suggested;
      if (safeFloor != null) {
        suggested = math.max(safeFloor, target * .90).toDouble();
        if (suggested >= target * .98) suggested = null;
      } else {
        suggested = target * .90;
      }
      return RoasStrategyAdvice(
        title: 'A campanha está cumprindo a meta',
        message: suggested == null
            ? 'O ROAS atual está acima da meta. Mantenha a configuração enquanto a campanha estiver aprendendo. Depois de estabilizar, se o objetivo for ganhar mais volume, teste mudanças pequenas e acompanhe por 7 a 14 dias.'
            : 'O ROAS atual está acima da meta. Se o anúncio estiver com pouco volume e a campanha já estiver estabilizada, existe espaço para testar uma redução gradual da Meta de ROAS para buscar mais tráfego e vendas, sem descer do limite de rentabilidade estimado.',
        grossMarginPct: margin == null ? null : margin * 100,
        preliminaryBreakEvenRoas: breakEven,
        suggestedTarget: suggested,
      );
    }

    if (fulfillment < .80) {
      final canLower = safeFloor == null || target * .90 > safeFloor;
      final double? suggested = canLower ? math.max(safeFloor ?? 0.0, target * .90).toDouble() : null;
      return RoasStrategyAdvice(
        title: canLower ? 'A meta pode estar restritiva' : 'Não reduza a meta sem revisar a margem',
        message: canLower
            ? 'O ROAS real está bem abaixo da meta. Metas muito altas podem limitar tráfego e gasto. Se a campanha já saiu da fase de aprendizado e o objetivo for ganhar volume, teste uma redução pequena, monitore por vários dias e evite mudanças frequentes.'
            : 'O ROAS real está abaixo da meta, mas a margem estimada após custo + taxas da Shopee não deixa espaço seguro para reduzir muito a Meta de ROAS. Priorize melhorar conversão, preço e custos antes de buscar mais volume.',
        grossMarginPct: margin == null ? null : margin * 100,
        preliminaryBreakEvenRoas: breakEven,
        suggestedTarget: suggested,
      );
    }

    return RoasStrategyAdvice(
      title: 'Meta e ROAS estão próximos',
      message: 'A campanha está operando perto da Meta de ROAS. Evite ajustes frequentes. Acompanhe um período de 7 a 14 dias e só altere a meta de forma gradual depois que o desempenho estiver estabilizado.',
      grossMarginPct: margin == null ? null : margin * 100,
      preliminaryBreakEvenRoas: breakEven,
    );
  }

  if (target != null) {
    return RoasStrategyAdvice(
      title: 'Meta registrada para comparação',
      message: 'Quando você informar também o ROAS real dos últimos 7 dias, o Super Anúncio poderá comparar resultado versus meta e sugerir se vale manter, aumentar ou reduzir a Meta de ROAS. O limite de rentabilidade considera o custo informado + 20% da Shopee + R\$ 4 por venda.',
      grossMarginPct: margin == null ? null : margin * 100,
      preliminaryBreakEvenRoas: breakEven,
    );
  }

  return RoasStrategyAdvice(
    title: 'Use uma meta compatível com sua margem',
    message: 'Informe a Meta de ROAS atual para acompanhar o desempenho nas próximas reanálises. Quando houver custo e preço disponíveis, o limite estimado de rentabilidade considera também 20% da Shopee + R\$ 4 por venda.',
    grossMarginPct: margin == null ? null : margin * 100,
    preliminaryBreakEvenRoas: breakEven,
  );
}
