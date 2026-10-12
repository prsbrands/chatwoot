// No Candidatos do workflow "CortexGen Caso" (a cada minuto).
//
// Por conta com bot ligado: o Rails reserva as respostas que a equipe escreveu
// num caso para a IA repassar ao cliente (POST cases/bot/relays/claims,
// Cases::AiCases), so das conversas nas caixas do bot. Sai um item por
// resposta, com a rota da caixa (persona, modelo e provedor) e o token do bot
// para postar. Conta sem a flag cases (401) fica de fora. Conta no teto mensal
// de IA nao passa pelo LLM: o texto da equipe sai daqui como esta, numa bolha,
// e o resultado volta ao Rails.

const https = require('https');

const CHATWOOT = 'https://prs.cortexgen.cloud/api/v1/accounts/';
const POR_CONTA = 5;

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
          const erro = new Error(method + ' ' + url.split('?')[0] + ': HTTP ' + res.statusCode + ' ' + raw.slice(0, 200));
          erro.statusCode = res.statusCode;
          reject(erro);
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
const sbHeaders = { apikey: $env.SUPABASE_SERVICE_ROLE_KEY, authorization: 'Bearer ' + $env.SUPABASE_SERVICE_ROLE_KEY };
const supabase = (method, path, body) => pedir(method, SB + path, sbHeaders, body);

const rotas = await supabase('GET', 'bot_route_resolved?is_active=is.true&select=*');
if (!rotas.length) return [];

const contas = [...new Set(rotas.map(r => r.chatwoot_account_id))];
const ajustes = await supabase('GET', 'bot_account_settings?chatwoot_account_id=in.(' + contas.join(',') + ')&select=chatwoot_account_id,chat_user_token,ai_monthly_budget_usd');
const tokens = await supabase('GET', 'bot_channel_routes?chatwoot_account_id=in.(' + contas.join(',') + ')&select=chatwoot_account_id,chatwoot_inbox_id,chatwoot_agent_bot_access_token');

const itens = [];
for (const conta of contas) {
  const ajuste = ajustes.find(a => a.chatwoot_account_id === conta) || {};
  if (!ajuste.chat_user_token) throw new Error('conta ' + conta + ' sem chat_user_token');
  let noTeto = false;
  if (ajuste.ai_monthly_budget_usd !== null && ajuste.ai_monthly_budget_usd !== undefined) {
    const gasto = await supabase('POST', 'rpc/bot_ai_month_spend', { p_account: conta });
    noTeto = Number(gasto) >= Number(ajuste.ai_monthly_budget_usd);
  }

  const daConta = rotas.filter(r => r.chatwoot_account_id === conta);
  let reservadas;
  try {
    reservadas = await pedir('POST', CHATWOOT + conta + '/cases/bot/relays/claims', { api_access_token: ajuste.chat_user_token },
      { inbox_ids: daConta.map(r => r.chatwoot_inbox_id), limit: POR_CONTA });
  } catch (error) {
    if (error.statusCode === 401 || error.statusCode === 403) continue;
    throw error;
  }
  for (const item of reservadas.payload || []) {
    const botToken = (tokens.find(t => t.chatwoot_account_id === conta && t.chatwoot_inbox_id === item.inbox_id) || {}).chatwoot_agent_bot_access_token;
    if (noTeto) {
      let enviado = true;
      try {
        await pedir('POST', CHATWOOT + conta + '/conversations/' + item.conversation_id + '/messages', { api_access_token: botToken },
          { content: item.text, message_type: 'outgoing' });
      } catch (error) {
        enviado = false;
      }
      await pedir('POST', CHATWOOT + conta + '/cases/bot/relays/' + item.event_id, { api_access_token: ajuste.chat_user_token },
        { sent: enviado, message: enviado ? item.text : null });
      continue;
    }
    itens.push({ json: Object.assign({ accountId: conta, chatUserToken: ajuste.chat_user_token, botToken: botToken },
      item, { rota: daConta.find(r => r.chatwoot_inbox_id === item.inbox_id) }) });
  }
}

return itens;
