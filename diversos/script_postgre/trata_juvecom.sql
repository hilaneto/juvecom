

SELECT table_name FROM information_schema.tables
WHERE table_schema = 'public';

-- -----------------------------------------------
select * from tb_plano;
select * from tb_servico;
select * from tb_contrato_status;
select * from tb_encargo_atraso;
select * from tb_desconto_loja;
select * from tb_usuario_nivel;
select * from tb_evento_log;
select * from tb_plano_servico;
-- -----------------------------------------------

select * from tb_contato;
select * from tb_parcelas;

select * from tb_usuario;

select * from vw_cobranca_proximos;
select * from tb_contato_conversa;
select * from vw_cobranca_vencidos;
select * from tb_logusuario;
select * from tb_contrato_loja;

-- -------------------------------------
select * from tb_pessoa;
select * from tb_cliente;
select * from tb_loja;

-- -------------------------------------
select * from tb_contrato;
select * from tb_contrato_documento;
select * from tb_contrato_modelo;
-- -------------------------------------

select * from tb_pessoa;
select * from tb_cliente;
select * from tb_usuario_nivel;

select * from vw_cobranca_inadimplentes;
select * from vw_contatos_pendentes;
select * from vw_usuario;

-- ===================================================================================================================

select * from tb_cliente;
select * from tb_contrato;
select * from tb_cliente_link;
select * from tb_contrato_loja;


-- ================================================================================================================ *
-- Teste * Teste *  Teste *  Teste *  Teste *  Teste *  Teste *  Teste *  Teste *  Teste *  Teste *  Teste *  Teste *
-- ================================================================================================================ * 

select * from tb_cliente_status;
select * from tb_contrato_status;

select * from tb_pessoa a inner join tb_cliente b
on a.cd_pessoa = b.cd_pessoa
left join tb_loja c
on b.cd_cliente = c.cd_cliente
left join tb_contrato d
on b.cd_cliente = d.cd_cliente
where a.cpf_cnpj = '85073629000114';


-- acompanhamaneto: ====================================================================================

select * from tb_pessoa a inner join tb_cliente b
on a.cd_pessoa = b.cd_pessoa
left join tb_loja c
on b.cd_cliente = c.cd_cliente
left join tb_contrato d
on b.cd_cliente = d.cd_cliente
inner join tb_cliente_status e
on b.cd_status = e.cd_status
where b.cd_cliente = 4



select a.cd_pessoa, a.tp_pessoa, a.nm_pessoa, a.cpf_cnpj, a.telefone, a.email,	a.dados, a.fl_ativo, a.dt_cadastro, a.dt_atualizacao,
b.cd_cliente, b.cd_pessoa, b.nm_responsavel, b.cd_status, b.cd_contato, b.dt_cadastro, b.dt_atualizacao,
c.cd_loja, c.cd_cliente, c.nm_loja, c.shop_id, c.url_loja, c.fl_ativo, c.dt_cadastro, c.dt_atualizacao,
d.cd_contrato, d.cd_cliente, d.cd_plano, d.cd_status, d.nm_plano, d.ds_plano, d.vigencia, d.vl_bruto, d.vl_desconto_lojas, d.vl_desconto_manual, d.vl_acrescimo, d.vl_contrato, d.ds_contrato, d.ds_observacao, d.dt_cadastro, d.dt_atualizacao,
g.nm_plano, g.periodicidade_dias, g.valor
from tb_pessoa a inner join tb_cliente b
on a.cd_pessoa = b.cd_pessoa
left join tb_loja c
on b.cd_cliente = c.cd_cliente
left join tb_contrato d
on b.cd_cliente = d.cd_cliente
left join tb_plano g
on d.cd_plano = g.cd_plano
left join tb_cliente_status e
on b.cd_status = e.cd_status
left join tb_contrato_status f
on d.cd_status = f.cd_status
where b.cd_cliente = 4

