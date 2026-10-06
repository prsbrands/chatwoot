// No Responde do workflow do bot (depois do JevRevisao/PassaRevisao).
//
// Nos canais de mensageria a resposta sai como uma pessoa escreveria: em ate
// 4 bolhas, quebradas por paragrafo, cada uma depois de "digitando" e de uma
// espera proporcional ao tamanho. No widget vai numa bolha so, na hora. Quem
// decide e a rota (Guard.splitReplies).

const g = $('Guard').first().json;
const i = $input.first().json;
const https = require('https');

const MAX_BOLHAS = 4;

// O Chatwoot converte o Markdown do LLM para o formato de cada canal (WhatsApp
// Cloud, Instagram, Messenger...), mas o canal API manda o texto cru, e o
// OpenWA entregava "**negrito**" com os asteriscos. O OpenWA e o canal API com
// bolhas ligadas pela rota (o provision grava split_replies true); a voz e o
// site da DaGente tambem sao canal API, sem bolhas, e ficam como estao.
const doOpenwa = g.channel === 'Channel::Api' && g.splitReplies;
const paraWhatsapp = texto => texto
  .replace(/^#{1,6}\s+(.+)$/gm, '*$1*')
  .replace(/\*\*(.+?)\*\*/g, '*$1*')
  .replace(/__(.+?)__/g, '_$1_')
  .replace(/~~(.+?)~~/g, '~$1~')
  .replace(/\[([^\]]+)\]\((https?:[^)\s]+)\)/g, '$1: $2');
// Agendamento: a IA fecha a resposta com [[BOOK <horario>]] quando o cliente
// aceitou um horario (MontaPrompt). A etiqueta nunca chega ao cliente; o
// Rails confere de novo se o horario esta livre e marca. Ocupado no meio do
// caminho (409): a resposta vira um pedido de desculpas com as proximas opcoes.
const ETIQUETA = /\s*\[\[BOOK ([^\]]+)\]\]\s*/;
// Horario ja marcado no MontaPrompt: uma etiqueta que o LLM escreva assim
// mesmo so sai do texto, sem marcar de novo (daria 409 e um falso "ocupado").
const marcado = $('MontaPrompt').first().json.booked ? null : String(i.reply || '').match(ETIQUETA);
let texto = String(i.reply || '').replace(new RegExp(ETIQUETA.source, 'g'), '\n').trim();

// Catalogo (MontaPrompt): [[QUOTE 12x2, 15x1]] vira o rascunho da cotizacao,
// que a equipe revisa e envia (o Rails deixa a nota com mencao); [[SUBSCRIBE
// 12]] cria a assinatura do plano e o link vai numa bolha depois da resposta.
// As etiquetas nunca chegam ao cliente.
const COTACAO = /\s*\[\[QUOTE ([^\]]+)\]\]\s*/;
const ASSINAR = /\s*\[\[SUBSCRIBE (\d+)\]\]\s*/;
const cotacao = String(i.reply || '').match(COTACAO);
const assinar = String(i.reply || '').match(ASSINAR);
texto = texto.replace(new RegExp(COTACAO.source, 'g'), '\n').replace(new RegExp(ASSINAR.source, 'g'), '\n').trim();
const linhasDaCotacao = cotacao
  ? cotacao[1].split(/;|,\s+/).map(parte => parte.trim().match(/^(\d+)(?:\s*[x×*]\s*(\d+(?:[.,]\d+)?))?$/)).filter(Boolean)
    .map(m => ({ item_id: Number(m[1]), quantity: m[2] ? m[2].replace(',', '.') : '1' }))
  : [];

function agendar(startsAt) {
  return new Promise((resolve, reject) => {
    const data = JSON.stringify({ conversation_id: i.conversationId, starts_at: startsAt });
    const req = https.request('https://prs.cortexgen.cloud/api/v1/accounts/' + i.accountId + '/agenda/bot/bookings', {
      method: 'POST',
      headers: { 'content-type': 'application/json', 'content-length': Buffer.byteLength(data), api_access_token: g.chatUserToken },
    }, res => {
      let raw = '';
      res.on('data', chunk => { raw += chunk; });
      res.on('end', () => {
        if (res.statusCode >= 200 && res.statusCode < 300) resolve({ ok: true });
        else if (res.statusCode === 409) resolve({ ok: false, conflict: JSON.parse(raw) });
        else reject(new Error('Responde: agendar HTTP ' + res.statusCode + ' ' + raw.slice(0, 200)));
      });
    });
    req.setTimeout(20000, () => req.destroy(new Error('Responde: agendar timeout')));
    req.on('error', reject);
    req.end(data);
  });
}

