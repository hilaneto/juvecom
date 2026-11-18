
from peewee import Model, BigAutoField, BigIntegerField, CharField, IntegerField, DecimalField, DateTimeField, BooleanField, CompositeKey
from playhouse.postgres_ext import BinaryJSONField
from database.conexao import db, conectar


class Plano(Model):
    cd_plano = BigAutoField()
    cd_plano_tipo = IntegerField()
    nm_plano = CharField(max_length=100)
    ds_plano = CharField(max_length=500, null=True)
    periodicidade_dias = IntegerField()
    valor = DecimalField(max_digits=12, decimal_places=2)
    texto_banner = CharField(max_length=100, null=True)
    texto_periodo = CharField(max_length=100, null=True)
    beneficios = BinaryJSONField(default=list)
    fl_ativo = BooleanField(default=True)
    dt_cadastro = DateTimeField()

    class Meta:
        database = db
        table_name = "tb_plano"

    @staticmethod
    def listar_ativos():
        with conectar():
            return list(
                Plano.select()
                .where(Plano.fl_ativo == True)
                .order_by(Plano.periodicidade_dias.desc())
            )


    @staticmethod
    def nova_versao(cd_plano, **alteracoes):
        campos = {
            "nm_plano", "ds_plano", "periodicidade_dias", "valor",
            "texto_banner", "texto_periodo", "beneficios"
        }

        if not alteracoes or not set(alteracoes).issubset(campos):
            raise ValueError("Informe campos válidos para a nova versão.")

        with conectar():
            with db.atomic():
                atual = (
                    Plano.select()
                    .where(Plano.cd_plano == cd_plano)
                    .for_update()
                    .get_or_none()
                )

                if atual is None or not atual.fl_ativo:
                    raise ValueError("Versão ativa do plano não encontrada.")

                dados = {
                    "cd_plano_tipo": atual.cd_plano_tipo,
                    "nm_plano": atual.nm_plano,
                    "ds_plano": atual.ds_plano,
                    "periodicidade_dias": atual.periodicidade_dias,
                    "valor": atual.valor,
                    "texto_banner": atual.texto_banner,
                    "texto_periodo": atual.texto_periodo,
                    "beneficios": atual.beneficios,
                    "fl_ativo": True
                }

                dados.update(alteracoes)

                if dados["periodicidade_dias"] <= 0:
                    raise ValueError("A periodicidade deve ser maior que zero.")

                if dados["valor"] < 0:
                    raise ValueError("O valor não pode ser negativo.")

                # Desativa a versão anterior.
                Plano.update(fl_ativo=False).where(
                    Plano.cd_plano == cd_plano
                ).execute()

                # Cria a nova versão.
                novo = Plano.create(**dados)

                # Copia os serviços da versão anterior.
                servicos = [
                    {"cd_plano": novo.cd_plano, "cd_servico": item.cd_servico}
                    for item in PlanoServico.select().where(
                        PlanoServico.cd_plano == cd_plano
                    )
                ]

                if servicos:
                    PlanoServico.insert_many(servicos).execute()

                return novo.cd_plano


class PlanoServico(Model):
    cd_plano = BigIntegerField()
    cd_servico = BigIntegerField()

    class Meta:
        database = db
        table_name = "tb_plano_servico"
        primary_key = CompositeKey("cd_plano", "cd_servico")

