import random
from datetime import date, timedelta
import duckdb

DB_PATH = "supply_chain.db"

def seed_database():
    conn = duckdb.connect(DB_PATH)
    
    with open("schema/01_init_schema.sql", "r") as f:
        schema_sql = f.read()
    conn.execute(schema_sql)
    print("Supply chain schema initialized successfully.")

    random.seed(42)
    as_of_date = date(2026, 4, 1)

    # 1. Suppliers
    suppliers = [
        ("SUP-001", "Apex Precision Logistics", "United States", 7, 0.96),
        ("SUP-002", "EuroTech Components", "Germany", 14, 0.92),
        ("SUP-003", "Pacific Rim Electronics", "Taiwan", 21, 0.88),
        ("SUP-004", "Nordic Raw Materials", "Sweden", 10, 0.95),
    ]
    conn.executemany("INSERT INTO suppliers VALUES (?, ?, ?, ?, ?)", suppliers)

    # 2. Warehouses (4 Regional Hubs)
    warehouses = [
        ("WH-EAST", "DC-NEW-YORK", "East", 150000, 0.22),
        ("WH-WEST", "DC-LOS-ANGELES", "West", 200000, 0.24),
        ("WH-CENTRAL", "DC-DALLAS", "Central", 180000, 0.20),
        ("WH-MIDWEST", "DC-CHICAGO", "Midwest", 140000, 0.21),
    ]
    conn.executemany("INSERT INTO warehouses VALUES (?, ?, ?, ?, ?)", warehouses)

    # 3. Products (12 SKUs across fast-moving, steady, and dead-stock categories)
    products = [
        ("PROD-001", "SKU-KB-01", "Mechanical Keyboard RGB", "Electronics", 42.00, 40),
        ("PROD-002", "SKU-MO-02", "Ergonomic Wireless Mouse", "Electronics", 18.50, 50),
        ("PROD-003", "SKU-HP-03", "Noise Cancelling Headset", "Audio", 75.00, 30),
        ("PROD-004", "SKU-DK-04", "Thunderbolt 4 Dock", "Electronics", 95.00, 25),
        ("PROD-005", "SKU-MN-05", "34-inch Ultrawide Monitor", "Hardware", 280.00, 15),
        ("PROD-006", "SKU-CH-06", "Mesh Ergonomic Task Chair", "Furniture", 160.00, 20),
        ("PROD-007", "SKU-DS-07", "Motorized Standing Desk Frame", "Furniture", 210.00, 15),
        ("PROD-008", "SKU-CB-08", "Braided USB-C Cable 2m", "Accessories", 4.20, 100),
        ("PROD-009", "SKU-MP-09", "Extended Felt Desk Mat", "Accessories", 9.00, 60),
        ("PROD-010", "SKU-LP-10", "Aluminum Laptop Riser", "Accessories", 16.00, 45),
        # Dead-stock items (No shipments in last 90+ days)
        ("PROD-011", "SKU-DSK-OLD", "Legacy VGA Splitter Hub", "Legacy", 12.00, 10),
        ("PROD-012", "SKU-CRT-OLD", "CRT Monitor Privacy Shield", "Legacy", 24.00, 5),
    ]
    conn.executemany("INSERT INTO products VALUES (?, ?, ?, ?, ?, ?)", products)

    # 4. Warehouse Stock Levels
    stock_records = []
    stock_counter = 1
    for w in warehouses:
        for p in products:
            stock_id = f"STK-{stock_counter:05d}"
            stock_counter += 1
            if p[0] in ["PROD-011", "PROD-012"]:
                # Dead stock: high quantity on hand, last restocked 180 days ago
                qoh = random.randint(120, 350)
                reserved = 0
                last_restock = as_of_date - timedelta(days=random.randint(150, 250))
            elif p[0] in ["PROD-001", "PROD-004"] and w[0] == "WH-EAST":
                # Stockout risk scenario: very low stock in East Hub
                qoh = random.randint(5, 15)
                reserved = random.randint(2, 5)
                last_restock = as_of_date - timedelta(days=20)
            elif p[0] in ["PROD-001", "PROD-004"] and w[0] == "WH-WEST":
                # Surplus scenario: massive inventory in West Hub (prime candidate for transfer)
                qoh = random.randint(300, 450)
                reserved = 10
                last_restock = as_of_date - timedelta(days=10)
            else:
                qoh = random.randint(40, 180)
                reserved = random.randint(5, 20)
                last_restock = as_of_date - timedelta(days=random.randint(5, 60))
            
            stock_records.append((stock_id, w[0], p[0], qoh, reserved, last_restock))
    
    conn.executemany("INSERT INTO warehouse_stock VALUES (?, ?, ?, ?, ?, ?)", stock_records)

    # 5. Outbound Shipments (Trailing 90 Days of Activity)
    shipments = []
    ship_counter = 1
    for days_back in range(1, 91):
        ship_date = as_of_date - timedelta(days=days_back)
        for w in warehouses:
            # Active products ship regularly; dead stock never ships
            for p in products[:10]:
                if random.random() < 0.65:
                    ship_id = f"SHP-{ship_counter:06d}"
                    ship_counter += 1
                    qty = random.randint(1, 6)
                    shipments.append((ship_id, w[0], p[0], ship_date, qty))

    conn.executemany("INSERT INTO shipments VALUES (?, ?, ?, ?, ?)", shipments)

    # 6. Inbound Purchase Orders
    pos = [
        ("PO-001", "SUP-001", "WH-EAST", "PROD-001", 100, as_of_date - timedelta(days=2), as_of_date + timedelta(days=5), "In_Transit"),
        ("PO-002", "SUP-002", "WH-CENTRAL", "PROD-003", 50, as_of_date - timedelta(days=4), as_of_date + timedelta(days=10), "In_Transit"),
        ("PO-003", "SUP-003", "WH-WEST", "PROD-005", 30, as_of_date - timedelta(days=1), as_of_date + timedelta(days=20), "Pending"),
    ]
    conn.executemany("INSERT INTO purchase_orders VALUES (?, ?, ?, ?, ?, ?, ?, ?)", pos)

    print(f"Data seeded successfully:")
    print(f" - Suppliers:        {len(suppliers)}")
    print(f" - Warehouses:      {len(warehouses)}")
    print(f" - Products:        {len(products)}")
    print(f" - Stock Records:   {len(stock_records)}")
    print(f" - Shipments:       {len(shipments)}")
    print(f" - Purchase Orders: {len(pos)}")
    conn.close()

if __name__ == "__main__":
    seed_database()