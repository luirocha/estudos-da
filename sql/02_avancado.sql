-- ================================================================
-- ANÁLISE OLIST — SQL AVANÇADO: CTEs, WINDOW FUNCTIONS, UNION
-- Dataset: Brazilian E-Commerce Public Dataset by Olist (Kaggle)
-- Schema: olist | Autor: Luí Rocha
-- ================================================================


-- ----------------------------------------------------------------
-- QUERY 1: CTE — Ranking de categorias por faturamento
-- Pergunta: Qual é o ranking completo de categorias com
-- participação acumulada na receita?
-- Insight: As top 10 categorias representam 62% da receita,
-- indicando oportunidade de diversificação do catálogo.
-- ----------------------------------------------------------------
WITH faturamento_categoria AS (
    SELECT
        pt.product_category_name				AS categoria,
        SUM(p.payment_value)::numeric			AS faturamento
    FROM olist.olist_order_items			oi
    INNER JOIN olist.olist_products			pt ON oi.product_id = pt.product_id
    INNER JOIN olist.olist_order_payments	p  ON oi.order_id   = p.order_id
    INNER JOIN olist.olist_orders			o  ON oi.order_id   = o.order_id
    WHERE o.order_status = 'delivered'
      AND pt.product_category_name IS NOT NULL
    GROUP BY pt.product_category_name
)
SELECT
    categoria,
    ROUND(faturamento, 2)										AS faturamento,
    RANK() OVER (ORDER BY faturamento DESC)            			AS ranking,
    ROUND((SUM(faturamento) OVER (ORDER BY faturamento DESC
          ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW)
          * 100.0 / SUM(faturamento) OVER ()), 2)				AS pct_acumulado
FROM faturamento_categoria
ORDER BY ranking;


-- ----------------------------------------------------------------
-- QUERY 2: CTE em múltiplos passos — análise de clientes VIP
-- Pergunta: Quem são os clientes com maior valor de compras?
-- Insight: Top 1% dos clientes únicos geram 10% da receita.
-- ----------------------------------------------------------------
WITH pedidos_cliente AS (
    SELECT
        c.customer_unique_id,
        COUNT(DISTINCT o.order_id)				AS total_pedidos,
        SUM(p.payment_value)::numeric			AS gasto_total
    FROM olist.olist_orders					o
    INNER JOIN olist.olist_customers		c ON o.customer_id = c.customer_id
    INNER JOIN olist.olist_order_payments	p ON o.order_id = p.order_id
    WHERE o.order_status = 'delivered'
    GROUP BY c.customer_unique_id
),
percentis AS (
    SELECT
        PERCENTILE_CONT(0.99) WITHIN GROUP
            (ORDER BY gasto_total) AS p99_gasto
    FROM pedidos_cliente
)
SELECT
    COUNT(*) FILTER (WHERE pc.gasto_total >= p.p99_gasto)
                                       AS clientes_vip,
    ROUND(SUM(pc.gasto_total) FILTER
        (WHERE pc.gasto_total >= p.p99_gasto), 2)
                                       AS receita_vip,
    ROUND(SUM(pc.gasto_total) FILTER
        (WHERE pc.gasto_total >= p.p99_gasto)
        * 100.0 / SUM(pc.gasto_total), 2)
                                       AS pct_receita_vip
FROM pedidos_cliente pc, percentis p;


-- ----------------------------------------------------------------
-- QUERY 3: CTE + Window — variação mensal de pedidos (MoM)
-- Pergunta: Qual a variação percentual de pedidos mês a mês?
-- Insight: Forte crescimento inicial ao longo de 2016 e 2017,
-- se estabilizando durante 2018.
-- ----------------------------------------------------------------
WITH pedidos_mensais AS (
    SELECT
        DATE_TRUNC('month', order_purchase_timestamp::timestamp)::date AS mes,
        COUNT(*) AS total_pedidos
    FROM olist.olist_orders
    WHERE order_purchase_timestamp IS NOT NULL
    GROUP BY mes
)
SELECT
    mes,
    total_pedidos,
    LAG(total_pedidos) OVER (ORDER BY mes)				AS pedidos_mes_anterior,
    total_pedidos - LAG(total_pedidos) OVER
        (ORDER BY mes)									AS variacao_absoluta,
    ROUND(
        (total_pedidos - LAG(total_pedidos) OVER
            (ORDER BY mes))
        * 100.0 / NULLIF(LAG(total_pedidos) OVER
            (ORDER BY mes), 0), 2
    )													AS variacao_pct
