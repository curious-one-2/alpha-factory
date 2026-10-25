MERGE INTO {catalog}.{schema}.gold_fact_pnl_explain AS target
USING (
    SELECT 
        CAST(abs(hash(CONCAT(COALESCE(trade_id, 'UNKNOWN'), '_PNL'))) AS STRING) AS pnl_fact_id,
        CAST(trade_id AS STRING) AS execution_id,
        silver_enriched_executions.symbol,
        i.instrument_dim_key AS instrument_key,
        r.regime_key,
        portfolio_id,
        execution_timestamp,
        CAST(execution_timestamp AS DATE) AS execution_date,
        -- Generate 8-digit date_key (e.g., 20261001) from execution timestamp
        CAST(DATE_FORMAT(execution_timestamp, 'yyyyMMdd') AS INT) AS date_key,
        -- Generate integer time_key matching gold_time_dimension (minutes elapsed from midnight)
        CAST((CAST(DATE_FORMAT(execution_timestamp, 'H') AS INT) * 60 + CAST(DATE_FORMAT(execution_timestamp, 'm') AS INT)) AS INT) AS time_key,
        -- Gross PnL calculation (directional price variance * quantity)
        CAST(
            CASE 
                WHEN UPPER(side) = 'BUY' THEN (execution_price - order_submission_price) * order_quantity
                ELSE (order_submission_price - execution_price) * order_quantity
            END AS DECIMAL(18, 2)
        ) AS gross_pnl_usd,
        -- Transaction cost drag estimation (5 bps)
        CAST(
            (order_quantity * execution_price * 0.0005) AS DECIMAL(18, 2)
        ) AS cost_drag_usd,
        -- Net PnL (Gross PnL minus transaction costs)
        CAST(
            (CASE 
                WHEN UPPER(side) = 'BUY' THEN (execution_price - order_submission_price) * order_quantity
                ELSE (order_submission_price - execution_price) * order_quantity
             END) - (order_quantity * execution_price * 0.0005) AS DECIMAL(18, 2)
        ) AS net_pnl_usd,
        -- Alpha PnL attribution based on signal weight
        CAST(
            ((CASE 
                WHEN UPPER(side) = 'BUY' THEN (execution_price - order_submission_price) * order_quantity
                ELSE (order_submission_price - execution_price) * order_quantity
              END) * COALESCE(alpha_signal_value, 0.0)) AS DECIMAL(18, 2)
        ) AS alpha_pnl_usd,
        -- Market Drift PnL attribution (residual component)
        CAST(
            ((CASE 
                WHEN UPPER(side) = 'BUY' THEN (execution_price - order_submission_price) * order_quantity
                ELSE (order_submission_price - execution_price) * order_quantity
              END) * (1.0 - COALESCE(alpha_signal_value, 0.0))) AS DECIMAL(18, 2)
        ) AS market_drift_pnl_usd
    FROM {catalog}.{schema}.silver_enriched_executions
    LEFT JOIN {catalog}.{schema}.gold_dim_instrument i ON silver_enriched_executions.symbol = i.symbol
    LEFT JOIN {catalog}.{schema}.gold_dim_market_regime r 
        ON CONCAT('REGIME_', DATE_FORMAT(silver_enriched_executions.execution_timestamp, 'yyyyMMdd_H')) = r.regime_id
    WHERE trade_id IS NOT NULL AND execution_timestamp IS NOT NULL
) AS source
ON target.pnl_fact_id = source.pnl_fact_id

-- Insert new PnL explain records into the fact table
WHEN NOT MATCHED THEN
INSERT (
    pnl_fact_id,
    execution_id,
    instrument_key,
    regime_key,
    symbol,
    portfolio_id,
    execution_timestamp,
    execution_date,
    date_key,
    time_key,
    gross_pnl_usd,
    net_pnl_usd,
    market_drift_pnl_usd,
    alpha_pnl_usd,
    cost_drag_usd
)
VALUES (
    source.pnl_fact_id,
    source.execution_id,
    source.instrument_key,
    source.regime_key,
    source.symbol,
    source.portfolio_id,
    source.execution_timestamp,
    source.execution_date,
    source.date_key,
    source.time_key,
    source.gross_pnl_usd,
    source.net_pnl_usd,
    source.market_drift_pnl_usd,
    source.alpha_pnl_usd,
    source.cost_drag_usd
);