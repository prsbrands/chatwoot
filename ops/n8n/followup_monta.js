// No MontaRetomada do workflow "CortexGen Follow-up" (depois do JevFollowup).
//
// Monta, por conversa, a chamada ao LLM da persona que escreve a retomada. O
// prompt e o da persona (mesma voz, mesma base) mais um bloco de reentrada:
// quanto tempo passou, que tentativa e esta, e que nao e para repetir a ultima
// mensagem. Resposta em JSON: { send, message }. Com o Jev decidindo "vale",
// o `send` do LLM e ignorado (followup_envia.js).
// buildSpec repete o do MontaPrompt do bot: Code nodes sao isolados.

const quando = horas => (horas >= 48 ? Math.floor(horas / 24) + ' days' : horas >= 24 ? '1 day' : horas + ' hours');

return $input.all().map(item => {
  const c = item.json;
  const rota = c.rota;
  const primeiroNome = String(c.contactName || '').split(' ')[0];
  const persona = String(rota.composed_prompt || '')
    .split('{{contact.first_name}}').join(primeiroNome || '(desconocido)')
    .split('{{contact.email}}').join(c.contactEmail || '(desconocido)')
    .split('{{contact.call_summary}}').join('(vacio)');

  const reentrada = [
    '',
    '---',
    '',
    '# FOLLOW-UP',
    '',
    'The customer stopped answering ' + quando(c.horasCalado) + ' ago. This is follow-up ' + c.tentativa + ' of at most ' + rota.max_followups + '.',
    c.jevDecidiu === 'send'
      ? 'It was already decided that a follow-up goes out: write it.'
      : 'First decide if a follow-up is worth sending. It is not when the customer closed the conversation: thanked and said goodbye, said they are not interested, got what they needed, or asked not to be contacted.',
    'Write ONE short WhatsApp message (1 to 3 sentences) in the language of the conversation, that picks up where it stopped: mention what was pending, make it easy to answer, never guilt-trip about the silence.',
    'Do not repeat or paraphrase your last message. Do not invent prices, dates or promises that are not in your instructions or in the conversation.',
    'Answer ONLY with a JSON object, no markdown: {"send": true or false, "message": "..."}.',
  ].join('\n');

  const transcricao = 'Conversation so far:\n' +
    c.conversa.map(m => (m.from === 'customer' ? 'Customer: ' : 'You: ') + m.text).join('\n');
  const system = persona + reentrada;
  const maxTokens = 400;

  const style = rota.provider_api_style || 'openai';
  const base = String(rota.provider_base_url || 'https://openrouter.ai/api/v1').replace(/\/$/, '');
  const headers = { 'content-type': 'application/json' };
  let url;
  let body;
  if (style === 'anthropic') {
    url = base + '/messages';
    headers['x-api-key'] = rota.provider_api_key || '';
    headers['anthropic-version'] = '2023-06-01';
    body = { model: rota.model, system: system, messages: [{ role: 'user', content: transcricao }], max_tokens: maxTokens, thinking: { type: 'disabled' } };
  } else {
    url = base + '/chat/completions';
    if (rota.provider_api_key) headers.authorization = 'Bearer ' + rota.provider_api_key;
    body = {
      model: rota.model,
      messages: [{ role: 'system', content: system }, { role: 'user', content: transcricao }],
      max_tokens: maxTokens,
      temperature: Number(rota.temperature),
    };
    if ((rota.provider || 'openrouter') === 'openrouter') body.reasoning = { enabled: false };
  }

  // Sem a rota inteira (prompt e chave) daqui em diante: o Envia so precisa do
  // contexto da conversa.
  const ctx = Object.assign({}, c);
  delete ctx.rota;
  delete ctx.jevKey;
  ctx.maxFollowups = Number(rota.max_followups);

  return { json: {
    url: url,
    headers: headers,
    body: body,
    useOpenRouter: (rota.provider || 'openrouter') === 'openrouter' && !rota.provider_api_key,
    ctx: ctx,
  } };
});
