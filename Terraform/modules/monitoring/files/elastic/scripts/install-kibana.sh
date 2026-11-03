#!/bin/bash
set -euo pipefail

# ============================================================
# CONFIGURATION
# ============================================================

ELASTIC_VERSION="__ELASTIC_VERSION__"
ELASTIC_BUCKET="__ELASTIC_BUCKET__"
AWS_REGION="__AWS_REGION__"

KIBANA_PRIVATE_IP="__KIBANA_PRIVATE_IP__"
ELASTICSEARCH_PRIVATE_IP="__ELASTICSEARCH_PRIVATE_IP__"

INSTALL_DIR="/opt/elastic"
ARCHIVE="${INSTALL_DIR}/kibana.tar.gz"
EXTRACTED_DIR="${INSTALL_DIR}/kibana-${ELASTIC_VERSION}"
CONFIG_DIR="${EXTRACTED_DIR}/config"

LOG_DIR="/var/log/kibana"
HOME_DIR="/var/lib/kibana"

CERT_DIR="/opt/elastic/certs"
CA_CERT="${CERT_DIR}/http_ca.crt"

SERVICE_FILE="/etc/systemd/system/kibana.service"

ENV_DIR="/etc/kibana"
ENV_FILE="${ENV_DIR}/kibana.env"

ENVIRONMENT="__ENVIRONMENT__"

SSM_PARAMETER="/innovatech/${ENVIRONMENT}/kibana/service-account-token"

echo "Starting Kibana ${ELASTIC_VERSION} installation"

# ============================================================
# INSTALL DEPENDENCIES
# ============================================================

dnf install -y awscli openssl python3

# ============================================================
# CREATE DIRECTORIES
# ============================================================

mkdir -p "${INSTALL_DIR}"
mkdir -p "${CERT_DIR}"
mkdir -p "${LOG_DIR}"
mkdir -p "${HOME_DIR}"
mkdir -p "${ENV_DIR}"

# ============================================================
# DOWNLOAD KIBANA PACKAGE
# ============================================================

if [ ! -s "${ARCHIVE}" ]; then

    echo "Downloading Kibana package..."

    aws s3 cp \
        "s3://${ELASTIC_BUCKET}/kibana/kibana-${ELASTIC_VERSION}-linux-x86_64.tar.gz" \
        "${ARCHIVE}" \
        --region "${AWS_REGION}"

fi

# ============================================================
# EXTRACT KIBANA
# ============================================================

if [ ! -x "${EXTRACTED_DIR}/bin/kibana" ]; then

    echo "Extracting Kibana..."

    tar -xzf "${ARCHIVE}" -C "${INSTALL_DIR}"

fi

if [ ! -x "${EXTRACTED_DIR}/bin/kibana" ]; then
    echo "ERROR: Kibana executable was not found."
    exit 1
fi

if [ ! -f "${CONFIG_DIR}/kibana.yml" ]; then
    echo "ERROR: Kibana configuration file was not found."
    exit 1
fi

# ============================================================
# CREATE KIBANA USER
# ============================================================

if ! id kibana >/dev/null 2>&1; then

    useradd --system \
        --home-dir "${HOME_DIR}" \
        --shell /sbin/nologin \
        kibana

fi

# ============================================================
# DOWNLOAD ELASTICSEARCH CA CERTIFICATE
# ============================================================

echo "Downloading Elasticsearch CA certificate..."

aws s3 cp \
    "s3://${ELASTIC_BUCKET}/certs/http_ca.crt" \
    "${CA_CERT}" \
    --region "${AWS_REGION}"

chown root:kibana "${CA_CERT}"
chmod 640 "${CA_CERT}"

# ============================================================
# RETRIEVE KIBANA SERVICE ACCOUNT TOKEN
# ============================================================

echo "Retrieving Kibana service-account token from Parameter Store..."

KIBANA_SERVICE_TOKEN="$(
    aws ssm get-parameter \
        --name "${SSM_PARAMETER}" \
        --with-decryption \
        --region "${AWS_REGION}" \
        --query 'Parameter.Value' \
        --output text
)"

if [ -z "${KIBANA_SERVICE_TOKEN}" ] || \
   [ "${KIBANA_SERVICE_TOKEN}" = "None" ]; then

    echo "ERROR: Could not retrieve Kibana service-account token."
    exit 1

fi

# ============================================================
# GENERATE PERSISTENT ENCRYPTION KEYS
# ============================================================

# Preserve existing keys when the installation script runs again.

get_existing_key() {
    local key_name="$1"

    if [ -f "${ENV_FILE}" ]; then
        awk -F= -v key="${key_name}" \
            '$1 == key {
                sub(/^[^=]*=/, "")
                print
                exit
            }' "${ENV_FILE}"
    fi
}

