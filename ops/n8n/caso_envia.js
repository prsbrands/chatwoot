// No EnviaRepasse do workflow "CortexGen Caso" (depois do LLMRepasse /
// LLMRepasseCustom). Roda uma vez para todos os itens.
//
// Por resposta da equipe: registra o LLM no Uso de IA (kind 'reply': e uma
// mensagem ao cliente, conta no teto), posta como o bot (bolhas com
// "digitando" no WhatsApp por QR, como o Responde do bot) e devolve o
// resultado ao Rails (POST cases/bot/relays/:id). Sem mensagem do cliente
// por tras, o registro de uso leva chatwoot_message_id 0. LLM sem texto: vai o texto
// da equipe como esta. Falha ao postar: o Rails marca como falha e avisa quem
// escreveu.

const https = require('https');

const CHATWOOT = 'https://prs.cortexgen.cloud/api/v1/accounts/';
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

// O OpenWA (canal API com bolhas) recebe o texto cru: Markdown vira o formato
// do WhatsApp, como no Responde.
const paraWhatsapp = texto => texto
  .replace(/^#{1,6}\s+(.+)$/gm, '*$1*')
  .replace(/\*\*(.+?)\*\*/g, '*$1*')
  .replace(/__(.+?)__/g, '_$1_')
  .replace(/~~(.+?)~~/g, '~$1~')
  .replace(/\[([^\]]+)\]\((https?:[^)\s]+)\)/g, '$1: $2');
const atraso = texto => Math.min(Math.max(900 + 22 * texto.length, 1200), 7500);
const espera = ms => new Promise(resolve => setTimeout(resolve, ms));
const bolhas = texto => {
  const partes = texto.split(/\n\s*\n/).map(p => p.trim()).filter(Boolean);
  if (partes.length > MAX_BOLHAS) partes.push(partes.splice(MAX_BOLHAS - 1).join('\n\n'));
  return partes;
};

function lerResposta(res) {
  if (res.error || res.type === 'error') return '';
  const texto = Array.isArray(res.content)
    ? res.content.filter(p => p.type === 'text').map(p => p.text).join('\n')
    : String((((res.choices || [])[0] || {}).message || {}).content || '');
  return texto.trim().replace(/^"(.*)"$/s, '$1');
}

const relatorio = [];

for (const [k, item] of $input.all().entries()) {
  const res = item.json;
  const ctx = $('MontaRepasse').itemMatching(k).json.ctx;
  const nota = r => relatorio.push({ json: { resposta: ctx.accountId + '/' + ctx.eventId, resultado: r } });

  if (!res.error && res.type !== 'error') {
    const usage = res.usage || {};
    await pedir('POST', SB + 'bot_interactions', sbHeaders, {
      chatwoot_account_id: ctx.accountId, chatwoot_conversation_id: ctx.conversationId, chatwoot_message_id: 0,
      persona_id: ctx.personaId, kind: 'reply', provider: ctx.provider, model: res.model || null,
      tokens_in: usage.prompt_tokens || usage.input_tokens || 0, tokens_out: usage.completion_tokens || usage.output_tokens || 0,
      cost_usd: typeof usage.cost === 'number' ? usage.cost : null, status: 'ok',
    }).catch(() => {});
  }

  const texto = lerResposta(res) || ctx.text;
  const conversa = CHATWOOT + ctx.accountId + '/conversations/' + ctx.conversationId;
  const bot = { api_access_token: ctx.botToken };
  let enviado = true;
  try {
    if (ctx.splitReplies) {
      for (const bolha of bolhas(paraWhatsapp(texto))) {
        await pedir('POST', conversa + '/toggle_typing_status', bot, { typing_status: 'on' });
        await espera(atraso(bolha));
        await pedir('POST', conversa + '/messages', bot, { content: bolha, message_type: 'outgoing' });
      }
    } else {
      await pedir('POST', conversa + '/messages', bot, { content: texto, message_type: 'outgoing' });
    }
  } catch (error) {
    enviado = false;
    console.error('EnviaRepasse: ' + error.message);
  }

  await pedir('POST', CHATWOOT + ctx.accountId + '/cases/bot/relays/' + ctx.eventId, { api_access_token: ctx.chatUserToken },
    { sent: enviado, message: enviado ? texto : null });
  nota(enviado ? 'enviada' : 'falhou ao postar');
}

return relatorio;
