// No Envia do workflow "CortexGen Follow-up" (depois do LLMRetomada /
// LLMRetomadaCustom). Roda uma vez para todos os itens.
//
// Por conversa: le o que o LLM escreveu, veta texto quase igual aos ultimos
// 20 follow-ups do numero, confere que o cliente nao respondeu nem um humano
// assumiu enquanto isso, reserva a serie (um follow-up vivo por contato) e
// envia em bolhas com "digitando", com 20-45 s entre envios do mesmo numero.
//
// Anti-ban do WhatsApp por QR: o veto e o do DeskComm (spinning/engine.ts):
// Jaccard de palavras >= 0,8 ou texto igual, contra os ultimos 20 envios do
// numero, e so veta na 3a repeticao (2 parecidos na janela). Texto de ate 15
// caracteres e isento. Vetado 3 vezes na mesma serie, ela para.

const https = require('https');

const CHATWOOT = 'https://prs.cortexgen.cloud/api/v1/accounts/';
const JACCARD = 0.8;
const REPETICOES = 2;
const MAX_VETOS = 3;
const JITTER_S = [20, 45];
const MAX_BOLHAS = 4;

function pedir(method, url, headers, body) {
  return new Promise((resolve, reject) => {
    const data = body === undefined ? '' : JSON.stringify(body);
    const req = https.request(url, {
      method: method,
      headers: Object.assign({ 'content-type': 'application/json', 'content-length': Buffer.byteLength(data) }, headers),
    }, res => {
      let raw = '';
      res.on('data', chunk => { raw += chunk; });
      res.on('end', () => resolve({ statusCode: res.statusCode, body: raw }));
    });
    req.setTimeout(20000, () => req.destroy(new Error(method + ' ' + url.split('?')[0] + ': timeout')));
    req.on('error', reject);
    req.end(data);
  });
}

async function exigir(method, url, headers, body) {
  const r = await pedir(method, url, headers, body);
  if (r.statusCode < 200 || r.statusCode >= 300) {
    throw new Error(method + ' ' + url.split('?')[0] + ': HTTP ' + r.statusCode + ' ' + String(r.body).slice(0, 200));
  }
  return r.body ? JSON.parse(r.body) : null;
}

const SB = $env.SUPABASE_REST_URL + '/';
const sbHeaders = { apikey: $env.SUPABASE_SERVICE_ROLE_KEY, authorization: 'Bearer ' + $env.SUPABASE_SERVICE_ROLE_KEY };
const sb = (method, path, body, prefer) => exigir(method, SB + path, Object.assign({ prefer: prefer || 'return=minimal' }, sbHeaders), body);
const espera = ms => new Promise(resolve => setTimeout(resolve, ms));

// ---- texto ------------------------------------------------------------------------

function lerResposta(res) {
  if (res.error || res.type === 'error') return null;
  const texto = Array.isArray(res.content)
    ? res.content.filter(p => p.type === 'text').map(p => p.text).join('\n')
    : String((((res.choices || [])[0] || {}).message || {}).content || '');
  try {
    return JSON.parse(texto.slice(texto.indexOf('{'), texto.lastIndexOf('}') + 1));
  } catch (e) {
    return null;
  }
}

const normalizar = t => String(t || '').toLowerCase().replace(/\s+/g, ' ').trim();
function jaccard(a, b) {
  const x = new Set(a.split(' '));
  const y = new Set(b.split(' '));
  let comum = 0;
  x.forEach(p => { if (y.has(p)) comum += 1; });
  return comum / (x.size + y.size - comum);
}

