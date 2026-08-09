# PLANO — Twilio, SMS e Agente de Voz próprio

Escrito em 2026-08-09. Decisões do Paulo já incorporadas:

- Credenciais Twilio **por conta de Agent** (admin da conta), não no Super Admin.
- **Sem Vapi.** Orquestração de voz é nossa, rodando na nossa VPS.
- **OpenRouter** como provedor de LLM.
- Linhas são VoIP: o agente humano atende em **softphone externo** (Zoiper) — não construímos softphone no browser.
- Roteamento estilo GHL: define-se quem atende primeiro e, se o humano não atende, **transborda para o bot**.
- O `picosms` e o `voice-agent` que já rodam na VPS são de **outros clientes** e não entram neste desenho. Convivência por números diferentes.

---

## Como o Chatwoot é hoje (levantado no código, não suposto)

**SMS Twilio é 100% MIT e já funciona.** `Channel::TwilioSms` guarda `account_sid` + `auth_token` criptografados por inbox; entrada em `/twilio/callback`, saída em `Twilio::SendOnTwilioService`, status de entrega, campanhas e templates. Tudo aproveitável.

**Voz é inteiramente enterprise, e mais fechada do que parece:** as rotas estão atrás de `if ChatwootApp.enterprise?` em `config/routes.rb:696`, então com `DISABLE_ENTERPRISE=1` os webhooks de voz **não existem como rota**. Modelo `Call`, `Voice::Conference::Manager`, `Voice::Provider::Twilio::Adapter` e o token service estão todos em `enterprise/`. A arquitetura deles (Twilio Conference + SDK no browser) não é reaproveitável nem desejável aqui.

**Mas o esquema do banco é MIT:** `channel_twilio_sms` já tem `voice_enabled`, `twiml_app_sid`, `api_key_sid` e `api_key_secret`. Não precisamos de migration para ligar voz no canal.

**Regra de ouro:** nada em `enterprise/` é lido ou copiado. Rotas, modelos e serviços de voz são nossos, em namespace próprio, para não colidir se um dia a licença mudar.

---

## Arquitetura em três camadas

| Camada | Componente | Responsabilidade |
|---|---|---|
| Telefonia | **Twilio** | número, PSTN, SIP Domain dos agentes, gravação |
| Controle | **CortexGen Chat** | credenciais, números, regras de roteamento, persona de voz, conversas, relatórios |
| Mídia | **cortexgen-voice** (novo) | áudio em tempo real: STT → LLM → TTS, VAD, turnos, barge-in |

O Chatwoot **não processa áudio**. Ele configura, decide o roteamento e registra o resultado.

### Por que Pipecat

Pipecat é biblioteca MIT em Python, não fornecedor. Roda na nossa VPS, com as nossas chaves, e resolve a parte ingrata: WebSocket de áudio do Twilio, VAD, gestão de turnos e barge-in (cortar a fala do bot quando o cliente interrompe). É a diferença entre um bot que soa natural e um que atropela. Escrever esse laço do zero é o maior risco técnico do projeto e não agrega diferencial de produto.

**Serviço novo e independente** — não reaproveita o `voice-agent` existente, que é de outro cliente.

### OpenRouter cobre só o LLM

Uma chamada em tempo real precisa de três provedores:

| Peça | Provedor | Observação |
|---|---|---|
| STT | Deepgram / Soniox / AssemblyAI | streaming, com detecção de fim de turno |
| LLM | **OpenRouter** | reaproveita `bot_providers` e a persona que já existem |
| TTS | **ElevenLabs** | `voice_id` colado pelo cliente, como pedido |

Consequência de projeto: `bot_providers` ganha a coluna **`kind`** (`llm` \| `stt` \| `tts`). O cliente cadastra as três chaves na mesma tela de AI Providers que já construímos, com o mesmo isolamento por conta.

---

## Fases

### Fase 0 — Fundação: credenciais e números ✅ ENTREGUE

