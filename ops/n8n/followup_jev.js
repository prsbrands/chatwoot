// No JevFollowup do workflow "CortexGen Follow-up" (depois do Candidatos).
//
// O Jev decide se a conversa vale ser retomada: "vou pensar" vale, "obrigado,
// era so isso" nao. Atividade `followup` do cartao do Jev:
// - deciding: o veredito vale. Nao vale = a serie vira `declined` e nao volta
//   sem o cliente escrever de novo; vale = o LLM so escreve;
// - observing, sem Jev ou Jev falhando: o LLM decide no mesmo passo em que
//   escreve (followup_monta.js).
// Nunca derruba a varredura: falha do Jev cai no LLM, como no bot.

const https = require('https');

const JEV_URL = 'https://api.typesafe.ai/v1/systemone';
const JEV_MODEL = 'jev-1.13.0';
const DEADLINE_MS = 3000;
const VALE_NOUL = 0.5;

function postJson(url, headers, body, timeoutMs, method) {
  return new Promise(resolve => {
    const data = JSON.stringify(body);
    const req = https.request(url, {
      method: method || 'POST',
      headers: Object.assign({ 'content-type': 'application/json', 'content-length': Buffer.byteLength(data) }, headers),
    }, res => {
      let raw = '';
      res.on('data', chunk => { raw += chunk; });
      res.on('end', () => resolve({ statusCode: res.statusCode, body: raw }));
    });
    req.setTimeout(timeoutMs, () => req.destroy(new Error('timeout')));
    req.on('error', error => resolve({ statusCode: 0, error: error.message }));
    req.end(data);
  });
}

const sbHeaders = {
  apikey: $env.SUPABASE_SERVICE_ROLE_KEY,
  authorization: 'Bearer ' + $env.SUPABASE_SERVICE_ROLE_KEY,
  prefer: 'return=minimal',
};

// Sai da maquina sem e-mail, CPF e telefone, como no bot.
const scrub = text => String(text || '')
  .replace(/[\w.+-]+@[\w-]+(\.[\w-]+)+/g, '[email]')
  .replace(/\b\d{3}\.?\d{3}\.?\d{3}-?\d{2}\b/g, '[cpf]')
  .replace(/\+?\d[\d\s().-]{7,}\d/g, '[phone]');

const PERGUNTA = {
  worth_resuming: {
    type: 'noul',
    instructions: 'The customer stopped answering `recent_conversation` `hours_silent` hours ago. Is it worth sending one message to resume the conversation?',
    criteria: {
      true: 'Something was left open: the customer said they would think, check, talk to someone or come back; asked for information or a quote; was deciding; or stopped answering a question the assistant asked.',
      false: 'The customer closed the conversation: thanked and said goodbye, said they are not interested, got what they needed, or asked not to be contacted.',
    },
  },
};

const saida = [];
for (const item of $input.all()) {
  const c = item.json;
  const estado = ((c.jev || {}).activities || {}).followup || 'observing';
  const ligado = c.jevKey && c.jev.enabled === true && c.jev.consent && (estado === 'observing' || estado === 'deciding');
  if (!ligado) {
    saida.push({ json: Object.assign({}, c, { jevDecidiu: null }) });
    continue;
  }

  const inicio = Date.now();
  const res = await postJson(JEV_URL, { authorization: 'Bearer ' + c.jevKey }, {
    model: JEV_MODEL,
    state: {
      hours_silent: c.horasCalado,
      recent_conversation: c.conversa.slice(-8).map(m => ({ from: m.from, text: scrub(m.text) })),
    },
    questions: PERGUNTA,
  }, DEADLINE_MS);
  let corpo = null;
  if (res.statusCode === 200) {
    try { corpo = JSON.parse(res.body); } catch (e) { corpo = null; }
  }
  const noul = corpo && corpo.answers && corpo.answers.worth_resuming && typeof corpo.answers.worth_resuming.noul === 'number'
    ? corpo.answers.worth_resuming.noul : null;
  const vale = noul === null ? null : noul >= VALE_NOUL;
  const decide = estado === 'deciding' && vale !== null;

  await postJson($env.SUPABASE_REST_URL + '/bot_jev_calls', sbHeaders, {
    chatwoot_account_id: c.accountId,
    chatwoot_conversation_id: c.conversationId,
    phase: 'followup',
    model: (corpo && corpo.model) || JEV_MODEL,
    latency_ms: Date.now() - inicio,
    input_tokens: (corpo && corpo.usage && corpo.usage.input_tokens) || 0,
    status: noul === null ? 'error' : 'ok',
    error: noul === null ? ('TypeSafe ' + (res.statusCode ? 'HTTP ' + res.statusCode : res.error)) : null,
    // signal = o Jev pularia este follow-up (o cartao conta "would skip").
    decisions: noul === null ? {} : { followup: { state: estado, value: noul, signal: !vale, acted: decide && !vale } },
  }, 5000);

  if (decide && !vale) {
    // Serie recusada nao volta sem o cliente escrever de novo (ancora nova).
    const r = c.serie
      ? await postJson($env.SUPABASE_REST_URL + '/bot_followups?id=eq.' + c.serie.id, sbHeaders,
        { status: 'declined', decided_by: 'jev', updated_at: new Date().toISOString() }, 5000, 'PATCH')
      : await postJson($env.SUPABASE_REST_URL + '/bot_followups', sbHeaders, {
        chatwoot_account_id: c.accountId, chatwoot_inbox_id: c.inboxId, chatwoot_conversation_id: c.conversationId,
        chatwoot_contact_id: c.contactId, anchor_message_id: c.anchorMessageId, status: 'declined', decided_by: 'jev',
      }, 5000);
    if (r.statusCode < 200 || r.statusCode >= 300) {
      throw new Error('bot_followups (declined): HTTP ' + r.statusCode + ' ' + String(r.body || r.error).slice(0, 200));
    }
    continue;
  }

  saida.push({ json: Object.assign({}, c, { jevDecidiu: decide ? 'send' : null }) });
}

return saida;