where b.cd_status = 1 --Cliente Pendente
where b.cd_status = 2 --Cliente Aprovado
where b.cd_status = 3 --Cliente Confirmado
where b.cd_status = 4 --Cliente Reprovado
where b.cd_status = 5 --Cliente Cancelado
where d.cd_status = 1 --Contrato Sem assinatura
where d.cd_status = 2 --Contrato Ativo
where d.cd_status = 3 --Contrato Inadimplente
where d.cd_status = 4 --Contrato Liquidade
where d.cd_status = 5 --Contrato Cancelado


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





-- =========================================================================
-- View_cobranca_vencidos
-- =========================================================================
BEGIN;

SET LOCAL search_path TO public;

CREATE OR REPLACE VIEW public.vw_cobranca_vencidos AS
SELECT p.cd_parcela, p.cd_contrato, p.nr_parcela, pe.nm_pessoa, pe.telefone, pe.email, c.nm_plano,
p.dt_vencimento, CURRENT_DATE - p.dt_vencimento AS dias_atraso, p.vl_parcela - p.vl_desconto AS vl_original
FROM tb_parcelas p JOIN tb_contrato c ON c.cd_contrato = p.cd_contrato
JOIN tb_contrato_status st ON st.cd_status = c.cd_status
JOIN tb_cliente cl ON cl.cd_cliente = c.cd_cliente
JOIN tb_pessoa pe ON pe.cd_pessoa = cl.cd_pessoa
WHERE p.dt_pagamento IS NULL
AND p.dt_vencimento BETWEEN CURRENT_DATE - 3 AND CURRENT_DATE - 1
AND st.cd_status NOT IN (1, 5);

CREATE OR REPLACE VIEW public.vw_cobranca_inadimplentes AS
SELECT p.cd_parcela, p.cd_contrato, p.nr_parcela, pe.nm_pessoa, pe.telefone, pe.email, c.nm_plano, st.nm_status AS status_contrato,
p.dt_vencimento, CURRENT_DATE - p.dt_vencimento AS dias_atraso, p.vl_parcela - p.vl_desconto AS vl_original,
ROUND((p.vl_parcela - p.vl_desconto) * e.percentual_multa / 100, 2) AS vl_multa,
ROUND((p.vl_parcela - p.vl_desconto) * e.juros_mensal / 100 * (CURRENT_DATE - p.dt_vencimento - e.dias_carencia) / 30, 2) AS vl_juros,
CURRENT_DATE - p.dt_vencimento > e.dias_suspensao AS avaliar_suspensao
FROM tb_parcelas p JOIN tb_contrato c ON c.cd_contrato = p.cd_contrato
JOIN tb_contrato_status st ON st.cd_status = c.cd_status
JOIN tb_cliente cl ON cl.cd_cliente = c.cd_cliente
JOIN tb_pessoa pe ON pe.cd_pessoa = cl.cd_pessoa
JOIN tb_encargo_atraso e ON e.vigencia @> p.dt_vencimento
WHERE p.dt_pagamento IS NULL
AND CURRENT_DATE - p.dt_vencimento > e.dias_painel
AND CURRENT_DATE - p.dt_vencimento > e.dias_carencia
AND st.cd_status NOT IN (1, 5);

COMMIT;
-- ==============================================================================
SELECT * FROM public.vw_cobranca_vencidos;








select * from tb_plano;
select * from tb_contrato;
select * from tb_contrato;





SELECT c.cd_cliente, c.cd_status, s.nm_status
FROM public.tb_cliente c
JOIN public.tb_cliente_status s ON s.cd_status = c.cd_status
join public.tb_contrato_status a on a.cd_status = c. 
WHERE c.cd_cliente = 4;




-- ====================================================================================================

select * from tb_contrato;

select * from tb_plano;

select * from tb_cliente_link;

select * from tb_cliente;

select * from tb_contrato;

select * from tb_cliente_status;

select * from tb_contrato_status;

select * from tb_contrato_status where cd_status = 2




