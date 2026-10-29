
from peewee import (
    Model, BigAutoField, BigIntegerField, CharField,
    BooleanField, DateTimeField, SQL, IntegrityError
)
from database.conexao import db, conectar


class Loja(Model):
    cd_loja = BigAutoField()
    cd_cliente = BigIntegerField()
    nm_loja = CharField(max_length=150)
    shop_id = BigIntegerField(null=True, unique=True)
    url_loja = CharField(max_length=500, null=True)
    fl_ativo = BooleanField(default=True)
    dt_cadastro = DateTimeField(default=SQL("CURRENT_TIMESTAMP"))
    dt_atualizacao = DateTimeField(default=SQL("CURRENT_TIMESTAMP"))

    class Meta:
        database = db
        table_name = "tb_loja"

    @staticmethod
    def buscar(cd_loja=None, cd_cliente=None, fl_ativo=None):
        with conectar():
            consulta = Loja.select()

            if cd_loja is not None:
                consulta = consulta.where(Loja.cd_loja == cd_loja)

            if cd_cliente is not None:
                consulta = consulta.where(Loja.cd_cliente == cd_cliente)

            if fl_ativo is not None:
                consulta = consulta.where(Loja.fl_ativo == fl_ativo)

            return list(
                consulta.order_by(Loja.nm_loja, Loja.cd_loja)
            )

    @staticmethod
    def incluir(dados: dict):
        try:
            cd_cliente = int(dados.get("cd_cliente"))
            shop_id = dados.get("shop_id")
            shop_id = (
                int(shop_id)
                if shop_id not in (None, "")
                else None
            )
        except (ValueError, TypeError):
            return {
                "sucesso": False,
                "erro": "Código do cliente ou Shop ID inválido."
            }

        nm_loja = (dados.get("nm_loja") or "").strip()
        url_loja = (dados.get("url_loja") or "").strip() or None

        if not nm_loja:
            return {
                "sucesso": False,
                "erro": "Informe o nome da loja."
            }

        if len(nm_loja) > 150 or (
            url_loja and len(url_loja) > 500
        ):
            return {
                "sucesso": False,
                "erro": "Nome ou URL da loja excede o tamanho permitido."
            }

        try:
            with conectar():
                loja = Loja.create(
                    cd_cliente=cd_cliente,
                    nm_loja=nm_loja,
                    shop_id=shop_id,
                    url_loja=url_loja
                )

        except IntegrityError:
            return {
                "sucesso": False,
                "erro": (
                    "Não foi possível cadastrar. Verifique o cliente "
                    "e se o Shop ID já está cadastrado."
                )
            }

        return {
            "sucesso": True,
            "cd_loja": loja.cd_loja
        }

    @staticmethod
    def atualizar(dados: dict):
        try:
            cd_loja = int(dados.get("cd_loja"))

            codigo_cliente = dados.get("cd_cliente")
            cd_cliente = (
                int(codigo_cliente)
                if codigo_cliente not in (None, "")
                else None
            )

        except (ValueError, TypeError):
            return {
                "sucesso": False,
                "erro": "Código da loja ou do cliente inválido."
            }

        permitidos = {
            "nm_loja", "shop_id", "url_loja", "fl_ativo"
        }

        campos = {
            chave: valor
            for chave, valor in dados.items()
            if chave in permitidos
        }

        if not campos:
            return {
                "sucesso": False,
                "erro": "Informe um campo para atualizar."
            }

        if "nm_loja" in campos:
            if (
                not isinstance(campos["nm_loja"], str)
                or not campos["nm_loja"].strip()
            ):
                return {
                    "sucesso": False,
                    "erro": "Informe o nome da loja."
                }

            campos["nm_loja"] = campos["nm_loja"].strip()

            if len(campos["nm_loja"]) > 150:
                return {
                    "sucesso": False,
                    "erro": "O nome deve ter até 150 caracteres."
                }

        if "shop_id" in campos:
            try:
                valor = campos["shop_id"]
                campos["shop_id"] = (
                    int(valor)
                    if valor not in (None, "")
                    else None
                )
            except (ValueError, TypeError):
                return {
                    "sucesso": False,
                    "erro": "Shop ID inválido."
                }

        if "url_loja" in campos:
            valor = campos["url_loja"]

            if valor is not None and not isinstance(valor, str):
                return {
                    "sucesso": False,
                    "erro": "A URL deve ser um texto."
                }

            campos["url_loja"] = (valor or "").strip() or None

            if (
                campos["url_loja"]
                and len(campos["url_loja"]) > 500
            ):
                return {
                    "sucesso": False,
                    "erro": "A URL deve ter até 500 caracteres."
                }

        if (
            "fl_ativo" in campos
            and not isinstance(campos["fl_ativo"], bool)
        ):
            return {
                "sucesso": False,
                "erro": "fl_ativo deve ser True ou False."
            }

        try:
            with conectar():
                consulta = Loja.update(
                    **campos,
                    dt_atualizacao=SQL("CURRENT_TIMESTAMP")
                ).where(Loja.cd_loja == cd_loja)

                # Quando informado, confirma o vínculo com o cliente.
                if cd_cliente is not None:
                    consulta = consulta.where(
                        Loja.cd_cliente == cd_cliente
                    )

                alterados = consulta.execute()

        except IntegrityError:
            return {
                "sucesso": False,
                "erro": (
                    "Não foi possível atualizar. Verifique se "
                    "o Shop ID já pertence a outra loja."
                )
            }

        if not alterados:
            return {
                "sucesso": False,
                "erro": (
                    "Loja não encontrada ou não vinculada "
                    "ao cliente informado."
                )
            }

        return {
            "sucesso": True,
            "cd_loja": cd_loja
        }

    @staticmethod
    def excluir(cd_loja):
        return Loja.atualizar({
            "cd_loja": cd_loja,
            "fl_ativo": False
        })
