import os
import secrets
from datetime import timedelta
from functools import wraps

from dotenv import load_dotenv
from flask import Flask, abort, redirect, render_template, request, session, url_for

from models.contato import Contato
from models.plano import Plano
from models.usuario import Usuario


load_dotenv()
app = Flask(__name__)

app.secret_key = os.environ["FLASK_SECRET_KEY"]
app.config.update(
    PERMANENT_SESSION_LIFETIME=timedelta(hours=8),
    SESSION_COOKIE_HTTPONLY=True,
    SESSION_COOKIE_SAMESITE="Lax",
    SESSION_COOKIE_SECURE=os.getenv("SESSION_COOKIE_SECURE", "False") == "True"
)


def login_obrigatorio(funcao):
    @wraps(funcao)
    def protegida(*args, **kwargs):
        cd_usuario = session.get("cd_usuario")
        usuario = Usuario.buscar_ativo(cd_usuario) if cd_usuario else None

        if usuario is None:
            session.clear()
            return redirect(url_for("login"))

        session["cd_nivel"] = usuario.cd_nivel
        return funcao(*args, **kwargs)

    return protegida


def validar_csrf():
    token = request.form.get("csrf_token", "")
    token_sessao = session.get("csrf_token")

    if not token_sessao or not secrets.compare_digest(token, token_sessao):
        abort(400)


@app.route("/")
def home():
    return render_template("home.html")


@app.route("/planos")
def planos():
    return render_template("planos.html", planos=Plano.listar_ativos())


@app.route("/contato", methods=["GET", "POST"])
def contato():
    erro = None

    if request.method == "POST":
        resultado = Contato.incluir(request.form.to_dict())

        if resultado["sucesso"]:
            return redirect(url_for("contato", enviado=1))

        erro = resultado["erro"]

    return render_template(
        "contato.html",
        erro=erro,
        enviado=request.args.get("enviado") == "1"
    )


@app.route("/login", methods=["GET", "POST"])
def login():
    erro = None

    if request.method == "POST":
        validar_csrf()

        usuario = Usuario.autenticar(
            request.form.get("login", ""),
            request.form.get("senha", "")
        )

        if usuario:
            session.clear()
            session["cd_usuario"] = usuario.cd_usuario
            session["cd_nivel"] = usuario.cd_nivel
            session["csrf_token"] = secrets.token_urlsafe(32)
            session.permanent = True
            return redirect(url_for("adm"))

        erro = "Login ou senha inválidos."

    if "csrf_token" not in session:
        session["csrf_token"] = secrets.token_urlsafe(32)

    return render_template("login.html", erro=erro)


@app.route("/adm")
@login_obrigatorio
def adm():
    return render_template("adm.html")

@app.route("/adm/contatos")
@login_obrigatorio
def adm_contatos():
    return render_template("adm_contatos.html", grupos=Contato.por_prazo())

@app.route("/logout", methods=["POST"])
@login_obrigatorio
def logout():
    validar_csrf()
    session.clear()
    return redirect(url_for("login"))




if __name__ == "__main__":
    print(app.url_map)
    app.run(host="0.0.0.0", port=5155, debug=True)