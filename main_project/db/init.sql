-- Inventory streaming project — initial schema (RTA2026)

CREATE TABLE IF NOT EXISTS suppliers (
    supplier_id   VARCHAR(32) PRIMARY KEY,
    name          VARCHAR(255) NOT NULL,
    contact_email VARCHAR(255),
    lead_time_days INTEGER NOT NULL DEFAULT 7,
    created_at    TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS products (
    product_id     VARCHAR(32) PRIMARY KEY,
    name           VARCHAR(255) NOT NULL,
    category       VARCHAR(64) NOT NULL,
    unit           VARCHAR(16) NOT NULL DEFAULT 'szt',
    reorder_level  INTEGER NOT NULL DEFAULT 10,
    supplier_id    VARCHAR(32) NOT NULL REFERENCES suppliers (supplier_id),
    unit_cost      NUMERIC(12, 2) NOT NULL DEFAULT 0,
    created_at     TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS inventory_snapshots (
    id               BIGSERIAL PRIMARY KEY,
    product_id       VARCHAR(32) NOT NULL REFERENCES products (product_id),
    quantity_on_hand INTEGER NOT NULL,
    recorded_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS sales (
    event_id    VARCHAR(64) PRIMARY KEY,
    product_id  VARCHAR(32) NOT NULL REFERENCES products (product_id),
    quantity    INTEGER NOT NULL CHECK (quantity > 0),
    unit_price  NUMERIC(12, 2) NOT NULL,
    store_id    VARCHAR(32) NOT NULL,
    sold_at     TIMESTAMPTZ NOT NULL
);

CREATE TABLE IF NOT EXISTS deliveries (
    event_id     VARCHAR(64) PRIMARY KEY,
    product_id   VARCHAR(32) NOT NULL REFERENCES products (product_id),
    supplier_id  VARCHAR(32) NOT NULL REFERENCES suppliers (supplier_id),
    quantity     INTEGER NOT NULL CHECK (quantity > 0),
    expected_at  TIMESTAMPTZ,
    received_at  TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS alerts (
    alert_id           VARCHAR(64) PRIMARY KEY,
    product_id         VARCHAR(32) NOT NULL REFERENCES products (product_id),
    severity           VARCHAR(32) NOT NULL,
    quantity_on_hand   INTEGER NOT NULL,
    reorder_level      INTEGER NOT NULL,
    created_at         TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS forecasts (
    id                  BIGSERIAL PRIMARY KEY,
    product_id          VARCHAR(32) NOT NULL REFERENCES products (product_id),
    forecast_horizon_days INTEGER NOT NULL,
    predicted_demand    NUMERIC(12, 2) NOT NULL,
    sales_velocity      NUMERIC(12, 4),
    stockout_risk       VARCHAR(16),
    generated_at        TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS purchase_orders (
    order_id     VARCHAR(64) PRIMARY KEY,
    supplier_id  VARCHAR(32) NOT NULL REFERENCES suppliers (supplier_id),
    status       VARCHAR(32) NOT NULL DEFAULT 'CREATED',
    created_at   TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS purchase_order_items (
    id          BIGSERIAL PRIMARY KEY,
    order_id    VARCHAR(64) NOT NULL REFERENCES purchase_orders (order_id),
    product_id  VARCHAR(32) NOT NULL REFERENCES products (product_id),
    quantity    INTEGER NOT NULL CHECK (quantity > 0),
    UNIQUE (order_id, product_id)
);

CREATE INDEX IF NOT EXISTS idx_inventory_snapshots_product_recorded
    ON inventory_snapshots (product_id, recorded_at DESC);

CREATE INDEX IF NOT EXISTS idx_sales_product_sold_at
    ON sales (product_id, sold_at DESC);

CREATE INDEX IF NOT EXISTS idx_sales_sold_at
    ON sales (sold_at DESC);

CREATE INDEX IF NOT EXISTS idx_deliveries_product_received
    ON deliveries (product_id, received_at DESC);

CREATE INDEX IF NOT EXISTS idx_alerts_product_created
    ON alerts (product_id, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_forecasts_product_generated
    ON forecasts (product_id, generated_at DESC);

CREATE INDEX IF NOT EXISTS idx_purchase_orders_supplier_created
    ON purchase_orders (supplier_id, created_at DESC);

-- Seed data: 2 suppliers, 8 products
INSERT INTO suppliers (supplier_id, name, contact_email, lead_time_days) VALUES
    ('SUP-01', 'TechSupply Sp. z o.o.', 'orders@techsupply.pl', 5),
    ('SUP-02', 'FreshFood Distributors', 'logistics@freshfood.pl', 3)
ON CONFLICT (supplier_id) DO NOTHING;

INSERT INTO products (product_id, name, category, unit, reorder_level, supplier_id, unit_cost) VALUES
    ('P001', 'Laptop 14"', 'elektronika', 'szt', 10, 'SUP-01', 3499.00),
    ('P002', 'Mysz bezprzewodowa', 'elektronika', 'szt', 25, 'SUP-01', 89.99),
    ('P003', 'Klawiatura mechaniczna', 'elektronika', 'szt', 15, 'SUP-01', 299.00),
    ('P004', 'Monitor 27"', 'elektronika', 'szt', 8, 'SUP-01', 1299.00),
    ('P005', 'Mleko UHT 1L', 'żywność', 'szt', 50, 'SUP-02', 4.49),
    ('P006', 'Chleb pszenny', 'żywność', 'szt', 30, 'SUP-02', 5.99),
    ('P007', 'Jogurt naturalny 400g', 'żywność', 'szt', 40, 'SUP-02', 3.79),
    ('P008', 'Woda mineralna 1.5L', 'żywność', 'szt', 60, 'SUP-02', 2.29)
ON CONFLICT (product_id) DO NOTHING;

INSERT INTO inventory_snapshots (product_id, quantity_on_hand, recorded_at) VALUES
    ('P001', 42, NOW()),
    ('P002', 120, NOW()),
    ('P003', 35, NOW()),
    ('P004', 18, NOW()),
    ('P005', 200, NOW()),
    ('P006', 85, NOW()),
    ('P007', 95, NOW()),
    ('P008', 310, NOW());
