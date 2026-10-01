WITH facility_skus AS (
    SELECT 
        ws.warehouse_id,
        w.warehouse_code,
        w.region,
        ws.product_id,
        p.sku,
        p.product_name,
        (ws.quantity_on_hand - ws.quantity_reserved) AS net_available,
        COALESCE(SUM(s.quantity_shipped) / 30.0, 0.0) AS daily_demand
    FROM warehouse_stock ws
    JOIN warehouses w ON ws.warehouse_id = w.warehouse_id
    JOIN products p ON ws.product_id = p.product_id
    LEFT JOIN shipments s 
      ON ws.warehouse_id = s.warehouse_id 
     AND ws.product_id = s.product_id 
     AND s.shipment_date >= DATE '2026-04-01' - INTERVAL 30 DAY
    GROUP BY ws.warehouse_id, w.warehouse_code, w.region, ws.product_id, p.sku, p.product_name, ws.quantity_on_hand, ws.quantity_reserved
),

facility_status AS (
    SELECT 
        warehouse_id,
        warehouse_code,
        region,
        product_id,
        sku,
        product_name,
        net_available,
        daily_demand,
        CASE 
            WHEN daily_demand = 0 THEN 999.0
            ELSE ROUND(net_available / daily_demand, 1)
        END AS dos
    FROM facility_skus
),

deficits AS (
    SELECT * FROM facility_status WHERE dos < 10.0 AND daily_demand > 0
),

surpluses AS (
    SELECT * FROM facility_status WHERE dos > 40.0
)

SELECT 
    d.sku,
    d.product_name,
    d.warehouse_code AS deficit_facility,
    d.dos AS deficit_dos,
    d.net_available AS deficit_current_stock,
    s.warehouse_code AS surplus_source_facility,
    s.dos AS surplus_dos,
    s.net_available AS surplus_available_stock,
    -- Transfer enough units to bring deficit up to 25 days of buffer
    LEAST(
        CAST(CEIL((d.daily_demand * 25) - d.net_available) AS INTEGER),
        CAST(FLOOR(s.net_available - (s.daily_demand * 25)) AS INTEGER)
    ) AS recommended_transfer_units
FROM deficits d
JOIN surpluses s ON d.product_id = s.product_id
WHERE s.net_available > (s.daily_demand * 30)
ORDER BY d.dos ASC;