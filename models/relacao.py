from peewee import Model, SmallIntegerField, CharField, DateTimeField, BigIntegerField, CompositeKey
from database.conexao import db, conectar


class Relacao(Model):
    cd_relacao = SmallIntegerField(primary_key=True)
    nm_relacao = CharField(max_length=50)
    dt_atualizacao = DateTimeField()

    class Meta:
        database = db
        table_name = "tb_relacao"

    @staticmethod
    def buscar():
        with conectar():
            return list(Relacao.select().order_by(Relacao.nm_relacao))


class PessoaRelacao(Model):
    cd_pessoa = BigIntegerField()
    cd_relacao = SmallIntegerField()
    dt_atualizacao = DateTimeField()

    class Meta:
        database = db
        table_name = "tb_pessoa_relacao"
        primary_key = CompositeKey("cd_pessoa", "cd_relacao")

    @staticmethod
    def buscar(cd_pessoa):
        with conectar():
            consulta = PessoaRelacao.select().where(PessoaRelacao.cd_pessoa == cd_pessoa)
            return [vinculo.cd_relacao for vinculo in consulta]