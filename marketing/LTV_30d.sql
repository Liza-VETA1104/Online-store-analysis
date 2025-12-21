/*
** Метрика: LTV₃₀ (30-day Lifetime Value)
** Описание: Средний доход с клиента за первые 30 дней после регистрации
** Формула: Сумма покупок по завершённым заказам за 30 дней / Число уникальных пользователей
** Единицы измерения: рубли (₽)
** Примечание: 
**   - Учитываются только заказы со статусом 'completed'
**   - Пользователи без завершённых заказов вносят 0 в сумму (благодаря LEFT JOIN + COALESCE)
*/

WITH for_ltv AS (
    SELECT
        u.user_id,
        COALESCE(o.total_amount, 0) AS amount,
        c.campaign_name
    FROM users u
    LEFT JOIN orders o
        ON u.user_id = o.user_id
        AND o.order_date >= u.registration_date
        AND o.order_date < u.registration_date + INTERVAL '30 days'
        AND o.status = 'completed'  
    JOIN campaigns c
        ON c.campaign_id = u.campaign_id
    WHERE u.campaign_id IS NOT NULL
)
SELECT
    campaign_name,
    ROUND(SUM(amount) / COUNT(DISTINCT user_id), 0) AS ltv_30d
FROM for_ltv
GROUP BY campaign_name
ORDER BY ltv_30d DESC;
