from database.conexao import db, conectar


class DashboardAdmin:

    @staticmethod
    def resumo():
        with conectar():
            cursor = db.execute_sql("SELECT * FROM public.vw_dashboard_admin")
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