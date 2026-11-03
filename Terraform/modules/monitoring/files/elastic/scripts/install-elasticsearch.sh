#!/bin/bash
set -euo pipefail

ELASTIC_VERSION="__ELASTIC_VERSION__"
ELASTIC_BUCKET="__ELASTIC_BUCKET__"
AWS_REGION="__AWS_REGION__"
ELASTICSEARCH_PRIVATE_IP="__ELASTICSEARCH_PRIVATE_IP__"
ENVIRONMENT="__ENVIRONMENT__"

INSTALL_DIR="/opt/elastic"
ARCHIVE="${INSTALL_DIR}/elasticsearch.tar.gz"
EXTRACTED_DIR="${INSTALL_DIR}/elasticsearch-${ELASTIC_VERSION}"
CONFIG_DIR="${EXTRACTED_DIR}/config"
DATA_DIR="/var/lib/elasticsearch"
LOG_DIR="/var/log/elasticsearch"
SERVICE_FILE="/etc/systemd/system/elasticsearch.service"

KIBANA_TOKEN_NAME="kibana-token-2"
KIBANA_TOKEN_ID="elastic/kibana/${KIBANA_TOKEN_NAME}"
SSM_PARAMETER_NAME="/innovatech/${ENVIRONMENT}/kibana/service-account-token"

echo "Starting Elasticsearch ${ELASTIC_VERSION} installation"

# --------------------------------------------------
# Install dependencies
# --------------------------------------------------

dnf install -y java-21-amazon-corretto-headless awscli 

# --------------------------------------------------
# Prepare installation directory
# --------------------------------------------------

mkdir -p "${INSTALL_DIR}"

if [ ! -s "${ARCHIVE}" ]; then
    aws s3 cp \
        "s3://${ELASTIC_BUCKET}/elasticsearch/elasticsearch-${ELASTIC_VERSION}-linux-x86_64.tar.gz" \
        "${ARCHIVE}" \
        --region "${AWS_REGION}"
fi

if [ ! -x "${EXTRACTED_DIR}/bin/elasticsearch" ]; then
    tar -xzf "${ARCHIVE}" -C "${INSTALL_DIR}"
fi

if [ ! -x "${EXTRACTED_DIR}/bin/elasticsearch" ]; then
    echo "ERROR: Elasticsearch executable was not found."
    exit 1
fi

if [ ! -f "${CONFIG_DIR}/elasticsearch.yml" ]; then
    echo "ERROR: Elasticsearch configuration was not found."
    exit 1
fi

# --------------------------------------------------
# Create Elasticsearch service account
# --------------------------------------------------

if ! id elasticsearch >/dev/null 2>&1; then
    useradd --system \
        --home-dir "${DATA_DIR}" \
        --shell /sbin/nologin \
        elasticsearch
fi

mkdir -p "${DATA_DIR}" "${LOG_DIR}"

# --------------------------------------------------
# Configure Elasticsearch
# --------------------------------------------------

set_config() {
    local key="$1"
    local value="$2"

    if grep -qE "^${key}:" "${CONFIG_DIR}/elasticsearch.yml"; then
        sed -i \
            "s|^${key}:.*|${key}: ${value}|" \
            "${CONFIG_DIR}/elasticsearch.yml"
    else
        printf '\n%s: %s\n' "${key}" "${value}" \
            >> "${CONFIG_DIR}/elasticsearch.yml"
    fi
}

set_config "network.host" "${ELASTICSEARCH_PRIVATE_IP}"
set_config "http.port" "9200"
set_config "cluster.name" "innovatech-monitoring"
set_config "node.name" "elasticsearch-1"
set_config "discovery.type" "single-node"
set_config "path.data" "/var/lib/elasticsearch"
set_config "path.logs" "/var/log/elasticsearch"

# --------------------------------------------------
# Configure Linux kernel
# --------------------------------------------------

cat > /etc/sysctl.d/99-elasticsearch.conf <<'EOF'
vm.max_map_count=262144
EOF

sysctl --system

# --------------------------------------------------
# Set permissions
# --------------------------------------------------

chown -R elasticsearch:elasticsearch "${EXTRACTED_DIR}"
chown -R elasticsearch:elasticsearch "${DATA_DIR}"
chown -R elasticsearch:elasticsearch "${LOG_DIR}"

if [ -f "${CONFIG_DIR}/service_tokens" ]; then
    chown elasticsearch:elasticsearch "${CONFIG_DIR}/service_tokens"
    chmod 600 "${CONFIG_DIR}/service_tokens"
fi

# --------------------------------------------------
# Create systemd service
# --------------------------------------------------

cat > "${SERVICE_FILE}" <<EOF
[Unit]
Description=Elasticsearch
Wants=network-online.target
After=network-online.target

[Service]
Type=simple
User=elasticsearch
Group=elasticsearch
WorkingDirectory=${EXTRACTED_DIR}
Environment=ES_PATH_CONF=${CONFIG_DIR}
ExecStart=${EXTRACTED_DIR}/bin/elasticsearch
Restart=on-failure
RestartSec=10
LimitNOFILE=65535
TimeoutStartSec=180