SECURITY_KEY="$(get_existing_key KIBANA_SECURITY_ENCRYPTION_KEY)"
REPORTING_KEY="$(get_existing_key KIBANA_REPORTING_ENCRYPTION_KEY)"
SAVED_OBJECTS_KEY="$(get_existing_key KIBANA_SAVED_OBJECTS_ENCRYPTION_KEY)"

if [ -z "${SECURITY_KEY}" ]; then
    SECURITY_KEY="$(openssl rand -hex 32)"
fi

if [ -z "${REPORTING_KEY}" ]; then
    REPORTING_KEY="$(openssl rand -hex 32)"
fi

if [ -z "${SAVED_OBJECTS_KEY}" ]; then
    SAVED_OBJECTS_KEY="$(openssl rand -hex 32)"
fi

# ============================================================
# CREATE PROTECTED ENVIRONMENT FILE
# ============================================================

echo "Creating protected Kibana environment file..."

umask 077

cat > "${ENV_FILE}" <<EOF
KIBANA_SERVICE_TOKEN=${KIBANA_SERVICE_TOKEN}
KIBANA_SECURITY_ENCRYPTION_KEY=${SECURITY_KEY}
KIBANA_REPORTING_ENCRYPTION_KEY=${REPORTING_KEY}
KIBANA_SAVED_OBJECTS_ENCRYPTION_KEY=${SAVED_OBJECTS_KEY}
EOF

chown root:kibana "${ENV_FILE}"
chmod 640 "${ENV_FILE}"

# ============================================================
# CONFIGURE KIBANA
# ============================================================

echo "Restoring original Kibana configuration..."

TEMP_CONFIG="$(mktemp)"

# Extract the original configuration from the installation archive.
tar -xOf "${ARCHIVE}" \
    "kibana-${ELASTIC_VERSION}/config/kibana.yml" \
    > "${TEMP_CONFIG}"

# Replace the existing configuration with the clean original.
mv "${TEMP_CONFIG}" "${CONFIG_DIR}/kibana.yml"

echo "Generating Innovatech Kibana configuration..."

cat >> "${CONFIG_DIR}/kibana.yml" <<EOF

# ============================================================
# INNOVATECH KIBANA CONFIGURATION
# ============================================================

server.host: "${KIBANA_PRIVATE_IP}"
server.port: 5601

path.data: "${HOME_DIR}"

elasticsearch.hosts:
  - "https://${ELASTICSEARCH_PRIVATE_IP}:9200"

elasticsearch.ssl.certificateAuthorities:
  - "${CA_CERT}"

elasticsearch.serviceAccountToken: "\${KIBANA_SERVICE_TOKEN}"

xpack.security.encryptionKey: "\${KIBANA_SECURITY_ENCRYPTION_KEY}"

xpack.reporting.encryptionKey: "\${KIBANA_REPORTING_ENCRYPTION_KEY}"

xpack.encryptedSavedObjects.encryptionKey: "\${KIBANA_SAVED_OBJECTS_ENCRYPTION_KEY}"

EOF


# ============================================================
# SET FILE PERMISSIONS
# ============================================================

echo "Setting Kibana permissions..."

# Keep application files owned by root.
chown -R root:kibana "${EXTRACTED_DIR}"

# Kibana needs write access to its runtime directories.
mkdir -p "${EXTRACTED_DIR}/data"

# Recursively fix existing files as well.
chown -R kibana:kibana "${EXTRACTED_DIR}/data"

chmod 750 "${EXTRACTED_DIR}/data"

# Give Kibana ownership of its log and configured data directories.
chown -R kibana:kibana "${LOG_DIR}" "${HOME_DIR}"

# Protect the configuration.
chmod 640 "${CONFIG_DIR}/kibana.yml"

# ============================================================
# CREATE SYSTEMD SERVICE
# ============================================================

echo "Creating Kibana systemd service..."

cat > "${SERVICE_FILE}" <<EOF
[Unit]
Description=Kibana
Wants=network-online.target
After=network-online.target

[Service]
Type=simple

User=kibana
Group=kibana

WorkingDirectory=${EXTRACTED_DIR}

Environment=KBN_PATH_CONF=${CONFIG_DIR}
EnvironmentFile=${ENV_FILE}

ExecStart=${EXTRACTED_DIR}/bin/kibana

Restart=on-failure
RestartSec=10
TimeoutStartSec=180

UMask=0077

[Install]
WantedBy=multi-user.target
EOF

# ============================================================
# START KIBANA
# ============================================================

echo "Starting Kibana service..."

systemctl daemon-reload
systemctl enable kibana
systemctl restart kibana

echo "Kibana installation commands completed."

systemctl --no-pager --full status kibana || true