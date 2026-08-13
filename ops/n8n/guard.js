const crypto = require('crypto');
const https = require('https');

// O sandbox do Code node do n8n roda num task runner separado sem `fetch`
// global (confirmado ao vivo: "fetch is not defined"), mesmo com Node 24 no
// container. O modulo nativo `https` funciona porque ja esta liberado junto
// com `crypto` (NODE_FUNCTION_ALLOW_BUILTIN no docker-compose do n8n).
function getJson(url, headers) {
  return new Promise((resolve, reject) => {
    https.get(url, { headers }, res => {
      let body = '';
      res.on('data', chunk => { body += chunk; });
      res.on('end', () => resolve({ statusCode: res.statusCode, body }));
    }).on('error', reject);
  });
}

const raw = $input.first().json;
const b = raw.body || raw;
const headers = raw.headers || {};

// O webhook e um endereco publico: quem souber a URL injeta mensagem, faz o bot
// responder e gasta credito de LLM escrevendo em conversa de cliente. O Chatwoot
// assina todo payload; ate agora ninguem conferia.
//
// Assinatura: sha256=HMAC_SHA256(secret, "<timestamp>.<corpo cru>") em
// lib/webhooks/trigger.rb. O corpo cru importa: o n8n entrega o JSON ja
// parseado, e reserializar com JSON.stringify NAO reproduz o que o Rails
// mandou. O ActiveSupport escapa <, > e & como < > &, entao uma
// mensagem com "R&D" ou com HTML (toda a inbox de e-mail) daria assinatura
// diferente e o bot ficaria mudo so para esses clientes. Medido, nao suposto.
const LS = String.fromCharCode(0x2028);
const PS = String.fromCharCode(0x2029);
const railsJson = obj => JSON.stringify(obj)
  .split('<').join('\\u003c')
  .split('>').join('\\u003e')
  .split('&').join('\\u0026')
  .split(LS).join('\\u2028')
  .split(PS).join('\\u2029');

const assinatura = headers['x-chatwoot-signature'];
const ts = headers['x-chatwoot-timestamp'];

// Falhar alto, nao em silencio: `return []` deixaria a execucao verde e a
// mensagem sumindo, que e o modo de falha que mais custou neste projeto.
// Execucao com erro aparece na lista de execucoes do n8n.
if (!assinatura || !ts) throw new Error('webhook sem assinatura do Chatwoot — recusado');

// Cada conta tem seu proprio AgentBot com seu proprio secret — nao da mais
// pra verificar contra um valor fixo (era CHATWOOT_WEBHOOK_SECRET, copiado
// uma vez do bot da conta 1). accountId/inboxId vem do payload ainda NAO
// verificado, mas usa-los so pra escolher QUAL secret tentar nao abre
// brecha: quem nao souber o secret certo continua barrado no proximo passo,
// tanto faz o que declarou aqui. Bug visto em producao 12/08: conta dagente
// com bot Vitor, Guard comparando contra o secret do Nathan, mensagem nunca
// respondida — em silencio, porque a assinatura so falhava.
const accountId = b.account && b.account.id;
const inboxId = (b.inbox && b.inbox.id) || (b.conversation && b.conversation.inbox_id);
if (!accountId || !inboxId) throw new Error('payload sem account/inbox — nao da pra saber qual secret verificar');

const supabaseUrl = $env.SUPABASE_REST_URL;
const supabaseKey = $env.SUPABASE_SERVICE_ROLE_KEY;
if (!supabaseUrl || !supabaseKey) throw new Error('SUPABASE_REST_URL/SUPABASE_SERVICE_ROLE_KEY ausente no ambiente do n8n');

const lookupUrl = supabaseUrl + '/bot_channel_routes?chatwoot_account_id=eq.' + accountId +
  '&chatwoot_inbox_id=eq.' + inboxId + '&select=chatwoot_agent_bot_secret,chatwoot_agent_bot_access_token';
