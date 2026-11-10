import os
from dotenv import load_dotenv
from flask import Flask, abort, redirect, render_template, request, session, url_for, current_app
from peewee import OperationalError
import secrets
from datetime import date, datetime, timedelta
from functools import wraps
from models.contato import Contato
from models.plano import Plano
from models.usuario import Usuario
from models.contato_conversa import ContatoConversa
from models.cadastro_cliente import CadastroCliente
from models.cadastro_usuario import CadastroUsuario
from models.cliente import Cliente
from models.minha_conta import MinhaConta
from models.minhas_lojas import MinhasLojas
from models.cliente_link import ClienteLink


from zoneinfo import ZoneInfo

load_dotenv()

app = Flask(__name__)
app.secret_key = os.environ["FLASK_SECRET_KEY"]

app.config.update(
    PERMANENT_SESSION_LIFETIME=timedelta(minutes=30),
    SESSION_REFRESH_EACH_REQUEST=True,
    SESSION_COOKIE_HTTPONLY=True,
    SESSION_COOKIE_SAMESITE="Lax",
    SESSION_COOKIE_SECURE=os.getenv("SESSION_COOKIE_SECURE", "False") == "True"
)

app.config["PUBLIC_BASE_URL"] = "https://juvaecom.com.br"

def login_obrigatorio(funcao):
    @wraps(funcao)
    def protegida(*args, **kwargs):
        cd_usuario = session.get("cd_usuario")

        if cd_usuario is None:
            session.clear()
            return redirect(url_for("login"))

        usuario = Usuario.validar_sessao(cd_usuario)

        if usuario is None:
            session.clear()
            return redirect(url_for("login"))

        session["cd_nivel"] = usuario.cd_nivel
        session["login"] = usuario.login

        if request.endpoint not in ("trocar_senha", "logout"):
            if Usuario.precisa_trocar_senha(cd_usuario):
                return redirect(url_for("trocar_senha"))

        return funcao(*args, **kwargs)

    return protegida


def acesso_administrativo(funcao):
    @wraps(funcao)
    def protegida(*args, **kwargs):
        if session.get("cd_nivel") not in (0, 1, 2, 3, 4):
            abort(403)
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

            if resultado["status"] == 2:
                destino = "trocar_senha"
            elif usuario.cd_nivel == 5:
                destino = "cliente_inicio"
            else:
                destino = "adm"

            return redirect(url_for(destino))

        erro = "Login ou senha inválidos."

    if "csrf_token" not in session:
        session["csrf_token"] = secrets.token_urlsafe(32)

    return render_template("login.html", erro=erro)


@app.route("/adm")
@login_obrigatorio
@acesso_administrativo
def adm():
    return redirect(url_for("adm_contato"))



@app.route("/cliente/lojas")
@login_obrigatorio
def cliente_lojas():

    if session["cd_nivel"] != 5:
        abort(403)

    resultado = MinhasLojas.consultar(
        session["cd_usuario"]
    )

    if not resultado["sucesso"]:
        abort(403)

    return render_template(
        "cliente/lojas.html",
        lojas=resultado["lojas"],
        total_lojas=resultado["total_lojas"],
        total_ativas=resultado["total_ativas"]
    )


