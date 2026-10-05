"""Uso de IA por conta e teto mensal (1.11.0, db/botlayer/bot_ai_usage.sql).

Bot (pd5V9pdaldRLUu4C):
    docker exec n8n-y4jd-n8n-1 n8n export:workflow --id=pd5V9pdaldRLUu4C --output=/home/node/wf.json
    python3 ops/n8n/patch_uso.py bot wf.json wf-uso.json BASE

Follow-up (1aloIF0zKm8pjpeK, agendado: depois do Publish, docker restart do n8n):
    docker exec n8n-y4jd-n8n-1 n8n export:workflow --id=1aloIF0zKm8pjpeK --output=/home/node/fu.json
    python3 ops/n8n/patch_uso.py followup fu.json fu-uso.json BASE

Troca os Code nodes pelo que esta no repo, e so se o codigo ao vivo for
exatamente o do commit BASE (uma edicao feita na tela aborta). No bot, o corpo
do no Log (HTTP) passa a gravar conta, tipo e custo, e so se for o esperado.
"""
import json
import subprocess
import sys
from pathlib import Path

HERE = Path(__file__).parent
NODES = {
    'bot': {'Guard': 'guard.js', 'Interpreta': 'interpreta.js', 'MontaPrompt': 'monta_prompt.js',
            'PreparaBriefing': 'prepara_briefing.js', 'Passagem': 'passagem.js'},
    'followup': {'Candidatos': 'followup_candidatos.js', 'MontaRetomada': 'followup_monta.js', 'Envia': 'followup_envia.js'},
}
I = '$("Interpreta").first().json'
LOG_ANTES = ('={{ JSON.stringify({ chatwoot_conversation_id: ' + I + '.conversationId, chatwoot_message_id: ' + I + '.messageId, '
             'persona_id: ' + I + '.personaId, provider: ' + I + '.provider, model: ' + I + '.model, tokens_in: ' + I + '.tokensIn, '
             'tokens_out: ' + I + '.tokensOut, latency_ms: ' + I + '.latencyMs, status: ' + I + '.handoff ? "handoff" : "ok" }) }}')
LOG_DEPOIS = ('={{ JSON.stringify({ chatwoot_account_id: ' + I + '.accountId, kind: "reply", '
              'chatwoot_conversation_id: ' + I + '.conversationId, chatwoot_message_id: ' + I + '.messageId, '
              'persona_id: ' + I + '.personaId, provider: ' + I + '.provider, model: ' + I + '.model, tokens_in: ' + I + '.tokensIn, '
              'tokens_out: ' + I + '.tokensOut, cost_usd: ' + I + '.costUsd, latency_ms: ' + I + '.latencyMs, '
              'status: ' + I + '.handoff ? "handoff" : "ok" }) }}')

qual, src, dst, base = sys.argv[1], sys.argv[2], sys.argv[3], sys.argv[4]
data = json.load(open(src))
wf = data[0] if isinstance(data, list) else data
nodes = {n['name']: n for n in wf['nodes']}

for name, arquivo in NODES[qual].items():
    antes = subprocess.run(['git', 'show', base + ':ops/n8n/' + arquivo], capture_output=True, text=True, check=True).stdout
    depois = (HERE / arquivo).read_text()
    ao_vivo = nodes[name]['parameters']['jsCode']
    if ao_vivo == depois:
        continue
    if ao_vivo != antes:
        sys.exit('ABORTADO: ' + name + ' ao vivo nao e o do ' + base)
    nodes[name]['parameters']['jsCode'] = depois
    print('trocado:', name)

if qual == 'bot':
    corpo = nodes['Log']['parameters']['jsonBody']
    if corpo != LOG_DEPOIS:
        if corpo != LOG_ANTES:
            sys.exit('ABORTADO: corpo do Log ao vivo nao e o esperado')
        nodes['Log']['parameters']['jsonBody'] = LOG_DEPOIS
        print('trocado: Log (corpo)')

json.dump(data, open(dst, 'w'), ensure_ascii=False)
