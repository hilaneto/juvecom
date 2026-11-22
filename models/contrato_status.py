from database.conexao import db, conectar

class ContratoStatus:

    @staticmethod
    def atualizar_inadimplencia():
        with conectar():
            db.execute_sql("""
                UPDATE tb_contrato c
                SET cd_status = 3,
                    dt_atualizacao = CURRENT_TIMESTAMP
                WHERE c.cd_status = 2
                  AND EXISTS (
                      SELECT 1 FROM tb_parcelas p
                      WHERE p.cd_contrato = c.cd_contrato
                        AND p.dt_pagamento IS NULL
                        AND p.dt_vencimento < CURRENT_DATE - 3
                  )
            """)
