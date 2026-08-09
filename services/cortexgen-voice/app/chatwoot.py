"""Onde a chamada busca quem ela é."""

import httpx
from loguru import logger

from .settings import settings


class ConfigError(Exception):
    """A chamada não pode ser conduzida — falta rota, persona ou chave."""


async def fetch_call_config(phone_number: str) -> dict:
    """Persona, prompt já composto e credenciais dos três provedores.

    Uma leitura por chamada. O Chatwoot resolve tudo e responde 422 com o que
    falta quando a configuração está incompleta, em vez de devolver meia
    configuração que só quebraria no meio da conversa.
    """
    url = f"{settings.chatwoot_url}/voice_agent/config"
    async with httpx.AsyncClient(timeout=settings.config_timeout) as client:
        response = await client.get(
            url,
            params={"phone_number": phone_number},
            headers={"Authorization": f"Bearer {settings.service_token}"},
        )

    if response.status_code == 200:
        return response.json()

    detail = _error_of(response)
    logger.error(f"config for {phone_number} failed ({response.status_code}): {detail}")
    raise ConfigError(detail)


async def report_call(payload: dict) -> None:
    """Entrega a chamada terminada ao Chatwoot: quem ligou, o que foi dito, quanto durou.

    É o que faz a ligação virar conversa e contato em vez de ficar só no log
    daqui.
    """
    url = f"{settings.chatwoot_url}/voice_agent/calls"
    async with httpx.AsyncClient(timeout=settings.config_timeout) as client:
        response = await client.post(
            url,
            json=payload,
            headers={"Authorization": f"Bearer {settings.service_token}"},
        )

    if response.status_code in (200, 201):
        logger.info(f"call {payload['call_sid']} filed as {response.json()}")
    else:
        logger.error(f"call {payload['call_sid']} not filed ({response.status_code}): {_error_of(response)}")


def _error_of(response: httpx.Response) -> str:
    try:
        return response.json().get("error", response.text)
    except ValueError:
        return response.text
