const g = $('Guard').first().json;
const ctx = $('MontaPrompt').first().json;
const res = $input.first().json;

// Erro do provedor: OpenRouter devolve {error} com HTTP 200; com onError
// "continue" dos nós HTTP, falhas de rede/4xx/5xx também chegam como {error}.
if (res.error || res.type === 'error') {
  const err = res.error || res;
  throw new Error('LLM: ' + (err.message || JSON.stringify(err)));
}

// Detecta o formato pela resposta (o fallback pode ter estilo diferente do primário).
const isAnthropic = Array.isArray(res.content) && res.type === 'message';
let reply = '';
let finishReason = null;
let tokensIn = 0;
let tokensOut = 0;
const usage = res.usage || {};

if (isAnthropic) {
  reply = res.content.filter(p => p.type === 'text').map(p => p.text).join('\n').trim();
  finishReason = res.stop_reason;
  tokensIn = usage.input_tokens || 0;
  tokensOut = usage.output_tokens || 0;
} else {
  const choice = (res.choices || [])[0] || {};
  reply = String((choice.message || {}).content || '').trim();
  finishReason = choice.finish_reason;
  tokensIn = usage.prompt_tokens || 0;
  tokensOut = usage.completion_tokens || 0;
}
if (!reply) return [];

// Handoff determinístico: palavra-chave do cliente, limite de turnos ou
// bloqueio por filtro de conteúdo do provedor.
const rules = ctx.handoffRules || {};
const texto = String(g.content || '').toLowerCase();
const porPalavra = (rules.keywords || []).some(k => texto.includes(String(k).toLowerCase()));
const porTurnos = rules.max_turns ? ctx.turns >= Number(rules.max_turns) : false;
const porFiltro = finishReason === 'content_filter' || finishReason === 'refusal';
const handoff = porPalavra || porTurnos || porFiltro;

return [{ json: {
  reply: reply,
  handoff: handoff,
  handoffReason: porPalavra ? 'keyword' : (porTurnos ? 'max_turns' : (porFiltro ? 'content_filter' : null)),
  truncada: finishReason === 'length' || finishReason === 'max_tokens',
  personaId: ctx.personaId,
  provider: ctx.provider,
  model: res.model || null,
  tokensIn: tokensIn,
  tokensOut: tokensOut,
  latencyMs: Date.now() - Number(g.startedAt || Date.now()),
  accountId: g.accountId,
  conversationId: g.conversationId,
  messageId: g.messageId,
} }];