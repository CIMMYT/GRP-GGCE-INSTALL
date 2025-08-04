FROM python:3.12-slim-bookworm

LABEL maintainer="Juan Carlos Moreno Sanchez <j.m.sanchez@cgiar.org, j.m.sanchez@cimmyt.org>"

WORKDIR /app


COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt


COPY version_ggce.py .

CMD ["python", "version_ggce.py"]
