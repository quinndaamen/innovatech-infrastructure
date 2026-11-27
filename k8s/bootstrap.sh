#!/usr/bin/env bash
# Rebuild the in-cluster parts after `terraform apply`.
# usage: KEYCLOAK_ADMIN_PASSWORD=... DESKTOP_PROXY_SECRET=... ./k8s/bootstrap.sh
set -euo pipefail

: "${KEYCLOAK_ADMIN_PASSWORD:?set KEYCLOAK_ADMIN_PASSWORD}"
: "${DESKTOP_PROXY_SECRET:?set DESKTOP_PROXY_SECRET (Keycloak: Clients > desktop-proxy > Credentials)}"

gcloud container clusters get-credentials innovatech-gke-cluster --zone europe-west4-a

# helper: create or update a secret without failing when it already exists
upsert_secret() {
  kubectl create secret generic "$@" --dry-run=client -o yaml | kubectl apply -f -
}

echo "== namespaces and gateway =="
kubectl apply -f k8s/base/namespace.yaml
kubectl apply -f k8s/base/gateway.yaml

echo "== secrets =="
DB_IP=$(gcloud sql instances describe innovatech-database --format='value(ipAddresses[0].ipAddress)')
DB_PASS=$(gcloud secrets versions access latest --secret=innovatech-keycloak-db-password)

upsert_secret keycloak-db -n keycloak \
  --from-literal=url="jdbc:postgresql://${DB_IP}:5432/keycloak" \
  --from-literal=password="${DB_PASS}"
upsert_secret keycloak-admin -n keycloak \
  --from-literal=username=admin \
  --from-literal=password="${KEYCLOAK_ADMIN_PASSWORD}"
upsert_secret desktop-proxy-client -n desktops \
  --from-literal=client-secret="${DESKTOP_PROXY_SECRET}"

echo "== keycloak =="
kubectl apply -f k8s/base/keycloak.yaml
[ -f k8s/base/keycloak-route.yaml ] && kubectl apply -f k8s/base/keycloak-route.yaml
kubectl -n keycloak rollout status deploy/keycloak --timeout=300s

echo "Done. Check: https://keycloak.innovatech.qvnn.me"