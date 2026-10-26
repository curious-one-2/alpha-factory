-- Unity Catalog Silver Layer Schema Initialization
CREATE SCHEMA IF NOT EXISTS ${catalog}.${schema};

-- 1. streaming_source data
CREATE TABLE IF NOT EXISTS ${catalog}.${schema}.silver_cleansed_executions (
    trade_id STRING NOT NULL,
    order_id LONG NOT NULL,
    symbol STRING NOT NULL,
    side STRING NOT NULL,
    order_quantity INT NOT NULL,
    order_submission_price DECIMAL(18, 2) NOT NULL,
    order_submission_timestamp TIMESTAMP NOT NULL,
    execution_price DECIMAL(18, 2),
    execution_timestamp TIMESTAMP,
    venue_id STRING,
    alpha_signal_value LONG,
    portfolio_id STRING NOT NULL,
    insert_timestamp TIMESTAMP
)
USING DELTA
CLUSTER BY (symbol, execution_timestamp);


CREATE TABLE IF NOT EXISTS ${catalog}.${schema}.silver_enriched_executions (
    trade_id STRING NOT NULL,
    order_id LONG NOT NULL,
    symbol STRING NOT NULL,
    side STRING NOT NULL,
    order_quantity INT NOT NULL,
    order_submission_price DECIMAL(18, 2) NOT NULL,
    order_submission_timestamp TIMESTAMP NOT NULL,
    execution_price DECIMAL(18, 2) NOT NULL,
    execution_timestamp TIMESTAMP NOT NULL,
    venue_id STRING NOT NULL,
    slippage_amount DECIMAL(18, 2) NOT NULL,
    transaction_costs DECIMAL(18, 2) NOT NULL,
    session_bucket STRING NOT NULL,
    alpha_signal_value DOUBLE,
    portfolio_id STRING NOT NULL,
    updated_at TIMESTAMP NOT NULL
)
USING DELTA
CLUSTER BY (execution_timestamp, symbol);


CREATE TABLE IF NOT EXISTS {catalog}.{schema}.silver_rejected_executions (
    trade_id STRING,
    order_id BIGINT,
    symbol STRING,
    side STRING,
    order_quantity INT,
    order_submission_price DECIMAL(18,2),
    order_submission_timestamp TIMESTAMP,
    execution_price DECIMAL(18,2),
    execution_timestamp TIMESTAMP,
    venue_id STRING,
    alpha_signal_value BIGINT,
    portfolio_id STRING,
    rejection_timestamp TIMESTAMP,
    rejection_reason STRING
)
USING DELTA;