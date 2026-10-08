from peewee import Model, BigAutoField, BigIntegerField, SmallIntegerField, CharField, TextField, DateTimeField, BooleanField, SQL, IntegrityError
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
        from models.plano import Plano

        try:
            cd_contato = int(dados.get("cd_contato"))
        except (ValueError, TypeError):
            return {"sucesso": False, "erro": "Informe o código do contato."}

        permitidos = {
            "nm_contato", "celular", "email", "mensagem",
            "marketplace", "cd_plano", "cd_contrato", "cd_status"
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

        for campo in ("cd_plano", "cd_contrato", "cd_status"):
            if campo not in campos:
                continue

            valor = campos[campo]

            if valor in (None, ""):
                if campo == "cd_status":
                    return {"sucesso": False, "erro": "Informe o status do contato."}

                campos[campo] = None
            else:
                try:
                    campos[campo] = int(valor)
                except (ValueError, TypeError):
                    return {"sucesso": False, "erro": f"{campo} inválido."}

        if "marketplace" in campos:
            campos["marketplace"] = campos["marketplace"] in (True, "1")

        try:
            with conectar():
                with db.atomic():
                    contato = (
                        Contato.select()
                        .where(Contato.cd_contato == cd_contato)
                        .for_update().first()
                    )

                    if contato is None:
                        return {"sucesso": False, "erro": "Contato não encontrado."}

                    if "cd_plano" in campos and campos["cd_plano"] is not None:
                        plano = Plano.get_or_none(Plano.cd_plano == campos["cd_plano"])

                        if plano is None or (
                            not plano.fl_ativo and plano.cd_plano != contato.cd_plano
                        ):
                            return {"sucesso": False, "erro": "Plano indisponível."}

                    if "cd_status" in campos:
                        if not ContatoStatus.select().where(
                            ContatoStatus.cd_status == campos["cd_status"]
                        ).exists():
                            return {"sucesso": False, "erro": "Status não encontrado."}

                    if "cd_contrato" in campos and campos["cd_contrato"] is not None:
                        contrato = (
                            ContratoOpcao.select()
                            .where(ContratoOpcao.cd_contrato == campos["cd_contrato"])
                            .for_update().first()
                        )

                        if contrato is None:
                            return {"sucesso": False, "erro": "Contrato não encontrado."}

                        ocupado = Contato.select().where(
                            (Contato.cd_contrato == campos["cd_contrato"]) &
                            (Contato.cd_contato != cd_contato)
                        ).exists()

                        if ocupado:
                            return {"sucesso": False, "erro": "Esse contrato já está vinculado a outro contato."}

                    campos["dt_atualizacao"] = SQL("CURRENT_TIMESTAMP")
                    Contato.update(**campos).where(Contato.cd_contato == cd_contato).execute()

        except IntegrityError:
            return {"sucesso": False, "erro": "Não foi possível salvar. Confira plano, contrato e status; o contrato pode ter sido vinculado a outro contato."}

        return {"sucesso": True, "cd_contato": cd_contato}

    @staticmethod
    def excluir(cd_contato):
        with conectar():
            alterados = (Contato.update(cd_status=3, dt_atualizacao=SQL("CURRENT_TIMESTAMP")).where(Contato.cd_contato == cd_contato).execute())
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
            return list(
                Contato.select()
                .where(Contato.cd_status.in_([1, 2]))
                .order_by(Contato.marketplace.desc(), Contato.dt_cadastro.asc(), Contato.cd_contato.asc()))


    @staticmethod
    def finalizados():
        with conectar():
            return list(
                Contato.select()
                .where(Contato.cd_status == 3)
                .order_by(Contato.dt_atualizacao.desc(),Contato.cd_contato.desc()))



    @staticmethod
    def opcoes(cd_contato):
        from models.plano import Plano

        with conectar():
            contato = Contato.get_or_none(Contato.cd_contato == cd_contato)

            planos = Plano.select().where(Plano.fl_ativo == True)

            if contato is not None and contato.cd_plano is not None:
                planos = Plano.select().where(
                    (Plano.fl_ativo == True) | (Plano.cd_plano == contato.cd_plano)
                )

            vinculados = Contato.select(Contato.cd_contrato).where(
                (Contato.cd_contrato.is_null(False)) &
                (Contato.cd_contato != cd_contato)
            )

            contratos = ContratoOpcao.select().where(
                ContratoOpcao.cd_contrato.not_in(vinculados)
            )

            return (
                list(planos.order_by(Plano.periodicidade_dias.desc(), Plano.nm_plano)),
                list(contratos.order_by(ContratoOpcao.cd_contrato.desc())),
                list(ContatoStatus.select().order_by(ContatoStatus.cd_status))
            )

            

class ContatoStatus(Model):
    cd_status = SmallIntegerField(primary_key=True)
    nm_status = CharField(max_length=30)
    ds_status = CharField(max_length=150)

    class Meta:
        database = db
        table_name = "tb_contato_status"


class ContratoOpcao(Model):
    cd_contrato = BigIntegerField(primary_key=True)
    nm_plano = CharField(max_length=100)

    class Meta:
        database = db
        table_name = "tb_contrato"