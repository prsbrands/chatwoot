import TwilioAPI from 'dashboard/api/integrations/twilio';
import BotlayerAPI from 'dashboard/api/integrations/botlayer';

// Nem as rotas nem as personas mudam entre conversas, e o botão de ligar
// precisa saber que existe rota antes de aparecer. O cache vive aqui, no
// módulo, porque o topo de um `<script setup>` roda por instância: dentro do
// componente seriam dois requests a cada conversa aberta.
let routesRequest = null;
let personasRequest = null;

/**
 * Números já roteados para o bot. Só eles podem discar: a chamada de saída
 * reaproveita a rota para achar a conta, a credencial do Twilio e o resto da
 * configuração. Conta sem a integração devolve 403 e a lista vem vazia.
 * @returns {Promise<Array>} rotas habilitadas com persona
 */
export const loadBotRoutes = () => {
  routesRequest ??= TwilioAPI.voiceRoutes()
    .then(({ data }) =>
      data.routes.filter(route => route.enabled && route.bot_persona_slug)
    )
    .catch(() => []);
  return routesRequest;
};

/**
 * Personas com as três pontas de voz configuradas — uma persona de texto aqui
 * daria uma chamada muda. A camada de bots pode estar desligada na conta: sem
 * ela ainda dá para ligar, vale a persona da rota.
 * @returns {Promise<Array>} personas de voz ativas
 */
export const loadVoicePersonas = () => {
  personasRequest ??= BotlayerAPI.personas()
    .then(({ data }) =>
      data.personas.filter(
        persona =>
          persona.is_active &&
          persona.stt_provider &&
          persona.tts_provider &&
          persona.tts_voice_id
      )
    )
    .catch(() => []);
  return personasRequest;
};
