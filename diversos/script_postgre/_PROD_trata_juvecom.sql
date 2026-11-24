

SELECT table_name FROM information_schema.tables
WHERE table_schema = 'public';


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

SELECT column_name
FROM information_schema.columns
WHERE table_schema = 'public'
  AND table_name = 'tb_parcelas'
ORDER BY ordinal_position;

-- Views ---------------------------------------
select * from vw_cobranca_proximos;
select * from vw_usuario;
select * from vw_dash_adm;
select * from vw_dash_fin;
select * from vw_cliente_contrato;
select * from vw_cobranca_vencidos;
select * from vw_cobranca_inadimplentes;
select * from vw_contatos_pendentes;





SELECT * FROM public.vw_dash_fin;


SELECT column_name, data_type, column_default
FROM information_schema.columns
WHERE table_schema = 'public'
  AND table_name = 'tb_encargo_atraso'
  AND column_name = 'juros_diario';

-- CONTRATOS -----------------------------------
select * from tb_contrato;

select sum(vl_contrato), count(*) from tb_contrato

select cd_status, sum(vl_contrato), count(*) from tb_contrato
group by cd_status

select a.cd_status, a.nm_status, count(b.cd_status) as qtd
from tb_cliente_status a left join tb_cliente b
on a.cd_status = b.cd_status
group by a.cd_status, a.nm_status
order by a.cd_status;

select * from tb_cliente;

select * from tb_contrato;

select * from tb_parcelas;

select a.cd_status, a.nm_status, coalesce(sum(vl_contrato),0) as Valor, count(b.cd_status) as qtd
from tb_contrato_status a left join tb_contrato b
on a.cd_status = b.cd_status
group by a.cd_status, a.nm_status
order by a.cd_status;


GRANT USAGE ON SCHEMA public TO app_juvecom;
GRANT SELECT, INSERT ON TABLE public.tb_contato TO app_juvecom;

select * from tb_contato;

select cd_status, 
case when cd_status = 1 then 'Pendente' 
     when cd_status = 2 then 'Atendido'
     when cd_status = 3 then 'Perdido' end as nm_status,  count(cd_status) as qtd
from tb_contato
group by cd_status
order by cd_status;

select * from vw_cliente_contrato;

select * from vw_dash_fin;

select * from vw_dash_adm;

-- Junção views

select 'Cliente' as origem, a.cd_status, a.nm_status, 0::numeric AS valor, count(b.cd_status) as qtd
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
     when cd_status = 3 then 'Perdido' end as nm_status, 0::numeric AS valor,  count(cd_status) as qtd
from tb_contato
group by cd_status;



GRANT USAGE ON SCHEMA public TO app_juvecom;

GRANT SELECT, INSERT, UPDATE
ON TABLE public.tb_contato
TO app_juvecom;


select cd_status, count(*) from tb_contrato
group by cd_status

select cd_status, sum(vl_contrato), count(*) from tb_contrato
group by cd_status

select TO_CHAR(dt_vencimento, 'MM-YYYY'), sum(vl_parcela), count(*)
from tb_parcelas
group by TO_CHAR(dt_vencimento, 'MM-YYYY')

select * from vw_cobranca_inadimplentes;

select * from vw_cobranca_vencidos;

GRANT SELECT ON ALL TABLES IN SCHEMA public TO app_juvecom;

SELECT * FROM pg_catalog.pg_user;

SELECT rolname, rolcanlogin, rolsuper, rolcreatedb
FROM pg_catalog.pg_roles
ORDER BY rolname;

SELECT rolname, rolcanlogin, rolsuper
FROM pg_roles
WHERE rolname ILIKE '%juve%';


GRANT USAGE ON SCHEMA public TO app_juvecom;
GRANT SELECT ON public.vw_dash_adm, public.vw_dash_fin TO app_juvecom;



