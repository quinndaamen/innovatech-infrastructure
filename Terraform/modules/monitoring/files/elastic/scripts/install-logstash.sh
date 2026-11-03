#!/bin/bash
set -euo pipefail

ELASTIC_VERSION="__ELASTIC_VERSION__"
ELASTIC_BUCKET="__ELASTIC_BUCKET__"
AWS_REGION="__AWS_REGION__"
ELASTICSEARCH_PRIVATE_IP="__ELASTICSEARCH_PRIVATE_IP__"
ENVIRONMENT="__ENVIRONMENT__"

INSTALL_DIR="/opt/elastic"
ARCHIVE="${INSTALL_DIR}/logstash.tar.gz"
EXTRACTED_DIR="${INSTALL_DIR}/logstash-${ELASTIC_VERSION}"
CONFIG_DIR="${EXTRACTED_DIR}/config"

PIPELINE_DIR="/etc/logstash/conf.d"
LOG_DIR="/var/log/logstash"
DATA_DIR="/var/lib/logstash"

CERT_DIR="/opt/elastic/certs"
CA_CERT="${CERT_DIR}/http_ca.crt"

ENV_DIR="/etc/logstash"
ENV_FILE="${ENV_DIR}/logstash.env"

SERVICE_FILE="/etc/systemd/system/logstash.service"

SSM_PARAMETER="/innovatech/${ENVIRONMENT}/logstash/api-key"

echo "Starting Logstash ${ELASTIC_VERSION} installation"

# --------------------------------------------------
# 1. Install required utilities
# --------------------------------------------------

dnf install -y awscli

# --------------------------------------------------
# 2. Prepare directories
# --------------------------------------------------

mkdir -p "${INSTALL_DIR}"
mkdir -p "${PIPELINE_DIR}"
mkdir -p "${LOG_DIR}"
mkdir -p "${DATA_DIR}"
mkdir -p "${CERT_DIR}"
mkdir -p "${ENV_DIR}"

# --------------------------------------------------
# 3. Download Logstash archive
# --------------------------------------------------

if [ ! -s "${ARCHIVE}" ]; then
    aws s3 cp \
        "s3://${ELASTIC_BUCKET}/logstash/logstash-${ELASTIC_VERSION}-linux-x86_64.tar.gz" \
        "${ARCHIVE}" \
        --region "${AWS_REGION}"
fi

# --------------------------------------------------
# 4. Extract Logstash
# --------------------------------------------------

if [ ! -x "${EXTRACTED_DIR}/bin/logstash" ]; then
    tar -xzf "${ARCHIVE}" -C "${INSTALL_DIR}"
fi

if [ ! -x "${EXTRACTED_DIR}/bin/logstash" ]; then
    echo "ERROR: Logstash executable was not found."
    exit 1
fi

# --------------------------------------------------
# 5. Create Logstash service account
# --------------------------------------------------

if ! id logstash >/dev/null 2>&1; then
    useradd --system \
        --home-dir "${DATA_DIR}" \
        --shell /sbin/nologin \
        logstash
fi

# --------------------------------------------------
# 6. Download Elasticsearch CA certificate
# --------------------------------------------------

echo "Downloading Elasticsearch CA certificate..."

aws s3 cp \
    "s3://${ELASTIC_BUCKET}/certs/http_ca.crt" \
    "${CA_CERT}" \
    --region "${AWS_REGION}"

if [ ! -s "${CA_CERT}" ]; then
    echo "ERROR: Elasticsearch CA certificate is missing."
    exit 1
fi

chown root:logstash "${CA_CERT}"
chmod 640 "${CA_CERT}"

echo "Verifying Elasticsearch CA certificate..."

if ! openssl x509 -in "${CA_CERT}" -noout -fingerprint -sha256; then
    echo "ERROR: Downloaded CA certificate is invalid."
    exit 1
fi

# --------------------------------------------------
# 7. Retrieve Logstash API key from SSM
# --------------------------------------------------

echo "Retrieving Logstash API key from SSM..."

LOGSTASH_API_KEY=$(aws ssm get-parameter \
    --name "${SSM_PARAMETER}" \
    --with-decryption \
    --region "${AWS_REGION}" \
    --query 'Parameter.Value' \
    --output text)

if [ -z "${LOGSTASH_API_KEY}" ] || \
   [ "${LOGSTASH_API_KEY}" = "None" ]; then
    echo "ERROR: Could not retrieve Logstash API key."
    exit 1
fi

# --------------------------------------------------
# 8. Create protected environment file
# --------------------------------------------------

umask 077

cat > "${ENV_FILE}" <<EOF
LOGSTASH_API_KEY=${LOGSTASH_API_KEY}
EOF

chown root:logstash "${ENV_FILE}"
chmod 640 "${ENV_FILE}"

unset LOGSTASH_API_KEY

# --------------------------------------------------
# 9. Configure Logstash pipeline
# --------------------------------------------------

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

    api_key => "\${LOGSTASH_API_KEY}"

    ssl_enabled => true
    ssl_certificate_authorities => ["${CA_CERT}"]
  }
}
EOF

# --------------------------------------------------
# 10. Set permissions
# --------------------------------------------------

chown -R logstash:logstash "${EXTRACTED_DIR}"
chown -R logstash:logstash "${PIPELINE_DIR}"
chown -R logstash:logstash "${LOG_DIR}" "${DATA_DIR}"

# --------------------------------------------------
# 11. Create systemd service
# --------------------------------------------------

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
EnvironmentFile=${ENV_FILE}

ExecStart=${EXTRACTED_DIR}/bin/logstash \
    --path.settings ${CONFIG_DIR} \
    --path.data ${DATA_DIR} \
    --path.logs ${LOG_DIR} \
    -f ${PIPELINE_DIR}

Restart=on-failure
RestartSec=10
LimitNOFILE=65535
TimeoutStartSec=180

[Install]
WantedBy=multi-user.target
EOF

# --------------------------------------------------
# 12. Validate pipeline configuration
# --------------------------------------------------

echo "Validating Logstash pipeline..."

LOGSTASH_API_KEY=$(aws ssm get-parameter \
    --name "${SSM_PARAMETER}" \
    --with-decryption \
    --region "${AWS_REGION}" \
    --query 'Parameter.Value' \
    --output text)

if [ -z "${LOGSTASH_API_KEY}" ] || \
   [ "${LOGSTASH_API_KEY}" = "None" ]; then
    echo "ERROR: Could not retrieve Logstash API key."
    exit 1
fi

runuser -u logstash -- env \
    LOGSTASH_API_KEY="${LOGSTASH_API_KEY}" \
    "${EXTRACTED_DIR}/bin/logstash" \
    --path.settings "${CONFIG_DIR}" \
    --path.data "${DATA_DIR}" \
    --path.logs "${LOG_DIR}" \
    --config.test_and_exit \
    -f "${PIPELINE_DIR}"

unset LOGSTASH_API_KEY

# --------------------------------------------------
# 13. Enable and start Logstash
# --------------------------------------------------

echo "Starting Logstash service..."

systemctl daemon-reload
systemctl enable logstash
systemctl restart logstash

# --------------------------------------------------
# 14. Display service status
# --------------------------------------------------

echo "Logstash installation commands completed."

systemctl --no-pager --full status logstash || true