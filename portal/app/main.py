"""Innovatech portal API.

Identity comes from the oauth2-proxy sidecar (X-Forwarded-* headers). The app
listens on 127.0.0.1 only, so nothing but the sidecar can reach it and the
headers can be trusted. The app has no Kubernetes permissions: it only writes
rows. The worker does the actual provisioning.
"""
import html
import json
import os
import re

import psycopg
from psycopg.rows import dict_row
from fastapi import FastAPI, Form, HTTPException, Request
from fastapi.responses import HTMLResponse, RedirectResponse

DOMAIN = os.environ.get("DESKTOPS_DOMAIN", "desktops.innovatech.qvnn.me")
ADMIN_GROUPS = {g.strip() for g in os.environ.get("ADMIN_GROUPS", "hr-admin,admin").split(",") if g.strip()}
ROLES = ["hr-staff", "developer"]          # roles that have a values-<role>.yaml + image
USERNAME_RE = re.compile(r"^[a-z][a-z0-9-]{0,30}$")
EMAIL_RE = re.compile(r"^[^@\s]+@[^@\s]+\.[^@\s]+$")

app = FastAPI(title="Innovatech portal API")


def log(event, severity="INFO", **fields):
    # one JSON object per line: Cloud Logging turns it into jsonPayload fields
    print(json.dumps({"severity": severity, "event": event, **fields}), flush=True)


def db():
    return psycopg.connect(
        host=os.environ["DB_HOST"], dbname="portal", user="portal",
        password=os.environ["DB_PASSWORD"], row_factory=dict_row, connect_timeout=5,
    )


def audit(conn, actor, action, target, details=""):
    conn.execute(
        "INSERT INTO audit_log (actor, action, target, details) VALUES (%s,%s,%s,%s)",
        (actor, action, target, details),
    )


def identity(request: Request):
    h = request.headers
    email = (h.get("x-forwarded-email") or "").strip().lower()
    groups = {g.strip().lstrip("/") for g in (h.get("x-forwarded-groups") or "").split(",") if g.strip()}
    return {"email": email, "groups": sorted(groups), "is_admin": bool(groups & ADMIN_GROUPS)}


def require_admin(request: Request):
    who = identity(request)
    if not who["email"]:
        raise HTTPException(401, "not authenticated")
    if not who["is_admin"]:
        log("access_denied", "WARNING", actor=who["email"], path=request.url.path)
        raise HTTPException(403, "HR admins only")
    return who


def desktop_url(emp):
    return f"https://{emp['email'].split('@')[0]}.{DOMAIN}"


@app.get("/healthz")
def healthz():
    return {"status": "ok"}


@app.get("/whoami")
def whoami(request: Request):
    return identity(request)


@app.get("/api/employees")
def list_employees(request: Request):
    require_admin(request)
    with db() as conn:
        return conn.execute("SELECT id, name, email, department, role, status, created_at "
                            "FROM employees ORDER BY id").fetchall()


@app.post("/employees")
def add_employee(request: Request, name: str = Form(...), email: str = Form(...),
                 department: str = Form(...), role: str = Form(...)):
    who = require_admin(request)
    name, email, department = name.strip(), email.strip().lower(), department.strip()
    if not (1 <= len(name) <= 100 and 1 <= len(department) <= 100):
        raise HTTPException(422, "name and department must be 1-100 characters")
    if not EMAIL_RE.match(email) or not USERNAME_RE.match(email.split("@")[0]):
        raise HTTPException(422, "email local part: lowercase letters, digits, hyphens (it becomes the username)")
    if role not in ROLES:
        raise HTTPException(422, "unknown role")
    try:
        with db() as conn:
            conn.execute(
                "INSERT INTO employees (name, email, department, role) VALUES (%s,%s,%s,%s)",
                (name, email, department, role),
            )
            audit(conn, who["email"], "employee.create", email, f"role={role}")
    except psycopg.errors.UniqueViolation:
        raise HTTPException(409, "an employee with this email already exists")
    log("employee_created", actor=who["email"], employee=email, role=role)
    return RedirectResponse("/", status_code=303)


