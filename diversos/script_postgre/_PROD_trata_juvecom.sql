

SELECT table_name FROM information_schema.tables
WHERE table_schema = 'public';

GRANT USAGE ON SCHEMA public TO app_juvecom;

GRANT SELECT ON TABLE
    public.vw_usuario,
    public.vw_cliente_contrato,
    public.vw_dash_adm,
    public.vw_dash_fin,
    public.vw_cobranca_proximos,
    public.vw_cobranca_inadimplentes
TO app_juvecom;

-- Table ---------------------------------------
select * from tb_pessoa;
select * from tb_cliente;
select * from tb_cliente_status;
select * from tb_contato;
select * from tb_loja;
select * from tb_plano;
select * from tb_plano_servico;
select * from tb_servico;
select * from tb_contrato_status;
select * from tb_contrato;
select * from tb_contrato_documento;
select * from tb_contrato_modelo;
select * from tb_parcelas;
select * from tb_desconto_loja;
select * from tb_contrato_loja;
select * from tb_usuario;
select * from tb_usuario_nivel;
select * from tb_cliente_link;
select * from tb_logusuario;
select * from tb_evento_log;
select * from tb_encargo_atraso;

-- Views ---------------------------------------
select * from vw_usuario;
select * from vw_cliente_contrato;
select * from vw_dash_adm;
select * from vw_dash_fin;
select * from vw_cobranca_proximos;
select * from vw_cobranca_inadimplentes;

--(excluída) select * from vw_cobranca_vencidos; 

-- ========================================================================================================================================================= *
-- Contratos * Contratos * Contratos * Contratos * Contratos * Contratos * Contratos * Contratos * Contratos * Contratos * Contratos * Contratos * Contratos *
-- ========================================================================================================================================================= *

-- Relatório Contrato Status --------------------------------------------------------------------
select a.cd_contrato, a.cd_status_contrato, a.nm_pessoa, b.nm_status, count(*), sum(vl_contrato)
from vw_cliente_contrato a inner join tb_contrato_status b
on a.cd_status_contrato = b.cd_status
group by a.cd_contrato, a.cd_status_contrato, b.nm_status, a.nm_pessoa
order by b.nm_status, a.nm_pessoa, a.cd_status_contrato;

select * from vw_cliente_contrato
where cd_contrato in (39, 2)

select * from tb_contrato
where cd_status = 1;

-- ==============================================================================
SELECT * FROM public.fn_listar_contratos();  -- Todos
SELECT * FROM public.fn_listar_contratos(1); -- Sem assinatura
SELECT * FROM public.fn_listar_contratos(2); -- Vigente
SELECT * FROM public.fn_listar_contratos(3); -- Inadimplente
SELECT * FROM public.fn_listar_contratos(4); -- Liquidado
SELECT * FROM public.fn_listar_contratos(5); -- Cancelado

-- ==============================================================================
SELECT s.cd_status, s.nm_status, COUNT(c.cd_contrato) AS contratos
FROM public.tb_contrato_status s
LEFT JOIN public.tb_contrato c ON c.cd_status = s.cd_status
GROUP BY s.cd_status, s.nm_status
ORDER BY s.cd_status;




-- ============================================================================================================================================================= *
-- Parcelas Vencidas * Parcelas Vencidas * Parcelas Vencidas * Parcelas Vencidas * Parcelas Vencidas * Parcelas Vencidas * Parcelas Vencidas * Parcelas Vencidas *
-- ============================================================================================================================================================= *

-- Relatório Parcelas Vencidas  ------------------------------------------------------------
select b.cd_contrato, a.Nr_parcela, b.nm_pessoa, dt_vencimento, a.vl_parcela, b.vl_contrato
from tb_parcelas a inner join vw_cliente_contrato b
on a.cd_contrato = b.cd_contrato
WHERE dt_pagamento IS NULL
AND CURRENT_DATE - a.dt_vencimento > 1
AND b.cd_status_contrato  in(2,3)



-- ============================================================================================================================================================== *
-- Parcelas a Vencer  * Parcelas a Vencer * Parcelas a Vencer * Parcelas a Vencer * Parcelas a Vencer * Parcelas a Vencer * Parcelas a Vencer * Parcelas a Vencer *
-- ============================================================================================================================================================== *

