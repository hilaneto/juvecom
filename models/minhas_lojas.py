"""Consulta das lojas associadas ao usuário Cliente autenticado.

O identificador recebido por consultar() DEVE vir da sessão Flask validada.
Não aceitar cd_cliente por querystring, POST ou parâmetro de rota.
"""

from urllib.parse import urlsplit

from database.conexao import conectar
from models.usuario import Usuario
from models.pessoa import Pessoa
from models.cliente import Cliente
from models.loja import Loja


class MinhasLojas:

    @staticmethod
    def _url_externa(url):
        """Retorna somente URL HTTP(S) válida para uso como link externo."""
        url = (url or "").strip()
        if not url:
            return ""

        try:
            partes = urlsplit(url)
            if (partes.scheme.lower() not in ("http", "https")
                    or not partes.hostname
                    or partes.username is not None
                    or partes.password is not None):
                return ""
        except ValueError:
            return ""
        return url

    @staticmethod
    def consultar(cd_usuario):
        with conectar():
            # Nunca identificar o cliente a partir de dados enviados pelo navegador.
            usuario = Usuario.get_or_none(
                (Usuario.cd_usuario == cd_usuario)
                & (Usuario.cd_nivel == 5)
                & (Usuario.fl_ativo == True)
            )

            if usuario is None:
                return {"sucesso": False, "erro": "Usuário cliente não autorizado."}

            pessoa = Pessoa.get_or_none(
                (Pessoa.cd_pessoa == usuario.cd_pessoa)
                & (Pessoa.fl_ativo == True)
            )
            if pessoa is None:
                return {"sucesso": False, "erro": "Cadastro de pessoa inativo ou inexistente."}

            cliente = Cliente.get_or_none(
                (Cliente.cd_pessoa == pessoa.cd_pessoa)
                & (Cliente.fl_ativo == True)
            )
            if cliente is None:
                return {"sucesso": False, "erro": "Cliente inativo ou inexistente."}

            # Restrição de acesso: somente as lojas vinculadas ao próprio cliente.
            consulta = (
                Loja.select()
                .where(Loja.cd_cliente == cliente.cd_cliente)
                .order_by(Loja.nm_loja, Loja.cd_loja)
            )

            lojas = [
                {
                    "cd_loja": loja.cd_loja,
                    "nm_loja": loja.nm_loja,
                    "shop_id": loja.shop_id,
                    "url_loja": MinhasLojas._url_externa(loja.url_loja),
                    "fl_ativo": bool(loja.fl_ativo),
                }
                for loja in consulta
            ]

        return {
            "sucesso": True,
            "lojas": lojas,
            "total_lojas": len(lojas),
            "total_ativas": sum(1 for loja in lojas if loja["fl_ativo"]),
        }
