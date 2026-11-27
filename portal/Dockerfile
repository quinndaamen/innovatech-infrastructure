FROM python:3.12-slim
RUN useradd -u 10001 -m app
WORKDIR /srv
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt
COPY app app
USER 10001
# listens on localhost only: the oauth2-proxy sidecar is the only way in
CMD ["uvicorn", "app.main:app", "--host", "127.0.0.1", "--port", "8000"]