

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
select * from vw_cobranca_vencidos;
select * from vw_cobranca_inadimplentes;


-- ==========================================================================
-- vw_dash_adm: drop view vw_dash_adm cascade
-- ==========================================================================
CREATE OR REPLACE VIEW public.vw_dash_adm AS
select 'Cliente' as origem, a.cd_status, a.nm_status, 0 as valor, count(b.cd_status) as qtd
from tb_cliente_status a left join tb_cliente b
on a.cd_status = b.cd_status
group by a.cd_status, a.nm_status
union all -------------------------------------
select 'Contrato' as origem, a.cd_status, a.nm_status, coalesce(sum(vl_contrato),0) as Valor, count(b.cd_status) as qtd
from tb_contrato_status a left join tb_contrato b
on a.cd_status = b.cd_status
group by a.cd_status, a.nm_status
union all -------------------------------------
select 'Contato' as origem, cd_status, 
case when cd_status = 1 then 'Pendente' 
     when cd_status = 2 then 'Atendido'
     when cd_status = 3 then 'Perdido' end as nm_status,  0 as valor,  count(cd_status) as qtd
from tb_contato
group by cd_status;
-- -----------------------
select * from vw_dash_adm;


-- ==========================================================================
-- vw_dashboard_fin: drop view vw_dash_fin cascade - Usuarios
-- ==========================================================================
CREATE OR REPLACE VIEW public.vw_dash_fin AS
select vl_parcelas_a_vencer, qt_parcelas_a_vencer, vl_parcelas_vencidas, qt_parcelas_vencidas, vl_contrato, qt_contratos_vencidos from
(select sum(vl_parcela) as vl_parcelas_vencidas, count(distinct a.cd_parcela) as qt_parcelas_vencidas from tb_parcelas a inner join tb_contrato b
 on a.cd_contrato = b.cd_contrato
 where CURRENT_DATE - dt_vencimento > 1
 AND b.cd_status in(2,3))
cross join
(select sum(vl_contrato) as vl_contrato, sum(qt_contratos_vencidos) as qt_contratos_vencidos from
(select max(b.vl_contrato) as vl_contrato, count(distinct a.cd_contrato) as qt_contratos_vencidos from tb_parcelas a inner join tb_contrato b
 on a.cd_contrato = b.cd_contrato
 where CURRENT_DATE - dt_vencimento > 1
 AND b.cd_status in(2,3)
 group by b.cd_contrato))
cross join
(select COALESCE(SUM(vl_parcela),  0) as vl_parcelas_a_vencer,  count(*) as qt_parcelas_a_vencer
from tb_parcelas a inner join tb_contrato b
on a.cd_contrato = b.cd_contrato
WHERE dt_pagamento IS NULL
AND a.dt_vencimento BETWEEN CURRENT_DATE + 1 AND CURRENT_DATE + 30
AND cd_status IN (2, 3));
-- ----------------------- 
select * from vw_dash_fin;


select sum(a.vl_contrato) as vl_contrato, sum(qt_contratos_vencidos) as qt_contratos_vencidos from
(select sum(a.vl_parcela) as vl_contrato, count(distinct a.cd_contrato) as qt_contratos_vencidos from tb_parcelas a inner join tb_contrato b
 on a.cd_contrato = b.cd_contrato
 where CURRENT_DATE - dt_vencimento > 1
 AND b.cd_status in(2,3)) a
 

select sum(a.vl_contrato) as vl_contrato, sum(qt_contratos_vencidos) as qt_contratos_vencidos from
(select max(b.vl_contrato) as vl_contrato, count(distinct a.cd_contrato) as qt_contratos_vencidos from tb_parcelas a inner join tb_contrato b
 on a.cd_contrato = b.cd_contrato
 where CURRENT_DATE - dt_vencimento > 1
 AND b.cd_status in(2,3)
 group by b.cd_contrato) a



