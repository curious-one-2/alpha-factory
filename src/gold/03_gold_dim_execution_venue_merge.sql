MERGE INTO {catalog}.{schema}.gold_dim_execution_venue AS target
USING (
    SELECT DISTINCT
        abs(hash(venue_id)) AS venue_key,
        venue_id,
        CASE venue_id
            WHEN 'XNYS' THEN 'New York Stock Exchange'
            WHEN 'XNAS' THEN 'Nasdaq Stock Market'
            WHEN 'BATS' THEN 'Cboe BZX Exchange'
            WHEN 'ARCA' THEN 'NYSE Arca'
            ELSE CONCAT('Execution Venue ', venue_id)
        END AS venue_name,
        CASE venue_id
            WHEN 'XNYS' THEN 'Lit Exchange'
            WHEN 'XNAS' THEN 'Lit Exchange'
            WHEN 'BATS' THEN 'ECN'
            WHEN 'ARCA' THEN 'ECN'
            ELSE 'Alternative Trading System'
        END AS venue_type,
        venue_id AS mic_code,
        0.001500 AS estimated_rebate_cost,
        true AS is_active
    FROM {catalog}.{schema}.silver_enriched_executions
    WHERE venue_id IS NOT NULL
) AS source
ON target.venue_id = source.venue_id

-- Update attributes if they change over time
WHEN MATCHED THEN
UPDATE SET 
    target.venue_name = source.venue_name,
    target.venue_type = source.venue_type,
    target.estimated_rebate_cost = source.estimated_rebate_cost,
    target.is_active = source.is_active

-- Insert new venues as they appear in executions
WHEN NOT MATCHED THEN
INSERT (
    venue_key,
    venue_id,
    venue_name,
    venue_type,
    mic_code,
    estimated_rebate_cost,
    is_active
)
VALUES (
    source.venue_key,
    source.venue_id,
    source.venue_name,
    source.venue_type,
    source.mic_code,
    source.estimated_rebate_cost,
    source.is_active
);