-- ============================================================================
-- DELIVERABLE 2: STAGING MERGE & DERIVED COLUMNS (Snowflake Production SQL)
-- ============================================================================

MERGE INTO stg_members AS tgt
USING (
    SELECT
        member_id,
        member_name,
        enrollment_date,
        last_flight_date,
        tier_code,
        agent_name,
        state,
        country_iso3,
        post_code,
        dob,
        CASE
            WHEN dob IS NOT NULL THEN FLOOR(DATEDIFF('day', dob, CURRENT_DATE()) / 365.25)
            ELSE NULL
        END AS age,
        is_active,
        CASE
            WHEN last_flight_date IS NOT NULL AND DATEDIFF('day', last_flight_date, CURRENT_DATE()) > 90 THEN TRUE
            ELSE FALSE
        END AS stale_member,
        source_file_name,
        record_updated_at
    FROM validated_members_load
    QUALIFY ROW_NUMBER() OVER (
        PARTITION BY member_id
        ORDER BY record_updated_at DESC, last_flight_date DESC NULLS LAST, enrollment_date DESC
    ) = 1
) AS src
ON tgt.member_id = src.member_id
WHEN MATCHED AND src.record_updated_at >= tgt.record_updated_at THEN UPDATE SET
    tgt.member_name       = src.member_name,
    tgt.enrollment_date   = src.enrollment_date,
    tgt.last_flight_date  = src.last_flight_date,
    tgt.tier_code         = src.tier_code,
    tgt.agent_name        = COALESCE(src.agent_name, tgt.agent_name),
    tgt.state             = src.state,
    tgt.country_iso3      = src.country_iso3,
    tgt.post_code         = COALESCE(src.post_code, tgt.post_code),
    tgt.dob               = COALESCE(src.dob, tgt.dob),
    tgt.age               = src.age,
    tgt.is_active         = src.is_active,
    tgt.stale_member      = src.stale_member,
    tgt.source_file_name  = src.source_file_name,
    tgt.record_updated_at = src.record_updated_at
WHEN NOT MATCHED THEN INSERT (
    member_id, member_name, enrollment_date, last_flight_date, tier_code,
    agent_name, state, country_iso3, post_code, dob, age, is_active,
    stale_member, source_file_name, record_updated_at
) VALUES (
    src.member_id, src.member_name, src.enrollment_date, src.last_flight_date, src.tier_code,
    src.agent_name, src.state, src.country_iso3, src.post_code, src.dob, src.age, src.is_active,
    src.stale_member, src.source_file_name, src.record_updated_at
);
