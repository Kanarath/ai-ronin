# Imagen de los servidores MCP. Etiqueta comprobada en Docker Hub el 2026-11-10.
FROM python:3.13-slim

# No ejecutar como root dentro del contenedor (A6: «contenedor root»).
RUN useradd --create-home --uid 10001 forja
WORKDIR /app

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY servidor.py host.py ataques.json ./
COPY datos ./datos
USER forja

# Dentro del contenedor escucha en 0.0.0.0 (si no, Docker no podría reenviarle tráfico); hacia
# fuera, compose.yaml solo publica el puerto en 127.0.0.1. La protección contra DNS rebinding del
# SDK sigue activa: solo acepta cabeceras Host de localhost.
ENV ESCUCHAR_EN=0.0.0.0
EXPOSE 8765 8770
CMD ["python", "servidor.py", "almacen"]
