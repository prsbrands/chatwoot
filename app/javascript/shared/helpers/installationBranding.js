/**
 * Troca "Chatwoot" pelo nome da instalação em toda string traduzida.
 *
 * Existe para não editar os arquivos de locale. São ~2.600 ocorrências
 * espalhadas por trinta e poucos idiomas, e eles são sincronizados pelo Crowdin
 * — qualquer edição ali volta atrás no próximo merge com o upstream. Aplicado
 * como `postTranslation` do vue-i18n, um lugar só cobre todos os idiomas e
 * sobrevive ao merge.
 *
 * O `replaceInstallationName` de `shared/composables/useBranding` faz o mesmo
 * para texto montado dentro de componente; este roda fora do contexto do Vue,
 * por isso lê o `window.globalConfig` em vez do store.
 */

/**
 * Não casa quando "chatwoot" é parte de um domínio ou de um identificador.
 *
 * - `(?<![\w/@.])` deixa de fora `app.chatwoot.com`, `github.com/chatwoot/...`
 *   e nomes como `latestChatwootVersion`, que são variáveis de interpolação —
 *   trocar dentro delas quebraria a mensagem.
 * - `(?!\.[a-z])` deixa de fora `chatwoot.com` e `chatwoot.help`.
 *
 * Medido contra os arquivos de locale: 2.062 trocas e 503 ocorrências
 * preservadas, todas elas URL, chave ou variável.
 */
const MENCAO_A_CHATWOOT = /(?<![\w/@.])chatwoot(?!\.[a-z])/gi;

export const brandTranslation = translated => {
  if (typeof translated !== 'string') return translated;

  const nome = window.globalConfig?.INSTALLATION_NAME;
  // Sem nome configurado, ou com o nome de fábrica, não há o que trocar.
  if (!nome || nome.toLowerCase() === 'chatwoot') return translated;

  return translated.replace(MENCAO_A_CHATWOOT, nome);
};
