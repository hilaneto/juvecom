from database.conexao import db, conectar


class DashboardAdmin:

    @staticmethod
    def administrativo():
        with conectar():
            cursor = db.execute_sql("""
                SELECT origem, cd_status, nm_status, qtd, valor FROM public.vw_dash_adm ORDER BY origem, cd_status
            """)
            campos = [coluna[0] for coluna in cursor.description]
            registros = [dict(zip(campos, linha)) for linha in cursor.fetchall()]

        return {
            origem: [registro for registro in registros if registro["origem"] == origem]
            for origem in ("Cliente", "Contrato", "Contato")
        }

    @staticmethod
    def financeiro():
        with conectar():
            cursor = db.execute_sql("SELECT vl_parcelas_a_vencer, qt_parcelas_a_vencer, vl_parcelas_vencidas, qt_parcelas_vencidas, vl_contratos_vencidos, qt_contratos_vencidos FROM public.vw_dash_fin")
            campos = [coluna[0] for coluna in cursor.description]
            registro = cursor.fetchone()
            return dict(zip(campos, registro)) if registro else {}

    @staticmethod
    def contatos_recentes():
        with conectar():
            cursor = db.execute_sql("""
                SELECT nm_contato, email, celular, dt_cadastro,
                       CURRENT_DATE - dt_cadastro::date AS dias_aguardando
                FROM public.tb_contato
                WHERE cd_status = 1
                ORDER BY dt_cadastro DESC
            """)
            campos = [coluna[0] for coluna in cursor.description]
            return [dict(zip(campos, linha)) for linha in cursor.fetchall()]