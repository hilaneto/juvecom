-- ============================================================================
-- JUVECOM | CRIACAO INTEGRAL DO BANCO - AMBIENTE DEV
-- Revisao: 2026-11-21 v2 | JUV-027 + funcoes de listagem
-- Base: cria_juvecom(1).sql de 2026-11-18
-- ATENCAO: ESTE SCRIPT APAGA O BANCO juvecom E TODOS OS SEUS DADOS.
-- Executar SOMENTE no servidor DEV, com backup previo e conexoes encerradas.
-- Exemplo: psql -U hilaneto -d postgres -v ON_ERROR_STOP=1 -v RECRIAR_DEV=1 -f cria_juvecom.sql
-- Nao executar no ambiente de producao.
-- ============================================================================
\if :{?RECRIAR_DEV}
\if :RECRIAR_DEV
\echo 'ATENCAO: recriando o banco juvecom; dados anteriores serao perdidos.'
\else
\echo 'ABORTADO: RECRIAR_DEV precisa ser 1.'
\quit
\endif
\else
\echo 'ABORTADO: e necessario informar -v RECRIAR_DEV=1.'
\quit
\endif

DROP DATABASE IF EXISTS juvecom;
CREATE DATABASE juvecom;
\connect juvecom

BEGIN;
-- ==============================================================
-- tb_contato: captação de interessados (sem vínculo com plano ou contrato)
-- ==============================================================
CREATE TABLE public.tb_contato (
cd_contato BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
nm_contato VARCHAR(150) NOT NULL,
celular VARCHAR(20) NOT NULL,
email VARCHAR(150),
mensagem TEXT,
marketplace BOOLEAN NOT NULL DEFAULT FALSE,
cd_status SMALLINT NOT NULL DEFAULT 1,
dt_cadastro TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
dt_atualizacao TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
CONSTRAINT ck_contato_status CHECK (cd_status IN (1, 2, 3)));


-- ============================================================
-- tb_pessoa - drop table tb_pessoa cascade
-- ============================================================
CREATE TABLE tb_pessoa (
cd_pessoa bigint GENERATED ALWAYS AS IDENTITY (MINVALUE 0 START WITH 0) PRIMARY KEY,
tp_pessoa char(1) NOT NULL,
nm_pessoa varchar(150) NOT NULL,
cpf_cnpj varchar(14) NOT NULL UNIQUE,
telefone varchar(20),
email varchar(150),
dados jsonb NOT NULL DEFAULT '{}'::jsonb,
fl_ativo boolean NOT NULL DEFAULT true,
dt_cadastro timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
dt_atualizacao timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
CONSTRAINT ck_pessoa_tipo CHECK (tp_pessoa IN ('F', 'J')),
CONSTRAINT ck_pessoa_nome CHECK (btrim(nm_pessoa) <> ''),
CONSTRAINT ck_pessoa_cpf_cnpj CHECK ((tp_pessoa = 'F' AND cpf_cnpj ~ '^[0-9]{11}$') OR (tp_pessoa = 'J' AND cpf_cnpj ~ '^[0-9]{14}$')),
CONSTRAINT ck_pessoa_dados CHECK (jsonb_typeof(dados) = 'object'),
CONSTRAINT ck_pessoa_dados_endereco CHECK (NOT (dados ? 'endereco') OR (jsonb_typeof(dados -> 'endereco') = 'string' AND char_length(dados ->> 'endereco') <= 60)),
CONSTRAINT ck_pessoa_dados_numero CHECK (NOT (dados ? 'numero') OR (jsonb_typeof(dados -> 'numero') = 'string' AND char_length(dados ->> 'numero') <= 10)),
CONSTRAINT ck_pessoa_dados_complemento CHECK (NOT (dados ? 'complemento') OR (jsonb_typeof(dados -> 'complemento') = 'string' AND char_length(dados ->> 'complemento') <= 20)),
CONSTRAINT ck_pessoa_dados_bairro CHECK (NOT (dados ? 'bairro') OR (jsonb_typeof(dados -> 'bairro') = 'string' AND char_length(dados ->> 'bairro') <= 50)),
CONSTRAINT ck_pessoa_dados_cep CHECK (NOT (dados ? 'cep') OR (jsonb_typeof(dados -> 'cep') = 'string' AND ((dados ->> 'cep') = '' OR (dados ->> 'cep') ~ '^[0-9]{8}$'))),
CONSTRAINT ck_pessoa_dados_cidade CHECK (NOT (dados ? 'cidade') OR (jsonb_typeof(dados -> 'cidade') = 'string' AND char_length(dados ->> 'cidade') <= 50)),
CONSTRAINT ck_pessoa_dados_uf CHECK (NOT (dados ? 'uf') OR (jsonb_typeof(dados -> 'uf') = 'string' AND ((dados ->> 'uf') = '' OR (dados ->> 'uf') ~ '^[A-Z]{2}$'))));


