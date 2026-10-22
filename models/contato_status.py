from peewee import Model, SmallIntegerField, CharField
from database.conexao import db

class ContatoStatus(Model):
    cd_status = SmallIntegerField(primary_key=True)
    nm_status = CharField(max_length=30, unique=True)
    ds_status = CharField(max_length=150)

    class Meta:
        database = db
        table_name = "tb_contato_status"