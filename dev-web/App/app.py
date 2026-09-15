import os

from flask import Flask, render_template, request, redirect, url_for
from flask_sqlalchemy import SQLAlchemy
from sqlalchemy import text
from sqlalchemy.engine import URL

app = Flask(__name__)

# --------------------------------------------------
# Database configuration
# --------------------------------------------------

DB_HOST = os.environ.get("DB_HOST")
DB_PORT = os.environ.get("DB_PORT", "5432")
DB_NAME = os.environ.get("DB_NAME")
DB_USER = os.environ.get("DB_USER")
DB_PASSWORD = os.environ.get("DB_PASSWORD")

if not DB_HOST:
    raise RuntimeError("DB_HOST is not configured")

if not DB_NAME:
    raise RuntimeError("DB_NAME is not configured")

if not DB_USER:
    raise RuntimeError("DB_USER is not configured")

if not DB_PASSWORD:
    raise RuntimeError("DB_PASSWORD is not configured")


database_url = URL.create(
    drivername="postgresql+psycopg2",
    username=DB_USER,
    password=DB_PASSWORD,
    host=DB_HOST,
    port=int(DB_PORT),
    database=DB_NAME
)

app.config["SQLALCHEMY_DATABASE_URI"] = database_url
app.config["SQLALCHEMY_TRACK_MODIFICATIONS"] = False

db = SQLAlchemy(app)


# --------------------------------------------------
# Database model
# --------------------------------------------------

class Submission(db.Model):

    __tablename__ = "submissions"

    id = db.Column(
        db.Integer,
        primary_key=True
    )

    name = db.Column(
        db.String(100),
        nullable=False
    )

    email = db.Column(
        db.String(255),
        nullable=False
    )

    message = db.Column(
        db.Text,
        nullable=False
    )


# --------------------------------------------------
# Initialise database
# --------------------------------------------------

def initialise_database():

    with app.app_context():
        db.create_all()


# --------------------------------------------------
# Routes
# --------------------------------------------------

@app.route("/")
def home():

    return render_template("index.html")


@app.route("/form")
def form():

    return render_template("form.html")


@app.route("/submit", methods=["POST"])
def submit():

    name = request.form.get("name", "").strip()
    email = request.form.get("email", "").strip()
    message = request.form.get("message", "").strip()

    if not name or not email or not message:
        return "All fields are required.", 400

    if len(name) > 100:
        return "Name is too long.", 400

    if len(email) > 255:
        return "Email is too long.", 400

    submission = Submission(
        name=name,
        email=email,
        message=message
    )

    try:

        db.session.add(submission)
        db.session.commit()

    except Exception as error:

        db.session.rollback()

        print(
            f"Database insert failed: {type(error).__name__}"
        )

        return "Unable to save submission.", 500

    return redirect(url_for("submissions"))


@app.route("/submissions")
def submissions():

    try:

        data = (
            Submission.query
            .order_by(Submission.id.desc())
            .all()
        )

        return render_template(
            "submissions.html",
            submissions=data
        )

    except Exception as error:

        print(
            f"Database query failed: {type(error).__name__}"
        )

        return "Unable to retrieve submissions.", 500


# --------------------------------------------------
# Health checks
# --------------------------------------------------

@app.route("/health")
def health():

    return "OK", 200


@app.route("/health/db")
def database_health():

    try:

        db.session.execute(
            text("SELECT 1")
        )

        return "Database OK", 200

    except Exception as error:

        print(
            f"Database health check failed: {type(error).__name__}"
        )

        return "Database unavailable", 503


# --------------------------------------------------
# Start-up
# --------------------------------------------------

initialise_database()