/*
** Повторные покупки в первые 30 дней после первой
** Метрики:
** - Доля пользователей с повторной покупкой в течение 30 дней,
** - Общее число первых покупателей,
** - Число повторивших,
** - Среднее время до повторной покупки (в днях).
**
** Учитываются ТОЛЬКО завершённые заказы (status = 'completed').
*/

WITH first_purchases AS (
    SELECT
        user_id,
        MIN(order_date) AS first_order_date
    FROM orders
    WHERE status = 'completed'
    GROUP BY user_id
),
second_purchases AS (
    SELECT
        fp.user_id,
        fp.first_order_date,
        MIN(o.order_date) AS second_order_date
    FROM first_purchases fp
    JOIN orders o
        ON fp.user_id = o.user_id
        AND o.status = 'completed'
        AND o.order_date > fp.first_order_date
        AND o.order_date <= fp.first_order_date + INTERVAL '30 days'
    GROUP BY fp.user_id, fp.first_order_date
)
SELECT
    ROUND(
        100.0 * COUNT(DISTINCT sp.user_id) / NULLIF(COUNT(DISTINCT fp.user_id), 0),
        1
    ) AS repeat_purchase_30d_percent,
    COUNT(DISTINCT fp.user_id) AS total_first_time_buyers,
    COUNT(DISTINCT sp.user_id) AS repeated_in_30d,
    ROUND(
        AVG(sp.second_order_date - fp.first_order_date),
        1
    ) AS avg_days_to_repeat
FROM first_purchases fp
LEFT JOIN second_purchases sp
    ON fp.user_id = sp.user_id;