const lookupResponse = await getJson(lookupUrl, { apikey: supabaseKey, Authorization: 'Bearer ' + supabaseKey });
if (lookupResponse.statusCode < 200 || lookupResponse.statusCode >= 300) {
  throw new Error('falha ao consultar bot_channel_routes: HTTP ' + lookupResponse.statusCode);
}
const rows = JSON.parse(lookupResponse.body);
const segredo = rows[0] && rows[0].chatwoot_agent_bot_secret;
// Rota criada antes desta migracao (ou nunca migrada) nao tem o secret
// gravado — falha alto em vez de aceitar sem verificar.
if (!segredo) throw new Error('sem secret de bot gravado para conta ' + accountId + ' / inbox ' + inboxId + ' — recrie a rota em Bot Personas > Channels');

// Responde/Handoff postam de volta no Chatwoot autenticados como o bot; sem
// o access_token certo por conta, account_accessible_for_bot? recusa com
// "Bot is not authorized to access this account" (ensure_current_account_helper.rb).
const botAccessToken = rows[0] && rows[0].chatwoot_agent_bot_access_token;
if (!botAccessToken) throw new Error('sem access_token de bot gravado para conta ' + accountId + ' / inbox ' + inboxId + ' — recrie a rota em Bot Personas > Channels');

// O no Historico le o historico da conversa com token de User (o de Agent
// Bot nao pode chamar messages#index, de proposito — ver HANDOFF "Historico
// com 401"). Token fixo de uma unica conta quebraria toda conta que nao
// fosse essa (mesma classe de bug do secret acima); resolve por conta aqui
// e passa adiante, em vez de credential fixo no proprio no Historico.
const tokenUrl = supabaseUrl + '/bot_account_settings?chatwoot_account_id=eq.' + accountId + '&select=chat_user_token';
const tokenResponse = await getJson(tokenUrl, { apikey: supabaseKey, Authorization: 'Bearer ' + supabaseKey });
if (tokenResponse.statusCode < 200 || tokenResponse.statusCode >= 300) {
  throw new Error('falha ao consultar bot_account_settings: HTTP ' + tokenResponse.statusCode);
}
const tokenRows = JSON.parse(tokenResponse.body);
const chatUserToken = tokenRows[0] && tokenRows[0].chat_user_token;
if (!chatUserToken) throw new Error('sem chat_user_token gravado para conta ' + accountId + ' — rode o backfill de bot_account_settings');

const esperado = 'sha256=' + crypto
  .createHmac('sha256', segredo)
  .update(ts + '.' + railsJson(b))
  .digest('hex');

const a = Buffer.from(assinatura);
const e = Buffer.from(esperado);
if (a.length !== e.length || !crypto.timingSafeEqual(a, e)) {
  throw new Error('assinatura invalida — payload nao veio do Chatwoot');
}

// Janela de 5 minutos: sem isso, um payload legitimo capturado uma vez poderia
// ser reenviado para sempre, com assinatura valida.
const idade = Math.abs(Math.floor(Date.now() / 1000) - Number(ts));
if (!Number.isFinite(idade) || idade > 300) {
  throw new Error('assinatura expirada (' + idade + 's) — possivel reenvio');
}

if (b.event !== 'message_created') return [];
if (b.message_type !== 'incoming') return [];
if (b.private === true) return [];
const conv = b.conversation || {};
const meta = conv.meta || {};
// O Chatwoot atribui a conversa ao próprio bot (assignee_type 'AgentBot'),
// então só desiste quando quem assumiu é um humano.
if (meta.assignee_type === 'User') return [];
const content = String(b.content || '').trim();
if (!content) return [];
const sender = meta.sender || {};
return [{ json: {
  accountId: accountId,
  inboxId: inboxId,
  conversationId: conv.id,
  messageId: b.id,
  content: content,
  contactId: sender.id || null,
  contactName: sender.name || '',
  contactEmail: sender.email || '',
  callSummary: (sender.custom_attributes && sender.custom_attributes.call_summary) || '',
  startedAt: Date.now(),
  chatUserToken: chatUserToken,
  botAccessToken: botAccessToken,
} }];