-- ==========================================================================
-- vw_cobranca_proximos: drop view vw_cobranca_proximos - Usuarios
-- ==========================================================================
CREATE OR REPLACE VIEW public.vw_cobranca_proximos AS
SELECT p.cd_parcela, p.cd_contrato, p.nr_parcela, pe.nm_pessoa, pe.telefone, pe.email, c.nm_plano,
p.dt_vencimento, p.dt_vencimento - CURRENT_DATE AS dias_para_vencer, p.vl_parcela AS vl_a_pagar
FROM tb_parcelas p
JOIN tb_contrato c ON c.cd_contrato = p.cd_contrato
JOIN tb_contrato_status st ON st.cd_status = c.cd_status
JOIN tb_cliente cl ON cl.cd_cliente = c.cd_cliente
JOIN tb_pessoa pe ON pe.cd_pessoa = cl.cd_pessoa
WHERE p.dt_pagamento IS NULL
AND p.dt_vencimento BETWEEN CURRENT_DATE + 1 AND CURRENT_DATE + 30
AND st.cd_status IN (2,3);
-- --------------------------------
select * from vw_cobranca_proximos;


-- ==========================================================================
-- vw_cobranca_vencidos: drop view vw_cobranca_vencidos
-- ==========================================================================
CREATE OR replace VIEW public.vw_cobranca_vencidos AS
SELECT p.cd_parcela, p.cd_contrato, p.nr_parcela,
       pe.nm_pessoa, pe.telefone, pe.email, c.nm_plano,
       p.dt_vencimento, CURRENT_DATE - p.dt_vencimento AS dias_atraso,
       p.vl_parcela AS vl_original
FROM tb_parcelas p
JOIN tb_contrato c ON c.cd_contrato = p.cd_contrato
JOIN tb_contrato_status st ON st.cd_status = c.cd_status
JOIN tb_cliente cl ON cl.cd_cliente = c.cd_cliente
JOIN tb_pessoa pe ON pe.cd_pessoa = cl.cd_pessoa
WHERE p.dt_pagamento IS NULL
AND p.dt_vencimento < CURRENT_DATE - 1
AND c.cd_status in(2,3);
-- ----------------------------------------------------------------------
select * from vw_cobranca_vencidos;



-- ==============================================================================
-- vw_cobranca_inadimplentes: drop view vw_cobranca_inadimplentes
-- A view preserva vl_juros (soma dos dois tipos), alem de discriminar cada um.
-- Politicas inexistentes para uma data de vencimento nao geram linha nesta view.
-- ==============================================================================
CREATE OR REPLACE VIEW vw_cobranca_inadimplentes AS
SELECT p.cd_parcela, p.cd_contrato, p.nr_parcela, pe.nm_pessoa, pe.telefone, pe.email, c.nm_plano,
st.nm_status AS status_contrato, p.dt_vencimento,
CURRENT_DATE - p.dt_vencimento AS dias_atraso, p.vl_parcela AS vl_original,
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
SELECT
CASE WHEN CURRENT_DATE - p.dt_vencimento > e.dias_carencia
THEN ROUND(p.vl_parcela * e.percentual_multa / 100, 2) ELSE 0::numeric END AS vl_multa,
ROUND(p.vl_parcela * e.juros_mensal / 100 * GREATEST(CURRENT_DATE - p.dt_vencimento - e.dias_carencia, 0) / 30, 2) AS vl_juros_mensal,
ROUND(p.vl_parcela * e.juros_diario / 100 * GREATEST(CURRENT_DATE - p.dt_vencimento - e.dias_carencia, 0), 2) AS vl_juros_diario
) enc
WHERE p.dt_pagamento IS NULL AND CURRENT_DATE - p.dt_vencimento > 1 AND st.cd_status in(2,3);

-- ----------------------------------------------------------------------
select * from vw_cobranca_inadimplentes;




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

select * from tb_pessoa a inner join tb_cliente b
on a.cd_pessoa = b.cd_pessoa
left join tb_usuario c
on b.cd_pessoa = c.cd_pessoa;

select * from tb_contrato;

select * from tb_pessoa a inner join tb_cliente b
on a.cd_pessoa = b.cd_pessoa
left join tb_usuario c
on b.cd_pessoa = c.cd_pessoa
left join tb_contrato d
on b.cd_cliente = d.cd_cliente
left join tb_parcelas e
on d.cd_contrato = e.cd_contrato
where a.cd_pessoa = 10;


