FROM python:3.12-slim

WORKDIR /srv

# O Silero roda local e vem como modelo ONNX dentro do pacote; nada é baixado em
# tempo de chamada.
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY app ./app
# Vai junto de propósito: o teste roda contra a imagem construída, que é onde as
# versões são as de verdade.
COPY smoke.py .

EXPOSE 8080

CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8080"]
