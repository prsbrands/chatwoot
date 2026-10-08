// Fase 4a (catalogo na IA): MontaPrompt, Responde e JevRevisao com o n8n e
// as APIs falsos (harness.js).
const run = require('./harness');
const R = require('path').join(__dirname, '..') + '/';
const ok = (n, c) => console.log((c ? 'OK ' : 'FALHOU ') + n);
(async () => {
  const guard = { accountId: 1, conversationId: 89, chatUserToken: 't', botAccessToken: 'b', content: 'cuanto cuesta', contactName: 'Ana', splitReplies: false, contactId: 5, channel: 'Channel::Api', jev: { key: 'k', activities: { catalog: 'deciding' } } };
  const persona = { persona_id: 1, composed_prompt: 'PERSONA', system_prompt: 'PERSONA', model: 'm' };
  const semMemoria = { summary: '', facts: [] };
  const hist = { payload: [{ message_type: 0, content: 'Hola, cuanto cuesta la cortina?', private: false }] };
  const catalog = { items: [
    { id: 12, name: 'Cortina', category: 'Cortinas', description: 'Blackout\nmedida', price: '35.5', currency: 'USD', unit: 'm2', billing_interval: 'one_time', subscribable: false },
    { id: 13, name: 'Proyecto', category: null, description: '', price: null, currency: 'USD', unit: 'unit', billing_interval: 'one_time', subscribable: false },
    { id: 14, name: 'Plan Pro', category: null, description: '', price: '49.9', currency: 'USD', unit: 'unit', billing_interval: 'month', subscribable: true } ] };
  let r = await run(R + 'monta_prompt.js', { Guard: guard, Persona: persona, JevEntrada: { jev: { catalog: true, language: 'es' } }, Historico: hist }, {}, { 'commerce/bot/catalog': [200, catalog] });
  const sys = r.out[0].json.body.messages[0].content;
  ok('MontaPrompt: secao CATALOG com itens e regras', sys.includes('# CATALOG') && sys.includes('- [12] Cortina (Cortinas): USD 35.5 per m2\n  Blackout medida') &&
     sys.includes('[13] Proyecto: price on request') && sys.includes('[14] Plan Pro: USD 49.9 per month (plan); subscribe online') && sys.includes('[[SUBSCRIBE <id>]]') && sys.includes('when they did not say how many, use 1') &&
     sys.indexOf('# CATALOG') < sys.indexOf('# LANGUAGE') && r.out[0].json.catalog === true);
  r = await run(R + 'monta_prompt.js', { Guard: guard, Persona: persona, JevEntrada: { jev: { catalog: true } }, Historico: hist }, {}, { 'commerce/bot/catalog': [500, {}], 'ai_memory/bot/contact': [200, semMemoria] });
  const sys2 = r.out[0].json.body.messages[0].content;
  ok('MontaPrompt: catalogo fora do ar nao cala o bot', sys2.includes('cannot be read right now') && r.out[0].json.catalog === false && r.logs.length === 1);
  r = await run(R + 'monta_prompt.js', { Guard: guard, Persona: persona, JevEntrada: { jev: { catalog: true } }, Historico: hist }, {}, { 'commerce/bot/catalog': [401, {}], 'ai_memory/bot/contact': [200, semMemoria] });
  ok('MontaPrompt: conta sem o Comercial (401) segue sem secao nem erro', !r.out[0].json.body.messages[0].content.includes('CATALOG') && !r.logs.length);
  ok('MontaPrompt: regra de nao pedir nome e e-mail', sys.includes('Do not ask for their name, email or company'));
  r = await run(R + 'monta_prompt.js', { Guard: guard, Persona: persona, JevEntrada: { jev: {} }, Historico: hist }, {}, { 'ai_memory/bot/contact': [200, semMemoria] });
  ok('MontaPrompt: sem o Jev ver catalogo, nada muda', !r.out[0].json.body.messages[0].content.includes('CATALOG') && !r.calls.some(c => c.url.includes('commerce')));

  const hist2 = { payload: [{ message_type: 0, content: 'Hola, quiero assinar el Plan Pro', private: false }] };
  r = await run(R + 'monta_prompt.js', { Guard: guard, Persona: persona, JevEntrada: { jev: { catalog: true, language: 'es' } }, Historico: hist2 }, {},
    { 'commerce/bot/catalog': [200, catalog], 'typesafe.ai': [200, { answers: { subscribe: { choice: 'p14', confidence: 0.99 } } }],
      'commerce/bot/subscriptions': [200, { id: 7, public_url: 'https://x/s/plan' }] });
  const jevPlano = r.calls.find(c => c.url.includes('typesafe'));
  const criada = r.calls.find(c => c.url.includes('bot/subscriptions'));
  const sys3 = r.out[0].json.body.messages[0].content;
  ok('MontaPrompt: Jev escolhe o plano e a assinatura nasce antes do LLM',
     jevPlano && jevPlano.body.questions.subscribe.criteria.p14 && criada && criada.body.item_id === 14 && criada.body.language === 'es' &&
     r.out[0].json.subscriptionUrl === 'https://x/s/plan' && sys3.includes('decided to subscribe to "Plan Pro"'));
  r = await run(R + 'monta_prompt.js', { Guard: guard, Persona: persona, JevEntrada: { jev: { catalog: true } }, Historico: hist2 }, {},
    { 'commerce/bot/catalog': [200, catalog], 'typesafe.ai': [200, { answers: { subscribe: { choice: 'p14', confidence: 0.6 } } }] });
  ok('MontaPrompt: sem certeza do Jev, nada criado (fica a etiqueta)', !r.calls.some(c => c.url.includes('bot/subscriptions')) && r.out[0].json.subscriptionUrl === null);
  const hist3 = { payload: [{ message_type: 0, content: 'Ahora genere una cotizacion del product test #1 de 10 unidades', private: false }] };
  r = await run(R + 'monta_prompt.js', { Guard: guard, Persona: persona, JevEntrada: { jev: { catalog: true, language: 'es' } }, Historico: hist3 }, {},
    { 'commerce/bot/catalog': [200, catalog], 'typesafe.ai': [200, { answers: { subscribe: { choice: 'none', confidence: 0.9 }, quote: { choice: 'i12', confidence: 0.7 } } }],
      'commerce/bot/quotes': [200, { id: 9, number: 'COT-2026-0009' }] });
  const pedido = r.calls.find(c => c.url.includes('bot/quotes'));
  const sys4 = r.out[0].json.body.messages[0].content;
  ok('MontaPrompt: Jev escolhe o item e o rascunho nasce antes do LLM, com a quantidade da mensagem',
     pedido && JSON.stringify(pedido.body.lines) === JSON.stringify([{ item_id: 12, quantity: '10' }]) && r.out[0].json.quoted === true &&
     sys4.includes('The draft quote COT-2026-0009 for 10 x "Cortina"') && !r.calls.some(c => c.url.includes('bot/subscriptions')));
  const mp = { booked: null, catalog: true };
  const input = { reply: 'Perfecto, preparo la cotización y el equipo te la envía.\n[[QUOTE 12x2, 13]]\n[[SUBSCRIBE 14]]', accountId: 1, conversationId: 89 };
  r = await run(R + 'responde.js', { Guard: guard, MontaPrompt: mp, JevEntrada: { jev: { language: 'es' } } }, input,
    { '/conversations/89': [200, { meta: {} }], 'bot/quotes': [200, { id: 1 }], 'bot/subscriptions': [200, { id: 2, public_url: 'https://x/s/abc' }] });
  const msgs = r.calls.filter(c => c.url.endsWith('/messages'));
  const q = r.calls.find(c => c.url.includes('bot/quotes'));
  const s = r.calls.find(c => c.url.includes('bot/subscriptions'));
  ok('Responde: etiquetas fora do texto', msgs[0].body.content === 'Perfecto, preparo la cotización y el equipo te la envía.');
  ok('Responde: rascunho com linhas e idioma', q && JSON.stringify(q.body) === JSON.stringify({ conversation_id: 89, lines: [{ item_id: 12, quantity: '2' }, { item_id: 13, quantity: '1' }], language: 'es' }));
  ok('Responde: assinatura e link na bolha final', s && s.body.item_id === 14 && msgs[1] && msgs[1].body.content === 'Suscríbete aquí: https://x/s/abc');
  r = await run(R + 'responde.js', { Guard: guard, MontaPrompt: { catalog: true, subscriptionUrl: 'https://x/s/plan' }, JevEntrada: { jev: { language: 'es' } } },
    { reply: 'El enlace te llega en el siguiente mensaje. [[SUBSCRIBE 14]]', accountId: 1, conversationId: 89 }, { '/conversations/89': [200, { meta: {} }] });
  const m2 = r.calls.filter(c => c.url.endsWith('/messages'));
  ok('Responde: link da assinatura do MontaPrompt, sem criar outra pela etiqueta',
     m2.length === 2 && m2[1].body.content === 'Suscríbete aquí: https://x/s/plan' && !r.calls.some(c => c.url.includes('commerce/bot')));
  r = await run(R + 'responde.js', { Guard: guard, MontaPrompt: { catalog: true, subscriptionUrl: 'https://x/s/plan' }, JevEntrada: { jev: {} } },
    { reply: 'Listo.', accountId: 1, conversationId: 89 }, { '/conversations/89': [200, { meta: {} }] });
  ok('Responde: sem idioma decidido, o link vai sem rotulo em ingles',
     r.calls.filter(c => c.url.endsWith('/messages'))[1].body.content === '👉 https://x/s/plan');
  r = await run(R + 'responde.js', { Guard: guard, MontaPrompt: { catalog: true, quoted: true }, JevEntrada: { jev: {} } },
    { reply: 'Listo, cotización en camino. [[QUOTE 12x10]]', accountId: 1, conversationId: 89 }, { '/conversations/89': [200, { meta: {} }] });
  ok('Responde: rascunho ja criado no MontaPrompt nao se repete pela etiqueta', !r.calls.some(c => c.url.includes('commerce/bot')));
  r = await run(R + 'responde.js', { Guard: guard, MontaPrompt: mp, JevEntrada: { jev: {} } }, input,
    { '/conversations/89': [200, { meta: { assignee_type: 'User' } }] });
  ok('Responde: humano assumiu, nada criado', !r.calls.some(c => c.url.includes('commerce/bot')));
  r = await run(R + 'responde.js', { Guard: guard, MontaPrompt: mp, JevEntrada: { jev: {} } }, { reply: 'ok [[SUBSCRIBE 14]]', accountId: 1, conversationId: 89 },
    { '/conversations/89': [200, { meta: {} }], 'bot/subscriptions': [404, {}] });
  ok('Responde: assinatura recusada nao derruba, sem link', r.calls.filter(c => c.url.endsWith('/messages')).length === 1 && r.logs.length === 1);
  const guardRevisao = { accountId: 1, conversationId: 89, content: 'mandame la cotizacion', jev: { key: 'k', activities: { catalog: 'deciding' }, reviewRules: [] } };
  const jevResp = noul => ({ 'typesafe.ai': [200, { answers: { answers: { noul: 0.9 }, leaks: { noul: 0 }, false_sale: { noul } }, model: 'jev' }] });
  r = await run(R + 'jev_revisao.js', { Guard: guardRevisao, MontaPrompt: { catalog: true }, JevEntrada: { jev: { catalog: true } } },
    { reply: 'Te preparo la cotización ahora mismo.' }, jevResp(0.9));
  const pergunta = r.calls.find(c => c.url.includes('typesafe'));
  ok('JevRevisao: promessa sem etiqueta vai para a equipe', pergunta && pergunta.body.questions.false_sale && r.out[0].json.passagem &&
     r.out[0].json.passagem.detalhe.includes('quote or a subscription link'));
  r = await run(R + 'jev_revisao.js', { Guard: guardRevisao, MontaPrompt: { catalog: true }, JevEntrada: { jev: { catalog: true } } },
    { reply: 'Te preparo la cotización.\n[[QUOTE 12x2]]' }, jevResp(0.9));
  ok('JevRevisao: com etiqueta, nem pergunta (revisao geral desligada)', !r.calls.some(c => c.url.includes('typesafe')) && !r.out[0].json.passagem);
  r = await run(R + 'jev_revisao.js', { Guard: guardRevisao, MontaPrompt: { catalog: true }, JevEntrada: { jev: { catalog: true } } },
    { reply: 'La cortina cuesta USD 35.5 por m2.' }, jevResp(0.1));
  ok('JevRevisao: so informar preco segue', !r.out[0].json.passagem);
  const g2 = Object.assign({}, guardRevisao, { jev: { key: 'k', activities: { catalog: 'deciding', reply_review: 'deciding' }, reviewRules: [] } });
  r = await run(R + 'jev_revisao.js', { Guard: g2, MontaPrompt: { catalog: true }, JevEntrada: { jev: {} } },
    { reply: 'Listo, la cotización va en camino.\n[[QUOTE 12x2]]' }, jevResp(0.1));
  const p2 = r.calls.find(c => c.url.includes('typesafe'));
  ok('JevRevisao: com etiqueta, sem a pergunta de promessa e o texto revisado sem a etiqueta',
     p2 && !p2.body.questions.promises && !p2.body.questions.false_sale && !p2.body.state.assistant_reply.includes('[['));
  r = await run(R + 'jev_revisao.js', { Guard: g2, MontaPrompt: { catalog: true, subscriptionUrl: 'https://x/s/plan' }, JevEntrada: { jev: {} } },
    { reply: 'Listo, el enlace te llega en el siguiente mensaje.' }, jevResp(0.1));
  const p3 = r.calls.find(c => c.url.includes('typesafe'));
  ok('JevRevisao: assinatura ja criada, sem rede nem pergunta de promessa', p3 && !p3.body.questions.false_sale && !p3.body.questions.promises);
})();
