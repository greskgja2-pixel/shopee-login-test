from pathlib import Path

root = Path('build_super_anuncio/lib')

def replace(path, old, new):
    p = root / path
    text = p.read_text(encoding='utf-8')
    if old not in text:
        raise SystemExit(f'Padrao nao encontrado em {path}: {old[:100]!r}')
    p.write_text(text.replace(old, new, 1), encoding='utf-8')

# CAPTCHA no coletor: o clique manual precisa SEMPRE forçar um novo enquadramento.
replace('shopee_web_collector_v2.dart',
"""  Future<void> _focusChallengeOnce() async {
    try { await controller.runJavaScript(_centerVerificationScript); } catch (_) {}
  }
""",
"""  Future<void> _focusChallengeOnce() async {
    try {
      await controller.runJavaScript("window.__SA_CAPTCHA_FOCUSED__=false;");
      await controller.runJavaScript(_centerVerificationScript);
      await Future.delayed(const Duration(milliseconds: 260));
      await controller.runJavaScript("window.__SA_CAPTCHA_FOCUSED__=false;");
      await controller.runJavaScript(_centerVerificationScript);
    } catch (_) {}
  }
""")

# CAPTCHA no gate inicial: mesma correção para o botão Centralizar.
replace('shopee_verification_gate.dart',
"""  Future<void> _focusChallengeOnce() async {
    try {
      await controller.runJavaScript(_focusChallengeScript);
    } catch (_) {}
  }
""",
"""  Future<void> _focusChallengeOnce() async {
    try {
      await controller.runJavaScript("window.__SA_CAPTCHA_FOCUSED__=false;");
      await controller.runJavaScript(_focusChallengeScript);
      await Future.delayed(const Duration(milliseconds: 260));
      await controller.runJavaScript("window.__SA_CAPTCHA_FOCUSED__=false;");
      await controller.runJavaScript(_focusChallengeScript);
    } catch (_) {}
  }
""")

# Centralização horizontal/vertical usando a posição atual do desafio no viewport.
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

print('Correcoes finais v1.5.7 aplicadas ao build.')