- Card **Twilio** em Settings → Integrations (admin da conta). Account SID + Auth Token, criptografados, no nível da **conta**.
- Ao salvar, valida contra a API do Twilio e **lista os números com as `capabilities` de cada um** (`sms`, `mms`, `voice`). É assim que o cliente descobre que um número não faz SMS **antes** de tentar, em vez de na falha.
- ~~`bot_providers.kind`~~ — **adiado de propósito para a Fase 3**: nada leria a coluna até o serviço de voz existir.
- Tela mostra os webhooks de cada número com **copiar** e **configurar automaticamente** (a API do Twilio permite escrever `sms_url` e `voice_url` no número — o `Twilio::WebhookSetupService` MIT já faz isso para SMS).

**Entrega:** conectar o Twilio e ver os números com o que cada um sabe fazer.

### Fase 1 — SMS inbound e outbound ✅ ENTREGUE

**Paginação e busca da lista de números** (entregue junto) (pedido do Paulo em 2026-08-09, ao ver a Fase 0 funcionando com a conta real). A tabela cresce sem limite na vertical. Não é só CSS: `client.incoming_phone_numbers.list` pagina sozinho e traz **todos** os números, então uma conta grande vira várias chamadas à API do Twilio e um payload pesado a cada abertura da tela.

Fazer junto com o provisionamento, porque a Fase 1 mexe nessa mesma tabela de qualquer forma:
- backend: usar `page`/`page_size` da API do Twilio em vez de `list`, devolvendo o cursor
- frontend: busca por número ou apelido, filtro por capability, e paginação
- busca provavelmente vale mais que paginação pura — com 50 números, quem procura um específico não quer folhear


- Provisionamento em 1 clique: escolhe o número → cria a inbox `Channel::TwilioSms` → grava o webhook no Twilio via API. Mesmo padrão do OpenWA.
- Números sem capability `sms` aparecem desabilitados com o motivo.
- **Aviso de A2P 10DLC** quando o número for US e não estiver registrado — é bloqueio regulatório do Twilio, e o cliente precisa saber disso na tela, não no primeiro envio que falha.

**Herdamos de graça:** entrada, saída, status de entrega, campanhas de SMS, templates.

### Fase 2 — Voz: roteamento e atendimento humano ✅ ENTREGUE

- Rotas próprias `/voice/twilio/...` (as EE estão atrás do gate e não podem ser usadas).
- Modelo próprio de chamada (`voice_calls`), sem relação com o `Call` do enterprise.
- **Regras de roteamento por número**, na linha do que a GHL faz:
  - quem atende primeiro: humano ou bot
  - destino humano: **SIP endpoint** (Zoiper, via Twilio SIP Domain) ou número PSTN
  - `timeout` de toque
  - o que fazer se não atender: transbordar para o bot, voicemail ou desligar
- Implementação: TwiML `<Dial timeout="N" action="...">`. Quando o dial termina, o Twilio chama a `action` com `DialCallStatus` (`no-answer`, `busy`, `failed`) e nós devolvemos o próximo passo. **O transbordo é nativo do Twilio** — não precisamos inventar máquina de estado.
- Gravação e status callbacks viram mensagens numa conversa da inbox de voz.

**Entrega:** ligar para o número, tocar no Zoiper do agente, e se ninguém atender cair no bot.

### Fase 3 — Bot de voz  ⬅️ PRÓXIMA

**Decisões já tomadas pelo Paulo, não reabrir:** orquestração é nossa (sem Vapi), LLM pelo **OpenRouter**, motor de mídia é **serviço novo usando Pipecat** — independente do container `voice-agent` que já roda na VPS, que é de outro cliente.

#### O que já existe e deve ser reaproveitado

`bot_personas` no Supabase (colunas conferidas em 09/08): `id, slug, display_name, description, system_prompt, provider, model, temperature, max_tokens, handoff_rules, is_active, fallback_model, fallback_provider`. A view `bot_route_resolved` já entrega `composed_prompt` (persona + base de conhecimento) numa chamada — é o que o workflow de texto consome e o que o serviço de voz deve consumir também.

