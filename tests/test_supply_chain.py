import duckdb
import pytest

DB_PATH = "supply_chain.db"

@pytest.fixture
def db_conn():
    conn = duckdb.connect(DB_PATH)
    yield conn
    conn.close()

def test_database_seeded_properly(db_conn):
    wh_count = db_conn.execute("SELECT COUNT(*) FROM warehouses").fetchone()[0]
    prod_count = db_conn.execute("SELECT COUNT(*) FROM products").fetchone()[0]
    ship_count = db_conn.execute("SELECT COUNT(*) FROM shipments").fetchone()[0]
    assert wh_count == 4
    assert prod_count >= 12
    assert ship_count > 500

def test_reorder_forecasting_identifies_stockouts(db_conn):
    with open("queries/01_reorder_forecasting.sql", "r") as f:
        query = f.read()
    df = db_conn.execute(query).df()
    
    assert len(df) > 0
    # Confirms presence of critical stockout warnings
    assert any("CRITICAL" in status or "WARNING" in status for status in df["inventory_health_status"])

def test_dead_stock_identifies_legacy_skus(db_conn):
    with open("queries/02_dead_stock_holding_cost.sql", "r") as f:
        query = f.read()
    df = db_conn.execute(query).df()
    
    assert len(df) > 0
    # Both legacy dead stock items should be detected
    skus = df["sku"].unique()
    assert "SKU-DSK-OLD" in skus or "SKU-CRT-OLD" in skus
    assert (df["annualized_holding_cost_usd"] > 0).all()

def test_inter_warehouse_transfers_positive(db_conn):
    with open("queries/03_warehouse_stock_balancing.sql", "r") as f:
        query = f.read()
    df = db_conn.execute(query).df()
    
    assert len(df) > 0
    # Recommended transfer units must be positive integers
    assert (df["recommended_transfer_units"] > 0).all()