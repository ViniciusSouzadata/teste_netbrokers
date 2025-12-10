/* -------------------- CRIAÇÃO DAS TABELAS BASE -------------------- */
CREATE TABLE clientes (
    id_cliente VARCHAR PRIMARY KEY,
    nome TEXT,
    sexo CHAR(2),
    data_nasc DATE,
    cidade TEXT,
    uf CHAR(2),
    data_cadastro DATE
);

CREATE TABLE produtos (
    id_sku VARCHAR PRIMARY KEY,
    categoria_n1 TEXT,
    categoria_n2 TEXT,
    marca TEXT,
    preco_lista NUMERIC(10,2)
);

CREATE TABLE pedidos (
    id_pedido VARCHAR PRIMARY KEY,
    data_pedido DATE,
    id_cliente VARCHAR REFERENCES clientes(id_cliente),
    canal TEXT,
    uf CHAR(2),
    status TEXT
);

CREATE TABLE itens_pedido (
    id_pedido VARCHAR REFERENCES pedidos(id_pedido),
    seq_item INTEGER,
    id_sku VARCHAR REFERENCES produtos(id_sku),
    qtde INTEGER,
    valor_unit NUMERIC(10,2),
    desconto_valor NUMERIC(10,2),
    cupom TEXT
);

/* -------------------- IMPORTAÇÃO DOS ARQUIVOS CSV -------------------- */
COPY clientes(id_cliente, nome, sexo, data_nasc, cidade, uf, data_cadastro)
FROM 'C:\teste_dbex\clientes.csv' DELIMITER ',' CSV HEADER;

COPY produtos(id_sku, categoria_n1, categoria_n2, marca, preco_lista)
FROM 'C:\teste_dbex\produtos.csv' DELIMITER ',' CSV HEADER;

COPY pedidos(id_pedido, data_pedido, id_cliente, canal, uf, status)
FROM 'C:\teste_dbex\pedidos.csv' DELIMITER ',' CSV HEADER;

COPY itens_pedido(id_pedido, seq_item, id_sku, qtde, valor_unit, desconto_valor, cupom)
FROM 'C:\teste_dbex\itens_pedido.csv' DELIMITER ',' CSV HEADER;

/* -------------------- DIMENSÕES -------------------- */
-- Dimensão Cliente
CREATE TABLE dim_cliente AS
SELECT
    id_cliente,
    sexo,
    uf,
    DATE_PART('year', AGE(data_nasc)) AS idade_atual,
    CASE
        WHEN AGE(data_nasc) < INTERVAL '18 years' THEN '0-17'
        WHEN AGE(data_nasc) < INTERVAL '25 years' THEN '18-24'
        WHEN AGE(data_nasc) < INTERVAL '35 years' THEN '25-34'
        WHEN AGE(data_nasc) < INTERVAL '45 years' THEN '35-44'
        WHEN AGE(data_nasc) < INTERVAL '55 years' THEN '45-54'
        WHEN AGE(data_nasc) < INTERVAL '65 years' THEN '55-64'
        ELSE '65+'
    END AS faixa_etaria
FROM clientes;

-- Dimensão Produto
CREATE TABLE dim_produto AS
SELECT
    id_sku,
    categoria_n1,
    categoria_n2,
    marca
FROM produtos;

/* -------------------- FATO ITEM -------------------- */
CREATE TABLE fato_item AS
SELECT
    ip.id_pedido,
    ip.id_sku,
    ip.seq_item,
    ip.qtde,
    ip.valor_unit,
    ip.desconto_valor,
    (ip.valor_unit - ip.desconto_valor) * ip.qtde AS valor_liquido_item
FROM itens_pedido ip
JOIN pedidos p ON p.id_pedido = ip.id_pedido;

/* -------------------- FATO PEDIDO -------------------- */
CREATE TABLE fato_pedido AS
SELECT
    p.id_pedido,
    p.data_pedido,
    p.id_cliente,
    p.canal,
    p.uf AS uf_pedido,
    CASE p.uf
        WHEN 'AC' THEN 'Acre'
        WHEN 'AL' THEN 'Alagoas'
        WHEN 'AP' THEN 'Amapá'
        WHEN 'AM' THEN 'Amazonas'
        WHEN 'BA' THEN 'Bahia'
        WHEN 'CE' THEN 'Ceará'
        WHEN 'DF' THEN 'Distrito Federal'
        WHEN 'ES' THEN 'Espírito Santo'
        WHEN 'GO' THEN 'Goiás'
        WHEN 'MA' THEN 'Maranhão'
        WHEN 'MT' THEN 'Mato Grosso'
        WHEN 'MS' THEN 'Mato Grosso do Sul'
        WHEN 'MG' THEN 'Minas Gerais'
        WHEN 'PA' THEN 'Pará'
        WHEN 'PB' THEN 'Paraíba'
        WHEN 'PR' THEN 'Paraná'
        WHEN 'PE' THEN 'Pernambuco'
        WHEN 'PI' THEN 'Piauí'
        WHEN 'RJ' THEN 'Rio de Janeiro'
        WHEN 'RN' THEN 'Rio Grande do Norte'
        WHEN 'RS' THEN 'Rio Grande do Sul'
        WHEN 'RO' THEN 'Rondônia'
        WHEN 'RR' THEN 'Roraima'
        WHEN 'SC' THEN 'Santa Catarina'
        WHEN 'SP' THEN 'São Paulo'
        WHEN 'SE' THEN 'Sergipe'
        WHEN 'TO' THEN 'Tocantins'
        ELSE 'Não identificado'
    END AS estado_nome,
    p.status,
    SUM(CASE WHEN p.status IN ('concluido', 'aberto') THEN ip.qtde * ip.valor_unit ELSE 0 END) AS valor_bruto,
    SUM(CASE WHEN p.status IN ('concluido', 'aberto') THEN ip.desconto_valor * ip.qtde ELSE 0 END) AS total_descontos,
    SUM(CASE WHEN p.status IN ('concluido', 'aberto') THEN (ip.valor_unit - ip.desconto_valor) * ip.qtde ELSE 0 END) AS valor_liquido,
    SUM(ip.qtde) AS qtde_itens
