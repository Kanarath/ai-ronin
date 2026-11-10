# Imagen del servicio. Etiqueta comprobada en Docker Hub el 2026-11-10.
# Se construye desde forja/labs (ver compose.yaml) porque reutiliza los documentos de A2-04.
FROM python:3.13-slim

# No ejecutar como root dentro del contenedor (A6: «contenedor root»).
RUN useradd --create-home --uid 10001 forja
WORKDIR /app/A2-06_reranking

COPY A2-06_reranking/requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY A2-04_rag/documentos.json /app/A2-04_rag/documentos.json
COPY A2-06_reranking/reranking.py A2-06_reranking/corpus.json A2-06_reranking/ataques.json ./
# El volumen hereda el dueño de esta carpeta: si no existiera, sería de root y forja no podría escribir.
RUN mkdir -p /home/forja/.cache/huggingface && chown -R forja:forja /home/forja/.cache
USER forja
# La caché de Hugging Face (el cross-encoder, unos 135 MB) va a un volumen: se descarga una vez.
ENV HF_HOME=/home/forja/.cache/huggingface

EXPOSE 8000
CMD ["uvicorn", "reranking:app", "--host", "0.0.0.0", "--port", "8000"]
