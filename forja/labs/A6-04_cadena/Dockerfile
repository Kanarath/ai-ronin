# Imagen del verificador. Etiqueta comprobada en Docker Hub el 2026-11-10.
FROM python:3.13-slim

# No ejecutar como root dentro del contenedor (A6: «contenedor root»).
RUN useradd --create-home --uid 10001 forja
WORKDIR /app
ENV PYTHONDONTWRITEBYTECODE=1

# Solo biblioteca estándar: requirements.txt no instala nada.
COPY verificador.py indice.json ./
USER forja

ENTRYPOINT ["python", "verificador.py"]
CMD ["/proyecto"]