-- Relatório Parcelas a Vencer --------------------------------------------------------------------
SELECT p.cd_parcela, p.cd_contrato, p.nr_parcela, pe.nm_pessoa, pe.telefone, pe.email, c.nm_plano,
p.dt_vencimento, p.dt_vencimento - CURRENT_DATE AS dias_para_vencer, p.vl_parcela AS vl_a_pagar
FROM tb_parcelas p
JOIN tb_contrato c ON c.cd_contrato = p.cd_contrato
JOIN tb_contrato_status st ON st.cd_status = c.cd_status
JOIN tb_cliente cl ON cl.cd_cliente = c.cd_cliente
JOIN tb_pessoa pe ON pe.cd_pessoa = cl.cd_pessoa
WHERE p.dt_pagamento IS NULL
AND p.dt_vencimento BETWEEN CURRENT_DATE + 1 AND CURRENT_DATE + 30
AND st.cd_status IN (2, 3);



-- ======================================================================================================================================================= *
-- Contatos * Contatos * Contatos * Contatos * Contatos * Contatos * Contatos * Contatos * Contatos * Contatos * Contatos * Contatos * Contatos * Contatos *
-- ======================================================================================================================================================= *

-- Relatório Contatos Status  --------------------------------------------------------------------
select cd_status, nm_contato, celular, dt_cadastro,
case when cd_status = 1 then 'Pendente' 
     when cd_status = 2 then 'Atendido'
     when cd_status = 3 then 'Perdido' end as nm_status,  count(cd_status) as qtd
from tb_contato
group by cd_status, nm_contato, celular, dt_cadastro
order by cd_status;


-- ======================================================================================================================================================= *
-- Diversos * Diversos * Diversos * Diversos * Diversos * Diversos * Diversos * Diversos * Diversos * Diversos * Diversos * Diversos * Diversos * Diversos *
-- ======================================================================================================================================================= *

-- Ultimas Atualizações ------------------------------------ 
select * from
(select max(dt_atualizacao) as tb_pessoa from tb_pessoa) a
cross join
(select max(dt_atualizacao) as tb_cliente from tb_cliente) b
cross join
(select max(dt_atualizacao) as tb_contrato from tb_contrato) c
cross join
(select max(dt_atualizacao) as tb_loja from tb_loja) d
cross join
(select max(dt_atualizacao) as tb_parcelas from tb_parcelas) e;


SELECT COUNT(*) AS parcelas_inadimplentes, COALESCE(SUM(vl_total_atualizado), 0) AS valor_inadimplencia FROM public.vw_cobranca_inadimplentes


select TO_CHAR(dt_vencimento, 'MM-YYYY'), sum(vl_parcela), count(*)
from vw_cobranca_inadimplentes
group by TO_CHAR(dt_vencimento, 'MM-YYYY')


-- ====================================================================================================================================================== *
-- Ad-Hoc * Ad-Hoc * Ad-Hoc * Ad-Hoc * Ad-Hoc * Ad-Hoc * Ad-Hoc * Ad-Hoc * Ad-Hoc * Ad-Hoc * Ad-Hoc * Ad-Hoc * Ad-Hoc * Ad-Hoc * Ad-Hoc * Ad-Hoc * Ad-Hoc *  
-- ====================================================================================================================================================== *

SELECT cd_parcela, cd_contrato, nr_parcela,
       vl_parcela, pc_desconto, vl_pago,
       dt_vencimento, dt_pagamento, dt_atualizacao
FROM tb_parcelas
WHERE cd_parcela = 1;


select * from tb_parcelas;

select distinct dt_pagamento, vl_pago  from tb_parcelas;
	
SELECT current_database() AS banco,
       current_schema() AS schema,
       current_user AS usuario,
       inet_server_addr() AS servidor,
       inet_server_port() AS porta;


SELECT cd_parcela, cd_contrato, nr_parcela,
       vl_parcela, pc_desconto, vl_pago,
       dt_vencimento, dt_pagamento, dt_atualizacao
FROM public.tb_parcelas
WHERE cd_parcela = 58;


SELECT COUNT(*) AS total_parcelas,
       COUNT(dt_pagamento) AS parcelas_pagas,
       COUNT(*) FILTER (WHERE dt_pagamento IS NULL) AS pendentes
FROM public.tb_parcelas;


UPDATE public.tb_parcelas
SET pc_desconto = %s,
    vl_pago = %s,
    dt_pagamento = %s,
    dt_atualizacao = CURRENT_TIMESTAMP
WHERE cd_parcela = %s


SELECT cd_parcela, cd_contrato, nr_parcela,
       vl_parcela, pc_desconto, vl_pago,
       dt_vencimento, dt_pagamento, dt_atualizacao
FROM public.tb_parcelas
WHERE dt_pagamento IS NOT NULL
ORDER BY dt_pagamento DESC;

