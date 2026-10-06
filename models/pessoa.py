from peewee import Model, BigAutoField, CharField, BooleanField, DateTimeField, SQL, IntegrityError
from playhouse.postgres_ext import BinaryJSONField
from database.conexao import db, conectar
from suporte.validacao import CpfCnpj, somente_numeros
from models.relacao import Relacao, PessoaRelacao

class Pessoa(Model):
    cd_pessoa = BigAutoField()
    tp_pessoa = CharField(max_length=1)
    nm_pessoa = CharField(max_length=150)
    cpf_cnpj = CharField(max_length=14, unique=True)
    telefone = CharField(max_length=20, null=True)
    email = CharField(max_length=150, null=True)
    dados = BinaryJSONField(default=dict)
    fl_ativo = BooleanField(default=True)
    dt_cadastro = DateTimeField(default=SQL("CURRENT_TIMESTAMP"))
    dt_atualizacao = DateTimeField(default=SQL("CURRENT_TIMESTAMP"))
    
    class Meta:
        database = db
        table_name = "tb_pessoa"


    @staticmethod
    def validar(campos):
        for campo in ("tp_pessoa", "nm_pessoa", "cpf_cnpj", "telefone", "email"):
            if campo in campos:
                valor = campos[campo]

                if valor is not None and not isinstance(valor, str):
                    return f"{campo} deve ser um texto."

                campos[campo] = (valor or "").strip()

        if "tp_pessoa" in campos:
            campos["tp_pessoa"] = campos["tp_pessoa"].upper()

            if campos["tp_pessoa"] not in ("F", "J"):
                return "Informe F para pessoa física ou J para jurídica."

        if "nm_pessoa" in campos:
            if not campos["nm_pessoa"]:
                return "Informe o nome da pessoa."

            if len(campos["nm_pessoa"]) > 150:
                return "O nome deve ter até 150 caracteres."

        if "cpf_cnpj" in campos:
            documento = somente_numeros(campos["cpf_cnpj"])

            if not documento:
                return "Informe o CPF/CNPJ."

            if len(documento) == 11:
                valido = CpfCnpj.cpf(documento)
            elif len(documento) == 14:
                valido = CpfCnpj.cnpj(documento)
            else:
                return "O CPF deve ter 11 dígitos e o CNPJ, 14."

            if not valido:
                return "CPF/CNPJ inválido."

            tipo = campos.get("tp_pessoa")

            if tipo == "F" and len(documento) != 11:
                return "Pessoa física deve ter CPF."

            if tipo == "J" and len(documento) != 14:
                return "Pessoa jurídica deve ter CNPJ."

            campos["cpf_cnpj"] = documento

        for campo, limite in (("telefone", 20), ("email", 150)):
            if campo in campos:
                campos[campo] = campos[campo] or None

                if campos[campo] and len(campos[campo]) > limite:
                    return f"{campo} deve ter até {limite} caracteres."


        if "dados" in campos:

            if not isinstance(campos["dados"], dict):
                return "O campo dados deve ser um dicionário."
            endereco = campos["dados"].copy()

            for campo in ("endereco", "numero", "complemento", "bairro", "cep", "cidade", "uf"):
                if campo in endereco:
                    valor = endereco[campo]
                    if valor is not None and not isinstance(valor, str):
                        return f"{campo} deve ser um texto."
                    endereco[campo] = (valor or "").strip()


            if "cep" in endereco:
                endereco["cep"] = somente_numeros(endereco["cep"])
                if endereco["cep"] and len(endereco["cep"]) != 8:
                    return "O CEP deve conter 8 dígitos."


            if "uf" in endereco:
                endereco["uf"] = endereco["uf"].upper()
                if endereco["uf"] and (
                    len(endereco["uf"]) != 2
                    or any(letra not in "ABCDEFGHIJKLMNOPQRSTUVWXYZ" for letra in endereco["uf"])
                ):
                    return "A UF deve conter 2 letras."


            limites = {"endereco": 60, "numero": 10, "complemento": 20, "bairro": 50, "cidade": 50}
            for campo, limite in limites.items():
                if campo in endereco and len(endereco[campo]) > limite:
                    return f"{campo} deve ter até {limite} caracteres."
            campos["dados"] = endereco


        if "fl_ativo" in campos and not isinstance(campos["fl_ativo"], bool):
            return "fl_ativo deve ser True ou False."

        return None


    @staticmethod
    def buscar(cd_pessoa=None, fl_ativo=None):
        with conectar():
            consulta = Pessoa.select()

            if cd_pessoa is not None:
                consulta = consulta.where(Pessoa.cd_pessoa == cd_pessoa)

            if fl_ativo is not None:
                consulta = consulta.where(Pessoa.fl_ativo == fl_ativo)

            return list(consulta.order_by(Pessoa.nm_pessoa, Pessoa.cd_pessoa))


    @staticmethod
    def incluir(dados: dict, relacoes=None):
        permitidos = {"tp_pessoa", "nm_pessoa", "cpf_cnpj", "telefone", "email", "dados"}
        campos = {chave: valor for chave, valor in dados.items() if chave in permitidos}

        for campo in ("tp_pessoa", "nm_pessoa", "cpf_cnpj"):
            campos.setdefault(campo, None)

        erro = Pessoa.validar(campos)

        if erro:
            return {"sucesso": False, "erro": erro}

        try:
            with conectar():
                with db.atomic():
                    pessoa = Pessoa.create(**campos)

                    if relacoes is not None:
                        Pessoa.gravar_relacoes(pessoa.cd_pessoa, relacoes)

        except ValueError as erro:
            return {"sucesso": False, "erro": str(erro)}
        except IntegrityError:
            return {"sucesso": False, "erro": "Não foi possível incluir. Verifique se o CPF/CNPJ já está cadastrado."}

        return {"sucesso": True, "cd_pessoa": pessoa.cd_pessoa}


    @staticmethod
    def atualizar(dados: dict, relacoes=None):
        cd_pessoa = dados.get("cd_pessoa")

        if cd_pessoa in (None, ""):
            return {"sucesso": False, "erro": "Informe o código da pessoa."}

        permitidos = {"tp_pessoa", "nm_pessoa", "cpf_cnpj", "telefone", "email", "dados", "fl_ativo"}
        campos = {chave: valor for chave, valor in dados.items() if chave in permitidos}

        if not campos and relacoes is None:
            return {"sucesso": False, "erro": "Informe um campo para atualizar."}

        try:
            with conectar():
                with db.atomic():
                    pessoa = (Pessoa.select().where(Pessoa.cd_pessoa == cd_pessoa).for_update().first())

                    if pessoa is None:
                        return {"sucesso": False, "erro": "Pessoa não encontrada."}

                    if "tp_pessoa" in campos or "cpf_cnpj" in campos:
                        campos.setdefault("tp_pessoa", pessoa.tp_pessoa)
                        campos.setdefault("cpf_cnpj", pessoa.cpf_cnpj)

                    if "dados" in campos and isinstance(campos["dados"], dict):
                        campos["dados"] = {**pessoa.dados, **campos["dados"]}

                    erro = Pessoa.validar(campos)

                    if erro:
                        return {"sucesso": False, "erro": erro}

                    campos["dt_atualizacao"] = SQL("CURRENT_TIMESTAMP")
                    Pessoa.update(**campos).where(Pessoa.cd_pessoa == cd_pessoa).execute()

                    if relacoes is not None:
                        Pessoa.gravar_relacoes(cd_pessoa, relacoes)

        except ValueError as erro:
            return {"sucesso": False, "erro": str(erro)}
        except IntegrityError:
            return {"sucesso": False, "erro": "Não foi possível atualizar. Verifique se o CPF/CNPJ já está cadastrado."}

        return {"sucesso": True, "cd_pessoa": cd_pessoa}
        

    @staticmethod
    def gravar_relacoes(cd_pessoa, relacoes):
        codigos = set(relacoes)
        existentes = {
            relacao.cd_relacao
            for relacao in Relacao.select().where(Relacao.cd_relacao.in_(codigos))}

        if codigos != existentes:
            raise ValueError("Uma das relações informadas não existe.")

        PessoaRelacao.delete().where(PessoaRelacao.cd_pessoa == cd_pessoa).execute()

        if codigos:
            PessoaRelacao.insert_many([
                {"cd_pessoa": cd_pessoa, "cd_relacao": codigo, "dt_atualizacao": SQL("CURRENT_TIMESTAMP")}
                for codigo in codigos
                ]).execute()


    @staticmethod
    def excluir(cd_pessoa):
        return Pessoa.atualizar({"cd_pessoa": cd_pessoa, "fl_ativo": False})