-- Cadastre pessoas reais por procedimento seguro após a instalação.
-- ============================================================
-- tb_cliente_status: etapas do cadastro JUV-026
-- ============================================================
CREATE TABLE tb_cliente_status (
cd_status SMALLINT PRIMARY KEY,
nm_status VARCHAR(30) NOT NULL UNIQUE,
ds_status VARCHAR(200) NOT NULL);


INSERT INTO tb_cliente_status (cd_status, nm_status, ds_status) VALUES
(1, 'Pendente', 'Recebido, aguardando conferência ou em análise'),
(2, 'Aprovado', 'Dados conferidos, corrigidos e confirmados pelo analista'),
(3, 'Confirmado', 'Cliente acessou o site e definiu sua senha'),
(4, 'Reprovado', 'Cadastro encerrado sem aprovação'),
(5, 'Cancelado', 'Cliente cancelado/excluído da base');


-- ============================================================
-- tb_cliente - drop table tb_cliente cascade
-- ============================================================
CREATE TABLE tb_cliente (
cd_cliente BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
cd_pessoa BIGINT NOT NULL UNIQUE REFERENCES tb_pessoa(cd_pessoa),
nm_responsavel VARCHAR(150),
cd_status SMALLINT NOT NULL DEFAULT 2 REFERENCES tb_cliente_status(cd_status),
dt_cadastro TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
dt_atualizacao TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP);


-- ============================================================
-- tb_loja - drop table tb_loja cascade
-- ============================================================
CREATE TABLE tb_loja (
cd_loja BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
cd_cliente BIGINT NOT NULL REFERENCES tb_cliente(cd_cliente),
nm_loja VARCHAR(150) NOT NULL,
shop_id BIGINT UNIQUE,
url_loja VARCHAR(500),
fl_ativo BOOLEAN NOT NULL DEFAULT TRUE,
dt_cadastro TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
dt_atualizacao TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
UNIQUE (cd_cliente, cd_loja));


CREATE INDEX ix_loja_cliente ON tb_loja (cd_cliente);


-- ============================================================
-- tb_servico: catálogo de serviços individuais
-- ============================================================
CREATE TABLE tb_servico (
cd_servico bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
nm_servico varchar(100) NOT NULL,
ds_servico varchar(500),
vl_servico numeric(12,2),
fl_ativo boolean NOT NULL DEFAULT true,
dt_cadastro timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
CONSTRAINT ck_servico_preco_base CHECK (vl_servico >= 0));


-- -----------------------------------------------------------------------------------------------------------------------------------------------------------------
INSERT INTO tb_servico (nm_servico, ds_servico, vl_servico) values
('Diagnóstico inicial', 'Análise inicial da loja e definição de prioridades e recomendações de atuação.',0),
('Gestão e otimização da loja', 'Configuração, organização e melhoria contínua da presença da loja na Shopee.',0),
('Gestão de anúncios e produtos', 'Otimização recorrente de títulos, descrições, atributos, categorias, preços e variações dos produtos.',0),
('Tratamento de imagens de anúncios', 'Criação, tratamento ou melhoria de imagens com base nos materiais fornecidos pelo cliente, conforme o plano contratado.',0),
('Promoções e campanhas', 'Planejamento de cupons, kits, benefícios de frete, campanhas sazonais e outras ações promocionais aplicáveis.',0),
('Gestão de Shopee Ads', 'Avaliação, configuração e otimização de anúncios patrocinados, mediante aprovação e saldo de mídia do cliente.',0),
('Métricas e recomendações', 'Acompanhamento de indicadores de desempenho e elaboração de recomendações de melhoria.',0),
('Suporte e alinhamento operacional', 'Orientações e alinhamentos sobre a operação da loja pelos canais oficiais de atendimento.',0);


