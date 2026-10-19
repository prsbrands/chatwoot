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
  'The memory has two parts and each piece of information goes in ONE of them, never both.',
  '',
  'FACTS are what stays true about the customer across conversations, one per line, at most 15 words, in the language the customer writes in: who they are, their business (type, size, location), budget, decisions they made, objections, preferences (schedule, channel, tone), what they bought, personal context they shared. Also an open commitment with a date or an owner ("customer sends the photo by Friday", "team calls on Tuesday"), removed once it is done.',
  'The SUMMARY is where things stand now, at most 5 sentences, not a transcript: what the customer is asking for at the moment, what was agreed, what is pending. Keep what the previous summary said unless it changed.',
  'A fact must not restate the summary, and the summary must not list the facts. If something is only the current request or status, it belongs in the summary only.',
  '',
  'Store what the CUSTOMER said, decided or committed to. Never store what the business or the assistant did or said: that a price, quote, phone number, link or answer was sent or given, who handled it, what the team replied. The business already knows what it did.',
  'Never store: greetings, small talk, prices or rules from the business, guesses, or anything that is only true for this moment ("is online now"). Never store card numbers, passwords or documents.',
  'Change a fact (update) when the customer corrected or changed it; remove a fact that is no longer true or that the summary now covers; add only what is new. Before adding, check the existing facts AND the summary: if it is already there in other words, do not add it. Facts marked [team] were written by people: never update or remove them.',
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
