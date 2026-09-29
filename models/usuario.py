from peewee import Model, BigAutoField, BigIntegerField, SmallIntegerField, CharField, TextField, BooleanField, DateTimeField, SQL
from werkzeug.security import generate_password_hash, check_password_hash
from database.conexao import db, conectar

class Usuario(Model):
    cd_usuario = BigAutoField()
    cd_pessoa = BigIntegerField()
    cd_nivel = SmallIntegerField()
    login = CharField(max_length=100)
    senha_hash = TextField()
    fl_ativo = BooleanField()
    dt_atualizacao = DateTimeField()

    class Meta:
        database = db
        table_name = "tb_usuario"


    @staticmethod
    def incluir(dados: dict):
        cd_pessoa = dados.get("cd_pessoa")
        cd_nivel = dados.get("cd_nivel")
        login = (dados.get("login") or "").strip()
        senha = dados.get("senha")        

        if not cd_pessoa or not cd_nivel:
            return {"sucesso": False, "erro": "Pessoa e nível são obrigatórios."}

        if not login or not isinstance(senha, str) or not senha.strip():
            return {"sucesso": False, "erro": "Login e senha são obrigatórios."}
        
        with conectar():
            Usuario.create(cd_pessoa=cd_pessoa, cd_nivel=cd_nivel, login=login, senha_hash=generate_password_hash(senha), fl_ativo=True)
            return {"sucesso": True, "cd_usuario": Usuario.login}

    @staticmethod
    def buscar(cd_usuario=None, cd_status=None):
        with conectar():
            consulta = Usuario.select()

            if cd_usuario is not None:
                consulta = consulta.where(Usuario.cd_usuario == cd_usuario)

            if cd_status is not None:
                consulta = consulta.where(Usuario.cd_status == cd_status)

            return list(consulta.order_by(Usuario.dt_atualizacao.desc()))

    @staticmethod
    def buscar_ativo(cd_usuario):
        with conectar():
            return Usuario.get_or_none((Usuario.cd_usuario == cd_usuario) & (Usuario.fl_ativo == True))

    @staticmethod
    def atualizar(dados: dict):
        cd_usuario = dados.get("cd_usuario")
        if not cd_usuario:
            return {"sucesso": False, "erro": "Informe o código do usuário."}

        permitidos = {"login", "senha", "cd_nivel"}
        campos = {chave: valor for chave, valor in dados.items() if chave in permitidos}

        if not campos:
            return {"sucesso": False, "erro": "Informe um campo para atualizar."}

        if "login" in campos:
            login = campos["login"]
            if not isinstance(login, str) or not login.strip():
                return {"sucesso": False, "erro": "O login não pode ficar vazio."}
            campos["login"] = login.strip()

        if "senha" in campos:
            senha = campos.pop("senha")
            if not isinstance(senha, str) or not senha.strip():
                return {"sucesso": False, "erro": "A senha não pode ficar vazia."}
                
            campos["senha_hash"] = generate_password_hash(senha)

        if "cd_nivel" in campos and not campos["cd_nivel"]:
            return {"sucesso": False, "erro": "Informe o nível do usuário."}

        campos["dt_atualizacao"] = SQL("CURRENT_TIMESTAMP")

        with conectar():
            alterados = (Usuario.update(**campos).where(Usuario.cd_usuario == cd_usuario).execute())

        return ({"sucesso": True, "cd_usuario": cd_usuario}
                if alterados
                else {"sucesso": False, "erro": "Usuário não encontrado."})


    @staticmethod
    def autenticar(login, senha):
        if not login or not senha:
            return None

        with conectar():
            usuario = Usuario.get_or_none( (Usuario.login == login.strip()) & (Usuario.fl_ativo == True) )
            if usuario and check_password_hash(usuario.senha_hash, senha):
                return usuario

        return None
