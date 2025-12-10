# 📊 Case Técnico Netbrokers

## ✨ Visão Geral

Este projeto tem como objetivo construir um sistema de análise de vendas completo utilizando **PostgreSQL** para modelagem de dados, **Power BI** para visualização dos KPIs e **Python** para análises avançadas com foco em comportamento do cliente e desempenho de produtos.

---

## 📂 ETL e Modelagem no PostgreSQL

### Esquema Estrela Criado:

- **Fato Pedido**: uma linha por pedido
- **Fato Item**: uma linha por item
- **Dim Cliente**: id_cliente, idade, faixa etária, UF
- **Dim Produto**: id_sku, categoria_n1, categoria_n2, marca

### Principais Cálculos no SQL:
- **valor_bruto**: qtde * valor_unit
- **valor_liquido_item**: (valor_unit - desconto_valor) * qtde
- **valor_liquido_pedido**: soma do valor_liquido_item
- **qtde_itens** por pedido
- **% cancelamento** considerando status 'cancelado' e 'fraude'

### Criação das Views:
- `vw_kpis_diario` e `vw_kpis_mensal` com:
  - Receita Líquida
  - Nº Pedidos
  - Ticket Médio
  - % Cancelamento
  - Segmentação por Canal e UF

> ⚠️ **Nota**: as views se mostraram pesadas para atualização no Power BI, por isso foram **materializadas** em tabelas cache:
> `kpis_diario_cache` e `kpis_mensal_cache`

git add images/C:\teste_dbex\modelo_base.sql
git commit -m "modelo sql"
git push origin main

![Modelo sql do projeo](C:\teste_dbex\modelo_base.sql)

---

## 🔍 Tabela Especial: Cohort de Retorno

Criada no PostgreSQL com base em:
- Primeiro mês de compra por cliente (`mes_entrada`)
- Mês de cada nova compra (`mes_compra`)
- Cálculo do `mes_relativo` (M0, M1, ...)
- Percentual de retorno por cohort

> Resultado usado no Power BI em visual de matriz com linhas = mes_entrada e colunas = mes_relativo

---

## 📈 Power BI - Visualizações Criadas

### Página 1: Visão Geral
- Filtros: Mês, Canal, UF
- KPIs: Receita, Pedidos, Ticket Médio, % Cancelamento
- Gráficos:
  - Receita Mensal
  - Pedidos por Categoria
  - Receita por Canal

### Página 2: Análise por Produto
- Pedidos por Marca
- Receita e Desconto por Produto
- Faixa de Desconto x Receita

### Página 3: Cohort
- Matriz com % de Retorno por Mês Relativo
- Filtro de Mês de Entrada

> ✏️ O background foi prototipado no **Figma** e importado como imagem

---

## 📊 Medidas DAX Utilizadas

```DAX
Pct_Retorno_ajustado = MAX(cohort_retorno[pct_retorno])
```
> Usado na matriz de cohort, traz a % de retorno de cada mês relativo

```DAX
Percentual_Desconto =
DIVIDE(
    SUM(f_item[desconto_valor]),
    SUM(f_item[valor_unit]),
    0
)
```
> Mostra % de desconto aplicado por SKU, usado em gráfico de produto

```DAX
Qtd_Pedidos_por_Marca =
CALCULATE(
    DISTINCTCOUNT(f_item[id_pedido]),
    ALLEXCEPT(d_produto, d_produto[marca])
)
```
> Quantidade de pedidos distintos por marca, usado em gráfico de barras

```DAX
Total_Bruto =
SUMX(
    f_item,
    f_item[valor_unit] * f_item[qtde]
)
```

```DAX
Total_Líquida =
SUMX(
    f_item,
    (f_item[valor_unit] - f_item[desconto_valor]) * f_item[qtde]
)
```

```DAX
Total_Desconto =
SUMX(
    f_item,
    f_item[desconto_valor] * f_item[qtde]
)
```
> As 3 medidas acima usadas para compor KPI card e comparação entre valores brutos e líquidos

---

## 📓 Dim Calendário
Criada e relacionada por `data_pedido` com as tabelas fato. Contém colunas:
- Data, Ano, Mês, Trimestre
- Ano-Mês, Dia da Semana

---

## 💻 Python - Análises Avançadas (Jupyter)

Arquivo: `analise_final.ipynb`

### 1. 🚫 Detecção de Anomalias
- Cálculo de z-score da receita diária
- Identifica 3 maiores outliers
- Para cada outlier, extrai:
  - Canal com maior receita no dia
  - SKU mais vendido
- Gráfico: linha com receita e marcação dos outliers

### 2. 🌟 RFM - Propensão de Compra
- Recência: dias desde última compra
- Frequência: total de pedidos
- Monetário: soma da receita
- Cálculo de Score RFM (1 a 5 para cada dimensão)
- Gráfico de barras: Top 20 clientes com maior RFM

### 3. 📅 Classificação ABC de Produtos
- Soma da receita por SKU
- Participação acumulada
- Classifica como:
  - A: Top 80%
  - B: 80-95%
  - C: 95-100%
- Gráfico de barras com classificacão

### 4. 🤔 Simulação What-If (+10% desconto em SKUs B)
- Aplica desconto adicional virtual de 10%
- Calcula impacto na receita total
- Exibe:
  - Receita atual
  - Receita simulada
  - % de perda

---

## 📅 Conclusão
O projeto atinge todos os requisitos técnicos esperados:
- Modelagem em estrela
- KPIs completos
- Visuals funcionais e responsivos
- Análises em Python com insights reais
- Apresentação profissional e bem documentada

---

> ✨ *Desenvolvido com capricho por [Seu Nome]*

