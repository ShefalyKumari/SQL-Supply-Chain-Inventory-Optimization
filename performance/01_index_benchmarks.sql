-- 1. Explain analyze trailing shipment aggregation without explicit indexing
EXPLAIN ANALYZE
SELECT 
    warehouse_id,
    product_id,
    SUM(quantity_shipped) AS total_shipped,
    AVG(quantity_shipped) AS avg_per_shipment
FROM shipments
WHERE shipment_date BETWEEN DATE '2026-01-01' AND DATE '2026-04-01'
GROUP BY warehouse_id, product_id;

-- 2. Create composite indexes for high-frequency scan predicates
CREATE INDEX idx_shipments_composite ON shipments(warehouse_id, product_id, shipment_date);
CREATE INDEX idx_warehouse_stock_lookup ON warehouse_stock(warehouse_id, product_id);

-- 3. Re-evaluate execution plan with index support
EXPLAIN ANALYZE
SELECT 
    warehouse_id,
    product_id,
    SUM(quantity_shipped) AS total_shipped,
    AVG(quantity_shipped) AS avg_per_shipment
FROM shipments
WHERE shipment_date BETWEEN DATE '2026-01-01' AND DATE '2026-04-01'
GROUP BY warehouse_id, product_id;