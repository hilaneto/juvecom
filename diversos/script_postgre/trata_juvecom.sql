

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
select * from tb_relacao;
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
select * from tb_pessoa_relacao;
select * from tb_relacao;

-- -------------------------------------
select * from tb_contrato;
select * from tb_contrato_documento;
select * from tb_contrato_modelo;
-- -------------------------------------

select * from tb_pessoa
select * from tb_cliente

select * from tb_usuario_nivel;



select * from vw_cobranca_inadimplentes;
select * from vw_contatos_pendentes;
select * from vw_usuario;

-- ===================================================================================================================


select * from tb_pessoa a inner join tb_usuario b
on a.cd_pessoa = b.cd_pessoa



-- Pessoa ------------------------------------
-- --------------------------------------------------------------------------------------------------------------------------------------------------------
INSERT INTO tb_pessoa (tp_pessoa, nm_pessoa, cpf_cnpj, telefone, email, dados, fl_ativo, dt_cadastro, dt_atualizacao) values
('F', 'José Hilário Alves Neto', '06478701859', '11 9 7666-0826', 'hilaneto@yahoo.com.br', '{}'::jsonb, true, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
('F', 'Juvenal Pereira de Souza', '12345678195', '11 98738-5695', 'variedadesjps@gmail.com'     , '{}'::jsonb, true, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
('J', 'JPS - Juvaecom Promoções', '22144785142369', '11 98738-5695', 'variedadesjps@gmail.com'     , '{}'::jsonb, true, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP);

-- pessoa_relacao ------------------------------
INSERT INTO tb_pessoa_relacao (cd_pessoa, cd_relacao) values
(0, 1), (0, 2),
(1, 1), (1, 2);

-- Importação de Pessoas.xlsx para public.tb_pessoa
INSERT INTO tb_pessoa (tp_pessoa, nm_pessoa, cpf_cnpj, telefone, email, dados) VALUES
('F', 'Jaqueline de Sousa Ribeiro', '99848422234', '48984840191', 'Jacksousa1989@gmail.com', '{"endereco": "Rua manoel medeiros borges", "numero": "1607", "cidade": "São José", "uf": "SC"}'::jsonb),
('F', 'ALEXANDRE BURMAS DA SILVA SILVA', '12512178854', '1992065245', '/alexandreburmas@gmail.com', '{"endereco": "Avenida Cassandoca", "numero": "757", "uf": "SP"}'::jsonb),
('F', 'Aline de Sousa Alves Laise', '39499679820', '11974898031', 'alishop.alishop.2020@gmail.com', '{"endereco": "Rua Valdecir Ferreira dos Reis", "numero": "350", "cidade": "Suzano", "uf": "SP"}'::jsonb),
('J', 'ANDREA DE BARROS SANTOS', '65084601000175', '11959605451', 'arjn04@gmail.com', '{"endereco": "Rua Dos Cravos", "numero": "51"}'::jsonb),
('J', 'Camila Paganotto Ltda', '29555924000136', '45999484930', 'camilapaganotto@hotmail.com', '{"endereco": "Rua 1° de Maio", "numero": "1630", "cidade": "Toledo", "uf": "PR", "cep": "85909010"}'::jsonb),
('J', 'Cleber Jacinto', '50166991000155', '11991642657', 'cl eber.j acint o@yahoo.com', '{"endereco": "Rua Cascavel", "cidade": "Itaquaquecetuba", "uf": "SP", "cep": "08575680"}'::jsonb),
('J', 'Luanna Comercio de Bijuterias Ltda', '19320598000205', '81991896753', 'diegopita1@hotmail.com', '{"endereco": "Rua José osti", "numero": "284", "cidade": "Neves Paulista", "uf": "SP"}'::jsonb),
('J', 'Jefferson Toffoli Lelis', '65648940000137', '34988560330', 'comercial@toffbr.com.br', '{"endereco": "Rua Itumbiara", "numero": "598", "cidade": "Uberlandia", "uf": "MG", "cep": "38400617"}'::jsonb),
('J', 'Josy Rafaela dos Santos Fazan', '65846714000160', '12988456216', 'josy-rafaela@hotmail.com', '{"endereco": "Rua Pedro Pomar", "cidade": "São Jose dos Campos", "uf": "SP", "cep": "12232471"}'::jsonb),
('J', 'TRI FORMA 3D', '68920193000132', '51991995352', 'KATHLEENCARINE18@GMAIL', '{"endereco": "RUA CELINA VIEIRA PEIXOTO", "numero": "142", "cidade": "Tijucas", "uf": "SC"}'::jsonb),
('J', 'Aline Barbosa Souza Furtuoso', '61586175000171', '31995957347', 'lilisouzas@yahoo.com.br', '{"cidade": "Itaverava", "uf": "MG", "cep": "36440000"}'::jsonb),
('F', 'Luci Rodrigues da Costa', '85960045567', '62994690440', '/luciarodriguesdac@gmail.com,', '{"endereco": "Rua patriarca qd 16", "numero": "lt07", "cidade": "Goiania", "uf": "GO", "cep": "74453610"}'::jsonb),
('J', 'MILENAR MADEIRAS LTDA', '68134578000174', '11917446684', 'keller.contato@gmail.com,', '{"endereco": "Rua Talofitos", "cidade": "São Paulo", "uf": "SP", "cep": "02945170"}'::jsonb),
('F', 'Natalia Daudt Porto', '43273189819', '11982089853', 'trendseyewear.sac@gmail.com', '{"endereco": "Rua Moisés Justino", "cidade": "São Paulo", "uf": "SP", "cep": "03562000"}'::jsonb),
('J', 'Eskinão - Utilidades, móveis e decoração', '29891871000124', '13997717160', 'Eskinao.financeiro@gmail.com', '{"endereco": "Avenida Eva Pereira dos Santos", "numero": "215", "cidade": "Santos", "uf": "SP", "cep": "11495005"}'::jsonb),
('J', 'ESCADAO COM PECAS ELETRICAS P/ AUTOS LTDA', '02124962000188', '11981940851', 'rodrigo@escadao.com.br', '{"endereco": "RUA SILVEIRA CAMPOS", "numero": "447", "cidade": "São Paulo", "uf": "SP", "cep": "01541030"}'::jsonb),
('J', 'Fábricapet975/ Sandra', '30401088000114', '14997725758', 'fabricadopet@gmail.com', '{"endereco": "Avenida Custódio Soares da Silva", "cidade": "Cafelandia", "uf": "SP", "cep": "16503042"}'::jsonb),
('J', 'LOJA DOT RIOMAR', '51312652000100', '819995676427', 'financeirojadot@gmail.com', '{"cidade": "Recife", "uf": "PE"}'::jsonb),
('J', 'COMERCI AL REI DO TNT LTDA', '37802034000100', '11981587705', 't hi agonsil va @terra.com.br', '{"endereco": "Rua Mogi Mirim", "cidade": "São Paulo", "uf": "SP", "cep": "03187040"}'::jsonb),
('J', 'Vicya Professional', '62058883000148', '1130735447', 'vicyacosmeticos@gmail.com', '{"endereco": "4180081", "cidade": "São Paulo", "uf": "SP"}'::jsonb),
('F', 'Waléria Cristina de Souza', '00220931178', '62982251329', 'waleriac1982@gmail.com', '{"endereco": "Rua C-48", "cidade": "Goiania", "uf": "GO", "cep": "74305280"}'::jsonb),
('J', 'Germano Group', '06817144000144', '(11) 915933151', 'germanogroupp@gmail.com', '{"endereco": "Avenida dos Autonomistas", "cidade": "Osasco", "uf": "SP", "cep": "06090020"}'::jsonb),
('J', 'Amanda Cristina de Oliveira', '43406970000122', '(19)996246099', 'amanda.cristina278@gmail.com', '{"endereco": "Rua Cristiano Osório", "cidade": "São Paulo", "uf": "SP"}'::jsonb);


INSERT INTO public.tb_cliente (cd_pessoa, nm_responsavel)
values (4, 'ALEXANDRE BURMAS DA SILVA SILVA'),
(13, 'Aline Barbosa Souza Furtuoso'),
(5, 'Aline de Sousa Alves Laise'),
(25, 'Amanda Cristina de Oliveira'),
(6, 'ANDREA DE BARROS SANTOS'),
(7, 'Camila Paganotto Ltda'),
(8, 'Cleber Jacinto'),
(21, 'COMERCI AL REI DO TNT LTDA'),
(18, 'ESCADAO COM PECAS ELETRICAS P/ AUTOS LTDA'),
(17, 'Eskinão - Utilidades, móveis e decoração'),
(19, 'Fábricapet975/ Sandra'),
(24, 'Germano Group'),
(3, 'Jaqueline de Sousa Ribeiro'),
(10, 'Jefferson Toffoli Lelis'),
(11, 'Josy Rafaela dos Santos Fazan'),
(20, 'LOJA DOT RIOMAR'),
(9, 'Luanna Comercio de Bijuterias Ltda'),
(14, 'Luci Rodrigues da Costa'),
(15, 'MILENAR MADEIRAS LTDA'),
(16, 'Natalia Daudt Porto'),
(12, 'TRI FORMA 3D'),
(22, 'Vicya Professional'),
(23, 'Waléria Cristina de Souza');



select a.nm_pessoa, b.nm_responsavel  from tb_pessoa a inner join tb_cliente b 
on a.cd_pessoa  = b.cd_pessoa
left join tb_loja c
on b.cd_cliente  = c.cd_cliente
where a.nm_pessoa = b.nm_responsavel


select * from tb_pessoa
order by dt_atualizacao desc;

select * from tb_cliente
order by dt_atualizacao desc;

select * from tb_loja;
shop_id, url_loja

INSERT INTO tb_loja (cd_cliente, nm_loja, url_loja)
values (1,'ALEXANDRE','https://br.shp.ee/zpNUATDo'), 
(2,'Aline','Visual Fashion 2'),
(3,'Alinesa','https://www.mercadolivre.com.br/pagina/alishop2405'), 
(4,'Amanda','https://br.shp.ee/BaLeRaBQ'),
(5,'ANDREA','https://shopee.com.br/ikep7vralb'),
(6,'Camila','https://br.shp.ee/TydBkyVN'),
(7,'Cleber','https://br.shp.ee/53Lk2auN'),
(8,'Com Rei','Rei dotnt'),
(9,'ESCADAO','https://shopee.com.br/shop/1557529648'), 
(10,'Eskinão','https://shopee.com.br/user/account/profile'), 
(11,'Fábricapet','https://br.shp.ee/qS8DVBS'),
(12,'Germano Group','https://br.shp.ee/6RVCrbWS'),
(13,'Jaqueline','https://br.shp.ee/qk8kgpVP'), 
(14,'Jefferson','https://br.shp.ee/KjkMTgbJ'),
(15,'Josy','https://s.shopee.com.br/20vsHau6y2'), 
(16,'LOJA RIOMAR','2acjcdvzgv'),
(17,'Luanna Com','https://br.shp.ee/qvXgC5Zz'), 
(18,'Luci','https://br.shp.ee/u5sGTPsg'),
(19,'MILENAR','https://shopee.com.br'), 
(20,'Natalia','https://shopee.com.br/shop/1130492484'),
(21,'TRI FORMA','https://seller.shopee.com.br/portal/settings/shop/profile'), 
(22,'Vicya','https://br.shp.ee/TuNsZiAs'),
(23,'Waléria','https://br.shp.ee/WanJhV8q'); 

select * from tb_pessoa a inner join tb_cliente b
on a.cd_pessoa = b.cd_pessoa
left join tb_loja c
on b.cd_cliente = c.cd_cliente
where a.cpf_cnpj = '02124962000188'



select a.cd_pessoa, a.nm_pessoa , b.nm_responsavel  from tb_pessoa a inner join tb_cliente b
on a.cd_pessoa = b.cd_pessoa
where a.cpf_cnpj = '68134578000174'

tb_pessoa_relacao b
on a.cd_pessoa  = b.cd_pessoa
left join tb_loja c
on a.
where b.cd_relacao = 1

select DATE_TRUNC('month', dt_atualizacao)::DATE, dt_atualizacao::time from tb_pessoa
where cpf_cnpj in ('61586175000171','12345678195','22144785142369')

select * from tb_pessoa
where dt_atualizacao::DATE = '2026-10-15'

select * from tb_pessoa
order by nm_pessoa




-- Usuários -----------------------------------
INSERT INTO tb_usuario (cd_pessoa, cd_nivel, login, senha_hash, fl_ativo) values
(0, 0, 'hilaneto', 'scrypt:32768:8:1$4mjPXrerf5DlpXpO$f8a99dcefa0f79ae3731df309f3e64eb24c34d2d252e79bf8ff4c22321e79b26d1238145047ef14d8fd23c381e249b17d2886e9e1256a9cf6bf57576480dcc8f', true),
(1, 1, 'juvenal' , 'scrypt:32768:8:1$zebpNPKMDH6Ck8IR$97ec87e2c1f9f8a67192ef784f86dab8223eb8e5570764ae86cd2cafd557ae1278eb0a9ab8fbc4c0a16c1df6703ae50815d765989e0ca465ff7a35bc5d820ec0', true);

select * from tb_usuario;

SELECT cd_relacao, nm_relacao
FROM tb_relacao
ORDER BY cd_relacao;

-- CONTATOS -----------------------------------
select * from tb_contato;
select * from tb_contato_conversa;
select * from tb_contato_status;

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

