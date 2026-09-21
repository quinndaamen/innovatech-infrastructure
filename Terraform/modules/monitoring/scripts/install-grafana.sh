#!/bin/bash

set -euo pipefail

echo "Installing Grafana..."

# Create Grafana user
if ! id grafana >/dev/null 2>&1; then
    useradd --system --no-create-home --shell /sbin/nologin grafana
fi

# Create directories
mkdir -p /etc/grafana
mkdir -p /var/lib/grafana
mkdir -p /var/log/grafana

# Download Grafana archive from private S3 endpoint
cd /tmp

aws s3 cp \
  "s3://${prometheus_bucket}/${grafana_key}" \
  grafana.tar.gz

# Extract Grafana
mkdir -p /opt/grafana
tar -xzf grafana.tar.gz -C /opt/grafana --strip-components=1

# Remove archive to free disk space
rm -f grafana.tar.gz

cd /opt/grafana

# Find the Grafana binary

chmod +x /opt/grafana/bin/grafana

# Create basic configuration
cat > /etc/grafana/grafana.ini <<'GRAFANA_CONFIG'
[server]
http_addr = 0.0.0.0
http_port = 3000

[security]
admin_user = admin

[database]
type = sqlite3
path = /var/lib/grafana/grafana.db
GRAFANA_CONFIG

# Set permissions
chown -R grafana:grafana /opt/grafana
chown -R grafana:grafana /etc/grafana
chown -R grafana:grafana /var/lib/grafana
chown -R grafana:grafana /var/log/grafana

# Create systemd service
cat > /etc/systemd/system/grafana.service <<'SERVICE'
[Unit]
Description=Grafana Monitoring Dashboard
Wants=network-online.target
After=network-online.target prometheus.service

[Service]
User=grafana
Group=grafana
Type=simple

ExecStart=/opt/grafana/bin/grafana server \
  --config=/etc/grafana/grafana.ini \
  --homepath=/opt/grafana

Restart=on-failure

[Install]
WantedBy=multi-user.target
SERVICE

# Start Grafana
systemctl daemon-reload
systemctl enable grafana
systemctl start grafana

echo "Grafana installation completed."