// POST na API da conta com o token de usuario (o mesmo da Agenda): devolve o
// JSON, ou null com o erro no log, sem derrubar a resposta ao cliente.
function chamarComercial(caminho, corpo) {
  return new Promise(resolve => {
    const data = JSON.stringify(Object.assign({ conversation_id: i.conversationId }, corpo));
    const req = https.request('https://prs.cortexgen.cloud/api/v1/accounts/' + i.accountId + '/commerce/bot/' + caminho, {
      method: 'POST',
      headers: { 'content-type': 'application/json', 'content-length': Buffer.byteLength(data), api_access_token: g.chatUserToken },
    }, res => {
      let raw = '';
      res.on('data', chunk => { raw += chunk; });
      res.on('end', () => {
        if (res.statusCode >= 200 && res.statusCode < 300) return resolve(JSON.parse(raw));
        console.error('Responde: commerce/bot/' + caminho + ' ' + data + ' HTTP ' + res.statusCode + ' ' + raw.slice(0, 200));
        resolve(null);
      });
    });
    req.setTimeout(20000, () => req.destroy(new Error('timeout')));
    req.on('error', error => { console.error('Responde: commerce/bot/' + caminho + ' ' + error.message); resolve(null); });
    req.end(data);
  });
}

const OCUPADO = {
  es: ['Ese horario se acaba de ocupar, lo siento. ¿Te sirve alguno de estos?', 'Ese horario se acaba de ocupar, lo siento. Alguien del equipo te escribe para confirmar otro.'],
  pt: ['Esse horário acabou de ser ocupado, desculpe. Algum destes serve para você?', 'Esse horário acabou de ser ocupado, desculpe. Alguém da equipe vai te escrever para confirmar outro.'],
  en: ['Sorry, that time was just taken. Would one of these work for you?', 'Sorry, that time was just taken. Someone from the team will write to you to confirm another one.'],
};

// Uma pessoa pode ter assumido enquanto o LLM escrevia (automação, ou alguém
// na tela): o Guard só viu a conversa quando a mensagem chegou. Visto em
// 03/10: a automação atribuiu ao Paulo e o bot respondeu 6 s depois.
const conversa = await getJson('https://prs.cortexgen.cloud/api/v1/accounts/' + i.accountId + '/conversations/' + i.conversationId);
if ((conversa.meta || {}).assignee_type === 'User') return [{ json: i }];

// O horario marcado neste turno, no MontaPrompt ou pela etiqueta: o link da
// reuniao vai logo depois da confirmacao (mandarLinkDaReuniao).
let marcadoAgora = $('MontaPrompt').first().json.booked;
if (marcado) {
  const resultado = await agendar(marcado[1].trim());
  if (resultado.ok) marcadoAgora = marcado[1].trim();
  else {
    const idioma = ($('JevEntrada').first().json.jev || {}).language;
    const frases = OCUPADO[idioma] || OCUPADO.en;
    const opcoes = (resultado.conflict.alternatives || []).map(slot => '• ' + new Intl.DateTimeFormat(idioma || 'en', {
      weekday: 'long', day: 'numeric', month: 'long', hour: '2-digit', minute: '2-digit', timeZone: resultado.conflict.time_zone,
    }).format(new Date(slot)));
    texto = opcoes.length ? frases[0] + '\n\n' + opcoes.join('\n') : frases[1];
  }
}

const reply = doOpenwa ? paraWhatsapp(texto) : texto;
const atraso = texto => Math.min(Math.max(900 + 22 * texto.length, 1200), 7500);
const espera = ms => new Promise(resolve => setTimeout(resolve, ms));