SELECT a.parcelas_proximas, a.valor_proximos, b.parcelas_vencidas, b.valor_vencidos, c.parcelas_inadimplentes, c.valor_inadimplencia
FROM (SELECT COUNT(*) AS parcelas_proximas, COALESCE(SUM(vl_a_pagar), 0) AS valor_proximos FROM public.vw_cobranca_proximos) a
CROSS JOIN (SELECT COUNT(*) AS parcelas_vencidas, COALESCE(SUM(vl_original), 0) AS valor_vencidos FROM public.vw_cobranca_vencidos) b
CROSS JOIN (SELECT COUNT(*) AS parcelas_inadimplentes, COALESCE(SUM(vl_original), 0) AS valor_inadimplencia FROM public.vw_cobranca_inadimplentes) c;

SELECT a.parcelas_proximas, a.valor_proximos, b.parcelas_vencidas, b.valor_vencidos, c.parcelas_inadimplentes, c.valor_inadimplencia
FROM (SELECT COUNT(*) AS parcelas_proximas, COALESCE(SUM(vl_a_pagar), 0) AS valor_proximos FROM public.vw_cobranca_proximos) a
CROSS JOIN (SELECT COUNT(*) AS parcelas_vencidas, COALESCE(SUM(vl_original), 0) AS valor_vencidos FROM public.vw_cobranca_vencidos) b
CROSS JOIN (SELECT COUNT(*) AS parcelas_inadimplentes, COALESCE(SUM(vl_total_atualizado), 0) AS valor_inadimplencia FROM public.vw_cobranca_inadimplentes) c;


CREATE OR replace VIEW vw_cobranca_inadimplentes AS
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
WHERE p.dt_pagamento IS NULL
AND CURRENT_DATE - p.dt_vencimento > 3
AND st.cd_status in(2,3);

SELECT cd_link, cd_cliente, dt_criacao, dt_utilizacao
FROM public.tb_cliente_link
WHERE cd_cliente = 52;


select * from tb_pessoa
where nm_pessoa  = 'Marcos Sumiyoshi Missawa'

select * from tb_pessoa a inner join tb_cliente b
on a.cd_pessoa = b.cd_pessoa
where a.cd_pessoa  = 47

select * from tb_contrato
where cd_cliente  = 52

SELECT cd_cliente, cd_pessoa, cd_status
FROM tb_cliente
WHERE cd_cliente = 52;

SELECT cd_contrato, cd_cliente, cd_status
FROM tb_contrato
WHERE cd_cliente = 52;

SELECT cd_link, cd_cliente, dt_criacao, dt_utilizacao
FROM tb_cliente_link
WHERE cd_cliente = 52;




GRANT SELECT, INSERT, UPDATE, DELETE
ON public.vw_cobranca_inadimplentes TO app_juvecom;

GRANT SELECT
ON public.vw_dash_fin TO app_juvecom;

select * from tb_pessoa
where cd_pessoa in (0, 1, 27)

SELECT a.attname AS coluna, v.oid::regclass AS view_dependente
FROM pg_depend d
JOIN pg_rewrite r ON r.oid = d.objid
JOIN pg_class v ON v.oid = r.ev_class
JOIN pg_attribute a ON a.attrelid = d.refobjid
                   AND a.attnum = d.refobjsubid
WHERE d.refobjid = 'public.tb_encargo_atraso'::regclass
  AND a.attname IN ('dias_painel', 'dias_suspensao')
  AND v.relkind = 'v'
ORDER BY a.attname, view_dependente;


INSERT into tb_contato
(cd_status, nm_contato, celular, email, mensagem)
VALUES(1, 'Juvenal Pereira de Souza', '11 98738-5695', 'variedadesjps@gmail.com', 'TESTE');

select * from tb_cliente_link;


-- --------------------------------------------------
--TRUNCATE TABLE tb_usuario RESTART IDENTITY CASCADE;

select * from vw_usuario;

select * from tb_usuario;

select * from tb_logusuario;
select * from tb_contrato_documento;

-- -----------------------------------
select * from vw_cobranca_proximos;
select * from vw_cobranca_vencidos;
select * from vw_cobranca_inadimplentes;
SELECT * FROM vw_contatos_pendentes ORDER BY dt_contato;


