from peewee import Model, BigAutoField, CharField, IntegerField, DecimalField, DateTimeField, BooleanField
from playhouse.postgres_ext import BinaryJSONField
from database.conexao import db, conectar

class Plano(Model):
    cd_plano = BigAutoField()
    nm_plano = CharField(max_length=100, unique=True)
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
                Plano.select().where(Plano.fl_ativo == True).order_by(Plano.periodicidade_dias.desc()))