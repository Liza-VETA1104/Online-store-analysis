/*
** Когортный анализ: удержание и монетизация по календарным месяцам жизни
**
** Цель: оценить качество привлечённых пользователей и долгосрочную ценность когорт.
**
** Метрики:
** - Retention на день 1, 7, 30 (раннее удержание),
** - Месячный retention (M1, M2) — доля активных в 1-й и 2-й месяцы жизни,
** - ARPU по месяцам жизни (M0, M1, M2) — выручка на пользователя,
** - Конверсия в покупку по месяцам (paying_rate_m0, m1, m2).
**
** Особенности:
** - Используются календарные месяцы (месяц регистрации = M0),
** - Учитываются ТОЛЬКО завершённые заказы (status = 'completed'),
*/

WITH user_cohorts AS (
    SELECT
        user_id,
        DATE_TRUNC('month', registration_date)::DATE AS cohort_month,
        DATE_TRUNC('month', registration_date)::DATE AS m0_start,
        (DATE_TRUNC('month', registration_date) + INTERVAL '1 month')::DATE AS m1_start,
        (DATE_TRUNC('month', registration_date) + INTERVAL '2 months')::DATE AS m2_start,
        (DATE_TRUNC('month', registration_date) + INTERVAL '3 months')::DATE AS m3_start
    FROM users
    WHERE registration_date IS NOT NULL
     ),
cohort_sizes AS (
    SELECT 
        cohort_month, 
        COUNT(*) AS cohort_size
    FROM user_cohorts
    GROUP BY cohort_month
),
retention_calc AS (
    SELECT
        uc.cohort_month,
        -- Удержание дни
        COUNT(DISTINCT CASE WHEN us.session_start::DATE = uc.cohort_month THEN uc.user_id END) AS active_d0,
        COUNT(DISTINCT CASE WHEN us.session_start::DATE = uc.cohort_month + 1 THEN uc.user_id END) AS active_d1,
        COUNT(DISTINCT CASE WHEN us.session_start::DATE = uc.cohort_month + 7 THEN uc.user_id END) AS active_d7,
        COUNT(DISTINCT CASE WHEN us.session_start::DATE = uc.cohort_month + 30 THEN uc.user_id END) AS active_d30,
        -- Удержание месяцы
        COUNT(DISTINCT CASE WHEN us.session_start::DATE >= uc.m1_start AND us.session_start::DATE < uc.m2_start THEN uc.user_id END) AS active_m1,
        COUNT(DISTINCT CASE WHEN us.session_start::DATE >= uc.m2_start AND us.session_start::DATE < uc.m3_start THEN uc.user_id END) AS active_m2
    FROM user_cohorts uc
    LEFT JOIN user_sessions us 
        ON uc.user_id = us.user_id
        AND us.session_start::DATE >= uc.cohort_month
        AND us.session_start::DATE < uc.m3_start
    GROUP BY uc.cohort_month
),
arpu_calc AS (
    SELECT
        uc.cohort_month,
        -- Выручка по месяцам
        SUM(CASE WHEN o.order_date::DATE >= uc.m0_start AND o.order_date::DATE < uc.m1_start THEN o.total_amount ELSE 0 END) AS revenue_m0,
        SUM(CASE WHEN o.order_date::DATE >= uc.m1_start AND o.order_date::DATE < uc.m2_start THEN o.total_amount ELSE 0 END) AS revenue_m1,
        SUM(CASE WHEN o.order_date::DATE >= uc.m2_start AND o.order_date::DATE < uc.m3_start THEN o.total_amount ELSE 0 END) AS revenue_m2,
        -- Платящие пользователи
        COUNT(DISTINCT CASE WHEN o.order_date::DATE >= uc.m0_start AND o.order_date::DATE < uc.m1_start THEN o.user_id END) AS paying_m0,
        COUNT(DISTINCT CASE WHEN o.order_date::DATE >= uc.m1_start AND o.order_date::DATE < uc.m2_start THEN o.user_id END) AS paying_m1,
        COUNT(DISTINCT CASE WHEN o.order_date::DATE >= uc.m2_start AND o.order_date::DATE < uc.m3_start THEN o.user_id END) AS paying_m2
    FROM user_cohorts uc
    LEFT JOIN orders o 
        ON uc.user_id = o.user_id
        AND o.status = 'completed'
        AND o.order_date::DATE >= uc.cohort_month
        AND o.order_date::DATE < uc.m3_start        
    GROUP BY uc.cohort_month
)
SELECT
    cs.cohort_month,
    cs.cohort_size,
    -- Удержание дни (%)
    ROUND(100.0 * COALESCE(rc.active_d1, 0) / NULLIF(cs.cohort_size, 0), 1) AS retention_d1_pct,
    ROUND(100.0 * COALESCE(rc.active_d7, 0) / NULLIF(cs.cohort_size, 0), 1) AS retention_d7_pct,
    ROUND(100.0 * COALESCE(rc.active_d30, 0) / NULLIF(cs.cohort_size, 0), 1) AS retention_d30_pct,
    -- Месячное удержание (%)
    ROUND(100.0 * COALESCE(rc.active_m1, 0) / NULLIF(cs.cohort_size, 0), 1) AS retention_m1_pct,
    ROUND(100.0 * COALESCE(rc.active_m2, 0) / NULLIF(cs.cohort_size, 0), 1) AS retention_m2_pct,
    -- ARPU по месяцам
    ROUND(COALESCE(ac.revenue_m0, 0) / NULLIF(cs.cohort_size, 0), 2) AS arpu_m0,
    ROUND(COALESCE(ac.revenue_m1, 0) / NULLIF(cs.cohort_size, 0), 2) AS arpu_m1,
    ROUND(COALESCE(ac.revenue_m2, 0) / NULLIF(cs.cohort_size, 0), 2) AS arpu_m2,
    -- Конверсия в платящих (%)
    ROUND(100.0 * COALESCE(ac.paying_m0, 0) / NULLIF(cs.cohort_size, 0), 1) AS paying_rate_m0,
    ROUND(100.0 * COALESCE(ac.paying_m1, 0) / NULLIF(cs.cohort_size, 0), 1) AS paying_rate_m1,
    ROUND(100.0 * COALESCE(ac.paying_m2, 0) / NULLIF(cs.cohort_size, 0), 1) AS paying_rate_m2
FROM cohort_sizes cs
LEFT JOIN retention_calc rc ON cs.cohort_month = rc.cohort_month
LEFT JOIN arpu_calc ac ON cs.cohort_month = ac.cohort_month
ORDER BY cs.cohort_month
