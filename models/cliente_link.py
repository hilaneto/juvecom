import secrets
import hashlib
from datetime import datetime, timedelta, timezone
from peewee import Model, BigIntegerField, CharField, DateTimeField
from database.conexao import db, conectar

class ClienteLink(Model):
    cd_link = BigIntegerField(primary_key=True)
    token = CharField(max_length=100, unique=True)
    cd_usuario = BigIntegerField()
    cd_cliente = BigIntegerField(null=True)
    dt_criacao = DateTimeField()
    dt_validade = DateTimeField()
    dt_utilizacao = DateTimeField(null=True)

    class Meta:
        database = db
        table_name = "tb_cliente_link"

    @staticmethod
    def gerar(cd_usuario):

        token = secrets.token_urlsafe(32)
        agora = datetime.now(timezone.utc)

        with conectar():
            link = ClienteLink.create(
                token=token,
                cd_usuario=cd_usuario,
                dt_criacao=agora,
                dt_validade=agora + timedelta(days=7))

        return {"cd_link": link.cd_link,
                "token": token,
                "dt_validade": link.dt_validade
                }

    @staticmethod
    def validar(token):

        if not token:
            return None

        with conectar():
            link = ClienteLink.get_or_none(
                (ClienteLink.token == token) &
                (ClienteLink.dt_validade > datetime.now(timezone.utc)) &
                (ClienteLink.dt_utilizacao.is_null(True)))
            return link

    @staticmethod
    def listar():
        """Retorna os links gerados."""

        with conectar():
            registros = list(
                ClienteLink.select()
                .order_by(ClienteLink.cd_link.desc())
                .dicts()
            )

        return registros