-- tb_pessoa ----------------------------------------------

select * from tb_pessoa;

select * from tb_cliente;

select * from tb_loja;

select * from tb_cliente a inner join tb_loja b
on a.cd_cliente = b.cd_cliente

SELECT * FROM public.vw_cobranca_vencidos;
SELECT * FROM public.fn_listar_contratos();  -- Todos
select * from vw_cliente_contrato;


select * from tb_pessoa a inner join tb_cliente b
on a.cd_pessoa = b.cd_pessoa

select 34*600

select * from tb_parcelas;

SELECT c.cd_cliente, p.nm_pessoa, COUNT(l.cd_loja) AS lojas_ativas
FROM public.tb_cliente c
JOIN public.tb_pessoa p ON p.cd_pessoa = c.cd_pessoa
LEFT JOIN public.tb_loja l ON l.cd_cliente = c.cd_cliente AND l.fl_ativo
WHERE c.cd_status IN (2, 3)
  AND p.fl_ativo
  AND NOT EXISTS (SELECT 1 FROM public.tb_contrato ct WHERE ct.cd_cliente = c.cd_cliente)
GROUP BY c.cd_cliente, p.nm_pessoa
ORDER BY p.nm_pessoa, c.cd_cliente;

select * from tb_contrato;

select 100*37

select sum(vl_bruto) from tb_contrato;



where cpf_cnpj = '48463520057'

select * from tb_pessoa
where cpf_cnpj = '48463520057'


select * delete from tb_pessoa
where cd_pessoa = 21

select * from tb_cliente
where cd_pessoa = 21

select * from tb_loja
where cd_cliente = 8


-- tb_usuario ------------------------------------------------

select * from tb_pessoa;

select * from tb_usuario;

select * from tb_pessoa a inner join tb_usuario b
on a.cd_pessoa = b.cd_pessoa



-- Área de Clientes -------------------------------------------
SELECT column_name, data_type, character_maximum_length
FROM information_schema.columns
WHERE table_schema = 'public'
  AND table_name = 'tb_cliente_link'
ORDER BY ordinal_position;

select * from vw_dashboard_admin;

select * from tb_cliente;

select * from tb_plano;

select * from tb_contrato;

DROP INDEX IF EXISTS uq_plano_nome_ativo;

CREATE UNIQUE INDEX uq_plano_tipo_ativo
ON public.tb_plano (cd_plano_tipo)
WHERE fl_ativo;


SELECT s.cd_status, s.nm_status, COUNT(c.cd_contrato) AS contratos
FROM public.tb_contrato_status s
LEFT JOIN public.tb_contrato c ON c.cd_status = s.cd_status
GROUP BY s.cd_status, s.nm_status
ORDER BY s.cd_status;

1	pendente	0
2	assinatura	3
3	ativo	43
4	inadimplente	0
5	vencido	0
6	cancelado	0


select * from tb_usuario;

select * from tb_cliente;

select * from tb_usuario_nivel;

select * from tb_cliente_link;

-- tb_contrato_documento --------
SELECT cd_modelo, octet_length(arquivo_pdf) AS tamanho_bytes, dt_atualizacao
FROM tb_contrato_modelo;

select * from tb_contrato;

select * from tb_pessoa a left join tb_cliente b
on a.cd_pessoa = b.cd_pessoa
where cd_status = 1 


SELECT column_name, data_type, is_nullable
FROM information_schema.columns
WHERE table_schema = 'public'
  AND table_name = 'tb_usuario'
ORDER BY ordinal_position;

-- Simulação --------------------------------------------
SELECT c.cd_contrato, pe.nm_pessoa, c.nm_plano,
       count(DISTINCT cl.cd_loja) AS lojas,
       count(DISTINCT pa.cd_parcela) AS parcelas,
       c.vl_contrato,
       sum(DISTINCT pa.vl_parcela - pa.vl_desconto) AS conferir_apenas_se_valores_distintos