function postar(path, body) {
  return new Promise((resolve, reject) => {
    const data = JSON.stringify(body);
    const req = https.request('https://prs.cortexgen.cloud/api/v1/accounts/' + i.accountId + '/conversations/' + i.conversationId + path, {
      method: 'POST',
      headers: { 'content-type': 'application/json', 'content-length': Buffer.byteLength(data), api_access_token: g.botAccessToken },
    }, res => {
      let raw = '';
      res.on('data', chunk => { raw += chunk; });
      res.on('end', () => (res.statusCode >= 200 && res.statusCode < 300
        ? resolve()
        : reject(new Error('Responde: ' + path + ' no Chatwoot: HTTP ' + res.statusCode + ' ' + raw.slice(0, 200)))));
    });
    req.setTimeout(20000, () => req.destroy(new Error('Responde: ' + path + ' no Chatwoot: timeout')));
    req.on('error', reject);
    req.end(data);
  });
}

// Paragrafos, sem partir bloco de codigo nem lista: item de lista cola no item
// anterior, e o que vem depois de uma frase terminada em ":" cola nela.
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

function getJson(url) {
  return new Promise((resolve, reject) => {
    const req = https.get(url, { headers: { api_access_token: g.chatUserToken } }, res => {
      let raw = '';
      res.on('data', chunk => { raw += chunk; });
      res.on('end', () => (res.statusCode >= 200 && res.statusCode < 300
        ? resolve(JSON.parse(raw))
        : reject(new Error('Responde: ' + url + ' HTTP ' + res.statusCode + ' ' + raw.slice(0, 200)))));
    });
    req.setTimeout(20000, () => req.destroy(new Error('Responde: ' + url + ' timeout')));
    req.on('error', reject);
  });
}

// O Meet nasce no GooglePushJob, segundos depois da marcacao, entao a IA nao
// tem o link quando escreve. Depois da confirmacao ele ja existe; se o job
// ainda nao rodou (google_synced_at vazio), espera uma vez. Tipo sem Meet nao
// manda nada, e o lembrete leva o link de qualquer jeito.
const LINK = { es: 'Enlace de la reunión:', pt: 'Link da reunião:', en: 'Meeting link:' };
const ASSINATURA = { es: 'Suscríbete aquí:', pt: 'Assine aqui:', en: 'Subscribe here:' };
async function mandarBolhaFinal(texto) {
  if (g.splitReplies) {
    await postar('/toggle_typing_status', { typing_status: 'on' });
    await espera(atraso(texto));
  }
  await postar('/messages', { content: texto, message_type: 'outgoing' });
}
async function mandarLinkDaReuniao() {
  const alvo = Math.floor(new Date(marcadoAgora).getTime() / 1000);
  const url = 'https://prs.cortexgen.cloud/api/v1/accounts/' + i.accountId + '/agenda/appointments?contact_id=' + g.contactId;
  const buscar = async () => ((await getJson(url)).payload || []).find(a => a.starts_at === alvo);
  let compromisso = await buscar();
  if (compromisso && !compromisso.google_synced_at) {
    await espera(3000);
    compromisso = await buscar();
  }
  if (!compromisso || !compromisso.meeting_url) return;
  const idioma = ($('JevEntrada').first().json.jev || {}).language;
  await mandarBolhaFinal((LINK[idioma] || LINK.en) + ' ' + compromisso.meeting_url);
}

if (!g.splitReplies) {
  await postar('/messages', { content: reply, message_type: 'outgoing' });
} else {
  for (const bolha of bolhas(reply)) {
    await postar('/toggle_typing_status', { typing_status: 'on' });
    await espera(atraso(bolha));
    await postar('/messages', { content: bolha, message_type: 'outgoing' });
  }
}
if (marcadoAgora) await mandarLinkDaReuniao();
const idiomaDoCliente = ($('JevEntrada').first().json.jev || {}).language;
if (linhasDaCotacao.length) await chamarComercial('quotes', { lines: linhasDaCotacao, language: idiomaDoCliente });
if (assinar) {
  const assinatura = await chamarComercial('subscriptions', { item_id: Number(assinar[1]), language: idiomaDoCliente });
  if (assinatura) await mandarBolhaFinal((ASSINATURA[idiomaDoCliente] || ASSINATURA.en) + ' ' + assinatura.public_url);
}
return [{ json: i }];