FROM pedidos_mensais
ORDER BY mes;


-- ----------------------------------------------------------------
-- QUERY 4: Window function RANK — top vendedor por estado
-- Pergunta: Quem é o melhor vendedor em cada estado?
-- Insight: Concentração: em SP, o top 1 vendedor tem 3x mais
-- pedidos que o 2º colocado.
-- ----------------------------------------------------------------
WITH ranking_vendedores AS (
    SELECT
        s.seller_state                              AS estado,
        oi.seller_id,
        COUNT(DISTINCT oi.order_id)                 AS total_pedidos,
        ROUND(SUM(p.payment_value)::numeric, 2)     AS faturamento,
        RANK() OVER (
            PARTITION BY s.seller_state
            ORDER BY SUM(p.payment_value) DESC
        )                                           AS rank_no_estado
    FROM olist.olist_order_items			oi
    INNER JOIN olist.olist_sellers			s ON oi.seller_id = s.seller_id
    INNER JOIN olist.olist_order_payments	p ON oi.order_id = p.order_id
    INNER JOIN olist.olist_orders			o ON oi.order_id  = o.order_id
    WHERE o.order_status = 'delivered'
    GROUP BY s.seller_state, oi.seller_id
)
SELECT *
FROM ranking_vendedores
WHERE rank_no_estado = 1
ORDER BY faturamento DESC;


-- ----------------------------------------------------------------
-- QUERY 5: Window SUM acumulado — curva de crescimento de receita
-- Pergunta: Como a receita acumulada evoluiu ao longo do tempo?
-- Insight: A receita acumulada seguiu uma trajetória de forte
-- aceleração exponencial inicial entre o final de 2016 e o fim de 2017,
-- migrando para uma curva de crescimento linear e constante ao longo do ano de 2018.
-- ----------------------------------------------------------------
WITH receita_mensal AS (
    SELECT
        DATE_TRUNC('month', o.order_purchase_timestamp::timestamp)::date AS mes,
        SUM(p.payment_value)  AS receita_mes
    FROM olist.olist_orders					o
    INNER JOIN olist.olist_order_payments	p ON o.order_id = p.order_id
    WHERE o.order_status = 'delivered'
    GROUP BY mes
)
SELECT
    mes,
    ROUND(receita_mes::numeric, 2)          AS receita_mes,
    ROUND(SUM(receita_mes) OVER
        (ORDER BY mes
         ROWS BETWEEN UNBOUNDED PRECEDING
         AND CURRENT ROW)::numeric, 2)		AS receita_acumulada
FROM receita_mensal
ORDER BY mes;


-- ----------------------------------------------------------------
-- QUERY 6: Window NTILE — segmentação de clientes em quartis
-- Pergunta: Como segmentar clientes por valor gasto?
-- Insight: Q4 (top 25%) gasta, em média, quase 10x mais que Q1 (bottom 25%).
-- ----------------------------------------------------------------
WITH gasto_cliente AS (
    SELECT
        c.customer_unique_id,
        SUM(p.payment_value) AS gasto_total
    FROM olist.olist_orders					o
    INNER JOIN olist.olist_customers		c ON o.customer_id = c.customer_id
    INNER JOIN olist.olist_order_payments	p ON o.order_id  = p.order_id
    WHERE o.order_status = 'delivered'
    GROUP BY c.customer_unique_id
),
gasto_com_quartil AS (
    SELECT
        gasto_total,
        NTILE(4) OVER (ORDER BY gasto_total) AS quartil
    FROM gasto_cliente
)
SELECT
    quartil,
	COUNT(*)                                  AS clientes,
    ROUND(MIN(gasto_total)::numeric, 2)       AS gasto_minimo,
    ROUND(MAX(gasto_total)::numeric, 2)       AS gasto_maximo,
    ROUND(AVG(gasto_total)::numeric, 2)       AS gasto_medio
FROM gasto_com_quartil
GROUP BY quartil
ORDER BY quartil;


