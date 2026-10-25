MERGE INTO {catalog}.{schema}.silver_enriched_executions AS target
USING (
    SELECT 
        trade_id, order_id, symbol, side, order_quantity, order_submission_price,
        order_submission_timestamp, execution_price, execution_timestamp, venue_id, portfolio_id,
        -- Derived Fields
        CASE 
            WHEN side = 'BUY' THEN ROUND((execution_price - order_submission_price) * order_quantity, 2)
            ELSE ROUND((order_submission_price - execution_price) * order_quantity, 2)
        END AS slippage_amount,
        ROUND(execution_price * order_quantity * 0.0005, 2) AS transaction_costs,
        CASE 
            WHEN HOUR(execution_timestamp) < 9 OR (HOUR(execution_timestamp) = 9 AND MINUTE(execution_timestamp) < 30) THEN 'Pre-Market'
            WHEN HOUR(execution_timestamp) >= 16 THEN 'After-Hours'
            ELSE 'Market Hours'
        END AS session_bucket,
        alpha_signal_value
    FROM bronze_view
    WHERE trade_id IS NOT NULL 
      AND order_id IS NOT NULL 
      AND symbol IS NOT NULL 
      AND side IS NOT NULL
) AS source
ON target.trade_id = source.trade_id 
   AND target.order_id = source.order_id 
   AND target.symbol = source.symbol 
   AND target.side = source.side

-- UPDATE MATCHED (Note: Spark SQL uses COMMAS ',' between columns, NOT 'AND')
WHEN MATCHED THEN
UPDATE SET 
    target.portfolio_id = source.portfolio_id,
    target.execution_price = source.execution_price,
    target.execution_timestamp = source.execution_timestamp,
    target.venue_id = source.venue_id,
    target.slippage_amount = source.slippage_amount,
    target.transaction_costs = source.transaction_costs,
    target.session_bucket = source.session_bucket,
    target.alpha_signal_value = source.alpha_signal_value,
    target.updated_at = current_timestamp()

-- INSERT NOT MATCHED
WHEN NOT MATCHED THEN
INSERT (
    trade_id, order_id, symbol, side, order_quantity, order_submission_price,
    order_submission_timestamp, execution_price, execution_timestamp, venue_id, 
    slippage_amount, transaction_costs, session_bucket, alpha_signal_value, 
    portfolio_id, updated_at
)
VALUES (
    source.trade_id, source.order_id, source.symbol, source.side, source.order_quantity, source.order_submission_price,
    source.order_submission_timestamp, source.execution_price, source.execution_timestamp, source.venue_id, 
    source.slippage_amount, source.transaction_costs, source.session_bucket, source.alpha_signal_value, 
    source.portfolio_id, current_timestamp()
);