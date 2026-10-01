WITH recent_movement AS (
    SELECT DISTINCT
        warehouse_id,
        product_id
    FROM shipments
    WHERE shipment_date >= DATE '2026-04-01' - INTERVAL 90 DAY
),

stagnant_inventory AS (
    SELECT 
        w.warehouse_code,
        w.region,
        w.holding_cost_rate_annual,
        p.sku,
        p.product_name,
        p.category,
        p.unit_cost_usd,
        ws.quantity_on_hand,
        ws.last_restock_date,
        (DATE '2026-04-01' - ws.last_restock_date) AS days_dormant,
        ROUND(ws.quantity_on_hand * p.unit_cost_usd, 2) AS tied_up_capital_usd,
        ROUND(ws.quantity_on_hand * p.unit_cost_usd * w.holding_cost_rate_annual, 2) AS annualized_holding_cost_usd
    FROM warehouse_stock ws
    JOIN warehouses w ON ws.warehouse_id = w.warehouse_id
    JOIN products p ON ws.product_id = p.product_id
    LEFT JOIN recent_movement rm 
      ON ws.warehouse_id = rm.warehouse_id 
     AND ws.product_id = rm.product_id
    WHERE rm.product_id IS NULL -- Zero movement in trailing 90 days
      AND ws.quantity_on_hand > 0
)

SELECT 
    warehouse_code,
    region,
    sku,
    product_name,
    category,
    quantity_on_hand AS dormant_units,
    days_dormant,
    unit_cost_usd,
    tied_up_capital_usd,
    annualized_holding_cost_usd,
    'LIQUIDATE_OR_SCRAP' AS inventory_recommendation
FROM stagnant_inventory
ORDER BY annualized_holding_cost_usd DESC;