SELECT p.cd_parcela, p.cd_contrato, p.nr_parcela,
       pe.nm_pessoa, c.cd_cliente, p.dt_vencimento,
       p.vl_parcela, p.pc_desconto, p.dt_pagamento,
       p.vl_pago,
       CASE
           WHEN p.dt_vencimento < CURRENT_DATE THEN 'Vencida'
           WHEN p.dt_vencimento = CURRENT_DATE THEN 'Hoje'
           ELSE 'Futura'
       END AS situacao,
       GREATEST(0, CURRENT_DATE - p.dt_vencimento) AS dias_atraso
FROM tb_parcelas p
JOIN tb_contrato ct ON ct.cd_contrato = p.cd_contrato
JOIN tb_cliente c ON c.cd_cliente = ct.cd_cliente
JOIN tb_pessoa pe ON pe.cd_pessoa = c.cd_pessoa
WHERE p.dt_pagamento IS NULL
ORDER BY p.dt_vencimento, pe.nm_pessoa;

select * from vw_dash_fin;
select * from vw_cobranca_proximos;
select * from vw_cobranca_vencidos;
select * from vw_cobranca_inadimplentes;


CREATE OR REPLACE VIEW public.vw_cobranca_vencidos AS
SELECT p.cd_parcela, p.cd_contrato, p.nr_parcela,
       pe.nm_pessoa, pe.telefone, pe.email, c.nm_plano,
       p.dt_vencimento, CURRENT_DATE - p.dt_vencimento AS dias_atraso,
       p.vl_parcela AS vl_original
FROM tb_parcelas p
JOIN tb_contrato c ON c.cd_contrato = p.cd_contrato
JOIN tb_contrato_status st ON st.cd_status = c.cd_status
JOIN tb_cliente cl ON cl.cd_cliente = c.cd_cliente
JOIN tb_pessoa pe ON pe.cd_pessoa = cl.cd_pessoa
WHERE p.dt_pagamento IS NULL
  AND p.dt_vencimento < CURRENT_DATE
  AND c.cd_status in(2,3);

SELECT 'Próximos' AS origem, COUNT(*) AS qtd, COALESCE(SUM(vl_a_pagar), 0) AS valor FROM vw_cobranca_proximos
UNION ALL
SELECT 'Vencidos', COUNT(*), COALESCE(SUM(vl_original), 0) FROM vw_cobranca_vencidos
UNION ALL
SELECT 'Inadimplentes', COUNT(*), COALESCE(SUM(vl_total_atualizado), 0) FROM vw_cobranca_inadimplentes;

select 1109.95 + 1099.25 + 1096.15 + 1085.17


select * from vw_cobranca_vencidos;


select * from tb_parcelas;

SELECT COUNT(*) AS parcelas_em_atraso
FROM tb_parcelas
WHERE cd_contrato = 9
  AND dt_pagamento IS NULL
  AND dt_vencimento < CURRENT_DATE - 3;


UPDATE tb_contrato
SET cd_status = 3,
    dt_atualizacao = CURRENT_TIMESTAMP
WHERE cd_contrato = 9
  AND cd_status = 2;

select * from vw_cobranca_proximos;

select * from tb_contrato;

select * from tb_parcelas
where cd_contrato = 9

select * from tb_cliente;

select * from tb_usuario;

SELECT conname, pg_get_constraintdef(oid) AS definicao
FROM pg_constraint
WHERE conrelid = 'public.tb_usuario'::regclass
ORDER BY conname;

select * from tb_contrato_status;

SELECT cd_contrato, cd_status, dt_atualizacao
FROM tb_contrato
WHERE cd_contrato = 9;

UPDATE tb_contrato
SET cd_status = 2
WHERE cd_status = 3;

select count(*) from tb_contrato
WHERE cd_status = 3;

SELECT c.cd_contrato, c.cd_status, MIN(p.dt_vencimento) AS vencimento_mais_antigo
FROM tb_contrato c
JOIN tb_parcelas p ON p.cd_contrato = c.cd_contrato
WHERE c.cd_status = 3
  AND p.dt_pagamento IS NULL
  AND p.dt_vencimento < CURRENT_DATE - 3
GROUP BY c.cd_contrato, c.cd_status
ORDER BY c.cd_contrato;