-- ----------------------------------------------------------------
-- QUERY 7: UNION — categorias com nota ótima OU volume alto
-- Pergunta: Quais categorias se destacam em qualidade OU volume?
-- Insight: Nenhuma categoria aparece nos dois conjuntos,
-- sugerindo que qualidade e volume não andam juntos.
-- ----------------------------------------------------------------
-- Top 10 por nota média
SELECT product_category_name AS categoria, 'top_nota' AS tipo
FROM (
    SELECT pt.product_category_name,
           AVG(r.review_score) AS nota_media
    FROM olist.olist_order_items     oi
    INNER JOIN olist.olist_products  pt ON oi.product_id = pt.product_id
    INNER JOIN olist.olist_orders     o ON oi.order_id   = o.order_id
    INNER JOIN olist.olist_order_reviews r ON o.order_id = r.order_id
    WHERE pt.product_category_name IS NOT NULL
    GROUP BY pt.product_category_name
    HAVING COUNT(r.review_id) >= 50
    ORDER BY nota_media DESC LIMIT 10
) top_nota

UNION

-- Top 10 por volume de pedidos
SELECT product_category_name AS categoria, 'top_volume' AS tipo
FROM (
    SELECT pt.product_category_name,
           COUNT(DISTINCT oi.order_id) AS total
    FROM olist.olist_order_items     oi
    INNER JOIN olist.olist_products  pt ON oi.product_id = pt.product_id
    WHERE pt.product_category_name IS NOT NULL
    GROUP BY pt.product_category_name
    ORDER BY total DESC LIMIT 10
) top_volume
ORDER BY tipo, categoria;


-- ----------------------------------------------------------------
-- QUERY 8: EXCEPT — vendedores sem nenhuma avaliação
-- Pergunta: Existe vendedores que nunca receberam avaliação?
-- Insight: Apenas 5 vendedores nunca tiveram feedback do cliente.
-- ----------------------------------------------------------------
SELECT DISTINCT seller_id FROM olist.olist_order_items
EXCEPT
SELECT DISTINCT oi.seller_id
FROM olist.olist_order_items    oi
INNER JOIN olist.olist_orders   o  ON oi.order_id = o.order_id
INNER JOIN olist.olist_order_reviews r ON o.order_id = r.order_id
WHERE r.review_score IS NOT NULL;


-- ----------------------------------------------------------------
-- QUERY 9: Subquery correlacionada — produtos acima da média de sua categoria
-- Pergunta: Quais produtos têm preço acima da média da sua categoria?
-- Insight: Identifica produtos com posicionamento premium dentro
-- de cada categoria para análise de margem.
-- ----------------------------------------------------------------
SELECT
    oi.product_id,
    pt.product_category_name          AS categoria,
    ROUND(AVG(oi.price)::numeric, 2)  AS preco_medio_produto,
    ROUND((
        SELECT AVG(oi2.price)
        FROM olist.olist_order_items oi2
        INNER JOIN olist.olist_products pt2
               ON oi2.product_id = pt2.product_id
        WHERE pt2.product_category_name = pt.product_category_name
    )::numeric, 2)                    AS media_categoria
FROM olist.olist_order_items oi
INNER JOIN olist.olist_products pt ON oi.product_id = pt.product_id
GROUP BY oi.product_id, pt.product_category_name
HAVING AVG(oi.price) > (
    SELECT AVG(oi2.price)
    FROM olist.olist_order_items oi2
    INNER JOIN olist.olist_products pt2 ON oi2.product_id = pt2.product_id
    WHERE pt2.product_category_name = pt.product_category_name
)
ORDER BY categoria, preco_medio_produto DESC
LIMIT 300;


-- ----------------------------------------------------------------
-- QUERY 10: Subquery correlacionada — estados acima da média nacional
-- Pergunta: Quais estados têm ticket médio acima da média nacional?
-- Insight: 24 estados superam a média nacional de R$154.
-- ----------------------------------------------------------------
SELECT
    estado,
    ROUND(ticket_medio::numeric, 2) AS ticket_medio,
    ROUND((
        SELECT AVG(p2.payment_value)
        FROM olist.olist_order_payments p2
    )::numeric, 2)                  AS media_nacional
FROM (
    SELECT
        c.customer_state          AS estado,
        AVG(p.payment_value)      AS ticket_medio
    FROM olist.olist_orders           o
    INNER JOIN olist.olist_customers  c ON o.customer_id = c.customer_id
    INNER JOIN olist.olist_order_payments p ON o.order_id = p.order_id
    WHERE o.order_status = 'delivered'
    GROUP BY c.customer_state
) sub
WHERE ticket_medio > (
    SELECT AVG(payment_value)
    FROM olist.olist_order_payments
)
ORDER BY ticket_medio DESC;
