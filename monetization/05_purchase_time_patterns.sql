/*
** Временные паттерны покупок
** В какие дни недели и часы суток пользователи чаще всего совершают заказы?
** Учитываются ТОЛЬКО завершённые заказы (status = 'completed').
*/

WITH completed_orders AS (
    SELECT
        order_id,
        order_date,
        order_timestamp
    FROM orders
    WHERE status = 'completed'
)
SELECT
    'day_of_week' AS period_type,
    EXTRACT('isodow' FROM order_date)::INT AS time_unit,  -- 1=Пн, 7=Вс
    COUNT(order_id) AS orders_count
FROM completed_orders
GROUP BY time_unit
UNION ALL
SELECT
    'hour_weekday' AS period_type,
    EXTRACT('hour' FROM order_timestamp)::INT AS time_unit,
    COUNT(order_id) AS orders_count
FROM completed_orders
WHERE EXTRACT('isodow' FROM order_date) BETWEEN 1 AND 5
GROUP BY time_unit
UNION ALL
SELECT
    'hour_weekend' AS period_type,
    EXTRACT('hour' FROM order_timestamp)::INT AS time_unit,
    COUNT(order_id) AS orders_count
FROM completed_orders
WHERE EXTRACT('isodow' FROM order_date) IN (6, 7)
GROUP BY time_unit
ORDER BY period_type, time_unit;
