#!/bin/bash
set -euo pipefail

ELASTIC_VERSION="__ELASTIC_VERSION__"
ELASTIC_BUCKET="__ELASTIC_BUCKET__"
AWS_REGION="__AWS_REGION__"
ELASTICSEARCH_PRIVATE_IP="__ELASTICSEARCH_PRIVATE_IP__"

INSTALL_DIR="/opt/elastic"
ARCHIVE="${INSTALL_DIR}/logstash.tar.gz"
EXTRACTED_DIR="${INSTALL_DIR}/logstash-${ELASTIC_VERSION}"
CONFIG_DIR="${EXTRACTED_DIR}/config"
PIPELINE_DIR="/etc/logstash/conf.d"
LOG_DIR="/var/log/logstash"
DATA_DIR="/var/lib/logstash"
SERVICE_FILE="/etc/systemd/system/logstash.service"

echo "Starting Logstash ${ELASTIC_VERSION} installation"

# Install required utilities
dnf install -y awscli

# Prepare installation directory
mkdir -p "${INSTALL_DIR}"

# Download the Logstash archive from S3
if [ ! -s "${ARCHIVE}" ]; then
    aws s3 cp \
        "s3://${ELASTIC_BUCKET}/logstash/logstash-${ELASTIC_VERSION}-linux-x86_64.tar.gz" \
        "${ARCHIVE}" \
        --region "${AWS_REGION}"
fi

# Extract Logstash if it is not already installed
if [ ! -x "${EXTRACTED_DIR}/bin/logstash" ]; then
    tar -xzf "${ARCHIVE}" -C "${INSTALL_DIR}"
fi

# Verify installation
if [ ! -x "${EXTRACTED_DIR}/bin/logstash" ]; then
    echo "ERROR: Logstash executable was not found."
    exit 1
fi

# Create service account
if ! id logstash >/dev/null 2>&1; then
    useradd --system \
        --home-dir "${DATA_DIR}" \
        --shell /sbin/nologin \
        logstash
fi

# Create required directories
mkdir -p "${PIPELINE_DIR}" "${LOG_DIR}" "${DATA_DIR}"

# Configure Logstash pipeline
cat > "${PIPELINE_DIR}/main.conf" <<EOF
input {
  beats {
    port => 5044
  }
}

output {
  elasticsearch {
    hosts => ["https://${ELASTICSEARCH_PRIVATE_IP}:9200"]
    index => "innovatech-logs-%{+YYYY.MM.dd}"
    ssl_enabled => true
    ssl_verification_mode => "none"
  }

  stdout {
    codec => rubydebug
  }
}
EOF

# Set permissions
chown -R logstash:logstash "${EXTRACTED_DIR}"
chown -R logstash:logstash "${PIPELINE_DIR}"
chown -R logstash:logstash "${LOG_DIR}" "${DATA_DIR}"

# Create systemd service
cat > "${SERVICE_FILE}" <<EOF
[Unit]
Description=Logstash
Wants=network-online.target
After=network-online.target

[Service]
Type=simple
User=logstash
Group=logstash
WorkingDirectory=${EXTRACTED_DIR}
Environment=LS_SETTINGS_DIR=${CONFIG_DIR}
ExecStart=${EXTRACTED_DIR}/bin/logstash --path.settings ${CONFIG_DIR} --path.data ${DATA_DIR} --path.logs ${LOG_DIR} -f ${PIPELINE_DIR}
Restart=on-failure
RestartSec=10
LimitNOFILE=65535
TimeoutStartSec=180

[Install]
WantedBy=multi-user.target
EOF

# Validate the pipeline configuration
"${EXTRACTED_DIR}/bin/logstash" \
    --path.settings "${CONFIG_DIR}" \
    --path.data "${DATA_DIR}" \
    --path.logs "${LOG_DIR}" \
    --config.test_and_exit \
    -f "${PIPELINE_DIR}"

# Enable and start Logstash
systemctl daemon-reload
systemctl enable logstash
systemctl restart logstash

echo "Logstash installation commands completed."
systemctl --no-pager --full status logstash || true