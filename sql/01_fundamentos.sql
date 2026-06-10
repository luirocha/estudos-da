-- ================================================================
-- ANÁLISE OLIST — SQL FUNDAMENTOS
-- Dataset: Brazilian E-Commerce Public Dataset by Olist (Kaggle)
-- Schema: olist | Autor: Luí Rocha
-- ================================================================


-- ----------------------------------------------------------------
-- QUERY 1: Volume de pedidos por status
-- Pergunta: Qual é a distribuição de pedidos por status de entrega?
-- Insight: 97% dos pedidos têm status 'delivered', o que indica
-- alta taxa de conclusão, mas os 3% restantes merecem atenção.
-- ----------------------------------------------------------------
SELECT
    order_status                        AS status,
    COUNT(*)                            AS total_pedidos,
    ROUND(COUNT(*) * 100.0 /
          SUM(COUNT(*)) OVER (), 2)     AS percentual
FROM olist.olist_orders
GROUP BY order_status
ORDER BY total_pedidos DESC;


-- ----------------------------------------------------------------
-- QUERY 2: Pedidos entregues com atraso
-- Pergunta: Quantos pedidos foram entregues após a data estimada?
-- Insight: Aproximadamente 8% dos pedidos chegam com atraso,
-- o que impacta diretamente a avaliação do cliente.
-- ----------------------------------------------------------------
SELECT
    COUNT(*) FILTER (
        WHERE order_delivered_customer_date
              > order_estimated_delivery_date
    )                                   AS pedidos_atrasados,
    COUNT(*) FILTER (
        WHERE order_delivered_customer_date
              <= order_estimated_delivery_date
    )                                   AS pedidos_no_prazo,
    COUNT(*)                            AS total,
    ROUND(
        COUNT(*) FILTER (
            WHERE order_delivered_customer_date
                  > order_estimated_delivery_date
        ) * 100.0 / COUNT(*), 2
    )                                   AS pct_atrasados
FROM olist.olist_orders
WHERE order_status = 'delivered'
  AND order_delivered_customer_date IS NOT NULL;


-- ----------------------------------------------------------------
-- QUERY 3: Ticket médio e faturamento por estado
-- Pergunta: Quais estados têm maior ticket médio e faturamento?
-- Insight: SP lidera em volume absoluto, mas estados do Norte e Nordeste
-- têm ticket médio mais alto, talvez impulsionados pelos valores de entrega.
-- ----------------------------------------------------------------
SELECT
    c.customer_state                             AS estado,
    COUNT(DISTINCT o.order_id)                   AS total_pedidos,
    ROUND(SUM(p.payment_value)::numeric, 2)      AS faturamento_total,
    ROUND(SUM(p.payment_value)::numeric / 
    	  COUNT(DISTINCT o.order_id), 2)     	 AS ticket_medio
FROM olist.olist_orders AS o
INNER JOIN olist.olist_customers AS c ON o.customer_id = c.customer_id
INNER JOIN olist.olist_order_payments AS p ON o.order_id   = p.order_id
WHERE o.order_status = 'delivered'
GROUP BY c.customer_state
ORDER BY faturamento_total DESC;


-- ----------------------------------------------------------------
-- QUERY 4: Evolução mensal de pedidos
-- Pergunta: Como o volume de pedidos evoluiu mês a mês?
-- Insight: Pico em novembro, provavelmente impulsionado pela Black Friday.
-- ----------------------------------------------------------------
SELECT
    DATE_TRUNC('month', order_purchase_timestamp::timestamp)::date AS mes,
    COUNT(*)                                             		   AS total_pedidos
FROM olist.olist_orders
WHERE order_purchase_timestamp IS NOT NULL
GROUP BY mes
ORDER BY mes;


