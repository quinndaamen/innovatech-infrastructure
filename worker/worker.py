"""Innovatech onboarding worker.

Polls the employees table. 'pending' rows get a desktop, 'offboarding' rows lose it.
Every external call uses an argument list (no shell), because usernames come from a form.
Each step is idempotent, so a crashed run is simply retried.
"""
import json
import os
import re
import secrets
import subprocess
import tempfile
import time

import psycopg
import requests
from psycopg.rows import dict_row

DOMAIN = os.environ.get("DESKTOPS_DOMAIN", "desktops.innovatech.qvnn.me")
KC_URL = os.environ["KEYCLOAK_URL"].rstrip("/")
REALM = os.environ.get("KEYCLOAK_REALM", "innovatech")
KC_CLIENT = os.environ.get("KEYCLOAK_CLIENT_ID", "onboarding-worker")
KC_SECRET = os.environ["KEYCLOAK_CLIENT_SECRET"]
PROXY_CLIENT = os.environ.get("PROXY_CLIENT_ID", "desktop-proxy")
BUCKET = os.environ["ARCHIVE_BUCKET"]
ARCHIVE_IMAGE = os.environ.get("ARCHIVE_IMAGE", "gcr.io/google.com/cloudsdktool/google-cloud-cli:slim")  # pin a version tag later
POLL = int(os.environ.get("POLL_SECONDS", "10"))
NS = "desktops"
CHART = "/chart"
USERNAME_RE = re.compile(r"^[a-z][a-z0-9-]{0,30}$")
ROLE_RE = re.compile(r"^[a-z][a-z-]{0,20}$")


def log(event, severity="INFO", **fields):
    print(json.dumps({"severity": severity, "event": event, **fields}), flush=True)


def run(args, stdin=None, check=True, timeout=1200):
    r = subprocess.run(args, input=stdin, capture_output=True, text=True, timeout=timeout)
    if check and r.returncode != 0:
        raise RuntimeError(f"{args[0]} {args[1] if len(args) > 1 else ''} failed: {r.stderr.strip()[:400]}")
    return r


def kubectl(*args, stdin=None, check=True):
    return run(["kubectl", "-n", NS, *args], stdin=stdin, check=check)


# ---------------- Keycloak ----------------
class Keycloak:
    def __init__(self):
        self.token, self.exp = None, 0

    def _auth(self):
        if time.time() < self.exp:
            return
        r = requests.post(
            f"{KC_URL}/realms/{REALM}/protocol/openid-connect/token",
            data={"grant_type": "client_credentials", "client_id": KC_CLIENT, "client_secret": KC_SECRET},
            timeout=15,
        )
        r.raise_for_status()
        j = r.json()
        self.token, self.exp = j["access_token"], time.time() + j["expires_in"] - 30

    def call(self, method, path, **kw):
        self._auth()
        r = requests.request(method, f"{KC_URL}/admin/realms/{REALM}{path}",
                             headers={"Authorization": f"Bearer {self.token}"}, timeout=15, **kw)
        r.raise_for_status()
        return r

    def find_user(self, username):
        users = self.call("GET", "/users", params={"username": username, "exact": "true"}).json()
        return users[0] if users else None

    def ensure_user(self, username, email, name):
        """Returns (user id, temporary password or None if the account already existed)."""
        u = self.find_user(username)
        if u:
            if not u.get("enabled"):
                self.call("PUT", f"/users/{u['id']}", json={"enabled": True})
            return u["id"], None
        temp = secrets.token_urlsafe(12)
        first, _, last = name.partition(" ")
        r = self.call("POST", "/users", json={
            "username": username, "email": email, "firstName": first or username, "lastName": last or "-",
            "enabled": True, "emailVerified": True, "requiredActions": ["UPDATE_PASSWORD"],
            "credentials": [{"type": "password", "value": temp, "temporary": True}],
        })
        return r.headers["Location"].rsplit("/", 1)[-1], temp

    def add_to_group(self, uid, group):
        groups = self.call("GET", "/groups", params={"search": group, "exact": "true"}).json()
        match = [g for g in groups if g["name"] == group]
        if not match:
            raise RuntimeError(f"Keycloak group '{group}' does not exist")
        self.call("PUT", f"/users/{uid}/groups/{match[0]['id']}")

    def set_redirect(self, uri, present):
        cid = self.call("GET", "/clients", params={"clientId": PROXY_CLIENT}).json()[0]["id"]
        client = self.call("GET", f"/clients/{cid}").json()
        old = set(client.get("redirectUris", []))
        new = (old | {uri}) if present else (old - {uri})
        if new != old:
            client["redirectUris"] = sorted(new)
            self.call("PUT", f"/clients/{cid}", json=client)

    def disable_user(self, username):
        u = self.find_user(username)
        if u:
            self.call("PUT", f"/users/{u['id']}", json={"enabled": False})
            self.call("POST", f"/users/{u['id']}/logout")


kc = Keycloak()


# ---------------- Kubernetes / Helm ----------------
def check_input(username, role):
    if not USERNAME_RE.match(username) or not ROLE_RE.match(role):
        raise RuntimeError("invalid username or role")
    if not os.path.exists(f"{CHART}/values-{role}.yaml"):
        raise RuntimeError(f"no values file for role '{role}'")


def ensure_cookie_secret(username):
    name = f"cookie-{username}"
    if kubectl("get", "secret", name, check=False).returncode == 0:
        return
    manifest = {"apiVersion": "v1", "kind": "Secret",
                "metadata": {"name": name, "namespace": NS, "labels": {"innovatech/owner": username}},
                "type": "Opaque", "stringData": {"cookie-secret": secrets.token_hex(16)}}
    kubectl("apply", "-f", "-", stdin=json.dumps(manifest))   # via stdin, so it never shows in a process list


