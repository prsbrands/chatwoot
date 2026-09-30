// No OptOut do workflow do bot (entre Historico e JevEntrada).
//
// Pedido INEQUIVOCO de descadastro vira passagem com motivo `opt_out`, antes
// de qualquer LLM e com ou sem o Jev ligado: o no Passagem bloqueia o contato,
// etiqueta e abre a conversa. O caso ambiguo ("me deixa em paz") nao passa por
// aqui — e a atividade opt_out do Jev que o pega, e so em `deciding`.
//
// A regra e a do DeskComm (lib/opt-out/deteccao.ts no repo do CRM), que tem o
// historico de cada padrao e as frases de controle. Resumo: a palavra SOZINHA
// (a mensagem inteira e "stop", "baja"...) ou verbo de cessacao + OBJETO DE
// COMUNICACAO. Nunca a palavra no meio da frase — "tem como parar a dor?" e
// "posso sair antes das 15h?" bloqueavam paciente com a regex antiga.
//
// So em canal de mensageria: no widget e no e-mail quem escreve "cancelar"
// esta falando do pedido, e bloquear ali nao protege ninguem.

const g = $('Guard').first().json;
const rota = $('Persona').first().json;
const segue = [{ json: {} }];

if (!rota || !rota.persona_id) return segue;
if (g.channel === 'Channel::WebWidget' || g.channel === 'Channel::Email') return segue;

const normalizar = texto => String(texto || '')
  .toLowerCase()
  .normalize('NFD')
  .replace(/[̀-ͯ]/g, '');

const PALAVRAS = new Set([
  'stop', 'parar', 'pare', 'sair', 'cancelar', 'descadastrar', 'remover', 'unsubscribe',
  'baja', 'bajar', 'salir', 'desuscribir', 'desuscribirme',
]);

const VERBOS =
  'mandar|manda|mande|mandem|enviar|envia|envie|enviem|receber|recebe|escrever|escreve|' +
  'chamar|chama|ligar|liga|perturbar|perturba|encher|enche|insistir|insiste|' +
  'recibir|recibe|escribir|escribe|escriban|molestar|molesta|llamar|llama|mandes|envien|' +
  'contactar|contacta|contacte|contacten|contactes|' +
  'contate|contatem|chame|chamem|ligue|liguem|escreva|escrevam|perturbe|perturbem';
// Depois de "nao me", descrevem outra pessoa ("o convenio nao me recebe mais").
const DESCRITIVAS = 'recebe|escreve|perturba|enche|insiste|contacta';
// O objeto e outra coisa que nao a mensagem: "pare de mandar o pedido".
const OBJETOS =
  'pedido|pedidos|encomenda|encomendas|pacote|pacotes|entrega|entregas|' +
  'fatura|faturas|boleto|boletos|cobranca|cobrancas|produto|produtos|' +
  'paquete|paquetes|envio|envios|factura|facturas|boleta|boletas|' +
  'cobro|cobros|producto|productos|pauta|pautas|presupuesto|presupuestos';
const DETERMINANTES =
  'o|a|os|as|el|los|la|las|meu|minha|meus|minhas|seu|sua|seus|suas|' +
  'mi|mis|tu|tus|esse|essa|esses|essas|ese|esa|esos|esas|nesse|nessa';
const NAO_E_O_OBJETO = `(?!\\s+(?:${DETERMINANTES})?\\s*(?:${OBJETOS})\\b)`;
// "lista de espera" e paciente querendo ser chamado; so vale lista de envio.
const LISTAS = 'contatos?|transmissao|envios?|mensagens|disparos?|divulgacao|promocoes|ofertas|whatsapp|zap|voces|vcs';
const FREIO_DE_LISTA = `(?!\\s+de\\s+(?!(?:${LISTAS})\\b))`;
// "meu filho nao me liga mais" e relato, nao pedido: o sujeito de 3a pessoa
// colado antes de "nao me" isenta as quatro formas ambiguas.
const PRONOMES = 'ele|ela|eles|elas|aquele|aquela|aqueles|aquelas';
const DET_SUJEITO =
  'o|a|os|as|meu|minha|meus|minhas|seu|sua|seus|suas|esse|essa|esses|essas|' +
  'nesse|nessa|do|da|dos|das|nosso|nossa|nossos|nossas|dele|dela|deles|delas';
const NAO_ABREM_SUJEITO =
  'de|da|do|das|dos|em|no|na|nos|nas|que|para|pra|pro|ate|desde|partir|apartir|' +
  'partindo|com|por|pelo|pela|ao|aos|e|mas|ja|quando|como|se|sem|entao|apos|logo|porque|' +
  'senhor|senhora|sr|sra|deus|amor|querido|querida|moco|moca';
const SUJEITO_DE_TERCEIRA =
  '(?<=(?:^|[.!?,;:])\\s*(?:' +
  `(?:${PRONOMES})\\b\\s*(?:(?!(?:${NAO_ABREM_SUJEITO})\\b)[a-z]+\\s+){0,2}|` +
  `(?:${DET_SUJEITO})\\b\\s*(?:(?!(?:${NAO_ABREM_SUJEITO})\\b)[a-z]+\\s+){1,2}` +
  ')nao\\s+me\\s+)';

