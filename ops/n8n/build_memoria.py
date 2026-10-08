"""Monta o workflow "CortexGen Memória" a partir do export do bot.

    docker exec n8n-y4jd-n8n-1 n8n export:workflow --id=pd5V9pdaldRLUu4C --output=/tmp/wf.json
    python3 build_memoria.py wf.json wf-memoria.json [id]   # na pasta ops/n8n; com id, atualiza o existente
    docker exec n8n-y4jd-n8n-1 n8n import:workflow --input=/tmp/wf-memoria.json   # entra desativado: publicar

    A cada 10 min -> Candidatos -> MontaMemoria -> EscolheProvider
      -> LLMMemoria (OpenRouter, credencial do n8n) | LLMMemoriaCustom -> GravaMemoria

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


add('A cada 10 min', 0, type='n8n-nodes-base.scheduleTrigger', typeVersion=1.2,
    parameters={'rule': {'interval': [{'field': 'minutes', 'minutesInterval': 10}]}})
code('Candidatos', 'memoria_candidatos.js', 220)
code('MontaMemoria', 'memoria_monta.js', 440)
clone('EscolheProvider', 'EscolheProvider', 660, 300)
clone('LLMMemoria', 'LLM', 880, 200)
clone('LLMMemoriaCustom', 'LLMCustom', 880, 400)
code('GravaMemoria', 'memoria_grava.js', 1100)


def link(a, *saidas):
    return a, {'main': [[{'node': b, 'type': 'main', 'index': 0}] for b in saidas]}


wf_id = wf_existente or ''.join(secrets.choice(string.ascii_letters + string.digits) for _ in range(16))

wf = {
    'id': wf_id,
    'name': 'CortexGen Memória',
    'nodes': nodes,
    'connections': dict([
        link('A cada 10 min', 'Candidatos'),
        link('Candidatos', 'MontaMemoria'),
        link('MontaMemoria', 'EscolheProvider'),
        link('EscolheProvider', 'LLMMemoria', 'LLMMemoriaCustom'),
        link('LLMMemoria', 'GravaMemoria'),
        link('LLMMemoriaCustom', 'GravaMemoria'),
    ]),
    'settings': bot.get('settings') or {'executionOrder': 'v1'},
    'active': False,
}
json.dump([wf], open(dst, 'w'), ensure_ascii=False, indent=2)
print('ok:', dst)
