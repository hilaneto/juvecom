from peewee import Model, BigAutoField, BigIntegerField, CharField, BooleanField, DateTimeField, SQL, IntegrityError
from database.conexao import db, conectar
from datetime import date, datetime, time
from zoneinfo import ZoneInfo

class Cliente(Model):
    cd_cliente = BigAutoField()
    cd_pessoa = BigIntegerField(unique=True)
    nm_responsavel = CharField(max_length=150, null=True)
    fl_ativo = BooleanField(default=True)
    cd_contato = BigIntegerField(unique=True, null=True)
    dt_cadastro = DateTimeField(default=SQL("CURRENT_TIMESTAMP"))
    dt_atualizacao = DateTimeField(default=SQL("CURRENT_TIMESTAMP"))

    class Meta:
        database = db
        table_name = "tb_cliente"

    @staticmethod
    def buscar(cd_cliente=None, cd_pessoa=None, fl_ativo=None):
        with conectar():
            consulta = Cliente.select()

            if cd_cliente is not None:
                consulta = consulta.where(Cliente.cd_cliente == cd_cliente)

            if cd_pessoa is not None:
                consulta = consulta.where(Cliente.cd_pessoa == cd_pessoa)

            if fl_ativo is not None:
                consulta = consulta.where(Cliente.fl_ativo == fl_ativo)

            return list(consulta.order_by(Cliente.cd_cliente))


    @staticmethod
    def incluir(dados: dict):
        try:
            cd_pessoa = int(dados.get("cd_pessoa"))
            cd_contato = dados.get("cd_contato")
            cd_contato = int(cd_contato) if cd_contato not in (None, "") else None
        except (ValueError, TypeError):
            return {"sucesso": False, "erro": "Código da pessoa ou do contato inválido."}

        nm_responsavel = (dados.get("nm_responsavel") or "").strip() or None

        if nm_responsavel and len(nm_responsavel) > 150:
            return {"sucesso": False, "erro": "O responsável deve ter até 150 caracteres."}

        try:
            data = date.fromisoformat(dados.get("dt_cadastro") or "")
            dt_cadastro = datetime.combine(data, time.min, tzinfo=ZoneInfo("America/Sao_Paulo"))
        except (ValueError, TypeError):
            return {"sucesso": False, "erro": "Data de cadastro inválida."}

        try:
            with conectar():
                cliente = Cliente.create(
                    cd_pessoa=cd_pessoa,
                    cd_contato=cd_contato,
                    nm_responsavel=nm_responsavel,
                    dt_cadastro=dt_cadastro
                )

        except IntegrityError:
            return {"sucesso": False, "erro": "Não foi possível cadastrar. Verifique se a pessoa já é cliente ou se o contato já foi convertido."}

        return {"sucesso": True, "cd_cliente": cliente.cd_cliente}


    @staticmethod
    def atualizar(dados: dict):
        try:
            cd_cliente = int(dados.get("cd_cliente"))
        except (ValueError, TypeError):
            return {"sucesso": False, "erro": "Informe o código do cliente."}

        permitidos = {"nm_responsavel", "fl_ativo", "cd_contato"}
        campos = {chave: valor for chave, valor in dados.items() if chave in permitidos}

        if not campos:
            return {"sucesso": False, "erro": "Informe um campo para atualizar."}

        if "nm_responsavel" in campos:
            valor = campos["nm_responsavel"]

            if valor is not None and not isinstance(valor, str):
                return {"sucesso": False, "erro": "O responsável deve ser um texto."}

            campos["nm_responsavel"] = (valor or "").strip() or None

            if campos["nm_responsavel"] and len(campos["nm_responsavel"]) > 150:
                return {"sucesso": False, "erro": "O responsável deve ter até 150 caracteres."}

        if "cd_contato" in campos:
            try:
                valor = campos["cd_contato"]
                campos["cd_contato"] = int(valor) if valor not in (None, "") else None
            except (ValueError, TypeError):
                return {"sucesso": False, "erro": "Código do contato inválido."}

        if "fl_ativo" in campos and not isinstance(campos["fl_ativo"], bool):
            return {"sucesso": False, "erro": "fl_ativo deve ser True ou False."}

        try:
            with conectar():
                campos["dt_atualizacao"] = SQL("CURRENT_TIMESTAMP")
                alterados = Cliente.update(**campos).where(Cliente.cd_cliente == cd_cliente).execute()

        except IntegrityError:
            return {"sucesso": False, "erro": "Não foi possível atualizar. Verifique se o contato já está vinculado a outro cliente."}

        if not alterados:
            return {"sucesso": False, "erro": "Cliente não encontrado."}

        return {"sucesso": True, "cd_cliente": cd_cliente}

    @staticmethod
    def excluir(cd_cliente):
        return Cliente.atualizar({"cd_cliente": cd_cliente, "fl_ativo": False})