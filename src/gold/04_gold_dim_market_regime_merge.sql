
MERGE INTO {catalog}.{schema}.gold_dim_market_regime AS target
USING (
    SELECT 
        abs(hash(CONCAT(DATE_FORMAT(execution_timestamp, 'yyyyMMdd_HH'), '_', COALESCE(symbol, 'ALL')))) AS regime_key,
        CONCAT('REGIME_', DATE_FORMAT(execution_timestamp, 'yyyyMMdd_HH')) AS regime_id,
        CASE 
            WHEN avg(alpha_signal_value) > 0.3 THEN 'HIGH_VOLATILITY' 
            ELSE 'LOW_VOLATILITY' 
        END AS volatility_state,
        CASE 
            WHEN count(order_id) >= 3 THEN 'TRENDING_UP' 
            ELSE 'MEAN_REVERTING' 
        END AS trend_state,
        CASE 
            WHEN sum(order_quantity) > 5000 THEN 'HIGH_VOLUME' 
            ELSE 'DRY_LIQUIDITY' 
        END AS volume_profile,
        min(execution_timestamp) AS effective_timestamp,
        current_timestamp() AS created_at
    FROM {catalog}.{schema}.silver_enriched_executions
    WHERE execution_timestamp IS NOT NULL
    GROUP BY DATE_FORMAT(execution_timestamp, 'yyyyMMdd_HH'), symbol
) AS source
ON target.regime_id = source.regime_id AND target.regime_key = source.regime_key

WHEN NOT MATCHED THEN
INSERT (
    regime_key,
    regime_id,
    volatility_state,
    trend_state,
    volume_profile,
    effective_timestamp,
    created_at
)
VALUES (
    source.regime_key,
    source.regime_id,
    source.volatility_state,
    source.trend_state,
    source.volume_profile,
    source.effective_timestamp,
    source.created_at
);