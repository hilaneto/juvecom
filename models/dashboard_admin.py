from database.conexao import db, conectar


class DashboardAdmin:

    @staticmethod
    def resumo():
        sql = """
            SELECT
                (SELECT COUNT(*) FROM tb_cliente WHERE fl_ativo = TRUE) AS clientes_ativos,

                (SELECT COUNT(*)
                 FROM tb_contrato c
                 JOIN tb_contrato_status s ON s.cd_status = c.cd_status
                 WHERE LOWER(s.nm_status) = 'ativo') AS contratos_ativos,

                (SELECT COUNT(*) FROM vw_contatos_pendentes) AS contatos_pendentes,

                (SELECT COUNT(*) FROM vw_cobranca_vencidos) AS parcelas_vencidas,

                (SELECT COUNT(*) FROM vw_cobranca_proximos) AS parcelas_proximas,

                (SELECT COUNT(*) FROM vw_cobranca_inadimplentes) AS parcelas_inadimplentes,

                (SELECT COALESCE(SUM(vl_a_pagar), 0)
                 FROM vw_cobranca_proximos) AS valor_proximos,

                (SELECT COALESCE(SUM(vl_original), 0)
                 FROM vw_cobranca_vencidos) AS valor_vencidos,

                (SELECT COALESCE(SUM(vl_original + vl_multa + vl_juros), 0)
                 FROM vw_cobranca_inadimplentes) AS valor_inadimplencia
        """

        with conectar():
            cursor = db.execute_sql(sql)
            campos = [coluna[0] for coluna in cursor.description]
            return dict(zip(campos, cursor.fetchone()))

    @staticmethod
    def contatos_recentes(limite=5):
        sql = """
            SELECT cd_contato, nm_contato, email, celular,
                   dt_cadastro, dias_aguardando
            FROM vw_contatos_pendentes
            ORDER BY dt_cadastro DESC
            LIMIT %s
        """

        with conectar():
            cursor = db.execute_sql(sql, (limite,))
            campos = [coluna[0] for coluna in cursor.description]
            return [dict(zip(campos, linha)) for linha in cursor.fetchall()]