
import re

def somente_numeros(valor: str) -> str:
    """Remove todos os caracteres que não sejam números."""
    return re.sub(r"\D", "", valor)

class CpfCnpj:

    def cpf(cpf: str) -> bool:
        """Valida um CPF."""
        cpf = somente_numeros(cpf)

        # CPF deve possuir 11 dígitos
        if len(cpf) != 11:
            return False

        # Rejeita CPFs com todos os dígitos iguais
        if cpf == cpf[0] * 11:
            return False
        # Primeiro dígito verificador
        soma = sum(int(cpf[i]) * (10 - i) for i in range(9))
        resto = soma % 11
        digito1 = 0 if resto < 2 else 11 - resto

        if int(cpf[9]) != digito1:
            return False
        # Segundo dígito verificador
        soma = sum(int(cpf[i]) * (11 - i) for i in range(10))
        resto = soma % 11
        digito2 = 0 if resto < 2 else 11 - resto

        if int(cpf[10]) != digito2:
            return False
        return True

    def cnpj(cnpj: str) -> bool:
        """Valida um CNPJ."""
        cnpj = somente_numeros(cnpj)

        # CNPJ deve possuir 14 dígitos
        if len(cnpj) != 14:
            return False

        # Rejeita CNPJs com todos os dígitos iguais
        if cnpj == cnpj[0] * 14:
            return False
        # Primeiro dígito verificador
        pesos = [5, 4, 3, 2, 9, 8, 7, 6, 5, 4, 3, 2]
        soma = sum(int(cnpj[i]) * pesos[i] for i in range(12))
        resto = soma % 11
        digito1 = 0 if resto < 2 else 11 - resto

        if int(cnpj[12]) != digito1:
            return False
        # Segundo dígito verificador
        pesos = [6, 5, 4, 3, 2, 9, 8, 7, 6, 5, 4, 3, 2]
        soma = sum(int(cnpj[i]) * pesos[i] for i in range(13))
        resto = soma % 11
        digito2 = 0 if resto < 2 else 11 - resto

        if int(cnpj[13]) != digito2:
            return False
        return True