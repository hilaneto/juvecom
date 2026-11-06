"""Consulta exclusiva dos dados do cliente autenticado.

Não usa cd_cliente, cd_pessoa ou cd_usuario recebidos de querystring/formulário.
A rota deve obter cd_usuario exclusivamente da sessão validada.
"""

from database.conexao import conectar
from models.usuario import Usuario
from models.pessoa import Pessoa
from models.cliente import Cliente
from models.cadastro_cliente import CadastroCliente


class MinhaConta:
    @staticmethod
    def consultar(cd_usuario):
        # 1. Identificar a conta autenticada e seu vínculo com cliente ativo.
        with conectar():
            conta = Usuario.get_or_none(
                (Usuario.cd_usuario == cd_usuario)
                & (Usuario.cd_nivel == 5)
                & (Usuario.fl_ativo == True)
            )

            if conta is None:
                return {"sucesso": False, "erro": "Acesso de cliente não encontrado."}

            pessoa = Pessoa.get_or_none(
                (Pessoa.cd_pessoa == conta.cd_pessoa)
                & (Pessoa.fl_ativo == True)
            )

            if pessoa is None:
                return {"sucesso": False, "erro": "Cadastro da pessoa não está ativo."}

            cliente = Cliente.get_or_none(
                (Cliente.cd_pessoa == pessoa.cd_pessoa)
                & (Cliente.fl_ativo == True)
            )

            if cliente is None:
                return {"sucesso": False, "erro": "Cadastro de cliente não está ativo."}

            cd_cliente = cliente.cd_cliente

        # 2. Reutilizar a consulta existente, evitando duplicar dados/regras.
        #    Esta chamada abre sua própria conexão, fora do bloco anterior.
        cadastro = CadastroCliente.buscar(cd_cliente)

        if not cadastro["sucesso"]:
            return cadastro

        # 3. Entregar apenas dados necessários à página (sem senha_hash).
        return {
            "sucesso": True,
            "cd_cliente": cd_cliente,
            "dados": cadastro["dados"],
            "cliente": cadastro["cliente"],
            "usuario": cadastro["usuario"],
        }
