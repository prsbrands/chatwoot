"""Bloco 1 (0.9.0) no workflow do bot (pd5V9pdaldRLUu4C), a partir de um export.

    docker exec n8n-y4jd-n8n-1 n8n export:workflow --id=pd5V9pdaldRLUu4C --output=/tmp/wf.json
    python3 patch_bloco1.py wf.json wf-b1.json   # na pasta ops/n8n
    docker exec n8n-y4jd-n8n-1 n8n import:workflow --input=/tmp/wf-b1.json   # desativa: publicar de novo

    Historico -> OptOut -> JevEntrada -> PassaEntrada -+-> MontaPrompt -> ...
    Interpreta -> JevRevisao -> PassaRevisao -+-> Responde -> Log -> PrecisaHandoff -+
                                              |                                      |
    PassaEntrada / PassaRevisao --------------+--> PreparaBriefing <-----------------+
    PreparaBriefing -> EscolheProviderBriefing -> LLMBriefing | LLMBriefingCustom -> Passagem

O Handoff (HTTP) sai: a Passagem deixa a nota com briefing e abre a conversa
nos tres caminhos. O Responde vira Code node (bolhas com "digitando").

So aplica sobre o workflow que o repo conhece: Guard, JevEntrada e JevRevisao
ao vivo tem que ser os do commit BASE, e Responde/PrecisaHandoff/Handoff os de
antes do bloco 1. Uma edicao feita na tela aborta em vez de sumir em silencio.
"""
import copy
import json
import subprocess
import sys
import uuid
from pathlib import Path

HERE = Path(__file__).parent
BASE = '25e1472f0'
src, dst = sys.argv[1], sys.argv[2]

data = json.load(open(src))
wf = data[0] if isinstance(data, list) else data
nodes = {n['name']: n for n in wf['nodes']}


def code(name):
    return (HERE / name).read_text()


def na_base(name):
    return subprocess.run(['git', 'show', BASE + ':ops/n8n/' + name], cwd=HERE, check=True,
                          capture_output=True, text=True).stdout


def fail(msg):
    sys.exit('ABORTADO: ' + msg)


for name, script in [('Guard', 'guard.js'), ('JevEntrada', 'jev_entrada.js'), ('JevRevisao', 'jev_revisao.js')]:
    if nodes[name]['parameters']['jsCode'] != na_base(script):
        fail(name + ' ao vivo nao e o ' + script + ' de ' + BASE)
    nodes[name]['parameters']['jsCode'] = code(script)

PRECISA_ANTES = "const i = $('Interpreta').first().json;\nif (!i.handoff) return [];\nreturn [{ json: i }];"
if nodes['PrecisaHandoff']['parameters']['jsCode'].strip() != PRECISA_ANTES:
    fail('PrecisaHandoff ao vivo tem outra edicao')
nodes['PrecisaHandoff']['parameters']['jsCode'] = (
    "// Keyword, max_turns ou content_filter (Interpreta): a resposta ja saiu,\n"
    "// e a Passagem resume a conversa com ela.\n"
    "const i = $('Interpreta').first().json;\n"
    "if (!i.handoff) return [];\n"
    "return [{ json: { passagem: { motivo: i.handoffReason, fonte: 'regra', respostaEnviada: i.reply } } }];\n"
)

if 'toggle_status' not in nodes['Handoff']['parameters']['url'] or '/messages' not in nodes['Responde']['parameters']['url']:
    fail('Handoff/Responde ao vivo nao sao os nos HTTP esperados')

# Responde: HTTP -> Code, no mesmo lugar e com o mesmo id.
responde = nodes['Responde']
responde.update({'type': 'n8n-nodes-base.code', 'typeVersion': 2, 'parameters': {'jsCode': code('responde.js')}})
responde.pop('credentials', None)

wf['nodes'] = [n for n in wf['nodes'] if n['name'] != 'Handoff']
del nodes['Handoff']
wf['connections'].pop('Handoff', None)


def novo(name, base, dx, dy, **campos):
    x, y = nodes[base]['position']
    node = {'id': str(uuid.uuid4()), 'name': name, 'position': [x + dx, y + dy]}
    node.update(campos)
    wf['nodes'].append(node)
    nodes[name] = node
    return node


def code_node(name, script, base, dx, dy):
    return novo(name, base, dx, dy, type='n8n-nodes-base.code', typeVersion=2, parameters={'jsCode': code(script)})


def if_node(name, expressao, base, dx, dy):
    params = copy.deepcopy(nodes['EscolheProvider']['parameters'])
    cond = params['conditions']['conditions'][0]
    cond['id'] = str(uuid.uuid4())
    cond['leftValue'] = expressao
    return novo(name, base, dx, dy, type='n8n-nodes-base.if', typeVersion=nodes['EscolheProvider']['typeVersion'],
                parameters=params)


def http_clone(name, modelo, base, dx, dy):
    node = copy.deepcopy(nodes[modelo])
    node.update({'id': str(uuid.uuid4()), 'name': name})
    node['parameters']['options']['timeout'] = 20000
    wf['nodes'].append(node)
    nodes[name] = node
    x, y = nodes[base]['position']
    node['position'] = [x + dx, y + dy]
    return node


for name in ['OptOut', 'PassaEntrada', 'PassaRevisao', 'PreparaBriefing', 'EscolheProviderBriefing',
             'LLMBriefing', 'LLMBriefingCustom', 'Passagem']:
    if name in nodes:
        fail(name + ' ja existe no workflow')

code_node('OptOut', 'opt_out.js', 'Historico', 0, 200)
if_node('PassaEntrada', '={{ !!$json.passagem }}', 'JevEntrada', 0, 200)
if_node('PassaRevisao', '={{ !!$json.passagem }}', 'JevRevisao', 0, 200)
code_node('PreparaBriefing', 'prepara_briefing.js', 'PrecisaHandoff', 0, 250)
if_node('EscolheProviderBriefing', '={{ $json.useOpenRouter }}', 'PreparaBriefing', 200, 0)
http_clone('LLMBriefing', 'LLM', 'EscolheProviderBriefing', 200, -100)
http_clone('LLMBriefingCustom', 'LLMCustom', 'EscolheProviderBriefing', 200, 100)
code_node('Passagem', 'passagem.js', 'EscolheProviderBriefing', 400, 0)


def link(a, *saidas):
    wf['connections'][a] = {'main': [[{'node': b, 'type': 'main', 'index': 0}] for b in saidas]}


# IF: saida 0 = verdadeiro, saida 1 = falso.
link('Historico', 'OptOut')
link('OptOut', 'JevEntrada')
link('JevEntrada', 'PassaEntrada')
link('PassaEntrada', 'PreparaBriefing', 'MontaPrompt')
link('JevRevisao', 'PassaRevisao')
link('PassaRevisao', 'PreparaBriefing', 'Responde')
link('PrecisaHandoff', 'PreparaBriefing')
link('PreparaBriefing', 'EscolheProviderBriefing')
link('EscolheProviderBriefing', 'LLMBriefing', 'LLMBriefingCustom')
link('LLMBriefing', 'Passagem')
link('LLMBriefingCustom', 'Passagem')

json.dump(data, open(dst, 'w'), ensure_ascii=False, indent=2)
print('ok:', dst)
