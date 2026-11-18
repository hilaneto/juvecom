
from peewee import Model, BigAutoField, BigIntegerField, CharField, DateTimeField, SmallIntegerField, SQL, IntegrityError
from database.conexao import db, conectar
from datetime import date, datetime, time
from zoneinfo import ZoneInfo


class Cliente(Model):

    cd_cliente = BigAutoField()
    cd_pessoa = BigIntegerField(unique=True)
    nm_responsavel = CharField(max_length=150, null=True)
    cd_status = SmallIntegerField(default=1)
    dt_cadastro = DateTimeField(default=SQL("CURRENT_TIMESTAMP"))
    dt_atualizacao = DateTimeField(default=SQL("CURRENT_TIMESTAMP"))

    class Meta:
        database = db
        table_name = "tb_cliente"

    @staticmethod
    def buscar(cd_cliente=None, cd_pessoa=None, cd_status=None):
        with conectar():
            consulta = Cliente.select()

            if cd_cliente is not None:
                consulta = consulta.where(Cliente.cd_cliente == cd_cliente)

            if cd_pessoa is not None:
                consulta = consulta.where(Cliente.cd_pessoa == cd_pessoa)

            if cd_status is not None:
                consulta = consulta.where(Cliente.cd_status == cd_status)

            return list(consulta.order_by(Cliente.cd_cliente))

    @staticmethod
    def incluir(dados: dict):
        try:
            cd_pessoa = int(dados.get("cd_pessoa"))
        except (ValueError, TypeError):
            return {"sucesso": False, "erro": "Código da pessoa inválido."}

        nm_responsavel = (dados.get("nm_responsavel") or "").strip() or None

        if nm_responsavel and len(nm_responsavel) > 150:
            return {"sucesso": False, "erro": "O responsável deve ter até 150 caracteres."}

        try:
            cd_status = int(dados.get("cd_status", 1))
            if cd_status not in (1, 2, 3, 4, 5):
                raise ValueError()
        except (ValueError, TypeError):
            return {"sucesso": False, "erro": "Situação do cliente inválida."}

        data_informada = dados.get("dt_cadastro")

        if data_informada:
            try:
                data = date.fromisoformat(data_informada) if isinstance(data_informada, str) else data_informada
                dt_cadastro = datetime.combine(data, time.min, tzinfo=ZoneInfo("America/Sao_Paulo"))
            except (ValueError, TypeError):
                return {"sucesso": False, "erro": "Data de cadastro inválida."}
        else:
            dt_cadastro = datetime.now(ZoneInfo("America/Sao_Paulo"))

        try:
            with conectar():
                cliente = Cliente.create(
                    cd_pessoa=cd_pessoa,
                    nm_responsavel=nm_responsavel,
                    cd_status=cd_status,
                    dt_cadastro=dt_cadastro
                )

        except IntegrityError:
            return {"sucesso": False, "erro": "Não foi possível cadastrar. Verifique se a pessoa já possui cadastro de cliente."}

        return {"sucesso": True, "cd_cliente": cliente.cd_cliente}

    @staticmethod
    def atualizar(dados: dict):
        try:
            cd_cliente = int(dados.get("cd_cliente"))
        except (ValueError, TypeError):
            return {"sucesso": False, "erro": "Informe o código do cliente."}

        permitidos = {"nm_responsavel", "cd_status"}
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

        if "cd_status" in campos:
            try:
                cd_status = int(campos["cd_status"])
                if cd_status not in (1, 2, 3, 4, 5):
                    raise ValueError()
                campos["cd_status"] = cd_status
            except (ValueError, TypeError):
                return {"sucesso": False, "erro": "Situação do cliente inválida."}

        try:
            with conectar():
                campos["dt_atualizacao"] = SQL("CURRENT_TIMESTAMP")
                alterados = (
                    Cliente.update(**campos)
                    .where(Cliente.cd_cliente == cd_cliente)
                    .execute()
                )

        except IntegrityError:
            return {"sucesso": False, "erro": "Não foi possível atualizar o cadastro do cliente."}

        if not alterados:
            return {"sucesso": False, "erro": "Cliente não encontrado."}

        return {"sucesso": True, "cd_cliente": cd_cliente}

    @staticmethod
    def excluir(cd_cliente):
        return Cliente.atualizar({
            "cd_cliente": cd_cliente,
            "cd_status": 5
        })
