/*
** Метрики вовлечённости по основному устройству пользователя
** Критерий основного устройства: устройство с наибольшим суммарным временем сессий.
** Все метрики вовлеченности считаются по ВСЕМ сессиям пользователя.
** Добавлена валидационная метрика: средняя доля времени на основном устройстве.
*/

WITH device_usage AS (
    -- Суммарное время по устройствам пользователя
    SELECT
        user_id,
        device_type,
        SUM(session_duration_minutes) AS total_duration_minutes
    FROM user_sessions
    WHERE session_duration_minutes > 0
    GROUP BY user_id, device_type
),
primary_device AS (
    -- Определяем основное устройство с сохранением времени
    SELECT
        user_id,
        device_type AS primary_device,
        total_duration_minutes AS primary_device_time
    FROM (
        SELECT
            user_id,
            device_type,
            total_duration_minutes,
            ROW_NUMBER() OVER (
                PARTITION BY user_id
                ORDER BY total_duration_minutes DESC
            ) AS device_rank
        FROM device_usage
    ) ranked
    WHERE device_rank = 1
),
user_totals AS (
    -- Общее время пользователя по всем устройствам
    SELECT
        user_id,
        SUM(session_duration_minutes) AS total_user_time
    FROM user_sessions
    WHERE session_duration_minutes > 0
    GROUP BY user_id
),
user_behavior AS (
    -- Метрики вовлеченности по всем сессиям
    SELECT
        user_id,
        AVG(pages_viewed) AS avg_pages_per_session,
        AVG(session_duration_minutes) AS avg_session_minutes,
        COUNT(DISTINCT session_id) AS total_sessions
    FROM user_sessions
    WHERE session_duration_minutes > 0
    GROUP BY user_id
)
-- Финальный агрегат по устройствам
SELECT
    pd.primary_device AS device_type,
    -- Доля пользователей
    COUNT(DISTINCT ub.user_id) AS users_count,
    ROUND(
        100.0 * COUNT(DISTINCT ub.user_id) / 
        SUM(COUNT(DISTINCT ub.user_id)) OVER (), 
        2
    ) AS device_share_percent,
    -- Ключевые метрики вовлеченности
    ROUND(AVG(ub.avg_pages_per_session), 2) AS avg_pages_per_session,
    ROUND(AVG(ub.avg_session_minutes), 2) AS avg_session_minutes,
    ROUND(AVG(ub.total_sessions), 2) AS avg_sessions_per_user,
    -- Валидационная метрика (средняя доля времени на основном устройстве)
    ROUND(
        AVG(pd.primary_device_time * 100.0 / ut.total_user_time),
        1
    ) AS avg_primary_device_time_share_percent
FROM user_behavior ub
INNER JOIN primary_device pd ON ub.user_id = pd.user_id
INNER JOIN user_totals ut ON ub.user_id = ut.user_id
GROUP BY pd.primary_device
ORDER BY users_count DESC;
