const g = $('Guard').first().json;
const rota = $('Persona').first().json;
// O que o Jev decidiu (JevEntrada): secoes da base que importam para esta
// mensagem e o modelo. null/ausente = o de sempre (base inteira, modelo da persona).
const jev = $('JevEntrada').first().json.jev || {};
if (!rota || !rota.persona_id) return [];

const payload = $('Historico').first().json.payload || [];
const chat = payload
  .filter(m => !m.private && (m.message_type === 0 || m.message_type === 1) && String(m.content || '').trim())
  .slice(-10);

const messages = [];
for (const m of chat) {
  const role = m.message_type === 0 ? 'user' : 'assistant';
  const text = String(m.content).trim();
  if (messages.length && messages[messages.length - 1].role === role) {
    messages[messages.length - 1].content += '\n' + text;
  } else {
    messages.push({ role: role, content: text });
  }
}
if (!messages.length || messages[messages.length - 1].role !== 'user') {
  messages.push({ role: 'user', content: g.content });
}
if (messages[0].role !== 'user') messages.shift();
if (!messages.length) return [];

// Merge fields herdados do GHL -> dados reais do contato no Chatwoot.
const firstName = String(g.contactName || '').split(' ')[0] || '';
const composto = jev.knowledge
  ? rota.system_prompt + '\n\n---\n\n# BASE DE CONOCIMIENTO\n\n' + jev.knowledge
  : rota.composed_prompt;
const systemText = String(composto || '')
  .split('{{contact.first_name}}').join(firstName || '(desconocido)')
  .split('{{contact.email}}').join(g.contactEmail || '(desconocido)')
  .split('{{contact.call_summary}}').join(g.callSummary || '(vacio)');

const maxTokens = Number(rota.max_tokens) || 1200;
const temperature = Number(rota.temperature);

// Monta a especificação de uma chamada para um provider/modelo.
// extraModels: fallback nativo do OpenRouter (array models na mesma chamada).
function buildSpec(provider, apiStyle, baseUrl, apiKey, model, extraModels) {
  const style = apiStyle || 'openai';
  const base = String(baseUrl || 'https://openrouter.ai/api/v1').replace(/\/$/, '');
  const headers = { 'content-type': 'application/json' };
  let url;
  let body;
  if (style === 'anthropic') {
    // Claude 5: temperature é rejeitada (400) e o adaptive thinking consome
    // max_tokens — desligar explicitamente.
    url = base + '/messages';
    body = { model: model, system: systemText, messages: messages, max_tokens: maxTokens, thinking: { type: 'disabled' } };
    headers['x-api-key'] = apiKey || '';
    headers['anthropic-version'] = '2023-06-01';
  } else {
    url = base + '/chat/completions';
    body = {
      messages: [{ role: 'system', content: systemText }].concat(messages),
      max_tokens: maxTokens,
      temperature: temperature,
    };
    if (extraModels && extraModels.length) {
      body.models = [model].concat(extraModels);
    } else {
      body.model = model;
    }
    if (provider === 'openrouter') body.reasoning = { enabled: false };
    if (apiKey) headers.authorization = 'Bearer ' + apiKey;
  }
  return { url: url, headers: headers, body: body };
}

const provider = rota.provider || 'openrouter';
const fbProvider = rota.fallback_provider || provider;
const sameProviderFallback = rota.fallback_model && fbProvider === provider;
const nativeOpenRouterFallback = sameProviderFallback && provider === 'openrouter';

const primary = buildSpec(
  provider, rota.provider_api_style, rota.provider_base_url, rota.provider_api_key,
  jev.model || rota.model, nativeOpenRouterFallback ? [rota.fallback_model] : null
);

// Fallback em chamada separada, além do array nativo do OpenRouter (o array
// não cobre erro de validação, ex. modelo inexistente). Mesmo provider reusa a
// chave; provider diferente exige chave própria gravada — sem chave não há como
// autenticar fora do nó credenciado e o fallback separado é omitido.
let fallbackSpec = null;
if (rota.fallback_model) {
  const fbKey = sameProviderFallback ? rota.provider_api_key : rota.fallback_provider_api_key;
  const fbStyle = sameProviderFallback ? rota.provider_api_style : rota.fallback_provider_api_style;
  const fbBase = sameProviderFallback ? rota.provider_base_url : rota.fallback_provider_base_url;
  if (fbKey) {
    fallbackSpec = buildSpec(fbProvider, fbStyle, fbBase, fbKey, rota.fallback_model, null);
  }
}

const useOpenRouter = provider === 'openrouter' && !rota.provider_api_key;

return [{ json: {
  body: primary.body,
  url: primary.url,
  headers: primary.headers,
  fallbackSpec: fallbackSpec,
  useOpenRouter: useOpenRouter,
  personaId: rota.persona_id,
  provider: provider,
  handoffRules: rota.handoff_rules || {},
  turns: messages.filter(m => m.role === 'user').length,
} }];