@app.route("/adm/contatos", methods=["GET", "POST"])
@login_obrigatorio
@acesso_administrativo
def adm_contato():
    erro = None
    dados = {}
    texto_conversa = ""

    if request.method == "POST":
        validar_csrf()

        try:
            cd_contato = int(request.form.get("cd_contato"))
        except (ValueError, TypeError):
            abort(400)
    else:
        codigo = request.args.get("editar")

        try:
            cd_contato = int(codigo) if codigo is not None else None
        except (ValueError, TypeError):
            abort(400)

    fila = Contato.pendentes()
    finalizados = Contato.finalizados()

    if cd_contato is None and fila:
        cd_contato = fila[0].cd_contato

    selecionado = None

    if cd_contato is not None:
        encontrados = Contato.buscar(cd_contato=cd_contato)

        if not encontrados:
            abort(404)

        selecionado = encontrados[0]
        dados = selecionado.__data__.copy()

    if request.method == "POST":
        acao = request.form.get("acao")

        if acao == "salvar":
            dados = request.form.to_dict()
            dados["marketplace"] = request.form.get("marketplace", "0")
            resultado = Contato.atualizar(dados)

        elif acao == "conversa":
            texto_conversa = request.form.get("texto", "")
            resultado = ContatoConversa.incluir(
                cd_contato, session["cd_usuario"], texto_conversa
            )

        else:
            abort(400)

        if resultado["sucesso"]:
            return redirect(url_for(
                "adm_contato", editar=cd_contato, sucesso=acao
            ))

        erro = resultado["erro"]
        
    if selecionado is not None:
        status = Contato.opcoes(cd_contato)
        conversas = ContatoConversa.buscar(cd_contato)
    else:
        status = Contato.opcoes()
        conversas = []

    return render_template(
        "adm_contato.html",
        fila=fila,
        selecionado=selecionado,
        dados=dados,
        status=status,
        conversas=conversas,
        texto_conversa=texto_conversa,
        erro=erro,
        sucesso=request.args.get("sucesso"),
        finalizados=finalizados,
        hoje=date.today().isoformat(),
    )


