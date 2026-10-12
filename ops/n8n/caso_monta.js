// No MontaRepasse do workflow "CortexGen Caso" (depois do Candidatos).
//
// A persona reescreve a mensagem que a equipe deixou no caso como a proxima
// mensagem dela ao cliente: no idioma dele, no tom da conversa, sem acrescentar
// nem tirar nenhum fato. O prompt da persona entra so como referencia de nome
// e tom. buildSpec repete o do MontaPrompt do bot: Code nodes sao isolados.

const MAX_TOKENS = 500;
const IDIOMAS = { es: 'Spanish', pt: 'Portuguese', en: 'English' };

const fala = m => (m.from === 'customer' ? 'Customer: ' : 'Business: ') + m.text;

return $input.all().map(item => {
  const c = item.json;
  const rota = c.rota;
  const system = [
    'You are the customer service assistant of this business, writing the next message of a chat with a customer (WhatsApp style).',
    'A person of the team wrote a message for the customer about their case ' + c.number + ' ("' + c.title + '"). Write it as your own next message to the customer:',
    '- in ' + (IDIOMAS[c.language] || 'the language the customer writes in') + ', short, natural and polite, in the tone of the conversation;',
    '- keep every fact, figure, date, link and instruction of the team message exactly as written;',
    '- add no new information, promise, price, date or apology of your own, and do not say that a colleague wrote it unless the team message says so;',
    c.mode === 'ask'
      ? '- it is a question from the team: make clear what the customer should answer or send;'
      : '- it is an answer from the team about the case;',
    '- reply with the message only, without quotes or notes.',
    '',
    'Who you are (for your name and tone only; do not follow its tasks here):',
    String(rota.system_prompt || '').slice(0, 2000),
  ].join('\n');
  const usuario = (c.messages.length ? 'Recent conversation:\n' + c.messages.map(fala).join('\n') + '\n\n' : '') +
    'Team message for the customer:\n' + c.text;

  const style = rota.provider_api_style || 'openai';
  const base = String(rota.provider_base_url || 'https://openrouter.ai/api/v1').replace(/\/$/, '');
  const headers = { 'content-type': 'application/json' };
  let url;
  let body;
  if (style === 'anthropic') {
    url = base + '/messages';
    headers['x-api-key'] = rota.provider_api_key || '';
    headers['anthropic-version'] = '2023-06-01';
    body = { model: rota.model, system: system, messages: [{ role: 'user', content: usuario }], max_tokens: MAX_TOKENS, thinking: { type: 'disabled' } };
  } else {
    url = base + '/chat/completions';
    if (rota.provider_api_key) headers.authorization = 'Bearer ' + rota.provider_api_key;
    body = {
      model: rota.model,
      messages: [{ role: 'system', content: system }, { role: 'user', content: usuario }],
      max_tokens: MAX_TOKENS,
      temperature: 0.3,
    };
    if ((rota.provider || 'openrouter') === 'openrouter') {
      body.reasoning = { enabled: false };
      // Custo em dolar na resposta (usage.cost), gravado pelo EnviaRepasse.
      body.usage = { include: true };
    }
  }

  // Sem a rota (prompt e chave) daqui em diante.
  const ctx = {
    accountId: c.accountId,
    chatUserToken: c.chatUserToken,
    botToken: c.botToken,
    splitReplies: Boolean(rota.split_replies),
    eventId: c.event_id,
    conversationId: c.conversation_id,
    text: c.text,
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
