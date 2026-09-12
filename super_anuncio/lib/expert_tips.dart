part of 'main.dart';

class ExpertTips {
  static const Map<String, List<String>> _tips = {
    'Título': [
      'Comece pelo que o produto é e priorize as palavras que ajudam o comprador a identificar produto, marca/modelo e principal diferencial.',
      'Evite repetir palavras, encher de termos soltos ou usar frases promocionais que não ajudam a identificar o produto.',
      'Pense primeiro em leitura no celular: clareza e informação útil valem mais do que um título enorme.',
    ],
    'Descrição': [
      'Organize a descrição para responder rapidamente: o que é, para quem serve, benefícios, medidas/especificações, compatibilidade e o que acompanha.',
      'Transforme características em benefícios, mas use apenas informações verdadeiras e confirmadas.',
      'Use blocos curtos, listas e subtítulos para o comprador localizar informações sem precisar ler um paredão de texto.',
    ],
    'Imagens': [
      'Capa: produto inteiro, nítido, bem iluminado, em destaque e sem elementos que confundam o que está sendo vendido.',
      'Sequência sugerida: capa → ângulos/detalhes → produto em uso → medidas/escala → variações → itens do kit/embalagem → prova de confiança quando fizer sentido.',
      'Mostre textura, acabamento e detalhes importantes; fotos repetidas ocupam espaço sem responder novas dúvidas.',
      'Inclua uma imagem de escala ou medidas para reduzir a dúvida sobre tamanho e evitar expectativa errada.',
      'Se for kit, deixe muito claro o que acompanha. Não mostre acessórios como se estivessem inclusos quando não estão.',
      'Como referência técnica, prefira imagens quadradas, de alta resolução, com boa luz, foco e fundo limpo.',
    ],
    'Vídeo': [
      'Use o vídeo para mostrar o que a foto não explica tão bem: funcionamento, movimento, montagem, textura, tamanho real e forma de uso.',
      'Comece mostrando o produto rapidamente; vídeos longos que demoram para chegar ao ponto tendem a perder atenção.',
      'Mostre somente itens e benefícios reais do produto anunciado.',
    ],
    'Categoria': [
      'Escolha a subcategoria mais específica que realmente representa o produto.',
      'Categoria correta ajuda a busca, os filtros e os atributos certos a aparecerem para o comprador.',
      'Se concorrentes equivalentes estão concentrados em outra subcategoria, vale revisar antes de mudar.',
    ],
    'Preço e concorrência': [
      'Compare produtos equivalentes de verdade: mesmo tipo, quantidade, material, tamanho e nível de entrega.',
      'Não entre em guerra de preço automaticamente. Conteúdo, reputação, frete, prazo, cupom e qualidade percebida também mudam a conversão.',
      'Use a faixa/mediana dos concorrentes como referência e teste alterações pequenas, uma por vez.',
    ],
    'Prova social': [
      'Avaliações reais, fotos de compradores e respostas claras reduzem a insegurança antes da compra.',
      'Observe reclamações recorrentes: elas mostram quais dúvidas precisam ser respondidas melhor no anúncio.',
      'Não invente depoimentos nem transforme comentário em promessa que o produto não consegue cumprir.',
    ],
    'Atributos, estoque e variações': [
      'Preencha atributos que ajudam o comprador a filtrar e comparar, como material, tamanho, compatibilidade, cor e modelo.',
      'Dê nomes claros às variações; evite códigos internos que o comprador não entende.',
      'Mantenha estoque e variações coerentes para não gerar escolha errada ou cancelamento.',
    ],
    'Ads e eficiência': [
      'Antes de aumentar orçamento, confirme se a página do produto está convertendo bem o tráfego que já recebe.',
      'Compare ROAS e gasto em uma janela consistente; evite concluir com base em poucas horas ou em um único dia atípico.',
      'Ao otimizar, mude uma coisa importante por vez para conseguir entender o que realmente melhorou ou piorou o resultado.',
    ],
  };

  static List<String> forDimension(String name) => _tips[name] ?? const [
        'Compare o seu anúncio com produtos equivalentes e priorize mudanças que reduzam dúvidas do comprador.',
        'Faça uma alteração relevante por vez e reanalise depois para medir o efeito.',
      ];
}

class ExpertTipsPanel extends StatelessWidget {
  final String dimensionName;
  const ExpertTipsPanel({super.key, required this.dimensionName});

  @override
  Widget build(BuildContext context) {
    final tips = ExpertTips.forDimension(dimensionName);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.secondaryContainer.withOpacity(.35),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(children: [
            Icon(Icons.lightbulb_outline, size: 19),
            SizedBox(width: 7),
            Text('Dicas de especialistas', style: TextStyle(fontWeight: FontWeight.w900)),
          ]),
          const SizedBox(height: 8),
          for (final tip in tips) ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.only(top: 7),
                  child: Icon(Icons.circle, size: 5),
                ),
                const SizedBox(width: 8),
                Expanded(child: Text(tip)),
              ],
            ),
            if (tip != tips.last) const SizedBox(height: 7),
          ],
        ],
      ),
    );
  }
}

Future<void> showExpertTips(BuildContext context, String dimensionName) async {
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(18, 0, 18, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(dimensionName, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900)),
            const SizedBox(height: 12),
            ExpertTipsPanel(dimensionName: dimensionName),
          ],
        ),
      ),
    ),
  );
}
