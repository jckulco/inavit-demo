# Imagen utilitaria: genera los datos sintéticos y los carga a HANA (hdbcli).
FROM python:3.12-slim
ENV PYTHONUNBUFFERED=1 PIP_NO_CACHE_DIR=1 PIP_DISABLE_PIP_VERSION_CHECK=1
RUN pip install hdbcli
WORKDIR /app
COPY *.py /app/
