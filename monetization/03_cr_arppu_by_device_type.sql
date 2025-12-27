/*
** Монетизация по основному устройству (на основе сегментации из engagement-анализа)
** 
** - ARPPU: средняя выручка с платящего пользователя,
** - Конверсия: доля пользователей с хотя бы одним завершённым заказом.
**
** Учитываются ТОЛЬКО заказы со статусом 'completed'.
*/

-- Повторяем логику сегментации как в engagement
WITH primary_device AS (
    SELECT
        user_id,
        device_type AS primary_device
    FROM (
        SELECT
            us.user_id,
            us.device_type,
            ROW_NUMBER() OVER (
                PARTITION BY us.user_id
                ORDER BY SUM(us.session_duration_minutes) DESC
            ) AS rank
        FROM user_sessions us
        WHERE us.session_duration_minutes > 0
        GROUP BY us.user_id, us.device_type
    ) ranked
    WHERE rank = 1
),
user_orders AS (
    SELECT
        user_id,
        COUNT(DISTINCT order_id) AS orders_count,
        SUM(total_amount) AS total_revenue
    FROM orders
    WHERE status = 'completed' 
    GROUP BY user_id
)
SELECT
    pd.primary_device AS device_type,
    -- Конверсия: % пользователей с хотя бы одним заказом
    ROUND(
        100.0 * COUNT(DISTINCT uo.user_id) / COUNT(DISTINCT pd.user_id),
        2
    ) AS conversion_rate_percent,
    -- ARPPU: средняя выручка с платящего пользователя
    ROUND(
        SUM(COALESCE(uo.total_revenue, 0)) / NULLIF(COUNT(DISTINCT uo.user_id), 0),
        2
    ) AS arppu
FROM primary_device pd
LEFT JOIN user_orders uo
    ON pd.user_id = uo.user_id
GROUP BY pd.primary_device
ORDER BY conversion_rate_percent DESC;