FROM tb_contrato c
JOIN tb_pessoa pe ON pe.cd_pessoa = c.cd_pessoa
LEFT JOIN tb_contrato_loja cl ON cl.cd_contrato = c.cd_contrato
LEFT JOIN tb_parcelas pa ON pa.cd_contrato = c.cd_contrato
WHERE c.ds_contrato = 'Contrato de simulação'
GROUP BY c.cd_contrato, pe.nm_pessoa, c.nm_plano
ORDER BY c.cd_contrato;


-- financeiro sem duplicação pelas lojas ------------------------------

-- Parcelas --------------------------------------------------------------


select * from tb_parcelas;

cd_parcela
select a.nm_pessoa, a.cpf_cnpj, a.telefone, a.email, 
b.nm_responsavel, 
c.nm_plano, c.vigencia, c.vl_bruto, c.vl_contrato, 
d.cd_parcela, d.cd_contrato, d.nr_parcela, d.dt_vencimento, d.vl_parcela, d.dt_pagamento, d.vl_pago
from tb_pessoa a inner join tb_cliente b
on a.cd_pessoa = b.cd_pessoa
inner join tb_contrato c
on b.cd_cliente = c.cd_cliente
inner join  tb_parcelas d
on c.cd_contrato = d.cd_contrato


SELECT c.cd_contrato, c.vl_contrato, sum(p.vl_parcela - p.vl_desconto) AS total_parcelas
FROM tb_contrato c
JOIN tb_parcelas p ON p.cd_contrato = c.cd_contrato
WHERE c.ds_contrato = 'Contrato de simulação'
GROUP BY c.cd_contrato, c.vl_contrato
ORDER BY c.cd_contrato;






select * from tb_contrato
where cd_contrato =  2

select * from tb_pessoa
where cd_pessoa = 1

select * from tb_loja
where cd_pessoa = 1

select sum(vl_contrato) from tb_contrato;

 -- atualizar tb_plano ------------------------------------
SELECT fn_nova_versao_plano(
    p_cd_plano => 9,
    p_valor => 1800,
    p_nm_plano => 'desk'
) AS cd_plano_novo;

-- --------------------
select * from tb_plano;

select * from tb_loja
where cd_pessoa = 4

SELECT cd_pessoa, nm_pessoa, cpf_cnpj, telefone, email, dados->>'representante_legal' AS representante_legal
FROM tb_pessoa
WHERE cd_pessoa = 0 AND tp_pessoa = 'J'


-- Soma das Parcelas bate com total do Contrato -----------------------
SELECT c.cd_contrato, c.vl_contrato,
COALESCE(SUM(p.vl_parcela - p.vl_desconto), 0) AS total_parcelas
FROM tb_contrato c LEFT JOIN tb_parcelas p
ON p.cd_contrato = c.cd_contrato
GROUP BY c.cd_contrato, c.vl_contrato
HAVING c.vl_contrato <> COALESCE(SUM(p.vl_parcela - p.vl_desconto), 0)
ORDER BY c.cd_contrato


SELECT * FROM tb_contrato a 
JOIN tb_desconto_loja b
ON b.qt_loja @> a.qt_loja
AND b.vigencia @> a.dt_cadastro::date;

SELECT c.cd_contrato, c.qt_lojas, c.dt_cadastro::date AS dt_contrato, d.percentual
FROM tb_contrato c
JOIN LATERAL (
    SELECT percentual
    FROM tb_desconto_loja
    WHERE qtd_minima_lojas <= c.qt_lojas
      AND vigencia @> c.dt_cadastro::date
    ORDER BY qtd_minima_lojas DESC
    LIMIT 1) d ON true;


select sum(vl_contrato) from tb_contrato;

SELECT l.cd_loja, l.nm_loja
FROM tb_loja l
LEFT JOIN tb_contrato_loja cl ON cl.cd_loja = l.cd_loja
WHERE cl.cd_loja IS NULL;


