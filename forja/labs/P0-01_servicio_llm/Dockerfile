# Imagen del servicio. Etiqueta comprobada en Docker Hub el 2026-11-10.
FROM python:3.13-slim

# No ejecutar como root dentro del contenedor (A6: «contenedor root»).
RUN useradd --create-home --uid 10001 forja
WORKDIR /app

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY servicio.py .
USER forja

# Dentro del contenedor escucha en 0.0.0.0 (si no, Docker no podría reenviarle tráfico);
# hacia fuera, compose.yaml solo publica el puerto en 127.0.0.1.
EXPOSE 8000
CMD ["uvicorn", "servicio:app", "--host", "0.0.0.0", "--port", "8000"]
