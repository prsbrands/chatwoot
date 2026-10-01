// No Candidatos do workflow "CortexGen Follow-up" (a cada 15 min).
//
// Acha as conversas em que o bot falou por ultimo e o cliente sumiu, nas rotas
// do OpenWA (split_replies) cuja persona tem follow-up ligado. Sai um item por
// conversa a retomar; o Jev, o LLM e o envio vem depois.
//
// Regras (as do DeskComm, lib/followup/silence-sweep.ts, com o que custou la):
// - pendente com o bot: humano atribuido, contato bloqueado ou conversa
//   aberta/resolvida ficam de fora;
// - a ultima mensagem nao privada e do bot, ha pelo menos N horas;
// - uma serie por SILENCIO: bot_followups.anchor_message_id = ultima mensagem
//   do cliente. Serie esgotada, recusada ou vetada nao volta sem o cliente
//   escrever de novo. Sem isso a varredura reinscreve o mesmo contato a cada
//   rodada (32 vezes em 9 h no DeskComm);
// - o cliente escreveu nos ultimos 7 dias: ligar o recurso nao pode acordar
//   conversa de meses atras;
// - janela 8h-20h no fuso da inbox (inbox em UTC = fuso nao configurado, fica
//   sem follow-up); fora dela a conversa espera a proxima varredura;
// - teto diario pela idade do numero (20 -> 50 -> 100 -> 200) e no maximo 3
//   por inbox por varredura, para o envio caber no tempo do Code node.

const https = require('https');

const CHATWOOT = 'https://prs.cortexgen.cloud/api/v1/accounts/';
const JANELA = [8, 20];
const MAX_IDADE_DIAS = 7;
const POR_VARREDURA = 3;
const MAX_PAGINAS = 10;
const teto = idadeDias => (idadeDias <= 3 ? 20 : idadeDias <= 7 ? 50 : idadeDias <= 14 ? 100 : 200);

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
          resolve({ headers: res.headers, body: raw ? JSON.parse(raw) : null });
        }
      });
    });
    req.setTimeout(20000, () => req.destroy(new Error(method + ' ' + url.split('?')[0] + ': timeout')));
    req.on('error', reject);
    req.end(data);
  });
}

const SB = $env.SUPABASE_REST_URL + '/';
const sbHeaders = { apikey: $env.SUPABASE_SERVICE_ROLE_KEY, authorization: 'Bearer ' + $env.SUPABASE_SERVICE_ROLE_KEY };
const supabase = async (method, path, body, extra) => (await pedir(method, SB + path, Object.assign({}, sbHeaders, extra), body)).body;

const rotas = await supabase('GET', 'bot_route_resolved?split_replies=is.true&is_active=is.true&followup_after_hours=gt.0&select=*');
if (!rotas.length) return [];

const contas = [...new Set(rotas.map(r => r.chatwoot_account_id))];
const ajustes = await supabase('GET', 'bot_account_settings?chatwoot_account_id=in.(' + contas.join(',') + ')&select=chatwoot_account_id,chat_user_token,jev_api_key,jev');
const tokens = await supabase('GET', 'bot_channel_routes?chatwoot_account_id=in.(' + contas.join(',') + ')&select=chatwoot_account_id,chatwoot_inbox_id,chatwoot_agent_bot_access_token');

const agora = Date.now();
const itens = [];