SELECT
c.cd_contato,
c.nm_contato,
c.email,
c.celular,
c.mensagem,
c.dt_cadastro,
CURRENT_DATE - c.dt_cadastro::date AS dias_aguardando
FROM public.tb_contato c
WHERE c.cd_status IN (1, 2);

select * from vw_dash_adm;
select * from tb_contato;
select * from vw_dash_adm;
select * from vw_dash_fin;
select * from tb_contato;

SELECT 'Cliente' AS origem, b.cd_status, b.nm_status, COUNT(a.cd_cliente) AS qtd
FROM tb_cliente_status b
LEFT JOIN tb_cliente a ON a.cd_status = b.cd_status
GROUP BY b.cd_status, b.nm_status

UNION ALL
SELECT 'Contrato' AS origem, b.cd_status, b.nm_status, COUNT(a.cd_contrato) AS qtd
FROM tb_contrato_status b
LEFT JOIN tb_contrato a ON a.cd_status = b.cd_status
GROUP BY b.cd_status, b.nm_status
UNION ALL
SELECT 'Contato' AS origem, b.cd_status, b.nm_status, COUNT(a.cd_contato) AS qtd
FROM (VALUES (1, 'Pendente'), (2, 'Atendido'), (3, 'Perdido')) AS b(cd_status, nm_status)
LEFT JOIN tb_contato a ON a.cd_status = b.cd_status
GROUP BY b.cd_status, b.nm_status
ORDER BY origem, cd_status;


SELECT * FROM public.vw_dash_adm

ORDER BY origem, cd_status;

SELECT * FROM public.vw_dash_adm ORDER BY origem, cd_status;

SELECT * FROM public.vw_contatos_pendentes
ORDER BY dt_cadastro DESC;

SELECT 'tb_cliente' AS tabela, COUNT(*) AS registros FROM public.tb_cliente
UNION ALL
SELECT 'tb_loja', COUNT(*) FROM public.tb_loja
UNION ALL
SELECT 'tb_contrato', COUNT(*) FROM public.tb_contrato
UNION ALL
SELECT 'tb_parcelas', COUNT(*) FROM public.tb_parcelas
UNION ALL
SELECT 'tb_contrato_documento', COUNT(*) FROM public.tb_contrato_documento
UNION ALL
SELECT 'tb_contrato_loja', COUNT(*) FROM public.tb_contrato_loja
UNION ALL
SELECT 'tb_cliente_link', COUNT(*) FROM public.tb_cliente_link;


SELECT l.cd_link, l.cd_cliente, l.dt_utilizacao,
       c.cd_cliente AS cliente_cadastrado,
       p.nm_pessoa , p.cpf_cnpj
FROM public.tb_cliente_link l
LEFT JOIN public.tb_cliente c ON c.cd_cliente = l.cd_cliente
LEFT JOIN public.tb_pessoa p ON p.cd_pessoa = c.cd_pessoa
ORDER BY l.cd_link DESC;

-- ================================================================================================================================= *
-- Fim Teste * Fim Teste * Fim Teste * Fim Teste * Fim Teste * Fim Teste * Fim Teste * Fim Teste * Fim Teste * Fim Teste * Fim Teste * 
-- ================================================================================================================================= *

select * from tb_pessoa;

select * from tb_cliente;

select * from tb_contrato;

select * from tb_contato;

select * from tb_cliente_link;
select * from tb_loja;

select * from public.vw_dashboard_admin;

(select count(*) AS clientes_ativos FROM public.tb_cliente)



bf981eccd4d868c603db10ef48888e8e6ab83805c568255b2d2fbd16a2cde417
https://juvaecom.jhan.com.br/cadastro/bf981eccd4d868c603db10ef48888e8e6ab83805c568255b2d2fbd16a2cde417
https://juvaecom.com.br/cadastro/9emGEzwjv4yIwJNSmksHnkEz53-v5e8G23IbUCRtgOM
https://juvaecom.jhan.com.br/cadastro/xcLkS8rw_USN708XMsHOLuvWc6DRuNSC7-9UfZkFlT0
https://juvaecom.jhan.com.br/cadastro/yOXFCGU3n49RC5FUHMt1cifLLfydmqVV-5tRjvvBi8M
https://juvaecom.jhan.com.br/cadastro/WxJ5SKdr3hrnIiABtGv1vaXULz7f-u6yLQjvkl3_t9A

