// Evolução da IA: os nós do workflow "CortexGen Evolução" com o n8n e as APIs
// falsos (harness.js).
//   node ops/n8n/test/evolucao.test.js
const run = require('./harness');
const R = require('path').join(__dirname, '..') + '/';
const ok = (n, c) => console.log((c ? 'OK ' : 'FALHOU ') + n);
(async () => {
  const rota = { persona_id: 'p1', model: 'deepseek', light_model: 'leve', provider: 'openrouter', chatwoot_account_id: 1, chatwoot_inbox_id: 33, is_active: true };
  const reserva = {
    conversation_id: 89, inbox_id: 33, last_message_id: 900, signals: ['handoff'],
    transcript: [{ from: 'customer', text: '¿Envían a Colón? mi correo es ana@x.com' }, { from: 'system', text: '[handed to the team: Traspaso · x]' },
      { from: 'team', text: 'Sí, a Colón USD 8, llamar al +507 6517-3186' }],
    cases: [{ number: 'CAS-1', type: 'Problema', title: 'roto', description: '', team_replies: ['Cambiamos en 30 días'], resolution: null }],
    persona: { id: 'p1', name: 'Nathan', prompt: 'Eres Nathan.' },
    knowledge: [{ id: 'd1', title: 'Entregas', content: '### Entregas\nEn 5 días.' }, { id: 'd2', title: 'Grande', sections: ['Uno', 'Dos'] }],
    suggestions: { pending: [{ id: 7, kind: 'knowledge_add', title: 'Envíos a Colón' }], rejected: [{ title: 'Descuentos', reason: 'no' }] },
  };
  const sb = (extra = {}) => Object.assign({
    bot_route_resolved: [200, [rota]], bot_account_settings: [200, [{ chatwoot_account_id: 1, chat_user_token: 't', ai_monthly_budget_usd: null }]],
    'bot/claims': [200, { payload: [reserva] }] }, extra);

  // Candidatos
  let r = await run(R + 'evolucao_candidatos.js', {}, {}, sb());
  const claim = r.calls.find(c => c.url.includes('bot/claims'));
  ok('Candidatos: manda caixa -> persona e o teto de 20', JSON.stringify(claim.body) === JSON.stringify({ routes: [{ inbox_id: 33, persona_id: 'p1' }], limit: 20 }) &&
     r.out.length === 1 && r.out[0].json.rota.model === 'deepseek');
  r = await run(R + 'evolucao_candidatos.js', {}, {}, sb({ 'bot/claims': [401, {}] }));
  ok('Candidatos: conta sem a flag fica de fora', r.out.length === 0);
  r = await run(R + 'evolucao_candidatos.js', {}, {}, sb({ bot_account_settings: [200, [{ chatwoot_account_id: 1, chat_user_token: 't', ai_monthly_budget_usd: 5 }]],
    bot_ai_month_spend: [200, 6] }));
  ok('Candidatos: conta no teto nem reserva', r.out.length === 0 && !r.calls.some(c => c.url.includes('bot/claims')));

  // MontaEvolucao
  r = await run(R + 'evolucao_monta.js', {}, [Object.assign({ accountId: 1, chatUserToken: 't', rota: rota }, reserva)]);
  const m = r.out[0].json;
  const u = m.body.messages[1].content;
  ok('Monta: modelo normal da persona, nao o leve', m.body.model === 'deepseek' && m.body.usage.include === true);
  ok('Monta: conversa com quem disse o que, sem e-mail nem telefone', u.includes('Customer: ¿Envían a Colón? mi correo es [email]') &&
     u.includes('Team: Sí, a Colón USD 8, llamar al [phone]') && !u.includes('ana@x.com'));
  ok('Monta: base com ids, documento grande so com secoes', u.includes('### Document d1: Entregas\n### Entregas\nEn 5 días.') && u.includes('Sections: Uno; Dos'));
  ok('Monta: caso com a resposta da equipe', u.includes('Team replies through the assistant: Cambiamos en 30 días'));
  ok('Monta: pendentes com id e recusadas com motivo', u.includes('[7] knowledge_add: Envíos a Colón') && u.includes('Descuentos (no)'));
  ok('Monta: regras de nao inventar e JSON', m.body.messages[0].content.includes('Never invent prices') && m.body.messages[0].content.includes('{"suggestions": [...]}'));
  ok('Monta: ctx sem a rota', m.ctx.personaId === 'p1' && m.ctx.personaName === 'Nathan' && m.ctx.lastMessageId === 900 && !m.ctx.rota);

  // GravaEvolucao
  const monta = { MontaEvolucao: [m] };
  const resposta = { choices: [{ message: { content: '```json\n{"suggestions":[{"kind":"knowledge_add","title":"Envíos a Colón","content":"USD 8","target_doc_id":"d1"},' +
    '{"same_as":7,"customer_quote":"a","team_quote":"b"},{"kind":"invent","title":"x","content":"y"},{"kind":"prompt_rule","title":"","content":"z"}]}\n```' } }],
    usage: { cost: 0.002, prompt_tokens: 900, completion_tokens: 80 }, model: 'deepseek' };
  r = await run(R + 'evolucao_grava.js', monta, [resposta], { 'bot/results': [200, { saved: [1, 7] }] });
  const gravou = r.calls.find(c => c.url.includes('bot/results'));
  ok('Grava: so as validas (nova e same_as), com persona e ultima mensagem', gravou.body.suggestions.length === 2 && gravou.body.persona_id === 'p1' &&
     gravou.body.last_message_id === 900 && gravou.body.suggestions[1].same_as === 7);
  ok('Grava: uso como evolution, com custo', r.calls.find(c => c.url.includes('bot_interactions')).body.kind === 'evolution' &&
     r.calls.find(c => c.url.includes('bot_interactions')).body.cost_usd === 0.002);
  r = await run(R + 'evolucao_grava.js', monta, [{ choices: [{ message: { content: 'no se' } }] }], {});
  ok('Grava: resposta ilegivel nao grava', !r.calls.some(c => c.url.includes('bot/results')) && r.out[0].json.resultado.includes('sem JSON legivel'));
  r = await run(R + 'evolucao_grava.js', monta, [{ choices: [{ message: { content: '{"suggestions":[]}' } }] }], { 'bot/results': [200, { saved: [] }] });
  ok('Grava: lista vazia ainda marca a conversa como lida', r.calls.find(c => c.url.includes('bot/results')).body.suggestions.length === 0);
})();
