"""Monta o workflow "CortexGen Caso" a partir do export do bot (casos, fase 2).

    docker exec n8n-y4jd-n8n-1 n8n export:workflow --id=pd5V9pdaldRLUu4C --output=/tmp/wf.json
    python3 build_caso.py wf.json wf-caso.json [id]   # na pasta ops/n8n; com id, atualiza o existente
    docker exec n8n-y4jd-n8n-1 n8n import:workflow --input=/tmp/wf-caso.json   # entra desativado: publicar

    A cada minuto -> Candidatos -> MontaRepasse -> EscolheProvider
      -> LLMRepasse (OpenRouter, credencial do n8n) | LLMRepasseCustom -> EnviaRepasse

A equipe escreve no caso o que a IA deve dizer ao cliente (Cases::CaseFlow#relay!);
o workflow reserva, a persona reescreve no idioma e no tom da conversa e posta como
o bot. O IF e os dois nos HTTP de LLM sao clonados do workflow do bot, com a mesma
credencial do OpenRouter, como no build_memoria.py. Workflow agendado: depois do
Publish, `docker restart` no n8n (o import nao para o Schedule antigo).
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


add('A cada minuto', 0, type='n8n-nodes-base.scheduleTrigger', typeVersion=1.2,
    parameters={'rule': {'interval': [{'field': 'minutes', 'minutesInterval': 1}]}})
code('Candidatos', 'caso_candidatos.js', 220)
code('MontaRepasse', 'caso_monta.js', 440)
clone('EscolheProvider', 'EscolheProvider', 660, 300)
clone('LLMRepasse', 'LLM', 880, 200)
clone('LLMRepasseCustom', 'LLMCustom', 880, 400)
code('EnviaRepasse', 'caso_envia.js', 1100)


def link(a, *saidas):
    return a, {'main': [[{'node': b, 'type': 'main', 'index': 0}] for b in saidas]}


wf_id = wf_existente or ''.join(secrets.choice(string.ascii_letters + string.digits) for _ in range(16))

wf = {
    'id': wf_id,
    'name': 'CortexGen Caso',
    'nodes': nodes,
    'connections': dict([
        link('A cada minuto', 'Candidatos'),
        link('Candidatos', 'MontaRepasse'),
        link('MontaRepasse', 'EscolheProvider'),
        link('EscolheProvider', 'LLMRepasse', 'LLMRepasseCustom'),
        link('LLMRepasse', 'EnviaRepasse'),
        link('LLMRepasseCustom', 'EnviaRepasse'),
    ]),
    'settings': bot.get('settings') or {'executionOrder': 'v1'},
    'active': False,
}
json.dump([wf], open(dst, 'w'), ensure_ascii=False, indent=2)
print('ok:', dst)
