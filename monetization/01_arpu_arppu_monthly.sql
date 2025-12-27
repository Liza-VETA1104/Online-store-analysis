/*
** Метрики монетизации: ARPU, ARPPU, доля платящих пользователей
** Описание:
** - ARPU (Average Revenue Per User) = Общая выручка / Все активные пользователи
** - ARPPU (Average Revenue Per Paying User) = Общая выручка / Платящие пользователи
** - Доля платящих = Платящие пользователи / Все активные пользователи
**
** Важно:
** - Учитываются ТОЛЬКО заказы со статусом 'completed'.
** - Активные пользователи — те, кто заходил в приложение в течение месяца.
** - Месяц определяется по дате заказа (для выручки) и сессии (для активности).
*/

WITH paying_users AS (
    SELECT
        DATE_TRUNC('month', o.order_date)::DATE AS order_month,
        COUNT(DISTINCT o.user_id) AS paying_users,
        SUM(o.total_amount) AS amount_per_month
    FROM orders o
    WHERE o.status = 'completed' 
    GROUP BY order_month
),
active_users AS (
    SELECT
        DATE_TRUNC('month', us.session_start)::DATE AS active_month,
        COUNT(DISTINCT us.user_id) AS active_users
    FROM user_sessions us
    GROUP BY active_month
)
SELECT
    p.order_month,
    ROUND(p.amount_per_month / NULLIF(a.active_users, 0), 2) AS arpu,
    ROUND(p.amount_per_month / NULLIF(p.paying_users, 0), 2) AS arppu,
    ROUND(p.paying_users * 100.0 / NULLIF(a.active_users, 0), 2) AS share_of_paying_users_percent
FROM paying_users p
JOIN active_users a
    ON p.order_month = a.active_month
ORDER BY p.order_month;
