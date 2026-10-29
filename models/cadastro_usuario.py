from peewee import IntegrityError

from database.conexao import conectar, db
from models.pessoa import Pessoa
from models.usuario import Usuario, UsuarioView, NivelOpcao
from suporte.validacao import somente_numeros


class CadastroUsuario:
    """Coordena Pessoa + Usuario sem substituir as regras de Usuario."""

    @staticmethod
    def _operador(cd_operador):
        return Usuario.get_or_none(
            (Usuario.cd_usuario == cd_operador) &
            (Usuario.fl_ativo == True)
        )

    @staticmethod
    def _exigir_sucesso(resultado):
        if not resultado.get("sucesso"):
            raise ValueError(resultado.get("erro") or "Operação não concluída.")
        return resultado

    @staticmethod
    def incluir(cd_operador, pessoa, usuario):
        try:
            with conectar():
                with db.atomic():
                    operador = CadastroUsuario._operador(cd_operador)
                    if operador is None or operador.cd_nivel != 0:
                        raise ValueError("Somente Master pode incluir usuários.")

                    documento = somente_numeros(pessoa.get("cpf_cnpj") or "")
                    if not documento:
                        raise ValueError("Informe o CPF/CNPJ.")

                    existente = Pessoa.get_or_none(Pessoa.cpf_cnpj == documento)
                    if existente is None:
                        resultado = CadastroUsuario._exigir_sucesso(Pessoa.incluir(pessoa))
                        cd_pessoa = resultado["cd_pessoa"]
                    else:
                        if not existente.fl_ativo:
                            raise ValueError("A pessoa vinculada está inativa.")
                        if existente.tp_pessoa != (pessoa.get("tp_pessoa") or "").strip().upper():
                            raise ValueError("Tipo de pessoa incompatível com o CPF/CNPJ.")
                        cd_pessoa = existente.cd_pessoa

                    if Usuario.get_or_none(Usuario.cd_pessoa == cd_pessoa):
                        raise ValueError("Essa pessoa já possui usuário cadastrado.")

                    resultado = CadastroUsuario._exigir_sucesso(
                        Usuario.salvar_autorizado(cd_operador, {
                            "documento_pessoa": documento,
                            "login": usuario.get("login", ""),
                            "cd_nivel": usuario.get("cd_nivel", ""),
                        })
                    )
                    return {"sucesso": True, "cd_pessoa": cd_pessoa,
                            "cd_usuario": resultado.get("cd_usuario")}
        except (ValueError, TypeError, IntegrityError) as erro:
            return {"sucesso": False, "erro": str(erro)}

    @staticmethod
    def listar():
        with conectar():
            return list(UsuarioView.select().order_by(
                UsuarioView.cd_nivel, UsuarioView.login).dicts())

    @staticmethod
    def buscar(cd_usuario):
        with conectar():
            conta = Usuario.get_or_none(Usuario.cd_usuario == cd_usuario)
            if conta is None:
                return {"sucesso": False, "erro": "Usuário não encontrado."}
            pessoa = Pessoa.get_or_none(Pessoa.cd_pessoa == conta.cd_pessoa)
            if pessoa is None:
                return {"sucesso": False, "erro": "Pessoa vinculada não encontrada."}
            dados = {
                "cd_pessoa": pessoa.cd_pessoa,
                "tp_pessoa": pessoa.tp_pessoa,
                "nm_pessoa": pessoa.nm_pessoa,
                "cpf_cnpj": pessoa.cpf_cnpj,
                "telefone": pessoa.telefone or "",
                "email": pessoa.email or "",
                "dados": dict(pessoa.dados or {}),
            }
            usuario = {
                "cd_usuario": conta.cd_usuario,
                "cd_pessoa": conta.cd_pessoa,
                "login": conta.login,
                "cd_nivel": conta.cd_nivel,
                "fl_ativo": conta.fl_ativo,
            }
            return {"sucesso": True, "dados": dados, "usuario": usuario}

    @staticmethod
    def atualizar(cd_operador, cd_usuario, pessoa, usuario):
        try:
            with conectar():
                with db.atomic():
                    operador = CadastroUsuario._operador(cd_operador)
                    if operador is None:
                        raise ValueError("Operador não autorizado.")

                    conta = Usuario.get_or_none(Usuario.cd_usuario == cd_usuario)
                    if conta is None:
                        raise ValueError("Usuário não encontrado.")

                    if operador.cd_nivel == 0:
                        dados_pessoa = dict(pessoa)
                        dados_pessoa["cd_pessoa"] = conta.cd_pessoa
                        CadastroUsuario._exigir_sucesso(Pessoa.atualizar(dados_pessoa))
                        alteracoes = {"cd_usuario": cd_usuario}
                        for campo in ("login", "cd_nivel", "fl_ativo"):
                            if campo in usuario:
                                alteracoes[campo] = usuario[campo]
                    elif operador.cd_nivel == 1 and cd_usuario != cd_operador and conta.cd_nivel in (2, 3, 4):
                        if "fl_ativo" not in usuario:
                            raise ValueError("Informe a situação do usuário.")
                        # Nível 1 não modifica Pessoa, login ou nível de acesso.
                        alteracoes = {
                            "cd_usuario": cd_usuario,
                            "fl_ativo": usuario["fl_ativo"],
                        }
                    else:
                        raise ValueError("Sem permissão para alterar este cadastro. Use Alterar minha senha.")

                    CadastroUsuario._exigir_sucesso(
                        Usuario.salvar_autorizado(cd_operador, alteracoes)
                    )
                    return {"sucesso": True, "cd_usuario": cd_usuario}
        except (ValueError, TypeError, IntegrityError) as erro:
            return {"sucesso": False, "erro": str(erro)}

    @staticmethod
    def niveis():
        with conectar():
            return list(NivelOpcao.select().order_by(NivelOpcao.cd_nivel))
