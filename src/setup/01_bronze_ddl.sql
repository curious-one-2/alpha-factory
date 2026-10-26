-- Unity Catalog Bronze Layer Schema Initialization
CREATE SCHEMA IF NOT EXISTS ${catalog}.${schema};

-- 1. streaming_source data
CREATE TABLE IF NOT EXISTS ${catalog}.${schema}.bronze_streaming_source (
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
    alpha_signal_value DOUBLE,
    portfolio_id STRING NOT NULL,
    insert_timestamp TIMESTAMP,
    _source_file STRING
)
USING DELTA
CLUSTER BY (symbol, execution_timestamp);

CREATE TABLE IF NOT EXISTS {catalog}.{schema}.bronze_quarantined_records (
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
    alpha_signal_value DOUBLE,
    portfolio_id STRING,
    _source_file STRING,
    insert_timestamp TIMESTAMP,
    _rescued_data STRING,
    quarantine_timestamp TIMESTAMP
)
USING DELTA;