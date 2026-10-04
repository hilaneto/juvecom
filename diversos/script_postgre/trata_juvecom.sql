

SELECT table_name FROM information_schema.tables
WHERE table_schema = 'public';

-- -----------------------------------
select * from tb_servico;
select * from tb_plano;
select * from tb_plano_servico;
select * from tb_desconto_loja;
select * from tb_contrato_status;
select * from tb_encargo_atraso;
select * from tb_contato_status;
select * from tb_usuario_nivel;
select * from tb_evento_log;

select * from tb_pessoa;
select * from tb_usuario;

select * from tb_contrato_modelo;

-- -----------------------------------
select * from tb_loja;
select * from tb_contrato;
select * from tb_contrato_loja;
select * from tb_parcelas;

select * from tb_contato;

INSERT into tb_contato
(cd_status, nm_contato, celular, email, mensagem)
VALUES(1, 'Juvenal Pereira de Souza', '11 98738-5695', 'variedadesjps@gmail.com', 'TESTE');


-- --------------------------------------------------
--TRUNCATE TABLE tb_usuario RESTART IDENTITY CASCADE;

select * from vw_usuario;

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


