"""Configuração do próprio serviço. Nada de credencial de cliente aqui.

As chaves de LLM, transcrição e voz chegam por chamada, vindas do Chatwoot, que
é quem as guarda por conta. Este processo só precisa saber onde perguntar e com
que segredo se identificar.
"""

import os


class Settings:
    def __init__(self) -> None:
        self.chatwoot_url = os.environ["CHATWOOT_URL"].rstrip("/")
        self.service_token = os.environ["VOICE_SERVICE_TOKEN"]
        self.config_timeout = float(os.getenv("CONFIG_TIMEOUT_SECONDS", "5"))


settings = Settings()
