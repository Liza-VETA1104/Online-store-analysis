/*
** Метрика: CAC (Customer Acquisition Cost)
** Описание: Средняя стоимость привлечения одного клиента по маркетинговой кампании
** Формула: Общий бюджет кампании (в рублях) / Число уникальных пользователей
** Единицы измерения: рубли (₽)
** Примечание: Кампании без пользователей возвращают 0
*/

WITH users_count AS (
    SELECT
        campaign_id,
        COUNT(DISTINCT user_id) AS users_from_camp
    FROM users
    WHERE campaign_id IS NOT NULL
    GROUP BY campaign_id
)
SELECT
    c.campaign_name,
    CASE
    WHEN u.users_from_camp IS NULL OR u.users_from_camp = 0 THEN 0
    ELSE ROUND(c.spent * 1.0 / u.users_from_camp, 0)
END AS cac
FROM campaigns c
LEFT JOIN users_count u ON u.campaign_id = c.campaign_id
ORDER BY cac DESC;
