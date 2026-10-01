DROP TABLE IF EXISTS inventory_snapshots;
DROP TABLE IF EXISTS shipments;
DROP TABLE IF EXISTS purchase_orders;
DROP TABLE IF EXISTS warehouse_stock;
DROP TABLE IF EXISTS products;
DROP TABLE IF EXISTS warehouses;
DROP TABLE IF EXISTS suppliers;

-- 1. Suppliers Table
CREATE TABLE suppliers (
    supplier_id VARCHAR(16) PRIMARY KEY,
    supplier_name VARCHAR(64) NOT NULL,
    country VARCHAR(32) NOT NULL,
    lead_time_days INTEGER NOT NULL CHECK (lead_time_days > 0),
    on_time_delivery_rate NUMERIC(5, 2) NOT NULL
);

-- 2. Warehouses Table
CREATE TABLE warehouses (
    warehouse_id VARCHAR(16) PRIMARY KEY,
    warehouse_code VARCHAR(16) NOT NULL UNIQUE,
    region VARCHAR(32) NOT NULL,
    capacity_sqft INTEGER NOT NULL,
    holding_cost_rate_annual NUMERIC(4, 2) NOT NULL DEFAULT 0.22 -- 22% annual carrying cost
);

-- 3. Products Table
CREATE TABLE products (
    product_id VARCHAR(16) PRIMARY KEY,
    sku VARCHAR(32) NOT NULL UNIQUE,
    product_name VARCHAR(128) NOT NULL,
    category VARCHAR(64) NOT NULL,
    unit_cost_usd NUMERIC(10, 2) NOT NULL,
    minimum_safety_stock INTEGER NOT NULL DEFAULT 20
);

-- 4. Warehouse Stock Levels (Current State)
CREATE TABLE warehouse_stock (
    stock_id VARCHAR(16) PRIMARY KEY,
    warehouse_id VARCHAR(16) NOT NULL REFERENCES warehouses(warehouse_id),
    product_id VARCHAR(16) NOT NULL REFERENCES products(product_id),
    quantity_on_hand INTEGER NOT NULL CHECK (quantity_on_hand >= 0),
    quantity_reserved INTEGER NOT NULL DEFAULT 0 CHECK (quantity_reserved >= 0),
    last_restock_date DATE NOT NULL
);

-- 5. Inbound Purchase Orders (Open Orders)
CREATE TABLE purchase_orders (
    po_id VARCHAR(16) PRIMARY KEY,
    supplier_id VARCHAR(16) NOT NULL REFERENCES suppliers(supplier_id),
    warehouse_id VARCHAR(16) NOT NULL REFERENCES warehouses(warehouse_id),
    product_id VARCHAR(16) NOT NULL REFERENCES products(product_id),
    ordered_quantity INTEGER NOT NULL,
    order_date DATE NOT NULL,
    expected_delivery_date DATE NOT NULL,
    po_status VARCHAR(24) NOT NULL CHECK (po_status IN ('Pending', 'In_Transit', 'Delivered', 'Cancelled'))
);

-- 6. Outbound Shipments / Fulfillments (Historical Consumption)
CREATE TABLE shipments (
    shipment_id VARCHAR(16) PRIMARY KEY,
    warehouse_id VARCHAR(16) NOT NULL REFERENCES warehouses(warehouse_id),
    product_id VARCHAR(16) NOT NULL REFERENCES products(product_id),
    shipment_date DATE NOT NULL,
    quantity_shipped INTEGER NOT NULL CHECK (quantity_shipped > 0)
);