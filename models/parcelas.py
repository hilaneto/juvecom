"""JUV-027 — Consulta e confirmação de pagamentos de parcelas.

Utilização em app.py:
    from models.parcelas import Parcelas
    tela = Parcelas.tela(cd_parcela=cd_parcela)
    resultado = Parcelas.confirmar_pagamento(cd_parcela, request.form.to_dict())

Todas as consultas e alterações financeiras permanecem fora das rotas Flask.
"""

from datetime import date, datetime
from decimal import Decimal, InvalidOperation, ROUND_HALF_UP
from zoneinfo import ZoneInfo

from database.conexao import db, conectar


class Parcelas:
    FUSO = ZoneInfo("America/Sao_Paulo")
    CENTAVOS = Decimal("0.01")

    @staticmethod
    def _hoje():
        return datetime.now(Parcelas.FUSO).date()

    @staticmethod
    def _linhas(cursor):
        colunas = [coluna[0] for coluna in cursor.description]
        return [dict(zip(colunas, linha)) for linha in cursor.fetchall()]

    @staticmethod
    def _decimal(valor, campo):
        try:
            numero = Decimal(str(valor).strip().replace(",", "."))
        except (InvalidOperation, ValueError, TypeError):
            raise ValueError(f"Informe um valor válido para {campo}.") from None
        if not numero.is_finite():
            raise ValueError(f"Informe um valor válido para {campo}.")
        return numero

    @staticmethod
    def _moeda(valor):
        return valor.quantize(Parcelas.CENTAVOS, rounding=ROUND_HALF_UP)

    @staticmethod
    def _data(valor):
        if isinstance(valor, date) and not isinstance(valor, datetime):
            return valor
        try:
            return date.fromisoformat(str(valor).strip())
        except (TypeError, ValueError):
            raise ValueError("Informe uma data de pagamento válida.") from None

    @staticmethod
    def tela(cd_parcela=None):
        """Retorna dados da tela e três listas de parcelas ainda não pagas."""
        with conectar():
            cursor = db.execute_sql("""
                SELECT p.cd_parcela, p.cd_contrato, p.nr_parcela,
                       p.dt_vencimento, p.vl_parcela, p.pc_desconto,
                       p.dt_pagamento, p.vl_pago, p.dt_atualizacao,
                       c.nm_plano, c.cd_status AS cd_status_contrato,
                       st.nm_status AS status_contrato, c.vigencia,
                       LOWER(c.vigencia) AS dt_inicio_vigencia,
                       CASE WHEN UPPER_INF(c.vigencia) THEN NULL
                            ELSE UPPER(c.vigencia) - 1 END AS dt_fim_vigencia,
                       cl.cd_cliente, cl.nm_responsavel,
                       pe.nm_pessoa, pe.cpf_cnpj, pe.telefone, pe.email
                FROM public.tb_parcelas p
                JOIN public.tb_contrato c ON c.cd_contrato = p.cd_contrato
                JOIN public.tb_contrato_status st ON st.cd_status = c.cd_status
                JOIN public.tb_cliente cl ON cl.cd_cliente = c.cd_cliente
                JOIN public.tb_pessoa pe ON pe.cd_pessoa = cl.cd_pessoa
                ORDER BY p.dt_vencimento, p.cd_parcela
            """)
            registros = Parcelas._linhas(cursor)

        hoje = Parcelas._hoje()
        pendentes = [p for p in registros if p["dt_pagamento"] is None]
        vencidas = [p for p in pendentes if p["dt_vencimento"] < hoje]
        vencem_hoje = [p for p in pendentes if p["dt_vencimento"] == hoje]
        futuras = [p for p in pendentes if p["dt_vencimento"] > hoje]

        selecionada = next((p for p in registros if p["cd_parcela"] == cd_parcela), None)
        if selecionada is None:
            selecionada = next(iter(pendentes), None)

        return {
            "vencidas": vencidas,
            "vencem_hoje": vencem_hoje,
            "futuras": futuras,
            "selecionada": selecionada,
        }

    @staticmethod
    def _total_atualizado(parcela, pagamento):
        """Calcula encargos da política vigente no vencimento e aplica o desconto.

        O cálculo utiliza a data efetiva do pagamento; juros só incidem depois
        de dias_carencia. Retorna o total com arredondamento a centavos.
        """
        valor = Decimal(parcela["vl_parcela"])
        desconto = Decimal(parcela["pc_desconto"])
        dias_atraso = max((pagamento - parcela["dt_vencimento"]).days, 0)
        multa = juros_mensal = juros_diario = Decimal("0")

        if dias_atraso > 0:
            cursor = db.execute_sql("""
                SELECT percentual_multa, juros_mensal, juros_diario, dias_carencia
                FROM public.tb_encargo_atraso
                WHERE vigencia @> %s::date
                ORDER BY LOWER(vigencia) DESC
                LIMIT 1
            """, (parcela["dt_vencimento"],))
            politica = cursor.fetchone()
            if politica is None:
                raise ValueError("Não existe política de encargos para o vencimento desta parcela.")

            percentual_multa, pc_juros_mensal, pc_juros_diario, carencia = politica
            dias_cobrados = max(dias_atraso - int(carencia), 0)
            if dias_cobrados:
                multa = Parcelas._moeda(valor * Decimal(percentual_multa) / 100)
                juros_mensal = Parcelas._moeda(
                    valor * Decimal(pc_juros_mensal) / 100 * dias_cobrados / 30
                )
                juros_diario = Parcelas._moeda(
                    valor * Decimal(pc_juros_diario) / 100 * dias_cobrados
                )

        subtotal = valor + multa + juros_mensal + juros_diario
        vl_desconto = Parcelas._moeda(subtotal * desconto / 100)
        return Parcelas._moeda(subtotal - vl_desconto)

    @staticmethod
    def confirmar_pagamento(cd_parcela, dados):
        """Confirma uma parcela e, quando cabível, regulariza o contrato 3 -> 2.

        A gravação da parcela e a eventual atualização do contrato são atômicas.
        Um pagamento já confirmado não é alterado por esta operação.
        """
        try:
            if not isinstance(cd_parcela, int) or isinstance(cd_parcela, bool) or cd_parcela <= 0:
                raise ValueError("Código da parcela inválido.")

            desconto = Parcelas._decimal(dados.get("pc_desconto", ""), "desconto")
            pago = Parcelas._decimal(dados.get("vl_pago", ""), "valor pago")
            pagamento = Parcelas._data(dados.get("dt_pagamento", ""))

            if desconto < 0 or desconto > 100 or desconto.as_tuple().exponent < -2:
                raise ValueError("O desconto deve estar entre 0 e 100%, com até duas casas decimais.")
            if pago <= 0 or pago != Parcelas._moeda(pago):
                raise ValueError("O valor pago deve ser positivo e possuir até duas casas decimais.")
            if pagamento > Parcelas._hoje():
                raise ValueError("A data do pagamento não pode ser futura.")

            with conectar():
                with db.atomic():
                    # Bloquear primeiro o contrato, depois a parcela: ordem única
                    # para minimizar conflitos entre pagamentos simultâneos.
                    cursor = db.execute_sql("""
                        SELECT c.cd_contrato, c.cd_status
                        FROM public.tb_contrato c
                        JOIN public.tb_parcelas p ON p.cd_contrato = c.cd_contrato
                        WHERE p.cd_parcela = %s
                        FOR UPDATE OF c
                    """, (cd_parcela,))
                    contrato = cursor.fetchone()
                    if contrato is None:
                        raise ValueError("Parcela não encontrada.")
                    cd_contrato, status_contrato = contrato

                    cursor = db.execute_sql("""
                        SELECT vl_parcela, pc_desconto, dt_vencimento, dt_pagamento
                        FROM public.tb_parcelas
                        WHERE cd_parcela = %s AND cd_contrato = %s
                        FOR UPDATE
                    """, (cd_parcela, cd_contrato))
                    linha = cursor.fetchone()
                    if linha is None:
                        raise ValueError("Parcela não encontrada.")

                    valor_parcela, _, vencimento, ja_pago = linha
                    if ja_pago is not None:
                        raise ValueError("Esta parcela já possui pagamento confirmado.")
                    if status_contrato not in (2, 3):
                        raise ValueError("O contrato não está vigente ou inadimplente.")

                    total = Parcelas._total_atualizado({
                        "vl_parcela": valor_parcela,
                        "pc_desconto": desconto,
                        "dt_vencimento": vencimento,
                    }, pagamento)
                    if pago != total:
                        raise ValueError(
                            f"Valor informado ({pago:.2f}) diferente do total calculado "
                            f"({total:.2f}). Confira os encargos e o desconto."
                        )

                    db.execute_sql("""
                        UPDATE public.tb_parcelas
                        SET pc_desconto = %s, vl_pago = %s,
                            dt_pagamento = %s, dt_atualizacao = CURRENT_TIMESTAMP
                        WHERE cd_parcela = %s
                    """, (desconto, pago, pagamento, cd_parcela))

                    # Exclusivamente o pagamento pode reverter 3 -> 2.
                    # Não altera contratos com outros status.
                    if status_contrato == 3:
                        db.execute_sql("""
                            UPDATE public.tb_contrato c
                            SET cd_status = 2, dt_atualizacao = CURRENT_TIMESTAMP
                            WHERE c.cd_contrato = %s AND c.cd_status = 3
                              AND NOT EXISTS (
                                  SELECT 1 FROM public.tb_parcelas p
                                  WHERE p.cd_contrato = c.cd_contrato
                                    AND p.dt_pagamento IS NULL
                                    AND p.dt_vencimento < CURRENT_DATE - 3
                              )
                        """, (cd_contrato,))

            return {"sucesso": True, "erro": None}

        except ValueError as exc:
            return {"sucesso": False, "erro": str(exc)}