-- =====================================================================
-- tb_plano: pacotes oferecidos ao cliente - drop table tb_plano cascade
-- =====================================================================
CREATE TABLE tb_plano (
cd_plano bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
cd_plano_tipo integer NOT NULL,
nm_plano varchar(100) NOT NULL,
ds_plano varchar(500),
periodicidade_dias integer NOT NULL,
valor numeric(12,2) NOT NULL,
texto_banner varchar(100),
texto_periodo varchar(100),
beneficios jsonb NOT NULL DEFAULT '[]'::jsonb,
fl_ativo boolean NOT NULL DEFAULT true,
dt_cadastro timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
CONSTRAINT ck_plano_periodicidade CHECK (periodicidade_dias > 0),
CONSTRAINT ck_plano_preco CHECK (valor >= 0),
CONSTRAINT ck_plano_beneficios CHECK (jsonb_typeof(beneficios) = 'array'));


-- -----------------------------------------------------------------------------------------------------------------------------------------
INSERT INTO tb_plano (cd_plano_tipo, nm_plano, ds_plano, periodicidade_dias, valor,texto_banner, texto_periodo, beneficios)
VALUES
(1,'Diamante',
 'Para quem busca crescimento sustentável e evolução contínua da sua loja Shopee, com acompanhamento estratégico ao longo de todo o ano.',
 360, 900,
 'Gestão completa da loja', '12 meses de acompanhamento',
 '["Gestão completa da operação", "Anúncios e Shopee Ads", "Campanhas e promoções", "Análise de performance", "Relatórios e acompanhamento"]'::jsonb),
(2,'Safira', 'Ideal para quem quer estruturar e impulsionar a operação da loja com consistência, em um ciclo intermediário de evolução.',
180, 1100,
 'Gestão completa da loja', '6 meses de acompanhamento',
 '["Gestão completa da operação", "Anúncios e Shopee Ads", "Campanhas e promoções", "Análise de performance", "Relatórios e acompanhamento"]'::jsonb),
(3,'Esmeralda','Para quem deseja organizar, otimizar e ganhar tração na loja em um período inicial, com foco em resultados e direcionamento prioritário.',
 90, 1300,'Gestão completa da loja','3 meses de acompanhamento',
 '["Gestão completa da operação", "Anúncios e Shopee Ads", "Campanhas e promoções", "Análise de performance", "Relatórios e acompanhamento"]'::jsonb),
(4,'Avulso','Uma análise completa da sua loja para identificar os principais problemas, oportunidades e prioridades de ação.',
  7, 150,'Análise de Conta','Análise em reunião de 1 hora',
 '["Diagnóstico da operação", "Análise de anúncios e campanhas", "Avaliação de Shopee Ads", "Recomendações personalizadas", "Entrega de relatório com plano de ação"]'::jsonb
);


-- -------------------------------------
CREATE UNIQUE INDEX uq_plano_nome_ativo
ON tb_plano (nm_plano)
WHERE fl_ativo;


-- ============================================================
-- tb_plano_servico: serviços incluídos em cada plano
-- ============================================================
CREATE TABLE tb_plano_servico (
cd_plano bigint NOT NULL REFERENCES tb_plano(cd_plano),
cd_servico bigint NOT NULL REFERENCES tb_servico(cd_servico),
CONSTRAINT pk_plano_servico PRIMARY KEY (cd_plano, cd_servico));


-- -----------------------------------------------------------------------
INSERT INTO tb_plano_servico (cd_plano, cd_servico)
SELECT p.cd_plano, s.cd_servico
FROM tb_plano p
CROSS JOIN tb_servico s
WHERE p.nm_plano IN ('Diamante', 'Safira', 'Esmeralda')
   OR (p.nm_plano = 'Avulso' AND s.nm_servico = 'Diagnóstico inicial');


-- ============================================================
-- tb_contrato_status
-- ============================================================
CREATE TABLE tb_contrato_status (
cd_status smallint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
nm_status varchar(30) NOT NULL UNIQUE,
ds_status varchar(200) NOT NULL);