@app.post("/employees/{emp_id}/offboard")
def offboard(request: Request, emp_id: int):
    who = require_admin(request)
    with db() as conn:
        emp = conn.execute(
            "UPDATE employees SET status='offboarding' "
            "WHERE id=%s AND status IN ('active','failed','pending') RETURNING email",
            (emp_id,),
        ).fetchone()
        if not emp:
            raise HTTPException(409, "employee not found or already offboarded")
        audit(conn, who["email"], "employee.offboard", emp["email"])
    log("employee_offboard_requested", actor=who["email"], employee=emp["email"])
    return RedirectResponse("/", status_code=303)


@app.post("/employees/{emp_id}/clear-password")
def clear_password(request: Request, emp_id: int):
    who = require_admin(request)
    with db() as conn:
        conn.execute("UPDATE employees SET temp_password=NULL WHERE id=%s", (emp_id,))
        audit(conn, who["email"], "employee.password_cleared", str(emp_id))
    return RedirectResponse("/", status_code=303)


@app.get("/", response_class=HTMLResponse)
def home(request: Request):
    who = identity(request)
    if not who["email"]:
        raise HTTPException(401, "not authenticated")
    with db() as conn:
        me = conn.execute("SELECT * FROM employees WHERE lower(email)=%s", (who["email"],)).fetchone()
        rows = conn.execute("SELECT * FROM employees ORDER BY id").fetchall() if who["is_admin"] else []

    # regular employees go straight to their own desktop
    if me and me["status"] == "active" and not who["is_admin"]:
        log("desktop_redirect", employee=who["email"])
        return RedirectResponse(desktop_url(me), status_code=302)

    e = html.escape
    parts = [f"<h1>Innovatech portal</h1><p>Signed in as {e(who['email'])}</p>"]
    if me and me["status"] == "active":
        parts.append(f"<p><a href='{e(desktop_url(me))}'>Open my desktop</a></p>")
    if not who["is_admin"]:
        msg = "Your desktop is being prepared, try again in a few minutes." if me and me["status"] == "pending" \
            else "No desktop is available for your account. Contact HR."
        parts.append(f"<p>{msg}</p>")
    else:
        opts = "".join(f"<option>{r}</option>" for r in ROLES)
        parts.append(
            "<h2>Onboard employee</h2><form method='post' action='/employees'>"
            "<input name='name' placeholder='Name' required> "
            "<input name='email' placeholder='jan@innovatech.qvnn.me' required> "
            "<input name='department' placeholder='Department' required> "
            f"<select name='role'>{opts}</select> <button>Onboard</button></form>"
            "<h2>Employees</h2><table border='1' cellpadding='6'>"
            "<tr><th>Name</th><th>Email</th><th>Department</th><th>Role</th><th>Status</th><th>Temp password</th><th></th></tr>"
        )
        for r in rows:
            action = ""
            if r["status"] in ("active", "failed", "pending"):
                action = (f"<form method='post' action='/employees/{r['id']}/offboard' "
                          "onsubmit=\"return confirm('Offboard this employee?')\"><button>Offboard</button></form>")
            pw = ""
            if r.get("temp_password"):
                pw = (f"<code>{e(r['temp_password'])}</code> "
                      f"<form method='post' action='/employees/{r['id']}/clear-password' style='display:inline'>"
                      "<button>Clear</button></form>")
            parts.append(
                f"<tr><td>{e(r['name'])}</td><td>{e(r['email'])}</td><td>{e(r['department'])}</td>"
                f"<td>{e(r['role'])}</td><td>{e(r['status'])}</td><td>{pw}</td><td>{action}</td></tr>"
            )
        parts.append("</table><p>Refresh the page to see status changes.</p>")
    return HTMLResponse("<!doctype html><meta charset='utf-8'><body style='font-family:sans-serif'>" + "".join(parts))