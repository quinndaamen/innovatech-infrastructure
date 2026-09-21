#!/bin/bash

set -euo pipefail

echo "Installing Prometheus..."

# Create Prometheus user
if ! id prometheus >/dev/null 2>&1; then
    useradd --no-create-home --shell /sbin/nologin prometheus
fi

# Create directories
mkdir -p /etc/prometheus
mkdir -p /var/lib/prometheus

# Download Prometheus archive from the private S3 endpoint
cd /tmp

aws s3 cp \
  "s3://${prometheus_bucket}/${prometheus_key}" \
  prometheus.tar.gz

# Extract
tar -xzf prometheus.tar.gz

cd "prometheus-${prometheus_version}.linux-amd64"

# Install binaries
install -m 0755 prometheus /usr/local/bin/prometheus
install -m 0755 promtool /usr/local/bin/promtool



# Create configuration
cat > /etc/prometheus/prometheus.yml <<'PROMETHEUS_CONFIG'
global:
  scrape_interval: 15s
  evaluation_interval: 15s

scrape_configs:
  - job_name: "prometheus"
    static_configs:
      - targets:
          - "localhost:9090"
PROMETHEUS_CONFIG

# Set permissions
chown prometheus:prometheus /usr/local/bin/prometheus
chown prometheus:prometheus /usr/local/bin/promtool
chown -R prometheus:prometheus /etc/prometheus
chown -R prometheus:prometheus /var/lib/prometheus

# Create systemd service
cat > /etc/systemd/system/prometheus.service <<'SERVICE'
[Unit]
Description=Prometheus Monitoring
Wants=network-online.target
After=network-online.target

[Service]
User=prometheus
Group=prometheus
Type=simple

ExecStart=/usr/local/bin/prometheus \
  --config.file=/etc/prometheus/prometheus.yml \
  --storage.tsdb.path=/var/lib/prometheus

Restart=on-failure

[Install]
WantedBy=multi-user.target
SERVICE

# Start Prometheus
systemctl daemon-reload
systemctl enable prometheus
systemctl start prometheus

echo "Prometheus installation completed."