-- ----------------------------------------------------------------
-- QUERY 5: Top 10 categorias por faturamento
-- Pergunta: Quais categorias de produto geram mais receita?
-- Insight: As três categorias com maior receita são
-- cama_mesa_banho, beleza_saude e informatica_acessorios,
-- refletindo o perfil de consumo do e-commerce brasileiro.
-- ----------------------------------------------------------------
SELECT
    pt.product_category_name                       AS categoria,
    COUNT(DISTINCT oi.order_id)                    AS total_pedidos,
    ROUND(SUM(p.payment_value)::numeric, 2)        AS faturamento,
    ROUND(AVG(oi.price)::numeric, 2)               AS preco_medio_produto
FROM olist.olist_order_items 			AS oi
INNER JOIN olist.olist_products 		AS pt ON oi.product_id = pt.product_id
INNER JOIN olist.olist_order_payments 	AS p ON oi.order_id   = p.order_id
INNER JOIN olist.olist_orders 			AS o ON oi.order_id   = o.order_id
WHERE o.order_status = 'delivered'
  AND pt.product_category_name IS NOT NULL
GROUP BY categoria
ORDER BY faturamento DESC
LIMIT 10;


-- ----------------------------------------------------------------
-- QUERY 6: Nota média por categoria de produto
-- Pergunta: Quais categorias têm melhor e pior avaliação?
-- Insight: 3 categorias de livros se encontram no top 4 e a pior
-- é moveis_escritorio.
-- ----------------------------------------------------------------
SELECT
    pt.product_category_name          AS categoria,
    ROUND(AVG(r.review_score), 2)     AS nota_media,
    COUNT(r.review_id)                AS total_avaliacoes
FROM olist.olist_order_reviews 		AS r
INNER JOIN olist.olist_orders 		AS o  ON r.order_id   = o.order_id
INNER JOIN olist.olist_order_items 	AS oi ON o.order_id   = oi.order_id
INNER JOIN olist.olist_products 	AS pt ON oi.product_id = pt.product_id
WHERE pt.product_category_name IS NOT NULL
GROUP BY categoria
HAVING COUNT(r.review_id) >= 50   -- filtra categorias com dados suficientes
ORDER BY nota_media ASC;


-- ----------------------------------------------------------------
-- QUERY 7: Top 5 vendedores por faturamento com nota média
-- Pergunta: Os vendedores que mais faturam também têm boa avaliação?
-- Insight: Dos top 5 em faturamento, apenas 1 tem nota acima de 4.
-- Alto volume nem sempre significa boa experiência para o cliente.
-- ----------------------------------------------------------------
SELECT
    oi.seller_id,
    COUNT(DISTINCT oi.order_id)              AS total_pedidos,
    ROUND(SUM(p.payment_value)::numeric, 2)  AS faturamento,
    ROUND(AVG(r.review_score), 2)            AS nota_media
FROM olist.olist_order_items 			AS oi
INNER JOIN olist.olist_order_payments 	AS p ON oi.order_id = p.order_id
INNER JOIN olist.olist_orders 			AS o ON oi.order_id = o.order_id
LEFT  JOIN olist.olist_order_reviews 	AS r ON o.order_id  = r.order_id
WHERE o.order_status = 'delivered'
GROUP BY oi.seller_id
ORDER BY faturamento DESC
LIMIT 5;


-- ----------------------------------------------------------------
-- QUERY 8: Forma de pagamento mais usada por valor
-- Pergunta: Qual forma de pagamento representa mais receita?
-- Insight: Cartão de crédito representa 78% da receita total.
-- ----------------------------------------------------------------
SELECT
    payment_type                                  		AS forma_pagamento,
    COUNT(*)                                      		AS total_transacoes,
    ROUND(SUM(payment_value)::numeric, 2)         		AS valor_total,
    ROUND(SUM(payment_value)::numeric / 
    	  COUNT(DISTINCT order_id), 2)     	 			AS ticket_medio,
    ROUND(SUM(payment_value)::numeric * 100.0 /
          SUM(SUM(payment_value)::numeric) OVER (), 2)	AS pct_receita
FROM olist.olist_order_payments
GROUP BY payment_type
ORDER BY valor_total DESC;


