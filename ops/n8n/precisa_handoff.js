// No PrecisaHandoff do workflow do bot (depois do Log): a resposta ja saiu e
// a Passagem resume a conversa com ela.
//   - keyword, max_turns ou content_filter (Interpreta);
//   - caso aberto pela IA de um tipo que passa a conversa (MontaPrompt,
//     ai_mode handoff): a resposta deu o numero ao cliente e a equipe assume.
const i = $('Interpreta').first().json;
if (i.handoff) return [{ json: { passagem: { motivo: i.handoffReason, fonte: 'regra', respostaEnviada: i.reply } } }];
const caso = $('MontaPrompt').first().json.caseHandoff;
if (caso) return [{ json: { passagem: { motivo: 'case', fonte: 'jev', detalhe: caso, respostaEnviada: i.reply } } }];
return [];
