const https = require('https');

const g = $('Guard').first().json;
const rota = $('Persona').first().json;
// O que o Jev decidiu (JevEntrada): secoes da base que importam para esta
// mensagem, o modelo e o idioma. null/ausente = o de sempre (base inteira,
// modelo da persona, idioma do cliente); knowledge '' = a mensagem nao precisa
// da base, vai so a persona.
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
let composto = rota.composed_prompt;
if (jev.knowledge === '') composto = rota.system_prompt;
else if (jev.knowledge) composto = rota.system_prompt + '\n\n---\n\n# BASE DE CONOCIMIENTO\n\n' + jev.knowledge;
// Agenda: quando o Jev ve o cliente querendo marcar, entram os horarios livres
// do tipo que a IA oferece (Agenda::AiBooking, no Rails). A IA pergunta a
// preferencia do cliente antes de oferecer, e fecha com a etiqueta
// [[BOOK <horario>]] que o Responde tira do texto e usa para marcar.
function getJson(url, headers) {
  return new Promise((resolve, reject) => {
    const req = https.get(url, { headers }, res => {
      let body = '';
      res.on('data', chunk => { body += chunk; });
      res.on('end', () => (res.statusCode >= 200 && res.statusCode < 300
        ? resolve(JSON.parse(body))
        : reject(new Error('MontaPrompt: agenda HTTP ' + res.statusCode + ' ' + body.slice(0, 200)))));
    });
    req.setTimeout(10000, () => req.destroy(new Error('MontaPrompt: agenda timeout')));
    req.on('error', reject);
  });
}

let regraDeAgenda = '';
// A Agenda fora do ar nao pode calar o bot: ele responde e diz que a equipe
// confirma o horario.
let agenda = { available: false };
if (jev.booking) {
  try {
    agenda = await getJson('https://prs.cortexgen.cloud/api/v1/accounts/' + g.accountId + '/agenda/bot/slots',
      { api_access_token: g.chatUserToken });
  } catch (error) {
    console.error(error.message);
    regraDeAgenda = '\n\n---\n\n# BOOKING\n\nThe customer wants to book, but the calendar cannot be read right now. Do not offer or confirm any time: say that someone from the team will confirm a time shortly.';
  }
  if (agenda.available) {
    const diaDaSemana = new Intl.DateTimeFormat('en-US', { weekday: 'long', timeZone: agenda.time_zone });
    const lista = agenda.slots.map(slot => '- ' + slot + ' (' + diaDaSemana.format(new Date(slot)) + ')').join('\n');
    regraDeAgenda = '\n\n---\n\n# BOOKING\n\n' +
      'The customer wants to book a "' + agenda.event_type.name + '" (' + agenda.event_type.duration_minutes + ' minutes). ' +
      'Times are in ' + agenda.time_zone + '.\n' +
      '1. Unless the customer already said it, first ask which day and which part of the day (morning or afternoon) suit them best. Do not list times before that.\n' +
      '2. Then offer at most 3 times from the list below that best match their preference, written naturally (weekday, date and hour). Never offer or confirm a time that is not on the list.\n' +
      '3. Only after the customer clearly accepts one time, confirm it and end your reply with a last line containing exactly [[BOOK <the time exactly as written in the list>]]. The customer never sees that line. Never write it before a clear yes.\n' +
      (lista ? 'Free times:\n' + lista : 'There are no free times in the next 14 days: say so and offer that someone from the team will get in touch.');
  }
}

// O idioma vai por ultimo, depois da base. Prompt e base costumam estar num
// idioma so (na conta 1, espanhol) e o modelo seguia o bloco maior: visto em
// 02/10, cliente em ingles, a 1a resposta (so a persona) em ingles e a 2a (com
// a base) em espanhol. Com o Jev decidindo, a regra diz qual idioma.
const IDIOMAS = { es: 'Spanish', pt: 'Portuguese', en: 'English' };
const idioma = IDIOMAS[jev.language]
  ? IDIOMAS[jev.language] + ', the language the customer is writing in'
  : 'the language the customer is writing in (their latest messages)';
const regraDeIdioma = '\n\n---\n\n# LANGUAGE\n\nReply in ' + idioma +
  ', even when these instructions or the knowledge base are written in another language.';
const systemText = (String(composto || '') + regraDeAgenda + regraDeIdioma)
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