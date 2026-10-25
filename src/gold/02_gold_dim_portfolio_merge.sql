MERGE INTO {catalog}.{schema}.gold_dim_portfolio AS target
USING (
    SELECT DISTINCT
        portfolio_id,
        CONCAT(portfolio_id, '_', DATE_FORMAT(current_date(), 'yyyyMMdd')) AS portfolio_key,
        CASE portfolio_id
            WHEN 'PORT_A' THEN 'Alpha Growth Fund'
            WHEN 'PORT_B' THEN 'Global Quantitative Arbitrage'
            WHEN 'PORT_C' THEN 'High-Frequency Momentum'
            ELSE CONCAT('Portfolio ', portfolio_id)
        END AS portfolio_name,
        CASE portfolio_id
            WHEN 'PORT_A' THEN 'Long-Short Equity'
            WHEN 'PORT_B' THEN 'Statistical Arbitrage'
            WHEN 'PORT_C' THEN 'Momentum Cross-Asset'
            ELSE 'Core Strategy'
        END AS strategy_name,
        CASE portfolio_id
            WHEN 'PORT_A' THEN 'Sarah Jenkins'
            WHEN 'PORT_B' THEN 'Marcus Chen'
            WHEN 'PORT_C' THEN 'Elena Rostova'
            ELSE 'Desk Lead'
        END AS desk_owner,
        CASE portfolio_id
            WHEN 'PORT_A' THEN 5000000.00
            WHEN 'PORT_B' THEN 10000000.00
            WHEN 'PORT_C' THEN 2500000.00
            ELSE 1000000.00
        END AS risk_limit_amount,
        current_date() AS effective_start_date,
        CAST(NULL AS DATE) AS effective_end_date,
        'Y' AS is_current
    FROM {catalog}.{schema}.silver_enriched_executions
    WHERE portfolio_id IS NOT NULL
) AS source
ON target.portfolio_id = source.portfolio_id AND target.is_current = 'Y'

-- WHEN MATCHED: If attributes changed, close out the old active record (SCD Type 2 update)
WHEN MATCHED AND (
    target.portfolio_name <> source.portfolio_name OR
    target.strategy_name <> source.strategy_name OR
    target.risk_limit_amount <> source.risk_limit_amount
) THEN
UPDATE SET 
    target.effective_end_date = current_date(),
    target.is_current = 'N'

-- WHEN NOT MATCHED: Insert brand new portfolios or new active versions resulting from changes
WHEN NOT MATCHED THEN
INSERT (
    portfolio_key,
    portfolio_id,
    portfolio_name,
    strategy_name,
    desk_owner,
    risk_limit_amount,
    effective_start_date,
    effective_end_date,
    is_current
)
VALUES (
    source.portfolio_key,
    source.portfolio_id,
    source.portfolio_name,
    source.strategy_name,
    source.desk_owner,
    source.risk_limit_amount,
    source.effective_start_date,
    source.effective_end_date,
    source.is_current
);