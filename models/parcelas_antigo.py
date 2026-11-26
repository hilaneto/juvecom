"""JUV-027 — Controle de parcelas e baixa de pagamentos.

A listagem exibe os valores de public.vw_cobranca_inadimplentes (referência
CURRENT_DATE). A confirmação calcula os encargos no PostgreSQL para a data
efetiva do pagamento, usando a mesma política de public.tb_encargo_atraso.

IMPORTANTE: Para este modulo, somente contratos com cd_status IN (2, 3)
permitem cobranca e baixa. Status 1 (Sem assinatura), 4 (Liquidado) e
5 (Cancelado) nao permitem nova baixa. A view deve preservar (2, 3).

Não há cálculo monetário em JavaScript nem valor pago informado pelo operador.
"""

from datetime import date, datetime
from decimal import Decimal, InvalidOperation
from zoneinfo import ZoneInfo

from database.conexao import db, conectar


class Parcelas:
    FUSO = ZoneInfo("America/Sao_Paulo")
    CENTAVOS = Decimal("0.01")
    ATIVO = 2
    INADIMPLENTE = 3

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
    def _data(valor):
        if isinstance(valor, date) and not isinstance(valor, datetime):
            return valor
        try:
            return date.fromisoformat(str(valor).strip())
        except (TypeError, ValueError):
            raise ValueError("Informe uma data de pagamento válida.") from None

    @staticmethod
    def _validar_entrada(dados):
        desconto = Parcelas._decimal(dados.get("pc_desconto", ""), "desconto")
        pagamento = Parcelas._data(dados.get("dt_pagamento", ""))
        if desconto < 0 or desconto > 100 or desconto.as_tuple().exponent < -2:
            raise ValueError("O desconto deve estar entre 0 e 100%, com até duas casas decimais.")
        if pagamento > Parcelas._hoje():
            raise ValueError("A data de pagamento não pode ser futura.")
        return desconto, pagamento

    @staticmethod
    def tela(cd_parcela=None):
        """Retorna registros, listas pendentes e valores atuais da view."""
        with conectar():
            cursor = db.execute_sql("""
                SELECT p.cd_parcela, p.cd_contrato, p.nr_parcela,
                       p.dt_vencimento, p.vl_parcela, p.pc_desconto,
                       p.dt_pagamento, p.vl_pago, p.dt_atualizacao,
                       c.nm_plano, c.vl_bruto, c.vl_contrato,
                       c.cd_status AS cd_status_contrato,
                       st.nm_status AS status_contrato, c.vigencia,
                       LOWER(c.vigencia) AS dt_inicio_vigencia,
                       CASE WHEN UPPER_INF(c.vigencia) THEN NULL
                            ELSE UPPER(c.vigencia) - 1 END AS dt_fim_vigencia,
                       cl.cd_cliente, cl.nm_responsavel,
                       pe.nm_pessoa, pe.cpf_cnpj, pe.telefone, pe.email,
                       CASE WHEN p.dt_pagamento IS NOT NULL THEN 0
                            ELSE GREATEST(CURRENT_DATE - p.dt_vencimento, 0) END AS dias_atraso,
                       fin.vl_multa, fin.vl_juros_mensal,
                       fin.vl_juros_diario, fin.vl_juros,
                       fin.vl_desconto_calculado,
                       CASE WHEN fin.cd_parcela IS NOT NULL
                            THEN p.vl_parcela + fin.vl_multa + fin.vl_juros
                            WHEN p.dt_vencimento >= CURRENT_DATE AND p.dt_pagamento IS NULL
                            THEN p.vl_parcela ELSE NULL END AS vl_total_sem_desconto,
                       CASE WHEN p.dt_pagamento IS NOT NULL THEN p.vl_pago
                            WHEN fin.cd_parcela IS NOT NULL THEN fin.vl_total_atualizado
                            WHEN p.dt_vencimento >= CURRENT_DATE AND p.pc_desconto = 0 THEN p.vl_parcela
                            ELSE NULL END AS vl_total_atualizado,
                       (fin.cd_parcela IS NOT NULL) AS tem_demonstrativo_view
                FROM public.tb_parcelas p
                JOIN public.tb_contrato c ON c.cd_contrato = p.cd_contrato
                JOIN public.tb_contrato_status st ON st.cd_status = c.cd_status
                JOIN public.tb_cliente cl ON cl.cd_cliente = c.cd_cliente
                JOIN public.tb_pessoa pe ON pe.cd_pessoa = cl.cd_pessoa
                LEFT JOIN public.vw_cobranca_inadimplentes fin
                       ON fin.cd_parcela = p.cd_parcela
                ORDER BY p.dt_vencimento, p.cd_parcela
            """)
            registros = Parcelas._linhas(cursor)

        hoje = Parcelas._hoje()
        for p in registros:
            # A view apenas cobre inadimplentes; valores ausentes NÃO são
            # convertidos em zero para parcelas antigas, evitando falsa quitação.
            if p["dt_pagamento"] is None and p["dt_vencimento"] >= hoje and p["pc_desconto"] == 0:
                for campo in ("vl_multa", "vl_juros_mensal", "vl_juros_diario", "vl_juros", "vl_desconto_calculado"):
                    if p[campo] is None:
                        p[campo] = Decimal("0.00")
            p["demonstrativo_disponivel"] = bool(
                p["tem_demonstrativo_view"] or
                (p["dt_pagamento"] is None and p["dt_vencimento"] >= hoje and p["pc_desconto"] == 0)
            )

        pendentes = [p for p in registros if p["dt_pagamento"] is None
                     and p["cd_status_contrato"] in (Parcelas.ATIVO, Parcelas.INADIMPLENTE)]
        selecionada = next((p for p in registros if p["cd_parcela"] == cd_parcela), None)
        if selecionada is None:
            selecionada = next(iter(pendentes), None)
        return {
            "vencidas": [p for p in pendentes if p["dt_vencimento"] < hoje],
            "vencem_hoje": [p for p in pendentes if p["dt_vencimento"] == hoje],
            "futuras": [p for p in pendentes if p["dt_vencimento"] > hoje],
            "selecionada": selecionada,
            "hoje": hoje,
        }

    @staticmethod
    def _calcular_no_banco(parcela, pagamento, desconto):
        """SQL com as mesmas fórmulas da view, mas data parametrizada.

        Deve ser chamado dentro de uma conexão aberta. Não grava no banco.
        """
        cursor = db.execute_sql("""
            WITH entrada AS (
                SELECT %s::numeric AS vl_parcela, %s::date AS dt_vencimento,
                       %s::date AS dt_referencia, %s::numeric AS pc_desconto
            ), encargos AS (
                SELECT x.vl_parcela,
                       GREATEST(x.dt_referencia - x.dt_vencimento, 0) AS dias_atraso,
                       CASE WHEN x.dt_referencia - x.dt_vencimento > e.dias_carencia
                            THEN ROUND(x.vl_parcela * e.percentual_multa / 100, 2)
                            ELSE 0::numeric END AS vl_multa,
                       ROUND(x.vl_parcela * e.juros_mensal / 100 *
                             GREATEST(x.dt_referencia - x.dt_vencimento - e.dias_carencia, 0) / 30, 2)
                             AS vl_juros_mensal,
                       ROUND(x.vl_parcela * e.juros_diario / 100 *
                             GREATEST(x.dt_referencia - x.dt_vencimento - e.dias_carencia, 0), 2)
                             AS vl_juros_diario,
                       x.pc_desconto
                FROM entrada x
                JOIN public.tb_encargo_atraso e ON e.vigencia @> x.dt_vencimento
            ), subtotal AS (
                SELECT *, (vl_parcela + vl_multa + vl_juros_mensal + vl_juros_diario)
                          AS vl_total_sem_desconto
                FROM encargos
            )
            SELECT vl_parcela AS valor_original, dias_atraso, vl_multa,
                   vl_juros_mensal, vl_juros_diario,
                   (vl_juros_mensal + vl_juros_diario) AS vl_juros,
                   vl_total_sem_desconto,
                   ROUND(vl_total_sem_desconto * pc_desconto / 100, 2)
                       AS vl_desconto_calculado,
                   vl_total_sem_desconto - ROUND(vl_total_sem_desconto * pc_desconto / 100, 2)
                       AS vl_pago
            FROM subtotal
        """, (parcela["vl_parcela"], parcela["dt_vencimento"], pagamento, desconto))
        linhas = Parcelas._linhas(cursor)
        if not linhas:
            raise ValueError("Não existe política de encargos para o vencimento desta parcela.")
        return linhas[0]

    @staticmethod
    def _buscar_parcela_para_pagamento(cd_parcela, bloquear=False):
        # O contrato deve ser bloqueado antes da parcela nas confirmações.
        if bloquear:
            cursor = db.execute_sql("""
                SELECT c.cd_contrato, c.cd_status
                FROM public.tb_contrato c
                JOIN public.tb_parcelas p ON p.cd_contrato = c.cd_contrato
                WHERE p.cd_parcela = %s FOR UPDATE OF c
            """, (cd_parcela,))
            contrato = cursor.fetchone()
            if contrato is None:
                raise ValueError("Parcela não encontrada.")
            cd_contrato, status = contrato
            cursor = db.execute_sql("""
                SELECT vl_parcela, dt_vencimento, dt_pagamento
                FROM public.tb_parcelas
                WHERE cd_parcela = %s AND cd_contrato = %s FOR UPDATE
            """, (cd_parcela, cd_contrato))
            linha = cursor.fetchone()
            if linha is None:
                raise ValueError("Parcela não encontrada.")
            valor, vencimento, ja_pago = linha
        else:
            cursor = db.execute_sql("""
                SELECT p.vl_parcela, p.dt_vencimento, p.dt_pagamento, c.cd_status
                FROM public.tb_parcelas p JOIN public.tb_contrato c
                  ON c.cd_contrato = p.cd_contrato
                WHERE p.cd_parcela = %s
            """, (cd_parcela,))
            linha = cursor.fetchone()
            if linha is None:
                raise ValueError("Parcela não encontrada.")
            valor, vencimento, ja_pago, status = linha
            cd_contrato = None
        if ja_pago is not None:
            raise ValueError("Esta parcela já possui pagamento confirmado.")
        if status not in (Parcelas.ATIVO, Parcelas.INADIMPLENTE):
            raise ValueError("O contrato não está ativo ou inadimplente.")
        return {"vl_parcela": valor, "dt_vencimento": vencimento}, cd_contrato, status

    @staticmethod
    def previa_pagamento(cd_parcela, dados):
        """Compatibilidade para uma eventual rota de consulta; não grava."""
        try:
            if not isinstance(cd_parcela, int) or isinstance(cd_parcela, bool) or cd_parcela <= 0:
                raise ValueError("Código da parcela inválido.")
            desconto, pagamento = Parcelas._validar_entrada(dados)
            with conectar():
                parcela, _, _ = Parcelas._buscar_parcela_para_pagamento(cd_parcela)
                valores = Parcelas._calcular_no_banco(parcela, pagamento, desconto)
            valores["pc_desconto"] = desconto
            valores["vl_total_atualizado"] = valores["vl_total_sem_desconto"]
            valores["vl_total_pagar"] = valores["vl_pago"]
            return {"sucesso": True, "dados": valores}
        except ValueError as exc:
            return {"sucesso": False, "erro": str(exc)}

    @staticmethod
    def confirmar_pagamento(cd_parcela, dados):
        """Baixa sem valor digitado; recalcula e persiste atomicamente."""
        try:
            if not isinstance(cd_parcela, int) or isinstance(cd_parcela, bool) or cd_parcela <= 0:
                raise ValueError("Código da parcela inválido.")
            desconto, pagamento = Parcelas._validar_entrada(dados)
            # A confirmação exige uma prévia exibida e valores não modificados.
            try:
                desconto_previa = Parcelas._decimal(
                    dados.get("previa_desconto", ""), "desconto da prévia"
                )
                data_previa = Parcelas._data(dados.get("previa_pagamento", ""))
            except ValueError:
                raise ValueError("Recalcule o demonstrativo antes de confirmar o pagamento.") from None

            if desconto_previa != desconto or data_previa != pagamento:
                raise ValueError("Desconto ou data alterados. Recalcule antes de confirmar.")

            try:
                total_previa = Parcelas._decimal(dados.get("previa_total", ""), "total previsto")
            except ValueError:
                raise ValueError("Recalcule o demonstrativo antes de confirmar o pagamento.") from None
            with conectar():
                with db.atomic():
                    parcela, cd_contrato, status = Parcelas._buscar_parcela_para_pagamento(cd_parcela, bloquear=True)
                    demonstrativo = Parcelas._calcular_no_banco(parcela, pagamento, desconto)
                    pago = demonstrativo["vl_pago"]
                    if pago != total_previa:
                        raise ValueError("O valor mudou desde a prévia. Recalcule antes de confirmar.")
                    if pago <= 0:
                        raise ValueError("O valor calculado para pagamento deve ser positivo.")
                    cursor = db.execute_sql("""
                        UPDATE public.tb_parcelas
                        SET pc_desconto = %s, vl_pago = %s, dt_pagamento = %s,
                            dt_atualizacao = CURRENT_TIMESTAMP
                        WHERE cd_parcela = %s AND dt_pagamento IS NULL
                        RETURNING cd_parcela
                    """, (desconto, pago, pagamento, cd_parcela))
                    if cursor.fetchone() is None:
                        raise ValueError("Pagamento já confirmado por outra operação.")
                    if status == Parcelas.INADIMPLENTE:
                        db.execute_sql("""
                            UPDATE public.tb_contrato c
                            SET cd_status = %s, dt_atualizacao = CURRENT_TIMESTAMP
                            WHERE c.cd_contrato = %s AND c.cd_status = %s
                              AND NOT EXISTS (
                                  SELECT 1 FROM public.tb_parcelas p
                                  WHERE p.cd_contrato = c.cd_contrato
                                    AND p.dt_pagamento IS NULL
                                    AND p.dt_vencimento < CURRENT_DATE - 3
                              )
                        """, (Parcelas.ATIVO, cd_contrato, Parcelas.INADIMPLENTE))
            return {"sucesso": True, "erro": None}
        except ValueError as exc:
            return {"sucesso": False, "erro": str(exc)}
