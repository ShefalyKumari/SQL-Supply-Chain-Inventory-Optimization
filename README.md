# Supply Chain & Multi-Warehouse Inventory Optimization Engine

A production-grade SQL analytical engine modeling multi-facility supply chains, automated reorder point forecasting, dead-stock holding cost quantification, and inter-warehouse inventory balancing.

---

## Relational Entity-Relationship Model (ERD)

```text
[suppliers] 1 ────< [purchase_orders] >──── 1 [products] 1 ────< [shipments]
                             │                     │                  │
                             └──────────── 1 [warehouses] 1 ──────────┘
                                                   │
                                         1 ────< [warehouse_stock] >──── 1 [products]