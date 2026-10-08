from peewee import Model, BigAutoField, BigIntegerField, TextField, DateTimeField, SQL
from database.conexao import db, conectar
from models.contato import Contato
from models.usuario import Usuario


class ContatoConversa(Model):
    cd_conversa = BigAutoField()
    cd_contato = BigIntegerField()
    cd_usuario = BigIntegerField()
    dt_conversa = DateTimeField(default=SQL("CURRENT_TIMESTAMP"))
    texto = TextField()

    class Meta:
        database = db
        table_name = "tb_contato_conversa"

    @staticmethod
    def incluir(cd_contato, cd_usuario, texto):
        if not isinstance(texto, str) or not texto.strip():
            return {"sucesso": False, "erro": "Informe o conteúdo da conversa."}

        with conectar():
            with db.atomic():
                if not Contato.select().where(Contato.cd_contato == cd_contato).exists():
                    return {"sucesso": False, "erro": "Contato não encontrado."}

                if not Usuario.select().where(
                    (Usuario.cd_usuario == cd_usuario) & (Usuario.fl_ativo == True)
                ).exists():
                    return {"sucesso": False, "erro": "Atendente não autorizado."}

                conversa = ContatoConversa.create(
                    cd_contato=cd_contato,
                    cd_usuario=cd_usuario,
                    texto=texto.strip()
                )

        return {"sucesso": True, "cd_conversa": conversa.cd_conversa}

    @staticmethod
    def buscar(cd_contato):
        with conectar():
            consulta = (
                ContatoConversa.select(
                    ContatoConversa,
                    Usuario.login.alias("atendente")
                )
                .join(Usuario, on=(ContatoConversa.cd_usuario == Usuario.cd_usuario))
                .where(ContatoConversa.cd_contato == cd_contato)
                .order_by(ContatoConversa.dt_conversa.desc(), ContatoConversa.cd_conversa.desc())
                .dicts()
            )
            return list(consulta)