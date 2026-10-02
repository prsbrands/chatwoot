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
const marcado = String(i.reply || '').match(ETIQUETA);
let texto = String(i.reply || '').replace(new RegExp(ETIQUETA.source, 'g'), '\n').trim();

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

const OCUPADO = {
  es: ['Ese horario se acaba de ocupar, lo siento. ¿Te sirve alguno de estos?', 'Ese horario se acaba de ocupar, lo siento. Alguien del equipo te escribe para confirmar otro.'],
  pt: ['Esse horário acabou de ser ocupado, desculpe. Algum destes serve para você?', 'Esse horário acabou de ser ocupado, desculpe. Alguém da equipe vai te escrever para confirmar outro.'],
  en: ['Sorry, that time was just taken. Would one of these work for you?', 'Sorry, that time was just taken. Someone from the team will write to you to confirm another one.'],
};

if (marcado) {
  const resultado = await agendar(marcado[1].trim());
  if (!resultado.ok) {
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

if (!g.splitReplies) {
  await postar('/messages', { content: reply, message_type: 'outgoing' });
  return [{ json: i }];
}

for (const bolha of bolhas(reply)) {
  await postar('/toggle_typing_status', { typing_status: 'on' });
  await espera(atraso(bolha));
  await postar('/messages', { content: bolha, message_type: 'outgoing' });
}
return [{ json: i }];