-- -------------------------------------------------------------
INSERT INTO tb_contrato_status (nm_status, ds_status) VALUES
('Sem assinatura', 'Contrato emitido e aguardando assinatura'),
('Vigente', 'Vigente sem restrições'),
('Inadimplente', 'Suspenso por falta de pagamento'),
('Liquidado', 'Liquidado atingiu o fim da vigência'),
('Cancelado', 'Cancelado mantido para histórico');


-- ============================================================
-- tb_contrato - drop table tb_contrato cascade
-- ============================================================
CREATE TABLE public.tb_contrato (
cd_contrato BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
cd_cliente BIGINT NOT NULL REFERENCES public.tb_cliente(cd_cliente),
cd_plano BIGINT NOT NULL REFERENCES public.tb_plano(cd_plano),
cd_status SMALLINT NOT NULL REFERENCES public.tb_contrato_status(cd_status),
cd_contrato_origem BIGINT,
nm_plano VARCHAR(100) NOT NULL,
ds_plano VARCHAR(500),
vigencia DATERANGE NOT NULL,
vl_bruto NUMERIC(12,2) NOT NULL,
vl_desconto_lojas NUMERIC(12,2) NOT NULL DEFAULT 0,
vl_desconto_manual NUMERIC(12,2) NOT NULL DEFAULT 0,
vl_acrescimo NUMERIC(12,2) NOT NULL DEFAULT 0,
vl_contrato NUMERIC(12,2) NOT NULL,
ds_contrato VARCHAR(500),
ds_observacao TEXT,
dt_cadastro TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
dt_atualizacao TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
CONSTRAINT uq_contrato_cliente_contrato UNIQUE (cd_cliente, cd_contrato),
CONSTRAINT fk_contrato_origem FOREIGN KEY (cd_cliente, cd_contrato_origem)
REFERENCES public.tb_contrato (cd_cliente, cd_contrato),
CONSTRAINT ck_contrato_origem_self CHECK (cd_contrato_origem IS NULL OR cd_contrato_origem <> cd_contrato),
CONSTRAINT ck_contrato_vigencia CHECK (NOT isempty(vigencia) AND NOT lower_inf(vigencia)),
CONSTRAINT ck_contrato_valores CHECK (
vl_bruto >= 0 AND vl_desconto_lojas >= 0 AND vl_desconto_manual >= 0 AND vl_acrescimo >= 0
AND vl_contrato = vl_bruto - vl_desconto_lojas - vl_desconto_manual + vl_acrescimo
AND vl_contrato >= 0));
-- --------------------------------------------------------------------------
CREATE INDEX ix_contrato_origem ON public.tb_contrato (cd_contrato_origem);
CREATE INDEX ix_contrato_vigencia ON tb_contrato USING gist (vigencia);
CREATE INDEX ix_contrato_cliente ON tb_contrato (cd_cliente);


-- ============================================================
-- tb_contrato_documento: contrato físico em .pdf
-- ============================================================
CREATE TABLE tb_contrato_documento (
cd_documento bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
cd_contrato bigint NOT NULL UNIQUE REFERENCES tb_contrato(cd_contrato),
arquivo_pdf bytea NOT NULL,
dt_assinatura timestamptz NOT NULL,
dt_atualizacao timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
CONSTRAINT ck_documento_pdf CHECK (octet_length(arquivo_pdf) > 0));


-- ============================================================
-- tb_contrato_modelo: contrato modelo em .pdf
-- ============================================================
CREATE TABLE tb_contrato_modelo (
cd_modelo bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
arquivo_pdf bytea NOT NULL,
dt_atualizacao timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
CONSTRAINT ck_modelo_pdf CHECK (octet_length(arquivo_pdf) > 0));