// Mesma quebra do Responde do bot.
function bolhas(texto) {
  const partes = [];
  let atual = [];
  let emCodigo = false;
  for (const linha of texto.split('\n')) {
    if (/^\s*```/.test(linha)) emCodigo = !emCodigo;
    if (!emCodigo && !linha.trim()) {
      if (atual.length) partes.push(atual.join('\n'));
      atual = [];
    } else {
      atual.push(linha);
    }
  }
  if (atual.length) partes.push(atual.join('\n'));
  const item = linha => /^\s*([-*•]|\d+[.)])\s/.test(linha);
  const juntas = [];
  for (const parte of partes) {
    const anterior = juntas[juntas.length - 1];
    const cola = anterior !== undefined &&
      (/:\s*$/.test(anterior) || (item(parte) && item(anterior.split('\n').pop())));
    if (cola) juntas[juntas.length - 1] = anterior + '\n\n' + parte;
    else juntas.push(parte);
  }
  if (juntas.length > MAX_BOLHAS) juntas.push(juntas.splice(MAX_BOLHAS - 1).join('\n\n'));
  return juntas;
}

// ---- a serie ----------------------------------------------------------------------

// Cria a linha da serie na primeira vez. 409 = o contato ja tem outra serie
// viva (bot_followups_one_live): esta conversa espera.
async function serieDe(ctx, campos) {
  if (ctx.serie) return ctx.serie;
  const r = await pedir('POST', SB + 'bot_followups', Object.assign({ prefer: 'return=representation' }, sbHeaders), Object.assign({
    chatwoot_account_id: ctx.accountId, chatwoot_inbox_id: ctx.inboxId, chatwoot_conversation_id: ctx.conversationId,
    chatwoot_contact_id: ctx.contactId, anchor_message_id: ctx.anchorMessageId,
  }, campos));
  if (r.statusCode === 409) return null;
  if (r.statusCode < 200 || r.statusCode >= 300) throw new Error('POST bot_followups: HTTP ' + r.statusCode + ' ' + String(r.body).slice(0, 200));
  ctx.serie = JSON.parse(r.body)[0];
  return ctx.serie;
}

const atualizar = (id, campos) => sb('PATCH', 'bot_followups?id=eq.' + id, Object.assign({ updated_at: new Date().toISOString() }, campos));

// ---- a rodada ---------------------------------------------------------------------

const entradas = $input.all().map((item, k) => ({ res: item.json, ctx: $('MontaRetomada').itemMatching(k).json.ctx }));
// Intercala os numeros: o jitter e por numero, e assim a espera de um cobre o outro.
const porInbox = {};
entradas.forEach(e => { (porInbox[e.ctx.inboxId] = porInbox[e.ctx.inboxId] || []).push(e); });
const fila = [];
for (let i = 0; Object.values(porInbox).some(l => l.length > i); i += 1) {
  Object.values(porInbox).forEach(l => { if (l[i]) fila.push(l[i]); });
}

const recentes = {};
const ultimoEnvio = {};
const relatorio = [];

for (const { res, ctx } of fila) {
  const nota = r => relatorio.push({ conversa: ctx.accountId + '/' + ctx.conversationId, resultado: r });
  const lido = lerResposta(res);
  if (!lido) { nota('LLM sem resposta legivel; tenta na proxima varredura'); continue; }

  const decididoPor = ctx.jevDecidiu === 'send' ? 'jev' : 'llm';
  const mensagem = String(lido.message || '').trim();
  if ((decididoPor === 'llm' && lido.send !== true) || !mensagem) {
    const serie = await serieDe(ctx, { status: 'declined', decided_by: 'llm' });
    if (serie && serie.status !== 'declined') await atualizar(serie.id, { status: 'declined', decided_by: 'llm' });
    nota('nao vale retomar (' + decididoPor + ')');
    continue;
  }

  if (!recentes[ctx.inboxId]) {
    recentes[ctx.inboxId] = (await sb('GET', 'bot_followup_sends?chatwoot_inbox_id=eq.' + ctx.inboxId + '&select=content&order=sent_at.desc&limit=20'))
      .map(s => normalizar(s.content));
  }
  const norm = normalizar(mensagem);
  const parecidos = recentes[ctx.inboxId].filter(t => t === norm || jaccard(t, norm) >= JACCARD).length;
  if (norm.length > 15 && parecidos >= REPETICOES) {
    const serie = await serieDe(ctx, { status: 'active' });
    if (serie) {
      const vetos = serie.vetoes + 1;
      await atualizar(serie.id, { vetoes: vetos, status: vetos >= MAX_VETOS ? 'vetoed' : serie.status });
    }
    nota('vetado: parecido com ' + parecidos + ' dos ultimos 20 envios do numero');
    continue;
  }

  // Entre a varredura e agora o cliente pode ter respondido ou um humano assumido.
  const agora = await exigir('GET', CHATWOOT + ctx.accountId + '/conversations/' + ctx.conversationId, { api_access_token: ctx.botToken });
  const ultima = agora.last_non_activity_message || {};
  if (agora.status !== 'pending' || (agora.meta || {}).assignee_type === 'User' || ultima.id !== ctx.lastMessageId) {
    nota('a conversa mudou antes do envio');
    continue;
  }

  const serie = await serieDe(ctx, { status: 'active' });
  if (!serie) { nota('o contato ja tem outro follow-up vivo'); continue; }

  if (ultimoEnvio[ctx.inboxId]) {
    const gap = (JITTER_S[0] + Math.random() * (JITTER_S[1] - JITTER_S[0])) * 1000;
    const falta = ultimoEnvio[ctx.inboxId] + gap - Date.now();
    if (falta > 0) await espera(falta);
  }

  const base = CHATWOOT + ctx.accountId + '/conversations/' + ctx.conversationId;
  for (const bolha of bolhas(mensagem)) {
    await exigir('POST', base + '/toggle_typing_status', { api_access_token: ctx.botToken }, { typing_status: 'on' });
    await espera(Math.min(Math.max(900 + 22 * bolha.length, 1200), 7500));
    await exigir('POST', base + '/messages', { api_access_token: ctx.botToken }, { content: bolha, message_type: 'outgoing' });
  }
  ultimoEnvio[ctx.inboxId] = Date.now();

  const tentativas = serie.attempts + 1;
  await atualizar(serie.id, {
    attempts: tentativas,
    last_sent_at: new Date().toISOString(),
    decided_by: decididoPor,
    status: tentativas >= ctx.maxFollowups ? 'exhausted' : 'active',
  });
  await sb('POST', 'bot_followup_sends', {
    followup_id: serie.id, chatwoot_account_id: ctx.accountId, chatwoot_inbox_id: ctx.inboxId, content: mensagem,
  });
  recentes[ctx.inboxId].unshift(norm);
  nota('enviado (tentativa ' + tentativas + ', ' + decididoPor + ')');
}

return [{ json: { relatorio: relatorio } }];
