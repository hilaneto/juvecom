
from decimal import Decimal, InvalidOperation
from flask import render_template
from weasyprint import HTML
from database.conexao import conectar, db
from datetime import date, datetime, timedelta
from dateutil.relativedelta import relativedelta
from zoneinfo import ZoneInfo


class CadastroContrato:
    MAX_PARCELAS = 600
    CAMPOS_VALOR = ("vl_bruto", "vl_desconto_lojas", "vl_desconto_manual", "vl_acrescimo")

    SEM_ASSINATURA = 1
    VIGENTE = 2
    INADIMPLENTE = 3
    LIQUIDADO = 4
    CANCELADO = 5

    FILTROS_STATUS = (
        (SEM_ASSINATURA, "Sem assinatura"),
        (VIGENTE, "Vigente"),
        (INADIMPLENTE, "Inadimplente"),
        (LIQUIDADO, "Liquidado"),
        (CANCELADO, "Cancelado"),
    )

    @staticmethod
    def tela(cd_cliente=None, cd_contrato=None, cd_status=None):
        with conectar():
            registros = db.execute_sql("""
                SELECT cd_contrato, nm_pessoa, nm_status
                FROM public.fn_listar_contratos(%s)
                ORDER BY cd_contrato DESC
            """, (cd_status,)).fetchall()

            contrato = {}
            parcelas = []
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
                parcelas = CadastroContrato._parcelas(cd_contrato)

            clientes = db.execute_sql("""
                SELECT cl.cd_cliente, p.nm_pessoa FROM public.tb_cliente cl
                JOIN public.tb_pessoa p USING (cd_pessoa)
                WHERE (cl.cd_status IN (1, 2, 3) AND p.fl_ativo) OR cl.cd_cliente = %s
                ORDER BY p.nm_pessoa, cl.cd_cliente
            """, (cd_cliente if contrato else None,)).fetchall()

            if cd_cliente is not None and not any(codigo == cd_cliente for codigo, _ in clientes):
                return None

            planos = db.execute_sql("""
                SELECT cd_plano, nm_plano, cd_plano_tipo FROM public.tb_plano
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
                    cd_cliente=cd_cliente, planos=planos, lojas=lojas, parcelas=parcelas,
                    max_parcelas=CadastroContrato.MAX_PARCELAS,
                    pode_renovar=CadastroContrato._vigencia_encerrada(contrato.get("dt_fim")))

    @staticmethod
    def _vigencia_encerrada(fim, hoje=None):
        hoje = hoje or datetime.now(ZoneInfo("America/Sao_Paulo")).date()
        return fim is not None and fim < hoje

    @classmethod
    def renovar(cls, cd_contrato):
        with conectar(), db.atomic():
            origem = db.execute_sql("""
                SELECT lower(vigencia), upper(vigencia) - 1
                FROM public.tb_contrato WHERE cd_contrato = %s FOR UPDATE
            """, (cd_contrato,)).fetchone()

            if origem is None:
                raise ValueError("Contrato de origem não encontrado.")

            hoje = datetime.now(ZoneInfo("America/Sao_Paulo")).date()
            inicio_anterior, fim_anterior = origem
            if not cls._vigencia_encerrada(fim_anterior, hoje):
                raise ValueError("A renovação só está disponível após o último dia da vigência.")

            renovacao = db.execute_sql("""
                SELECT cd_contrato FROM public.tb_contrato
                WHERE cd_contrato_origem = %s AND cd_status <> %s
            """, (cd_contrato, cls.CANCELADO)).fetchone()
            if renovacao is not None:
                return renovacao[0]

            fim_exclusivo = hoje + (fim_anterior - inicio_anterior) + timedelta(days=1)
            novo = db.execute_sql("""
                INSERT INTO public.tb_contrato (
                    cd_cliente, cd_status, cd_plano, nm_plano, ds_plano, vigencia,
                    vl_bruto, vl_desconto_lojas, vl_desconto_manual, vl_acrescimo,
                    vl_contrato, ds_contrato, cd_contrato_origem
                )
                SELECT cd_cliente, %s, cd_plano, nm_plano, ds_plano, daterange(%s, %s, '[)'),
                       vl_bruto, vl_desconto_lojas, vl_desconto_manual, vl_acrescimo,
                       vl_contrato, ds_contrato, cd_contrato
                FROM public.tb_contrato WHERE cd_contrato = %s
                RETURNING cd_contrato
            """, (cls.SEM_ASSINATURA, hoje, fim_exclusivo, cd_contrato)).fetchone()[0]

            db.execute_sql("""
                INSERT INTO public.tb_contrato_loja (cd_contrato, cd_loja, cd_cliente)
                SELECT %s, cd_loja, cd_cliente
                FROM public.tb_contrato_loja WHERE cd_contrato = %s
            """, (novo, cd_contrato))
            return novo

    @staticmethod
    def _parcelas(cd_contrato):
        return db.execute_sql("""
            SELECT nr_parcela, dt_vencimento, vl_parcela, pc_desconto, dt_pagamento
            FROM public.tb_parcelas
            WHERE cd_contrato = %s
            ORDER BY nr_parcela
        """, (cd_contrato,)).fetchall()

    @classmethod
    def _gerar_parcelas(cls, total, quantidade, primeiro_vencimento):
        try:
            quantidade = int(quantidade)
            primeiro = date.fromisoformat(primeiro_vencimento)
            if not 1 <= quantidade <= cls.MAX_PARCELAS or quantidade > int(total * 100):
                raise ValueError()
            centavos, sobra = divmod(int(total * 100), quantidade)
            return [
                (indice + 1, primeiro + relativedelta(months=indice),
                 Decimal(centavos + (indice >= quantidade - sobra)).scaleb(-2))
                for indice in range(quantidade)
            ]
        except (ValueError, OverflowError) as erro:
            raise ValueError(
                f"Informe um primeiro vencimento válido e de 1 a {cls.MAX_PARCELAS} parcelas "
                "de pelo menos R$ 0,01."
            ) from erro

    @classmethod
    def _salvar_parcelas(cls, cd_contrato, total, quantidade, vencimento):
        atuais = cls._parcelas(cd_contrato)
        total_atual = sum(valor - desconto for _, _, valor, desconto, _ in atuais)
        if not quantidade and not vencimento:
            if atuais and total_atual != total:
                raise ValueError("Atualize o parcelamento para acompanhar o novo valor do contrato.")
            return

        novas = cls._gerar_parcelas(total, quantidade, vencimento)
        if atuais and len(atuais) == len(novas) and atuais[0][1] == novas[0][1] and total_atual == total:
            return

        if any(desconto or pagamento is not None for _, _, _, desconto, pagamento in atuais):
            raise ValueError("O parcelamento contém descontos ou pagamentos registrados e não pode ser recalculado.")

        db.execute_sql("DELETE FROM public.tb_parcelas WHERE cd_contrato = %s", (cd_contrato,))
        numeros, vencimentos, valores = map(list, zip(*novas))
        db.execute_sql("""
            INSERT INTO public.tb_parcelas (cd_contrato, nr_parcela, dt_vencimento, vl_parcela)
            SELECT %s, nr_parcela, dt_vencimento, vl_parcela
            FROM unnest(%s::integer[], %s::date[], %s::numeric[])
                AS parcela(nr_parcela, dt_vencimento, vl_parcela)
        """, (cd_contrato, numeros, vencimentos, valores))

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
                    SELECT cl.cd_status FROM public.tb_cliente cl
                    JOIN public.tb_pessoa p USING (cd_pessoa)
                    WHERE cl.cd_cliente = %s AND cl.cd_status IN (1, 2, 3) AND p.fl_ativo
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

                if (cliente[0] == 1) != confirmar or (confirmar and not pendente):
                    raise ValueError("Volte à ficha do cliente para conferir o pré-cadastro ou iniciar outro contrato.")

            else:
                atual = db.execute_sql("""
                    SELECT cd_cliente, cd_plano, nm_plano, ds_plano
                    FROM public.tb_contrato
                    WHERE cd_contrato = %s AND cd_status = %s
                    FOR UPDATE
                """, (cd_contrato, cls.SEM_ASSINATURA)).fetchone()

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
                if confirmar:
                    db.execute_sql("""
                        UPDATE public.tb_cliente
                        SET cd_status = 2, dt_atualizacao = CURRENT_TIMESTAMP
                        WHERE cd_cliente = %s
                    """, (cd_cliente,))
                cd_contrato = db.execute_sql("""
                    INSERT INTO public.tb_contrato (
                        cd_cliente, cd_status, cd_plano, nm_plano, ds_plano, vigencia,
                        vl_bruto, vl_desconto_lojas, vl_desconto_manual, vl_acrescimo,
                        vl_contrato, ds_contrato
                    ) VALUES (%s, %s, %s, %s, %s, daterange(%s::date, %s::date + 1, '[)'),
                              %s, %s, %s, %s, %s, %s)
                    RETURNING cd_contrato
                """, (cd_cliente, cls.SEM_ASSINATURA, *parametros)).fetchone()[0]

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

                db.execute_sql(
                    "DELETE FROM public.tb_contrato_loja WHERE cd_contrato = %s",
                    (cd_contrato,)
                )

            if lojas:
                db.execute_sql("""
                    INSERT INTO public.tb_contrato_loja (cd_contrato, cd_loja, cd_cliente)
                    SELECT %s, loja, %s FROM unnest(%s::bigint[]) AS lista(loja)
                """, (cd_contrato, cd_cliente, lojas))

            cls._salvar_parcelas(
                cd_contrato, total, formulario.get("qt_parcelas", "").strip(),
                formulario.get("dt_primeiro_vencimento", "").strip(),
            )

        return cd_contrato

    @classmethod
    def cancelar(cls, cd_contrato, motivo):
        motivo = motivo.strip()

        if not motivo:
            raise ValueError("Informe o motivo do cancelamento.")

        with conectar(), db.atomic():
            linha = db.execute_sql("""
                UPDATE public.tb_contrato
                SET cd_status = %s, ds_observacao = %s, dt_atualizacao = CURRENT_TIMESTAMP
                WHERE cd_contrato = %s AND cd_status IN (%s, %s, %s)
                RETURNING cd_contrato
            """, (cls.CANCELADO, motivo, cd_contrato,
                  cls.SEM_ASSINATURA, cls.VIGENTE, cls.INADIMPLENTE)).fetchone()

            if linha is None:
                raise ValueError("Este contrato não pode ser cancelado.")

    @classmethod
    def confirmar_assinatura(cls, cd_contrato):
        with conectar(), db.atomic():
            linha = db.execute_sql("""
                UPDATE public.tb_contrato
                SET cd_status = %s, dt_atualizacao = CURRENT_TIMESTAMP
                WHERE cd_contrato = %s AND cd_status = %s
                  AND vigencia @> (CURRENT_TIMESTAMP AT TIME ZONE 'America/Sao_Paulo')::date
                RETURNING vl_contrato
            """, (cls.VIGENTE, cd_contrato, cls.SEM_ASSINATURA)).fetchone()

            if linha is None:
                raise ValueError("O contrato precisa aguardar assinatura e estar dentro da vigência.")

            total = linha[0]
            parcelas = cls._parcelas(cd_contrato)
            if sum(valor - desconto for _, _, valor, desconto, _ in parcelas) != total:
                raise ValueError("Cadastre as parcelas com a soma igual ao valor do contrato antes de confirmar a assinatura.")

    @staticmethod
    def dados_pdf(cd_contrato):
        def registros(cursor):
            colunas = [coluna[0] for coluna in cursor.description]
            return [dict(zip(colunas, linha)) for linha in cursor.fetchall()]

        with conectar():
            cursor = db.execute_sql("""
                SELECT c.*, lower(c.vigencia) AS dt_inicio,
                       upper(c.vigencia) - 1 AS dt_fim,
                       (c.dt_cadastro AT TIME ZONE 'America/Sao_Paulo')::date AS dt_contrato,
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

        if rua:
            partes.append(f"{rua}, {numero}" if numero else rua)
        if endereco.get("complemento"):
            partes.append(endereco["complemento"])
        if endereco.get("bairro"):
            partes.append(endereco["bairro"])

        cidade, uf = endereco.get("cidade", ""), endereco.get("uf", "")
        if cidade or uf:
            partes.append(f"{cidade}/{uf}" if cidade and uf else cidade or uf)

        cep = endereco.get("cep", "")
        if cep:
            partes.append(f"CEP {cep[:5]}-{cep[5:]}" if len(cep) == 8 else f"CEP {cep}")

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

        html = render_template("contratos/contrato_pdf.html", **dados)
        return HTML(string=html).write_pdf()


    @staticmethod
    def calcular_vigencia(meses, inicio=None):
        meses = int(meses)

        if meses < 1:
            raise ValueError("A vigência deve ser de pelo menos um mês.")

        inicio = inicio or date.today()
        fim = inicio + relativedelta(months=meses) - timedelta(days=1)

        return inicio, fim