"""Idioma da resposta e formatacao do OpenWA no workflow do bot (pd5V9pdaldRLUu4C).

    docker exec n8n-y4jd-n8n-1 n8n export:workflow --id=pd5V9pdaldRLUu4C --output=/home/node/wf.json
    python3 ops/n8n/patch_idioma.py wf.json wf-idioma.json   # na raiz do repo, precisa do git
    docker exec n8n-y4jd-n8n-1 n8n import:workflow --input=/home/node/wf-idioma.json   # desativa: publicar de novo

Troca Guard, JevEntrada, MontaPrompt e Responde pelo que esta no repo, e so se
o codigo ao vivo for exatamente o do commit BASE: uma edicao feita na tela
aborta o script em vez de sumir em silencio.
"""
import json
import subprocess
import sys
from pathlib import Path

BASE = 'c544844dd'
HERE = Path(__file__).parent
NODES = {'Guard': 'guard.js', 'JevEntrada': 'jev_entrada.js', 'MontaPrompt': 'monta_prompt.js', 'Responde': 'responde.js'}

src, dst = sys.argv[1], sys.argv[2]
data = json.load(open(src))
wf = data[0] if isinstance(data, list) else data
nodes = {n['name']: n for n in wf['nodes']}

for name, arquivo in NODES.items():
    antes = subprocess.run(['git', 'show', BASE + ':ops/n8n/' + arquivo], capture_output=True, text=True, check=True).stdout
    depois = (HERE / arquivo).read_text()
    ao_vivo = nodes[name]['parameters']['jsCode']
    if ao_vivo == depois:
        continue
    if ao_vivo != antes:
        sys.exit('ABORTADO: ' + name + ' ao vivo nao e o do ' + BASE)
    nodes[name]['parameters']['jsCode'] = depois
    print('trocado:', name)

json.dump(data, open(dst, 'w'), ensure_ascii=False)