const FRASES = [
  new RegExp(`\\bpar(?:ar|a|e|em)\\s+de\\s+(?:me\\s+)?(?:${VERBOS})\\b${NAO_E_O_OBJETO}`),
  /\bnao\s+(?:quero|desejo|gostaria)\s+(?:de\s+)?(?:mais\s+)?receber\b(?!\s+(?:ligacao|ligacoes|chamada|chamadas|telefonema|telefonemas|telefone)\b)/,
  /\bnao\s+quero\s+receber\s+mais\b/,
  /\bnao\s+quero\s+mais\s+(?:mensagem|mensagens|contato|nada\s+de\s+voces)\b/,
  new RegExp(
    `\\bnao\\s+me\\s+(?!(?:${DESCRITIVAS})\\b)` +
    `(?!(?=${SUJEITO_DE_TERCEIRA})(?:manda|chama|liga|envia)\\s+mais\\b)` +
    `(?:${VERBOS})\\s+mais\\b${NAO_E_O_OBJETO}`,
  ),
  new RegExp(
    '\\b(?:nao\\s+(?:entre|entrem)\\s+(?:mais\\s+)?|nao\\s+(?:volte|voltem)\\s+a\\s+entrar\\s+|' +
    '(?:par|deix)(?:ar|a|e|em)\\s+de\\s+entrar\\s+)em\\s+contato\\b' +
    '(?!\\s+(?:com|pel[oa]|via)\\b|\\s+por\\s+(?!(?:aqui|est[ea]|ess[ea])\\b))',
  ),
  new RegExp(
    '\\bme\\s+(?:tira|tire|tirem|tirar|remove|remova|removam|remover|retira|retire|retirar|' +
    'exclui|exclua|excluir|apaga|apague|apagar)\\s+(?:da|dessa|desta|de\\s+sua|da\\s+sua)\\s+lista\\b' +
    FREIO_DE_LISTA,
  ),
  new RegExp(`\\bsair\\s+d(?:a|essa|esta)\\s+lista\\b${FREIO_DE_LISTA}`),
  /\bcancelar?\s+(?:a\s+)?(?:inscricao|assinatura)\b/,
  /\b(?:me\s+)?descadastr\w*\b/,
  /\bdescadastro\b/,
  // espanhol
  new RegExp(
    `\\bno\\s+(?:quiero|deseo)\\s+(?:mas\\s+)?(?:${VERBOS})\\b` +
    '(?!\\s+(?:la|el|los|las|mi|mis)?\\s*(?:factura|facturas|boleta|boletas|presupuesto|' +
    'presupuestos|recibo|recibos|comprobante|comprobantes|llamada|llamadas|contrato|contratos)\\b)',
  ),
  /\bno\s+quiero\s+recibir\s+mas\b/,
  /\bno\s+quiero\s+mas\s+(?:mensajes?|publicidad|promociones|nada\s+de\s+ustedes)\b/,
  /\b(?:dame|deme|denme|danos)\s+de\s+baja\b/,
  /\bno\s+quiero\s+que\s+me\s+contact(?:e|en|es)\b/,
  /\b(?:borrame|borrar|eliminame|elimina|sacame|quitame)\s+de\s+(?:tus\s+|mis\s+|la\s+)?(?:contactos|base\s+de\s+datos)\b/,
  new RegExp(
    '\\bno\\s+me\\s+(?:escriba|escriban|escribas|mande|manden|mandes|llame|llamen|contacte|contacten|contactes)\\s+mas\\b' +
    NAO_E_O_OBJETO,
  ),
  new RegExp(`\\b(?:dej(?:ar|a|e|en)|par(?:ar|a|e|en))\\s+de\\s+(?:${VERBOS})(?:me|nos|le|les)?\\b${NAO_E_O_OBJETO}`),
  /\b(?:dar|darme|doy)\s+de\s+baja\s+(?:la\s+)?(?:suscripcion|lista|publicidad|promociones)\b/,
  /\bdarme\s+de\s+baja\b/,
  /\bme\s+desuscrib\w*\b/,
  /\b(?:sacame|sacar|quitame|quitar|borrame|borrar|elimina|eliminame)\s+de\s+(?:la\s+)?lista\b(?!\s+de\s+(?:espera|precios|invitados))/,
  /\bsalir\s+de\s+(?:la\s+)?lista\b(?!\s+de\s+(?:espera|precios|invitados))/,
  /\bcancelar\s+(?:la\s+)?(?:suscripcion|inscripcion)\b/,
];

const texto = normalizar(g.content.trim());
const pediu = PALAVRAS.has(texto.replace(/[^a-z]/g, '')) || FRASES.some(re => re.test(texto));
if (!pediu) return segue;
return [{ json: { passagem: { motivo: 'opt_out', fonte: 'regra' } } }];
