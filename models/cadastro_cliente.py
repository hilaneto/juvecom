from peewee import IntegrityError, SQL
from datetime import date, datetime
from zoneinfo import ZoneInfo
from database.conexao import db, conectar
from models.pessoa import Pessoa
from models.cliente import Cliente
from models.loja import Loja
from models.cliente_link import ClienteLink
from models.usuario import Usuario


class CadastroCliente:

    @staticmethod
    def incluir(pessoa: dict, cliente: dict, lojas=None, usuario=None, cd_operador=None):
        try:
            if not isinstance(pessoa, dict) or not isinstance(cliente, dict):
                raise ValueError("Informe os dados da pessoa e do cliente.")

            lojas = [] if lojas is None else lojas

            if not isinstance(lojas, list) or any(
                not isinstance(loja, dict) for loja in lojas
            ):
                raise ValueError("Informe uma lista válida de lojas.")

            documento = pessoa.get("cpf_cnpj")
            tipo = pessoa.get("tp_pessoa")

            if not isinstance(documento, str) or not documento.strip():
                raise ValueError("Informe o CPF/CNPJ.")

            if not isinstance(tipo, str) or tipo.strip().upper() not in ("F", "J"):
                raise ValueError("Informe o tipo de pessoa.")

            with conectar():
                with db.atomic():

                    # 1. Localizar ou cadastrar Pessoa
                    encontrados = Pessoa.buscar(cpf_cnpj=documento)

                    if encontrados:
                        registro = encontrados[0]

                        if registro.tp_pessoa != tipo.strip().upper():
                            raise ValueError("CPF/CNPJ incompatível com o tipo de pessoa.")
                        cd_pessoa = registro.cd_pessoa

                    else:
                        resultado = Pessoa.incluir(pessoa)
                        if not resultado["sucesso"]:
                            raise ValueError(resultado["erro"])
                        cd_pessoa = resultado["cd_pessoa"]

                    # 2. Impedir duplicidade de Cliente
                    existente = Cliente.get_or_none(Cliente.cd_pessoa == cd_pessoa)

                    if existente is not None:
                        raise ValueError("Esta pessoa já possui cadastro de Cliente.")

                    # 3. Cadastrar Cliente
                    resultado = Cliente.incluir({
                        **cliente,
                        "cd_pessoa": cd_pessoa
                    })

                    if not resultado["sucesso"]:
                        raise ValueError(resultado["erro"])

                    cd_cliente = resultado["cd_cliente"]

                    # 4. Cadastrar Lojas
                    quantidade_lojas = 0

                    for loja in lojas:
                        if not any(
                            valor not in (None, "")
                            for valor in loja.values()
                        ):
                            continue

                        resultado = Loja.incluir({
                            **loja,
                            "cd_cliente": cd_cliente
                        })

                        if not resultado["sucesso"]:
                            raise ValueError(resultado["erro"])

                        quantidade_lojas += 1

                    # 5. Cadastrar usuário, quando solicitado
                    cd_usuario = CadastroCliente._salvar_usuario(cd_operador, cd_pessoa, usuario)


            return {"sucesso": True, "cd_pessoa": cd_pessoa, "cd_cliente": cd_cliente, "lojas": quantidade_lojas, "cd_usuario": cd_usuario}

        except (ValueError, TypeError) as erro:
            return {"sucesso": False, "erro": str(erro)}

        except IntegrityError:
            return {
                "sucesso": False,
                "erro": (
                    "Não foi possível cadastrar. "
                    "Verifique os documentos, contatos e Shop IDs."
                )
            }



    @staticmethod
    def receber_precadastro(token, formulario):

        if not token:
            return {
                "sucesso": False,
                "erro": "Link de cadastro inválido."
            }

        # Dados da Pessoa
        pessoa = {
            "tp_pessoa": formulario.get("tp_pessoa", "").strip(),
            "nm_pessoa": formulario.get("nm_pessoa", "").strip(),
            "cpf_cnpj": formulario.get("cpf_cnpj", "").strip(),
            "telefone": formulario.get("telefone", "").strip(),
            "email": formulario.get("email", "").strip(),
            "dados": {
                campo: formulario.get(campo, "").strip()
                for campo in (
                    "endereco",
                    "numero",
                    "complemento",
                    "bairro",
                    "cidade",
                    "uf",
                    "cep"
                )
            }
        }

        # Dados do Cliente
        cliente = {
            "nm_responsavel": formulario.get(
                "nm_responsavel", ""
            ).strip(),
            "cd_status": 1
        }

        # Dados da Loja
        loja = {
            "nm_loja": formulario.get("nm_loja", "").strip(),
            "shop_id": formulario.get("shop_id", "").strip(),
            "url_loja": formulario.get("url_loja", "").strip()
        }

        lojas = [loja] if any(loja.values()) else []

        try:
            with conectar():
                with db.atomic():

                    # Bloquear o link durante a gravação
                    link = (
                        ClienteLink.select()
                        .where(
                            (ClienteLink.token == token) &
                            (ClienteLink.dt_validade > SQL(
                                "CURRENT_TIMESTAMP"
                            )) &
                            (ClienteLink.dt_utilizacao.is_null(True))
                        )
                        .for_update()
                        .get_or_none()
                    )

                    if link is None:
                        raise ValueError(
                            "Link inválido, expirado ou já utilizado."
                        )

                    # Reutilizar o cadastro existente
                    resultado = CadastroCliente.incluir(
                        pessoa=pessoa,
                        cliente=cliente,
                        lojas=lojas,
                        usuario=None
                    )

                    if not resultado["sucesso"]:
                        raise ValueError(resultado["erro"])

                    cd_cliente = resultado["cd_cliente"]

                    # Registrar utilização do link
                    alterados = (
                        ClienteLink.update(
                            cd_cliente=cd_cliente,
                            dt_utilizacao=SQL("CURRENT_TIMESTAMP")
                        )
                        .where(
                            ClienteLink.cd_link == link.cd_link
                        )
                        .execute()
                    )

                    if alterados != 1:
                        raise ValueError(
                            "Não foi possível finalizar o cadastro."
                        )

            return {
                "sucesso": True,
                "cd_cliente": cd_cliente
            }

        except ValueError as erro:
            return {
                "sucesso": False,
                "erro": str(erro)
            }



    @staticmethod
    def listar():
        with conectar():
            consulta = (
                Cliente.select(
                    Cliente.cd_cliente,
                    Pessoa.nm_pessoa
                )
                .join(
                    Pessoa,
                    on=(Cliente.cd_pessoa == Pessoa.cd_pessoa)
                )
                .where(
                    (Cliente.fl_ativo == True) &
                    (Pessoa.fl_ativo == True)
                )
                .order_by(Pessoa.nm_pessoa)
            )

            return list(consulta.dicts())

    @staticmethod
    def buscar(cd_cliente):
        with conectar():
            cadastro = Cliente.get_or_none(
                (Cliente.cd_cliente == cd_cliente) &
                (Cliente.fl_ativo == True)
            )

            if cadastro is None:
                return {
                    "sucesso": False,
                    "erro": "Cliente não encontrado."
                }

            pessoa = Pessoa.get_or_none(
                Pessoa.cd_pessoa == cadastro.cd_pessoa
            )

            if pessoa is None:
                return {
                    "sucesso": False,
                    "erro": "Pessoa não encontrada."
                }

            endereco = dict(pessoa.dados or {})

            dados = {
                "cd_pessoa": pessoa.cd_pessoa,
                "tp_pessoa": pessoa.tp_pessoa,
                "nm_pessoa": pessoa.nm_pessoa,
                "cpf_cnpj": pessoa.cpf_cnpj,
                "telefone": pessoa.telefone or "",
                "email": pessoa.email or "",
                "dados": endereco,
                **endereco
            }

            dt_cadastro = cadastro.dt_cadastro

            if isinstance(dt_cadastro, datetime):
                if dt_cadastro.tzinfo:
                    dt_cadastro = dt_cadastro.astimezone(
                        ZoneInfo("America/Sao_Paulo")
                    )
                dt_cadastro = dt_cadastro.date()

            if isinstance(dt_cadastro, date):
                dt_cadastro = dt_cadastro.isoformat()

            cliente = {
                "nm_responsavel": cadastro.nm_responsavel or "",
                "cd_contato": cadastro.cd_contato or "",
                "fl_ativo": cadastro.fl_ativo,
                "dt_cadastro": dt_cadastro or ""
            }

            lojas = [
                {
                    "cd_loja": item.cd_loja,
                    "nm_loja": item.nm_loja or "",
                    "shop_id": item.shop_id or "",
                    "url_loja": item.url_loja or ""
                }
                for item in (
                    Loja.select()
                    .where(Loja.cd_cliente == cd_cliente)
                    .order_by(Loja.cd_loja)
                )
            ]

            # 5. Consultar usuário vinculado ao Cliente
            conta = Usuario.get_or_none(
                Usuario.cd_pessoa == cadastro.cd_pessoa
            )

            usuario = {
                "cd_usuario": conta.cd_usuario if conta else None,
                "login": conta.login if conta else "",
                "cd_nivel": conta.cd_nivel if conta else 5,
                "fl_ativo": conta.fl_ativo if conta else False
            }


            return {
                "sucesso": True,
                "dados": dados,
                "cliente": cliente,
                "loja": lojas[0] if lojas else {},
                "lojas": lojas,
                "usuario": usuario
            }        


    @staticmethod
    def atualizar(cd_cliente: int, pessoa: dict, cliente: dict, lojas=None, usuario=None, cd_operador=None):

        try:
            with conectar():
                with db.atomic():

                    # 1. Localizar Cliente
                    encontrados = Cliente.buscar(cd_cliente=cd_cliente)

                    if not encontrados:
                        raise ValueError("Cliente não encontrado.")

                    cadastro = encontrados[0]

                    # 2. Atualizar Pessoa vinculada
                    pessoa = {**pessoa, "cd_pessoa": cadastro.cd_pessoa}
                    resultado = Pessoa.atualizar(pessoa)

                    if not resultado["sucesso"]:
                        raise ValueError(resultado["erro"])

                    # 3. Atualizar Cliente
                    cliente = {**cliente, "cd_cliente": cd_cliente}
                    resultado = Cliente.atualizar(cliente)

                    if not resultado["sucesso"]:
                        raise ValueError(resultado["erro"])

                    # 4. Atualizar ou incluir Lojas
                    for loja in lojas or []:
                        codigo = loja.get("cd_loja")

                        if codigo not in (None, ""):
                            resultado = Loja.atualizar({**loja, "cd_cliente": cd_cliente})
                        else:
                            if not any(loja.get(campo) not in (None, "")
                                       for campo in ("nm_loja", "shop_id", "url_loja")):
                                 continue

                            resultado = Loja.incluir({**loja, "cd_cliente": cd_cliente})

                        if not resultado["sucesso"]:
                            raise ValueError(resultado["erro"])

                    # 5. Criar ou atualizar Usuário
                    cd_usuario = CadastroCliente._salvar_usuario(cd_operador, cadastro.cd_pessoa, usuario)

                return {"sucesso": True, "cd_cliente": cd_cliente, "cd_usuario": cd_usuario}

        except (ValueError, TypeError) as erro:
            return {"sucesso": False, "erro": str(erro)}

        except IntegrityError:
            return {"sucesso": False, "erro": "Não foi possível atualizar o cadastro do Cliente."}


    @staticmethod
    def _salvar_usuario(cd_operador, cd_pessoa, usuario):
        # Cadastro de usuário não solicitado
        if usuario is None:
            return None

        if not isinstance(usuario, dict):
            raise ValueError("Dados do usuário inválidos.")

        # Somente Master administra acessos
        operador = Usuario.get_or_none(
            (Usuario.cd_usuario == cd_operador) &
            (Usuario.cd_nivel == 0) &
            (Usuario.fl_ativo == True)
        )

        if operador is None:
            raise ValueError(
                "Somente Master pode administrar usuários clientes."
            )

        # Verificar vínculo com cliente ativo
        if not Usuario._cliente_ativo(cd_pessoa):
            raise ValueError(
                "A pessoa precisa possuir um cliente ativo."
            )

        pessoa = Pessoa.get_or_none(
            Pessoa.cd_pessoa == cd_pessoa
        )

        # Identificar usuário existente pela Pessoa
        existente = Usuario.get_or_none(
            Usuario.cd_pessoa == cd_pessoa
        )

        if existente is None:
            # Criar usuário cliente
            dados = {
                "documento_pessoa": pessoa.cpf_cnpj,
                "login": usuario.get("login", ""),
                "cd_nivel": 5
            }

        else:
            if existente.cd_nivel != 5:
                raise ValueError(
                    "Esta pessoa já possui um usuário "
                    "com outro nível de acesso."
                )

            # Atualizar usuário cliente
            dados = {
                "cd_usuario": existente.cd_usuario,
                "cd_nivel": 5
            }

            if "login" in usuario:
                dados["login"] = usuario["login"]

            if "fl_ativo" in usuario:
                dados["fl_ativo"] = usuario["fl_ativo"]

        resultado = Usuario.salvar_autorizado(
            cd_operador, dados
        )

        if not resultado["sucesso"]:
            raise ValueError(resultado["erro"])

        return resultado["cd_usuario"]
