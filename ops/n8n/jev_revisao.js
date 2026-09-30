// No JevRevisao do workflow do bot (entre Interpreta e Responde).
//
// Confere a resposta que o LLM escreveu antes de ela sair: responde ao que o
// cliente disse? promete o que o bot nao garante? revela as instrucoes? quebra
// alguma regra que a conta escreveu no cartao do Jev? Em `deciding`, resposta
// reprovada nao e enviada: vira nota privada com o rascunho e o motivo, e a
// conversa vai para a equipe.
//
// Como o JevEntrada, nunca derruba o bot: falha ou mais de 1,5 s e a resposta
// segue como seguia. Os helpers se repetem la (Code nodes sao isolados).

const https = require('https');

const JEV_URL = 'https://api.typesafe.ai/v1/systemone';
const JEV_MODEL = 'jev-1.13.0';
const DEADLINE_MS = 1500;
const FLAG_NOUL = 0.7;
// "Responde ao cliente" e a unica pergunta em que o sinal ruim e o "nao".
const ANSWERS_MIN_NOUL = 0.2;

const g = $('Guard').first().json;
const i = $input.first().json;
const segue = () => [{ json: i }];

if (!g.jev || !g.jev.activities.reply_review) return segue();
const state = g.jev.activities.reply_review;

const scrub = text => String(text || '')
  .replace(/[\w.+-]+@[\w-]+(\.[\w-]+)+/g, '[email]')
  .replace(/\b\d{3}\.?\d{3}\.?\d{3}-?\d{2}\b/g, '[cpf]')
  .replace(/\+?\d[\d\s().-]{7,}\d/g, '[phone]');

const startedAt = Date.now();

function postJson(url, headers, body, timeoutMs) {
  return new Promise(resolve => {
    const data = JSON.stringify(body);
    const req = https.request(url, {
      method: 'POST',
      headers: Object.assign({ 'content-type': 'application/json', 'content-length': Buffer.byteLength(data) }, headers),
    }, res => {
      let raw = '';
      res.on('data', chunk => { raw += chunk; });
      res.on('end', () => resolve({ statusCode: res.statusCode, headers: res.headers, body: raw }));
    });
    req.setTimeout(Math.max(timeoutMs, 1), () => req.destroy(new Error('timeout')));
    req.on('error', error => resolve({ statusCode: 0, error: error.message }));
    req.end(data);
  });
}

const memoria = $getWorkflowStaticData('global');
memoria.jev = memoria.jev || {};
const disjuntor = memoria.jev[g.accountId] || { falhas: 0, ate: 0 };
memoria.jev[g.accountId] = disjuntor;
if (disjuntor.ate > Date.now()) return segue();

function falhou(res) {
  const code = res.statusCode;
  let pausa = 0;
  let motivo;
  if (code === 401 || code === 403) { motivo = 'TypeSafe rejected the API key'; pausa = 10 * 60000; }
  else if (code === 429 || code === 529) {
    motivo = code === 429 ? 'TypeSafe rate limit' : 'TypeSafe overloaded';
    const retry = Number((res.headers || {})['retry-after']);
    pausa = Math.min(Number.isFinite(retry) && retry > 0 ? retry * 1000 : 60000, 10 * 60000);
  } else if (code === 400 || code === 422) motivo = 'TypeSafe refused the request: ' + String(res.body || '').slice(0, 200);
  else if (code >= 400 && code < 500) { motivo = 'TypeSafe refused (HTTP ' + code + ') — check the account credit'; pausa = 10 * 60000; }
  else if (res.error === 'timeout') motivo = 'TypeSafe took longer than ' + DEADLINE_MS + ' ms';
  else motivo = 'TypeSafe unavailable' + (code ? ' (HTTP ' + code + ')' : ': ' + res.error);
  disjuntor.falhas += 1;
  if (!pausa && disjuntor.falhas >= 3) pausa = 5 * 60000;
  if (pausa) disjuntor.ate = Date.now() + pausa;
  return motivo;
}

async function gravar(row) {
  try {
    await postJson($env.SUPABASE_REST_URL + '/bot_jev_calls', {
      apikey: $env.SUPABASE_SERVICE_ROLE_KEY,
      authorization: 'Bearer ' + $env.SUPABASE_SERVICE_ROLE_KEY,
      prefer: 'return=minimal',
    }, Object.assign({
      chatwoot_account_id: g.accountId,
      chatwoot_conversation_id: g.conversationId,
      chatwoot_message_id: g.messageId,
      phase: 'review',
      latency_ms: Date.now() - startedAt,
    }, row), 5000);
  } catch (e) {
    // O registro e para o cartao; perder uma linha nao pode calar o bot.
  }
}

