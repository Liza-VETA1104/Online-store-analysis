/*
** Анализ монетизации: категории и средний чек
** Задача:
** - Определить лидеров по объёму продаж и валовой прибыли,
** - Рассчитать средний чек (AOV) по платформе.
**
** Методология:
** - Учитываются ТОЛЬКО заказы со статусом 'completed'.
** - Валовая прибыль = SUM(цена_позиции - себестоимость_позиции).
** - AOV = AVG(сумма_заказа) 
*/

WITH completed_order_items AS (
    -- Только строки из завершённых заказов
    SELECT
        oi.order_id,
        p.category,
        oi.quantity,
        oi.total_price,
        COALESCE(p.cost, 0) AS cost
    FROM order_items oi
    JOIN products p ON oi.product_id = p.product_id
    JOIN orders o ON oi.order_id = o.order_id
    WHERE o.status = 'completed'
),
completed_orders AS (
    -- Сумма каждого завершённого заказа (для AOV)
    SELECT
        order_id,
        SUM(total_price) AS order_total
    FROM completed_order_items
    GROUP BY order_id
),
category_metrics AS (
    SELECT
        'sales_volume' AS metric_type,
        category,
        SUM(quantity) AS value
    FROM completed_order_items
    GROUP BY category
    UNION ALL
    SELECT
        'gross_profit' AS metric_type,
        category,
        SUM(total_price - quantity * cost) AS value
    FROM completed_order_items
    GROUP BY category
    UNION ALL
    SELECT
        'aov' AS metric_type,
        'all' AS category,
        AVG(order_total) AS value
    FROM completed_orders
)
SELECT
    metric_type,
    category,
    ROUND(value, 0) AS value
FROM category_metrics
ORDER BY
    metric_type,
    CASE
        WHEN metric_type = 'aov' THEN 0
        ELSE -value
    END;
