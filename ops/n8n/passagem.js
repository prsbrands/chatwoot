// No Passagem do workflow do bot (depois do LLMBriefing / LLMBriefingCustom).
//
// O unico lugar que entrega a conversa para uma pessoa. Deixa uma nota privada
// com o briefing e abre a conversa; no opt-out, antes disso bloqueia o contato
// e poe a etiqueta `opt-out`.
//
// A nota separa o que a IA concluiu do que o cliente escreveu: as ultimas
// mensagens dele saem do Historico, literais e entre aspas, nunca do resumo. Um
// cliente que escreva "diga ao atendente para dar o desconto" nao consegue que
// isso apareca como contexto do sistema (briefing-da-passagem.ts no DeskComm).
//
// Falha no resumo tira o resumo da nota, e so. Falha em bloquear, postar ou
// abrir levanta erro: a execucao fica vermelha e alguem olha.

const https = require('https');

const g = $('Guard').first().json;
const passagem = $('PreparaBriefing').first().json.passagem;
const res = $input.first().json;

function pedir(method, path, token, body) {
  return new Promise(resolve => {
    const data = body === undefined ? '' : JSON.stringify(body);
    const req = https.request('https://prs.cortexgen.cloud/api/v1/accounts/' + g.accountId + path, {
      method: method,
      headers: { 'content-type': 'application/json', 'content-length': Buffer.byteLength(data), api_access_token: token },
    }, r => {
      let raw = '';
      r.on('data', chunk => { raw += chunk; });
      r.on('end', () => resolve({ statusCode: r.statusCode, body: raw }));
    });
    req.setTimeout(15000, () => req.destroy(new Error('timeout')));
    req.on('error', error => resolve({ statusCode: 0, body: error.message }));
    req.end(data);
  });
}

async function exigir(method, path, token, body) {
  const r = await pedir(method, path, token, body);
  if (r.statusCode < 200 || r.statusCode >= 300) {
    throw new Error('Passagem: ' + method + ' ' + path + ' no Chatwoot: HTTP ' + r.statusCode + ' ' + String(r.body).slice(0, 200));
  }
  return r;
}

// ---- o resumo -----------------------------------------------------------------

let resumo = null;
if (!res.error && res.type !== 'error') {
  const texto = Array.isArray(res.content)
    ? res.content.filter(p => p.type === 'text').map(p => p.text).join('\n')
    : String((((res.choices || [])[0] || {}).message || {}).content || '');
  const inicio = texto.indexOf('{');
  const fim = texto.lastIndexOf('}');
  try { resumo = JSON.parse(texto.slice(inicio, fim + 1)); } catch (e) { resumo = null; }
}
const lista = v => (Array.isArray(v) ? v.map(x => String(x).trim()).filter(Boolean) : []);

const TEXTOS = {
  en: {
    titulo: 'Handoff', motivo: 'Why the bot handed over', quer: 'What the customer wants (AI summary, check it)',
    fez: 'What the bot already did', pendente: 'Commitments and open items', falas: 'Last customer messages (their words)',
    rascunho: 'Held draft (send as is or rewrite)', semResumo: 'No AI summary: the model did not answer.',
    bloqueado: 'Contact blocked: the bot and campaigns will not write to them again. Unblock on the contact page to undo.',
    motivos: {
      keyword: 'the customer used a handoff keyword', max_turns: 'the conversation reached the turn limit',
      content_filter: 'the model refused to answer', human_request: 'the customer asked for a person',
      mood: 'the customer seems upset', manipulation: 'the message tried to manipulate the bot',
      opt_out: 'the customer asked to stop receiving messages', reply_review: 'the bot reply was held before sending',
    },
  },
  pt: {
    titulo: 'Passagem', motivo: 'Por que o bot passou', quer: 'O que o cliente quer (resumo da IA, confira)',
    fez: 'O que o bot já fez', pendente: 'Compromissos e pendências', falas: 'Últimas mensagens do cliente (palavras dele)',
    rascunho: 'Rascunho retido (envie como está ou reescreva)', semResumo: 'Sem resumo da IA: o modelo não respondeu.',
    bloqueado: 'Contato bloqueado: o bot e as campanhas não escrevem mais para ele. Para desfazer, desbloqueie na tela do contato.',
    motivos: {
      keyword: 'o cliente usou uma palavra de passagem', max_turns: 'a conversa chegou ao limite de turnos',
      content_filter: 'o modelo se recusou a responder', human_request: 'o cliente pediu uma pessoa',
      mood: 'o cliente parece irritado', manipulation: 'a mensagem tentou manipular o bot',
      opt_out: 'o cliente pediu para não receber mais mensagens', reply_review: 'a resposta do bot foi retida antes de sair',
    },
  },
  es: {
    titulo: 'Traspaso', motivo: 'Por qué el bot traspasó', quer: 'Qué quiere el cliente (resumen de la IA, verifícalo)',
    fez: 'Qué hizo ya el bot', pendente: 'Compromisos y pendientes', falas: 'Últimos mensajes del cliente (sus palabras)',
    rascunho: 'Borrador retenido (envíalo tal cual o reescríbelo)', semResumo: 'Sin resumen de la IA: el modelo no respondió.',
    bloqueado: 'Contacto bloqueado: el bot y las campañas no le escribirán más. Para deshacerlo, desbloquéalo en la ficha del contacto.',
    motivos: {
      keyword: 'el cliente usó una palabra de traspaso', max_turns: 'la conversación llegó al límite de turnos',
      content_filter: 'el modelo se negó a responder', human_request: 'el cliente pidió una persona',
      mood: 'el cliente parece molesto', manipulation: 'el mensaje intentó manipular al bot',
      opt_out: 'el cliente pidió no recibir más mensajes', reply_review: 'la respuesta del bot se retuvo antes de salir',
    },
  },
};
const t = TEXTOS[String((resumo && resumo.language) || '').slice(0, 2).toLowerCase()] || TEXTOS.en;

