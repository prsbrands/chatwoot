// No MontaMemoria do workflow "CortexGen Memória" (depois do Candidatos).
//
// Monta, por conversa, a chamada ao modelo leve da persona (ou ao modelo dela,
// sem leve) que atualiza a memoria do cliente: o resumo e os fatos atuais, as
// mensagens de antes para contexto e as novas. Resposta em JSON:
// { summary, add[], update[{id,text}], remove[id] }. Fato da equipe (locked)
// vai so para leitura; o Rails ignora mudanca nele de qualquer jeito.
// buildSpec repete o do MontaPrompt do bot: Code nodes sao isolados.

const MAX_TOKENS = 700;

const SYSTEM = [
  'You keep the long-term memory a business assistant has about ONE customer. It is read before every future answer, in any channel.',
  '',
  'You get the current memory (a summary and a list of facts with ids) and the newest messages of a conversation. Update the memory with what those messages teach about the customer.',
  '',
  'Facts are short, durable and specific, one per line, written in the language the customer writes in: who they are, their business (type, size, location), what they want or bought, budget, decisions, objections, preferences (schedule, channel, tone), commitments made by either side and their dates, personal context they shared.',
  'Never store: greetings, small talk, what the assistant said about itself, prices or rules from the business, guesses, or anything that is only true for this moment ("is online now"). Never store card numbers, passwords or documents.',
  'Change a fact (update) when the customer corrected or changed it; remove a fact that is no longer true; add only what is new. Do not repeat a fact that already exists in other words. Facts marked [team] were written by people: never update or remove them.',
  'The summary is at most 5 sentences, about the customer and where things stand (what they want, what was agreed, what is pending), not a transcript. Keep what the previous summary said unless it changed.',
  'If the new messages teach nothing new, return the same summary and empty lists.',
  '',
  'Answer ONLY with a JSON object, no markdown: {"summary": "...", "add": ["..."], "update": [{"id": 123, "text": "..."}], "remove": [123]}.',
].join('\n');

const fala = m => (m.from === 'customer' ? 'Customer: ' : 'Business: ') + m.text;

return $input.all().map(item => {
  const c = item.json;
  const rota = c.rota;
  const fatos = c.facts.length
    ? c.facts.map(f => '- [' + f.id + ']' + (f.locked ? ' [team]' : '') + ' ' + f.text).join('\n')
    : '(none)';
  const usuario = [
    'Customer name: ' + (c.contact_name || '(unknown)'),
    '',
    'Current summary:',
    c.summary || '(empty)',
    '',
    'Current facts:',
    fatos,
    '',
    c.earlier.length ? 'Earlier messages (already in memory, context only):\n' + c.earlier.map(fala).join('\n') + '\n' : '',
    'New messages:',
    c.messages.map(fala).join('\n'),
  ].join('\n');

  const modelo = rota.light_model || rota.model;
  const style = rota.provider_api_style || 'openai';
  const base = String(rota.provider_base_url || 'https://openrouter.ai/api/v1').replace(/\/$/, '');
  const headers = { 'content-type': 'application/json' };
  let url;
  let body;
  if (style === 'anthropic') {
    url = base + '/messages';
    headers['x-api-key'] = rota.provider_api_key || '';
    headers['anthropic-version'] = '2023-06-01';
    body = { model: modelo, system: SYSTEM, messages: [{ role: 'user', content: usuario }], max_tokens: MAX_TOKENS, thinking: { type: 'disabled' } };
  } else {
    url = base + '/chat/completions';
    if (rota.provider_api_key) headers.authorization = 'Bearer ' + rota.provider_api_key;
    body = {
      model: modelo,
      messages: [{ role: 'system', content: SYSTEM }, { role: 'user', content: usuario }],
      max_tokens: MAX_TOKENS,
      temperature: 0,
    };
    if ((rota.provider || 'openrouter') === 'openrouter') {
      body.reasoning = { enabled: false };
      // Custo em dolar na resposta (usage.cost), gravado pelo GravaMemoria.
      body.usage = { include: true };
    }
  }

  // Sem a rota (prompt e chave) daqui em diante.
  const ctx = {
    accountId: c.accountId,
    chatUserToken: c.chatUserToken,
    conversationId: c.conversation_id,
    contactId: c.contact_id,
    lastMessageId: c.last_message_id,
    summary: c.summary,
    personaId: rota.persona_id,
    provider: rota.provider || 'openrouter',
  };

  return { json: {
    url: url,
    headers: headers,
    body: body,
    useOpenRouter: (rota.provider || 'openrouter') === 'openrouter' && !rota.provider_api_key,
    ctx: ctx,
  } };
});
