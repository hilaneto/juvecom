-- ============================================================
-- BANCO: juvecom
-- SCHEMA: public
-- 2026-09-2026
-- rodar no terminal
-- local/local   : psql -U hilaneto -d postgres -v ON_ERROR_STOP=1 -f cria_juvecom.sql
-- local/servidor: scp cria_juvecom.sql vps:/tmp/cria_juvecom.sql && ssh -t vps 'psql -U hilaneto -d postgres -v ON_ERROR_STOP=1 -f /tmp/cria_juvecom.sql'
-- ============================================================


-- Cria o banco juvecom
DROP DATABASE IF EXISTS juvecom WITH (FORCE);
CREATE DATABASE juvecom;

-- Conectar ao banco juvecom antes de executar o restante.
\connect juvecom

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

-- --------------------------------------------------------------------------------------------------------------------------------------------------------
INSERT INTO tb_pessoa (tp_pessoa, nm_pessoa, cpf_cnpj, telefone, email, dados, fl_ativo, dt_cadastro, dt_atualizacao) values
('F', 'José Hilário Alves Neto', '06478701859', '11 9 7666-0826', 'hilaneto@yahoo.com.br', '{}'::jsonb, true, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
('F', 'Juvenal Pereira de Souza', '12345678195', '11 98738-5695', 'variedadesjps@gmail.com'     , '{}'::jsonb, true, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
('J', 'JPS - Juvaecom Promoções', '22144785142369', '11 98738-5695', 'variedadesjps@gmail.com'     , '{}'::jsonb, true, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP);


-- ============================================================
-- tb_relacao - drop table tb_relacao cascade
-- ============================================================
CREATE TABLE tb_relacao (
    cd_relacao smallint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    nm_relacao varchar(50) NOT NULL UNIQUE,
    dt_atualizacao timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT ck_relacao_nome CHECK (btrim(nm_relacao) <> '')
);

-- ---------------------------------------------------------------
INSERT INTO tb_relacao (nm_relacao)
VALUES ('Cliente'), ('Colaborador'), ('Fornecedor');


-- ============================================================
-- tb_pessoa_relacao - drop table tb_pessoa_relacao cascade
-- ============================================================
CREATE TABLE tb_pessoa_relacao (
    cd_pessoa bigint NOT NULL REFERENCES tb_pessoa (cd_pessoa),
    cd_relacao smallint NOT NULL REFERENCES tb_relacao (cd_relacao),
    dt_atualizacao timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (cd_pessoa, cd_relacao)
);

-- --------------------------------------------------
INSERT INTO tb_pessoa_relacao (cd_pessoa, cd_relacao) values
(0, 1), (0, 2),
(1, 1), (1, 2);


-- ============================================================
-- tb_loja
-- ============================================================
CREATE TABLE tb_loja (
cd_loja bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
cd_pessoa bigint NOT NULL,
nm_loja varchar(150) NOT NULL,
shop_id bigint,
url_loja varchar(500),
fl_ativo boolean NOT NULL DEFAULT true,
dt_cadastro timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
dt_atualizacao timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
CONSTRAINT fk_loja_pessoa FOREIGN KEY (cd_pessoa) REFERENCES tb_pessoa (cd_pessoa),
CONSTRAINT uq_loja_pessoa_loja UNIQUE (cd_pessoa, cd_loja),
CONSTRAINT uq_loja_shop_id UNIQUE (shop_id));


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


-- ============================================================
-- tb_plano: pacotes oferecidos ao cliente
-- ============================================================
CREATE TABLE tb_plano (
cd_plano bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
nm_plano varchar(100) NOT NULL,
ds_plano varchar(500),
periodicidade_dias integer NOT NULL,
valor numeric(12,2) NOT NULL,
texto_banner varchar(100),
fl_ativo boolean NOT NULL DEFAULT true,
dt_cadastro timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
CONSTRAINT ck_plano_periodicidade CHECK (periodicidade_dias > 0),
CONSTRAINT ck_plano_preco CHECK (valor >= 0));

-- ---------------------------------------------------------------------------------------------------------------------------------
CREATE UNIQUE INDEX uq_plano_nome_ativo
ON tb_plano (nm_plano)
WHERE fl_ativo;

-- ---------------------------------------------------------------------------------------------------------------------------------
INSERT INTO tb_plano (nm_plano, ds_plano, periodicidade_dias, valor, texto_banner)
VALUES ('Diamante' , 'Gestão completa da loja Shopee', 360,   900, 'Mais tempo para desenvolver sua loja com uma gestão contínua.'),
       ('Safira'   , 'Gestão completa da loja Shopee', 180,  1100, 'Uma gestão completa para evoluir com consistência.'),
       ('Esmeralda', 'Gestão completa da loja Shopee',  90,  1300, 'Comece a organizar e fortalecer sua presença na Shopee.'),
       ('Avulso'   , 'Diagnóstico inicial'           ,   7,   150, 'Descubra as prioridades da sua loja antes dos próximos passos.');


-- ============================================================
-- tb_plano_servico: serviços incluídos em cada plano
-- ============================================================
CREATE TABLE tb_plano_servico (
cd_plano bigint NOT NULL,
cd_servico bigint NOT NULL,
CONSTRAINT pk_plano_servico PRIMARY KEY (cd_plano, cd_servico),
CONSTRAINT fk_plano_servico_plano FOREIGN KEY (cd_plano) REFERENCES tb_plano (cd_plano),
CONSTRAINT fk_plano_servico_servico FOREIGN KEY (cd_servico) REFERENCES tb_servico (cd_servico));

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
('pendente', 'Contrato emitido e aguardando assinatura'),
('ativo', 'Contrato assinado e em vigência'),
('vencido', 'Contrato que atingiu o fim da vigência'),
('suspenso', 'Contrato com restrição que impede sua execução'),
('cancelado',  'Contrato cancelado e mantido para histórico'),
('inadimplente', 'Contrato suspenso por falta de pagamento');


-- ============================================================
-- tb_contrato
-- ============================================================
CREATE TABLE tb_contrato (
cd_contrato bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
cd_pessoa bigint NOT NULL,
cd_status smallint NOT NULL,
nm_plano varchar(100) NOT NULL,
ds_plano varchar(500),
vigencia daterange NOT NULL,
vl_bruto numeric(12,2) NOT NULL,
vl_desconto_lojas numeric(12,2) NOT NULL DEFAULT 0,
vl_desconto_manual numeric(12,2) NOT NULL DEFAULT 0,
vl_acrescimo numeric(12,2) NOT NULL DEFAULT 0,
vl_contrato numeric(12,2) NOT NULL,
ds_contrato varchar(500),
dt_cadastro timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
dt_atualizacao timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
CONSTRAINT fk_contrato_pessoa FOREIGN KEY (cd_pessoa) REFERENCES tb_pessoa (cd_pessoa),
CONSTRAINT fk_contrato_status FOREIGN KEY (cd_status) REFERENCES tb_contrato_status (cd_status),
CONSTRAINT uq_contrato_pessoa_contrato UNIQUE (cd_pessoa, cd_contrato),
CONSTRAINT ck_contrato_vigencia CHECK (NOT isempty(vigencia) AND NOT lower_inf(vigencia)),
CONSTRAINT ck_contrato_valores CHECK (vl_bruto >= 0
AND vl_desconto_lojas >= 0
AND vl_desconto_manual >= 0
AND vl_acrescimo >= 0
AND vl_contrato = vl_bruto - vl_desconto_lojas - vl_desconto_manual + vl_acrescimo
AND vl_contrato >= 0));

-- --------------------------------------------------------------------
CREATE INDEX ix_contrato_vigencia ON tb_contrato USING gist (vigencia);


-- ============================================================
-- tb_contrato_documento: contrato físico em .pdf
-- ============================================================
CREATE TABLE tb_contrato_documento (
cd_documento bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
cd_contrato bigint NOT NULL UNIQUE,
arquivo_pdf bytea NOT NULL,
dt_assinatura timestamptz NOT NULL,
dt_atualizacao timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
CONSTRAINT fk_documento_contrato FOREIGN KEY (cd_contrato) REFERENCES tb_contrato (cd_contrato),
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
-- tb_contato_status: status de interessados em planos
-- ============================================================
CREATE TABLE tb_contato_status (
cd_status smallint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
nm_status varchar(30) NOT NULL UNIQUE,
ds_status varchar(150) NOT NULL);

-- ---------------------------------------------------------
INSERT INTO tb_contato_status (nm_status, ds_status) VALUES
('pendente', 'Aguardando atendimento'),
('ativo', 'Convertido em cliente'),
('aguardando', 'Atendido; solicitou contato posterior'),
('sem contato', 'Não foi possível estabelecer contato'),
('desistência', 'Desistiu após o atendimento');

-- ============================================================
-- drop table tb_contato cascade: mensagens e interesse em planos
-- ============================================================
CREATE TABLE tb_contato (
cd_contato bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
cd_plano bigint,
cd_contrato bigint,
cd_status smallint NOT NULL,
nm_contato varchar(150) NOT NULL,
celular varchar(20) NOT NULL,
email varchar(150),
mensagem text,
dt_cadastro timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
dt_atualizacao timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
CONSTRAINT fk_contato_plano FOREIGN KEY (cd_plano) REFERENCES tb_plano (cd_plano),
CONSTRAINT fk_contato_contrato FOREIGN KEY (cd_contrato) REFERENCES tb_contrato (cd_contrato),
CONSTRAINT fk_contato_status FOREIGN KEY (cd_status) REFERENCES tb_contato_status (cd_status),
CONSTRAINT ck_contato_celular CHECK (btrim(celular) <> ''),
CONSTRAINT ck_contato_nome CHECK (btrim(nm_contato) <> ''));



-- ============================================================
-- tb_parcelas: parcelas de contratos
-- ============================================================
CREATE TABLE tb_parcelas (
cd_parcela bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
cd_contrato bigint NOT NULL,
nr_parcela integer NOT NULL,
dt_vencimento date NOT NULL,
vl_parcela numeric(12,2) NOT NULL,
vl_desconto numeric(12,2) NOT NULL DEFAULT 0,
dt_pagamento date,
vl_pago numeric(12,2),
CONSTRAINT fk_parcelas_contrato FOREIGN KEY (cd_contrato) REFERENCES tb_contrato (cd_contrato),
CONSTRAINT uq_parcelas_contrato_numero UNIQUE (cd_contrato, nr_parcela),
CONSTRAINT ck_parcelas_numero CHECK (nr_parcela > 0),
CONSTRAINT ck_parcelas_valores CHECK (vl_parcela >= 0 AND vl_desconto BETWEEN 0 AND vl_parcela AND (vl_pago IS NULL OR vl_pago >= 0)),
CONSTRAINT ck_parcelas_pagamento CHECK ((dt_pagamento IS NULL) = (vl_pago IS NULL)));


-- ============================================================
-- tb_encargo_atraso: politica de multas em caso de atrasos
-- ============================================================
CREATE TABLE tb_encargo_atraso (
cd_encargo bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
vigencia daterange NOT NULL,
percentual_multa numeric(5,2) NOT NULL,
juros_mensal numeric(5,2) NOT NULL,
dias_carencia integer NOT NULL DEFAULT 0,
dias_painel integer NOT NULL DEFAULT 3,
dias_suspensao integer NOT NULL DEFAULT 10,
CONSTRAINT ck_encargo_vigencia CHECK (NOT isempty(vigencia) AND NOT lower_inf(vigencia)),
CONSTRAINT ck_encargo_percentuais CHECK (percentual_multa BETWEEN 0 AND 100 AND juros_mensal BETWEEN 0 AND 100),
CONSTRAINT ck_encargo_dias CHECK (dias_carencia >= 0 AND dias_painel >= 0 AND dias_suspensao >= dias_painel),
CONSTRAINT ex_encargo_vigencia EXCLUDE USING gist (vigencia WITH &&));

-- -------------------------------------------------------------------------------------------
INSERT INTO tb_encargo_atraso (vigencia, percentual_multa, juros_mensal, dias_carencia, dias_painel, dias_suspensao)
VALUES (daterange(DATE '2026-09-26', NULL, '[)'), 2, 1, 0, 3, 10);

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
-- tb_contrato_loja: lojas cobertas por cada contrato
-- ============================================================
CREATE TABLE tb_contrato_loja (
cd_contrato bigint NOT NULL,
cd_loja bigint NOT NULL,
cd_pessoa bigint NOT NULL,
CONSTRAINT pk_contrato_loja PRIMARY KEY (cd_contrato, cd_loja),
CONSTRAINT fk_contrato_loja_contrato FOREIGN KEY (cd_pessoa, cd_contrato)
REFERENCES tb_contrato (cd_pessoa, cd_contrato),
CONSTRAINT fk_contrato_loja_loja FOREIGN KEY (cd_pessoa, cd_loja)
REFERENCES tb_loja (cd_pessoa, cd_loja));



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


-- ============================================================
-- tb_usuario - drop table tb_usuario cascade
-- ============================================================
CREATE TABLE tb_usuario (
cd_usuario bigint GENERATED ALWAYS AS IDENTITY (MINVALUE 0 START WITH 0) PRIMARY KEY,
cd_pessoa bigint NOT NULL UNIQUE,
cd_nivel smallint NOT NULL,
login varchar(100) NOT NULL UNIQUE,
senha_hash text NOT NULL,
fl_ativo boolean NOT NULL DEFAULT true,
dt_atualizacao timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
CONSTRAINT fk_usuario_pessoa FOREIGN KEY (cd_pessoa) REFERENCES tb_pessoa (cd_pessoa),
CONSTRAINT fk_usuario_nivel FOREIGN KEY (cd_nivel) REFERENCES tb_usuario_nivel (cd_nivel),
CONSTRAINT ck_usuario_login CHECK (btrim(login) <> ''),
CONSTRAINT ck_usuario_senha CHECK (btrim(senha_hash) <> ''));

-- --------------------------------------------------------------------------------------------------------------------------------
INSERT INTO tb_usuario (cd_pessoa, cd_nivel, login, senha_hash, fl_ativo) values
(0, 0, 'hilaneto', 'scrypt:32768:8:1$4mjPXrerf5DlpXpO$f8a99dcefa0f79ae3731df309f3e64eb24c34d2d252e79bf8ff4c22321e79b26d1238145047ef14d8fd23c381e249b17d2886e9e1256a9cf6bf57576480dcc8f', true),
(1, 1, 'juvenal' , 'scrypt:32768:8:1$zebpNPKMDH6Ck8IR$97ec87e2c1f9f8a67192ef784f86dab8223eb8e5570764ae86cd2cafd557ae1278eb0a9ab8fbc4c0a16c1df6703ae50815d765989e0ca465ff7a35bc5d820ec0', true);



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
cd_usuario bigint,
cd_evento smallint NOT NULL,
login_informado varchar(100),
fl_sucesso boolean NOT NULL DEFAULT true,
ip_acesso inet,
dt_evento timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
CONSTRAINT fk_logusuario_usuario FOREIGN KEY (cd_usuario) REFERENCES tb_usuario (cd_usuario),
CONSTRAINT fk_logusuario_evento FOREIGN KEY (cd_evento) REFERENCES tb_evento_log (cd_evento));



-- ===========================================================
-- vw_cobranca_proximos: 1. Vence hoje ou nos próximos 3 dias
-- ===========================================================
CREATE OR REPLACE VIEW vw_cobranca_proximos AS
SELECT p.cd_parcela, p.cd_contrato, p.nr_parcela, pe.nm_pessoa, pe.telefone, pe.email, c.nm_plano,
p.dt_vencimento, p.dt_vencimento - CURRENT_DATE AS dias_para_vencer, p.vl_parcela - p.vl_desconto AS vl_a_pagar
FROM tb_parcelas p JOIN tb_contrato c ON c.cd_contrato = p.cd_contrato
JOIN tb_contrato_status st ON st.cd_status = c.cd_status
JOIN tb_pessoa pe ON pe.cd_pessoa = c.cd_pessoa
WHERE p.dt_pagamento IS NULL
AND p.dt_vencimento BETWEEN CURRENT_DATE AND CURRENT_DATE + 3
AND st.nm_status IN ('ativo', 'inadimplente');


-- ========================================================================
-- vw_cobranca_vencidos: 2. Vencidas de 1 a 3 dias: acompanhamento inicial
-- ========================================================================
CREATE OR REPLACE VIEW vw_cobranca_vencidos AS
SELECT p.cd_parcela, p.cd_contrato, p.nr_parcela, pe.nm_pessoa, pe.telefone, pe.email, c.nm_plano,
p.dt_vencimento, CURRENT_DATE - p.dt_vencimento AS dias_atraso, p.vl_parcela - p.vl_desconto AS vl_original
FROM tb_parcelas p JOIN tb_contrato c ON c.cd_contrato = p.cd_contrato
JOIN tb_contrato_status st ON st.cd_status = c.cd_status
JOIN tb_pessoa pe ON pe.cd_pessoa = c.cd_pessoa
WHERE p.dt_pagamento IS NULL
AND p.dt_vencimento BETWEEN CURRENT_DATE - 3 AND CURRENT_DATE - 1
AND st.nm_status <> 'cancelado';


-- ==========================================================================
-- vw_cobranca_inadimplentes: 3. Mais de 3 dias: cobrança com multa e juros
-- ==========================================================================
CREATE OR REPLACE VIEW vw_cobranca_inadimplentes AS
SELECT p.cd_parcela, p.cd_contrato, p.nr_parcela, pe.nm_pessoa, pe.telefone, pe.email, c.nm_plano, st.nm_status AS status_contrato,
p.dt_vencimento, CURRENT_DATE - p.dt_vencimento AS dias_atraso, p.vl_parcela - p.vl_desconto AS vl_original,
ROUND((p.vl_parcela - p.vl_desconto) * e.percentual_multa / 100, 2) AS vl_multa,
ROUND((p.vl_parcela - p.vl_desconto) * e.juros_mensal / 100 * (CURRENT_DATE - p.dt_vencimento - e.dias_carencia) / 30, 2) AS vl_juros, 
CURRENT_DATE - p.dt_vencimento > e.dias_suspensao AS avaliar_suspensao
FROM tb_parcelas p JOIN tb_contrato c ON c.cd_contrato = p.cd_contrato
JOIN tb_contrato_status st ON st.cd_status = c.cd_status
JOIN tb_pessoa pe ON pe.cd_pessoa = c.cd_pessoa
JOIN tb_encargo_atraso e ON e.vigencia @> p.dt_vencimento
WHERE p.dt_pagamento IS NULL
AND CURRENT_DATE - p.dt_vencimento > e.dias_painel
AND CURRENT_DATE - p.dt_vencimento > e.dias_carencia
AND st.nm_status <> 'cancelado';


-- ==========================================================================
-- vw_contatos_pendentes: Contatos pendentes
-- ==========================================================================
CREATE VIEW vw_contatos_pendentes AS
SELECT c.cd_contato, c.nm_contato, c.email, c.celular, c.mensagem, p.nm_plano, c.dt_cadastro, 
CURRENT_DATE - c.dt_cadastro::date AS dias_aguardando
FROM tb_contato c
LEFT JOIN tb_plano p ON p.cd_plano = c.cd_plano
WHERE c.cd_status = 1;


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
-- pr_reajustar_plano: Contatos pendentes
-- ==========================================================================
CREATE OR REPLACE FUNCTION fn_nova_versao_plano(
    p_cd_plano bigint,
    p_nm_plano varchar(100) DEFAULT NULL,
    p_ds_plano varchar(500) DEFAULT NULL,
    p_periodicidade_dias integer DEFAULT NULL,
    p_valor numeric(12,2) DEFAULT NULL,
    p_texto_banner varchar(100) DEFAULT NULL)
    
RETURNS bigint
LANGUAGE plpgsql
AS $$
DECLARE
    v_anterior tb_plano%ROWTYPE;
    v_cd_novo bigint;
BEGIN
    SELECT * INTO v_anterior
    FROM tb_plano
    WHERE cd_plano = p_cd_plano
    FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Plano % não encontrado', p_cd_plano;
    END IF;

    IF NOT v_anterior.fl_ativo THEN
        RAISE EXCEPTION 'Plano % já está inativo', p_cd_plano;
    END IF;

    IF p_nm_plano IS NULL AND p_ds_plano IS NULL
       AND p_periodicidade_dias IS NULL AND p_valor IS NULL
       AND p_texto_banner IS NULL THEN
        RAISE EXCEPTION 'Informe ao menos um campo para a nova versão';
    END IF;

    UPDATE tb_plano
    SET fl_ativo = false
    WHERE cd_plano = p_cd_plano;

    INSERT INTO tb_plano
        (nm_plano, ds_plano, periodicidade_dias, valor,
         texto_banner, fl_ativo)
    VALUES
        (COALESCE(p_nm_plano, v_anterior.nm_plano),
         COALESCE(p_ds_plano, v_anterior.ds_plano),
         COALESCE(p_periodicidade_dias, v_anterior.periodicidade_dias),
         COALESCE(p_valor, v_anterior.valor),
         COALESCE(p_texto_banner, v_anterior.texto_banner),
         true)
    RETURNING cd_plano INTO v_cd_novo;

    INSERT INTO tb_plano_servico (cd_plano, cd_servico)
    SELECT v_cd_novo, cd_servico
    FROM tb_plano_servico
    WHERE cd_plano = p_cd_plano;

    RETURN v_cd_novo;
END;
$$;

