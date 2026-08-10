# HANDOFF — CortexGen Chat

Última sessão: 2026-08-09 · Instância: https://prs.cortexgen.cloud

---

## ▶️ RETOMAR AQUI — validar o Flux até a chamada ficar usável

Produção em **`8d59ba0c0`**. `/api`, `/app/login`, `/super_admin/sign_in` em 200; `cortexgen-voice` respondendo.

**A migração para o Deepgram Flux está no ar e NUNCA foi validada com uma chamada real.** Essa é a única prioridade desta sessão. Não construa mais nada até a chamada estar boa.

### O que mudou e por que

O Deepgram tem duas famílias e estávamos na errada. **Nova** transcreve; **Flux** é feito para conversa e traz a máquina de turnos dentro do serviço — ela enxerga a forma de onda, não só os intervalos.

Tudo o que este serviço tinha acumulado para suprir o Nova saiu do caminho quando o modelo é `flux-*`: VAD local do Silero, cronômetro de silêncio, portão por LLM, mínimo de palavras. **Cada uma dessas peças já derrubou uma chamada real** — silêncio de 5 s, saudação engolida, bot falando por cima, resposta descartada por chegar tarde.

Config ativa, confirmada no endpoint:

```
stt : deepgram flux-general-multi   (idioma ouvido: multi)
llm : openai/gpt-4.1-mini  ·  reserva deepseek/deepseek-v4-flash-0731
tts : eleven_multilingual_v2  ·  voz ny3E2DZImeZm00WLGZi9
```

Limiares do Flux, hoje fixos no código (`_stt` em `app/bot.py`): `eot_threshold=0.7`, `eager_eot_threshold=0.5`, `eot_timeout_ms=5000`. São **confiança de fim de turno**, não milissegundos de silêncio.

### Protocolo de teste — siga na ordem, uma chamada por vez

Depois de **cada** ligação:

```bash
docker logs --tail 800 cortexgen-voice 2>&1 | grep -v 'Generating chat from context' \
  | cut -c1-190 | grep -iE 'call .* (started|finished)|Generating TTS|ERROR|StartOfTurn|EndOfTurn|EagerEndOfTurn|TurnResumed|TTFB'
```

E as métricas gravadas:

```bash
cd /opt/cortexgen-chat && docker compose exec -T rails bundle exec rails runner \
  "c=TwilioVoiceCall.order(id: :desc).first; puts c.duration_seconds; puts c.metrics"
```

**Teste 1 — a conversa acontece?** Ligue, responda o nome, diga a empresa, responda uma pergunta. Procure no log `StartOfTurn` / `EndOfTurn` do Flux.
- Passou: siga para o 2.
- Bot mudo ou intervalo longo: veja "Se o Flux falhar" abaixo.

**Teste 2 — latência.** Alvo: **mediana abaixo de 1.500 ms**. Régua atual (Nova, última chamada boa): mediana 2.018 ms, pior 2.695 ms.
- Acima do alvo: baixe `eot_threshold` para 0.6 (fecha o turno com menos confiança, responde antes). **Uma chamada por ajuste.**

**Teste 3 — soletrar.** Dite um e-mail letra por letra. O bot não pode responder no meio.
- Cortou: suba `eot_threshold` para 0.8. Esse é o trade-off direto com o teste 2 — ache o meio.

**Teste 4 — interromper.** Fale por cima do bot. Ele deve parar.
- Não parou: `should_interrupt` do `DeepgramFluxSTTService` (padrão `True`).

**Teste 5 — português no meio do espanhol.** Diga "consertos de automóveis". Não pode virar "conciertos".
- Errou: o `flux-general-multi` já está ativo; considere `language_hints=[Language.ES, Language.PT_BR]` em `_stt`.

**Critério de "usável":** os cinco testes passando, mediana abaixo de 1.500 ms, e **duas chamadas seguidas sem intervalo perceptível**.

### Se o Flux falhar

Volta em **um campo, sem deploy**: persona → Voz → `Transcription model` de `flux-general-multi` para `nova-3`. Todo o caminho Nova continua no código, com `interim_results` + `utterance_end_ms`, e `_turn_strategies` volta a valer.

Antes de voltar, confirme no log se o Flux chegou a conectar — se não houver `StartOfTurn` nenhum, o problema é conexão/credencial, não comportamento.

### Aberto e sem explicação: 502 no webhook

Uma chamada não atendeu. Alerta do próprio Twilio:

```
02:29:07  code=11200  Got HTTP 502 response to /twilio/voice/incoming
```

Rails de pé desde 00:22 **sem reinícios**, 394 MB, e **o nginx não tem registro dessa requisição** — nem acesso, nem erro. O 502 veio antes do nginx e não deixou rastro nosso.

Um webhook que devolve 502 é uma ligação de cliente perdida em silêncio; só descobrimos porque fomos perguntar ao Twilio. **Precisa de monitor.** Sugestão: checagem periódica de `/api` com alerta, e ler `client.monitor.v1.alerts` do Twilio no painel de chamadas.

### Skills — leia antes de mexer

- **`pipecat`** (`~/.claude/skills/pipecat/`): modelo de turno, a armadilha do mute, tabela sintoma → assinatura no log → causa.
- **`deepgram`** (`~/.claude/skills/deepgram/`): decisão Nova vs Flux, semântica de streaming, telefonia, idioma.

A regra que custou seis ligações está nas duas: **uma mudança por chamada.** As três últimas regressões foram mecanismos adicionados sem validação individual.

### Fase 3 — o que já está em produção

| Peça | Onde |
|---|---|
| `bot_providers.kinds` (`llm`/`stt`/`tts`) + preset ElevenLabs | `db/botlayer/bot_voice.sql`, aplicado |
| Campos de voz na persona + view `bot_persona_resolved` | idem |
| Rota com `answer_mode`/`no_answer_action`/`bot_persona_slug` | migration `20260810000001`, aplicada |
| TwiML `<Connect><Stream>` | `app/controllers/twilio/voice_routing_controller.rb` |
| Endpoint `/voice_agent/config` (Bearer) | `app/controllers/voice_agent/`, `app/services/voice/` |
| Serviço `cortexgen-voice` | `services/cortexgen-voice/`, rodando em `/opt/cortexgen-voice` |
| `wss://prs.cortexgen.cloud/voice-stream` | location no vhost do painel |

**Verificado em 09/08:** health 200; handshake WebSocket real através do nginx OK; endpoint de config responde 401 sem token, 404 em número desconhecido, 422 em rota sem bot. Backup do vhost em `/root/prs.vhost.bak-*`.

### Dois caminhos de transcrição, e por que o direto ganha

| | Deepgram direto | via OpenRouter |
|---|---|---|
| Protocolo | WebSocket, texto chega **enquanto** a pessoa fala | POST de arquivo, só depois do turno fechado |
| Latência | ~200 ms | ~500 ms |
| `api_style` | `deepgram`, modelo `nova-3` | `openai`, modelo `deepgram/nova-3` |
| Conta | própria (o Paulo tem, com saldo) | a mesma chave que já responde mensagens |

Preço igual nos dois (US$0,0043/min). **Usar o direto** — 300 ms é muito quando o alvo é 1,5 s. O OpenRouter fica como caminho de quem não quer criar conta.

O OpenRouter serve Deepgram mesmo, mas **só em lote**: `/api/v1/audio/transcriptions` existe, `/api/v1/realtime` dá 404. Não aparece em `/api/v1/models` porque não é modelo de chat — está em `/api/v1/providers`. (Verificar em `/models` foi um erro meu que o Paulo corrigiu.)