https://juvaecom.jhan.com.br/cadastro/Id39CRFjjWhgVmTSX_ovOEbaQi7gd83FYeUPw0ZeeNw

SELECT cd_contrato, cd_status
FROM public.tb_contrato
WHERE cd_cliente = 42;


SELECT table_name, column_name, data_type, is_nullable
FROM information_schema.columns
WHERE table_schema = 'public'
  AND table_name IN ('tb_contrato', 'tb_contrato_modelo', 'tb_contrato_documento')
ORDER BY table_name, ordinal_position;

SELECT * FROM tb_contrato_modelo LIMIT 3;

select * from tb_cliente;

select * from tb_contrato;

select * from vw_dashboard_admin;

SELECT * FROM public.vw_dashboard_admin


SELECT * FROM vw_contatos_pendentes ORDER BY dt_cadastro DESC

SELECT cd_contato, nm_contato, email, celular, dt_cadastro, dias_aguardando
FROM vw_contatos_pendentes
ORDER BY dt_cadastro DESC
LIMIT 10;

SELECT * FROM vw_contatos_pendentes LIMIT 0;

SELECT * FROM vw_contatos_pendentes;

select * from tb_contato;

SELECT * FROM tb_contato_status ORDER BY cd_status;

SELECT viewname, definition
FROM pg_views
WHERE schemaname = 'public'
AND viewname IN ('vw_contatos_pendentes', 'vw_cobranca_proximos',
                   'vw_cobranca_vencidos', 'vw_cobranca_inadimplentes','vw_dashboard_admin');

select * from tb_plano;


SELECT column_name, data_type, is_nullable, column_default
FROM information_schema.columns
WHERE table_schema = 'public' AND table_name = 'tb_plano_servico'
ORDER BY ordinal_position;
	
ALTER TABLE tb_plano ADD COLUMN cd_plano_tipo integer;

update tb_plano
set cd_plano_tipo = cd_plano


select periodicidade_dias, valor, dt_plano from tb_plano;

select * from tb_contrato;


DROP INDEX IF EXISTS uq_plano_nome_ativo;

CREATE UNIQUE INDEX uq_plano_tipo_ativo
ON public.tb_plano (cd_plano_tipo);

SELECT indexname, indexdef
FROM pg_indexes
WHERE tablename = 'tb_plano'
AND indexname = 'uq_plano_nome_ativo';


SELECT cd_plano, cd_plano_tipo, nm_plano, periodicidade_dias, dt_cadastro
FROM tb_plano
WHERE cd_plano_tipo = 3
ORDER BY cd_plano;

select * from tb_pessoa
where nm_pessoa = 'simone apartecida'

A regra deverá ser a seguinte em ordem:

Cliente envia dados via link (Pendente)
A Jovecom acessa esse cliente pendente (página Cadastro Cliente, botão Pendente) e confirma dados cadastrais, esse registro de cliente passa de pendente para 

select * from tb_cliente_status;
select * from tb_contrato_status;

SELECT c.cd_status, s.nm_status, COUNT(*) AS quantidade
FROM public.tb_contrato c
JOIN public.tb_contrato_status s ON s.cd_status = c.cd_status
GROUP BY c.cd_status, s.nm_status
ORDER BY c.cd_status;



BEGIN;

UPDATE public.tb_contrato
SET cd_status = CASE cd_status
    WHEN 2 THEN 1
    WHEN 3 THEN 2
END
WHERE cd_status IN (2, 3);

SELECT c.cd_status, s.nm_status, COUNT(*) AS quantidade
FROM public.tb_contrato c
JOIN public.tb_contrato_status s ON s.cd_status = c.cd_status
GROUP BY c.cd_status, s.nm_status
ORDER BY c.cd_status;

ROLLBACK;


