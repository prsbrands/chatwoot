"""Liga o Jev no workflow do bot (pd5V9pdaldRLUu4C) a partir de um export.

    docker exec n8n-y4jd-n8n-1 n8n export:workflow --id=pd5V9pdaldRLUu4C --output=/tmp/wf.json
    python3 patch_jev.py wf.json wf-jev.json   # na pasta ops/n8n
    docker exec n8n-y4jd-n8n-1 n8n import:workflow --input=/tmp/wf-jev.json   # desativa: publicar de novo

Por que export/import e nao o MCP: `update_workflow` apaga as credenciais dos
nos HTTP (HANDOFF, "Armadilhas"). Aqui so Guard e MontaPrompt sao reescritos,
e so se o codigo ao vivo for exatamente o que o repo espera — uma edicao
feita na tela aborta o script em vez de sumir em silencio.

    Historico -> JevEntrada -> MontaPrompt
    Interpreta -> JevRevisao -> Responde
"""
import json
import sys
import uuid
from pathlib import Path

HERE = Path(__file__).parent
src, dst = sys.argv[1], sys.argv[2]

data = json.load(open(src))
wf = data[0] if isinstance(data, list) else data
nodes = {n['name']: n for n in wf['nodes']}


def code(name):
    return (HERE / name).read_text()


def fail(msg):
    sys.exit('ABORTADO: ' + msg)


# Guard: as trocas do Jev aplicadas ao codigo ao vivo tem que dar exatamente o
# guard.js do repo. A mensagem do chat_user_token e a unica divergencia
# conhecida entre o ao vivo e o repo (HANDOFF) e entra como troca tambem.
bloco_jev = code('guard.js').split("para gravar');\n", 1)[1].split('const esperado', 1)[0]
guard = nodes['Guard']['parameters']['jsCode']
if guard != code('guard.js'):
    trocas = [
        ('— rode o backfill de bot_account_settings', '— salve o canal em Bot Personas > Channels para gravar'),
        ("&select=chat_user_token';", "&select=chat_user_token,jev_api_key,jev';"),
        ("para gravar');\n\nconst esperado", "para gravar');\n" + bloco_jev + 'const esperado'),
        ('  botAccessToken: botAccessToken,\n} }];', '  botAccessToken: botAccessToken,\n  jev: jev,\n} }];'),
    ]
    for old_, new_ in trocas:
        if guard.count(old_) != 1:
            fail('Guard ao vivo nao tem o trecho esperado: ' + old_[:40])
        guard = guard.replace(old_, new_)
    if guard != code('guard.js'):
        fail('Guard ao vivo tem outra edicao alem das esperadas')
nodes['Guard']['parameters']['jsCode'] = guard

# MontaPrompt: as tres trocas do Jev aplicadas ao codigo ao vivo tem que dar
# exatamente o monta_prompt.js do repo.
mp = nodes['MontaPrompt']['parameters']['jsCode']
if mp != code('monta_prompt.js'):
    trocas = [
        ("const rota = $('Persona').first().json;\n",
         "const rota = $('Persona').first().json;\n"
         "// O que o Jev decidiu (JevEntrada): secoes da base que importam para esta\n"
         "// mensagem e o modelo. null/ausente = o de sempre (base inteira, modelo da persona).\n"
         "const jev = $('JevEntrada').first().json.jev || {};\n"),
        ("const systemText = String(rota.composed_prompt || '')",
         "const composto = jev.knowledge\n"
         "  ? rota.system_prompt + '\\n\\n---\\n\\n# BASE DE CONOCIMIENTO\\n\\n' + jev.knowledge\n"
         "  : rota.composed_prompt;\n"
         "const systemText = String(composto || '')"),
        ("  rota.model, nativeOpenRouterFallback", "  jev.model || rota.model, nativeOpenRouterFallback"),
        ("const payload = $input.first().json.payload || [];", "const payload = $('Historico').first().json.payload || [];"),
    ]
    # Troca ja aplicada numa rodada anterior e pulada: o script roda tanto
    # sobre o workflow de antes do Jev quanto sobre uma versao intermediaria.
    for old, new in trocas:
        if new in mp:
            continue
        if mp.count(old) != 1:
            fail('MontaPrompt ao vivo nao tem o trecho esperado: ' + old[:40])
        mp = mp.replace(old, new)
    if mp != code('monta_prompt.js'):
        fail('MontaPrompt ao vivo tem outra edicao alem das esperadas')
nodes['MontaPrompt']['parameters']['jsCode'] = mp


def code_node(name, script, near):
    x, y = nodes[near]['position']
    node = nodes.get(name) or {
        'id': str(uuid.uuid4()), 'name': name, 'type': 'n8n-nodes-base.code', 'typeVersion': 2,
        'position': [x + 110, y + 180], 'parameters': {},
    }
    node['parameters']['jsCode'] = code(script)
    if name not in nodes:
        wf['nodes'].append(node)
        nodes[name] = node


code_node('JevEntrada', 'jev_entrada.js', 'Historico')
code_node('JevRevisao', 'jev_revisao.js', 'Interpreta')


def link(a, b):
    wf['connections'][a] = {'main': [[{'node': b, 'type': 'main', 'index': 0}]]}


link('Historico', 'JevEntrada')
link('JevEntrada', 'MontaPrompt')
link('Interpreta', 'JevRevisao')
link('JevRevisao', 'Responde')

json.dump(data, open(dst, 'w'), ensure_ascii=False, indent=2)
print('ok:', dst)
