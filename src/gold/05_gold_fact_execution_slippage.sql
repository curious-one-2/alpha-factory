MERGE INTO {catalog}.{schema}.gold_fact_execution_slippage AS target
USING (
    SELECT 
        CAST(trade_id AS STRING) AS execution_id,
        CAST(order_id AS STRING) AS order_id,
        e.symbol,
        i.instrument_dim_key AS instrument_key,
        e.portfolio_id,
        e.venue_id,
        r.regime_key,
        e.execution_timestamp,
        CAST(e.execution_timestamp AS DATE) AS execution_date,
        -- Generate 8-digit date_key (e.g., 20261001) from execution timestamp/date
        CAST(DATE_FORMAT(e.execution_timestamp, 'yyyyMMdd') AS INT) AS date_key,
        -- Generate integer time_key matching gold_time_dimension (minutes elapsed from midnight)
        CAST((CAST(DATE_FORMAT(e.execution_timestamp, 'H') AS INT) * 60 + CAST(DATE_FORMAT(e.execution_timestamp, 'm') AS INT)) AS INT) AS time_key,
        e.side,
        CAST(e.order_quantity AS DECIMAL(18, 4)) AS order_quantity,
        CAST(e.order_submission_price AS DECIMAL(18, 4)) AS order_submission_price,
        CAST(e.execution_price AS DECIMAL(18, 4)) AS execution_price,
        -- Slippage calculation: positive means unfavorable execution price relative to submission
        CAST(
            CASE 
                WHEN UPPER(e.side) = 'BUY' THEN (e.execution_price - e.order_submission_price) * e.order_quantity
                ELSE (e.order_submission_price - e.execution_price) * e.order_quantity
            END AS DECIMAL(18, 4)
        ) AS slippage_amount,
        -- Transaction costs estimation (e.g., 5 bps fee structure)
        CAST(
            (e.order_quantity * e.execution_price * 0.0005) AS DECIMAL(18, 4)
        ) AS transaction_costs
    FROM {catalog}.{schema}.silver_enriched_executions e
    LEFT JOIN {catalog}.{schema}.gold_dim_instrument i ON e.symbol = i.symbol
    LEFT JOIN {catalog}.{schema}.gold_dim_market_regime r 
        ON CONCAT('REGIME_', DATE_FORMAT(e.execution_timestamp, 'yyyyMMdd_H')) = r.regime_id
    WHERE e.trade_id IS NOT NULL AND e.execution_timestamp IS NOT NULL
) AS source
ON target.execution_id = source.execution_id

-- Insert new execution records into the fact table
WHEN NOT MATCHED THEN
INSERT (
    execution_id,
    order_id,
    symbol,
    instrument_key,
    portfolio_id,
    venue_id,
    regime_key,
    execution_timestamp,
    execution_date,
    date_key,
    time_key,
    side,
    order_quantity,
    order_submission_price,
    execution_price,
    slippage_amount,
    transaction_costs
)
VALUES (
    source.execution_id,
    source.order_id,
    source.symbol,
    source.instrument_key,
    source.portfolio_id,
    source.venue_id,
    source.regime_key,
    source.execution_timestamp,
    source.execution_date,
    source.date_key,
    source.time_key,
    source.side,
    source.order_quantity,
    source.order_submission_price,
    source.execution_price,
    source.slippage_amount,
    source.transaction_costs
);