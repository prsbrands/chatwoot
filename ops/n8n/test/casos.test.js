// Casos, fase 2: JevEntrada, MontaPrompt, JevRevisao e PrecisaHandoff do bot e
// os nos do workflow "CortexGen Caso", com o n8n e as APIs falsos (harness.js).
//   node ops/n8n/test/casos.test.js
const run = require('./harness');
const R = require('path').join(__dirname, '..') + '/';
const ok = (n, c) => console.log((c ? 'OK ' : 'FALHOU ') + n);
(async () => {
  const guard = { accountId: 1, conversationId: 89, messageId: 500, chatUserToken: 't', botAccessToken: 'b', content: 'Me llegó la cortina rota', contactName: 'Ana',
    splitReplies: false, contactId: 5, channel: 'Channel::Api', jev: { key: 'k', activities: { case: 'deciding' }, reviewRules: [] } };
  const persona = { persona_id: 1, composed_prompt: 'PERSONA', system_prompt: 'PERSONA', model: 'm' };
  const hist = { payload: [{ message_type: 0, content: 'Me llegó la cortina rota. ¿Qué hago?', private: false }] };
  const semMemoria = { 'ai_memory/bot/contact': [200, { summary: '', facts: [] }] };
  const tipos = [{ id: 3, name: 'Problema', ai_mode: 'continue', instructions: 'Producto con defecto' }, { id: 4, name: 'Reclamo', ai_mode: 'handoff', instructions: '' }];
  const ctx = (extra = {}) => Object.assign({ types: tipos, open_cases: [] }, extra);
  const base = { Guard: guard, Persona: persona, Historico: hist };

  // JevEntrada
  let r = await run(R + 'jev_entrada.js', Object.assign({}, base, { Persona: Object.assign({ knowledge_md: '' }, persona) }), {},
    { 'typesafe.ai': [200, { answers: { case: { noul: 0.82 } }, model: 'jev' }] });
  const jevCall = r.calls.find(c => c.url.includes('typesafe'));
  ok('JevEntrada: pergunta case e decide com 0,82', jevCall && jevCall.body.questions.case && r.out[0].json.jev.case === true);
  r = await run(R + 'jev_entrada.js', Object.assign({}, base, { Persona: Object.assign({ knowledge_md: '' }, persona) }), {},
    { 'typesafe.ai': [200, { answers: { case: { noul: 0.4 } }, model: 'jev' }] });
  ok('JevEntrada: abaixo de 0,6 nao', r.out[0].json.jev.case === false);
  const observando = Object.assign({}, guard, { jev: { key: 'k', activities: { case: 'observing' } } });
  r = await run(R + 'jev_entrada.js', Object.assign({}, base, { Guard: observando, Persona: Object.assign({ knowledge_md: '' }, persona) }), {},
    { 'typesafe.ai': [200, { answers: { case: { noul: 0.9 } }, model: 'jev' }] });
  const gravado = r.calls.find(c => c.url.includes('bot_jev_calls'));
  ok('JevEntrada: observando so grava', r.out[0].json.jev.case === false && gravado.body.decisions.case.signal === true && !gravado.body.decisions.case.acted);

  // MontaPrompt
  r = await run(R + 'monta_prompt.js', Object.assign({}, base, { JevEntrada: { jev: { case: true } } }), {},
    Object.assign({ 'cases/bot/context': [401, {}] }, semMemoria));
  ok('MontaPrompt: conta sem casos (401) segue sem secao nem erro', !r.out[0].json.body.messages[0].content.includes('# CASES') && !r.logs.length &&
     r.out[0].json.caseTypes === 0 && r.out[0].json.caseOpened === null);
  r = await run(R + 'monta_prompt.js', Object.assign({}, base, { JevEntrada: { jev: { case: true, language: 'es' } } }), {},
    Object.assign({ 'cases/bot/context': [200, ctx()], 'typesafe.ai': [200, { answers: { case_type: { choice: 'c3', confidence: 0.93 } } }],
      'cases/bot/cases': [200, { id: 7, number: 'CAS-2026-0007', title: 'Me llegó la cortina rota.', ai_mode: 'continue', reused: false }] }, semMemoria));
  const escolha = r.calls.find(c => c.url.includes('typesafe'));
  const aberto = r.calls.find(c => c.url.includes('cases/bot/cases'));
  const sys = r.out[0].json.body.messages[0].content;
  ok('MontaPrompt: Jev escolhe o tipo entre os da IA, com o criterio da conta',
     escolha && escolha.body.questions.case_type.criteria.c3 === 'Problema: Producto con defecto.' && escolha.body.questions.case_type.criteria.c4 === 'Reclamo.' &&
     escolha.body.state.recent_conversation.length === 1);
  ok('MontaPrompt: caso nasce antes do LLM com titulo da 1a frase, texto e idioma',
     aberto && aberto.body.type_id === 3 && aberto.body.title === 'Me llegó la cortina rota.' && aberto.body.description.includes('¿Qué hago?') && aberto.body.language === 'es');
  ok('MontaPrompt: prompt da o numero e segue atendendo', sys.includes('# CASES') && sys.includes('Case CAS-2026-0007 was just opened') &&
     sys.includes('Keep helping') && sys.indexOf('# CASES') < sys.indexOf('# LANGUAGE') && r.out[0].json.caseOpened === 'CAS-2026-0007' && r.out[0].json.caseHandoff === null);
  r = await run(R + 'monta_prompt.js', Object.assign({}, base, { JevEntrada: { jev: { case: true } } }), {},
    Object.assign({ 'cases/bot/context': [200, ctx()], 'typesafe.ai': [200, { answers: { case_type: { choice: 'c4', confidence: 0.9 } } }],
      'cases/bot/cases': [200, { id: 8, number: 'CAS-2026-0008', title: 'x', ai_mode: 'handoff', reused: false }] }, semMemoria));
  ok('MontaPrompt: tipo que passa a conversa marca o caseHandoff', r.out[0].json.caseHandoff === 'CAS-2026-0008' &&
     r.out[0].json.body.messages[0].content.includes('someone from the team will reply here shortly'));
  r = await run(R + 'monta_prompt.js', Object.assign({}, base, { JevEntrada: { jev: { case: true } } }), {},
    Object.assign({ 'cases/bot/context': [200, ctx()], 'typesafe.ai': [200, { answers: { case_type: { choice: 'c3', confidence: 0.7 } } }] }, semMemoria));
  ok('MontaPrompt: sem certeza do Jev, nada aberto e a regra de nao inventar numero',
     !r.calls.some(c => c.url.includes('cases/bot/cases')) && r.out[0].json.body.messages[0].content.includes('Never give a case number'));
  r = await run(R + 'monta_prompt.js', Object.assign({}, base, { JevEntrada: { jev: {} } }), {},
    Object.assign({ 'cases/bot/context': [200, ctx()] }, semMemoria));
  ok('MontaPrompt: sem o Jev ver caso, nem pergunta o tipo', !r.calls.some(c => c.url.includes('typesafe')) && !r.calls.some(c => c.url.includes('cases/bot/cases')));
  const abertos = [{ id: 2, number: 'CAS-2026-0002', title: 'Cambio de talla', type: 'Problema', status: 'in_progress', awaiting_customer_info: false }];
  r = await run(R + 'monta_prompt.js', Object.assign({}, base, { JevEntrada: { jev: {} } }), {},
    Object.assign({ 'cases/bot/context': [200, ctx({ open_cases: abertos })] }, semMemoria));
  ok('MontaPrompt: casos ativos com a situacao em palavras', r.out[0].json.body.messages[0].content.includes('- CAS-2026-0002 "Cambio de talla" (Problema): the team is working on it'));
  const esperando = [Object.assign({}, abertos[0], { status: 'waiting_customer', awaiting_customer_info: true })];
  r = await run(R + 'monta_prompt.js', Object.assign({}, base, { JevEntrada: { jev: { case: true } } }), {},
    Object.assign({ 'cases/bot/context': [200, ctx({ open_cases: esperando })], 'cases/bot/customer_replies': [200, { payload: [esperando[0]] }] }, semMemoria));
  const repassada = r.calls.find(c => c.url.includes('customer_replies'));
  ok('MontaPrompt: resposta a pergunta da equipe vai para o caso, sem abrir outro',
     repassada && repassada.body.body.includes('cortina rota') && !r.calls.some(c => c.url.includes('typesafe')) && r.out[0].json.caseReplied === true &&
     r.out[0].json.body.messages[0].content.includes('just answered the team\'s question about case CAS-2026-0002'));
  r = await run(R + 'monta_prompt.js', Object.assign({}, base, { JevEntrada: { jev: {} } }), {},
    Object.assign({ 'cases/bot/context': [500, {}] }, semMemoria));
  ok('MontaPrompt: Rails fora loga e segue', r.out[0].json.body && r.logs.some(l => l.includes('cases/bot/context')));

  // JevRevisao
  const jevResp = noul => ({ 'typesafe.ai': [200, { answers: { answers: { noul: 0.9 }, leaks: { noul: 0 }, false_case: { noul } }, model: 'jev' }] });
  r = await run(R + 'jev_revisao.js', { Guard: guard, MontaPrompt: { caseTypes: 2 }, JevEntrada: { jev: {} } }, { reply: 'Lo reviso con el equipo y te aviso.' }, jevResp(0.9));
  const rev = r.calls.find(c => c.url.includes('typesafe'));
  ok('JevRevisao: promete retorno da equipe sem caso: vai para a equipe', rev && rev.body.questions.false_case && r.out[0].json.passagem &&
     r.out[0].json.passagem.detalhe.includes('no case was opened'));
  r = await run(R + 'jev_revisao.js', { Guard: guard, MontaPrompt: { caseTypes: 2 }, JevEntrada: { jev: {} } }, { reply: 'Puedes cambiarla en 30 días.' }, jevResp(0.1));
  ok('JevRevisao: resposta propria segue', !r.out[0].json.passagem);
  r = await run(R + 'jev_revisao.js', { Guard: guard, MontaPrompt: { caseTypes: 2, caseOpened: 'CAS-1' }, JevEntrada: { jev: {} } }, { reply: 'Registré tu caso CAS-1.' }, jevResp(0.9));
  ok('JevRevisao: caso aberto neste turno, sem rede', !r.calls.some(c => c.url.includes('typesafe')) && !r.out[0].json.passagem);
  r = await run(R + 'jev_revisao.js', { Guard: guard, MontaPrompt: { caseTypes: 0 }, JevEntrada: { jev: {} } }, { reply: 'Lo reviso con el equipo.' }, jevResp(0.9));
  ok('JevRevisao: conta sem tipos com IA, sem rede', !r.calls.some(c => c.url.includes('typesafe')));

  // PrecisaHandoff
  r = await run(R + 'precisa_handoff.js', { Interpreta: { reply: 'Tu caso es CAS-8.' }, MontaPrompt: { caseHandoff: 'CAS-8' } }, {});
  ok('PrecisaHandoff: tipo que passa a conversa', r.out[0].json.passagem.motivo === 'case' && r.out[0].json.passagem.detalhe === 'CAS-8' &&
     r.out[0].json.passagem.respostaEnviada === 'Tu caso es CAS-8.');
  r = await run(R + 'precisa_handoff.js', { Interpreta: { reply: 'x', handoff: true, handoffReason: 'keyword' }, MontaPrompt: { caseHandoff: 'CAS-8' } }, {});
  ok('PrecisaHandoff: regra vem primeiro', r.out[0].json.passagem.motivo === 'keyword');
  r = await run(R + 'precisa_handoff.js', { Interpreta: { reply: 'x' }, MontaPrompt: {} }, {});
  ok('PrecisaHandoff: nada a fazer', r.out.length === 0);

  // CortexGen Caso
  const rota = { persona_id: 1, model: 'm', system_prompt: 'Soy Nathan', split_replies: true, chatwoot_account_id: 1, chatwoot_inbox_id: 33, is_active: true };
  const reserva = { event_id: 41, case_id: 7, number: 'CAS-7', title: 'Cortina rota', mode: 'ask', text: 'Mándanos una foto', conversation_id: 89, inbox_id: 33,
    contact_name: 'Ana', language: 'es', messages: [{ from: 'customer', text: 'Me llegó rota' }] };
  r = await run(R + 'caso_candidatos.js', {}, {}, {
    bot_route_resolved: [200, [rota]], bot_account_settings: [200, [{ chatwoot_account_id: 1, chat_user_token: 't', ai_monthly_budget_usd: null }]],
    bot_channel_routes: [200, [{ chatwoot_account_id: 1, chatwoot_inbox_id: 33, chatwoot_agent_bot_access_token: 'b' }]],
    'relays/claims': [200, { payload: [reserva] }] });
  const claim = r.calls.find(c => c.url.includes('relays/claims'));
  ok('Candidatos: reserva nas caixas do bot e sai com rota e token', claim.body.inbox_ids[0] === 33 && r.out.length === 1 && r.out[0].json.botToken === 'b' &&
     r.out[0].json.rota.persona_id === 1);
  r = await run(R + 'caso_candidatos.js', {}, {}, {
    bot_route_resolved: [200, [rota]], bot_account_settings: [200, [{ chatwoot_account_id: 1, chat_user_token: 't', ai_monthly_budget_usd: null }]],
    bot_channel_routes: [200, []], 'relays/claims': [401, {}] });
  ok('Candidatos: conta sem casos (401) fica de fora', r.out.length === 0);
  r = await run(R + 'caso_candidatos.js', {}, {}, {
    bot_route_resolved: [200, [rota]], bot_account_settings: [200, [{ chatwoot_account_id: 1, chat_user_token: 't', ai_monthly_budget_usd: 5 }]],
    bot_ai_month_spend: [200, 9], bot_channel_routes: [200, [{ chatwoot_account_id: 1, chatwoot_inbox_id: 33, chatwoot_agent_bot_access_token: 'b' }]],
    'relays/claims': [200, { payload: [reserva] }], '/relays/41': [200, { id: 41 }] });
  const cru = r.calls.find(c => c.url.endsWith('/conversations/89/messages'));
  const resultado = r.calls.find(c => c.url.endsWith('/relays/41'));
  ok('Candidatos: no teto de IA manda o texto da equipe sem LLM', r.out.length === 0 && cru.body.content === 'Mándanos una foto' && resultado.body.sent === true);

  r = await run(R + 'caso_monta.js', {}, [Object.assign({ accountId: 1, chatUserToken: 't', botToken: 'b', rota: rota }, reserva)]);
  const m = r.out[0].json;
  ok('MontaRepasse: idioma, pergunta, fatos e persona so de referencia', m.body.messages[0].content.includes('in Spanish') &&
     m.body.messages[0].content.includes('make clear what the customer should answer') && m.body.messages[0].content.includes('Soy Nathan') &&
     m.body.messages[1].content.endsWith('Team message for the customer:\nMándanos una foto') && m.ctx.eventId === 41 && m.ctx.splitReplies === true);

  const monta = { MontaRepasse: [m] };
  r = await run(R + 'caso_envia.js', monta, [{ choices: [{ message: { content: '¡Hola, Ana! ¿Nos mandas una **foto** de la cortina?' } }], usage: { cost: 0.001 } }],
    { '/relays/41': [200, {}] });
  const postadas = r.calls.filter(c => c.url.endsWith('/messages'));
  const fim = r.calls.find(c => c.url.endsWith('/relays/41'));
  ok('EnviaRepasse: posta como o bot, com digitando e formato do WhatsApp', postadas.length === 1 && postadas[0].body.content === '¡Hola, Ana! ¿Nos mandas una *foto* de la cortina?' &&
     r.calls.some(c => c.url.endsWith('/toggle_typing_status')) && fim.body.sent === true && fim.body.message.includes('*foto*'));
  ok('EnviaRepasse: uso registrado como resposta', r.calls.find(c => c.url.includes('bot_interactions')).body.kind === 'reply');
  r = await run(R + 'caso_envia.js', monta, [{ error: { message: 'boom' } }], { '/relays/41': [200, {}] });
  ok('EnviaRepasse: LLM falhou, vai o texto da equipe', r.calls.filter(c => c.url.endsWith('/messages'))[0].body.content === 'Mándanos una foto');
  r = await run(R + 'caso_envia.js', monta, [{ choices: [{ message: { content: 'Hola' } }] }], { '/conversations/89/messages': [500, {}], '/relays/41': [200, {}] });
  ok('EnviaRepasse: falha ao postar vira resultado de falha', r.calls.find(c => c.url.endsWith('/relays/41')).body.sent === false && r.logs.length === 1);
})();
