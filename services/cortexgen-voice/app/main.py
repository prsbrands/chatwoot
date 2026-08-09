"""cortexgen-voice — o lado de mídia do agente de voz.

O Chatwoot decide que uma chamada é do bot e devolve ao Twilio um
`<Connect><Stream>` apontando para cá. A partir daí o áudio dos dois lados passa
por este processo, e o Chatwoot volta a entrar em cena só no fim da chamada.
"""

from fastapi import FastAPI, WebSocket
from loguru import logger
from pipecat.runner.utils import parse_telephony_websocket

from .bot import run_call
from .chatwoot import ConfigError, fetch_call_config

app = FastAPI(title="cortexgen-voice")


@app.get("/health")
async def health() -> dict:
    return {"status": "ok"}


@app.websocket("/voice-stream")
async def voice_stream(websocket: WebSocket) -> None:
    await websocket.accept()

    # O primeiro par de mensagens do Twilio traz o stream, a chamada e os
    # `<Parameter>` que o Chatwoot embutiu no TwiML.
    transport_type, call_data = await parse_telephony_websocket(websocket)
    if transport_type != "twilio":
        logger.error(f"refusing a '{transport_type}' stream — this endpoint is Twilio's")
        await websocket.close()
        return

    custom = call_data.get("body", {}) or {}
    phone_number = custom.get("phone_number")
    if not phone_number:
        logger.error("stream arrived without a phone_number parameter — check the TwiML")
        await websocket.close()
        return

    try:
        config = await fetch_call_config(phone_number)
    except ConfigError:
        await websocket.close()
        return

    try:
        await run_call(
            websocket=websocket,
            stream_id=call_data["stream_id"],
            call_id=call_data["call_id"],
            config=config,
        )
    except ConfigError as error:
        logger.error(f"call on {phone_number} could not run: {error}")
        await websocket.close()