-- ----------------------------------------------------------------
-- QUERY 9: Tempo médio de entrega por estado
-- Pergunta: Quais estados têm maior tempo médio de entrega?
-- Insight: Estados do Norte e Nordeste têm tempo de entrega
-- mais de 2x maior que SP.
-- ----------------------------------------------------------------
SELECT
    c.customer_state                          AS estado,
    ROUND(AVG(
        EXTRACT(DAY FROM
            o.order_delivered_customer_date::timestamp
            - o.order_purchase_timestamp::timestamp
        )
    ), 1)                                     AS dias_entrega_media,
    COUNT(*)                                  AS total_pedidos
FROM olist.olist_orders 			AS o
INNER JOIN olist.olist_customers 	AS c ON o.customer_id = c.customer_id
WHERE o.order_status = 'delivered'
	AND o.order_delivered_customer_date IS NOT null
	AND o.order_delivered_customer_date <> ''
	AND o.order_purchase_timestamp <> ''
GROUP BY c.customer_state
ORDER BY dias_entrega_media DESC;


-- ----------------------------------------------------------------
-- QUERY 10: Relação entre tempo de entrega e nota do cliente
-- Pergunta: Entregas mais rápidas resultam em notas mais altas?
-- Insight: Pedidos entregues em até 7 dias têm nota média 4.4.
-- Pedidos com mais de 20 dias têm nota média 3.1.
-- ----------------------------------------------------------------
SELECT
    CASE
        WHEN EXTRACT(DAY FROM o.order_delivered_customer_date::timestamp
                              - o.order_purchase_timestamp::timestamp) <= 7
             THEN '01 - Até 7 dias'
        WHEN EXTRACT(DAY FROM o.order_delivered_customer_date::timestamp
                              - o.order_purchase_timestamp::timestamp) <= 14
             THEN '02 - 8 a 14 dias'
        WHEN EXTRACT(DAY FROM o.order_delivered_customer_date::timestamp
                              - o.order_purchase_timestamp::timestamp) <= 20
             THEN '03 - 15 a 20 dias'
        ELSE '04 - Mais de 20 dias'
    END                                    AS faixa_entrega,
    ROUND(AVG(r.review_score), 2)          AS nota_media,
    COUNT(*)                               AS total_pedidos
FROM olist.olist_orders 				AS o
INNER JOIN olist.olist_order_reviews 	AS r ON o.order_id = r.order_id
WHERE o.order_status = 'delivered'
  AND o.order_delivered_customer_date IS NOT NULL
  AND o.order_delivered_customer_date <> ''
  AND o.order_purchase_timestamp <> ''
GROUP BY faixa_entrega
ORDER BY faixa_entrega;


-- ----------------------------------------------------------------
-- QUERY 11: Produtos com mais de 1 item por pedido
-- Pergunta: Qual o perfil de pedidos com múltiplos itens?
-- Insight: Pedidos com 1 item dominam o volume,
-- mas pedidos com múltiplos itens têm ticket médio maior.
-- ----------------------------------------------------------------
SELECT
    quantidade_itens,
    COUNT(*)                                    AS total_pedidos,
    ROUND(AVG(valor_total)::numeric, 2)         AS ticket_medio
FROM (
    SELECT
        oi.order_id,
        COUNT(oi.order_item_id)              AS quantidade_itens,
        SUM(p.payment_value)                 AS valor_total
    FROM olist.olist_order_items 			AS oi
    INNER JOIN olist.olist_order_payments 	AS p ON oi.order_id = p.order_id
    GROUP BY oi.order_id
) sub
GROUP BY quantidade_itens
ORDER BY quantidade_itens;


-- ----------------------------------------------------------------
-- QUERY 12: Clientes recorrentes (mais de 1 pedido)
-- Pergunta: Existe retenção de clientes no Olist?
-- Insight: 97% dos clientes fizeram apenas 1 compra, sugerindo
-- que o marketplace atrai mas não retém.
-- ----------------------------------------------------------------
SELECT
    numero_pedidos,
    COUNT(*)           AS quantidade_clientes,
    ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER (), 2) AS percentual