select * from tb_pessoa
where cd_pessoa = 40

select * from tb_cliente
where cd_cliente = 45

select * from tb_contrato
where cd_contrato = 45

select * from tb_pessoa a inner join tb_cliente b
on a.cd_pessoa = b.cd_pessoa
inner join tb_contrato c
on b.cd_cliente = c.cd_cliente
where a.cd_pessoa = 40 and b.cd_cliente = 45

truncate table tb_pessoa;
truncate table tb_cliente;
truncate table tb_contrato;





1	Pendente	Recebido, aguardando conferência ou em análise
2	Aprovado	Dados conferidos, corrigidos e confirmados pelo analista
3	Confirmado	Cliente acessou o site e definiu sua senha
4	Reprovado	Cadastro encerrado sem aprovação

select * from tb_contrato_status
1	pendente		Cadastro aguardando validação dos dados
2	assinatura		Contrato emitido e aguardando assinatura
3	ativo			Contrato assinado e em vigência
4	inadimplente	Contrato suspenso por falta de pagamento
5	vencido			Contrato que atingiu o fim da vigência
6	cancelado		Contrato cancelado e mantido para histórico

SELECT s.cd_status, s.nm_status, COUNT(c.cd_contrato) AS contratos
FROM public.tb_contrato_status s
LEFT JOIN public.tb_contrato c ON c.cd_status = s.cd_status
GROUP BY s.cd_status, s.nm_status
ORDER BY s.cd_status;

SELECT con.conname AS constraint_name,
       con.conrelid::regclass AS tabela_origem,
       pg_get_constraintdef(con.oid) AS definicao
FROM pg_constraint con
WHERE con.contype = 'f'
  AND con.confrelid = 'public.tb_contrato_status'::regclass
ORDER BY con.conrelid::regclass::text;



select * from tb_cliente
where cd_pessoa = 49

select * from tb_cliente
where cd_cliente = 54

select * from tb_contrato
where cd_cliente = 54

select * from tb_cliente
where nm_responsavel 

SELECT schemaname, viewname, definition
FROM pg_views
WHERE schemaname = 'public'
  AND (definition ILIKE '%tb_cliente%' OR viewname ILIKE '%pendente%');

select * from tb_plano;

select * from tb_cliente;

select * from tb_plano_servico;
select * from tb_servico;

SELECT cd_plano, cd_plano_tipo, nm_plano, periodicidade_dias
FROM tb_plano
ORDER BY cd_plano;

SELECT
    p.nm_pessoa,
    p.tp_pessoa,
    p.cpf_cnpj,
    p.telefone,
    p.email,
    p.dados->>'endereco' AS endereco,
    p.dados->>'numero' AS numero,
    p.dados->>'complemento' AS complemento,
    p.dados->>'bairro' AS bairro,
    p.dados->>'cidade' AS cidade,
    p.dados->>'uf' AS uf,
    p.dados->>'cep' AS cep
FROM public.tb_pessoa p
WHERE p.cd_pessoa = 3;

select * from tb_pessoa;


