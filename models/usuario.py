from peewee import Model, BigAutoField, BigIntegerField, SmallIntegerField, CharField, TextField, BooleanField, DateTimeField, SQL, IntegrityError
from werkzeug.security import generate_password_hash, check_password_hash
from database.conexao import db, conectar
from models.pessoa import Pessoa
from suporte.validacao import somente_numeros

SENHA_INICIAL = "jps123"


class Usuario(Model):
    cd_usuario = BigAutoField()
    cd_pessoa = BigIntegerField()
    cd_nivel = SmallIntegerField()
    login = CharField(max_length=100)
    senha_hash = TextField()
    fl_ativo = BooleanField(default=True)
    dt_atualizacao = DateTimeField(default=SQL("CURRENT_TIMESTAMP"))

    class Meta:
        database = db
        table_name = "tb_usuario"

    @staticmethod
    def incluir(dados: dict):
        cd_pessoa = dados.get("cd_pessoa")
        cd_nivel = dados.get("cd_nivel")
        login = (dados.get("login") or "").strip()
        senha = dados.get("senha", SENHA_INICIAL)

        if cd_pessoa in (None, "") or cd_nivel in (None, ""):
            return {"sucesso": False, "erro": "Pessoa e nível são obrigatórios."}

        if not login:
            return {"sucesso": False, "erro": "Informe o login."}

        if not isinstance(senha, str) or not senha.strip() or len(senha) < 6:
            return {"sucesso": False, "erro": "A senha deve ter no mínimo 6 caracteres."}

        try:
            with conectar():
                usuario = Usuario.create(
                    cd_pessoa=cd_pessoa, cd_nivel=cd_nivel, login=login,
                    senha_hash=generate_password_hash(senha), fl_ativo=True
                )
        except IntegrityError:
            return {"sucesso": False, "erro": "Confira pessoa, nível e login. Pessoa ou login podem já estar cadastrados."}

        return {"sucesso": True, "cd_usuario": usuario.cd_usuario}

    @staticmethod
    def buscar(cd_usuario=None, fl_ativo=None):
        with conectar():
            consulta = UsuarioView.select()

            if cd_usuario is not None:
                consulta = consulta.where(UsuarioView.cd_usuario == cd_usuario)

            if fl_ativo is not None:
                consulta = consulta.where(UsuarioView.fl_ativo == fl_ativo)

            return list(consulta.order_by(UsuarioView.cd_nivel, UsuarioView.login))

    @staticmethod
    def opcoes():
        with conectar():
            pessoas = list(
                PessoaOpcao.select()
                .where(PessoaOpcao.cd_pessoa.not_in(Usuario.select(Usuario.cd_pessoa)))
                .order_by(PessoaOpcao.nm_pessoa)
            )
            niveis = list(NivelOpcao.select().order_by(NivelOpcao.cd_nivel))

        return pessoas, niveis

    @staticmethod
    def atualizar(dados: dict):
        cd_usuario = dados.get("cd_usuario")

        if cd_usuario in (None, ""):
            return {"sucesso": False, "erro": "Informe o código do usuário."}

        permitidos = {"login", "cd_nivel"}
        campos = {chave: valor for chave, valor in dados.items() if chave in permitidos}

        if "login" in campos:
            login = campos["login"]
            if not isinstance(login, str) or not login.strip():
                return {"sucesso": False, "erro": "O login não pode ficar vazio."}
            campos["login"] = login.strip()

        if "cd_nivel" in campos and campos["cd_nivel"] in (None, ""):
            return {"sucesso": False, "erro": "Informe o nível do usuário."}

        senha = dados.get("senha")

        if senha not in (None, ""):
            if not isinstance(senha, str) or not senha.strip() or len(senha) < 6:
                return {"sucesso": False, "erro": "A senha deve ter no mínimo 6 caracteres."}
            campos["senha_hash"] = generate_password_hash(senha)

        if not campos:
            return {"sucesso": False, "erro": "Informe um campo para atualizar."}

        campos["dt_atualizacao"] = SQL("CURRENT_TIMESTAMP")

        try:
            with conectar():
                alterados = Usuario.update(**campos).where(Usuario.cd_usuario == cd_usuario).execute()
        except IntegrityError:
            return {"sucesso": False, "erro": "Confira o nível e verifique se o login já está cadastrado."}

        return (
            {"sucesso": True, "cd_usuario": cd_usuario} if alterados
            else {"sucesso": False, "erro": "Usuário não encontrado."}
        )

    @staticmethod
    def excluir(cd_usuario):
        if cd_usuario in (None, ""):
            return {"sucesso": False, "erro": "Informe o código do usuário."}

        with conectar():
            alterados = (
                Usuario.update(fl_ativo=False, dt_atualizacao=SQL("CURRENT_TIMESTAMP"))
                .where(Usuario.cd_usuario == cd_usuario).execute()
            )

        return ({"sucesso": True, "cd_usuario": cd_usuario} if alterados
                else {"sucesso": False, "erro": "Usuário não encontrado."})

    @staticmethod
    def autenticar(login, senha):
        if not isinstance(login, str) or not isinstance(senha, str):
            return {"status": 0, "usuario": None}

        if not login.strip() or not senha:
            return {"status": 0, "usuario": None}

        with conectar():
            usuario = Usuario.get_or_none((Usuario.login == login.strip()) & (Usuario.fl_ativo == True))

            if usuario is None or not check_password_hash(usuario.senha_hash, senha):
                return {"status": 0, "usuario": None}

            status = 2 if check_password_hash(usuario.senha_hash, SENHA_INICIAL) else 1

        return {"status": status, "usuario": usuario}

    @staticmethod
    def precisa_trocar_senha(cd_usuario):
        with conectar():
            usuario = Usuario.get_or_none((Usuario.cd_usuario == cd_usuario) & (Usuario.fl_ativo == True))

            return (usuario is not None and check_password_hash(usuario.senha_hash, SENHA_INICIAL))

    @staticmethod
    def trocar_senha(cd_usuario, senha, confirmacao, senha_atual=None):
        if not isinstance(senha, str) or not senha.strip() or len(senha) < 6:
            return {"sucesso": False, "erro": "A senha deve ter no mínimo 6 caracteres."}

        if senha != confirmacao:
            return {"sucesso": False, "erro": "As senhas não conferem."}

        if senha == SENHA_INICIAL:
            return {"sucesso": False, "erro": "Escolha uma senha diferente da senha inicial."}

        with conectar():
            with db.atomic():
                usuario = (Usuario.select().where((Usuario.cd_usuario == cd_usuario) & (Usuario.fl_ativo == True)).for_update().first())

                if usuario is None:
                    return {"sucesso": False, "erro": "Usuário não encontrado ou inativo."}

                obrigatoria = check_password_hash(usuario.senha_hash, SENHA_INICIAL)

                if not obrigatoria:
                    if (
                        not isinstance(senha_atual, str)
                        or not check_password_hash(usuario.senha_hash, senha_atual)
                    ):
                        return {"sucesso": False, "erro": "A senha atual não confere."}

                (Usuario.update(senha_hash=generate_password_hash(senha), dt_atualizacao=SQL("CURRENT_TIMESTAMP")).where(Usuario.cd_usuario == cd_usuario).execute())

        return {"sucesso": True, "cd_usuario": cd_usuario}

    @staticmethod
    def trocar_senha_inicial(cd_usuario, senha, confirmacao):
        return Usuario.trocar_senha(cd_usuario, senha, confirmacao)

    @staticmethod
    def salvar_autorizado(cd_operador, dados: dict):
        try:
            codigo = dados.get("cd_usuario")
            cd_usuario = None if codigo in (None, "") else int(codigo)
        except (ValueError, TypeError):
            return {"sucesso": False, "erro": "Código do usuário inválido."}

        try:
            with conectar():
                with db.atomic():
                    usuarios = list(Usuario.select().order_by(Usuario.cd_usuario).for_update())
                    operador = next((u for u in usuarios if u.cd_usuario == cd_operador), None)

                    if operador is None or not operador.fl_ativo:
                        return {"sucesso": False, "erro": "Operador não autorizado."}

                    nivel = operador.cd_nivel
                    novo = cd_usuario is None
                    usuario = next((u for u in usuarios if u.cd_usuario == cd_usuario), None)

                    if nivel not in (0, 1, 2, 3, 4):
                        return {"sucesso": False, "erro": "Nível não autorizado."}

                    if novo and nivel != 0:
                        return {"sucesso": False, "erro": "Somente Master pode incluir usuários."}

                    if not novo and usuario is None:
                        return {"sucesso": False, "erro": "Usuário não encontrado."}

                    if not novo and nivel >= 2 and cd_usuario != cd_operador:
                        return {"sucesso": False, "erro": "Você pode alterar somente a própria senha."}

                    campos = {}

                    if nivel == 0:
                        if novo or "login" in dados:
                            login = dados.get("login")
                            if not isinstance(login, str) or not login.strip():
                                return {"sucesso": False, "erro": "Informe o login."}
                            if len(login.strip()) > 100:
                                return {"sucesso": False, "erro": "O login deve ter até 100 caracteres."}
                            campos["login"] = login.strip()

                        if novo or "cd_nivel" in dados:
                            try:
                                cd_nivel = int(dados.get("cd_nivel"))
                            except (ValueError, TypeError):
                                return {"sucesso": False, "erro": "Informe o nível."}

                            if not NivelOpcao.select().where(NivelOpcao.cd_nivel == cd_nivel).exists():
                                return {"sucesso": False, "erro": "Nível não encontrado."}

                            campos["cd_nivel"] = cd_nivel

                    elif "login" in dados or "cd_nivel" in dados:
                        return {"sucesso": False, "erro": "Somente Master pode alterar login e nível."}


                    if novo:
                        documento = dados.get("documento_pessoa")

                        if not isinstance(documento, str) or not documento.strip():
                            return {"sucesso": False, "erro": "Informe o CPF/CNPJ da pessoa."}

                        documento = somente_numeros(documento)

                        if len(documento) not in (11, 14):
                            return {"sucesso": False, "erro": "O CPF deve ter 11 dígitos e o CNPJ, 14."}

                        pessoa = (
                            Pessoa.select()
                            .where(Pessoa.cpf_cnpj == documento)
                            .for_update().first()
                        )

                        if pessoa is None:
                            return {"sucesso": False, "erro": "Nenhuma pessoa cadastrada com esse CPF/CNPJ."}

                        if not pessoa.fl_ativo:
                            return {"sucesso": False, "erro": "Essa pessoa está inativa."}

                        if Usuario.select().where(Usuario.cd_pessoa == pessoa.cd_pessoa).exists():
                            return {"sucesso": False, "erro": "Essa pessoa já possui um usuário cadastrado."}

                        campos["cd_pessoa"] = pessoa.cd_pessoa
                        campos["fl_ativo"] = True
                        campos["senha_hash"] = generate_password_hash(SENHA_INICIAL)


                    else:
                        if "fl_ativo" in dados:
                            permitido = nivel == 0 or (nivel == 1 and usuario.cd_nivel in (2, 3, 4))

                            if not permitido:
                                return {"sucesso": False, "erro": "Você não pode alterar a situação desse usuário."}

                            valor = dados["fl_ativo"]
                            if str(valor) not in ("0", "1", "True", "False"):
                                return {"sucesso": False, "erro": "Situação inválida."}

                            ativo = str(valor) in ("1", "True")

                            if cd_usuario == cd_operador and not ativo:
                                return {"sucesso": False, "erro": "Você não pode desativar o próprio usuário."}

                            campos["fl_ativo"] = ativo

                        senha = dados.get("senha")

                        if senha not in (None, ""):
                            if nivel != 0 and cd_usuario != cd_operador:
                                return {"sucesso": False, "erro": "Você pode alterar somente a própria senha."}

                            if not isinstance(senha, str) or not senha.strip() or len(senha) < 6:
                                return {"sucesso": False, "erro": "A senha deve ter no mínimo 6 caracteres."}

                            campos["senha_hash"] = generate_password_hash(senha)

                        if usuario.fl_ativo and usuario.cd_nivel == 0:
                            continua_master = (campos.get("fl_ativo", usuario.fl_ativo)
                                               and campos.get("cd_nivel", usuario.cd_nivel) == 0)
                            
                            quantidade = sum(u.fl_ativo and u.cd_nivel == 0 for u in usuarios)

                            if not continua_master and quantidade <= 1:
                                return {"sucesso": False, "erro": "É necessário manter pelo menos um Master ativo."}

                    if not campos:
                        return {"sucesso": False, "erro": "Informe um campo para atualizar."}

                    campos["dt_atualizacao"] = SQL("CURRENT_TIMESTAMP")

                    if novo:
                        usuario = Usuario.create(**campos)
                        cd_usuario = usuario.cd_usuario
                    else:
                        Usuario.update(**campos).where(Usuario.cd_usuario == cd_usuario).execute()

        except IntegrityError:
            return {"sucesso": False, "erro": "Confira pessoa, nível e login. Pessoa ou login podem já estar cadastrados."}

        return {"sucesso": True, "cd_usuario": cd_usuario}


    @staticmethod
    def resetar_senha(cd_operador, cd_usuario):
        with conectar():
            with db.atomic():
                operador = Usuario.get_or_none(
                    (Usuario.cd_usuario == cd_operador)
                    & (Usuario.fl_ativo == True)
                    & (Usuario.cd_nivel == 0)
                )

                if operador is None:
                    return {"sucesso": False, "erro": "Somente Master pode resetar senhas."}

                alterados = (
                    Usuario.update(
                        senha_hash=generate_password_hash(SENHA_INICIAL),
                        dt_atualizacao=SQL("CURRENT_TIMESTAMP")
                    ).where(Usuario.cd_usuario == cd_usuario).execute())

        return ({"sucesso": True} if alterados
                else {"sucesso": False, "erro": "Usuário não encontrado."})



class UsuarioView(Model):
    cd_usuario = BigIntegerField(primary_key=True)
    cd_pessoa = BigIntegerField()
    nm_pessoa = CharField(max_length=150)
    login = CharField(max_length=100)
    cd_nivel = SmallIntegerField()
    nm_nivel = CharField(max_length=30, null=True)
    fl_ativo = BooleanField()
    dt_atualizacao = DateTimeField()

    class Meta:
        database = db
        table_name = "vw_usuario"


class PessoaOpcao(Model):
    cd_pessoa = BigIntegerField(primary_key=True)
    nm_pessoa = CharField(max_length=150)

    class Meta:
        database = db
        table_name = "tb_pessoa"


class NivelOpcao(Model):
    cd_nivel = SmallIntegerField(primary_key=True)
    nm_nivel = CharField(max_length=30)

    class Meta:
        database = db
        table_name = "tb_usuario_nivel"