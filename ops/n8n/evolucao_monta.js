// No MontaEvolucao do workflow "CortexGen Evolução" (depois do Candidatos).
//
// Monta, por conversa, a chamada ao modelo da persona (o normal, nao o leve:
// aqui errar custa mais que o token) que le o que a equipe fez quando a IA nao
// deu conta e propoe mudancas na base ou no prompt. Resposta em JSON:
// { suggestions: [{ kind, title, content, target_doc_id, replace_text, same_as,
// rationale, customer_quote, team_quote }] }; lista vazia e o comum. E-mail e
// telefone saem do texto antes do LLM, como no Jev. buildSpec repete o do
// MontaPrompt do bot: Code nodes sao isolados.

const MAX_TOKENS = 1500;

const SYSTEM = [
  'You improve the customer service assistant of a business by learning from its team.',
  'You get one conversation where the assistant could not handle something (it handed the customer to the team, had a reply held back, or opened a case), what the team answered, the assistant\'s knowledge base and the start of its instructions.',
  '',
  'Propose at most 3 concrete changes, and only when the team\'s own words or actions teach something durable that the assistant should know or do next time:',
  '- "knowledge_add": a new short section for the knowledge base (title and text) with facts the team gave: prices, deadlines, policies, steps, areas served, contacts of the business. "target_doc_id": the id of the document where it fits best, or null.',
  '- "knowledge_update": the team contradicts or completes what the base says. "replace_text" must be copied EXACTLY, character by character, from the content of one document (a sentence or a paragraph); "content" is the corrected text that replaces it; "target_doc_id" is that document.',
  '- "prompt_rule": one sentence on how the assistant should behave (for example, not promising something only the team can confirm). Never a fact or a price.',
  '',
  'Rules:',
  '- Use only what the team said or did. Never invent prices, dates, policies, contacts or steps.',
  '- Skip what the knowledge base already says, and one-off details that only apply to this customer (their order, their delivery, their case).',
  '- Never copy the customer\'s personal data.',
  '- Write titles and texts in the language of the knowledge base, short and factual.',
  '- If an open suggestion already covers it, return only {"same_as": <its id>, "customer_quote": ..., "team_quote": ...}.',
  '- Never propose again what is in the rejected list.',
  '- "customer_quote": the customer\'s words that show the need; "team_quote": the team\'s words that teach it. Both short and exact.',
  '- "rationale": one sentence on why.',
  '',
  'Answer ONLY with a JSON object, no markdown: {"suggestions": [...]}. An empty list is the usual answer.',
].join('\n');

const scrub = text => String(text || '')
  .replace(/[\w.+-]+@[\w-]+(\.[\w-]+)+/g, '[email]')
  .replace(/\+?\d[\d\s().-]{7,}\d/g, '[phone]');
const QUEM = { customer: 'Customer', assistant: 'Assistant', team: 'Team', system: 'System' };

return $input.all().map(item => {
  const c = item.json;
  const rota = c.rota;
  const base = c.knowledge.map(doc => '### Document ' + doc.id + ': ' + doc.title + '\n' +
    (doc.content !== undefined ? doc.content : 'Sections: ' + (doc.sections || []).join('; '))).join('\n\n');
  const casos = c.cases.map(k => '- Case ' + k.number + ' (' + k.type + '): ' + scrub(k.title) +
    (k.team_replies.length ? '\n  Team replies through the assistant: ' + k.team_replies.map(scrub).join(' / ') : '') +
    (k.resolution ? '\n  Resolution: ' + scrub(k.resolution) : '')).join('\n');
  const usuario = [
    'Signals: ' + c.signals.join(', '),
    '',
    'Conversation:',
    c.transcript.map(l => (QUEM[l.from] || l.from) + ': ' + scrub(l.text)).join('\n'),
    casos ? '\nCases opened by the assistant:\n' + casos : '',
    '',
    'Assistant "' + c.persona.name + '" instructions (start):',
    c.persona.prompt,
    '',
    'Knowledge base:',
    base || '(empty)',
    '',
    'Open suggestions: ' + (c.suggestions.pending.length ? c.suggestions.pending.map(s => '[' + s.id + '] ' + s.kind + ': ' + s.title).join('; ') : '(none)'),
    'Rejected suggestions: ' + (c.suggestions.rejected.length ? c.suggestions.rejected.map(s => s.title + (s.reason ? ' (' + s.reason + ')' : '')).join('; ') : '(none)'),
  ].join('\n');

  const style = rota.provider_api_style || 'openai';
  const urlBase = String(rota.provider_base_url || 'https://openrouter.ai/api/v1').replace(/\/$/, '');
  const headers = { 'content-type': 'application/json' };
  let url;
  let body;
  if (style === 'anthropic') {
    url = urlBase + '/messages';
    headers['x-api-key'] = rota.provider_api_key || '';
    headers['anthropic-version'] = '2023-06-01';
    body = { model: rota.model, system: SYSTEM, messages: [{ role: 'user', content: usuario }], max_tokens: MAX_TOKENS, thinking: { type: 'disabled' } };
  } else {
    url = urlBase + '/chat/completions';
    if (rota.provider_api_key) headers.authorization = 'Bearer ' + rota.provider_api_key;
    body = {
      model: rota.model,
      messages: [{ role: 'system', content: SYSTEM }, { role: 'user', content: usuario }],
      max_tokens: MAX_TOKENS,
      temperature: 0.2,
    };
    if ((rota.provider || 'openrouter') === 'openrouter') {
      body.reasoning = { enabled: false };
      // Custo em dolar na resposta (usage.cost), gravado pelo GravaEvolucao.
      body.usage = { include: true };
    }
  }

  // Sem a rota (prompt e chave) daqui em diante.
  const ctx = {
    accountId: c.accountId,
    chatUserToken: c.chatUserToken,
    conversationId: c.conversation_id,
    lastMessageId: c.last_message_id,
    personaId: c.persona.id,
    personaName: c.persona.name,
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