def helm_install(username, email, role):
    with tempfile.NamedTemporaryFile("w", suffix=".json", delete=False) as f:
        json.dump({"username": username, "email": email}, f)   # a values file instead of --set: no comma/escape problems
    try:
        run(["helm", "upgrade", "--install", f"desktop-{username}", CHART, "-n", NS,
             "-f", f"{CHART}/values-{role}.yaml", "-f", f.name, "--wait", "--timeout", "15m"], timeout=1000)
    finally:
        os.unlink(f.name)


def archive_home(username):
    """Copy the home disk to the archive bucket with a short-lived Job, then return."""
    if kubectl("get", "pvc", f"home-{username}", check=False).returncode != 0:
        return
    ts = time.strftime("%Y%m%d-%H%M%S")
    job = f"archive-{username}-{ts}"
    target = f"gs://{BUCKET}/{username}-{ts}.tar.gz"
    manifest = {
        "apiVersion": "batch/v1", "kind": "Job", "metadata": {"name": job, "namespace": NS},
        "spec": {"backoffLimit": 1, "ttlSecondsAfterFinished": 3600, "template": {"spec": {
            "restartPolicy": "Never", "serviceAccountName": "archiver",
            "nodeSelector": {"workload": "desktop"},
            "tolerations": [{"key": "workload", "operator": "Equal", "value": "desktop", "effect": "NoSchedule"}],
            "containers": [{"name": "archive", "image": ARCHIVE_IMAGE,
                            "command": ["sh", "-c", f"tar czf /tmp/home.tgz -C /config . && gcloud storage cp /tmp/home.tgz {target}"],
                            "volumeMounts": [{"name": "home", "mountPath": "/config", "readOnly": True}]}],
            "volumes": [{"name": "home", "persistentVolumeClaim": {"claimName": f"home-{username}", "readOnly": True}}]}}},
    }
    kubectl("apply", "-f", "-", stdin=json.dumps(manifest))
    deadline = time.time() + 900
    while time.time() < deadline:
        conds = kubectl("get", "job", job, "-o", "jsonpath={.status.conditions[*].type}").stdout
        if "Complete" in conds:
            kubectl("delete", "job", job, "--ignore-not-found")
            log("home_archived", employee=username, target=target)
            return
        if "Failed" in conds:
            raise RuntimeError("archive job failed")
        time.sleep(10)
    raise RuntimeError("archive job timed out")


# ---------------- the two flows ----------------
def audit(conn, action, target, details=""):
    conn.execute("INSERT INTO audit_log (actor, action, target, details) VALUES ('worker',%s,%s,%s)",
                 (action, target, details))


def onboard(conn, emp):
    username, role = emp["email"].split("@")[0], emp["role"]
    check_input(username, role)
    uid, temp = kc.ensure_user(username, emp["email"], emp["name"])
    kc.add_to_group(uid, role)
    kc.set_redirect(f"https://{username}.{DOMAIN}/oauth2/callback", True)
    ensure_cookie_secret(username)
    helm_install(username, emp["email"], role)
    conn.execute("INSERT INTO desktops (employee_id, release_name, hostname) VALUES (%s,%s,%s)",
                 (emp["id"], f"desktop-{username}", f"{username}.{DOMAIN}"))
    conn.execute("UPDATE employees SET status='active', temp_password=%s WHERE id=%s", (temp, emp["id"]))
    audit(conn, "employee.provisioned", emp["email"], f"role={role}")
    log("employee_provisioned", employee=emp["email"], role=role)


def offboard(conn, emp):
    username = emp["email"].split("@")[0]
    check_input(username, emp["role"])
    kc.disable_user(username)
    kc.set_redirect(f"https://{username}.{DOMAIN}/oauth2/callback", False)
    run(["helm", "uninstall", f"desktop-{username}", "-n", NS, "--ignore-not-found", "--wait"])
    archive_home(username)                       # the PVC survives helm uninstall (resource-policy: keep)
    kubectl("delete", "pvc", f"home-{username}", "--ignore-not-found")
    kubectl("delete", "secret", f"cookie-{username}", "--ignore-not-found")
    conn.execute("DELETE FROM desktops WHERE employee_id=%s", (emp["id"],))
    conn.execute("UPDATE employees SET status='offboarded', temp_password=NULL WHERE id=%s", (emp["id"],))
    audit(conn, "employee.offboarded", emp["email"])
    log("employee_offboarded", employee=emp["email"])


def process_one():
    with psycopg.connect(host=os.environ["DB_HOST"], dbname="portal", user="portal",
                         password=os.environ["DB_PASSWORD"], row_factory=dict_row, connect_timeout=5) as conn:
        emp = conn.execute(
            "SELECT * FROM employees WHERE status IN ('pending','offboarding') "
            "ORDER BY id LIMIT 1 FOR UPDATE SKIP LOCKED").fetchone()
        if not emp:
            return False
        action = onboard if emp["status"] == "pending" else offboard
        try:
            action(conn, emp)
        except Exception as ex:          # any failure: mark it, keep the reason in the audit trail
            log("job_failed", "ERROR", employee=emp["email"], step=action.__name__, error=str(ex)[:300])
            conn.execute("UPDATE employees SET status='failed', temp_password=NULL WHERE id=%s", (emp["id"],))
            audit(conn, f"employee.{action.__name__}_failed", emp["email"], str(ex)[:500])
        return True


if __name__ == "__main__":
    log("worker_started")
    while True:
        try:
            if process_one():
                continue
        except Exception as ex:          # database or network trouble: log and try again
            log("loop_error", "ERROR", error=str(ex)[:300])
        time.sleep(POLL)