for (const rota of rotas) {
  const conta = rota.chatwoot_account_id;
  const inbox = rota.chatwoot_inbox_id;
  const ajuste = ajustes.find(a => a.chatwoot_account_id === conta) || {};
  const userToken = ajuste.chat_user_token;
  const botToken = (tokens.find(t => t.chatwoot_account_id === conta && t.chatwoot_inbox_id === inbox) || {}).chatwoot_agent_bot_access_token;
  if (!userToken || !botToken) throw new Error('conta ' + conta + ' / inbox ' + inbox + ' sem chat_user_token ou token do bot');
  const cw = (method, path, body) => pedir(method, CHATWOOT + conta + path, { api_access_token: userToken }, body).then(r => r.body);

  const dadosInbox = await cw('GET', '/inboxes/' + inbox);
  // Sessao do WhatsApp caida (Openwa::SessionWatchJob no Rails): o follow-up
  // apareceria no Chatwoot e nunca chegaria ao cliente.
  if (dadosInbox.reauthorization_required) continue;
  const fuso = dadosInbox.timezone;
  if (!fuso || fuso === 'UTC' || fuso === 'Etc/UTC') continue;
  // hourCycle h23: com hour12:false alguns ICU devolvem "24" a meia-noite, e a
  // janela deixava passar envio nessa hora (relogio.ts no DeskComm).
  const partes = Object.fromEntries(new Intl.DateTimeFormat('en-US', {
    timeZone: fuso, hourCycle: 'h23', year: 'numeric', month: '2-digit', day: '2-digit', hour: '2-digit', minute: '2-digit',
  }).formatToParts(new Date(agora)).map(p => [p.type, p.value]));
  const hora = Number(partes.hour);
  if (hora < JANELA[0] || hora >= JANELA[1]) continue;

  // Meia-noite local em UTC: o dia do teto e o do cliente, nao o do servidor.
  const minutosDesdeMeiaNoite = hora * 60 + Number(partes.minute);
  const meiaNoite = new Date(agora - minutosDesdeMeiaNoite * 60000 - (agora % 60000)).toISOString();
  const enviadosHoje = await pedir('GET', SB + 'bot_followup_sends?chatwoot_inbox_id=eq.' + inbox + '&sent_at=gte.' + meiaNoite + '&select=id',
    Object.assign({ prefer: 'count=exact', range: '0-0' }, sbHeaders));
  const jaHoje = Number(String(enviadosHoje.headers['content-range'] || '*/0').split('/')[1]) || 0;
  const idade = rota.number_activated_at ? Math.max(0, Math.floor((agora - Date.parse(rota.number_activated_at)) / 86400000)) : 0;
  let vagas = Math.min(POR_VARREDURA, teto(idade) - jaHoje);
  if (vagas <= 0) continue;

  const horas = Number(rota.followup_after_hours);
  const limiteSilencio = agora - horas * 3600000;
  const limiteIdade = agora - MAX_IDADE_DIAS * 86400000;

  for (let pagina = 1; pagina <= MAX_PAGINAS && vagas > 0; pagina += 1) {
    const lista = await cw('GET', '/conversations?inbox_id=' + inbox + '&status=pending&assignee_type=all&page=' + pagina);
    const conversas = (lista.data && lista.data.payload) || [];
    if (!conversas.length) break;

    for (const conv of conversas) {
      if (vagas <= 0) break;
      const meta = conv.meta || {};
      if (meta.assignee_type === 'User' || (meta.sender || {}).blocked) continue;
      const ultimaQualquer = conv.last_non_activity_message;
      if (!ultimaQualquer || ultimaQualquer.message_type !== 1 || ultimaQualquer.created_at * 1000 > limiteSilencio) continue;

      const mensagens = ((await cw('GET', '/conversations/' + conv.id + '/messages')).payload || [])
        .filter(m => !m.private && (m.message_type === 0 || m.message_type === 1) && String(m.content || '').trim());
      const ultima = mensagens[mensagens.length - 1];
      if (!ultima || ultima.message_type !== 1 || ultima.created_at * 1000 > limiteSilencio) continue;
      const doCliente = mensagens.filter(m => m.message_type === 0);
      const ancora = doCliente[doCliente.length - 1];
      if (!ancora || ancora.created_at * 1000 < limiteIdade) continue;

      // O cliente respondeu desde a serie anterior: ela acabou.
      await supabase('PATCH', 'bot_followups?chatwoot_account_id=eq.' + conta + '&chatwoot_conversation_id=eq.' + conv.id +
        '&status=eq.active&anchor_message_id=neq.' + ancora.id, { status: 'replied', updated_at: new Date().toISOString() }, { prefer: 'return=minimal' });

      const serie = (await supabase('GET', 'bot_followups?chatwoot_account_id=eq.' + conta + '&chatwoot_conversation_id=eq.' + conv.id +
        '&anchor_message_id=eq.' + ancora.id + '&select=id,status,attempts,vetoes'))[0] || null;
      if (serie && serie.status !== 'active') continue;
      if (serie && serie.attempts >= Number(rota.max_followups)) {
        await supabase('PATCH', 'bot_followups?id=eq.' + serie.id, { status: 'exhausted', updated_at: new Date().toISOString() }, { prefer: 'return=minimal' });
        continue;
      }

      vagas -= 1;
      itens.push({ json: {
        accountId: conta,
        inboxId: inbox,
        conversationId: conv.id,
        contactId: (meta.sender || {}).id,
        contactName: (meta.sender || {}).name || '',
        contactEmail: (meta.sender || {}).email || '',
        anchorMessageId: ancora.id,
        lastMessageId: ultima.id,
        serie: serie,
        tentativa: serie ? serie.attempts + 1 : 1,
        horasCalado: Math.floor((agora - ancora.created_at * 1000) / 3600000),
        conversa: mensagens.slice(-20).map(m => ({ from: m.message_type === 0 ? 'customer' : 'assistant', text: String(m.content).trim() })),
        botToken: botToken,
        jevKey: ajuste.jev_api_key || null,
        jev: ajuste.jev || {},
        rota: rota,
      } });
    }
  }
}

return itens;