FROM (
    SELECT
        customer_unique_id,
        COUNT(DISTINCT o.order_id) AS numero_pedidos
    FROM olist.olist_orders 			AS o
    INNER JOIN olist.olist_customers 	AS c ON o.customer_id = c.customer_id
    GROUP BY customer_unique_id
) sub
GROUP BY numero_pedidos
ORDER BY numero_pedidos;


-- ----------------------------------------------------------------
-- QUERY 13: Estados com maior proporção de pedidos atrasados
-- Pergunta: O atraso se concentra em alguma região?
-- Insight: Os atrasos se concentram no Nordeste.
-- Estados do Sul e Sudeste apresentam taxas até 4x menores.
-- ----------------------------------------------------------------
SELECT
    c.customer_state                       AS estado,
    COUNT(*)                               AS total_pedidos,
    COUNT(*) FILTER (
        WHERE o.order_delivered_customer_date
              > o.order_estimated_delivery_date
    )                                      AS pedidos_atrasados,
    ROUND(
        COUNT(*) FILTER (
            WHERE o.order_delivered_customer_date
                  > o.order_estimated_delivery_date
        ) * 100.0 / NULLIF(COUNT(*), 0), 2
    )                                      AS pct_atraso
FROM olist.olist_orders 			AS o
INNER JOIN olist.olist_customers 	AS c ON o.customer_id = c.customer_id
WHERE o.order_status = 'delivered'
  AND o.order_delivered_customer_date IS NOT NULL
GROUP BY c.customer_state
ORDER BY pct_atraso DESC;


-- ----------------------------------------------------------------
-- QUERY 14: Sazonalidade — comparação de faturamento por dia da semana
-- Pergunta: Há diferença de volume entre dias úteis e fins de semana?
-- Insight: Segunda, terça e quarta concentram maior parte dos pedidos da semana,
-- sugerindo comportamento de compra pós-pesquisa no fim de semana.
-- ----------------------------------------------------------------
SELECT
    TO_CHAR(order_purchase_timestamp::timestamp, 'Day') AS dia_semana,
    EXTRACT(DOW FROM order_purchase_timestamp::timestamp) AS num_dia,
    COUNT(*)                                              AS total_pedidos,
    ROUND(SUM(p.payment_value)::numeric, 2)               AS faturamento
FROM olist.olist_orders 				AS o
INNER JOIN olist.olist_order_payments 	AS p ON o.order_id = p.order_id
WHERE o.order_purchase_timestamp IS NOT NULL
  AND o.order_purchase_timestamp <> ''
GROUP BY dia_semana, num_dia
ORDER BY num_dia;


-- ----------------------------------------------------------------
-- QUERY 15: Receita por vendedor e estado do vendedor
-- Pergunta: De quais estados vêm os vendedores mais produtivos?
-- Insight: SP concentra o maior volume absoluto de vendedores e faturamento,
-- mas em produtividade por vendedor SP (R$ 7.361), RJ (R$ 6.567) e MG (R$ 6.424)
-- lideram entre os estados com base representativa — sugerindo que qualidade e volume coexistem no Sudeste.
-- ----------------------------------------------------------------
SELECT
    s.seller_state                                AS estado_vendedor,
    COUNT(DISTINCT oi.seller_id)                  AS num_vendedores,
    ROUND(SUM(p.payment_value)::numeric, 2)       AS faturamento_total,
    ROUND(
        (SUM(p.payment_value) / NULLIF(
            COUNT(DISTINCT oi.seller_id), 0
        ))::numeric, 2
    )                                             AS faturamento_por_vendedor
FROM olist.olist_order_items 			AS oi
INNER JOIN olist.olist_sellers 			AS s ON oi.seller_id  = s.seller_id
INNER JOIN olist.olist_order_payments 	AS p ON oi.order_id   = p.order_id
INNER JOIN olist.olist_orders 			AS o ON oi.order_id   = o.order_id
WHERE o.order_status = 'delivered'
GROUP BY s.seller_state
ORDER BY faturamento_total DESC;
