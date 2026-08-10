const crypto = require('crypto');

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

const segredo = $env.CHATWOOT_WEBHOOK_SECRET;
const assinatura = headers['x-chatwoot-signature'];
const ts = headers['x-chatwoot-timestamp'];

// Falhar alto, nao em silencio: `return []` deixaria a execucao verde e a
// mensagem sumindo, que e o modo de falha que mais custou neste projeto.
// Execucao com erro aparece na lista de execucoes do n8n.
if (!segredo) throw new Error('CHATWOOT_WEBHOOK_SECRET ausente no ambiente do n8n');
if (!assinatura || !ts) throw new Error('webhook sem assinatura do Chatwoot — recusado');

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
  accountId: (b.account && b.account.id) || 1,
  inboxId: (b.inbox && b.inbox.id) || conv.inbox_id,
  conversationId: conv.id,
  messageId: b.id,
  content: content,
  contactId: sender.id || null,
  contactName: sender.name || '',
  contactEmail: sender.email || '',
  callSummary: (sender.custom_attributes && sender.custom_attributes.call_summary) || '',
  startedAt: Date.now(),
} }];
