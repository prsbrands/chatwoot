// No GravaEvolucao do workflow "CortexGen Evolução" (depois do LLMEvolucao /
// LLMEvolucaoCustom). Roda uma vez para todos os itens.
//
// Por rodada (ate 20 conversas da mesma persona): registra o LLM no Uso de IA
// (kind 'evolution', conta no teto; db/botlayer/bot_ai_evolution.sql), le o
// JSON e grava pelo Rails (POST ai_evolution/bot/results), que junta as iguais
// e descarta correcao sem o trecho exato. Aceita tambem o formato que o
// DeepSeek inventou em 12/10 ({"knowledge_update": {...}} em vez de "kind") e
// as citacoes soltas no lugar de "evidence". Resposta ilegivel nao grava: a
// reserva vence em 1 h e as conversas voltam na rodada seguinte.

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

// {"knowledge_update": {...}} vira {"kind": "knowledge_update", ...}; citacao
// solta (conversation_id/customer_quote/team_quote) vira "evidence".
function normaliza(s) {
  if (!s || typeof s !== 'object') return null;
  let p = s;
  if (!p.kind) {
    const tipo = KINDS.find(k => p[k] && typeof p[k] === 'object');
    if (tipo) p = Object.assign({ kind: tipo }, p[tipo]);
  }
  if (!Array.isArray(p.evidence) && p.conversation_id !== undefined) {
    p = Object.assign({}, p, { evidence: [{ conversation_id: p.conversation_id, customer_quote: p.customer_quote, team_quote: p.team_quote }] });
  }
  return p;
}

// Proposta nova com tipo, titulo, texto e evidencia; ou so a evidencia de uma pendente (same_as).
const valida = s => s && Array.isArray(s.evidence) && s.evidence.length > 0 && (Number.isInteger(s.same_as) ||
  (KINDS.includes(s.kind) && typeof s.title === 'string' && s.title.trim() && typeof s.content === 'string' && s.content.trim()));

const relatorio = [];

for (const [k, item] of $input.all().entries()) {
  const res = item.json;
  const ctx = $('MontaEvolucao').itemMatching(k).json.ctx;
  const ids = ctx.conversations.map(c => c.conversation_id).join(',');
  const nota = r => relatorio.push({ json: { conversas: ctx.accountId + '/' + ids, resultado: r } });

  if (!res.error && res.type !== 'error') {
    const usage = res.usage || {};
    await pedir('POST', SB + 'bot_interactions', sbHeaders, {
      chatwoot_account_id: ctx.accountId, chatwoot_conversation_id: ctx.conversations[0].conversation_id,
      chatwoot_message_id: ctx.conversations[0].last_message_id,
      persona_id: ctx.personaId, kind: 'evolution', provider: ctx.provider, model: res.model || null,
      tokens_in: usage.prompt_tokens || usage.input_tokens || 0, tokens_out: usage.completion_tokens || usage.output_tokens || 0,
      cost_usd: typeof usage.cost === 'number' ? usage.cost : null, status: 'ok',
    });
  }

  const lidas = lerResposta(res);
  if (!lidas) { nota('LLM sem JSON legivel; volta depois de 1 h'); continue; }

  const gravado = await pedir('POST', CHATWOOT + ctx.accountId + '/ai_evolution/bot/results', { api_access_token: ctx.chatUserToken }, {
    persona_id: ctx.personaId,
    persona_name: ctx.personaName,
    conversations: ctx.conversations,
    suggestions: lidas.map(normaliza).filter(valida).slice(0, 10),
  });
  nota(gravado.saved.length + ' proposta(s) gravada(s) de ' + ctx.conversations.length + ' conversa(s)');
}

return relatorio;
