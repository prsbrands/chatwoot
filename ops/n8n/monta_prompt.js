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
// Agenda: quando o Jev ve o cliente querendo marcar, desmarcar ou mudar de
// horario, entram os horarios livres do tipo que a IA oferece e os proximos
// compromissos do contato (Agenda::AiBooking, no Rails). O que o Jev
// identifica com certeza e feito aqui, antes do LLM (escolherNaAgenda); o
// resto a IA conduz, e fecha com a etiqueta [[BOOK <horario>]] que o Responde
// tira do texto e usa para marcar.
function getJson(url, headers) {
  return new Promise((resolve, reject) => {
    const req = https.get(url, { headers }, res => {
      let body = '';
      res.on('data', chunk => { body += chunk; });
      res.on('end', () => (res.statusCode >= 200 && res.statusCode < 300
        ? resolve(JSON.parse(body))
        : reject(new Error('MontaPrompt: ' + url + ' HTTP ' + res.statusCode + ' ' + body.slice(0, 200)))));
    });
    req.setTimeout(10000, () => req.destroy(new Error('MontaPrompt: ' + url + ' timeout')));
    req.on('error', reject);
  });
}

function postJson(url, headers, body, timeoutMs) {
  return new Promise(resolve => {
    const data = JSON.stringify(body);
    const req = https.request(url, {
      method: 'POST',
      headers: Object.assign({ 'content-type': 'application/json', 'content-length': Buffer.byteLength(data) }, headers),
    }, res => {
      let raw = '';
      res.on('data', chunk => { raw += chunk; });
      res.on('end', () => resolve({ statusCode: res.statusCode, body: raw }));
    });
    req.setTimeout(timeoutMs, () => req.destroy(new Error('timeout')));
    req.on('error', error => resolve({ statusCode: 0, body: error.message }));
    req.end(data);
  });
}

const quando = timeZone => new Intl.DateTimeFormat('en-US', {
  weekday: 'long', month: 'long', day: 'numeric', hour: 'numeric', minute: '2-digit', timeZone: timeZone,
});

// Antes do LLM, o Jev escolhe: o horario livre que o cliente pediu ou aceitou,
// o compromisso que ele quer desmarcar e o que ele quer mudar de horario. Visto
// em 03/10: com a lista no prompt e o horario livre, o LLM confirmou sem a
// etiqueta [[BOOK]] (o historico so mostra confirmacoes sem ela, porque o
// Responde tira a etiqueta do texto); e, sem saber desmarcar, pediu ano e
// e-mail ao cliente. So o que vem com confianca alta vira acao; a etiqueta
// continua valendo para marcar quando o Jev nao tem certeza.
const ESCOLHA_CONFIDENCE = 0.8;
const NENHUM_COMPROMISSO = 'The customer does not ask this about any of these appointments.';
async function escolherNaAgenda(agenda) {
  const scrub = text => String(text || '')
    .replace(/[\w.+-]+@[\w-]+(\.[\w-]+)+/g, '[email]')
    .replace(/\+?\d[\d\s().-]{7,}\d/g, '[phone]');
  const anterior = messages.length > 1 ? messages[messages.length - 2] : null;
  const questions = {};
  if (agenda.slots.length) {
    const criteria = {
      none: 'The customer does not name or accept one specific time from this list: they ask what is available or whether a time is free, give only a day or a part of the day, ask something else, or want a time that is not listed.',
    };
    agenda.slots.forEach((slot, k) => { criteria['t' + k] = quando(agenda.time_zone).format(new Date(slot)) + '.'; });
    questions.time = {
      type: 'choice',
      instructions: 'Which new time does the customer ask to book, or accept from `previous_assistant_message`, in `customer_last_message`? Use `today` to resolve words like "tomorrow" or "Tuesday".',
      criteria: criteria,
    };
  }
  if (agenda.upcoming.length) {
    const compromissos = { none: NENHUM_COMPROMISSO };
    agenda.upcoming.forEach(a => { compromissos['a' + a.id] = a.title + ', ' + quando(agenda.time_zone).format(new Date(a.starts_at)) + '.'; });
    questions.cancel = {
      type: 'choice',
      instructions: 'Which of the customer\'s upcoming appointments does `customer_last_message` ask to cancel without booking another time (call it off, will not attend)? Use `today` and `previous_assistant_message` to tell which one.',
      criteria: compromissos,
    };
    questions.move = {
      type: 'choice',
      instructions: 'Which of the customer\'s upcoming appointments does the customer want to move to another day or time, in `customer_last_message` or answering `previous_assistant_message`? Use `today` to tell which one.',
      criteria: compromissos,
    };
  }
  const res = await postJson('https://api.typesafe.ai/v1/systemone', { authorization: 'Bearer ' + g.jev.key }, {
    model: 'jev-1.13.0',
    state: {
      today: new Intl.DateTimeFormat('en-US', { weekday: 'long', year: 'numeric', month: 'long', day: 'numeric', timeZone: agenda.time_zone }).format(new Date()),
      customer_last_message: scrub(messages[messages.length - 1].content),
      previous_assistant_message: anterior && anterior.role === 'assistant' ? scrub(anterior.content) : '',
    },
    questions: questions,
  }, 2500);
  let answers = {};
  try { answers = res.statusCode === 200 ? JSON.parse(res.body).answers || {} : {}; } catch (e) { answers = {}; }
  const certa = id => (answers[id] && answers[id].choice !== 'none' && answers[id].confidence >= ESCOLHA_CONFIDENCE ? answers[id].choice : null);
  const compromisso = id => agenda.upcoming.find(a => 'a' + a.id === certa(id)) || null;
  return {
    slot: certa('time') ? agenda.slots[Number(certa('time').slice(1))] || null : null,
    cancel: compromisso('cancel'),
    move: compromisso('move'),
  };
}

