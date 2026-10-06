import os
from dotenv import load_dotenv
from flask import Flask, abort, redirect, render_template, request, session, url_for
from peewee import OperationalError
import secrets
from datetime import timedelta
from functools import wraps
from models.contato import Contato
from models.plano import Plano
from models.usuario import Usuario
from models.pessoa import Pessoa
from models.relacao import Relacao, PessoaRelacao


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

        if cd_usuario is None:
            session.clear()
            return redirect(url_for("login"))

        usuarios = Usuario.buscar(cd_usuario=cd_usuario, fl_ativo=True)

        if not usuarios:
            session.clear()
            return redirect(url_for("login"))

        usuario = usuarios[0]
        session["cd_nivel"] = usuario.cd_nivel
        session["login"] = usuario.login

        if request.endpoint not in ("trocar_senha", "logout"):
            if Usuario.precisa_trocar_senha(cd_usuario):
                return redirect(url_for("trocar_senha"))

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


@app.route("/plano")
def plano():
    return render_template("plano.html", planos=Plano.listar_ativos())


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
        enviado=request.args.get("enviado") == "1")


@app.route("/login", methods=["GET", "POST"])
def login():
    erro = None

    if request.method == "POST":
        validar_csrf()

        resultado = Usuario.autenticar(
            request.form.get("login", ""),
            request.form.get("senha", ""))

        if resultado["status"] in (1, 2):
            usuario = resultado["usuario"]

            session.clear()
            session["cd_usuario"] = usuario.cd_usuario
            session["cd_nivel"] = usuario.cd_nivel
            session["csrf_token"] = secrets.token_urlsafe(32)
            session.permanent = True

            destino = "trocar_senha" if resultado["status"] == 2 else "adm"
            return redirect(url_for(destino))

        erro = "Login ou senha inválidos."

    if "csrf_token" not in session:
        session["csrf_token"] = secrets.token_urlsafe(32)

    return render_template("login.html", erro=erro)


@app.route("/adm")
@login_obrigatorio
def adm():
    return redirect(url_for("adm_contato"))


@app.route("/adm/contatos")
@login_obrigatorio
def adm_contato():
    return render_template("adm_contato.html", grupos=Contato.por_prazo())


@app.route("/adm/usuarios", methods=["GET", "POST"])
@login_obrigatorio
def adm_usuario():
    cd_operador = session["cd_usuario"]
    nivel = session["cd_nivel"]

    if nivel not in (0, 1, 2, 3, 4):
        abort(403)

    erro = None
    selecionado = None
    dados = {}

    if request.method == "POST":
        validar_csrf()
        dados = request.form.to_dict()

        codigo_recebido = dados.get("cd_usuario", "")

        try:
            codigo = int(codigo_recebido) if codigo_recebido != "" else None
        except (ValueError, TypeError):
            abort(400)

        # Confere o acesso ao registro antes de processar o formulário.
        if codigo is None:
            if nivel != 0:
                abort(403)
        else:
            if nivel not in (0, 1) and codigo != cd_operador:
                abort(403)

            encontrados = Usuario.buscar(cd_usuario=codigo)

            if not encontrados:
                abort(404)

            selecionado = encontrados[0]

            if nivel == 1 and codigo != cd_operador:
                if selecionado.cd_nivel not in (2, 3, 4):
                    abort(403)

        resultado = Usuario.salvar_autorizado(cd_operador, dados)

        if resultado["sucesso"]:
            return redirect(url_for("adm_usuario", sucesso=1))

        erro = resultado["erro"]

    else:
        codigo_recebido = request.args.get("editar")

        try:
            codigo = int(codigo_recebido) if codigo_recebido is not None else None
        except (ValueError, TypeError):
            abort(400)

        # Níveis inferiores editam somente a própria senha.
        if nivel not in (0, 1):
            if codigo is not None and codigo != cd_operador:
                abort(403)

            codigo = cd_operador

        if codigo is not None:
            encontrados = Usuario.buscar(cd_usuario=codigo)

            if not encontrados:
                abort(404)

            selecionado = encontrados[0]

            if nivel == 1 and codigo != cd_operador:
                if selecionado.cd_nivel not in (2, 3, 4):
                    abort(403)

            dados = selecionado.__data__.copy()

    if nivel in (0, 1):
        usuarios = Usuario.buscar()
    else:
        usuarios = Usuario.buscar(cd_usuario=cd_operador)

    if nivel == 0:
        pessoas, niveis = Usuario.opcoes()
    else:
        pessoas, niveis = [], []

    dados.pop("senha", None)

    return render_template(
        "adm_usuario.html",
        usuarios=usuarios,
        pessoas=pessoas,
        niveis=niveis,
        selecionado=selecionado,
        dados=dados,
        erro=erro,
        sucesso=request.args.get("sucesso") == "1"
    )


