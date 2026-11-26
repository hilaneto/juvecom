

SELECT table_name FROM information_schema.tables
WHERE table_schema = 'public';

GRANT SELECT, INSERT, UPDATE, DELETE
ON public.vw_cobranca_inadimplentes TO app_juvecom;

GRANT SELECT
ON public.vw_dash_fin TO app_juvecom;

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
select * from tb_encargo_atraso;
select * from tb_desconto_loja;
select * from tb_contrato_loja;
select * from tb_usuario;
select * from tb_usuario_nivel;
select * from tb_cliente_link;
select * from tb_logusuario;
select * from tb_evento_log;

-- Views ---------------------------------------
select * from vw_usuario;
select * from vw_cliente_contrato;
select * from vw_dash_adm;
select * from vw_dash_fin;
select * from vw_cobranca_proximos;
select * from vw_cobranca_inadimplentes;


-- ========================================================================================================================================================= *
-- Contratos * Contratos * Contratos * Contratos * Contratos * Contratos * Contratos * Contratos * Contratos * Contratos * Contratos * Contratos * Contratos *
-- ========================================================================================================================================================= *

-- Relatório Contrato Status --------------------------------------------------------------------
select a.cd_contrato, a.cd_status_contrato, a.nm_pessoa, b.nm_status, count(*), sum(vl_contrato)
from vw_cliente_contrato a inner join tb_contrato_status b
on a.cd_status_contrato = b.cd_status
group by a.cd_contrato, a.cd_status_contrato, b.nm_status, a.nm_pessoa
order by b.nm_status, a.nm_pessoa, a.cd_status_contrato;



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

select * from tb_encargo_atraso;

select * from vw_cobranca_inadimplentes;


SELECT p.cd_parcela, p.cd_contrato, p.nr_parcela, pe.nm_pessoa, pe.telefone, pe.email, c.nm_plano,
st.nm_status AS status_contrato, p.dt_vencimento,
CURRENT_DATE - p.dt_vencimento AS dias_atraso, p.vl_parcela, c.vl_contrato,
enc.vl_multa, enc.vl_juros_mensal, enc.vl_juros_diario,
(enc.vl_juros_mensal + enc.vl_juros_diario) AS vl_juros,
p.pc_desconto,
ROUND((p.vl_parcela + enc.vl_multa + enc.vl_juros_mensal + enc.vl_juros_diario) * p.pc_desconto / 100, 2) AS vl_desconto_calculado,
(p.vl_parcela + enc.vl_multa + enc.vl_juros_mensal + enc.vl_juros_diario)
- ROUND((p.vl_parcela + enc.vl_multa + enc.vl_juros_mensal + enc.vl_juros_diario) * p.pc_desconto / 100, 2) AS vl_total_atualizado
FROM tb_parcelas p JOIN tb_contrato c ON c.cd_contrato = p.cd_contrato
JOIN tb_contrato_status st ON st.cd_status = c.cd_status
JOIN tb_cliente cl ON cl.cd_cliente = c.cd_cliente
JOIN tb_pessoa pe ON pe.cd_pessoa = cl.cd_pessoa
JOIN tb_encargo_atraso e ON e.vigencia @> p.dt_vencimento
CROSS JOIN LATERAL (
select CASE WHEN CURRENT_DATE - p.dt_vencimento > e.dias_carencia
THEN ROUND(p.vl_parcela * e.percentual_multa / 100, 2) ELSE 0::numeric END AS vl_multa,
ROUND(p.vl_parcela * e.juros_mensal / 100 * GREATEST(CURRENT_DATE - p.dt_vencimento - e.dias_carencia, 0) / 30, 2) AS vl_juros_mensal,
ROUND(p.vl_parcela * e.juros_diario / 100 * GREATEST(CURRENT_DATE - p.dt_vencimento - e.dias_carencia, 0), 2) AS vl_juros_diario
) enc
WHERE p.dt_pagamento IS NULL AND p.dt_vencimento < CURRENT_DATE - 1 AND st.cd_status in(2,3);



SELECT cd_parcela, cd_contrato, nr_parcela,
       dt_vencimento, vl_parcela, pc_desconto,
       vl_pago, dt_pagamento, dt_atualizacao
FROM public.tb_parcelas
WHERE cd_contrato = 13
ORDER BY nr_parcela;

select * from tb_parcelas;

select * from tb_contrato;

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



















-- Pessoa ------------------------------------
INSERT INTO tb_pessoa
(cd_pessoa, tp_pessoa, nm_pessoa, cpf_cnpj, telefone, email, dados, fl_ativo, dt_cadastro, dt_atualizacao)
OVERRIDING SYSTEM VALUE
values
(0, 'F', 'José Hilário Alves Neto', '06478701859', '11 9 7666-0826', 'hilaneto@yahoo.com.br',
 '{"uf":"","cep":"06075260","bairro":"Cipava","cidade":"Osasco","numero":"185","endereco":"Av. Benedito Lopes da Silva","complemento":"casa"}'::jsonb,
 true, '2026-10-22 14:00:10.755-03', '2026-10-29 13:59:52.628-03'),
 
(1, 'F', 'Juvenal Pereira de Souza', '12345678195', '11 98738-5695', 'variedadesjps@gmail.com',
 '{}'::jsonb, true, '2026-10-22 14:00:10.755-03', '2026-10-22 14:00:10.755-03'),

(2, 'F', 'Rosana Myazi', '07355905830', '11 981419541', 'rosanamyazi1966@gmail.com',
 '{"uf":"SP","cep":"02377000","bairro":"HORTO FLORESTAL","cidade":"São Paulo","numero":"802","endereco":"RUA DO HORTO","complemento":"CASA 20"}'::jsonb,
 true, '2026-10-23 13:24:05.779-03', '2026-10-30 11:39:04.569-03');


-- Usuários -----------------------------------
INSERT INTO tb_usuario (cd_pessoa, cd_nivel, login, senha_hash, fl_ativo) values
(0, 0, 'hilaneto', 'scrypt:32768:8:1$4mjPXrerf5DlpXpO$f8a99dcefa0f79ae3731df309f3e64eb24c34d2d252e79bf8ff4c22321e79b26d1238145047ef14d8fd23c381e249b17d2886e9e1256a9cf6bf57576480dcc8f', true),
(1, 1, 'juvenal' , 'scrypt:32768:8:1$zebpNPKMDH6Ck8IR$97ec87e2c1f9f8a67192ef784f86dab8223eb8e5570764ae86cd2cafd557ae1278eb0a9ab8fbc4c0a16c1df6703ae50815d765989e0ca465ff7a35bc5d820ec0', true),
(2, 2, 'rosana'  , 'scrypt:32768:8:1$zebpNPKMDH6Ck8IR$97ec87e2c1f9f8a67192ef784f86dab8223eb8e5570764ae86cd2cafd557ae1278eb0a9ab8fbc4c0a16c1df6703ae50815d765989e0ca465ff7a35bc5d820ec0', true);



-- tb_cliente_link -----------------------------------
select * from tb_cliente_link;

https://juvaecom.jhan.com.br/cadastro/c1aa7182f2ceea105bc1f1e8162e01d7973f74ac7bd7e4bab14b63684d20f864
https://juvaecom.jhan.com.br/cadastro/4gGl8XpUbnxj3HO186EFH-6U4R3-KFGG_fd90gYWZ2s


-- Pessoa-Cliente -----------------------------------
-- Senha inicial cliente: jps123
-- Casa Um Eventos - casa1234
select * from tb_usuario;