[Install]
WantedBy=multi-user.target
EOF

# --------------------------------------------------
# Start Elasticsearch
# --------------------------------------------------

systemctl daemon-reload
systemctl enable elasticsearch
systemctl restart elasticsearch

echo "Waiting for Elasticsearch to become available..."

for attempt in $(seq 1 60); do

    status=$(curl --silent \
        --output /dev/null \
        --write-out '%{http_code}' \
        --cacert "${CONFIG_DIR}/certs/http_ca.crt" \
        "https://${ELASTICSEARCH_PRIVATE_IP}:9200" || true)

    if [ "${status}" = "200" ] || [ "${status}" = "401" ]; then
        echo "Elasticsearch is responding."
        break
    fi

    if [ "${attempt}" -eq 60 ]; then
        echo "ERROR: Elasticsearch did not become available. Last HTTP status: ${status}"
        exit 1
    fi

    sleep 10
done


# --------------------------------------------------
# Publish Elasticsearch CA certificate to S3
# --------------------------------------------------

echo "Publishing Elasticsearch CA certificate to S3..."

CA_CERT="${CONFIG_DIR}/certs/http_ca.crt"

if [ ! -s "${CA_CERT}" ]; then
    echo "ERROR: Elasticsearch CA certificate not found."
    exit 1
fi

aws s3 cp \
    "${CA_CERT}" \
    "s3://${ELASTIC_BUCKET}/certs/http_ca.crt" \
    --region "${AWS_REGION}"

echo "Elasticsearch CA certificate published successfully."

# --------------------------------------------------
# Kibana service-account token provisioning
# --------------------------------------------------



echo "Checking Kibana service-account token..."

PARAMETER_ERROR_FILE=$(mktemp)
chmod 600 "${PARAMETER_ERROR_FILE}"

TOKEN_VALID=false
EXISTING_TOKEN=""

if EXISTING_TOKEN=$(aws ssm get-parameter \
    --name "${SSM_PARAMETER_NAME}" \
    --with-decryption \
    --query "Parameter.Value" \
    --output text \
    --region "${AWS_REGION}" \
    2>"${PARAMETER_ERROR_FILE}"); then

    echo "Existing Kibana token found. Validating it..."

    if curl --silent --show-error --fail \
        --cacert "${CONFIG_DIR}/certs/http_ca.crt" \
        -H "Authorization: Bearer ${EXISTING_TOKEN}" \
        "https://${ELASTICSEARCH_PRIVATE_IP}:9200/_security/_authenticate" \
        >/dev/null 2>&1; then

        TOKEN_VALID=true
    fi

else
    ERROR_MESSAGE=$(cat "${PARAMETER_ERROR_FILE}")

    if ! grep -q "ParameterNotFound" <<< "${ERROR_MESSAGE}"; then
        rm -f "${PARAMETER_ERROR_FILE}"
        echo "ERROR: Unable to retrieve SSM parameter."
        exit 1
    fi
fi

rm -f "${PARAMETER_ERROR_FILE}"
unset EXISTING_TOKEN

if [ "${TOKEN_VALID}" = true ]; then
    echo "Existing Kibana token is valid."
else
    echo "Existing Kibana token is missing or invalid. Generating replacement..."

    # Remove old local token entry if present.
    if grep -q "SERVICE_TOKEN ${KIBANA_TOKEN_ID}" \
        "${CONFIG_DIR}/service_tokens" 2>/dev/null; then

        runuser -u elasticsearch -- \
            env ES_PATH_CONF="${CONFIG_DIR}" \
            "${EXTRACTED_DIR}/bin/elasticsearch-service-tokens" \
            delete "elastic/kibana" "${KIBANA_TOKEN_NAME}"
    fi

    # Generate replacement token.
    TOKEN_OUTPUT=$(runuser -u elasticsearch -- \
        env ES_PATH_CONF="${CONFIG_DIR}" \
        "${EXTRACTED_DIR}/bin/elasticsearch-service-tokens" \
        create elastic/kibana "${KIBANA_TOKEN_NAME}")

    NEW_TOKEN=$(printf '%s\n' "${TOKEN_OUTPUT}" |
        sed -n 's/^SERVICE_TOKEN .* = //p')

    unset TOKEN_OUTPUT

    if [ -z "${NEW_TOKEN}" ]; then
        echo "ERROR: Token generation failed."
        exit 1
    fi

    # Update SSM Parameter Store.
    if ! aws ssm put-parameter \
        --name "${SSM_PARAMETER_NAME}" \
        --type SecureString \
        --value "${NEW_TOKEN}" \
        --overwrite \
        --region "${AWS_REGION}" \
        >/dev/null; then

        echo "ERROR: Could not store replacement token."
        unset NEW_TOKEN
        exit 1
    fi

    unset NEW_TOKEN

    echo "Replacement Kibana token stored successfully."
fi

# --------------------------------------------------
# Installation complete
# --------------------------------------------------

echo "Elasticsearch installation commands completed."

echo "Service status:"
systemctl --no-pager --full status elasticsearch || true