const agendaUrl = 'https://prs.cortexgen.cloud/api/v1/accounts/' + g.accountId + '/agenda/bot/';
async function chamarAgenda(caminho, corpo) {
  const res = await postJson(agendaUrl + caminho, { api_access_token: g.chatUserToken },
    Object.assign({ conversation_id: g.conversationId }, corpo), 20000);
  if (res.statusCode >= 200 && res.statusCode < 300) return true;
  console.error('MontaPrompt: ' + caminho + ' ' + JSON.stringify(corpo) + ' HTTP ' + res.statusCode + ' ' + String(res.body).slice(0, 200));
  return false;
}
const motivo = String(messages[messages.length - 1].content).slice(0, 250);

let regraDeAgenda = '';
let marcado = null;
let desmarcado = null;
// A Agenda fora do ar nao pode calar o bot: ele responde e diz que a equipe
// confirma o horario.
let agenda = { available: false };
if (jev.booking) {
  try {
    agenda = await getJson(agendaUrl + 'slots?conversation_id=' + g.conversationId, { api_access_token: g.chatUserToken });
  } catch (error) {
    console.error(error.message);
    regraDeAgenda = '\n\n---\n\n# BOOKING\n\nThe customer wants to book, cancel or move an appointment, but the calendar cannot be read right now. Do not offer, confirm or cancel anything: say that someone from the team will take care of it shortly.';
  }
  const fuso = agenda.time_zone;
  const escolha = agenda.available && (agenda.slots.length || agenda.upcoming.length)
    ? await escolherNaAgenda(agenda)
    : { slot: null, cancel: null, move: null };

  // Mudar de horario: marca o novo e so entao desmarca o antigo, para o
  // cliente nunca ficar sem nenhum. Sem horario novo, o antigo fica.
  if (escolha.slot && await chamarAgenda('bookings', { starts_at: escolha.slot })) marcado = escolha.slot;
  const antigo = escolha.cancel || (marcado && escolha.move);
  if (antigo && await chamarAgenda('cancellations', { appointment_id: antigo.id, reason: motivo })) desmarcado = antigo;

  const descrever = a => '"' + a.title + '" on ' + quando(fuso).format(new Date(a.starts_at)) + ' (' + fuso + ')';
  if (marcado && desmarcado) {
    regraDeAgenda = '\n\n---\n\n# BOOKING\n\n' +
      'The customer\'s ' + descrever(desmarcado) + ' was moved: it is now booked for ' + quando(fuso).format(new Date(marcado)) +
      '. Confirm the new weekday, date and time in a short reply. Do not offer other times and do not write any [[BOOK ...]] line.';
  } else if (marcado) {
    regraDeAgenda = '\n\n---\n\n# BOOKING\n\n' +
      'The customer\'s "' + agenda.event_type.name + '" is now booked for ' + quando(fuso).format(new Date(marcado)) +
      ' (' + fuso + '). Confirm it in a short reply with the weekday, date and time. ' +
      'Do not offer other times and do not write any [[BOOK ...]] line.';
  } else if (desmarcado) {
    regraDeAgenda = '\n\n---\n\n# BOOKING\n\n' +
      'The customer\'s ' + descrever(desmarcado) + ' is now cancelled in the calendar. Confirm the cancellation in a short reply ' +
      'and ask whether they would like to book another time. Do not list times unless they ask, and do not write any [[BOOK ...]] line.';
  } else if (agenda.available) {
    const diaDaSemana = new Intl.DateTimeFormat('en-US', { weekday: 'long', timeZone: fuso });
    const lista = agenda.slots.map(slot => '- ' + slot + ' (' + diaDaSemana.format(new Date(slot)) + ')').join('\n');
    const proximos = agenda.upcoming.map(a => '- ' + descrever(a)).join('\n');
    regraDeAgenda = '\n\n---\n\n# BOOKING\n\n' +
      (proximos
        ? 'The customer\'s upcoming appointments:\n' + proximos + '\n' +
          (escolha.move
            ? 'The customer wants to move ' + descrever(escolha.move) + '. It stays booked until they choose a new time from the list below: ask which day and time suit them. '
            : 'You cannot cancel or move an appointment yourself in this reply. If the customer seems to want to cancel or move one, ask them to say which one (day and time) and whether to cancel it or move it. ') +
          'Never ask for an email, the year or any other data to do this.\n\n'
        : '') +
      'To book a "' + agenda.event_type.name + '" (' + agenda.event_type.duration_minutes + ' minutes). ' +
      'Times are in ' + fuso + '.\n' +
      '1. Unless the customer already said it, first ask which day and which part of the day (morning or afternoon) suit them best. Do not list times before that.\n' +
      '2. Then offer at most 3 times from the list below that best match their preference, written naturally (weekday, date and hour). Never offer or confirm a time that is not on the list.\n' +
      '3. When the customer picks a time that is on the list — one you offered, or one they asked for themselves ("Tuesday at 9") — that is a clear yes: confirm it and end your reply with a last line containing exactly [[BOOK <the time exactly as written in the list>]]. The customer never sees that line.\n' +
      '4. The [[BOOK ...]] line is what books the appointment. Never tell the customer an appointment is confirmed, booked or scheduled unless that same reply ends with the line. If the time they ask for is not on the list, say it is not available and offer the closest times from the list.\n' +
      (lista ? 'Free times:\n' + lista : 'There are no free times in the next 14 days: say so and offer that someone from the team will get in touch.');
  }
}

