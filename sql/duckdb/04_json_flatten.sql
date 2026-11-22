-- ============================================================================
-- DELIVERABLE 4: PARSE JSON REDEMPTION FEED & JOIN TO MEMBERS (DuckDB SQL)
-- Flattens nested `redemptions` array into `fact_redemptions`
-- ============================================================================

INSERT INTO fact_redemptions (
    txn_id,
    member_id,
    feed_date,
    txn_date,
    partner,
    miles_redeemed,
    status
)
SELECT
    json_extract_string(txn.value, '$.txn_id') AS txn_id,
    json_extract_string(raw_payload, '$.member_id') AS member_id,
    STRPTIME(json_extract_string(raw_payload, '$.feed_date'), '%Y%m%d')::DATE AS feed_date,
    STRPTIME(json_extract_string(txn.value, '$.txn_date'), '%Y%m%d')::DATE AS txn_date,
    json_extract_string(txn.value, '$.partner') AS partner,
    CAST(json_extract(txn.value, '$.miles_redeemed') AS DOUBLE) AS miles_redeemed,
    json_extract_string(txn.value, '$.status') AS status
FROM raw_redemptions_json,
     UNNEST(json_extract(raw_payload, '$.redemptions')::JSON[]) AS txn(value)
ON CONFLICT (txn_id) DO UPDATE SET
    status         = EXCLUDED.status,
    miles_redeemed = EXCLUDED.miles_redeemed,
    feed_date      = EXCLUDED.feed_date;

-- Analytical View joining flattened redemptions back to unified member profiles
CREATE OR REPLACE VIEW vw_member_redemptions AS
WITH all_country_members AS (
    SELECT 'IND' AS country, * FROM table_india
    UNION ALL SELECT 'USA' AS country, * FROM table_usa
    UNION ALL SELECT 'AUS' AS country, * FROM table_australia
    UNION ALL SELECT 'CAN' AS country, * FROM table_canada
    UNION ALL SELECT 'PHL' AS country, * FROM table_philippines
)
SELECT
    r.txn_id,
    r.txn_date,
    r.feed_date,
    r.partner,
    r.miles_redeemed,
    r.status,
    r.member_id,
    m.member_name,
    m.tier_code,
    m.country,
    m.age,
    m.stale_member
FROM fact_redemptions r
LEFT JOIN all_country_members m
    ON r.member_id = m.member_id;