@app.route("/trocar-senha", methods=["GET", "POST"])
@login_obrigatorio
def trocar_senha():
    cd_usuario = session["cd_usuario"]
    obrigatoria = Usuario.precisa_trocar_senha(cd_usuario)
    erro = None

    if request.method == "POST":
        validar_csrf()

        resultado = Usuario.trocar_senha(
            cd_usuario=cd_usuario,
            senha=request.form.get("senha", ""),
            confirmacao=request.form.get("confirmacao", ""),
            senha_atual=request.form.get("senha_atual", "")
        )

        if resultado["sucesso"]:
            session["csrf_token"] = secrets.token_urlsafe(32)
            return redirect(url_for("adm"))

        erro = resultado["erro"]

    return render_template(
        "trocar_senha.html",
        obrigatoria=obrigatoria,
        erro=erro
    )

@app.route("/logout", methods=["POST"])
@login_obrigatorio
def logout():
    validar_csrf()
    session.clear()

    return redirect(url_for("login"))

@app.route("/adm/usuarios/<int:cd_usuario>/resetar-senha", methods=["POST"])
@login_obrigatorio
def resetar_senha_usuario(cd_usuario):
    validar_csrf()

    if session["cd_nivel"] != 0:
        abort(403)

    resultado = Usuario.resetar_senha(session["cd_usuario"], cd_usuario)

    if not resultado["sucesso"]:
        abort(404)

    return redirect(url_for("adm_usuario", senha_resetada=1))
@app.route("/adm/pessoas", methods=["GET", "POST"])
@login_obrigatorio
def adm_pessoa():
    if session["cd_nivel"] not in (0, 1):
        abort(403)

    erro = None
    selecionado = None
    dados = {}
    relacoes = Relacao.buscar()
    relacoes_selecionadas = []

    if request.method == "POST":
        validar_csrf()
        formulario = request.form.to_dict()

        try:
            codigo = formulario.get("cd_pessoa", "")
            cd_pessoa = int(codigo) if codigo != "" else None
            relacoes_selecionadas = [
                int(valor) for valor in request.form.getlist("cd_relacao")
            ]
        except (ValueError, TypeError):
            abort(400)

        acao = formulario.get("acao", "salvar")

        if acao == "excluir":
            if cd_pessoa is None:
                abort(400)

            resultado = Pessoa.excluir(cd_pessoa)

        elif acao == "salvar":
            dados = {
                campo: formulario.get(campo, "")
                for campo in ("tp_pessoa", "nm_pessoa", "cpf_cnpj", "telefone", "email")
            }

            dados["dados"] = {
                campo: formulario.get(campo, "")
                for campo in ("endereco", "numero", "complemento", "bairro", "cep", "cidade", "uf")
            }

            if cd_pessoa is None:
                resultado = Pessoa.incluir(dados, relacoes=relacoes_selecionadas)
            else:
                dados["cd_pessoa"] = cd_pessoa
                resultado = Pessoa.atualizar(dados, relacoes=relacoes_selecionadas)                

        else:
            abort(400)

        if resultado["sucesso"]:
            return redirect(url_for("adm_pessoa", sucesso=1))

        erro = resultado["erro"]

        if cd_pessoa is not None:
            encontrados = Pessoa.buscar(cd_pessoa)
            selecionado = encontrados[0] if encontrados else None

            if acao == "excluir" and selecionado is not None:
                dados = selecionado.__data__.copy()
                relacoes_selecionadas = PessoaRelacao.buscar(cd_pessoa)

    else:
        codigo = request.args.get("editar")

        if codigo is not None:
            try:
                cd_pessoa = int(codigo)
            except (ValueError, TypeError):
                abort(400)

            encontrados = Pessoa.buscar(cd_pessoa)

            if not encontrados:
                abort(404)

            selecionado = encontrados[0]
            dados = selecionado.__data__.copy()
            relacoes_selecionadas = PessoaRelacao.buscar(cd_pessoa)

    return render_template(
        "adm_pessoa.html",
        pessoas=Pessoa.buscar(fl_ativo=True),
        selecionado=selecionado,
        dados=dados,
        erro=erro,
        sucesso=request.args.get("sucesso") == "1",
        relacoes=relacoes,
        relacoes_selecionadas=relacoes_selecionadas
    )

@app.errorhandler(OperationalError)
def erro_conexao_banco(erro):
    app.logger.exception("Falha de conexão com o banco de dados.")

    return ("Não foi possível concluir a operação devido a uma falha de conexão.<br>"
            "Se estava salvando dados, confira se foram gravados antes de tentar novamente.<br>"
            "Por favor, atualize/recarregue esta página.",503)

if __name__ == "__main__":
    print(app.url_map)
    app.run(host="0.0.0.0", port=5155, debug=True)