-- Pessoa ------------------------------------
-- --------------------------------------------------------------------------------------------------------------------------------------------------------
INSERT INTO tb_pessoa (tp_pessoa, nm_pessoa, cpf_cnpj, telefone    , email, dados, fl_ativo, dt_cadastro, dt_atualizacao) values
('F', 'José Hilário Alves Neto',  '06478701859', '11 9 7666-0826'  , 'hilaneto@yahoo.com.br'  , '{}'::jsonb, true, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
('F', 'Juvenal Pereira de Souza', '12345678195', '11 98738-5695'   , 'variedadesjps@gmail.com', '{}'::jsonb, true, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
('J', 'JPS - Juvaecom Promoções', '22144785142369', '11 98738-5695', 'juvaps@gmail.com'       , '{}'::jsonb, true, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP);

select a.nm_pessoa, b.nm_responsavel  from tb_pessoa a inner join tb_cliente b 
on a.cd_pessoa  = b.cd_pessoa
left join tb_loja c
on b.cd_cliente  = c.cd_cliente
where a.nm_pessoa = b.nm_responsavel

select * from tb_pessoa
order by dt_atualizacao desc;


select * from tb_cliente_link;

SELECT cd_link, cd_cliente, dt_criacao, dt_validade, dt_utilizacao
FROM tb_cliente_link
ORDER BY cd_link desc
LIMIT 5;


SELECT c.cd_cliente, p.nm_pessoa, c.cd_status, s.nm_status
FROM tb_cliente c
JOIN tb_pessoa p ON p.cd_pessoa = c.cd_pessoa
JOIN tb_cliente_status s ON s.cd_status = c.cd_status
WHERE c.cd_cliente = 1;


-- Usuários -----------------------------------
INSERT INTO tb_usuario (cd_pessoa, cd_nivel, login, senha_hash, fl_ativo) values
(0, 0, 'hilaneto', 'scrypt:32768:8:1$4mjPXrerf5DlpXpO$f8a99dcefa0f79ae3731df309f3e64eb24c34d2d252e79bf8ff4c22321e79b26d1238145047ef14d8fd23c381e249b17d2886e9e1256a9cf6bf57576480dcc8f', true),
(1, 1, 'juvenal' , 'scrypt:32768:8:1$zebpNPKMDH6Ck8IR$97ec87e2c1f9f8a67192ef784f86dab8223eb8e5570764ae86cd2cafd557ae1278eb0a9ab8fbc4c0a16c1df6703ae50815d765989e0ca465ff7a35bc5d820ec0', true);

select * from tb_usuario;

-- CONTATOS -----------------------------------
select * from tb_contato;
select * from tb_contato_conversa;


INSERT into tb_contato
(cd_status, nm_contato, celular, email, mensagem)
VALUES(1, 'Juvenal Pereira de Souza', '11 98738-5695', 'variedadesjps@gmail.com', 'TESTE');


-- --------------------------------
SELECT column_name, data_type, is_nullable, column_default
FROM information_schema.columns
WHERE table_schema = 'public' AND table_name = 'tb_loja'
ORDER BY ordinal_position;
-- --------------------------------
SELECT conname, pg_get_constraintdef(oid)
FROM pg_constraint
WHERE conrelid = 'public.tb_loja'::regclass;
-- -------------------------------
SELECT column_name, character_maximum_length
FROM information_schema.columns
WHERE table_name = 'tb_loja'
AND column_name IN ('nm_loja', 'url_loja');



-- contatos ---
INSERT INTO tb_contato (nm_contato, celular, email, mensagem, marketplace, cd_status, dt_cadastro, dt_atualizacao)
SELECT
    'Contato Teste ' || lpad(n::text, 2, '0'),
    '1190000' || lpad(n::text, 4, '0'),
    'contato' || n || '@example.com',
    CASE
        WHEN n % 3 = 1 THEN 'Gostaria de conhecer os planos de gestão.'
        WHEN n % 3 = 2 THEN 'Aguardando retorno sobre a proposta.'
        ELSE 'Atendimento de teste encerrado.'
    END,
    n % 2 = 0,
    CASE
        WHEN n % 3 = 1 THEN 1  -- Aguardando: 8 contatos
        WHEN n % 3 = 2 THEN 2  -- Pendente: 8 contatos
        ELSE 3                -- Finalizado: 7 contatos
    END,
    CURRENT_TIMESTAMP - (n - 1) * INTERVAL '1 day',
    CURRENT_TIMESTAMP - (n - 1) * INTERVAL '1 day' + INTERVAL '30 minutes'
FROM generate_series(1, 23) AS serie(n);




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

-- tb_contrato_documento --------
SELECT cd_modelo, octet_length(arquivo_pdf) AS tamanho_bytes, dt_atualizacao
FROM tb_contrato_modelo;


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
SELECT c.cd_contrato, c.vl_contrato,
       sum(p.vl_parcela - p.vl_desconto) AS total_parcelas
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

