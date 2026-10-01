WITH trailing_demand AS (
    SELECT 
        warehouse_id,
        product_id,
        COALESCE(SUM(quantity_shipped), 0) AS total_shipped_30d,
        ROUND(COALESCE(SUM(quantity_shipped), 0) / 30.0, 2) AS avg_daily_demand
    FROM shipments
    WHERE shipment_date >= DATE '2026-04-01' - INTERVAL 30 DAY
    GROUP BY warehouse_id, product_id
),

inbound_pipeline AS (
    SELECT 
        warehouse_id,
        product_id,
        COALESCE(SUM(ordered_quantity), 0) AS pipeline_incoming_qty
    FROM purchase_orders
    WHERE po_status IN ('Pending', 'In_Transit')
    GROUP BY warehouse_id, product_id
),

inventory_posture AS (
    SELECT 
        w.region,
        w.warehouse_code,
        p.product_id,
        p.sku,
        p.product_name,
        p.minimum_safety_stock,
        ws.quantity_on_hand,
        ws.quantity_reserved,
        (ws.quantity_on_hand - ws.quantity_reserved) AS net_available_stock,
        COALESCE(td.avg_daily_demand, 0.0) AS avg_daily_demand,
        COALESCE(ip.pipeline_incoming_qty, 0) AS incoming_po_qty
    FROM warehouse_stock ws
    JOIN warehouses w ON ws.warehouse_id = w.warehouse_id
    JOIN products p ON ws.product_id = p.product_id
    LEFT JOIN trailing_demand td ON ws.warehouse_id = td.warehouse_id AND ws.product_id = td.product_id
    LEFT JOIN inbound_pipeline ip ON ws.warehouse_id = ip.warehouse_id AND ws.product_id = ip.product_id
)

SELECT 
    warehouse_code,
    sku,
    product_name,
    net_available_stock,
    incoming_po_qty,
    avg_daily_demand,
    CASE 
        WHEN avg_daily_demand = 0 THEN 999.0
        ELSE ROUND(net_available_stock / avg_daily_demand, 1)
    END AS days_of_supply,
    CASE 
        WHEN avg_daily_demand > 0 AND (net_available_stock / avg_daily_demand) < 7 THEN 'CRITICAL: Imminent Stockout (<7 Days)'
        WHEN avg_daily_demand > 0 AND (net_available_stock / avg_daily_demand) < 14 THEN 'WARNING: Below Reorder Point (<14 Days)'
        WHEN avg_daily_demand = 0 THEN 'NO_DEMAND: Potential Dead Stock'
        ELSE 'HEALTHY'
    END AS inventory_health_status,
    -- Suggested Reorder Quantity to achieve 30 days of buffer
    CASE 
        WHEN avg_daily_demand > 0 AND (net_available_stock + incoming_po_qty) < (minimum_safety_stock + (avg_daily_demand * 14))
        THEN CAST(CEIL((avg_daily_demand * 30) + minimum_safety_stock - (net_available_stock + incoming_po_qty)) AS INTEGER)
        ELSE 0
    END AS suggested_reorder_qty
FROM inventory_posture
WHERE avg_daily_demand > 0
ORDER BY days_of_supply ASC
LIMIT 12;