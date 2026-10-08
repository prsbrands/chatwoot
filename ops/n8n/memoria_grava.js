// No GravaMemoria do workflow "CortexGen Memória" (depois do LLMMemoria /
// LLMMemoriaCustom). Roda uma vez para todos os itens.
//
// Por conversa: registra o LLM no Uso de IA (kind 'memory', conta no teto),
// le o JSON e grava pelo Rails (POST ai_memory/bot/updates). Resposta ilegivel
// nao grava: a reserva vence em 1 h e a conversa volta numa rodada seguinte.

const https = require('https');

const CHATWOOT = 'https://prs.cortexgen.cloud/api/v1/accounts/';

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
    return typeof lido.summary === 'string' ? lido : null;
  } catch (e) {
    return null;
  }
}

const lista = v => (Array.isArray(v) ? v : []);
const relatorio = [];

for (const [k, item] of $input.all().entries()) {
  const res = item.json;
  const ctx = $('MontaMemoria').itemMatching(k).json.ctx;
  const nota = r => relatorio.push({ json: { conversa: ctx.accountId + '/' + ctx.conversationId, resultado: r } });

  if (!res.error && res.type !== 'error') {
    const usage = res.usage || {};
    await pedir('POST', SB + 'bot_interactions', sbHeaders, {
      chatwoot_account_id: ctx.accountId, chatwoot_conversation_id: ctx.conversationId, chatwoot_message_id: ctx.lastMessageId,
      persona_id: ctx.personaId, kind: 'memory', provider: ctx.provider, model: res.model || null,
      tokens_in: usage.prompt_tokens || usage.input_tokens || 0, tokens_out: usage.completion_tokens || usage.output_tokens || 0,
      cost_usd: typeof usage.cost === 'number' ? usage.cost : null, status: 'ok',
    });
  }

  const lido = lerResposta(res);
  if (!lido) { nota('LLM sem JSON legivel; volta depois de 1 h'); continue; }

  const gravado = await pedir('POST', CHATWOOT + ctx.accountId + '/ai_memory/bot/updates', { api_access_token: ctx.chatUserToken }, {
    contact_id: ctx.contactId,
    conversation_id: ctx.conversationId,
    last_message_id: ctx.lastMessageId,
    summary: lido.summary.trim() || ctx.summary,
    add: lista(lido.add).filter(t => typeof t === 'string'),
    update: lista(lido.update).filter(u => u && Number.isInteger(u.id) && typeof u.text === 'string'),
    remove: lista(lido.remove).filter(Number.isInteger),
  });
  nota('gravada (' + lista(lido.add).length + ' novos, ' + lista(lido.update).length + ' mudados, ' + lista(lido.remove).length + ' apagados) ate ' + gravado.last_message_id);
}

return relatorio;