-- Primeira versão
SELECT a.cd_pessoa, a.nm_cliente,
       c.cd_contrato, c.vigencia,
       b.cd_loja, b.nm_loja, e.nm_plano, d.vl_plano, g.nm_servico
FROM tb_pessoa a
LEFT JOIN tb_contrato c ON c.cd_pessoa = a.cd_pessoa
LEFT JOIN tb_contrato_loja h ON h.cd_contrato = c.cd_contrato AND h.cd_pessoa = a.cd_pessoa
LEFT JOIN tb_loja b ON b.cd_loja = h.cd_loja AND b.cd_pessoa = h.cd_pessoa
LEFT JOIN tb_plano_contrato d ON d.cd_contrato = c.cd_contrato
LEFT JOIN tb_plano e ON e.cd_plano = d.cd_plano
LEFT JOIN tb_plano_servico f ON f.cd_plano = e.cd_plano
LEFT JOIN tb_servico g ON g.cd_servico = f.cd_servico
ORDER BY a.cd_pessoa, c.cd_contrato, b.cd_loja, g.cd_servico;


-- segunda versão
SELECT c.cd_contrato, a.cd_pessoa, a.nm_cliente,
       c.vigencia, c.vl_contrato, st.nm_status AS status,
       string_agg(DISTINCT b.nm_loja, ', ' ORDER BY b.nm_loja) AS lojas,
       string_agg(DISTINCT e.nm_plano, ', ' ORDER BY e.nm_plano) AS planos
FROM tb_contrato c
JOIN tb_pessoa a ON a.cd_pessoa = c.cd_pessoa
JOIN tb_contrato_status st ON st.cd_status = c.cd_status
LEFT JOIN tb_contrato_loja h ON h.cd_contrato = c.cd_contrato
LEFT JOIN tb_loja b ON b.cd_loja = h.cd_loja
LEFT JOIN tb_plano_contrato d ON d.cd_contrato = c.cd_contrato
LEFT JOIN tb_plano e ON e.cd_plano = d.cd_plano
GROUP BY c.cd_contrato, a.cd_pessoa, st.cd_status
ORDER BY c.cd_contrato;


-- =========================================================================
-- View vw_cliente_contrato
-- =========================================================================
CREATE OR REPLACE VIEW public.vw_cliente_contrato AS
SELECT c.cd_cliente, p.cd_pessoa, p.nm_pessoa,
c.nm_responsavel, c.cd_status AS cd_status_cliente, sc.nm_status AS nm_status_cliente,
ct.cd_contrato, ct.cd_status AS cd_status_contrato, st.nm_status AS nm_status_contrato,
ct.cd_plano, ct.nm_plano AS nm_plano_contrato, ct.vigencia, ct.vl_contrato
FROM public.tb_cliente c
JOIN public.tb_pessoa p ON p.cd_pessoa = c.cd_pessoa
LEFT JOIN public.tb_cliente_status sc ON sc.cd_status = c.cd_status
LEFT JOIN public.tb_contrato ct ON ct.cd_cliente = c.cd_cliente
LEFT JOIN public.tb_contrato_status st ON st.cd_status = ct.cd_status;


-- =========================================================================
-- Function fn_listar_clientes
-- =========================================================================
BEGIN;
CREATE OR REPLACE FUNCTION public.fn_listar_clientes(p_cd_status integer DEFAULT NULL)
RETURNS TABLE (cd_cliente bigint, nm_pessoa text)
LANGUAGE sql
STABLE
AS $$
    SELECT c.cd_cliente, p.nm_pessoa::text
    FROM public.tb_cliente c
    JOIN public.tb_pessoa p ON p.cd_pessoa = c.cd_pessoa
    WHERE p.fl_ativo IS TRUE
      AND (p_cd_status IS NULL OR c.cd_status = p_cd_status)
    ORDER BY p.nm_pessoa, c.cd_cliente;
$$;

