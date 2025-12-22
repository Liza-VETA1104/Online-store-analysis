/*
** Метрика: Sticky Factor (DAU / MAU)
** Описание: Показатель вовлечённости — доля ежедневно активных пользователей от месячной аудитории.
** Формула: Среднее DAU за месяц / MAU за тот же месяц
** Интерпретация:
**   - > 0.2 (20%) — высокая вовлечённость (типично для соцсетей, мессенджеров),
**   - 0.1–0.2 — средняя (e-commerce, контентные платформы),
**   - < 0.1 — низкая (утилиты, редко используемые сервисы).
**
** Источник: user_sessions (сессии пользователей)
*/

WITH dau AS (
    SELECT
        session_start::DATE AS day,
        COUNT(DISTINCT user_id) AS user_cnt
    FROM user_sessions
    GROUP BY session_start::DATE
),
avg_dau AS (
    SELECT
        TO_CHAR(day, 'YYYY-MM') AS months,
        ROUND(AVG(user_cnt), 0) AS dau
    FROM dau
    GROUP BY TO_CHAR(day, 'YYYY-MM')
),
mau AS (
    SELECT
        TO_CHAR(session_start, 'YYYY-MM') AS months,
        COUNT(DISTINCT user_id) AS mau
    FROM user_sessions
    GROUP BY TO_CHAR(session_start, 'YYYY-MM')
)
SELECT
    m.months,
    dau,
    mau,
    ROUND(a.dau / NULLIF(m.mau, 0), 2) AS sticky_factor
FROM mau m
JOIN avg_dau a
    ON a.months = m.months
ORDER BY m.months;