Em qualquer um dos dois o Silero roda local para os turnos. **O Smart Turn v3 foi desligado** — ver "Primeira chamada real" mais abaixo. TTS é ElevenLabs direto, que faz streaming.

**Cartesia (TTS) e Gemini (LLM) não estão ligados** — o Paulo tem as chaves, mas nenhuma persona aponta para elas e cada uma exige uma ramificação no `_stt`/`_tts` do serviço. São ~10 minutos cada quando houver motivo (comparar voz, ou tirar o hop do OpenRouter no LLM).

### Fase 3c entregue — a chamada vira conversa, contato e lead

Ao desligar, o serviço de mídia manda transcrição, duração e os dados do lead para `/voice_agent/calls`. O Chatwoot cria conversa numa inbox **própria de voz** (`Voz — <número>`, tipo `Channel::Api`, gravada em `twilio_voice_routes.voice_inbox_id`).

**Por que inbox separada e não a de SMS do mesmo número:** naquela, mensagem de saída é enviada de verdade pelo Twilio — devolver ao cliente a transcrição da própria ligação por SMS seria um acidente caro. Inbox de API não envia nada sozinha.

**Enriquecimento do contato** (mesma chamada de IA que faz o resumo, um request só): nome, e-mail, empresa e cidade saem da conversa; **país sai do número** via `TelephoneNumber` (`country_id` → ISO); WhatsApp assume o número de origem salvo se ditarem outro. Convenção do Chatwoot: `additional_attributes['country']` guarda o ISO e o `Contacts::SyncAttributes` espelha para `country_code`; `['city']` vira `location`; o contato passa a `lead`.

**Cidade NÃO sai do telefone, de propósito.** O gem não fornece, e número diz onde a linha foi habilitada — em celular nem isso. O prompt de extração manda explicitamente não adivinhar cidade pelo país. Preencher por DDD daria dado errado com cara de certo.

### Paciência ao soletrar — o que quebrou e como

Numa chamada real quem ligou soletrou "arrowgen" e o bot respondeu na quarta letra:

```
[incoming] Yo voy a deletrear
[incoming] a r r o
[outgoing] Gracias,          ← cortou aqui
```

Silêncio sozinho não distingue fim de frase de pausa entre duas letras. Agora quem decide é o modelo: o Pipecat pede que ele marque cada resposta como turno completo ou incompleto (`FilterIncompleteUserTurnStrategies`), e só o completo libera a fala. **Sai de graça** — é a mesma resposta que já estava sendo gerada. As instruções padrão do Pipecat cobrem ser cortado e pensar alto; o caso de ditado foi acrescentado por cima.

Interruptor visível na persona (`voice_wait_for_complete_turn`, padrão ligado) porque o mecanismo depende de o modelo obedecer a um formato — modelo pequeno que ignorar deixaria o bot mudo, que é exatamente a falha do Smart Turn.

**Saudação cortada — a tentativa de conserto foi pior que o defeito.** Pus `MuteUntilFirstBotCompleteUserMuteStrategy` para a abertura não ser cortada por um "alô?", e ela **matou uma chamada em 62 s de silêncio**: a abertura pergunta o nome, quem ligou respondeu no meio, o mute descartou os quadros de VAD e nenhum turno chegou a começar — com a transcrição já parada no contexto. Removido em `92b66a28f`. Detalhe do mecanismo na skill `pipecat`, seção 2.

### Correção: a latência do LLM varia muito mais do que a primeira medição sugeria

Medi 0,103 s numa chamada e registrei como típico. Nas seguintes: **0,575 s, 1,132 s e 1,341 s**. O `gpt-4.1` é irregular, então trocar para `gpt-4.1-mini` ajuda latência **e** custo (5× mais barato: US$0,024 vs US$0,120 numa chamada de 3 min). Benchmark completo em https://claude.ai/code/artifact/bb9db886-7084-4e34-882d-3a9338cc8b73

### Ainda aberto na Fase 3/4

- ~~Fallback de LLM na chamada~~ — **entregue** em `64fda3a37`. Principal e reserva vão no mesmo request (`extra.models`), o roteador do OpenRouter desce para o segundo sem nova ida à rede; `retry_on_timeout=True` com 6 s cobre modelo que emudece. Reserva em **fornecedor diferente** é recusada com aviso no log, não fingida — trocar de endpoint no meio do stream é outro problema, e a persona já oferece "same as primary" como padrão. Hoje: `openai/gpt-4.1-mini` → `deepseek/deepseek-v4-flash-0731`.
- ~~Termos que não interrompem~~ — **entregue** como `voice_interrupt_min_words` (padrão **0 = desligado**). Com 2, um "ajá" de cortesia não cala o bot — mas um "para!" de uma palavra também não. Trade-off escrito no campo; vale testar os dois numa chamada real.
- **Aviso de alterações não salvas no editor de persona**: medi que os saves funcionam (três PATCH, tamanhos crescentes, 200 OK), mas sair pela seta ← descarta tudo em silêncio.
- ~~Medição por chamada~~ — **entregue** em `008ad8836`. Cada chamada guarda em `twilio_voice_calls.metrics`: turnos, tokens, caracteres falados, segundos transcritos e a **latência sentida** (do fim da fala de quem ligou à primeira sílaba do bot), como mediana + pior caso. Aparece na aba Voz por chamada. Coletado por um `BaseObserver` próprio + o `UserBotLatencyObserver` do Pipecat.
- **Custo em dólar**: falta uma tarifa por fornecedor. Não inventei preço porque a **ElevenLabs cobra por plano**, não por caractere a preço fixo — um número confiante e errado na tela é pior que campo vazio. Desenho sugerido: colunas de tarifa em `bot_providers`, com os presets já preenchidos pelas tabelas públicas (Deepgram US$0,0043/min, OpenRouter por modelo em `/api/v1/models`, Twilio ~US$0,0085/min).
- **Pronúncia**: a ElevenLabs lê "PRS" como "PE, r, essi". Contornado escrevendo foneticamente na frase de abertura; dicionário de pronúncia resolveria de verdade.
- **Concorrência**: quantas chamadas simultâneas a VPS aguenta é medição, não estimativa.
- Chamada **saindo** do softphone segue sem funcionar (`voice_url` do domínio SIP é nil) — lacuna da Fase 2.

### Primeira chamada real (09/08, 22:25) — o que ela ensinou

O bot atendeu, se apresentou, perguntou o nome, respondeu "Gracias, Pablo" — e depois **emudeceu**. Diagnóstico pelos logs do `cortexgen-voice`:

O Pipecat fecha o turno de quem fala com o **Smart Turn**, um modelo semântico que julga se a frase acabou. Em espanhol ao telefone ele devolvia `INCOMPLETE` sempre, então o turno só fechava no **timeout de 5 s**. Cinco segundos de nada parecem queda de ligação, o cliente fala de novo, e essa fala **interrompe** a resposta que estava chegando. O log pega no flagrante: `broadcasting interruption` às 46.049 e `OpenAILLMService TTFB: 0.103s` às 46.052 — a resposta perdeu por 3 ms.

Corrigido em `7f7b9ecc0`: fim de turno por **silêncio** (`SpeechTimeoutUserTurnStopStrategy`), que é o que o campo "End of turn (ms)" da persona sempre prometeu controlar e não controlava. Rede de segurança de 5 s → 2 s.

**Latência medida na chamada real** (do fim da fala ao primeiro áudio, ≈ 1,1 s — dentro do alvo de 1,5 s):

