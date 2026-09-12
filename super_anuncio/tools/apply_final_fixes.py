from pathlib import Path

root = Path('build_super_anuncio/lib')

# Mensagem simples junto ao custo informado pelo usuario.
wizard = root / 'wizard_screen.dart'
text = wizard.read_text(encoding='utf-8')
old = "const Text('Esse valor ajuda o app a estimar um limite preliminar de rentabilidade para Ads. Taxas, impostos, frete, embalagem e outros custos variáveis não entram automaticamente nessa conta.', style: TextStyle(fontSize: 12)),"
new = "const Text('Informe aqui seu custo total próprio por venda: produto, embalagem e outros custos que você queira considerar. Não inclua os 20% + R\\$ 4 da Shopee, pois o app já calcula essas taxas automaticamente.', style: TextStyle(fontSize: 12)),"
if old not in text:
    raise SystemExit('Texto de custos esperado nao encontrado')
text = text.replace(old, new, 1)
wizard.write_text(text, encoding='utf-8')

# Centralizacao robusta do CAPTCHA: sem zoom repetitivo. O enquadramento e feito
# uma vez por desafio e o botao Centralizar pode reaplicar apenas o scroll.
gate = root / 'shopee_verification_gate.dart'
text = gate.read_text(encoding='utf-8')
old = """      const viewportWidth=Math.max(320,window.innerWidth||360);\n      const pageWidth=Math.max(viewportWidth,document.documentElement?.scrollWidth||viewportWidth,document.body?.scrollWidth||viewportWidth);\n      const scale=Math.max(.42,Math.min(.82,(viewportWidth/pageWidth)*.96));\n      if(document.body){\n        document.body.style.zoom=String(scale);\n        document.body.style.transformOrigin='top left';\n      }\n      document.documentElement.style.overflowX='auto';\n\n      setTimeout(()=>{\n        if(target){\n          target.style.scrollMargin='90px';\n          target.scrollIntoView({behavior:'auto',block:'center',inline:'center'});\n          setTimeout(()=>{\n            const r=target.getBoundingClientRect();\n            const left=Math.max(0,window.scrollX+r.left-(window.innerWidth-r.width)/2);\n            const top=Math.max(0,window.scrollY+r.top-(window.innerHeight-r.height)/2);\n            window.scrollTo({left,top,behavior:'auto'});\n          },70);\n        }else{\n          window.scrollTo({left:Math.max(0,(document.documentElement.scrollWidth-window.innerWidth)/2),top:0,behavior:'auto'});\n        }\n      },90);"""
new = """      // A Shopee costuma renderizar o desafio em uma pagina com largura de desktop.\n      // Em vez de aplicar zoom no body, centralizamos o elemento real no viewport\n      // e ajustamos somente o scroll. Isso evita animacao/zoom repetitivo.\n      if(document.body){\n        document.body.style.zoom='';\n        document.body.style.transformOrigin='';\n      }\n      document.documentElement.style.overflowX='auto';\n\n      const centerTarget=()=>{\n        if(target){\n          target.style.scrollMargin='110px';\n          target.scrollIntoView({behavior:'auto',block:'center',inline:'center'});\n          requestAnimationFrame(()=>{\n            const r=target.getBoundingClientRect();\n            const left=Math.max(0,window.scrollX+r.left-(window.innerWidth-r.width)/2);\n            const top=Math.max(0,window.scrollY+r.top-(window.innerHeight-r.height)/2);\n            window.scrollTo(left,top);\n          });\n        }else{\n          const pageWidth=Math.max(window.innerWidth,document.documentElement?.scrollWidth||0,document.body?.scrollWidth||0);\n          window.scrollTo(Math.max(0,(pageWidth-window.innerWidth)/2),0);\n        }\n      };\n      setTimeout(centerTarget,80);\n      setTimeout(centerTarget,260);"""
if old not in text:
    raise SystemExit('Bloco de centralizacao esperado nao encontrado')
text = text.replace(old, new, 1)
gate.write_text(text, encoding='utf-8')
