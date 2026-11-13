from datetime import date
from decimal import Decimal, InvalidOperation
from flask import render_template
from weasyprint import HTML
from database.conexao import conectar, db


class CadastroContrato:
    CAMPOS_VALOR = ("vl_bruto", "vl_desconto_lojas", "vl_desconto_manual", "vl_acrescimo")

    @staticmethod
    def tela(cd_cliente=None, cd_contrato=None):
        with conectar():
            registros = db.execute_sql("""
                SELECT c.cd_contrato, p.nm_pessoa, s.nm_status
                FROM public.tb_contrato c
                JOIN public.tb_cliente cl USING (cd_cliente)
                JOIN public.tb_pessoa p USING (cd_pessoa)
                JOIN public.tb_contrato_status s ON s.cd_status = c.cd_status
                ORDER BY c.cd_contrato DESC
            """).fetchall()

            contrato = {}
            if cd_contrato is not None:
                cursor = db.execute_sql("""
                    SELECT c.*, p.nm_pessoa, s.nm_status,
                           lower(c.vigencia) AS dt_inicio, upper(c.vigencia) - 1 AS dt_fim
                    FROM public.tb_contrato c
                    JOIN public.tb_cliente cl USING (cd_cliente)
                    JOIN public.tb_pessoa p USING (cd_pessoa)
                    JOIN public.tb_contrato_status s ON s.cd_status = c.cd_status
                    WHERE c.cd_contrato = %s
                """, (cd_contrato,))
                linha = cursor.fetchone()
                if linha is None:
                    return None
                contrato = dict(zip((coluna[0] for coluna in cursor.description), linha))
                cd_cliente = contrato["cd_cliente"]

            clientes = db.execute_sql("""
                SELECT cl.cd_cliente, p.nm_pessoa FROM public.tb_cliente cl
                JOIN public.tb_pessoa p USING (cd_pessoa)
                WHERE (cl.fl_ativo AND p.fl_ativo) OR cl.cd_cliente = %s
                ORDER BY p.nm_pessoa, cl.cd_cliente
            """, (cd_cliente if contrato else None,)).fetchall()
            if cd_cliente is not None and not any(codigo == cd_cliente for codigo, _ in clientes):
                return None

            planos = db.execute_sql("""
                SELECT cd_plano, nm_plano FROM public.tb_plano
                WHERE fl_ativo OR cd_plano = %s ORDER BY nm_plano
            """, (contrato.get("cd_plano"),)).fetchall()

            lojas = db.execute_sql("""
                SELECT l.cd_loja, l.nm_loja, v.cd_contrato IS NOT NULL
                FROM public.tb_loja l
                LEFT JOIN public.tb_contrato_loja v
                  ON v.cd_loja = l.cd_loja AND v.cd_contrato = %s
                WHERE l.cd_cliente = %s AND (l.fl_ativo OR v.cd_contrato IS NOT NULL)
                ORDER BY l.nm_loja
            """, (cd_contrato, cd_cliente)).fetchall()

        return dict(registros=registros, contrato=contrato, clientes=clientes,
                    cd_cliente=cd_cliente, planos=planos, lojas=lojas)

    @classmethod
    def salvar(cls, cd_cliente, formulario, cd_contrato=None, confirmar=False):
        try:
            cd_plano = int(formulario.get("cd_plano", ""))
            inicio = date.fromisoformat(formulario.get("dt_inicio", ""))
            fim = date.fromisoformat(formulario.get("dt_fim", ""))
            lojas = sorted({int(valor) for valor in formulario.getlist("cd_loja")})
        except ValueError as erro:
            raise ValueError("Confira o plano, as lojas e a vigência.") from erro
        if fim < inicio or fim == date.max:
            raise ValueError("Informe uma data final válida.")

        limite = Decimal("9999999999.99")
        valores = []
        for campo in cls.CAMPOS_VALOR:
            bruto_obrigatorio = campo == "vl_bruto"
            try:
                valor = Decimal(formulario.get(campo, "").strip() or ("" if bruto_obrigatorio else "0"))
            except InvalidOperation as erro:
                raise ValueError("Confira os valores do contrato.") from erro
            if not valor.is_finite() or not 0 <= valor <= limite or valor != valor.quantize(Decimal(".01")):
                raise ValueError("Use valores não negativos com até duas casas decimais.")
            valores.append(valor)

        bruto, desconto_lojas, desconto_manual, acrescimo = valores
        total = bruto - desconto_lojas - desconto_manual + acrescimo
        descricao = formulario.get("ds_contrato", "").strip()
        if not 0 <= total <= limite or len(descricao) > 500:
            raise ValueError("Confira o total e o limite de 500 caracteres da descrição.")

        with conectar(), db.atomic():
            atual = None
            if cd_contrato is None:
                cliente = db.execute_sql("""
                    SELECT cl.cd_cliente FROM public.tb_cliente cl
                    JOIN public.tb_pessoa p USING (cd_pessoa)
                    WHERE cl.cd_cliente = %s AND cl.fl_ativo AND p.fl_ativo
                    FOR UPDATE OF cl
                """, (cd_cliente,)).fetchone()
                if cliente is None:
                    raise ValueError("Selecione um cliente habilitado.")
                pendente = db.execute_sql("""
                    SELECT EXISTS (
                        SELECT 1 FROM public.tb_cliente_link
                        WHERE cd_cliente = %s AND dt_utilizacao IS NOT NULL
                    ) AND NOT EXISTS (
                        SELECT 1 FROM public.tb_contrato WHERE cd_cliente = %s
                    )
                """, (cd_cliente, cd_cliente)).fetchone()[0]
                if pendente != confirmar:
                    raise ValueError("Volte à ficha do cliente para conferir o pré-cadastro ou iniciar outro contrato.")
            else:
                atual = db.execute_sql("""
                    SELECT cd_cliente, cd_plano, nm_plano, ds_plano
                    FROM public.tb_contrato WHERE cd_contrato = %s AND cd_status = 2
                    FOR UPDATE
                """, (cd_contrato,)).fetchone()
                if atual is None:
                    raise ValueError("Só é possível editar contratos que aguardam assinatura.")
                cd_cliente = atual[0]

            if atual and atual[1] == cd_plano:
                plano = atual[2:]
            else:
                plano = db.execute_sql("""
                    SELECT nm_plano, ds_plano FROM public.tb_plano
                    WHERE cd_plano = %s AND fl_ativo FOR SHARE
                """, (cd_plano,)).fetchone()
            if plano is None:
                raise ValueError("Selecione um plano ativo.")

            if lojas:
                validas = db.execute_sql("""
                    SELECT l.cd_loja FROM public.tb_loja l
                    WHERE l.cd_cliente = %s AND l.cd_loja = ANY(%s::bigint[])
                      AND (l.fl_ativo OR EXISTS (
                          SELECT 1 FROM public.tb_contrato_loja v
                          WHERE v.cd_contrato = %s AND v.cd_loja = l.cd_loja
                      ))
                    FOR SHARE OF l
                """, (cd_cliente, lojas, cd_contrato)).fetchall()
                if {linha[0] for linha in validas} != set(lojas):
                    raise ValueError("Confira as lojas vinculadas ao cliente.")

            parametros = (cd_plano, *plano, inicio, fim, *valores, total, descricao or None)
            if cd_contrato is None:
                cd_contrato = db.execute_sql("""
                    INSERT INTO public.tb_contrato (
                        cd_cliente, cd_status, cd_plano, nm_plano, ds_plano, vigencia,
                        vl_bruto, vl_desconto_lojas, vl_desconto_manual, vl_acrescimo,
                        vl_contrato, ds_contrato
                    ) VALUES (%s, 2, %s, %s, %s, daterange(%s::date, %s::date + 1, '[)'),
                              %s, %s, %s, %s, %s, %s)
                    RETURNING cd_contrato
                """, (cd_cliente, *parametros)).fetchone()[0]
            else:
                db.execute_sql("""
                    UPDATE public.tb_contrato
                    SET cd_plano = %s, nm_plano = %s, ds_plano = %s,
                        vigencia = daterange(%s::date, %s::date + 1, '[)'),
                        vl_bruto = %s, vl_desconto_lojas = %s, vl_desconto_manual = %s,
                        vl_acrescimo = %s, vl_contrato = %s, ds_contrato = %s,
                        dt_atualizacao = CURRENT_TIMESTAMP
                    WHERE cd_contrato = %s
                """, (*parametros, cd_contrato))
                db.execute_sql("DELETE FROM public.tb_contrato_loja WHERE cd_contrato = %s", (cd_contrato,))

            if lojas:
                db.execute_sql("""
                    INSERT INTO public.tb_contrato_loja (cd_contrato, cd_loja, cd_cliente)
                    SELECT %s, loja, %s FROM unnest(%s::bigint[]) AS lista(loja)
                """, (cd_contrato, cd_cliente, lojas))

        return cd_contrato

    @staticmethod
    def cancelar(cd_contrato, motivo):
        motivo = motivo.strip()
        if not motivo:
            raise ValueError("Informe o motivo do cancelamento.")
        with conectar(), db.atomic():
            linha = db.execute_sql("""
                UPDATE public.tb_contrato
                SET cd_status = 6, ds_observacao = %s, dt_atualizacao = CURRENT_TIMESTAMP
                WHERE cd_contrato = %s AND cd_status IN (2, 3, 4)
                RETURNING cd_contrato
            """, (motivo, cd_contrato)).fetchone()
            if linha is None:
                raise ValueError("Este contrato não pode ser cancelado.")

    @staticmethod
    def confirmar_assinatura(cd_contrato):
        with conectar(), db.atomic():
            linha = db.execute_sql("""
                UPDATE public.tb_contrato
                SET cd_status = 3, dt_atualizacao = CURRENT_TIMESTAMP
                WHERE cd_contrato = %s AND cd_status = 2
                  AND vigencia @> (CURRENT_TIMESTAMP AT TIME ZONE 'America/Sao_Paulo')::date
                RETURNING cd_contrato
            """, (cd_contrato,)).fetchone()
            if linha is None:
                raise ValueError("O contrato precisa aguardar assinatura e estar dentro da vigência.")


    @staticmethod
    def dados_pdf(cd_contrato):
        def registros(cursor):
            colunas = [coluna[0] for coluna in cursor.description]
            return [dict(zip(colunas, linha)) for linha in cursor.fetchall()]

        with conectar():
            cursor = db.execute_sql("""
                SELECT c.*, lower(c.vigencia) AS dt_inicio,
                       upper(c.vigencia) - 1 AS dt_fim,
                       p.nm_pessoa AS nome, p.tp_pessoa, p.cpf_cnpj, p.telefone, p.email,
                       p.dados AS endereco_dados, cl.nm_responsavel
                FROM public.tb_contrato c
                JOIN public.tb_cliente cl ON cl.cd_cliente = c.cd_cliente
                JOIN public.tb_pessoa p ON p.cd_pessoa = cl.cd_pessoa
                WHERE c.cd_contrato = %s
            """, (cd_contrato,))
            contratos = registros(cursor)
            if not contratos:
                return None

            contrato = contratos[0]
            cursor = db.execute_sql("""
                SELECT l.cd_loja, l.nm_loja, l.shop_id, l.url_loja
                FROM public.tb_contrato_loja cl
                JOIN public.tb_loja l ON l.cd_loja = cl.cd_loja
                WHERE cl.cd_contrato = %s ORDER BY l.nm_loja
            """, (cd_contrato,))
            lojas = registros(cursor)

            cursor = db.execute_sql("""
                SELECT nr_parcela, dt_vencimento, vl_parcela, vl_desconto,
                       dt_pagamento, vl_pago
                FROM public.tb_parcelas
                WHERE cd_contrato = %s ORDER BY nr_parcela, cd_parcela
            """, (cd_contrato,))
            parcelas = registros(cursor)

        cliente = {campo: contrato[campo] for campo in
                   ("nome", "tp_pessoa", "cpf_cnpj", "telefone", "email", "nm_responsavel")}
        cliente["endereco_dados"] = contrato["endereco_dados"] or {}
        endereco = cliente["endereco_dados"]
        partes = []
        rua = endereco.get("endereco", "").strip()
        numero = endereco.get("numero", "").strip()
        if rua: partes.append(f"{rua}, {numero}" if numero else rua)
        if endereco.get("complemento"): partes.append(endereco["complemento"])
        if endereco.get("bairro"): partes.append(endereco["bairro"])
        cidade, uf = endereco.get("cidade", ""), endereco.get("uf", "")
        if cidade or uf: partes.append(f"{cidade}/{uf}" if cidade and uf else cidade or uf)
        cep = endereco.get("cep", "")
        if cep: partes.append(f"CEP {cep[:5]}-{cep[5:]}" if len(cep) == 8 else f"CEP {cep}")
        cliente["endereco"] = " - ".join(partes) or "Endereço não informado"
        cpf = "".join(c for c in (cliente["cpf_cnpj"] or "") if c.isdigit())
        if len(cpf) == 11:
            cliente["documento_formatado"] = f"{cpf[:3]}.{cpf[3:6]}.{cpf[6:9]}-{cpf[9:]}"
        elif len(cpf) == 14:
            cliente["documento_formatado"] = f"{cpf[:2]}.{cpf[2:5]}.{cpf[5:8]}/{cpf[8:12]}-{cpf[12:]}"
        else:
            cliente["documento_formatado"] = cliente["cpf_cnpj"]
        contrato["total_parcelas"] = len(parcelas)
        return dict(contrato=contrato, cliente=cliente, lojas=lojas, parcelas=parcelas)

    @staticmethod
    def gerar_pdf(cd_contrato):
        dados = CadastroContrato.dados_pdf(cd_contrato)
        if dados is None:
            return None
        # Documento gerado integralmente a partir do cadastro e do contrato.
        html = render_template("contratos/contrato_pdf.html", **dados)
        return HTML(string=html).write_pdf()
