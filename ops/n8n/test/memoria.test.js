// Memoria da IA: a secao no MontaPrompt e os nos do workflow "CortexGen
// Memória" (Candidatos, MontaMemoria, GravaMemoria) com o n8n e as APIs falsos.
//   node ops/n8n/test/memoria.test.js
const run = require('./harness');
const R = require('path').join(__dirname, '..') + '/';
const ok = (n, c) => console.log((c ? 'OK ' : 'FALHOU ') + n);
(async () => {
  // --- MontaPrompt -------------------------------------------------------------
  const guard = { accountId: 1, conversationId: 89, chatUserToken: 't', content: 'hola', contactName: 'Ana', jev: {} };
  const persona = { persona_id: 1, composed_prompt: 'PERSONA', system_prompt: 'PERSONA', model: 'm' };
  const hist = { payload: [{ message_type: 0, content: 'hola de nuevo', private: false }] };
  const nodes = { Guard: guard, Persona: persona, JevEntrada: { jev: {} }, Historico: hist };
  const memoria = { summary: 'Duena de 3 tiendas en Colon; quiere el plan anual.', facts: ['Quiere el plan anual', 'Prefiere hablar despues de las 18h'] };
  let r = await run(R + 'monta_prompt.js', nodes, {}, { 'ai_memory/bot/contact': [200, memoria] });
  const sys = r.out[0].json.body.messages[0].content;
  const pedido = r.calls.find(c => c.url.includes('ai_memory/bot/contact'));
  ok('MontaPrompt: le a memoria do contato da conversa com o token da conta', pedido && pedido.url.endsWith('/accounts/1/ai_memory/bot/contact?conversation_id=89'));
  ok('MontaPrompt: secao CUSTOMER MEMORY com resumo e fatos, antes do idioma',
     sys.includes('# CUSTOMER MEMORY') && sys.includes('\nDuena de 3 tiendas en Colon; quiere el plan anual.\n') &&
     sys.includes('- Quiere el plan anual\n- Prefiere hablar despues de las 18h') && sys.indexOf('# CUSTOMER MEMORY') < sys.indexOf('# LANGUAGE') &&
     sys.includes('Never mention that you keep notes'));
  r = await run(R + 'monta_prompt.js', nodes, {}, { 'ai_memory/bot/contact': [200, { summary: '', facts: [] }] });
  ok('MontaPrompt: sem memoria, sem secao', !r.out[0].json.body.messages[0].content.includes('CUSTOMER MEMORY') && !r.logs.length);
  r = await run(R + 'monta_prompt.js', nodes, {}, { 'ai_memory/bot/contact': [500, {}] });
  ok('MontaPrompt: Rails fora do ar nao cala o bot', r.out[0].json.body && !r.out[0].json.body.messages[0].content.includes('CUSTOMER MEMORY') && r.logs.length === 1);
  const muitos = { summary: 'r'.repeat(1000), facts: Array.from({ length: 30 }, (_, i) => 'fato numero ' + i + ' ' + 'x'.repeat(40)) };
  r = await run(R + 'monta_prompt.js', nodes, {}, { 'ai_memory/bot/contact': [200, muitos] });
  const sysLongo = r.out[0].json.body.messages[0].content;
  ok('MontaPrompt: teto de tamanho corta os ultimos fatos', sysLongo.includes('- fato numero 0 ') && !sysLongo.includes('- fato numero 29 '));

  // --- Candidatos ----------------------------------------------------------------
  const rotas = [
    { chatwoot_account_id: 1, chatwoot_inbox_id: 33, persona_id: 7, model: 'deepseek', light_model: 'leve', is_active: true },
    { chatwoot_account_id: 1, chatwoot_inbox_id: 34, persona_id: 7, model: 'deepseek', light_model: null, is_active: true },
    { chatwoot_account_id: 2, chatwoot_inbox_id: 31, persona_id: 9, model: 'outro', is_active: true },
  ];
  const ajustes = [{ chatwoot_account_id: 1, chat_user_token: 'tok1', ai_monthly_budget_usd: null },
    { chatwoot_account_id: 2, chat_user_token: 'tok2', ai_monthly_budget_usd: 5 }];
  const reserva = { payload: [{ conversation_id: 89, inbox_id: 34, contact_id: 5, contact_name: 'Ana', summary: '', last_message_id: 900,
    facts: [], earlier: [], messages: [{ from: 'customer', text: 'tengo 3 tiendas' }] }] };
  r = await run(R + 'memoria_candidatos.js', {}, {}, { bot_route_resolved: [200, rotas], bot_account_settings: [200, ajustes],
    'rpc/bot_ai_month_spend': [200, 5.2], 'accounts/1/ai_memory/bot/claims': [200, reserva] });
  const claims = r.calls.filter(c => c.url.includes('bot/claims'));
  ok('Candidatos: reserva as caixas do bot da conta, com o token dela', claims.length === 1 &&
     JSON.stringify(claims[0].body) === JSON.stringify({ inbox_ids: [33, 34], limit: 5 }));
  ok('Candidatos: conta no teto fica de fora', !r.calls.some(c => c.url.includes('accounts/2/')));
  ok('Candidatos: item com a conversa e a rota da caixa dela', r.out.length === 1 && r.out[0].json.conversation_id === 89 &&
     r.out[0].json.rota.chatwoot_inbox_id === 34 && r.out[0].json.chatUserToken === 'tok1' && r.out[0].json.accountId === 1);

  // --- MontaMemoria --------------------------------------------------------------
  const item = Object.assign({}, r.out[0].json, {
    summary: 'Quiere el plan anual.',
    facts: [{ id: 3, text: 'Quiere el plan anual', locked: false }, { id: 4, text: 'Prefiere la tarde', locked: true }],
    earlier: [{ from: 'business', text: 'En que te ayudo?' }],
    rota: Object.assign({}, rotas[0], { provider: 'openrouter' }),
  });
  r = await run(R + 'memoria_monta.js', {}, item, {});
  const spec = r.out[0].json;
  const usuario = spec.body.messages[1].content;
  ok('MontaMemoria: modelo leve, temperatura 0, custo no usage, sem chamada HTTP', spec.body.model === 'leve' && spec.body.temperature === 0 &&
     spec.body.usage.include && spec.useOpenRouter && !r.calls.length);
  ok('MontaMemoria: fatos com id e [team] nos da equipe; contexto e novas', usuario.includes('- [3] Quiere el plan anual') &&
     usuario.includes('- [4] [team] Prefiere la tarde') && usuario.includes('Business: En que te ayudo?') &&
     usuario.includes('New messages:\nCustomer: tengo 3 tiendas') && usuario.includes('Current summary:\nQuiere el plan anual.'));
  ok('MontaMemoria: ctx sem a rota (nem chave)', !spec.ctx.rota && spec.ctx.lastMessageId === 900 && spec.ctx.contactId === 5 && spec.ctx.chatUserToken === 'tok1');
  r = await run(R + 'memoria_monta.js', {}, Object.assign({}, item, { rota: rotas[1] }), {});
  ok('MontaMemoria: sem modelo leve, o da persona', r.out[0].json.body.model === 'deepseek');

  // --- GravaMemoria --------------------------------------------------------------
  const ctx = spec.ctx;
  const resposta = json => ({ model: 'leve', usage: { prompt_tokens: 300, completion_tokens: 80, cost: 0.0004 },
    choices: [{ message: { content: typeof json === 'string' ? json : '```json\n' + JSON.stringify(json) + '\n```' } }] });
  const llm = resposta({ summary: 'Duena de 3 tiendas; quiere el plan anual.', add: ['Tiene 3 tiendas', 7], update: [{ id: 3, text: 'Quiere el plan anual (USD)' }, { id: 'x' }], remove: [9, '9'] });
  r = await run(R + 'memoria_grava.js', { MontaMemoria: { ctx } }, llm, { bot_interactions: [201, {}], 'ai_memory/bot/updates': [200, { last_message_id: 900 }] });
  const uso = r.calls.find(c => c.url.includes('bot_interactions'));
  const grava = r.calls.find(c => c.url.includes('bot/updates'));
  ok('GravaMemoria: uso registrado como memory, com custo', uso && uso.body.kind === 'memory' && uso.body.cost_usd === 0.0004 &&
     uso.body.chatwoot_account_id === 1 && uso.body.tokens_in === 300 && uso.body.persona_id === 7);
  ok('GravaMemoria: grava pelo Rails so o que tem forma certa', grava && grava.url.includes('/accounts/1/ai_memory/bot/updates') &&
     JSON.stringify(grava.body) === JSON.stringify({ contact_id: 5, conversation_id: 89, last_message_id: 900, summary: 'Duena de 3 tiendas; quiere el plan anual.',
       add: ['Tiene 3 tiendas'], update: [{ id: 3, text: 'Quiere el plan anual (USD)' }], remove: [9] }));
  r = await run(R + 'memoria_grava.js', { MontaMemoria: { ctx } }, resposta('nao sei'), { bot_interactions: [201, {}] });
  ok('GravaMemoria: resposta sem JSON nao grava (volta em 1 h)', !r.calls.some(c => c.url.includes('bot/updates')) &&
     r.out[0].json.resultado.includes('sem JSON'));
  r = await run(R + 'memoria_grava.js', { MontaMemoria: { ctx } }, resposta({ summary: '  ', add: [] }), { bot_interactions: [201, {}], 'bot/updates': [200, { last_message_id: 900 }] });
  ok('GravaMemoria: resumo vazio mantem o anterior', r.calls.find(c => c.url.includes('bot/updates')).body.summary === 'Quiere el plan anual.');
  r = await run(R + 'memoria_grava.js', { MontaMemoria: { ctx } }, { error: { message: 'timeout' } }, {});
  ok('GravaMemoria: LLM com erro nao registra uso nem grava', !r.calls.length);
})();
