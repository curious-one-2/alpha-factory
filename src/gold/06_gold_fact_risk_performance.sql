MERGE INTO {catalog}.{schema}.gold_fact_risk_performance AS target
USING (
    SELECT 
        CAST(abs(hash(CONCAT(COALESCE(trade_id, 'UNKNOWN'), '_', COALESCE(symbol, 'UNKNOWN')))) AS STRING) AS risk_fact_id,
        CAST(trade_id AS STRING) AS execution_id,
        symbol,
        portfolio_id,
        execution_timestamp,
        CAST(execution_timestamp AS DATE) AS execution_date,
        -- Generate 8-digit date_key (e.g., 20261001) from execution timestamp
        CAST(DATE_FORMAT(execution_timestamp, 'yyyyMMdd') AS INT) AS date_key,
        -- Generate integer time_key matching gold_time_dimension (minutes elapsed from midnight)
        CAST((CAST(DATE_FORMAT(execution_timestamp, 'H') AS INT) * 60 + CAST(DATE_FORMAT(execution_timestamp, 'm') AS INT)) AS INT) AS time_key,
        CAST((order_quantity * execution_price) AS DECIMAL(18, 2)) AS position_value_usd,
        -- Estimated 1-day 95% Dollar VaR (modeled at ~2% of position notional value)
        CAST((order_quantity * execution_price * 0.02) AS DECIMAL(18, 2)) AS dollar_var_95,
        -- Estimated asset beta relative to market benchmark
        CAST(
            CASE 
                WHEN symbol IN ('NVDA', 'TSLA', 'AMZN') THEN 1.45
                WHEN symbol IN ('AAPL', 'MSFT', 'GOOGL', 'META') THEN 1.15
                WHEN symbol IN ('JPM', 'BAC', 'GS', 'MS') THEN 0.95
                ELSE 1.00
            END AS DECIMAL(8, 4)
        ) AS beta_to_market,
        CAST(alpha_signal_value AS DECIMAL(8, 4)) AS alpha_signal_score
    FROM {catalog}.{schema}.silver_enriched_executions
    WHERE trade_id IS NOT NULL AND execution_timestamp IS NOT NULL
) AS source
ON target.risk_fact_id = source.risk_fact_id

-- Insert new risk and performance records into the fact table
WHEN NOT MATCHED THEN
INSERT (
    risk_fact_id,
    execution_id,
    symbol,
    portfolio_id,
    execution_timestamp,
    execution_date,
    date_key,
    time_key,
    position_value_usd,
    dollar_var_95,
    beta_to_market,
    alpha_signal_score
)
VALUES (
    source.risk_fact_id,
    source.execution_id,
    source.symbol,
    source.portfolio_id,
    source.execution_timestamp,
    source.execution_date,
    source.date_key,
    source.time_key,
    source.position_value_usd,
    source.dollar_var_95,
    source.beta_to_market,
    source.alpha_signal_score
);