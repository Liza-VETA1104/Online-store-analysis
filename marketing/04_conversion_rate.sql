/*
** Метрика: Конверсия в покупку (30 дней)
** Описание: Доля пользователей, совершивших хотя бы один завершённый заказ в первые 30 дней
** Формула: (Число пользователей с completed-заказом за 30 дней) / (Все пользователи из кампании) * 100%
** Единицы: проценты (%)
*/

SELECT
    c.campaign_name,
    ROUND(
        COUNT(DISTINCT CASE 
            WHEN o.order_id IS NOT NULL THEN u.user_id 
        END) * 100.0
        / COUNT(DISTINCT u.user_id),
        0
    ) AS conversion_rate
FROM users u
JOIN campaigns c 
    ON u.campaign_id = c.campaign_id
LEFT JOIN orders o 
    ON u.user_id = o.user_id
    AND o.status = 'completed'                      -- только завершённые
    AND o.order_date >= u.registration_date
    AND o.order_date < u.registration_date + INTERVAL '30 days'  -- за 30 дней
GROUP BY c.campaign_name
ORDER BY conversion_rate DESC;
