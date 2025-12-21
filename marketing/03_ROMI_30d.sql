/*
** Метрика: ROMI (30-day, gross profit)
** Описание: (Валовая прибыль от клиентов за 30 дней - Бюджет кампании) / Бюджет
** Горизонт: первые 30 дней после регистрации
** Учитываются только заказы со статусом 'completed'
*/

WITH user_30d_profit AS (
    SELECT
        u.campaign_id,
        SUM(
            COALESCE(oi.total_price, 0) - COALESCE(oi.quantity * p.cost, 0)
        ) AS total_gross_profit
    FROM users u
    LEFT JOIN orders o
        ON u.user_id = o.user_id
        AND o.status = 'completed'
        AND o.order_date >= u.registration_date
        AND o.order_date < u.registration_date + INTERVAL '30 days'
    LEFT JOIN order_items oi ON o.order_id = oi.order_id
    LEFT JOIN products p ON oi.product_id = p.product_id
    WHERE u.campaign_id IS NOT NULL
    GROUP BY u.campaign_id
)
SELECT
    c.campaign_name,
    CASE
        WHEN c.spent = 0 THEN NULL
        ELSE ROUND((up.total_gross_profit - c.spent) / c.spent, 2)
    END AS romi
FROM campaigns c
JOIN user_30d_profit up ON up.campaign_id = c.campaign_id
WHERE c.spent > 0
ORDER BY romi DESC;
