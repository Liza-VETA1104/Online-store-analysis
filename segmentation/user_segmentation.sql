/*
** Сегментация пользователей по поведению: RFM + активность
**
** Цель: выделить ключевые группы пользователей и оценить их вклад в выручку.
**
** Метрики:
** - Recency: дни с последней покупки,
** - Frequency: число завершённых заказов,
** - Monetary: суммарная выручка,
** - Активность: число сессий за последние 30 дней.
**
** Сегменты:
** - Чемпионы: недавно покупали, часто, много тратят,
** - Лояльные: регулярно покупают,
** - Одноразовые: только одна покупка,
** - Неактивные: нет активности >30 дней.
*/


WITH analysis_date AS (
    SELECT MAX(order_date)::DATE AS max_date
    FROM orders
    WHERE status = 'completed'
),
user_order_metrics AS (
    SELECT
        o.user_id,
        MAX(o.order_date) AS last_order_date,
        COUNT(DISTINCT o.order_id) AS frequency,
        SUM(o.total_amount) AS monetary
    FROM orders o
    CROSS JOIN analysis_date ad
    WHERE o.status = 'completed'
      AND o.order_date <= ad.max_date
    GROUP BY o.user_id
),
user_activity AS (
    SELECT
        us.user_id,
        COUNT(DISTINCT us.session_id) AS sessions_30d
    FROM user_sessions us
    CROSS JOIN analysis_date ad
    WHERE us.session_start >= ad.max_date - INTERVAL '30 days'
      AND us.session_start <= ad.max_date
    GROUP BY us.user_id
),
user_metrics AS (
    SELECT
        u.user_id,
        COALESCE(ad.max_date - om.last_order_date, 999) AS recency_days,
        COALESCE(om.frequency, 0) AS frequency,
        COALESCE(om.monetary, 0) AS monetary,
        COALESCE(ua.sessions_30d, 0) AS sessions_30d
    FROM users u
    CROSS JOIN analysis_date ad
    LEFT JOIN user_order_metrics om ON u.user_id = om.user_id
    LEFT JOIN user_activity ua ON u.user_id = ua.user_id
    WHERE u.registration_date <= ad.max_date - INTERVAL '30 days'
),
user_segments AS (
    SELECT
        user_id,
        recency_days,
        frequency,
        monetary,
        sessions_30d,
        CASE
            WHEN frequency >= 3 AND monetary >= 1000 AND recency_days <= 60 THEN 'Чемпионы'
            WHEN frequency >= 2 AND recency_days <= 90 THEN 'Лояльные'
            WHEN frequency = 1 THEN 'Одноразовые'
            WHEN sessions_30d = 0 THEN 'Неактивные'
            ELSE 'Обычные'
        END AS segment
    FROM user_metrics
)
SELECT
    segment,
    COUNT(*) AS users_count,
    ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (), 2) AS users_share_pct,
    ROUND(AVG(monetary), 2) AS avg_ltv,
    SUM(monetary) AS total_revenue,
    ROUND(100.0 * SUM(monetary) / SUM(SUM(monetary)) OVER (), 2) AS revenue_share_pct
FROM user_segments
GROUP BY segment
ORDER BY revenue_share_pct DESC