`bot_providers`: `id, slug, label, base_url, api_style, api_key, models, is_active, chatwoot_account_id`. Hoje só tem `anthropic`, `openai` e `openrouter` — **todos de LLM**.

`twilio_voice_routes` (Postgres do Chatwoot): `phone_number, destination_type (sip|pstn), destination, ring_timeout, enabled`. **Não tem coluna de modo** — quem atende hoje é sempre humano. O bot entra aqui.

#### Trabalho da fase

1. **`bot_providers.kind`** (`llm` | `stt` | `tts`) + presets de Deepgram e ElevenLabs na tela de AI Providers. OpenRouter não faz STT nem TTS — são três provedores, três chaves, mesma tela e mesmo isolamento por conta.
2. **Campos de voz na persona** — voz (provider + `voice_id` da ElevenLabs), transcritor, primeira mensagem, e os tempos que definem a sensação da conversa: espera antes de falar, fim de turno, interrupção. Preferir colunas anuláveis em `bot_personas` a uma tabela nova com join.
3. **Modo na rota** — `twilio_voice_routes` ganha quem atende primeiro (humano ou bot) e o que fazer no transbordo. A estrutura do `<Dial timeout action>` já está pronta para receber isso.
4. **Serviço `cortexgen-voice`** — FastAPI + Pipecat, container e subdomínio próprios, **`wss://`** (Twilio Media Streams exige TLS). Busca a configuração no Chatwoot por número.
5. **TwiML `<Connect><Stream>`** quando a rota estiver em modo bot.
6. **Página de configuração** na convenção da Vapi.
7. **Fim da chamada** → transcrição, resumo e gravação viram conversa numa inbox de voz.

#### Riscos específicos desta fase

- **Latência é o produto.** Alvo abaixo de 1,5 s da fala à resposta. A Vapi do próprio Paulo usa GPT-4.1 Nano por esse motivo — não foi economia, foi latência. Isso limita o quanto o bot pode ser "inteligente".
- **Concorrência**: cada chamada é um processo com áudio em tempo real. Quantas simultâneas a VPS aguenta é medição, não estimativa — fazer antes de vender.
- **Custo por minuto** soma STT + LLM + TTS + Twilio. Precisa aparecer no painel desde o início, ou o cliente descobre na fatura.
- **`wss://` novo no nginx** — proxy de WebSocket é configuração diferente de HTTP, com `Upgrade`/`Connection` e timeouts longos.

### Fase 4 — Operação e apresentação

- Log por chamada com duração, custo de STT/LLM/TTS e latência — mesmo padrão de `bot_interactions`, que já provou o formato.
- Relatório de chamadas por número, resultado e custo.
- Revisão de todas as telas de webhook: URL exata, copiar, auto-configurar.

---

## Riscos, declarados antes de começar

1. **A2P 10DLC** — número US precisa de registro para SMS. Dias a semanas, depende do Twilio, não de nós. A tela avisa, mas não resolve.
2. **Latência é o produto.** Alvo abaixo de 1,5 s da fala do cliente à resposta. Cada hop conta: STT streaming, modelo rápido no OpenRouter, TTS com streaming. Modelo "inteligente demais" mata a experiência — a Vapi que você montou usa GPT-4.1 Nano por esse motivo.
3. **Custo por minuto** soma três provedores mais o Twilio. Precisa ficar visível no painel desde a Fase 3, ou o cliente descobre na fatura.
4. **Concorrência**: cada chamada é um processo com áudio em tempo real. Quantas simultâneas a VPS aguenta é medição, não estimativa — fazer antes de vender.
5. **SIP**: exige criar um Twilio SIP Domain e credenciais por agente. É configuração de telefonia que não existe hoje no painel; entra como tela na Fase 2.
6. **Não tocar em `enterprise/`.** Todo código de voz é nosso, em namespace próprio.

---

## Ordem sugerida

Fase 0 → 1 → 2 → 3 → 4. As fases 0 e 1 entregam valor demonstrável rápido e são de baixo risco. A Fase 2 é o que torna o produto vendável para telefonia. A Fase 3 é a que tem risco técnico real e deve começar só com as anteriores em produção.
