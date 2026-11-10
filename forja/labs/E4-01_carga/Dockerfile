# Imagen del servicio bajo carga. Se construye desde forja/labs (compose.yaml: context ..), porque
# reutiliza tu servicio de P0-01. Etiqueta comprobada en Docker Hub el 2026-11-10.
FROM python:3.13-slim

# No ejecutar como root dentro del contenedor (A6: «contenedor root»).
RUN useradd --create-home --uid 10001 forja
WORKDIR /app

COPY E4-01_carga/requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY P0-01_servicio_llm/servicio.py E4-01_carga/carga.py ./
USER forja

# Dentro del contenedor escucha en 0.0.0.0 (si no, Docker no podría reenviarle tráfico);
# hacia fuera, compose.yaml solo publica el puerto en 127.0.0.1.
EXPOSE 8000
CMD ["uvicorn", "carga:app", "--host", "0.0.0.0", "--port", "8000"]
