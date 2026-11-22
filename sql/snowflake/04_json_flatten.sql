-- ============================================================================
-- DELIVERABLE 4: PARSE JSON REDEMPTION FEED & JOIN TO MEMBERS (Snowflake SQL)
-- Uses Snowflake VARIANT + LATERAL FLATTEN for billion-scale JSON ingestion
-- ============================================================================

MERGE INTO fact_redemptions AS tgt
USING (
    SELECT
        txn.value:txn_id::VARCHAR(32)          AS txn_id,
        raw.raw_payload:member_id::VARCHAR(18) AS member_id,
        TO_DATE(raw.raw_payload:feed_date::VARCHAR, 'YYYYMMDD') AS feed_date,
        TO_DATE(txn.value:txn_date::VARCHAR, 'YYYYMMDD')        AS txn_date,
        txn.value:partner::VARCHAR(100)        AS partner,
        txn.value:miles_redeemed::NUMBER(12,2) AS miles_redeemed,
        txn.value:status::VARCHAR(20)          AS status
    FROM raw_redemptions_json raw,
         LATERAL FLATTEN(input => raw.raw_payload:redemptions) txn
    QUALIFY ROW_NUMBER() OVER (PARTITION BY txn_id ORDER BY feed_date DESC) = 1
) AS src
ON tgt.txn_id = src.txn_id
WHEN MATCHED THEN UPDATE SET
    tgt.status         = src.status,
    tgt.miles_redeemed = src.miles_redeemed,
    tgt.feed_date      = src.feed_date
WHEN NOT MATCHED THEN INSERT (
    txn_id, member_id, feed_date, txn_date, partner, miles_redeemed, status
) VALUES (
    src.txn_id, src.member_id, src.feed_date, src.txn_date, src.partner, src.miles_redeemed, src.status
);

-- Join back to Staging (or UNION ALL of country tables) for BI & Loyalty Analytics
CREATE OR REPLACE VIEW vw_member_redemptions AS
SELECT
    r.txn_id,
    r.txn_date,
    r.partner,
    r.miles_redeemed,
    r.status,
    r.member_id,
    m.member_name,
    m.tier_code,
    m.country_iso3 AS country,
    m.age,
    m.stale_member
FROM fact_redemptions r
LEFT JOIN stg_members m
    ON r.member_id = m.member_id;