| Etapa | Medido |
|---|---|
| Deepgram (inclui os 600 ms de endpointing configurados) | 0,67–0,72 s |
| LLM (gpt-4.1, prompt de 21 KB) | **0,103 s** |
| ElevenLabs até o primeiro áudio | 0,33 s |

**Correção de uma coisa que eu disse antes:** avisei que o prompt de 21 KB seria latência audível. **Não foi** — o modelo respondeu em 100 ms. O maior componente é o endpointing de 600 ms, que é ajustável na persona. Encurtar o prompt continua valendo por qualidade de conversa (respostas curtas e faladas), não por latência.

### Descoberta: Deepgram **Flux** substituiria toda a pilha de turnos

A Deepgram tem duas famílias, e estamos na errada para o nosso caso:

| | Nova (`/v1/listen`) — o que usamos | Flux (`/v2/listen`) |
|---|---|---|
| Para quê | legendas, gravações, transcrição geral | **agentes de voz conversacionais** |
| Detecção de turno | **nossa**, manual | **embutida** (EOT, EagerEOT) |
| Multilíngue | `language="multi"` | `flux-general-multi` + `language_hints` atualizáveis no meio da chamada |

**O Pipecat 1.7 já suporta** — `pipecat.services.deepgram.flux.stt.DeepgramFluxSTTService`, com eventos `on_start_of_turn`, `on_eager_end_of_turn`, `on_end_of_turn` e `on_turn_resumed`.

Resolveria de uma vez três problemas que venho remendando: a máquina de turnos frágil (passaria para a camada que ouve o áudio, que é onde a informação está), a mistura espanhol/português, e o "turno especulativo" do benchmark da ElevenLabs — que no Flux é o `EagerEOT`, de fábrica.

**Não migrei** porque seria a maior mudança até agora e a regra de uma mudança por chamada vale mais depois de seis regressões. É a próxima decisão de arquitetura a tomar, não um ajuste.

### Skill `pipecat` — leia antes de mexer no serviço de voz

`~/.claude/skills/pipecat/SKILL.md`. Carrega sozinha quando o assunto é Pipecat ou um sintoma de chamada. Contém o modelo de turno (início e fim são estratégias independentes; `None` aplica o padrão, não desliga), a armadilha do mute que mata a chamada em silêncio, a configuração de referência para telefonia, o que mudou de lugar na 1.7, e uma **tabela sintoma → assinatura no log → causa** para diagnosticar em segundos.

A regra que custou seis ligações está lá: **uma mudança por chamada.**

### Skill `deepgram`

`~/.claude/skills/deepgram/SKILL.md`. Decisão Nova vs Flux, semântica de `endpointing` / `utterance_end_ms` / `interim_results` (e por que ruído de linha trava o primeiro — confirmado pela documentação da Deepgram), configuração de telefonia, idioma e troca de idioma, tabela de diagnóstico. Skills oficiais da Deepgram em <https://github.com/deepgram/skills>.

### Armadilha: `extra` do Pipecat vira kwargs do SDK, não corpo do request

O fallback de LLM foi entregue mandando `models` em `OpenAILLMSettings.extra`. O Pipecat faz `params.update(settings.extra)` e passa tudo para `AsyncCompletions.create(**params)` — o SDK da OpenAI **não conhece `models`** e recusou toda chamada com `unexpected keyword argument`. O bot falava a saudação (que não passa pelo modelo) e emudecia. O lugar certo é **`extra_body`**, a porta do SDK para campos que só o fornecedor entende.

Na mesma leva, `STTUsageMetricsData.value` é um **objeto** `STTUsage(audio_seconds=…)`, enquanto o do TTS é um `int` puro — somar o objeto como número estourava em toda chamada.

Nenhum dos dois falhava antes de uma chamada real. O `smoke.py` agora confere os kwargs **contra a assinatura real do `AsyncCompletions.create`** e alimenta o coletor com objetos de métrica de verdade; ambos foram verificados rejeitando as versões que subiram.

### Armadilha: a API do Pipecat muda entre versões menores

Na 1.7 o `allow_interruptions` do `PipelineParams` **não existe mais** (virou `user_mute_strategies` no agregador), o VAD saiu do transport e virou `VADProcessor` no pipeline, e `model=`/`voice_id=` viraram `settings=Settings(...)`. Nada disso quebra no build — só na chamada. Por isso o `smoke.py` vai dentro da imagem e **roda antes de subir**: instancia cada peça com config falsa, sem gastar crédito. Foi ele que pegou os três.

---

Plano completo em `PLAN-TWILIO-VOZ.md`.

### O que já funciona em produção

| Fase | Commit | Entrega |
|---|---|---|
| 0 | `d6c5771c3` | Twilio conectado **por conta** (Settings → Integrations → Twilio), validado contra a API antes de gravar, token criptografado. Números listados com as capabilities de cada um |
| 1 | `19c59c3d5` | Inbox de SMS em 1 clique, com o `sms_url` gravado no número pela API. Paginação (`page_size: 25`) + busca do lado do Twilio. Aviso de A2P 10DLC em `+1` |
| 2 | `fa80e1eda` | Voz entrando: rotas próprias, domínio SIP e credenciais provisionados pelo painel, roteamento por número, transbordo para mensagem quando não atendem |

**Provado com tráfego real em 09/08:**
- SMS entrando e saindo no **+16893539100** (inbox 15, conversa 17, saída `delivered` — o A2P não barrou)
- Chamada de voz entrando, tocando no Zoiper e **atendida** (`TwilioVoiceCall` com `status=completed`, `+16893291777 → +16893539100`)
- Domínio SIP **`cortexgen-prs.sip.twilio.com`** criado pelo painel, credencial `paulo` registrada no Zoiper

**Migrations aplicadas:** `20260809000001` (`twilio_credentials`), `20260809000002` (`twilio_voice_routes`, `twilio_voice_calls`).
**Flags ligadas na conta 1:** `whatsapp_sessions`, `bot_personas`, `ai_providers`, `twilio_integration`.

### Lacunas conhecidas, por ordem de importância

