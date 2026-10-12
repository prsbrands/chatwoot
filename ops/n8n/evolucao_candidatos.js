// No Candidatos do workflow "CortexGen Evolução" (uma vez por dia).
//
// Por conta com bot ligado: o Rails reserva as conversas das caixas do bot com
// sinal novo desde a ultima leitura (passagem com resposta da equipe, resposta
// retida pelo Jev, caso aberto pela IA), paradas ha 2 h (POST
// ai_evolution/bot/claims, AiEvolution::Bot). Vai o par caixa -> persona de
// cada rota, para o Rails mandar a base e as propostas da persona certa. Sai um
// item por conversa, com a rota (modelo e provedor). Conta sem a flag
// ai_evolution (401) ou no teto mensal de IA fica de fora.

const https = require('https');

const CHATWOOT = 'https://prs.cortexgen.cloud/api/v1/accounts/';
const POR_CONTA = 20;

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

const itens = [];
for (const conta of contas) {
  const ajuste = ajustes.find(a => a.chatwoot_account_id === conta) || {};
  if (!ajuste.chat_user_token) throw new Error('conta ' + conta + ' sem chat_user_token');
  if (ajuste.ai_monthly_budget_usd !== null && ajuste.ai_monthly_budget_usd !== undefined) {
    const gasto = await supabase('POST', 'rpc/bot_ai_month_spend', { p_account: conta });
    if (Number(gasto) >= Number(ajuste.ai_monthly_budget_usd)) continue;
  }

  const daConta = rotas.filter(r => r.chatwoot_account_id === conta);
  let reservadas;
  try {
    reservadas = await pedir('POST', CHATWOOT + conta + '/ai_evolution/bot/claims', { api_access_token: ajuste.chat_user_token },
      { routes: daConta.map(r => ({ inbox_id: r.chatwoot_inbox_id, persona_id: r.persona_id })), limit: POR_CONTA });
  } catch (error) {
    if (error.statusCode === 401 || error.statusCode === 403) continue;
    throw error;
  }
  for (const item of reservadas.payload || []) {
    itens.push({ json: Object.assign({ accountId: conta, chatUserToken: ajuste.chat_user_token },
      item, { rota: daConta.find(r => r.chatwoot_inbox_id === item.inbox_id) }) });
  }
}

return itens;
