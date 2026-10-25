MERGE INTO {catalog}.{schema}.gold_dim_instrument AS target
USING (
    SELECT DISTINCT 
        abs(hash(symbol)) AS instrument_dim_key,
        symbol,
        'Equity' AS asset_class,
        CASE 
            WHEN symbol IN ('AAPL', 'MSFT', 'GOOGL', 'AMZN', 'NVDA', 'META') THEN 'Technology'
            WHEN symbol IN ('JPM', 'BAC', 'GS', 'MS') THEN 'Financials'
            WHEN symbol IN ('XOM', 'CVX') THEN 'Energy'
            ELSE 'General Equities'
        END AS sector,
        'Equities & Derivatives' AS industry,
        'NASDAQ/NYSE' AS exchange,
        'Large Cap' AS market_cap_tier,
        'USD' AS currency,
        true AS is_active,
        current_timestamp() AS created_at
    FROM {catalog}.{schema}.silver_enriched_executions
    WHERE symbol IS NOT NULL
) AS source
ON target.symbol = source.symbol

-- Update attributes if they change
WHEN MATCHED THEN
UPDATE SET 
    target.is_active = source.is_active

-- Insert new instruments with their generated surrogate key
WHEN NOT MATCHED THEN
INSERT (
    instrument_dim_key,
    symbol, 
    asset_class, 
    sector, 
    industry, 
    exchange, 
    market_cap_tier, 
    currency, 
    is_active, 
    created_at
)
VALUES (
    source.instrument_dim_key,
    source.symbol, 
    source.asset_class, 
    source.sector, 
    source.industry, 
    source.exchange, 
    source.market_cap_tier, 
    source.currency, 
    source.is_active, 
    source.created_at
);