1. **Chamada SAINDO do softphone não funciona** — o domínio SIP está com `voice_url = nil`, então o Twilio não sabe o que fazer com uma chamada originada no Zoiper e devolve ocupado. Não foi construído porque a Fase 2 era receber. Exige decidir qual número aparece como identificador, restrição de destino e registro da chamada.
2. ~~`bot_providers` só tem provedores de LLM~~ — **resolvido na Fase 3** com `kinds text[]` (array, não coluna singular: a mesma conta de OpenAI serve os três e a chave é o que não se quer duplicar). Ver "Dois caminhos de transcrição" no topo.
3. **Paginação/busca só na aba Números**; a aba Voz lista tudo direto.
4. **Assistente de escrita CortexGen AI nunca foi testado de verdade** — chave OpenAI gravada, endpoint vazio (= `api.openai.com`). Abrir uma conversa e usar reescrever/resumir. Se falhar, os erros úteis são `captain.api_key_missing` e qualquer coisa do `Llm::FeatureRouter` (modelo fora do catálogo de `config/llm.yml`).
5. Aba Channels com a coluna Agent bot: ligar o switch e conferir em Settings → Inboxes → Bot Configuration que o vínculo nasceu sozinho.
6. Widget real no site; handoff do bot ("quiero hablar con un consultor" deve virar `open`); multi-turno com histórico no prompt.
7. Limpar contatos/conversas de teste e as inboxes duplicadas de WhatsApp (#12, #13, #14).

### Os 9 outros números do Twilio são da GoHighLevel

Só o **+16893539100** migrou para cá. Os demais seguem apontados para `msgsndr.com` / `leadconnectorhq.com`, e **4 dos 6 domínios SIP servem a GHL em produção**. O painel os lista como externos e sem botão de editar, de propósito: reapontar um deles derrubaria a telefonia de um cliente. Não mudar isso sem pedir.

## Protocolo de deploy (custou duas quedas em 09/08)

1. `git push` do Mac
2. `git pull` na VPS
3. `docker build -t cortexgen-chat:test`
4. **Teste de fumaça: SUBIR a imagem `:test` numa porta livre e exigir HTTP 200.** Não é opcional e não é o mesmo que o passo 3 — ver abaixo
5. Só então `docker build -t cortexgen-chat:v1` + `docker compose up -d --force-recreate rails sidekiq`
6. **Esperar em loop até `/api` devolver 200** (~24 s). **Nunca** encadear `docker compose exec` logo após o `up -d`
7. `docker compose ps` + as 3 rotas; rollback para o commit anterior se o passo 6 estourar

### Por que o passo 4 existe

**`docker build` compila os assets e carrega o código, mas não sobe o Rails.** Erros de boot — callback inexistente, initializer quebrado, constante ausente — passam pelo build e só aparecem quando o servidor monta. Foi assim que `skip_before_action :verify_authenticity_token` (callback que o `ApplicationController` do Chatwoot não instala) passou no `:test` verde e deixou o site em crash-loop por 4 minutos.

```bash
docker run -d --name cgtest --network cortexgen-chat_default --env-file .env \
  -e RAILS_ENV=production -e NODE_ENV=production -e INSTALLATION_ENV=docker \
  -p 127.0.0.1:3099:3000 --entrypoint bundle cortexgen-chat:test exec rails s -p 3000 -b 0.0.0.0
sleep 25
curl -s -o /dev/null -w '%{http_code}\n' -H 'X-Forwarded-Proto: https' -H 'Host: prs.cortexgen.cloud' http://127.0.0.1:3099/api
docker rm -f cgtest
```

Sem `X-Forwarded-Proto: https` a resposta é 301, não 200 — não confundir com falha.

### Migrations não rodam sozinhas

O `docker/entrypoints/rails.sh` **não** executa `db:migrate`. Aplicar à mão antes de recriar os containers:

```bash
docker run --rm --network cortexgen-chat_default --env-file .env -e RAILS_ENV=production \
  cortexgen-chat:test bundle exec rails db:migrate
```

### O rollback custa um rebuild

A tag `:v1` é sobrescrita a cada deploy, então voltar exige `git checkout <sha>` + build. Vale migrar para tags versionadas (`:v1-<sha>`) — ainda não feito.

### Nenhum lint roda no checkout do Mac

Sem `node_modules` e sem rbenv, `rubocop` e `eslint` nunca rodam localmente. O `docker build` é o único gate de sintaxe, e o passo 4 é o único gate de boot.

### Acesso do Claude

`.claude/settings.local.json` (fora do git) libera `git push` e `ssh` para `187.77.20.155` com a chave `id_ed25519_cortexgen`. O Claude executa push, deploy e testes direto.

## Bugs corrigidos (não repetir)

### Guard descartava tudo (sessão 07/08)
O Chatwoot atribui a conversa **ao próprio agent bot**, então o payload chega com `meta.assignee_type = "AgentBot"`. O filtro "humano já assumiu" lia qualquer `assignee` preenchido e abortava — o Nathan se filtrava. Correção: `if (meta.assignee_type === 'User') return [];`

### Historico com 401 "Authorization failed" (sessão 08/08)
Token de **Agent Bot só serve para uma whitelist fechada** de endpoints — `app/controllers/concerns/access_token_auth_helper.rb` (`BOT_ACCESSIBLE_ENDPOINTS`): em `conversations` só `show/toggle_status/toggle_typing_status/toggle_priority/create/update/custom_attributes`; em `messages` só `create`. **`messages#index` (o GET do Historico) não está na lista** → 401. E `conversations#show` não substitui: devolve só a última mensagem.
Correção: nó **Historico** usa credencial `Chat User Token` (Header Auth `api_access_token` com token de **User** do painel, Profile Settings → Access Token). **Responde** e **Handoff** continuam com o token do bot (`CortexGen Chat Bot (api_access_token)`) — é isso que assina a resposta como Nathan.

---

## Estado dos subsistemas

### Infra ✅
- VPS srv1365122 (`187.77.20.155`), stack em `/opt/cortexgen-chat` (imagem `cortexgen-chat:v1`)
- rails (porta 3021) + sidekiq + postgres pgvector + redis — isolado do Chatwoot antigo (`chat.cortexgen.cloud`, porta 3020)
- nginx + Let's Encrypt (renova sozinho, expira 2026-11-05)
- Fork `prsbrands/chatwoot`, branch `feature/cortexgen-whitelabel`. Produção e GitHub sincronizados em `9d2c4ef94`
- Edição Community/MIT: `DISABLE_ENTERPRISE=1`, `DISABLE_TELEMETRY=true`
- Conta: **PRS Global Business** (id 1), flag `disable_branding` ativa

### Canais ✅
| Inbox | Canal | Como conecta |
|---|---|---|
| 2 — WA Com Cortex | WhatsApp (API) | OpenWA `com.cortexgen.cloud`, plugin chatwoot-adapter instância `teste`, ingress `/api/ingress/chatwoot-adapter/teste/chatwoot` |
| 8 — prsbrands | Instagram DM | App Meta **CortexComm** (1012302828635509), webhook `/webhooks/instagram` |
| 9 — PRS Brands | Facebook Messenger | Mesmo app, webhook `/bot`, Login Config `1809600620222184` |
| 10 — Website | Widget do site | Token `MrtKJhxPBc9DgjjCaU4so6o1`, cor #7C3AED |

- Instâncias do chatwoot-adapter **só podem ser criadas via API REST** (o painel gera um secret que nunca bate). Receita: README em github.com/rmyndharis/OpenWA-plugins/tree/main/chatwoot-adapter
- App Review da Meta não foi feito — funciona para as contas próprias (admin do app). Só necessário se terceiros forem conectar.

### Camada de bots — Supabase self-hosted ✅
`supabase.cortexgen.cloud` (container `supabase-db`), schema `public`, prefixo `bot_`.

| Objeto | Papel |
|---|---|
| `bot_personas` | Identidade, `system_prompt`, provider, `model`, `fallback_model`, temperature, `max_tokens`, `handoff_rules` |
| `bot_channel_routes` | inbox → persona; `is_active` liga/desliga o bot no canal; `overrides` jsonb; `channel_kind` text\|voice |
| `bot_knowledge_docs` / `bot_persona_knowledge` | Base de conhecimento; `is_global` entra no prompt de todas as personas |
| `bot_conversation_state` | Memória curta por conversa (ainda **não usada** pelo workflow) |
| `bot_interactions` | Log por chamada: modelo, tokens, latência, status |
| `bot_route_resolved` (view) | O que o n8n consome: 1 GET por inbox, devolve `composed_prompt` = persona + conhecimento |

- **RLS ligado sem policies**: anon key retorna `[]`, só a `service_role` lê. View com `security_invoker = true`. Chaves em `/opt/supabase/.env`.
- Personas ativas: **`nathan-website`** (inbox 10), **`nathan-social-dm`** (inboxes 8/9) e **`nathan-whatsapp`** (inbox 2) — as duas últimas são clones do nathan-website com etiqueta do canal, criadas 2026-08-08 via `persona_nathan_social.sql` / `persona_nathan_whatsapp.sql` (scratchpad). Todas as 4 rotas ativas.
- Persona `atendimento-prs` está **obsoleta, não usar como está**: aponta `provider: anthropic` / `claude-sonnet-5` — o workflow chama OpenRouter e esse ID de modelo quebraria na chamada. Se reaproveitar (ex.: WhatsApp), trocar para openrouter + modelo válido ou clonar de um dos Nathans.
- Base `prs-brands-core` (6,6 KB, global) vinda de `md/prs-brands-knowledge-base.md`. Decisões editoriais: escrita em espanhol; seção 10 (notas internas) excluída; seção 8 virou **guardrails** — proibido citar percentuais de resultado, inventar preço/prazo ou confirmar agenda.
- Prompt final do Nathan ≈ 11,6 KB (~3k tokens).
- SQL versionável no scratchpad: `bot_layer.sql`, `bot_seed.sql`, `bot_knowledge.sql`, `kb_prsbrands.sql`, `persona_nathan.sql`, `openrouter.sql`. **Vale mover para o repo** se a camada virar permanente.

### Workflow n8n ✅ (publicado e testado, 3,9 s de latência)
`pd5V9pdaldRLUu4C` · webhook `https://n8n.cortexgen.cloud/webhook/cortexgen-bot`

```
Webhook → Guard → Persona (Supabase) → Historico (10 últimas msgs)
  → MontaPrompt → LLM (OpenRouter, reasoning off) → Interpreta → Responde
  → Log (bot_interactions) → PrecisaHandoff → Handoff (toggle_status: open)
```

- Credenciais por nó: **Persona/Log** `Supabase account 2` · **LLM** `OpenRouter account 2` · **Historico** `Chat User Token` (token de User) · **Responde/Handoff** `CortexGen Chat Bot (api_access_token)` (token do bot).
- **Provider OpenRouter**, formato OpenAI-compat. Primário `deepseek/deepseek-v4-flash-0731` ($0.09/$0.18 por M, 1.05M ctx), fallback `tencent/hy3` ($0.13/$0.53, 262K) via o array `models` — o roteador cai no segundo na mesma chamada. Trocar de modelo = UPDATE em `bot_personas`, sem mexer no workflow.
- Merge fields do GHL (`{{contact.first_name}}`, `{{contact.email}}`, `{{contact.call_summary}}`) são substituídos no `MontaPrompt` pelos dados do contato Chatwoot. O atributo `call_summary` existe nos contatos.
- Handoff **determinístico** (keywords + `max_turns` + `content_filter`), não depende do modelo decidir.
- Webhook responde 200 imediato (`responseMode: onReceived`) — senão o Chatwoot considera falha e reenvia enquanto o modelo pensa.
- Erros do OpenRouter vêm no corpo com HTTP 200; `Interpreta` detecta e falha explicitamente.

### Operação do bot no painel do Chatwoot

- **Onde ver as conversas do bot**: elas ficam com status **Pending** (o painel abre no filtro Open por padrão — trocar o filtro de status no topo da lista, ou usar "All Conversations"). Quando o handoff dispara, o workflow faz `toggle_status: open` e a conversa entra na fila Open normal — esse é o sinal para humano assumir.
- **Humano pode intervir a qualquer momento**: se a conversa for atribuída a um User, o Guard se retira sozinho (`assignee_type === 'User'`).
- **Atribuição do bot é por inbox, em DUAS camadas que precisam concordar**:
  1. Chatwoot: Settings → Inboxes → *inbox* → **Bot Configuration** → selecionar "Nathan" (é o que faz o webhook disparar). Hoje: só inbox 10.
  2. Supabase: rota em `bot_channel_routes` com `is_active = true` (é o que dá persona ao `MontaPrompt`). Hoje: só inbox 10; rotas 2/8/9 inativas.
  Só Chatwoot ligado → Guard passa mas MontaPrompt descarta (sem persona). Só Supabase → webhook nem dispara.
- **"Give the team a way to reach you." / "Get notified by email" NÃO são do bot** — são o *email collect box* do widget (`inbox.enable_email_collect`, template disparado por `app/services/message_templates/hook_execution_service.rb` quando o contato não tem e-mail). O visitante via como cartão pedindo e-mail. **Desligado na inbox 10 em 2026-08-08** (`enable_email_collect: false`) — o prompt do Nathan já pede e-mail no momento certo da conversa. Religar (se quiser): Settings → Inboxes → Website — PRS Brands → Configuration → "Enable email collect box". Esses templates também disparam o webhook do bot, mas o Guard os descarta (`message_type !== 'incoming'`).

---

## Armadilhas descobertas (custaram tempo)

- **SDK do n8n MCP**: parâmetros só persistem em `config: { parameters: {...} }`. Usar `config: {...}` direto ou `parameters: {...}` passa na validação (`valid: true`) e grava o nó **vazio**, sem erro. Conferir sempre lendo `workflow_entity.nodes` no sqlite de `n8n-y4jd-n8n-1` (`/home/node/.n8n/database.sqlite`) — o mesmo banco serve para ler execuções (`execution_entity` / `execution_data`, formato de string-table: valores numéricos são índices no array).
- **`update_workflow` do n8n MCP APAGA as credenciais** dos nós HTTP (e regenera os IDs dos nós) — o campo `credentials` no código SDK é descartado silenciosamente. Receita para editar o workflow do bot sem clique manual: (1) `docker exec n8n-y4jd-n8n-1 n8n export:workflow --id=pd5V9pdaldRLUu4C --output=/tmp/wf.json`; (2) editar o JSON (nós, e reinjetar `credentials: {tipo: {id, name}}` — ids na tabela `credentials_entity`); (3) `n8n import:workflow --input=...` (desativa o workflow!); (4) publicar de novo (MCP `publish_workflow` reativa). Sintaxe do SDK que valida: nós como objetos `{type, version, name, config:{parameters}}` e `wf.add(a).to(b).to(c)`.
- **Cópia do sqlite do n8n para debug**: copiar também o `-wal` (`database.sqlite-wal`), senão a cópia fica minutos atrasada e execuções recentes "não existem".
- **Claude Sonnet 5 / Opus 5** (se um dia voltar para a Anthropic direto): rejeitam `temperature`/`top_p`/`top_k` com **HTTP 400**, e o *adaptive thinking* é o padrão quando `thinking` é omitido — com `max_tokens` limitando pensamento + resposta juntos. Mandar `thinking: {type:'disabled'}` ou dar folga no `max_tokens`.
- **Endpoint público de widget**: `/public/api/v1/inboxes/{token}/...` é para inbox do tipo **API**, não para widget de site. Para testar o widget, injetar a mensagem via `rails runner` (receita no topo).

---

## Pendências

### 1. E-mail — bloqueado por rede (a mais antiga)
`mail.prsbrands.com` (GreenGeeks, 65.60.38.74) é **inalcançável da VPS**: ping 100% loss e timeout em todas as portas (25/80/443/465/587/993). `mtr` mostra a rota morrendo no salto 4 — borda da Hostinger → GreenGeeks. É bloqueio de rede/edge, **não** o firewall CSF do servidor (por isso o suporte "não vê bloqueio"; o whitelist de 24h não teve efeito). Da rede local do Paulo tudo conecta.

O `.env` já está com SMTP correto (`mail.prsbrands.com:465`, `postmaster@prsbrands.com`, senha gravada, `SMTP_TLS=true`) — só não trafega.

**Recomendado:** relay transacional (Brevo 300/dia ou Resend 3k/mês) mantendo remetente `@prsbrands.com`, validando SPF/DKIM por DNS; trocar `SMTP_*` no `.env` + `docker compose up -d --force-recreate rails sidekiq`. IMAP sofre o mesmo bloqueio → inbox de e-mail terá que ser por **encaminhamento** (`MAILER_INBOUND_EMAIL_DOMAIN` + ingress Mailgun/SES).

**Enquanto isso:** reset de senha e convites de agente não saem.

### 2. Expandir o bot para os outros canais ✅ (WhatsApp validado com número real em 2026-08-09)
**Instagram (8) e Messenger (9): funcionando** ✅ — testados com DM real em 2026-08-08, rotas ativas com `nathan-social-dm`. (Diagnóstico útil do primeiro DM sem resposta, execução 9455: webhook e Guard OK, `Persona` voltou `[]` porque a rota estava inativa — o sintoma de rota inativa é o bot ficar mudo com execução `success`.)
**WhatsApp (2): funcionando** ✅ — validado em 2026-08-09 com número real: bot desconectado e reconectado num número novo pela página de sessões, respondendo. Persona `nathan-whatsapp` (`persona_nathan_whatsapp.sql` no scratchpad), canal via OpenWA em `com.cortexgen.cloud` (2 plugins próprios + chatwoot-adapter). Gestão de sessões pelo painel é a pendência 4.

### 3. Agente de voz
Canal de voz nativo é enterprise (fora do escopo MIT). Desenho combinado: a chamada acontece no stack de voz próprio (`voice-agent` / `voicept.cortexgen.cloud` na mesma VPS) e o n8n empurra transcrição + resumo + gravação para uma **inbox API "Voz"** no Chatwoot. `bot_channel_routes.channel_kind` já prevê `voice`.

### 4. Sessões do WhatsApp pelo painel — CONSTRUÍDO em 2026-08-08 (commit `9eabcc9fe`)
Decisões do Paulo: público em duas etapas (interno → clientes finais) e página nativa no fork. Motivação extra: o plugin **`prs-agent` v0.2.2** no OpenWA (sessão `teste`) faz papel parecido com o do Nathan — número novo em sessão nova evita o conflito e usa a integração Chatwoot+n8n.

**O que foi entregue (fase 1, admin-only):**
- Card "WhatsApp Sessions" em Settings → Integrations (aparece só com `OPENWA_API_URL`/`OPENWA_API_KEY` no env) → página que lista sessões com status/telefone/inbox, cria sessão nova, mostra **QR para parear** (polling 3 s até `ready`), start/stop/logout/delete.
- Backend: `lib/integrations/openwa/client.rb` (client HTTParty, header `X-API-Key`), `lib/integrations/openwa/provision_service.rb` (orquestração), controller `api/v1/accounts/{id}/integrations/openwa/sessions` (admin-only via `check_admin_authorization?`; erros do gateway → 422 com mensagem).
- **Provisionamento em 1 clique**: sessão OpenWA → inbox `Channel::Api` com `webhook_url` = ingress do adapter (webhook **escopado à inbox**, assinado com `channel.secret` — melhor que webhook de conta, que manda eventos de todos os canais) → instância do adapter cunhada via REST com `secret = channel.secret` (mata a armadilha do 401) → vínculo `AgentBotInbox` (bot selecionável no dialog) → rota em `bot_channel_routes` via PostgREST (persona de `OPENWA_BOT_PERSONA_SLUG`, default `nathan-whatsapp`) → start da sessão. Rollback best-effort se algum passo falhar.
- Deleção remove sessão + instâncias do adapter; **inbox é preservada** (apagar inbox destrói conversas — fica no fluxo normal de Settings → Inboxes).
- Env no `/opt/cortexgen-chat/.env` (backup em `.env.bak-openwa`): `OPENWA_API_URL=https://com.cortexgen.cloud`, `OPENWA_API_KEY` (= API_MASTER_KEY do container openwa-api), `SUPABASE_REST_URL`, `SUPABASE_SERVICE_ROLE_KEY` (de `/opt/supabase/.env`), `OPENWA_BOT_PERSONA_SLUG=nathan-whatsapp`.

**Melhorias de UX (commit `4faef5c54`, feedback do Paulo no primeiro uso):** a lista mostra o **nome** da inbox (não `#id`); o dialog de criação tem seletor de inbox — padrão "criar inbox nova" (recomendado), mas dá para **reaproveitar uma inbox de API existente** (o webhook dela é reapontado para o ingress da sessão; inboxes já usadas por outra sessão não aparecem); textos deixam explícito que **cada sessão = um número**, que várias sessões rodam em paralelo e que nada precisa ser criado antes. Inbox reaproveitada nunca é destruída no rollback; vínculo de bot e rota Supabase viraram upsert.

**Deploy + dry-run validados em 2026-08-08**: imagem rebuildada, envs ativas, e um provisionamento de teste (`zz-teste-painel`) criou toda a cadeia — sessão com QR real (`qr_ready` + imagem), inbox com webhook no ingress, instância do adapter, Nathan vinculado e rota no Supabase (`bot_route=created`) — e foi limpo em seguida. Falta só o teste com pareamento de número real, que exige o telefone.

**Fase 2 (pendente):** multi-tenant — mapear conta ↔ sessão (hoje a página lista TODAS as sessões do gateway, ok para uso interno), esconder sessões de outras contas, e provisionamento self-service por cliente.

**API do OpenWA (referência):** NestJS em `127.0.0.1:2785` (público via nginx `com.cortexgen.cloud`), auth header `X-API-Key`, spec em `/home/n8n-deploy/apps/openwa/openapi.json`. Sessões: `POST/GET /api/sessions`, `/{id}/qr` (devolve `{qrCode: dataURL, status}`), `/start|stop|logout`, status ∈ created|initializing|qr_ready|authenticating|ready|disconnected|action_required|failed. Instâncias de plugin: `/api/integration/plugins/chatwoot-adapter/instances`.

### 5. Bot Personas no painel — CONSTRUÍDO em 2026-08-08 (commit `0644c3d23`)
Pedido do Paulo (com referência aos cards do GHL): o usuário editar ele mesmo persona, modelos e base de conhecimento do bot, sem SQL.

**Entregue (admin-only, mesmo padrão do OpenWA — Rails proxya o Supabase com a service key; card some sem as envs):**
- Card **"Bot Personas"** em Settings → Integrations + botão "Bot personas" na tela de **Bots** (Settings → Bots).
- Aba **Personas**: cards por persona; editor com prompt (textarea mono), provider/model/fallback, temperature, max_tokens, keywords de handoff (vírgula) e max_turns, ativo/inativo. Slug travado na edição. Criar/excluir persona (excluir falha com mensagem se houver rota apontando — FK).
- Aba **Knowledge base**: docs markdown com global/vinculado por persona (checkboxes), prioridade, ativo. Salvar reescreve os vínculos em `bot_persona_knowledge`.
- Aba **Channels**: tabela inbox → persona com switch liga/desliga (upsert em `bot_channel_routes`); lembra na ajuda que a inbox também precisa do agent bot no Bot Configuration.
- Backend: `lib/integrations/botlayer/client.rb` (PostgREST, valida UUIDs antes de interpolar em filtros) + controllers em `api/v1/accounts/{id}/integrations/botlayer/{personas,knowledge,routes}`.
- **Mudança de prompt/modelo vale na próxima mensagem** — o workflow n8n lê a view a cada chamada, sem deploy.
- Fase 2 junto com o multi-tenant do OpenWA: personas não têm coluna de conta (globais); ok para uso interno.
**Editores em página dedicada (commit `93347405d`)** — o textarea do prompt aparecia com 2 linhas: `rows="14"` não segura altura dentro do flex column limitado do Dialog (o item encolhe). Persona e documento saíram do modal para **páginas full-screen**, montadas **fora do `SettingsWrapper`** (que impõe `max-w-5xl` e altura automática) — rotas de nível superior em `integrations.routes.js`. Layout: editor grande à esquerda (`flex-1` + `min-h-0`, o `min-h-0` é o que impede o encolhimento) e sidebar de configurações à direita. O header da persona mostra **quantos caracteres chegam ao modelo** (prompt + base de conhecimento), que antes era invisível. Combobox virou componente compartilhado `ModelCombobox.vue`.

**AI Providers como integração própria + chaves por conta (commit `335873044`)** — pergunta do Paulo: "onde o cliente a quem eu cedo o painel coloca as chaves dele?". Respostas:
- **Canais de mensageria (Twilio, 360dialog, WhatsApp Cloud, Telegram, Line, Bandwidth, e-mail)**: já é nativo do Chatwoot — Settings → Inboxes → Add Inbox, credenciais por conta e criptografadas (`encrypts :auth_token`). Não duplicar.
- **LLMs**: era a lacuna real. A aba Providers saiu de dentro de Bot Personas e virou o card **AI Providers** em Integrations, com **`bot_providers.chatwoot_account_id`** (unique por conta+slug, SQL em `bot_providers_per_account.sql`) — cada conta só lê/escreve as próprias chaves (filtro aplicado no client PostgREST em toda operação). A view resolve o provider dentro da conta da rota.
- Presets de 1 clique (OpenRouter, Anthropic, OpenAI, Groq, DeepSeek, Mistral) preenchem URL + api_style; só falta colar a chave. Chave nunca volta ao browser (mascarada).
- **Bug de largura corrigido**: as páginas de editor renderizavam com ~890px porque o root era flex item sem `flex-1` dentro do `<main class="flex flex-1">` do Dashboard.vue. Editor de conhecimento perdeu a sidebar (design errado para documento) — metadados em barra compacta no topo, texto em largura total.

- **Uma tela só para ligar o bot num canal — RESOLVIDO**: antes exigia duas chaves em telas diferentes (Bot Configuration na inbox + switch da rota em Channels) — no caso da `numero2`, mensagens chegavam e a rota estava ativa, mas o `AgentBotInbox` não existia e o bot ficou mudo. Agora a aba **Channels** tem coluna **Agent bot** (obrigatória, já pré-selecionada quando a conta tem um único bot) e o `routes_controller` sincroniza as duas pontas: salvar com o switch ligado cria/ativa o `AgentBotInbox`; desligar o switch ou apagar a rota **desfaz o vínculo** — mas só se o bot ligado for o da própria rota, para não mexer em bot atribuído por fora. Bots globais passaram a ser resolvidos por `AgentBot.accessible_to` (o `account.agent_bots.find` do provisionamento OpenWA daria 404 num bot global listado no seletor).
**Catálogo de fornecedores (commit `948fad663`)** — o campo de modelo era texto livre e o provider não fazia nada (o workflow mandava tudo para o OpenRouter; `atendimento-prs` com `anthropic`+`claude-sonnet-5` teria quebrado). Agora:
- Tabela **`bot_providers`** (`slug`, `label`, `base_url`, `api_style` openai|anthropic, `api_key`, `models` jsonb) — SQL em `bot_providers.sql` no scratchpad. `CHECK` de `bot_personas.provider` removido; a view `bot_route_resolved` ganhou `provider_base_url`/`provider_api_style`/`provider_api_key` **no fim** (`CREATE OR REPLACE VIEW` só permite acrescentar colunas no final — reordenar exige DROP).
- Aba **Providers**: cadastrar qualquer endpoint OpenAI-compat ou Anthropic com chave própria; botão **Sync models** lê o `/models` do fornecedor e grava o catálogo (nada de lista fixa envelhecendo). Chave mascarada na leitura; campo vazio na edição mantém a atual.
- Campo de modelo virou `input` + `datalist`: sugere os modelos sincronizados **e** aceita ID digitado. Vale para principal e fallback.
- Card da persona avisa em vermelho quando o provider não existe no catálogo ou não tem chave.
- **Workflow provider-aware**: `MontaPrompt` monta URL/headers/body pelo `api_style` e ramifica no nó **EscolheProvider** — OpenRouter segue pela credencial do n8n (chave nunca entra nos dados de execução), demais fornecedores vão pelo **LLMCustom** com headers montados. Estilo anthropic manda `system` fora do array, **omite `temperature`** e envia `thinking:{type:'disabled'}` (Claude 5 rejeita temperature com 400). `Interpreta` lê os dois formatos de resposta e de usage.
- Validado em produção: conversas 9 e 10 responderam em **4,8 s / 4,4 s** pelo caminho OpenRouter após a mudança; **Sync models** do OpenRouter trouxe **400 modelos** ao vivo.

**Combobox + fallback cross-provider (commit `778d2bb43`, feedback do Paulo):**
- O campo de modelo usava `<datalist>` nativo, que **esconde as opções quando o campo já tem valor** (por isso "a lista não carrega") — trocado por combobox próprio: abre no foco, filtra ao digitar, aceita qualquer ID.
- Fallback ganhou linha própria com **Fallback provider** (Select, "Same as primary" = null) + Fallback model (combobox com o catálogo do provider do fallback). Coluna `bot_personas.fallback_provider` nova; view expõe `fallback_provider_{base_url,api_style,api_key}` (SQL `bot_fallback_provider.sql` no scratchpad).
- Workflow: nós **TentaFallback** (IF) + **LLMFallback** (HTTP) depois do LLM/LLMCustom, que agora têm `onError: continueRegularOutput` (erro vira dado). `MontaPrompt` monta `fallbackSpec` (URL/headers/body do provider do fallback); `Interpreta` detecta o formato da resposta pelo shape (openai|anthropic), não pelo contexto.
- **Regra da chave**: fallback em outro provider (ou retry separado no mesmo) só acontece se a chave do provider do fallback estiver gravada no `bot_providers` — sem chave, só o fallback nativo do array do OpenRouter (que NÃO cobre erro de validação, ex. modelo inexistente: o request morre antes do roteamento).
- **Provado E2E** com provider mock (workflow `ZZ Mock LLM`, arquivado): primário com modelo inválido → LLMFallback chamou o mock → resposta postada na conversa 13, log `mock-fallback-1`. Regressão do caminho normal OK (conversas 11 e 14, ~2,6 s).

- **Deploy validado em 2026-08-08**: client lê personas (4), docs (`prs-brands-core`) e rotas (inboxes 2/8/9/10/12 ativas) em produção. Obs.: as experiências do Paulo com o pareamento criaram inboxes extras ("WhatsApp — Numero2" #14, "WhatsApp — Prs" duplicadas ~#12/#13) e uma rota ativa na inbox 12 — dá para revisar/limpar pela própria aba Channels + Settings → Inboxes.

### 6. Super Admin — conciliação com o painel de conta (2026-08-09)

Auditoria do que fizemos no Agent Dashboard vs. o que o Super Admin enxerga. **Branding já estava ok** (nav diz "CortexGen Chat", cards premium podados do `app/helpers/super_admin/features.yml` no commit de white label). **Agent bots** também: com o `AgentBot.accessible_to` de hoje, bot global criado no Super Admin funciona no painel de conta.

**Entregue:**
- **Feature flags por conta**: `whatsapp_sessions`, `bot_personas`, `ai_providers` em `config/features.yml` (`column: feature_flags_ext_1`, `enabled: false`). Aparecem em Super Admin → Accounts → Edit. Checadas em `Integrations::App#active?/enabled?` (esconde o card) **e** nos controllers (`raise Pundit::NotAuthorizedError`, que é o gate de verdade). `bot_personas` e `ai_providers` são separadas de propósito: ceder o painel de bots não obriga a ceder as chaves de LLM.
- **Config global saiu do ENV**: `OPENWA_API_URL/KEY/BOT_PERSONA_SLUG` e `SUPABASE_REST_URL/SERVICE_ROLE_KEY` passaram a ser lidas por `GlobalConfigService.load`, com entradas em `config/installation_config.yml` e páginas **Super Admin → Settings → WhatsApp Gateway / Bot Layer**. O `GlobalConfigService` cai no ENV enquanto o `InstallationConfig` não existir e **grava o valor do ENV na primeira leitura** — não precisa migrar nada, e as envs do `.env` podem sair depois.
- **Prontidão das outras integrações** (nenhuma ligada, decisão do Paulo): `shopify_integration` perdeu `chatwoot_internal` (a flag era invisível no Super Admin self-hosted, então o card nunca ligava) e a página **AI Assistant** (`config_key: captain`) voltou ao Super Admin. Agora toda integração listada no painel é conectável só colando credencial — exceto o card **OpenAI**, ver abaixo.

**Card OpenAI é morto** — não há processor para `'openai'` no `HookJob` e a implementação está em `enterprise/`. Com `DISABLE_ENTERPRISE=1` o cliente cola a chave e nada acontece. Decidir: remover do `config/integration/apps.yml` ou apontar para a nossa camada de bots.

**Achado que corrige uma premissa**: os serviços de escrita do composer (`rewrite`, `summarize`, `reply_suggestion`, `label_suggestion`) estão em `lib/captain/` e `lib/llm/` — **árvore MIT**, não enterprise. `Llm::Config` lê `CAPTAIN_OPEN_AI_API_KEY` + `CAPTAIN_OPEN_AI_ENDPOINT` do `InstallationConfig` e o `openai_api_base` é configurável, ou seja **aponta para o OpenRouter que já usamos**. O que está em `enterprise/` é o Captain "produto" (assistentes, documentos, RAG). Falta validar ponta a ponta; a flag `captain_integration` está marcada `premium`.

**Ainda aberto (fase 2 multi-tenant):** `bot_personas` e `bot_knowledge_docs` não têm coluna de conta (só `bot_channel_routes` e `bot_providers` têm) — admin da conta B edita persona da conta A.

### 7. CortexGen AI — assistente de escrita (2026-08-09, commit `0759ce331`)

O "Captain" do Chatwoot são **duas coisas** com o mesmo nome:

| | Captain **produto** | Captain **tasks** |
|---|---|---|
| O que é | Assistentes, documentos, RAG, copilot lateral | Assistente de escrita do compositor: reescrever, resumir, sugerir resposta, sugerir etiquetas |
| Código | `enterprise/` | `lib/captain/` + `lib/llm/` — **MIT** |
| Flag | `captain_integration` (premium, off) | `captain_tasks` — `enabled: true`, **já ligada em toda conta** |

Só o segundo é nosso. Renomeado para **CortexGen AI** em todas as strings EN visíveis; rotas, flags e classes seguem `captain*` de propósito, para não divergir do upstream.

**De quem é a chave** — `lib/captain/base_task_service.rb:179`, precedência:
1. **Chave da conta**: card **OpenAI** em Settings → Integrations do cliente (`account.hooks` do app `openai`). Todos os 7 serviços de tarefa marcam `use_account_openai_hook? = true`.
2. **Fallback, chave nossa**: `CAPTAIN_OPEN_AI_API_KEY` em Super Admin → Settings → CortexGen AI.

O toggle "Show label suggestions" dentro do card OpenAI é o que liga as sugestões de etiqueta. **O card OpenAI não é decorativo** — ele não processa eventos (não está no `HookJob`), é cofre de chave. Não remover.

**Pegadinha do endpoint**: `api_base` lê só `CAPTAIN_OPEN_AI_ENDPOINT`, que é **global**. Todas as chaves — a nossa e a dos clientes — têm que ser do mesmo fornecedor. Decisão de 2026-08-09: **começar com OpenAI direto** (endpoint vazio = `https://api.openai.com/`).

**Para trocar por OpenRouter depois** não basta trocar o endpoint: `config/llm.yml` é um catálogo fechado por feature (default `gpt-4.1-mini`) e o `Llm::FeatureRouter` só aceita modelo dessa lista, validada contra `config/llm_models.json`. Os IDs teriam que virar `openai/gpt-4.1-mini` etc. — reescrita do catálogo, ~meio dia.

`CAPTAIN_OPEN_AI_MODEL` **não afeta o assistente de escrita** (só o runtime de agents em `config/initializers/ai_agents.rb`); os modelos vêm do `config/llm.yml` por feature.

### 8. Cosméticas
- **Logos** são placeholders gerados (círculo violeta + "C", #7C3AED) — trocar pela arte oficial mantendo os nomes de arquivo em `public/brand-assets/`, favicons em `public/`, e assets em `app/javascript/{widget,dashboard,design-system}`; depois rebuildar a imagem.
- **Locales não-EN** ainda dizem "Chatwoot" (`app/javascript/dashboard/i18n/locale/pt_BR/` etc.).
- **Push mobile**: relay da Chatwoot desativado (`ENABLE_PUSH_RELAY_SERVER=false`); gerar VAPID se quiser web push.
- **Segurança do webhook**: `https://n8n.cortexgen.cloud/webhook/cortexgen-bot` é um endpoint aberto. O Chatwoot assina os payloads (`X-Chatwoot-Signature`, HMAC com o Webhook Secret do bot); validar no Guard são ~10 linhas.

---

## Operação

```bash
# Deploy — SEMPRE construir com :test antes (ver "Protocolo de deploy" no topo)
cd /opt/cortexgen-chat/src && git pull \
  && docker build -f docker/Dockerfile -t cortexgen-chat:test . \
  && docker build -f docker/Dockerfile -t cortexgen-chat:v1 . \
  && cd .. && docker compose up -d --force-recreate rails sidekiq \
  && docker compose ps
```

```bash
# Serviço de voz — o smoke test NÃO é opcional (ver armadilha do Pipecat no topo)
cd /opt/cortexgen-voice && docker compose build \
  && docker compose run --rm --entrypoint python voice smoke.py \
  && docker compose up -d && curl -s localhost:8095/health
```

- Logs do bot de voz: `docker logs -f cortexgen-voice`
- Logs: `docker compose logs -f rails` em `/opt/cortexgen-chat`
- **Mudança no `.env` exige `up -d --force-recreate`** — `restart` não relê o env
- Rails console: `docker compose exec rails bundle exec rails console`
- Supabase: `docker exec supabase-db psql -U postgres -d postgres`
- Acesso SSH: `ssh -i ~/.ssh/id_ed25519_cortexgen root@187.77.20.155`

## Decisão de licença (não reabrir sem motivo)

Rodamos a **edição Community (MIT)** com `DISABLE_ENTERPRISE=1`. Isso é o que torna o white label legal e desliga o job noturno que reverteria o branding. SLA, Captain AI, custom roles, audit logs, SAML e canal de voz ficam de fora — são da licença comercial da Chatwoot. Para tê-los, é comprar a assinatura e remover o env var.
