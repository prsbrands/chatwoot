"""Casos, fase 2, no workflow do bot (pd5V9pdaldRLUu4C): atividade case do Jev,
secao # CASES e caso aberto antes do LLM, rede false_case na revisao e passagem
do tipo que entrega a conversa a equipe.

    docker exec n8n-y4jd-n8n-1 n8n export:workflow --id=pd5V9pdaldRLUu4C --output=/home/node/wf.json
    python3 ops/n8n/patch_casos.py wf.json wf-casos.json [BASE]   # na raiz do repo, precisa do git
    docker exec n8n-y4jd-n8n-1 n8n import:workflow --input=/home/node/wf-casos.json   # recarregar a pagina e publicar

Troca Guard, JevEntrada, MontaPrompt, JevRevisao e Passagem pelo que esta no repo,
e so se o codigo ao vivo for exatamente o do commit BASE (o publicado). O
PrecisaHandoff entrou no repo agora: o ao vivo tem que ser o de antes, abaixo.
Uma edicao feita na tela aborta o script em vez de sumir em silencio.
"""
import json
import subprocess
import sys
from pathlib import Path

BASE = sys.argv[3] if len(sys.argv) > 3 else '95ced4788'
HERE = Path(__file__).parent
NODES = {'Guard': 'guard.js', 'JevEntrada': 'jev_entrada.js', 'MontaPrompt': 'monta_prompt.js', 'JevRevisao': 'jev_revisao.js',
         'Passagem': 'passagem.js', 'PrecisaHandoff': 'precisa_handoff.js'}
PRECISA_HANDOFF_ANTES = """// Keyword, max_turns ou content_filter (Interpreta): a resposta ja saiu,
// e a Passagem resume a conversa com ela.
const i = $('Interpreta').first().json;
if (!i.handoff) return [];
return [{ json: { passagem: { motivo: i.handoffReason, fonte: 'regra', respostaEnviada: i.reply } } }];
"""

src, dst = sys.argv[1], sys.argv[2]
data = json.load(open(src))
wf = data[0] if isinstance(data, list) else data
nodes = {n['name']: n for n in wf['nodes']}


def antes(arquivo):
    if arquivo == 'precisa_handoff.js':
        return PRECISA_HANDOFF_ANTES
    return subprocess.run(['git', 'show', BASE + ':ops/n8n/' + arquivo], capture_output=True, text=True, check=True).stdout


for name, arquivo in NODES.items():
    depois = (HERE / arquivo).read_text()
    ao_vivo = nodes[name]['parameters']['jsCode']
    if ao_vivo == depois:
        continue
    if ao_vivo.strip() != antes(arquivo).strip():
        sys.exit('ABORTADO: ' + name + ' ao vivo nao e o do ' + BASE)
    nodes[name]['parameters']['jsCode'] = depois
    print('trocado:', name)

json.dump(data, open(dst, 'w'), ensure_ascii=False)