CREATE OR REPLACE FUNCTION public.fn_listar_contratos(p_cd_status integer DEFAULT NULL)
RETURNS TABLE (cd_contrato bigint, nm_pessoa text, nm_status text)
LANGUAGE sql
STABLE
AS $$
    SELECT ct.cd_contrato, p.nm_pessoa::text, s.nm_status::text
    FROM public.tb_contrato ct
    JOIN public.tb_cliente c ON c.cd_cliente = ct.cd_cliente
    JOIN public.tb_pessoa p ON p.cd_pessoa = c.cd_pessoa
    JOIN public.tb_contrato_status s ON s.cd_status = ct.cd_status
    WHERE p_cd_status IS NULL OR ct.cd_status = p_cd_status
    ORDER BY ct.cd_contrato DESC;
$$;
COMMIT;

-- ==============================================================================
SELECT * FROM public.fn_listar_contratos();  -- Todos
SELECT * FROM public.fn_listar_contratos(1); -- Sem assinatura
SELECT * FROM public.fn_listar_contratos(2); -- Vigente
SELECT * FROM public.fn_listar_contratos(3); -- Inadimplente
SELECT * FROM public.fn_listar_contratos(4); -- Liquidado
SELECT * FROM public.fn_listar_contratos(5); -- Cancelado


-- =========================================================================
-- Function fn_listar_contratos
-- =========================================================================
CREATE OR REPLACE FUNCTION public.fn_listar_contratos(p_cd_status integer DEFAULT NULL)
RETURNS TABLE (cd_contrato bigint, nm_pessoa text, nm_status text)
LANGUAGE sql
STABLE
AS $$
    SELECT ct.cd_contrato, p.nm_pessoa::text, s.nm_status::text
    FROM public.tb_contrato ct
    JOIN public.tb_cliente c ON c.cd_cliente = ct.cd_cliente
    JOIN public.tb_pessoa p ON p.cd_pessoa = c.cd_pessoa
    JOIN public.tb_contrato_status s ON s.cd_status = ct.cd_status
    WHERE p_cd_status IS NULL OR ct.cd_status = p_cd_status
    ORDER BY ct.cd_contrato DESC;
$$;

-- ==============================================================================
SELECT * FROM public.fn_listar_contratos();  -- Todos
SELECT * FROM public.fn_listar_contratos(1); -- Sem assinatura
SELECT * FROM public.fn_listar_contratos(2); -- Vigente
SELECT * FROM public.fn_listar_contratos(3); -- Inadimplente
SELECT * FROM public.fn_listar_contratos(4); -- Liquidado
SELECT * FROM public.fn_listar_contratos(5); -- Cancelado




SELECT a.cd_pessoa, a.nm_cliente,
       c.cd_contrato, c.vigencia,
       b.cd_loja, b.nm_loja,
       e.nm_plano, d.vl_plano,
       s.servicos
FROM tb_pessoa a
LEFT JOIN tb_contrato c ON c.cd_pessoa = a.cd_pessoa
LEFT JOIN tb_contrato_loja h ON h.cd_contrato = c.cd_contrato
                            AND h.cd_pessoa = a.cd_pessoa
LEFT JOIN tb_loja b ON b.cd_loja = h.cd_loja
                   AND b.cd_pessoa = h.cd_pessoa
LEFT JOIN tb_plano_contrato d ON d.cd_contrato = c.cd_contrato
LEFT JOIN tb_plano e ON e.cd_plano = d.cd_plano
LEFT JOIN LATERAL (
    SELECT string_agg(g.nm_servico, ', ' ORDER BY g.cd_servico) AS servicos
    FROM tb_plano_servico f
    JOIN tb_servico g ON g.cd_servico = f.cd_servico
    WHERE f.cd_plano = e.cd_plano
) s ON true
ORDER BY a.cd_pessoa, c.cd_contrato, b.cd_loja;


