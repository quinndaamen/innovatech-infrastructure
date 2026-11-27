# build from the repo root:  docker buildx build -f worker/Dockerfile ... .
FROM python:3.12-slim
ARG HELM_VERSION=v3.16.3
ARG KUBECTL_VERSION=v1.31.4
RUN apt-get update && apt-get install -y --no-install-recommends curl ca-certificates && \
    curl -fsSL https://get.helm.sh/helm-${HELM_VERSION}-linux-amd64.tar.gz | tar xz -C /tmp && \
    mv /tmp/linux-amd64/helm /usr/local/bin/helm && \
    curl -fsSLo /usr/local/bin/kubectl https://dl.k8s.io/release/${KUBECTL_VERSION}/bin/linux/amd64/kubectl && \
    chmod +x /usr/local/bin/kubectl && \
    apt-get purge -y curl && rm -rf /var/lib/apt/lists/* /tmp/*
WORKDIR /srv
COPY worker/requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt
COPY worker/worker.py .
COPY k8s/desktop-chart /chart
RUN useradd -u 10001 worker
USER 10001
ENV HOME=/tmp
CMD ["python", "-u", "worker.py"]
