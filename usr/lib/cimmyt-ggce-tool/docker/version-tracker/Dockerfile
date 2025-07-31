FROM python:3.12-slim-bookworm


WORKDIR /app


COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt


COPY version_ggce.py .

CMD ["python", "version_ggce.py"]