-- ============================================================
-- tb_parcelas: parcelas de contratos
-- pc_desconto: percentual sobre parcela + multa + juros, aplicado na quitacao.
-- dt_atualizacao: atualizar via Peewee em cada UPDATE (sem trigger).
-- ============================================================
CREATE TABLE tb_parcelas (
cd_parcela bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
cd_contrato bigint NOT NULL REFERENCES tb_contrato(cd_contrato),
nr_parcela integer NOT NULL,
dt_vencimento date NOT NULL,
vl_parcela numeric(12,2) NOT NULL,
pc_desconto numeric(5,2) NOT NULL DEFAULT 0,
dt_pagamento date,
vl_pago numeric(12,2),
dt_atualizacao timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
CONSTRAINT uq_parcelas_contrato_numero UNIQUE (cd_contrato, nr_parcela),
CONSTRAINT ck_parcelas_numero CHECK (nr_parcela > 0),
CONSTRAINT ck_parcelas_valores CHECK (vl_parcela >= 0 AND (vl_pago IS NULL OR vl_pago >= 0)),
CONSTRAINT ck_parcelas_desconto CHECK (pc_desconto BETWEEN 0 AND 100),
CONSTRAINT ck_parcelas_pagamento CHECK ((dt_pagamento IS NULL) = (vl_pago IS NULL)));


-- ============================================================
-- tb_encargo_atraso: politica de multas em caso de atrasos
-- ============================================================
CREATE TABLE tb_encargo_atraso (
cd_encargo bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
vigencia daterange NOT NULL,
percentual_multa numeric(5,2) NOT NULL DEFAULT 0,
juros_mensal numeric(5,2) NOT NULL DEFAULT 0,
juros_diario numeric(8,5) NOT NULL DEFAULT 0,
dias_carencia integer NOT NULL DEFAULT 0,
CONSTRAINT ck_encargo_vigencia CHECK (NOT isempty(vigencia) AND NOT lower_inf(vigencia)),
CONSTRAINT ck_encargo_percentuais CHECK (percentual_multa BETWEEN 0 AND 100 AND juros_mensal BETWEEN 0 AND 100 AND juros_diario BETWEEN 0 AND 100),
CONSTRAINT ck_encargo_dias CHECK (dias_carencia >= 0),
CONSTRAINT ex_encargo_vigencia EXCLUDE USING gist (vigencia WITH &&));


-- -------------------------------------------------------------------------------------------
INSERT INTO tb_encargo_atraso (vigencia, percentual_multa, juros_mensal, juros_diario, dias_carencia)
VALUES (daterange(DATE '2026-09-26', NULL, '[)'), 2, 1, 0, 0);


-- ============================================================
-- tb_desconto_loja: desconto por lojas
-- ============================================================
CREATE TABLE tb_desconto_loja (
cd_desconto bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
qt_loja int4range NOT NULL,
vigencia daterange NOT NULL,
desconto numeric(5,2) NOT NULL,
CONSTRAINT ck_desconto_faixa CHECK (NOT isempty(qt_loja) AND NOT lower_inf(qt_loja) AND lower(qt_loja) > 0),
CONSTRAINT ck_desconto_vigencia CHECK (NOT isempty(vigencia) AND NOT lower_inf(vigencia)),
CONSTRAINT ck_desconto_percentual CHECK (desconto BETWEEN 0 AND 100),
CONSTRAINT ex_desconto_faixas EXCLUDE USING gist (qt_loja WITH &&, vigencia WITH &&));


-- ----------------------------------------------------------------------
INSERT INTO tb_desconto_loja (qt_loja, vigencia, desconto) VALUES
(int4range(1, 2, '[)'), daterange(DATE '2026-09-26', NULL, '[)'),  0),
(int4range(2, 3, '[)'), daterange(DATE '2026-09-26', NULL, '[)'), 10),
(int4range(3, NULL, '[)'), daterange(DATE '2026-09-26', NULL, '[)'), 20);


-- ============================================================
-- tb_contrato_loja: lojas cobertas por contrato, com consistência de cliente
-- ============================================================
-- Redundância controlada de cd_cliente: FKs compostas impedem vínculo cruzado entre clientes.
CREATE TABLE tb_contrato_loja (
cd_contrato BIGINT NOT NULL,
cd_loja BIGINT NOT NULL,
cd_cliente BIGINT NOT NULL REFERENCES tb_cliente(cd_cliente),
PRIMARY KEY (cd_contrato, cd_loja),
CONSTRAINT fk_contrato_loja_contrato FOREIGN KEY (cd_cliente, cd_contrato) REFERENCES tb_contrato(cd_cliente, cd_contrato),
CONSTRAINT fk_contrato_loja_loja FOREIGN KEY (cd_cliente, cd_loja) REFERENCES tb_loja(cd_cliente, cd_loja));