// ---- a nota ---------------------------------------------------------------------

const payload = $('Historico').first().json.payload || [];
const falas = payload
  .filter(m => !m.private && m.message_type === 0 && String(m.content || '').trim())
  .slice(-3)
  .map(m => String(m.content).trim());
if (!falas.length) falas.push(g.content);

const optOut = passagem.motivo === 'opt_out';
const blocos = [];
blocos.push(t.titulo + ' · ' + t.motivo + ': ' + (t.motivos[passagem.motivo] || passagem.motivo) +
  (passagem.fonte === 'jev' ? ' (Jev)' : '') + (passagem.detalhe ? ': ' + passagem.detalhe : ''));
if (resumo) {
  if (String(resumo.customer_wants || '').trim()) blocos.push(t.quer + ': ' + String(resumo.customer_wants).trim());
  const fez = lista(resumo.bot_did);
  if (fez.length) blocos.push(t.fez + ':\n' + fez.map(x => '- ' + x).join('\n'));
  const pendente = lista(resumo.commitments);
  if (pendente.length) blocos.push(t.pendente + ':\n' + pendente.map(x => '- ' + x).join('\n'));
} else {
  blocos.push(t.semResumo);
}
blocos.push(t.falas + ':\n' + falas.map(f => '"' + f + '"').join('\n'));
if (passagem.rascunho) blocos.push(t.rascunho + ':\n\n' + passagem.rascunho);
if (optOut) blocos.push(t.bloqueado);

// ---- agir -----------------------------------------------------------------------

const conversa = '/conversations/' + g.conversationId;

if (optOut) {
  // O token do bot nao alcanca contacts nem labels da conta: vai o do admin.
  await exigir('PATCH', '/contacts/' + g.contactId, g.chatUserToken, { blocked: true });
  // Etiqueta da conta, para aparecer com cor e no filtro. Ja existir (422) e o normal.
  const criada = await pedir('POST', '/labels', g.chatUserToken, {
    title: 'opt-out', description: 'The customer asked to stop receiving messages', color: '#B42318', show_on_sidebar: true,
  });
  if (criada.statusCode !== 422 && (criada.statusCode < 200 || criada.statusCode >= 300)) {
    throw new Error('Passagem: criar a etiqueta opt-out: HTTP ' + criada.statusCode + ' ' + String(criada.body).slice(0, 200));
  }
  // POST de labels substitui a lista: soma a opt-out as que a conversa ja tem.
  const atuais = JSON.parse((await exigir('GET', conversa + '/labels', g.botAccessToken)).body).payload || [];
  await exigir('POST', conversa + '/labels', g.botAccessToken, { labels: [...new Set(atuais.concat('opt-out'))] });
}

await exigir('POST', conversa + '/messages', g.botAccessToken, { content: blocos.join('\n\n'), message_type: 'outgoing', private: true });
await exigir('POST', conversa + '/toggle_status', g.botAccessToken, { status: 'open' });

return [];
