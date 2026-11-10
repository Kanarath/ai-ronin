# Imagen del servicio. Etiqueta comprobada en Docker Hub el 2026-11-10.
# Se construye desde forja/labs (ver compose.yaml) porque reutiliza los documentos de A2-04.
FROM python:3.13-slim

# No ejecutar como root dentro del contenedor (A6: «contenedor root»).
RUN useradd --create-home --uid 10001 forja
WORKDIR /app/A2-05_multimodal

COPY A2-05_multimodal/requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY A2-04_rag/documentos.json /app/A2-04_rag/documentos.json
COPY A2-05_multimodal/multimodal.py A2-05_multimodal/ataques.json ./
COPY A2-05_multimodal/fuentes ./fuentes
USER forja

# Dentro del contenedor escucha en 0.0.0.0; hacia fuera, compose.yaml solo publica en 127.0.0.1.
EXPOSE 8000
CMD ["uvicorn", "multimodal:app", "--host", "0.0.0.0", "--port", "8000"]
