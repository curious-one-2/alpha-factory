-- Unity Catalog Gold Layer Schema Initialization
CREATE SCHEMA IF NOT EXISTS ${catalog}.${schema};

-- 1. Dim Instrument
CREATE TABLE IF NOT EXISTS ${catalog}.${schema}.gold_dim_instrument (
    instrument_dim_key INT NOT NULL,
    symbol STRING NOT NULL,
    asset_class STRING NOT NULL,
    sector STRING,
    industry STRING,
    exchange STRING,
    market_cap_tier STRING,
    currency STRING,
    is_active BOOLEAN,
    created_at TIMESTAMP
)
USING DELTA
CLUSTER BY (symbol, asset_class);

-- 2. Dim Portfolio (SCD Type 2)
CREATE TABLE IF NOT EXISTS ${catalog}.${schema}.gold_dim_portfolio (
    portfolio_key STRING NOT NULL,
    portfolio_id STRING NOT NULL,
    portfolio_name STRING,
    strategy_name STRING,
    desk_owner STRING,
    risk_limit_amount DECIMAL(18, 2),
    effective_start_date DATE NOT NULL,
    effective_end_date DATE,
    is_current STRING NOT NULL
)
USING DELTA
CLUSTER BY (portfolio_id, is_current);

-- 3. Dim Execution Venue
CREATE TABLE IF NOT EXISTS ${catalog}.${schema}.gold_dim_execution_venue (
    venue_key INT NOT NULL,
    venue_id STRING NOT NULL,
    venue_name STRING,
    venue_type STRING,
    mic_code STRING NOT NULL,
    estimated_rebate_cost DECIMAL(10, 6),
    is_active BOOLEAN
)
USING DELTA;

CREATE TABLE IF NOT EXISTS {catalog}.{schema}.gold_dim_market_regime (
    regime_key INT NOT NULL,
    regime_id STRING NOT NULL,
    volatility_state STRING NOT NULL,
    trend_state STRING NOT NULL,
    volume_profile STRING NOT NULL,
    effective_timestamp TIMESTAMP,
    created_at TIMESTAMP
)
USING DELTA;

-- 4. Dim Time (With Native Session Buckets)
CREATE TABLE IF NOT EXISTS ${catalog}.${schema}.gold_dim_time (
    time_key INT NOT NULL,
    time_of_day STRING NOT NULL, -- HH:mm:ss
    hour_24 INT NOT NULL,
    minute_of_hour INT NOT NULL,
    session_bucket STRING NOT NULL -- PRE_MARKET, MARKET_OPEN, MIDDAY, MARKET_CLOSE, AFTER_HOURS
)
USING DELTA
CLUSTER BY (time_key);

-- 5. Fact Execution & Slippage
CREATE TABLE IF NOT EXISTS ${catalog}.${schema}.gold_fact_execution_slippage (
    date_key INT NOT NULL,
    time_key INT NOT NULL,
    instrument_key INT NOT NULL,
    regime_key INT NOT NULL,
    execution_id STRING NOT NULL,
    order_id STRING NOT NULL,
    symbol STRING NOT NULL,
    portfolio_id STRING NOT NULL,
    venue_id STRING NOT NULL,
    execution_timestamp TIMESTAMP NOT NULL,
    execution_date DATE NOT NULL,
    side STRING NOT NULL,
    order_quantity DECIMAL(18, 4),
    order_submission_price DECIMAL(18, 4),
    execution_price DECIMAL(18, 4),
    slippage_amount DECIMAL(18, 4),
    transaction_costs DECIMAL(18, 4)
)
USING DELTA
CLUSTER BY (execution_timestamp, symbol);

-- 6. Fact Risk & Performance
CREATE TABLE IF NOT EXISTS ${catalog}.${schema}.gold_fact_risk_performance (
    date_key INT NOT NULL,
    time_key INT NOT NULL,
    risk_fact_id STRING NOT NULL,
    execution_id STRING NOT NULL,
    symbol STRING NOT NULL,
    portfolio_id STRING NOT NULL,
    execution_timestamp TIMESTAMP NOT NULL,
    execution_date DATE NOT NULL,
    position_value_usd DECIMAL(18, 2),
    dollar_var_95 DECIMAL(18, 2),
    beta_to_market DECIMAL(8, 4),
    alpha_signal_score DECIMAL(8, 4)
)
USING DELTA
CLUSTER BY (execution_timestamp, symbol);

-- 7. Fact PnL Explain
CREATE TABLE IF NOT EXISTS ${catalog}.${schema}.gold_fact_pnl_explain (
    date_key INT NOT NULL,
    time_key INT NOT NULL,
    instrument_key INT NOT NULL,
    regime_key INT NOT NULL,
    pnl_fact_id STRING NOT NULL,
    execution_id STRING NOT NULL,
    symbol STRING NOT NULL,
    portfolio_id STRING NOT NULL,
    execution_timestamp TIMESTAMP NOT NULL,
    execution_date DATE NOT NULL,
    gross_pnl_usd DECIMAL(18, 2),
    net_pnl_usd DECIMAL(18, 2),
    market_drift_pnl_usd DECIMAL(18, 2),
    alpha_pnl_usd DECIMAL(18, 2),
    cost_drag_usd DECIMAL(18, 2)
)
USING DELTA
CLUSTER BY (execution_date, symbol);