CREATE INDEX ix_contrato_loja_loja ON tb_contrato_loja (cd_loja);


-- ============================================================
-- tb_usuario_nivel - drop table tb_usuario_nivel cascade
-- ============================================================
CREATE TABLE tb_usuario_nivel (
cd_nivel smallint GENERATED ALWAYS AS IDENTITY (MINVALUE 0 START WITH 0) PRIMARY KEY,
nm_nivel varchar(30) NOT NULL UNIQUE);

INSERT INTO tb_usuario_nivel (nm_nivel) values ('master');
INSERT INTO tb_usuario_nivel (nm_nivel) values ('superior');
INSERT INTO tb_usuario_nivel (nm_nivel) values ('médio');
INSERT INTO tb_usuario_nivel (nm_nivel) values ('intermediário');
INSERT INTO tb_usuario_nivel (nm_nivel) values ('limitado');
INSERT INTO tb_usuario_nivel (nm_nivel) values ('cliente'); -- cd_nivel = 5


-- ============================================================
-- tb_usuario - drop table tb_usuario cascade
-- ============================================================
CREATE TABLE tb_usuario (
cd_usuario bigint GENERATED ALWAYS AS IDENTITY (MINVALUE 0 START WITH 0) PRIMARY KEY,
cd_pessoa bigint NOT NULL UNIQUE REFERENCES tb_pessoa(cd_pessoa),
cd_nivel smallint NOT NULL REFERENCES tb_usuario_nivel(cd_nivel),
login varchar(100) NOT NULL UNIQUE,
senha_hash text NOT NULL,
fl_ativo boolean NOT NULL DEFAULT true,
dt_atualizacao timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
CONSTRAINT ck_usuario_login CHECK (btrim(login) <> ''),
CONSTRAINT ck_usuario_senha CHECK (btrim(senha_hash) <> ''));


-- Cadastre usuários e gere hashes de senha na aplicação; não inclua credenciais fixas no DDL.
-- ============================================================
-- tb_cliente_link: convite exclusivo de pre-cadastro JUV-026
--   Disponivel: dt_utilizacao nula, dt_validade > agora
--   Utilizado  : dt_utilizacao preenchida e cd_cliente associado
--   Expirado  : dt_utilizacao nula, dt_validade <= agora
--   Status e calculado na aplicacao; nao fica duplicado no banco.
-- ============================================================
CREATE TABLE public.tb_cliente_link (
cd_link BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
token_hash VARCHAR(64) NOT NULL UNIQUE,
cd_usuario BIGINT NOT NULL REFERENCES public.tb_usuario(cd_usuario),
cd_cliente BIGINT REFERENCES public.tb_cliente(cd_cliente),
dt_criacao TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
dt_validade TIMESTAMPTZ NOT NULL DEFAULT (CURRENT_TIMESTAMP + INTERVAL '7 days'),
dt_utilizacao TIMESTAMPTZ,
CONSTRAINT ck_cliente_link_hash CHECK (token_hash ~ '^[0-9a-f]{64}$'),
CONSTRAINT ck_cliente_link_validade CHECK (dt_validade > dt_criacao),
CONSTRAINT ck_cliente_link_uso CHECK ((dt_utilizacao IS NULL) = (cd_cliente IS NULL)));

CREATE INDEX ix_cliente_link_usuario
ON public.tb_cliente_link (cd_usuario);

CREATE INDEX ix_cliente_link_cliente
ON public.tb_cliente_link (cd_cliente);

CREATE INDEX ix_cliente_link_validade_pendente
ON public.tb_cliente_link (dt_validade)
WHERE dt_utilizacao IS NULL;



-- ============================================================
-- tb_evento_log
-- ============================================================
CREATE TABLE tb_evento_log (
cd_evento smallint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
ds_evento varchar(30) NOT NULL UNIQUE);

INSERT INTO tb_evento_log (ds_evento) VALUES
('login'),
('insert'),
('delete'),
('update'),
('read'),
('logoff');