FROM pedidos p
JOIN itens_pedido ip ON ip.id_pedido = p.id_pedido
GROUP BY p.id_pedido, p.data_pedido, p.id_cliente, p.canal, p.uf, p.status;

/* -------------------- TABELA DE COHORT -------------------- */
CREATE TABLE cohort_retorno AS
WITH primeira_compra AS (
    SELECT id_cliente, MIN(DATE_TRUNC('month', data_pedido)) AS mes_entrada
    FROM fato_pedido
    GROUP BY id_cliente
),
compras_com_mes_relativo AS (
    SELECT
        fp.id_cliente,
        DATE_TRUNC('month', fp.data_pedido) AS mes_compra,
        pc.mes_entrada,
        EXTRACT(MONTH FROM AGE(DATE_TRUNC('month', fp.data_pedido), pc.mes_entrada)) +
        12 * EXTRACT(YEAR FROM AGE(DATE_TRUNC('month', fp.data_pedido), pc.mes_entrada)) AS mes_relativo
    FROM fato_pedido fp
    JOIN primeira_compra pc ON fp.id_cliente = pc.id_cliente
),
clientes_por_cohort AS (
    SELECT mes_entrada, COUNT(DISTINCT id_cliente) AS total_clientes
    FROM primeira_compra
    GROUP BY mes_entrada
)
SELECT
    c.mes_entrada,
    c.mes_relativo,
    COUNT(DISTINCT c.id_cliente) AS clientes_ativos,
    ROUND(COUNT(DISTINCT c.id_cliente) * 100.0 / cp.total_clientes, 2) AS pct_retorno
FROM compras_com_mes_relativo c
JOIN clientes_por_cohort cp ON c.mes_entrada = cp.mes_entrada
GROUP BY c.mes_entrada, c.mes_relativo, cp.total_clientes
ORDER BY c.mes_entrada, c.mes_relativo;

/* -------------------- VIEWS DE KPI -------------------- */
CREATE OR REPLACE VIEW vw_kpis_diario AS
SELECT
    fp.data_pedido::date AS data,
    fp.canal,
    fp.uf_pedido AS uf,
    COUNT(DISTINCT fp.id_pedido) AS pedidos,
    SUM(fp.qtde_itens) AS itens,
    SUM(fp.valor_liquido) AS receita_liquida,
    SUM(CASE WHEN fp.status IN ('cancelado', 'fraude') THEN 1 ELSE 0 END)::decimal
        / NULLIF(COUNT(DISTINCT fp.id_pedido), 0) * 100 AS pct_cancelamento,
    CASE
        WHEN COUNT(DISTINCT fp.id_pedido) = 0 THEN 0
        ELSE SUM(fp.valor_liquido) / COUNT(DISTINCT fp.id_pedido)
    END AS ticket_medio
FROM fato_pedido fp
GROUP BY 1, 2, 3;

CREATE OR REPLACE VIEW vw_kpis_mensal AS
WITH base AS (
    SELECT
        id_pedido,
        TO_CHAR(data_pedido, 'YYYY-MM') AS ano_mes,
        canal,
        uf_pedido AS uf,
        valor_liquido,
        status
    FROM fato_pedido
)
SELECT
    ano_mes,
    canal,
    uf,
    COUNT(DISTINCT id_pedido) AS pedidos,
    SUM(valor_liquido) AS receita_liquida,
    SUM(CASE WHEN status IN ('cancelado', 'fraude') THEN 1 ELSE 0 END)::decimal
        / NULLIF(COUNT(DISTINCT id_pedido), 0) * 100 AS pct_cancelamento,
    CASE
        WHEN COUNT(DISTINCT id_pedido) = 0 THEN 0
        ELSE SUM(valor_liquido) / COUNT(DISTINCT id_pedido)
    END AS ticket_medio
FROM base
GROUP BY 1, 2, 3;

/* -------------------- MATERIALIZAÇÃO DAS VIEWS -------------------- */
CREATE TABLE kpis_diario_cache AS SELECT * FROM vw_kpis_diario;
CREATE TABLE kpis_mensal_cache AS SELECT * FROM vw_kpis_mensal;