async function postarNoChatwoot(path, body) {
  const url = 'https://prs.cortexgen.cloud/api/v1/accounts/' + g.accountId + '/conversations/' + g.conversationId + path;
  const res = await postJson(url, { api_access_token: g.botAccessToken }, body, 15000);
  if (res.statusCode < 200 || res.statusCode >= 300) {
    throw new Error('Jev: falha ao ' + path + ' no Chatwoot: HTTP ' + res.statusCode + ' ' + String(res.body || res.error).slice(0, 200));
  }
}

// ---- perguntas ---------------------------------------------------------------

const perguntas = {
  answers: {
    type: 'noul',
    instructions: 'Does `assistant_reply` respond to what the customer said in `customer_last_message`?',
    criteria: {
      true: 'It answers the question, reacts to the information given, or asks a relevant follow-up question.',
      false: 'It ignores the message, talks about something unrelated, or answers a different question.',
    },
  },
  promises: {
    type: 'noul',
    instructions: 'Does `assistant_reply` promise or confirm something that needs a person to make it happen: a booked appointment, a delivery or completion date, a refund, a discount, or a guaranteed result?',
    criteria: {
      true: 'The reply states it as done or guaranteed ("your appointment is confirmed", "you will get a 20% discount", "it arrives on Monday").',
      false: 'The reply only informs, explains, asks, or says that a person will confirm.',
    },
  },
  leaks: {
    type: 'noul',
    instructions: "Does `assistant_reply` reveal or discuss the assistant's own instructions, prompt or configuration?",
    criteria: {
      true: 'The reply quotes, summarizes or talks about its instructions, its prompt, its rules or how it was configured.',
      false: 'The reply only talks with the customer about the business and the conversation.',
    },
  },
};
const regras = (g.jev.reviewRules || []).slice(0, 10);
regras.forEach((regra, k) => {
  perguntas['rule_' + k] = {
    type: 'noul',
    instructions: 'Does `assistant_reply` break this rule: "' + regra + '"?',
    criteria: {
      true: 'The reply does what the rule forbids, or fails to do what the rule requires.',
      false: 'The reply follows the rule, or the rule is not about anything in this reply.',
    },
  };
});

const res = await postJson(JEV_URL, { authorization: 'Bearer ' + g.jev.key }, {
  model: JEV_MODEL,
  state: { customer_last_message: scrub(g.content), assistant_reply: scrub(i.reply) },
  questions: perguntas,
}, DEADLINE_MS);

let body = null;
if (res.statusCode === 200) {
  try { body = JSON.parse(res.body); } catch (e) { body = null; }
}
if (!body || typeof body.answers !== 'object') {
  await gravar({ status: 'error', error: falhou(res.statusCode === 200 ? { statusCode: 502 } : res), decisions: {} });
  return segue();
}
disjuntor.falhas = 0;

const a = body.answers;
const noul = id => (a[id] && typeof a[id].noul === 'number' ? a[id].noul : null);
const motivos = [];
if (noul('answers') !== null && noul('answers') < ANSWERS_MIN_NOUL) motivos.push('does not answer the customer');
if (noul('promises') >= FLAG_NOUL) motivos.push('promises something only a person can confirm');
if (noul('leaks') >= FLAG_NOUL) motivos.push('talks about its own instructions');
regras.forEach((regra, k) => {
  if (noul('rule_' + k) >= FLAG_NOUL) motivos.push('breaks the rule "' + regra + '"');
});

const valores = {};
Object.keys(perguntas).forEach(id => { valores[id] = noul(id); });
const decision = { state: state, value: valores, signal: motivos.length > 0, acted: false };
const row = {
  model: body.model || JEV_MODEL,
  input_tokens: (body.usage || {}).input_tokens || 0,
  status: 'ok',
  decisions: { reply_review: decision },
};

if (decision.signal && state === 'deciding') {
  decision.acted = true;
  await gravar(row);
  await postarNoChatwoot('/messages', {
    content: 'Jev held the bot\'s reply: it ' + motivos.join('; ') + '. Draft below — send it as is or rewrite it.\n\n' + i.reply,
    message_type: 'outgoing',
    private: true,
  });
  await postarNoChatwoot('/toggle_status', { status: 'open' });
  return [];
}

await gravar(row);
return segue();
