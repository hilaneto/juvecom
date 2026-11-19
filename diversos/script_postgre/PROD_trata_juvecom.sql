

SELECT table_name FROM information_schema.tables
WHERE table_schema = 'public';


-- -----------------------------------------------
select * from tb_plano;
select * from tb_servico;
select * from tb_contrato_status;
select * from tb_contato_status;
select * from tb_encargo_atraso;
select * from tb_desconto_loja;
select * from tb_usuario_nivel;
select * from tb_evento_log;
select * from tb_plano_servico;

-- -----------------------------------------------
select * from tb_pessoa;
select * from tb_cliente;
select * from tb_loja;
select * from tb_contrato;
select * from tb_contrato_documento;
select * from tb_contrato_modelo;
select * from tb_contato;
select * from tb_parcelas;
select * from tb_contrato_loja;
select * from tb_usuario;
select * from vw_cobranca_proximos;
select * from tb_contato_conversa;
select * from vw_cobranca_vencidos;
select * from tb_logusuario;
select * from vw_cobranca_inadimplentes;
select * from vw_contatos_pendentes;
select * from vw_usuario;
select * from tb_cliente_link;
select * from tb_cliente_status;
select * from tb_contrato_status;


select * from tb_cliente_status;

select * from tb_contrato_status;

SELECT s.cd_status, s.nm_status, COUNT(c.cd_contrato) AS qtd_contratos
FROM public.tb_contrato_status s
LEFT JOIN public.tb_contrato c ON c.cd_status = s.cd_status
GROUP BY s.cd_status, s.nm_status
ORDER BY s.cd_status;

SELECT viewname, definition
FROM pg_catalog.pg_views
WHERE schemaname = 'public'
  AND viewname IN (
      'vw_cobranca_proximos',
      'vw_cobranca_vencidos',
      'vw_cobranca_inadimplentes',
      'vw_dash_adm',
      'vw_dash_fin'
  )
ORDER BY viewname;

SELECT l.cd_link, l.cd_cliente, l.dt_utilizacao,
       c.cd_cliente AS cliente_cadastrado,
       c.cd_status, c.fl_ativo,
       p.nm_pessoa , p.cpf_cnpj
FROM public.tb_cliente_link l
LEFT JOIN public.tb_cliente c ON c.cd_cliente = l.cd_cliente
LEFT JOIN public.tb_pessoa p ON p.cd_pessoa = c.cd_pessoa
ORDER BY l.cd_link DESC;

-- ===================================================================================================================

select * from tb_cliente;

-- CONTATOS -----------------------------------
select * from tb_contato;
select * from tb_contato_conversa;
select * from tb_contato_status;

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

-- Carga massiva Contratos ---------------------------------------------------------------------------
BEGIN;

LOCK TABLE public.tb_pessoa, public.tb_cliente, public.tb_loja,
           public.tb_plano, public.tb_contrato_status IN SHARE MODE;
LOCK TABLE public.tb_contrato IN SHARE ROW EXCLUSIVE MODE;

CREATE TEMP TABLE lote_contratos_provisorios ON COMMIT DROP AS
SELECT c.cd_cliente, MIN(l.cd_loja) AS cd_loja, COUNT(l.cd_loja) AS lojas_ativas
FROM public.tb_cliente c
JOIN public.tb_pessoa p ON p.cd_pessoa = c.cd_pessoa
LEFT JOIN public.tb_loja l ON l.cd_cliente = c.cd_cliente AND l.fl_ativo
WHERE c.cd_status IN (2, 3)
  AND p.fl_ativo
  AND NOT EXISTS (SELECT 1 FROM public.tb_contrato ct WHERE ct.cd_cliente = c.cd_cliente)
GROUP BY c.cd_cliente;

DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM lote_contratos_provisorios WHERE lojas_ativas <> 1) THEN
        RAISE EXCEPTION 'Lote interrompido: há cliente elegível sem uma única loja ativa.';
    END IF;

    IF (SELECT COUNT(*) FROM public.tb_plano WHERE nm_plano = 'Avulso' AND fl_ativo) <> 1 THEN
        RAISE EXCEPTION 'Lote interrompido: é necessário exatamente um plano Avulso ativo.';
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM public.tb_contrato_status
        WHERE cd_status = 1 AND nm_status = 'Sem assinatura'
    ) THEN
        RAISE EXCEPTION 'Lote interrompido: status 1 deve ser Sem assinatura.';
    END IF;
END;
$$;

WITH novos AS (
    INSERT INTO public.tb_contrato (
        cd_cliente, cd_plano, cd_status, nm_plano, ds_plano,
        vigencia, vl_bruto, vl_contrato, ds_contrato
    )
    SELECT l.cd_cliente, p.cd_plano, 1, p.nm_plano, p.ds_plano,
           daterange(DATE '2026-11-19', DATE '2026-12-31', '[]'),
           100.00, 100.00, 'Contrato Provisório - Precisa ser Atualizado'
    FROM lote_contratos_provisorios l
    CROSS JOIN public.tb_plano p
    WHERE p.nm_plano = 'Avulso' AND p.fl_ativo
    RETURNING cd_cliente, cd_contrato
), vinculos AS (
    INSERT INTO public.tb_contrato_loja (cd_cliente, cd_contrato, cd_loja)
    SELECT n.cd_cliente, n.cd_contrato, l.cd_loja
    FROM novos n
    JOIN lote_contratos_provisorios l ON l.cd_cliente = n.cd_cliente
    RETURNING cd_cliente, cd_contrato, cd_loja
)
SELECT cd_cliente, cd_contrato, cd_loja, COUNT(*) OVER () AS total_criado
FROM vinculos
ORDER BY cd_cliente;

COMMIT;






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


CREATE OR REPLACE VIEW public.vw_dashboard_admin AS
SELECT
    (SELECT COUNT(*) FROM public.tb_cliente WHERE fl_ativo = TRUE) AS clientes_ativos,

    (SELECT COUNT(*) FROM public.tb_contrato c
     JOIN public.tb_contrato_status s ON s.cd_status = c.cd_status
     WHERE LOWER(s.nm_status) = 'ativo') AS contratos_ativos,

    (SELECT COALESCE(SUM(c.vl_bruto), 0)
     FROM public.tb_contrato c
     JOIN public.tb_contrato_status s ON s.cd_status = c.cd_status
     WHERE LOWER(s.nm_status) = 'ativo') AS valor_contratos_ativos,

    (SELECT COUNT(*) FROM public.vw_contatos_pendentes) AS contatos_pendentes,

    (SELECT COUNT(*) FROM public.vw_cobranca_proximos) AS parcelas_proximas,
    (SELECT COUNT(*) FROM public.vw_cobranca_vencidos) AS parcelas_vencidas,
    (SELECT COUNT(*) FROM public.vw_cobranca_inadimplentes) AS parcelas_inadimplentes,

    (SELECT COALESCE(SUM(vl_a_pagar), 0) FROM public.vw_cobranca_proximos) AS valor_proximos,
    (SELECT COALESCE(SUM(vl_original), 0) FROM public.vw_cobranca_vencidos) AS valor_vencidos,

    (SELECT COALESCE(SUM(vl_original + vl_multa + vl_juros), 0)
     FROM public.vw_cobranca_inadimplentes) AS valor_inadimplencia;

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


