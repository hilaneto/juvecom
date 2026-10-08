from peewee import Model, BigAutoField, BigIntegerField, SmallIntegerField, CharField, TextField, DateTimeField, BooleanField, SQL
from database.conexao import db, conectar
from datetime import datetime
from zoneinfo import ZoneInfo

class Contato(Model):
    cd_contato = BigAutoField()
    nm_contato = CharField(max_length=150)
    celular = CharField(max_length=20, null=False)
    email = CharField(max_length=150, null=True)
    mensagem = TextField(null=True)
    marketplace = BooleanField(default=False)
    cd_plano = BigIntegerField(null=True)
    cd_contrato = BigIntegerField(null=True)
    cd_status = SmallIntegerField(null=False)
    dt_cadastro = DateTimeField(default=SQL("CURRENT_TIMESTAMP"))
    dt_atualizacao = DateTimeField(default=SQL("CURRENT_TIMESTAMP"))

    class Meta:
        database = db
        table_name = "tb_contato"


    @staticmethod
    def incluir(dados: dict):
        nm_contato = (dados.get("nm_contato") or "").strip()
        celular = (dados.get("celular") or "").strip()
        email = (dados.get("email") or "").strip() or None
        mensagem = (dados.get("mensagem") or "").strip() or None
        marketplace = dados.get("marketplace") in (True, "1")
        if not (nm_contato and celular):
            return {"sucesso": False, "erro": "Nome e celular são campos obrigatórios"}
        with conectar():
            Contato.create(nm_contato=nm_contato, celular=celular, email=email, mensagem=mensagem, cd_plano=dados.get("cd_plano"), cd_status=1, marketplace=marketplace)
            return {"sucesso": True, "Nome": nm_contato}
    

    @staticmethod
    def buscar(cd_contato=None, cd_status=None):
        with conectar():
            consulta = Contato.select()

            if cd_contato is not None:
                consulta = consulta.where(Contato.cd_contato == cd_contato)

            if cd_status is not None:
                consulta = consulta.where(Contato.cd_status == cd_status)

            return list(consulta.order_by(Contato.dt_cadastro.desc()))


    @staticmethod
    def atualizar(dados: dict):
        cd_contato = dados.get("cd_contato")
        if not cd_contato:
            return {"sucesso": False, "erro": "Informe o código do contato."}

        permitidos = {"nm_contato", "celular", "email", "mensagem", "cd_plano", "cd_contrato", "cd_status"}
        campos = {chave: valor for chave, valor in dados.items() if chave in permitidos}

        if not campos:
            return {"sucesso": False, "erro": "Informe um campo para atualizar."}

        for campo in ("nm_contato", "celular"):
            if campo in campos and not (campos[campo] or "").strip():
                return {"sucesso": False, "erro": f"{campo} não pode ficar vazio."}

        for campo in ("nm_contato", "celular", "email", "mensagem"):
            if campo in campos:
                campos[campo] = (campos[campo] or "").strip() or None

        if campos.get("cd_status", 1) is None:
            return {"sucesso": False, "erro": "Informe o status do contato."}

        campos["dt_atualizacao"] = SQL("CURRENT_TIMESTAMP")

        with conectar():
            alterados = (Contato.update(**campos).where(Contato.cd_contato == cd_contato).execute())

        return ({"sucesso": True, "cd_contato": cd_contato} if alterados
                else {"sucesso": False, "erro": "Contato não encontrado."})


    @staticmethod
    def excluir(cd_contato):
        with conectar():
            alterados = (Contato.update(cd_status=5, dt_atualizacao=SQL("CURRENT_TIMESTAMP")).where(Contato.cd_contato == cd_contato).execute())
        if not alterados:
            return {"sucesso": False, "erro": "Contato não encontrado."}
        return {"sucesso": True, "cd_contato": cd_contato}


    @staticmethod
    def por_prazo():
        fuso = ZoneInfo("America/Sao_Paulo")
        hoje = datetime.now(fuso).date()
        grupos = {"atrasados": [], "recentes": [], "hoje": []}

        with conectar():
            contatos = list(Contato.select().where(Contato.cd_status == 1).order_by(Contato.dt_cadastro))

        for contato in contatos:
            cadastro = contato.dt_cadastro.astimezone(fuso).date()
            dias = (hoje - cadastro).days

            if dias >= 3:
                grupos["atrasados"].append(contato)
            elif dias in (1, 2):
                grupos["recentes"].append(contato)
            elif dias == 0:
                grupos["hoje"].append(contato)

        return grupos


    @staticmethod
    def pendentes():
        with conectar():
            return list(Contato.select().where(Contato.cd_status.in_([1,3])).order_by(Contato.dt_cadastro))
            