-- ============================================================
-- tb_logusuario
-- ============================================================
CREATE TABLE tb_logusuario (
cd_log bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
cd_usuario bigint REFERENCES tb_usuario(cd_usuario),
cd_evento smallint NOT NULL REFERENCES tb_evento_log(cd_evento),
login_informado varchar(100),
fl_sucesso boolean NOT NULL DEFAULT true,
ip_acesso inet,
dt_evento timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP);


-- ============================================================================
-- VIEWS FINANCEIRAS - JUV-027
-- Classificacao: proximos (hoje ate +3), vencidos (1 a 3 dias),
-- inadimplentes (4 ou mais dias). Carencia afeta encargos, nao classificacao.
-- Para simulacao/confirmacao em data escolhida, o Peewee deve recalcular
-- multa, juros e desconto na data efetiva do pagamento, usando Decimal.
-- A politica de encargos e escolhida por vigencia @> dt_vencimento.
-- ============================================================================
CREATE OR REPLACE VIEW vw_cobranca_proximos AS
SELECT p.cd_parcela, p.cd_contrato, p.nr_parcela, pe.nm_pessoa, pe.telefone, pe.email, c.nm_plano,
p.dt_vencimento, p.dt_vencimento - CURRENT_DATE AS dias_para_vencer, p.vl_parcela AS vl_a_pagar
FROM tb_parcelas p JOIN tb_contrato c ON c.cd_contrato = p.cd_contrato
JOIN tb_contrato_status st ON st.cd_status = c.cd_status
JOIN tb_cliente cl ON cl.cd_cliente = c.cd_cliente
JOIN tb_pessoa pe ON pe.cd_pessoa = cl.cd_pessoa
WHERE p.dt_pagamento IS NULL
AND p.dt_vencimento BETWEEN CURRENT_DATE AND CURRENT_DATE + 3
AND st.cd_status IN (2, 3);


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

-- A view preserva vl_juros (soma dos dois tipos), alem de discriminar cada um.
-- Politicas inexistentes para uma data de vencimento nao geram linha nesta view.
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
WHERE p.dt_pagamento IS NULL
AND CURRENT_DATE - p.dt_vencimento > 3
AND st.cd_status <> 5;

-- ==========================================================================
-- vw_contatos_pendentes: Contatos pendentes
-- ==========================================================================
CREATE VIEW public.vw_contatos_pendentes AS
SELECT c.cd_contato, c.nm_contato, c.email, c.celular, c.mensagem, c.dt_cadastro, CURRENT_DATE - c.dt_cadastro::date AS dias_aguardando
FROM public.tb_contato c
WHERE c.cd_status IN (1);


-- ==========================================================================
-- vw_usuario: drop view vw_usuario - Usuarios
-- ==========================================================================
CREATE OR REPLACE VIEW vw_usuario as
select a.cd_usuario, a.cd_pessoa, b.nm_pessoa, a.login, a.cd_nivel, c.nm_nivel, a.fl_ativo, a.dt_atualizacao
from tb_usuario a inner join tb_pessoa b
on a.cd_pessoa = b.cd_pessoa
left join tb_usuario_nivel c
on a.cd_nivel  = c.cd_nivel;


-- ==========================================================================
-- vw_dash_adm: drop view vw_dash_adm - Usuarios
-- ==========================================================================
CREATE OR REPLACE VIEW public.vw_dash_adm AS
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


-- ==========================================================================
-- vw_cobranca_proximos: drop view vw_cobranca_proximos - Usuarios
-- ==========================================================================
CREATE OR REPLACE VIEW public.vw_cobranca_proximos AS
SELECT p.cd_parcela, p.cd_contrato, p.nr_parcela,
       pe.nm_pessoa, pe.telefone, pe.email, c.nm_plano,
       p.dt_vencimento, p.dt_vencimento - CURRENT_DATE AS dias_para_vencer,
       p.vl_parcela AS vl_a_pagar
FROM tb_parcelas p
JOIN tb_contrato c ON c.cd_contrato = p.cd_contrato
JOIN tb_contrato_status st ON st.cd_status = c.cd_status
JOIN tb_cliente cl ON cl.cd_cliente = c.cd_cliente
JOIN tb_pessoa pe ON pe.cd_pessoa = cl.cd_pessoa
WHERE p.dt_pagamento IS NULL
AND p.dt_vencimento BETWEEN CURRENT_DATE + 1 AND CURRENT_DATE + 30
AND st.cd_status IN (2, 3);



