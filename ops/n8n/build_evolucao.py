"""Monta o workflow "CortexGen Evolução" a partir do export do bot (Evolução da IA).

    docker exec n8n-y4jd-n8n-1 n8n export:workflow --id=pd5V9pdaldRLUu4C --output=/tmp/wf.json
    python3 build_evolucao.py wf.json wf-evolucao.json [id]   # na pasta ops/n8n; com id, atualiza o existente
    docker exec n8n-y4jd-n8n-1 n8n import:workflow --input=/tmp/wf-evolucao.json   # entra desativado: publicar

    Todo dia 3h (fuso do workflow: America/Panama; o n8n roda em New York) -> Candidatos -> MontaEvolucao -> EscolheProvider
      -> LLMEvolucao (OpenRouter, credencial do n8n) | LLMEvolucaoCustom -> GravaEvolucao

Antes de publicar: db/botlayer/bot_ai_evolution.sql no supabase-db (kind
'evolution' no Uso de IA). Para rodar fora do horario (conta de demonstracao),
"Execute workflow" na tela do n8n.

O IF e os dois nos HTTP de LLM sao clonados do workflow do bot, com a mesma
credencial do OpenRouter, como no build_followup.py. Workflow agendado: depois
do Publish, `docker restart` no n8n (o import nao para o Schedule antigo).
"""
import copy
import json
import secrets
import string
import sys
import uuid
from pathlib import Path

HERE = Path(__file__).parent
src, dst = sys.argv[1], sys.argv[2]
wf_existente = sys.argv[3] if len(sys.argv) > 3 else None

bot = json.load(open(src))
bot = bot[0] if isinstance(bot, list) else bot
do_bot = {n['name']: n for n in bot['nodes']}
nodes = []


def add(name, x, **campos):
    node = {'id': str(uuid.uuid4()), 'name': name, 'position': [x, 300]}
    node.update(campos)
    nodes.append(node)


def code(name, script, x):
    add(name, x, type='n8n-nodes-base.code', typeVersion=2, parameters={'jsCode': (HERE / script).read_text()})


def clone(name, modelo, x, y):
    node = copy.deepcopy(do_bot[modelo])
    node.update({'id': str(uuid.uuid4()), 'name': name, 'position': [x, y]})
    nodes.append(node)


add('Todo dia', 0, type='n8n-nodes-base.scheduleTrigger', typeVersion=1.2,
    parameters={'rule': {'interval': [{'field': 'cronExpression', 'expression': '0 3 * * *'}]}})
code('Candidatos', 'evolucao_candidatos.js', 220)
code('MontaEvolucao', 'evolucao_monta.js', 440)
clone('EscolheProvider', 'EscolheProvider', 660, 300)
clone('LLMEvolucao', 'LLM', 880, 200)
clone('LLMEvolucaoCustom', 'LLMCustom', 880, 400)
# Uma rodada leva até 10 conversas e 3000 tokens de saída: os 60 s do bot não bastam.
for node in nodes:
    if node['name'] in ('LLMEvolucao', 'LLMEvolucaoCustom'):
        node['parameters'].setdefault('options', {})['timeout'] = 180000
code('GravaEvolucao', 'evolucao_grava.js', 1100)


def link(a, *saidas):
    return a, {'main': [[{'node': b, 'type': 'main', 'index': 0}] for b in saidas]}


wf_id = wf_existente or ''.join(secrets.choice(string.ascii_letters + string.digits) for _ in range(16))

wf = {
    'id': wf_id,
    'name': 'CortexGen Evolução',
    'nodes': nodes,
    'connections': dict([
        link('Todo dia', 'Candidatos'),
        link('Candidatos', 'MontaEvolucao'),
        link('MontaEvolucao', 'EscolheProvider'),
        link('EscolheProvider', 'LLMEvolucao', 'LLMEvolucaoCustom'),
        link('LLMEvolucao', 'GravaEvolucao'),
        link('LLMEvolucaoCustom', 'GravaEvolucao'),
    ]),
    'settings': dict(bot.get('settings') or {'executionOrder': 'v1'}, timezone='America/Panama'),
    'active': False,
}
json.dump([wf], open(dst, 'w'), ensure_ascii=False, indent=2)
print('ok:', dst)
