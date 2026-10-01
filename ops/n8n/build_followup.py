"""Monta o workflow "CortexGen Follow-up" (bloco 2) a partir do export do bot.

    docker exec n8n-y4jd-n8n-1 n8n export:workflow --id=pd5V9pdaldRLUu4C --output=/tmp/wf.json
    python3 build_followup.py wf.json wf-followup.json [id]   # na pasta ops/n8n; com id, atualiza o existente
    docker exec n8n-y4jd-n8n-1 n8n import:workflow --input=/tmp/wf-followup.json   # entra desativado: publicar

    A cada 15 min -> Candidatos -> JevFollowup -> MontaRetomada -> EscolheProvider
      -> LLMRetomada (OpenRouter, credencial do n8n) | LLMRetomadaCustom -> Envia

O IF e os dois nos HTTP de LLM sao clonados do workflow do bot, com a mesma
credencial do OpenRouter: nada de parametro escrito de memoria.
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
# Terceiro argumento: id do workflow que ja existe no n8n, para atualizar.
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


add('A cada 15 min', 0, type='n8n-nodes-base.scheduleTrigger', typeVersion=1.2,
    parameters={'rule': {'interval': [{'field': 'minutes', 'minutesInterval': 15}]}})
code('Candidatos', 'followup_candidatos.js', 220)
code('JevFollowup', 'followup_jev.js', 440)
code('MontaRetomada', 'followup_monta.js', 660)
clone('EscolheProvider', 'EscolheProvider', 880, 300)
clone('LLMRetomada', 'LLM', 1100, 200)
clone('LLMRetomadaCustom', 'LLMCustom', 1100, 400)
code('Envia', 'followup_envia.js', 1320)


def link(a, *saidas):
    return a, {'main': [[{'node': b, 'type': 'main', 'index': 0}] for b in saidas]}


# O import:workflow exige id (SQLITE_CONSTRAINT: workflow_entity.id sem ele).
# Id novo a cada geracao: reimportar este arquivo cria outro workflow, nao
# atualiza o anterior — para atualizar, use o id que o n8n ja tem.
wf_id = wf_existente or ''.join(secrets.choice(string.ascii_letters + string.digits) for _ in range(16))

wf = {
    'id': wf_id,
    'name': 'CortexGen Follow-up',
    'nodes': nodes,
    'connections': dict([
        link('A cada 15 min', 'Candidatos'),
        link('Candidatos', 'JevFollowup'),
        link('JevFollowup', 'MontaRetomada'),
        link('MontaRetomada', 'EscolheProvider'),
        link('EscolheProvider', 'LLMRetomada', 'LLMRetomadaCustom'),
        link('LLMRetomada', 'Envia'),
        link('LLMRetomadaCustom', 'Envia'),
    ]),
    'settings': bot.get('settings') or {'executionOrder': 'v1'},
    'active': False,
}
json.dump([wf], open(dst, 'w'), ensure_ascii=False, indent=2)
print('ok:', dst)