-- ==========================================================================
-- vw_dashboard_fin: drop view vw_dashboard_fin - Usuarios
-- ==========================================================================
CREATE OR REPLACE VIEW public.vw_dash_fin AS
SELECT a.parcelas_proximas, a.valor_proximos,
       b.parcelas_vencidas, b.valor_vencidos,
       c.parcelas_inadimplentes, c.valor_inadimplencia
FROM (SELECT COUNT(*) AS parcelas_proximas, COALESCE(SUM(vl_a_pagar), 0) AS valor_proximos FROM public.vw_cobranca_proximos) a
CROSS JOIN (SELECT COUNT(*) AS parcelas_vencidas, COALESCE(SUM(vl_original), 0) AS valor_vencidos FROM public.vw_cobranca_vencidos) b
CROSS JOIN (SELECT COUNT(*) AS parcelas_inadimplentes, COALESCE(SUM(vl_total_atualizado), 0) AS valor_inadimplencia FROM public.vw_cobranca_inadimplentes) c;


-- ============================================================================
-- FUNCTIONS DE LISTAGEM (usadas pela aplicacao Flask/Peewee)
-- Os parametros sao INTEGER para compatibilidade com os filtros do formulario.
-- NULL retorna todos os registros. A ordem final e definida na consulta chamadora.
-- ============================================================================
CREATE OR REPLACE FUNCTION public.fn_listar_clientes(p_cd_status INTEGER DEFAULT NULL)
RETURNS TABLE (cd_cliente BIGINT, nm_pessoa VARCHAR(150))
LANGUAGE sql STABLE AS $$
    SELECT c.cd_cliente, p.nm_pessoa
    FROM public.tb_cliente c
    JOIN public.tb_pessoa p ON p.cd_pessoa = c.cd_pessoa
    WHERE p_cd_status IS NULL OR c.cd_status = p_cd_status;
$$;

CREATE OR REPLACE FUNCTION public.fn_listar_contratos(p_cd_status INTEGER DEFAULT NULL)
RETURNS TABLE (cd_contrato BIGINT, nm_pessoa VARCHAR(150), nm_status VARCHAR(30))
LANGUAGE sql STABLE AS $$
    SELECT c.cd_contrato, p.nm_pessoa, s.nm_status
    FROM public.tb_contrato c
    JOIN public.tb_cliente cl ON cl.cd_cliente = c.cd_cliente
    JOIN public.tb_pessoa p ON p.cd_pessoa = cl.cd_pessoa
    JOIN public.tb_contrato_status s ON s.cd_status = c.cd_status
    WHERE p_cd_status IS NULL OR c.cd_status = p_cd_status;
$$;

COMMIT;



-- ============================================================================
-- VERIFICACAO BASICA POS-INSTALACAO
-- ============================================================================
SELECT 'tabelas' AS objeto, count(*) AS quantidade FROM information_schema.tables
 WHERE table_schema = 'public' AND table_type = 'BASE TABLE'
UNION ALL
SELECT 'views', count(*) FROM information_schema.views WHERE table_schema = 'public';


-- ==========================================================================
-- SMOKE TESTS (somente leitura; banco pode estar vazio)
-- ==========================================================================
SELECT 'fn_listar_clientes' AS teste, count(*) AS linhas FROM public.fn_listar_clientes(NULL)
UNION ALL SELECT 'fn_listar_clientes(2)', count(*) FROM public.fn_listar_clientes(2)
UNION ALL SELECT 'fn_listar_contratos', count(*) FROM public.fn_listar_contratos(NULL)
UNION ALL SELECT 'fn_listar_contratos(2)', count(*) FROM public.fn_listar_contratos(2);

SELECT 'views_financeiras' AS teste, count(*) AS quantidade
FROM information_schema.views
WHERE table_schema = 'public' AND table_name IN
('vw_cobranca_proximos', 'vw_cobranca_vencidos', 'vw_cobranca_inadimplentes', 'vw_dash_fin');
