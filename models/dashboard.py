from peewee import Model, CharField, IntegerField, BigIntegerField, DecimalField
from database.conexao import db, conectar


class DashboardAdmin(Model):
    origem = CharField()
    cd_status = IntegerField()
    nm_status = CharField()
    qtd = BigIntegerField()

    class Meta:
        database = db
        table_name = "vw_dash_adm"
        primary_key = False


class DashboardFinanceiro(Model):
    parcelas_proximas = BigIntegerField()
    valor_proximos = DecimalField()
    parcelas_vencidas = BigIntegerField()
    valor_vencidos = DecimalField()
    parcelas_inadimplentes = BigIntegerField()
    valor_inadimplencia = DecimalField()

    class Meta:
        database = db
        table_name = "vw_dash_fin"
        primary_key = False


class Dashboard:

    @staticmethod
    def administrativo():
        with conectar():
            return list(DashboardAdmin.select().dicts())

    @staticmethod
    def financeiro():
        with conectar():
            return DashboardFinanceiro.select().dicts().first()