INSERT INTO tb_servico (nm_servico, ds_servico, vl_servico) values
('Diagnóstico inicial', 'Análise inicial da loja e definição de prioridades e recomendações de atuação.',0),
('Gestão e otimização da loja', 'Configuração, organização e melhoria contínua da presença da loja na Shopee.',0),
('Gestão de anúncios e produtos', 'Otimização recorrente de títulos, descrições, atributos, categorias, preços e variações dos produtos.',0),
('Tratamento de imagens de anúncios', 'Criação, tratamento ou melhoria de imagens com base nos materiais fornecidos pelo cliente, conforme o plano contratado.',0),
('Promoções e campanhas', 'Planejamento de cupons, kits, benefícios de frete, campanhas sazonais e outras ações promocionais aplicáveis.',0),
('Gestão de Shopee Ads', 'Avaliação, configuração e otimização de anúncios patrocinados, mediante aprovação e saldo de mídia do cliente.',0),
('Métricas e recomendações', 'Acompanhamento de indicadores de desempenho e elaboração de recomendações de melhoria.',0),
('Suporte e alinhamento operacional', 'Orientações e alinhamentos sobre a operação da loja pelos canais oficiais de atendimento.',0);

INSERT INTO tb_plano (nm_plano, ds_plano, periodicidade_dias, valor, texto_banner)
VALUES ('Diamante' , 'Gestão completa da loja Shopee', 360, 1300, 'Mais tempo para desenvolver sua loja com uma gestão contínua.'),
       ('Safira'   , 'Gestão completa da loja Shopee', 180,  1100, 'Uma gestão completa para evoluir com consistência.'),
       ('Esmeralda', 'Gestão completa da loja Shopee',  90,  900, 'Comece a organizar e fortalecer sua presença na Shopee.'),
       ('Avulso'   , 'Diagnóstico inicial'           ,   7,  300, 'Descubra as prioridades da sua loja antes dos próximos passos.');

INSERT INTO tb_plano_servico (cd_plano, cd_servico) values (1, 1);
INSERT INTO tb_plano_servico (cd_plano, cd_servico) values (1, 2);
INSERT INTO tb_plano_servico (cd_plano, cd_servico) values (1, 3);
INSERT INTO tb_plano_servico (cd_plano, cd_servico) values (1, 4);
INSERT INTO tb_plano_servico (cd_plano, cd_servico) values (1, 5);
INSERT INTO tb_plano_servico (cd_plano, cd_servico) values (1, 6);
INSERT INTO tb_plano_servico (cd_plano, cd_servico) values (1, 7);
INSERT INTO tb_plano_servico (cd_plano, cd_servico) values (1, 8);
-- ---------------------------------------------------------------
INSERT INTO tb_plano_servico (cd_plano, cd_servico) values (2, 1);
INSERT INTO tb_plano_servico (cd_plano, cd_servico) values (2, 2);
INSERT INTO tb_plano_servico (cd_plano, cd_servico) values (2, 3);
INSERT INTO tb_plano_servico (cd_plano, cd_servico) values (2, 4);
INSERT INTO tb_plano_servico (cd_plano, cd_servico) values (2, 5);
INSERT INTO tb_plano_servico (cd_plano, cd_servico) values (2, 6);
INSERT INTO tb_plano_servico (cd_plano, cd_servico) values (2, 7);
INSERT INTO tb_plano_servico (cd_plano, cd_servico) values (2, 8);
-- ---------------------------------------------------------------
INSERT INTO tb_plano_servico (cd_plano, cd_servico) values (3, 1);
INSERT INTO tb_plano_servico (cd_plano, cd_servico) values (3, 2);
INSERT INTO tb_plano_servico (cd_plano, cd_servico) values (3, 3);
INSERT INTO tb_plano_servico (cd_plano, cd_servico) values (3, 4);
INSERT INTO tb_plano_servico (cd_plano, cd_servico) values (3, 5);
INSERT INTO tb_plano_servico (cd_plano, cd_servico) values (3, 6);
INSERT INTO tb_plano_servico (cd_plano, cd_servico) values (3, 7);
INSERT INTO tb_plano_servico (cd_plano, cd_servico) values (3, 8);
-- ---------------------------------------------------------------
INSERT INTO tb_plano_servico (cd_plano, cd_servico) values (4, 1);

-- ---------------------------------------------------------------


