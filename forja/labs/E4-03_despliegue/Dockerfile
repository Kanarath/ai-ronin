# La puerta de despliegue como contenedor: evalúa la política y no expone nada.
# Se construye desde forja/labs (compose.yaml: context ..). Etiqueta comprobada en Docker Hub el 2026-11-10.
FROM python:3.13-slim

RUN useradd --create-home --uid 10001 forja
WORKDIR /app

COPY E4-03_despliegue/requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY P0-01_servicio_llm/servicio.py E4-03_despliegue/politica.py E4-03_despliegue/bateria.py E4-03_despliegue/ataques.json ./
USER forja

CMD ["python", "bateria.py", "--sin-canary"]
