// Evolução da IA: os nós do workflow "CortexGen Evolução" com o n8n e as APIs
// falsos (harness.js).
//   node ops/n8n/test/evolucao.test.js
const run = require('./harness');
const R = require('path').join(__dirname, '..') + '/';
const ok = (n, c) => console.log((c ? 'OK ' : 'FALHOU ') + n);
(async () => {
  const rota = { persona_id: 'p1', model: 'deepseek', light_model: 'leve', provider: 'openrouter', chatwoot_account_id: 1, chatwoot_inbox_id: 33, is_active: true };
  const contexto = {
    persona: { id: 'p1', name: 'Nathan', prompt: 'Eres Nathan.' },
    knowledge: [{ id: 'd1', title: 'Entregas', content: '### Entregas\nEn 5 días.' }, { id: 'd2', title: 'Grande', sections: ['Uno', 'Dos'] }],
    suggestions: { pending: [{ id: 7, kind: 'knowledge_add', title: 'Envíos a Colón' }], rejected: [{ title: 'Descuentos', reason: 'no' }] },
  };
  const conversa = (id, extra = {}) => Object.assign({
    conversation_id: id, inbox_id: 33, last_message_id: id * 10, signals: ['handoff'],
    transcript: [{ from: 'customer', text: '¿Envían a Colón? mi correo es ana@x.com' }, { from: 'system', text: '[handed to the team: Traspaso · x]' },
      { from: 'team', text: 'Sí, a Colón USD 8, llamar al +507 6517-3186' }],
    cases: [],
  }, contexto, extra);
  const sb = (payload, extra = {}) => Object.assign({
    bot_route_resolved: [200, [rota]], bot_account_settings: [200, [{ chatwoot_account_id: 1, chat_user_token: 't', ai_monthly_budget_usd: null }]],
    'bot/claims': [200, { payload }] }, extra);

  // Candidatos
  let r = await run(R + 'evolucao_candidatos.js', {}, {}, sb([conversa(89), conversa(90)]));
  const claim = r.calls.find(c => c.url.includes('bot/claims'));
  ok('Candidatos: manda caixa -> persona e o teto de 20', JSON.stringify(claim.body) === JSON.stringify({ routes: [{ inbox_id: 33, persona_id: 'p1' }], limit: 20 }));
  ok('Candidatos: as conversas da mesma persona num item so', r.out.length === 1 && r.out[0].json.conversations.map(c => c.conversation_id).join() === '89,90' &&
     r.out[0].json.rota.model === 'deepseek' && r.out[0].json.persona.name === 'Nathan' && !r.out[0].json.conversations[0].persona);
  r = await run(R + 'evolucao_candidatos.js', {}, {}, sb(Array.from({ length: 22 }, (_, k) => conversa(100 + k))));
  ok('Candidatos: no maximo 20 conversas por rodada', r.out.map(i => i.json.conversations.length).join() === '20,2');
  r = await run(R + 'evolucao_candidatos.js', {}, {}, sb([], { 'bot/claims': [401, {}] }));
  ok('Candidatos: conta sem a flag fica de fora', r.out.length === 0);
  r = await run(R + 'evolucao_candidatos.js', {}, {}, sb([], { bot_account_settings: [200, [{ chatwoot_account_id: 1, chat_user_token: 't', ai_monthly_budget_usd: 5 }]],
    bot_ai_month_spend: [200, 6] }));
  ok('Candidatos: conta no teto nem reserva', r.out.length === 0 && !r.calls.some(c => c.url.includes('bot/claims')));

  // MontaEvolucao
  const rodada = Object.assign({ accountId: 1, chatUserToken: 't', rota: rota }, contexto, {
    conversations: [conversa(89), conversa(90, { cases: [{ number: 'CAS-1', type: 'Problema', title: 'roto', team_replies: ['Cambiamos en 30 días'], resolution: null }] })],
  });
  r = await run(R + 'evolucao_monta.js', {}, [rodada]);
  const m = r.out[0].json;
  const u = m.body.messages[1].content;
  ok('Monta: modelo normal da persona e JSON pedido ao provedor', m.body.model === 'deepseek' && m.body.response_format.type === 'json_object' && m.body.usage.include === true);
  ok('Monta: as conversas juntas, cada uma com o numero', u.includes('## Conversation 89 (handoff)') && u.includes('## Conversation 90 (handoff)'));
  ok('Monta: sem e-mail nem telefone', u.includes('mi correo es [email]') && u.includes('llamar al [phone]') && !u.includes('ana@x.com'));
  ok('Monta: base com ids, documento grande so com secoes', u.includes('### Document d1: Entregas\n### Entregas\nEn 5 días.') && u.includes('Sections: Uno; Dos'));
  ok('Monta: caso com a resposta da equipe', u.includes('Team replies through the assistant: Cambiamos en 30 días'));
  ok('Monta: pendentes com id e recusadas com motivo', u.includes('[7] knowledge_add: Envíos a Colón') && u.includes('Descuentos (no)'));
  ok('Monta: formato exato com kind e evidence, e juntar o que se repete', m.body.messages[0].content.includes('"kind":"knowledge_add"') &&
     m.body.messages[0].content.includes('"evidence":[{"conversation_id":123') && m.body.messages[0].content.includes('write ONE proposal'));
  ok('Monta: ctx com as conversas e sem a rota', JSON.stringify(m.ctx.conversations) === JSON.stringify([{ conversation_id: 89, last_message_id: 890 }, { conversation_id: 90, last_message_id: 900 }]) &&
     m.ctx.personaName === 'Nathan' && !m.ctx.rota);

  // GravaEvolucao
  const monta = { MontaEvolucao: [m] };
  const conteudo = JSON.stringify({ suggestions: [
    { kind: 'knowledge_add', title: 'Envíos a Colón', content: 'USD 8', target_doc_id: 'd1',
      evidence: [{ conversation_id: 89, customer_quote: 'a', team_quote: 'b' }, { conversation_id: 90, customer_quote: 'c', team_quote: 'd' }] },
    // O formato que o DeepSeek devolveu em 12/10:
    { knowledge_update: { target_doc_id: 'd1', title: 'Entregas', replace_text: 'En 5 días.', content: 'En 3 días.', conversation_id: 90, customer_quote: 'x', team_quote: 'y' } },
    { same_as: 7, evidence: [{ conversation_id: 89 }] },
    { kind: 'invent', title: 'x', content: 'y', evidence: [{ conversation_id: 89 }] },
    { kind: 'prompt_rule', title: 'Sem evidencia', content: 'z' },
  ] });
  const resposta = { choices: [{ message: { content: '```json\n' + conteudo + '\n```' } }], usage: { cost: 0.002, prompt_tokens: 900, completion_tokens: 80 }, model: 'deepseek' };
  r = await run(R + 'evolucao_grava.js', monta, [resposta], { 'bot/results': [200, { saved: [1, 2, 7] }] });
  const gravou = r.calls.find(c => c.url.includes('bot/results'));
  const s = gravou.body.suggestions;
  ok('Grava: a rodada inteira, com persona e as conversas', gravou.body.persona_id === 'p1' && gravou.body.conversations.length === 2);
  ok('Grava: aceita o formato do DeepSeek e a citacao solta', s.length === 3 && s[1].kind === 'knowledge_update' && s[1].replace_text === 'En 5 días.' &&
     s[1].evidence[0].conversation_id === 90);
  ok('Grava: descarta tipo inventado e proposta sem evidencia', !s.some(x => x.kind === 'invent' || x.title === 'Sem evidencia'));
  ok('Grava: uso como evolution, com custo', r.calls.find(c => c.url.includes('bot_interactions')).body.kind === 'evolution' &&
     r.calls.find(c => c.url.includes('bot_interactions')).body.cost_usd === 0.002);
  ok('Grava: relatorio da rodada', r.out[0].json.resultado === '3 proposta(s) gravada(s) de 2 conversa(s)');
  r = await run(R + 'evolucao_grava.js', monta, [{ choices: [{ message: { content: 'no se' } }] }], {});
  ok('Grava: resposta ilegivel nao grava', !r.calls.some(c => c.url.includes('bot/results')) && r.out[0].json.resultado.includes('sem JSON legivel'));
  r = await run(R + 'evolucao_grava.js', monta, [{ choices: [{ message: { content: '{"suggestions":[]}' } }] }], { 'bot/results': [200, { saved: [] }] });
  ok('Grava: lista vazia ainda marca as conversas como lidas', r.calls.find(c => c.url.includes('bot/results')).body.suggestions.length === 0);
})();
