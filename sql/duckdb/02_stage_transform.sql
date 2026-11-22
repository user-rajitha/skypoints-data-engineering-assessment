-- ============================================================================
-- DELIVERABLE 2: STAGING LOAD & DERIVED COLUMNS (DuckDB Local Execution)
-- Computes Age (from DOB) and Stale_Member (> 90 days since Last_Flight_Date)
-- Applies "latest record wins" deduplication into stg_members
-- ============================================================================

INSERT INTO stg_members (
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
    age,
    is_active,
    stale_member,
    source_file_name,
    record_updated_at
)
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
        WHEN dob IS NOT NULL THEN DATE_DIFF('year', dob, CURRENT_DATE)
             - CASE WHEN STRFTIME(CURRENT_DATE, '%m%d') < STRFTIME(dob, '%m%d') THEN 1 ELSE 0 END
        ELSE NULL
    END AS age,
    is_active,
    CASE
        WHEN last_flight_date IS NOT NULL AND DATE_DIFF('day', last_flight_date, CURRENT_DATE) > 90 THEN TRUE
        ELSE FALSE
    END AS stale_member,
    source_file_name,
    record_updated_at
FROM validated_members_load
QUALIFY ROW_NUMBER() OVER (
    PARTITION BY member_id
    ORDER BY record_updated_at DESC, last_flight_date DESC NULLS LAST, enrollment_date DESC
) = 1
ON CONFLICT (member_id) DO UPDATE SET
    member_name       = EXCLUDED.member_name,
    enrollment_date   = EXCLUDED.enrollment_date,
    last_flight_date  = EXCLUDED.last_flight_date,
    tier_code         = EXCLUDED.tier_code,
    agent_name        = COALESCE(EXCLUDED.agent_name, stg_members.agent_name),
    state             = EXCLUDED.state,
    country_iso3      = EXCLUDED.country_iso3,
    post_code         = COALESCE(EXCLUDED.post_code, stg_members.post_code),
    dob               = COALESCE(EXCLUDED.dob, stg_members.dob),
    age               = EXCLUDED.age,
    is_active         = EXCLUDED.is_active,
    stale_member      = EXCLUDED.stale_member,
    source_file_name  = EXCLUDED.source_file_name,
    record_updated_at = EXCLUDED.record_updated_at
WHERE EXCLUDED.record_updated_at >= stg_members.record_updated_at;
