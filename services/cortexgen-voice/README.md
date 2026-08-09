# cortexgen-voice

O lado de mídia do agente de voz. O Chatwoot decide que uma chamada é do bot e
devolve ao Twilio um `<Connect><Stream>` apontando para cá; a partir daí o áudio
dos dois lados passa por este processo.

Este serviço **não guarda credencial de cliente**. As chaves de LLM, transcrição
e voz chegam por chamada, do endpoint `/voice_agent/config` do Chatwoot, que é
quem as guarda por conta. O que existe no env daqui é só onde perguntar e com
que segredo se identificar.

## Como a chamada corre

```
Twilio ──áudio μ-law 8k──▶ /voice-stream
   transport.input → VAD (Silero, local) → STT → contexto → LLM → TTS → transport.output
```

O VAD roda local porque a transcrição é **por trecho, não por streaming**: o
Deepgram `nova-3` chega pelo OpenRouter no endpoint compatível com OpenAI, que
recebe um arquivo e devolve o texto. Quem recorta esse arquivo no lugar certo é
o Silero. O Pipecat ainda carrega sozinho o Smart Turn local, que decide se a
pessoa terminou a frase em vez de só medir silêncio.

## Env

| Variável | O que é |
|---|---|
| `CHATWOOT_URL` | `https://prs.cortexgen.cloud` |
| `VOICE_SERVICE_TOKEN` | o mesmo valor de Super Admin → Settings → Voice Agent |
| `CONFIG_TIMEOUT_SECONDS` | opcional, padrão 5 |

## Build e verificação

O `smoke.py` instancia cada peça do pipeline com configuração falsa. Não faz
chamada nem gasta crédito: prova que os nomes e assinaturas batem com a versão
do Pipecat instalada. **Rodar sempre antes de subir** — a API do Pipecat muda
entre versões menores, e um kwarg errado só apareceria com o cliente na linha.

```bash
docker build -t cortexgen-voice:test .
docker run --rm -e CHATWOOT_URL=x -e VOICE_SERVICE_TOKEN=x cortexgen-voice:test python smoke.py
```

## nginx

O WebSocket é servido sob o host do painel, em `/voice-stream`, para não
depender de registro DNS nem de certificado novo. Twilio Media Streams exige
`wss://`.

```nginx
location /voice-stream {
    proxy_pass http://127.0.0.1:8080;
    proxy_http_version 1.1;
    proxy_set_header Upgrade $http_upgrade;
    proxy_set_header Connection "upgrade";
    proxy_set_header Host $host;
    proxy_read_timeout 3600s;
    proxy_send_timeout 3600s;
}
```
