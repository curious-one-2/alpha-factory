INSERT INTO {catalog}.{schema}.silver_rejected_executions
SELECT 
    trade_id,
    order_id,
    symbol,
    side,
    order_quantity,
    order_submission_price,
    order_submission_timestamp,
    execution_price,
    execution_timestamp,
    venue_id,
    alpha_signal_value,
    portfolio_id,
    current_timestamp() AS rejection_timestamp,
    'Null primary key detected (trade_id, order_id, symbol, or side)' AS rejection_reason
FROM bronze_view
WHERE trade_id IS NULL 
   OR order_id IS NULL 
   OR symbol IS NULL 
   OR side IS NULL;