@app.route("/adm/usuarios", methods=["GET", "POST"])
@login_obrigatorio
@acesso_administrativo
def adm_usuario():
    cd_operador = session["cd_usuario"]
    nivel = session["cd_nivel"]

    if nivel not in (0, 1, 2, 3, 4):
        abort(403)

    hoje = datetime.now(
        ZoneInfo("America/Sao_Paulo")
    ).date().isoformat()

    erro = None
    selecionado = None
    dados = {}
    usuario = {}
    cd_usuario = None

    if request.method == "POST":
        validar_csrf()
        formulario = request.form.to_dict()

        codigo_recebido = formulario.get("cd_usuario", "").strip()


        print("DEBUG USUARIO:",
              "cd_usuario =", repr(codigo_recebido),
              "acao =", formulario.get("acao"),
              flush=True
            )

        try:
            cd_usuario = (
                int(codigo_recebido)
                if codigo_recebido else None
            )
        except (ValueError, TypeError):
            abort(400)

        # Verificar permissões de acesso
        if cd_usuario is None:
            if nivel != 0:
                abort(403)
        else:
            encontrados = Usuario.buscar(
                cd_usuario=cd_usuario
            )

            if not encontrados:
                abort(404)

            registro = encontrados[0]

            if nivel == 1:
                if (
                    cd_usuario != cd_operador
                    and registro.cd_nivel not in (2, 3, 4)
                ):
                    abort(403)

            elif nivel >= 2 and cd_usuario != cd_operador:
                abort(403)

        # Dados da Pessoa
        dados = {
            campo: formulario.get(campo, "")
            for campo in (
                "tp_pessoa",
                "nm_pessoa",
                "cpf_cnpj",
                "telefone",
                "email"
            )
        }

        dados["dados"] = {
            campo: formulario.get(campo, "")
            for campo in (
                "endereco",
                "numero",
                "complemento",
                "bairro",
                "cep",
                "cidade",
                "uf"
            )
        }

        # Dados do Usuário
        usuario = {
            campo: formulario[campo]
            for campo in (
                "login",
                "cd_nivel",
                "fl_ativo"
            )
            if campo in formulario
        }

        acao = formulario.get("acao", "salvar")

        if acao == "salvar":
            if cd_usuario is None:
                resultado = CadastroUsuario.incluir(
                    cd_operador,
                    dados,
                    usuario
                )
            else:
                resultado = CadastroUsuario.atualizar(
                    cd_operador,
                    cd_usuario,
                    dados,
                    usuario
                )

            if resultado["sucesso"]:
                return redirect(
                    url_for("adm_usuario", sucesso=1)
                )

            erro = resultado["erro"]
            selecionado = cd_usuario

        else:
            abort(400)

    else:
        # Compatibilidade com links antigos: editar
        codigo_recebido = request.args.get(
            "cd_usuario",
            request.args.get("editar")
        )

        try:
            cd_usuario = (
                int(codigo_recebido)
                if codigo_recebido is not None else None
            )
        except (ValueError, TypeError):
            abort(400)

        # Níveis inferiores consultam somente a própria conta
        if nivel >= 2:
            if cd_usuario is not None and cd_usuario != cd_operador:
                abort(403)

            cd_usuario = cd_operador

        if cd_usuario is not None:
            encontrados = Usuario.buscar(
                cd_usuario=cd_usuario
            )

            if not encontrados:
                abort(404)

            registro = encontrados[0]

            if nivel == 1:
                if (
                    cd_usuario != cd_operador
                    and registro.cd_nivel not in (2, 3, 4)
                ):
                    abort(403)

            resultado = CadastroUsuario.buscar(cd_usuario)

            if resultado["sucesso"]:
                dados = resultado["dados"]
                usuario = resultado["usuario"]
                selecionado = cd_usuario
            else:
                erro = resultado["erro"]

    # Listagem conforme nível de acesso
    registros = CadastroUsuario.listar()

    if nivel >= 2:
        registros = [
            registro
            for registro in registros
            if registro["cd_usuario"] == cd_operador
        ]

    # Opções para seleção do nível
    niveis = (
        CadastroUsuario.niveis()
        if nivel == 0 else []
    )

    return render_template(
        "cadastro/cadastro.html",
        titulo="Usuários",
        tipo_cadastro="usuario",
        dados=dados,
        usuario=usuario,
        registros=registros,
        niveis=niveis,
        selecionado=selecionado,
        erro=erro,
        sucesso=request.args.get("sucesso") == "1",
        hoje=hoje,
        url_cadastro=url_for("adm_usuario"),
        url_novo=url_for("adm_usuario")
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
            destino = "cliente_inicio" if session["cd_nivel"] == 5 else "adm"
            return redirect(url_for(destino))

        erro = resultado["erro"]

    return render_template(
        "trocar_senha.html",
        obrigatoria=obrigatoria,
        erro=erro)


@app.route("/cadastro/<token>", methods=["GET", "POST"])
def cadastro_publico(token):

    if ClienteLink.validar(token) is None:
        return render_template(
            "cadastro/link_invalido.html"
        ), 403

    if request.method == "POST":

        # A validação CSRF deve ocorrer antes da gravação,
        # utilizando o mecanismo existente da aplicação.

        resultado = CadastroCliente.receber_precadastro(
            token,
            request.form
        )

        if resultado["sucesso"]:
            return render_template(
                "cadastro/cadastro_sucesso.html"
            )

        return render_template(
            "cadastro/pre_cadastro.html",
            token=token,
            dados=request.form.to_dict(),
            cliente=request.form.to_dict(),
            loja=request.form.to_dict(),
            erro=resultado["erro"]
        ), 400

    return render_template(
        "cadastro/pre_cadastro.html",
        token=token,
        dados={},
        cliente={},
        loja={}
    )


@app.route("/adm/cliente/links", methods=["GET", "POST"])
@login_obrigatorio
@acesso_administrativo
def adm_cliente_links():

    url_gerada = None
    erro = None

    # Disponível tanto no GET quanto no POST
    base_url = current_app.config["PUBLIC_BASE_URL"].rstrip("/")

    if request.method == "POST":
        try:
            resultado = ClienteLink.gerar(
                cd_usuario=session["cd_usuario"]
            )

            url_gerada = (
                f"{base_url}/cadastro/"
                f"{resultado['token']}"
            )

        except Exception:
            current_app.logger.exception(
                "Erro ao gerar link de cadastro"
            )
            erro = "Não foi possível gerar o link."

    links = ClienteLink.listar()

    return render_template(
        "cliente/links.html",
        links=links,
        base_url=base_url,
        url_gerada=url_gerada,
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
@acesso_administrativo
def resetar_senha_usuario(cd_usuario):
    validar_csrf()

    if session["cd_nivel"] != 0:
        abort(403)

    resultado = Usuario.resetar_senha(session["cd_usuario"], cd_usuario)

    if not resultado["sucesso"]:
        abort(404)

    return redirect(url_for("adm_usuario", senha_resetada=1))


@app.route("/cliente")
@login_obrigatorio
def cliente_inicio():
    if session["cd_nivel"] != 5:
        abort(403)
    return render_template("cliente/inicio.html")



@app.route("/cliente/conta")
@login_obrigatorio
def cliente_conta():

    if session["cd_nivel"] != 5:
        abort(403)

    resultado = MinhaConta.consultar(
        session["cd_usuario"]
    )

    if not resultado["sucesso"]:
        abort(403)

    return render_template(
        "cliente/conta.html",
        cd_cliente=resultado["cd_cliente"],
        dados=resultado["dados"],
        cliente=resultado["cliente"],
        usuario=resultado["usuario"]
    )


@app.route("/adm/clientes", methods=["GET", "POST"])
@login_obrigatorio
@acesso_administrativo
def adm_cliente():

    # Permissão para acessar o cadastro de clientes
    if session["cd_nivel"] not in (0, 1):
        abort(403)

    hoje = datetime.now(
        ZoneInfo("America/Sao_Paulo")
    ).date().isoformat()

    # Inicialização dos dados do formulário
    dados = {}
    cliente = {"dt_cadastro": hoje}
    loja = {}
    lojas = []
    usuario = {}

    erro = None
    selecionado = None

    # ======================================================
    # POST - INCLUSÃO, ALTERAÇÃO E EXCLUSÃO
    # ======================================================
    if request.method == "POST":

        validar_csrf()

        formulario = request.form.to_dict()

        acao = formulario.get("acao", "salvar")
        cd_cliente = formulario.get("cd_cliente", "").strip()

        # --------------------------------------------------
        # EXCLUSÃO LÓGICA DO CLIENTE
        # --------------------------------------------------
        if acao == "excluir":

            if not cd_cliente.isdigit():
                erro = "Código do cliente não informado."

            else:
                resultado = Cliente.excluir(int(cd_cliente))

                if resultado["sucesso"]:
                    return redirect(
                        url_for("adm_cliente", excluido=1)
                    )

                erro = resultado["erro"]
                selecionado = int(cd_cliente)

        # --------------------------------------------------
        # INCLUSÃO OU ALTERAÇÃO DO CLIENTE
        # --------------------------------------------------
        elif acao == "salvar":

            # Dados de acesso do cliente
            usuario = {
                "login": formulario.get(
                    "usuario_login", ""
                ).strip(),

                "fl_ativo": (
                    formulario.get("usuario_fl_ativo", "1") == "1"
                ),

                "gerenciar_usuario": (
                    formulario.get("gerenciar_usuario") == "1"
                )
            }

            # O usuário é opcional.
            # Somente o Master pode criar ou alterar acesso.
            dados_usuario = None

            if usuario["gerenciar_usuario"]:

                if session["cd_nivel"] != 0:
                    abort(403)

                dados_usuario = {
                    "login": usuario["login"],
                    "fl_ativo": usuario["fl_ativo"]
                }

            # ----------------------------------------------
            # DADOS DA PESSOA
            # ----------------------------------------------
            dados = {
                campo: formulario.get(campo, "")
                for campo in (
                    "tp_pessoa",
                    "nm_pessoa",
                    "cpf_cnpj",
                    "telefone",
                    "email"
                )
            }

            # Endereço armazenado em JSONB
            dados["dados"] = {
                campo: formulario.get(campo, "")
                for campo in (
                    "endereco",
                    "numero",
                    "complemento",
                    "bairro",
                    "cep",
                    "cidade",
                    "uf"
                )
            }

            # ----------------------------------------------
            # DADOS DO CLIENTE
            # ----------------------------------------------
            cliente = {
                campo: formulario.get(campo, "")
                for campo in (
                    "nm_responsavel",
                    "cd_contato",
                    "dt_cadastro"
                )
            }

            # ----------------------------------------------
            # DADOS DA LOJA
            # ----------------------------------------------
            loja = {
                campo: formulario.get(campo, "")
                for campo in (
                    "cd_loja",
                    "nm_loja",
                    "shop_id",
                    "url_loja"
                )
            }

            lojas = (
                [loja]
                if any(valor.strip() for valor in loja.values())
                else []
            )

            # ----------------------------------------------
            # GRAVAÇÃO DO CLIENTE E USUÁRIO
            # ----------------------------------------------
            if cd_cliente:

                if not cd_cliente.isdigit():
                    erro = "Código do cliente inválido."

                else:
                    resultado = CadastroCliente.atualizar(
                        int(cd_cliente),
                        dados,
                        cliente,
                        lojas,
                        usuario=dados_usuario,
                        cd_operador=session["cd_usuario"]
                    )

                    if resultado["sucesso"]:
                        return redirect(
                            url_for("adm_cliente", sucesso=1)
                        )

                    erro = resultado["erro"]
                    selecionado = int(cd_cliente)

            else:

                resultado = CadastroCliente.incluir(
                    dados,
                    cliente,
                    lojas,
                    usuario=dados_usuario,
                    cd_operador=session["cd_usuario"]
                )

                if resultado["sucesso"]:
                    return redirect(
                        url_for("adm_cliente", sucesso=1)
                    )

                erro = resultado["erro"]

        else:
            abort(400)

    # ======================================================
    # LISTAGEM EXCLUSIVA DE CLIENTES
    # ======================================================
    registros = CadastroCliente.listar()

    # ======================================================
    # GET - CONSULTA DO CLIENTE SELECIONADO
    # ======================================================
    if request.method == "GET":

        cd_cliente = request.args.get(
            "cd_cliente",
            type=int
        )

        if cd_cliente is not None:

            resultado = CadastroCliente.buscar(cd_cliente)

            if resultado["sucesso"]:

                dados = resultado["dados"]
                cliente = resultado["cliente"]
                loja = resultado["loja"]
                lojas = resultado["lojas"]

                # Recupera o usuário vinculado ao cliente,
                # quando existir.
                usuario = resultado.get("usuario") or {}

                selecionado = cd_cliente

            else:
                erro = resultado["erro"]

    # ======================================================
    # RENDERIZAÇÃO DO FORMULÁRIO
    # ======================================================
    return render_template(
        "cadastro/cadastro.html",

        titulo="Clientes",
        tipo_cadastro="cliente",

        dados=dados,
        cliente=cliente,
        loja=loja,
        lojas=lojas,
        usuario=usuario,

        registros=registros,
        selecionado=selecionado,
        erro=erro,

        sucesso=request.args.get("sucesso") == "1",

        hoje=hoje,

        url_cadastro=url_for("adm_cliente"),
        url_novo=url_for("adm_cliente")
    )



@app.errorhandler(OperationalError)
def erro_conexao_banco(erro):
    app.logger.exception("Falha de conexão com o banco de dados.")

    return ("Não foi possível concluir a operação devido a uma falha de conexão.<br>"
            "Se estava salvando dados, confira se foram gravados antes de tentar novamente.<br>"
            "Por favor, atualize/recarregue esta página.",503)

# if __name__ == "__main__":
#     print(app.url_map)
#     app.run(host="0.0.0.0", port=5155, debug=True)


if __name__ == "__main__":
    print(app.url_map)
    app.run(
        host="0.0.0.0",
        port=5155,
        debug=True,
        use_reloader=False
    )    