// Catalogo: quando o Jev ve o cliente perguntando por produtos, precos ou
// planos, ou querendo um orcamento ou assinar, os itens disponiveis da conta
// (Commerce::AiSales, no Rails) entram no prompt com os unicos precos que a IA
// pode dar. Orcamento formal: a IA fecha com [[QUOTE <id>x<qtd>, ...]] e o
// Responde cria o rascunho da cotizacao para a equipe revisar e enviar. Plano
// que se assina online: [[SUBSCRIBE <id>]], e o Responde manda o link. Fora do
// ar, o catalogo nao cala o bot: ele responde sem inventar preco.
let regraDeCatalogo = '';
let catalogoNoPrompt = false;
if (jev.catalog) {
  try {
    const catalogo = await getJson('https://prs.cortexgen.cloud/api/v1/accounts/' + g.accountId + '/commerce/bot/catalog',
      { api_access_token: g.chatUserToken });
    const preco = item => {
      if (item.price === null) return 'price on request';
      const valor = item.currency + ' ' + item.price;
      return item.billing_interval === 'one_time' ? valor + ' per ' + item.unit : valor + ' per ' + item.billing_interval + ' (plan)';
    };
    const linhas = catalogo.items.map(item => '- [' + item.id + '] ' + item.name + (item.category ? ' (' + item.category + ')' : '') + ': ' +
      preco(item) + (item.subscribable ? '; subscribe online' : '') + (item.description ? '\n  ' + item.description.replace(/\s+/g, ' ') : ''));
    const assinaveis = catalogo.items.some(item => item.subscribable);
    catalogoNoPrompt = linhas.length > 0;
    regraDeCatalogo = '\n\n---\n\n# CATALOG\n\n' + (linhas.length
      ? 'These are the products, services and plans this business sells, with the only prices you may quote. The [id] is for the lines described below; never show it to the customer.\n' +
        linhas.join('\n') + '\n\n' +
        '1. Quote only prices from this list, in its currency. Never invent a price, a discount or an item. An item with "price on request" has no fixed price: say the team will prepare a quote for it.\n' +
        '2. If the customer asks for a formal quote (a quote, proposal, budget or PDF in writing), prepare it now: say that you are preparing the quote and the team will send it shortly, and end your reply with a last line containing exactly [[QUOTE <id>x<quantity>, <id>x<quantity>]] with the ids above. The items are the ones the customer asked for or that you were talking about in this conversation; when they did not say how many, use 1. Ask first, without the line, only when you cannot tell which item they mean. Never say a quote is being prepared or sent unless that same reply ends with the line.\n' +
        (assinaveis
          ? '3. Items with "subscribe online" are plans the customer can subscribe to by themselves. When the customer clearly decides to subscribe to one, say that the subscription link comes in the next message and end your reply with a last line containing exactly [[SUBSCRIBE <id>]]. Never write a link yourself, and never say a link is coming unless that same reply ends with the line.\n'
          : '') +
        'The customer never sees the [[...]] line.'
      : 'The catalog is empty. Do not quote prices that are not in the knowledge base: say the team will send the details.');
  } catch (error) {
    console.error(error.message);
    regraDeCatalogo = '\n\n---\n\n# CATALOG\n\nThe catalog cannot be read right now. Do not quote prices that are not in the knowledge base and do not promise a quote or a subscription link: say someone from the team will send the details shortly.';
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
const systemText = (String(composto || '') + regraDeAgenda + regraDeCatalogo + regraDeIdioma)
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
    if (provider === 'openrouter') {
      body.reasoning = { enabled: false };
      // Custo em dolar na resposta (usage.cost), gravado pelo Log.
      body.usage = { include: true };
    }
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
  booked: marcado,
  cancelled: desmarcado ? desmarcado.id : null,
  catalog: catalogoNoPrompt,
} }];