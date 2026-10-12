// No GravaEvolucao do workflow "CortexGen Evolução" (depois do LLMEvolucao /
// LLMEvolucaoCustom). Roda uma vez para todos os itens.
//
// Por conversa: registra o LLM no Uso de IA (kind 'evolution', conta no teto;
// db/botlayer/bot_ai_evolution.sql), le o JSON e grava pelo Rails (POST
// ai_evolution/bot/results), que junta as iguais e descarta correcao sem o
// trecho exato. Resposta ilegivel nao grava: a reserva vence em 1 h e a
// conversa volta na rodada seguinte.

const https = require('https');

const CHATWOOT = 'https://prs.cortexgen.cloud/api/v1/accounts/';
const KINDS = ['knowledge_add', 'knowledge_update', 'prompt_rule'];

function pedir(method, url, headers, body) {
  return new Promise((resolve, reject) => {
    const data = body === undefined ? '' : JSON.stringify(body);
    const req = https.request(url, {
      method: method,
      headers: Object.assign({ 'content-type': 'application/json', 'content-length': Buffer.byteLength(data) }, headers),
    }, res => {
      let raw = '';
      res.on('data', chunk => { raw += chunk; });
      res.on('end', () => {
        if (res.statusCode < 200 || res.statusCode >= 300) {
          reject(new Error(method + ' ' + url.split('?')[0] + ': HTTP ' + res.statusCode + ' ' + raw.slice(0, 200)));
        } else {
          resolve(raw ? JSON.parse(raw) : null);
        }
      });
    });
    req.setTimeout(20000, () => req.destroy(new Error(method + ' ' + url.split('?')[0] + ': timeout')));
    req.on('error', reject);
    req.end(data);
  });
}

const SB = $env.SUPABASE_REST_URL + '/';
const sbHeaders = { apikey: $env.SUPABASE_SERVICE_ROLE_KEY, authorization: 'Bearer ' + $env.SUPABASE_SERVICE_ROLE_KEY, prefer: 'return=minimal' };

function lerResposta(res) {
  if (res.error || res.type === 'error') return null;
  const texto = Array.isArray(res.content)
    ? res.content.filter(p => p.type === 'text').map(p => p.text).join('\n')
    : String((((res.choices || [])[0] || {}).message || {}).content || '');
  try {
    const lido = JSON.parse(texto.slice(texto.indexOf('{'), texto.lastIndexOf('}') + 1));
    return Array.isArray(lido.suggestions) ? lido.suggestions : null;
  } catch (e) {
    return null;
  }
}

// Proposta nova com tipo, titulo e texto; ou so a evidencia de uma pendente (same_as).
const valida = s => s && typeof s === 'object' && (Number.isInteger(s.same_as) ||
  (KINDS.includes(s.kind) && typeof s.title === 'string' && s.title.trim() && typeof s.content === 'string' && s.content.trim()));

const relatorio = [];

for (const [k, item] of $input.all().entries()) {
  const res = item.json;
  const ctx = $('MontaEvolucao').itemMatching(k).json.ctx;
  const nota = r => relatorio.push({ json: { conversa: ctx.accountId + '/' + ctx.conversationId, resultado: r } });

  if (!res.error && res.type !== 'error') {
    const usage = res.usage || {};
    await pedir('POST', SB + 'bot_interactions', sbHeaders, {
      chatwoot_account_id: ctx.accountId, chatwoot_conversation_id: ctx.conversationId, chatwoot_message_id: ctx.lastMessageId,
      persona_id: ctx.personaId, kind: 'evolution', provider: ctx.provider, model: res.model || null,
      tokens_in: usage.prompt_tokens || usage.input_tokens || 0, tokens_out: usage.completion_tokens || usage.output_tokens || 0,
      cost_usd: typeof usage.cost === 'number' ? usage.cost : null, status: 'ok',
    });
  }

  const lidas = lerResposta(res);
  if (!lidas) { nota('LLM sem JSON legivel; volta depois de 1 h'); continue; }

  const gravado = await pedir('POST', CHATWOOT + ctx.accountId + '/ai_evolution/bot/results', { api_access_token: ctx.chatUserToken }, {
    conversation_id: ctx.conversationId,
    last_message_id: ctx.lastMessageId,
    persona_id: ctx.personaId,
    persona_name: ctx.personaName,
    suggestions: lidas.filter(valida).slice(0, 3),
  });
  nota(gravado.saved.length + ' proposta(s) gravada(s)');
}

return relatorio;
