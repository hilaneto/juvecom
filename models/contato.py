
from datetime import datetime
from zoneinfo import ZoneInfo
from peewee import Model, BigAutoField, CharField, TextField, BooleanField, SmallIntegerField, DateTimeField, SQL, IntegrityError
from database.conexao import db, conectar
from models.contato_status import ContatoStatus


class Contato(Model):
    cd_contato = BigAutoField()
    nm_contato = CharField(max_length=150)
    celular = CharField(max_length=20)
    email = CharField(max_length=150, null=True)
    mensagem = TextField(null=True)
    marketplace = BooleanField(default=False)
    cd_status = SmallIntegerField()
    dt_cadastro = DateTimeField(default=datetime.now)
    dt_atualizacao = DateTimeField(default=datetime.now)

    class Meta:
        database = db
        table_name = "tb_contato"

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
    def incluir(dados: dict):
        nm_contato = (dados.get("nm_contato") or "").strip()
        celular = (dados.get("celular") or "").strip()
        email = (dados.get("email") or "").strip() or None
        mensagem = (dados.get("mensagem") or "").strip() or None
        marketplace = dados.get("marketplace") in (True, "1")

        if not nm_contato or not celular:
            return {"sucesso": False, "erro": "Nome e celular são campos obrigatórios."}

        if len(nm_contato) > 150 or len(celular) > 20 or (email and len(email) > 150):
            return {"sucesso": False, "erro": "Um ou mais campos excedem o tamanho permitido."}

        try:
            with conectar():
                contato = Contato.create(
                    nm_contato=nm_contato,
                    celular=celular,
                    email=email,
                    mensagem=mensagem,
                    marketplace=marketplace,
                    cd_status=1
                )
                return {"sucesso": True, "Nome": nm_contato, "cd_contato": contato.cd_contato}

        except IntegrityError:
            return {"sucesso": False, "erro": "Não foi possível cadastrar o contato."}

    @staticmethod
    def atualizar(dados: dict):
        try:
            cd_contato = int(dados.get("cd_contato"))
        except (ValueError, TypeError):
            return {"sucesso": False, "erro": "Informe o código do contato."}

        permitidos = {
            "nm_contato", "celular", "email", "mensagem",
            "marketplace", "cd_status"
        }
        campos = {chave: valor for chave, valor in dados.items() if chave in permitidos}

        if not campos:
            return {"sucesso": False, "erro": "Informe um campo para atualizar."}

        for campo, limite in (("nm_contato", 150), ("celular", 20), ("email", 150), ("mensagem", None)):
            if campo not in campos:
                continue

            valor = campos[campo]

            if valor is not None and not isinstance(valor, str):
                return {"sucesso": False, "erro": f"{campo} deve ser um texto."}

            valor = (valor or "").strip()

            if campo in ("nm_contato", "celular") and not valor:
                return {"sucesso": False, "erro": "Nome e celular são obrigatórios."}

            if limite is not None and len(valor) > limite:
                return {"sucesso": False, "erro": f"{campo} deve ter até {limite} caracteres."}

            campos[campo] = valor or None

        if "cd_status" in campos:
            try:
                campos["cd_status"] = int(campos["cd_status"])
            except (ValueError, TypeError):
                return {"sucesso": False, "erro": "Status inválido."}

        if "marketplace" in campos:
            campos["marketplace"] = campos["marketplace"] in (True, "1")

        try:
            with conectar():
                with db.atomic():
                    contato = (
                        Contato.select()
                        .where(Contato.cd_contato == cd_contato)
                        .for_update()
                        .first()
                    )

                    if contato is None:
                        return {"sucesso": False, "erro": "Contato não encontrado."}

                    if "cd_status" in campos:
                        existe = ContatoStatus.select().where(
                            ContatoStatus.cd_status == campos["cd_status"]
                        ).exists()

                        if not existe:
                            return {"sucesso": False, "erro": "Status não encontrado."}

                    campos["dt_atualizacao"] = SQL("CURRENT_TIMESTAMP")

                    Contato.update(**campos).where(
                        Contato.cd_contato == cd_contato
                    ).execute()

        except IntegrityError:
            return {"sucesso": False, "erro": "Não foi possível atualizar o contato."}

        return {"sucesso": True, "cd_contato": cd_contato}

    @staticmethod
    def excluir(cd_contato):
        with conectar():
            alterados = (
                Contato.update(
                    cd_status=3,
                    dt_atualizacao=SQL("CURRENT_TIMESTAMP")
                )
                .where(Contato.cd_contato == cd_contato)
                .execute()
            )

        if not alterados:
            return {"sucesso": False, "erro": "Contato não encontrado."}

        return {"sucesso": True, "cd_contato": cd_contato}

    @staticmethod
    def por_prazo():
        fuso = ZoneInfo("America/Sao_Paulo")
        hoje = datetime.now(fuso).date()
        grupos = {"atrasados": [], "recentes": [], "hoje": []}

        with conectar():
            contatos = list(
                Contato.select()
                .where(Contato.cd_status == 1)
                .order_by(Contato.dt_cadastro)
            )

        for contato in contatos:
            cadastro = contato.dt_cadastro

            if cadastro.tzinfo is None:
                cadastro = cadastro.replace(tzinfo=fuso)

            dias = (hoje - cadastro.astimezone(fuso).date()).days

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
            return list(
                Contato.select()
                .where(Contato.cd_status.in_([1, 2]))
                .order_by(
                    Contato.marketplace.desc(),
                    Contato.dt_cadastro.asc(),
                    Contato.cd_contato.asc()
                )
            )

    @staticmethod
    def finalizados():
        with conectar():
            return list(
                Contato.select()
                .where(Contato.cd_status == 3)
                .order_by(
                    Contato.dt_atualizacao.desc(),
                    Contato.cd_contato.desc()
                )
            )

    @staticmethod
    def opcoes(cd_contato=None):
        with conectar():
            return list(
                ContatoStatus.select().order_by(ContatoStatus.cd_status)
            )
