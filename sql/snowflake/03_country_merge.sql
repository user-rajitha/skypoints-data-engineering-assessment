-- ============================================================================
-- DELIVERABLE 3: COUNTRY SPLIT & "LATEST RECORD WINS" (Snowflake Production SQL)
-- Uses Snowflake MERGE + cross-country DELETE for moved members
-- ============================================================================

-- 1. INDIA
MERGE INTO table_india AS tgt
USING (SELECT * FROM stg_members WHERE country_iso3 = 'IND') AS src
ON tgt.member_id = src.member_id
WHEN MATCHED AND src.record_updated_at >= tgt.updated_at THEN UPDATE SET
    tgt.member_name = src.member_name, tgt.last_flight_date = src.last_flight_date,
    tgt.tier_code = src.tier_code, tgt.state = src.state, tgt.post_code = src.post_code,
    tgt.age = src.age, tgt.is_active = src.is_active, tgt.stale_member = src.stale_member,
    tgt.updated_at = src.record_updated_at
WHEN NOT MATCHED THEN INSERT VALUES (
    src.member_id, src.member_name, src.enrollment_date, src.last_flight_date,
    src.tier_code, src.agent_name, src.state, src.post_code, src.dob, src.age,
    src.is_active, src.stale_member, src.record_updated_at
);
DELETE FROM table_india tgt USING stg_members src WHERE tgt.member_id = src.member_id AND src.country_iso3 <> 'IND';

-- 2. USA
MERGE INTO table_usa AS tgt
USING (SELECT * FROM stg_members WHERE country_iso3 = 'USA') AS src
ON tgt.member_id = src.member_id
WHEN MATCHED AND src.record_updated_at >= tgt.updated_at THEN UPDATE SET
    tgt.member_name = src.member_name, tgt.last_flight_date = src.last_flight_date,
    tgt.tier_code = src.tier_code, tgt.state = src.state, tgt.post_code = src.post_code,
    tgt.age = src.age, tgt.is_active = src.is_active, tgt.stale_member = src.stale_member,
    tgt.updated_at = src.record_updated_at
WHEN NOT MATCHED THEN INSERT VALUES (
    src.member_id, src.member_name, src.enrollment_date, src.last_flight_date,
    src.tier_code, src.agent_name, src.state, src.post_code, src.dob, src.age,
    src.is_active, src.stale_member, src.record_updated_at
);
DELETE FROM table_usa tgt USING stg_members src WHERE tgt.member_id = src.member_id AND src.country_iso3 <> 'USA';

-- 3. AUSTRALIA
MERGE INTO table_australia AS tgt
USING (SELECT * FROM stg_members WHERE country_iso3 = 'AUS') AS src
ON tgt.member_id = src.member_id
WHEN MATCHED AND src.record_updated_at >= tgt.updated_at THEN UPDATE SET
    tgt.member_name = src.member_name, tgt.last_flight_date = src.last_flight_date,
    tgt.tier_code = src.tier_code, tgt.state = src.state, tgt.post_code = src.post_code,
    tgt.age = src.age, tgt.is_active = src.is_active, tgt.stale_member = src.stale_member,
    tgt.updated_at = src.record_updated_at
WHEN NOT MATCHED THEN INSERT VALUES (
    src.member_id, src.member_name, src.enrollment_date, src.last_flight_date,
    src.tier_code, src.agent_name, src.state, src.post_code, src.dob, src.age,
    src.is_active, src.stale_member, src.record_updated_at
);
DELETE FROM table_australia tgt USING stg_members src WHERE tgt.member_id = src.member_id AND src.country_iso3 <> 'AUS';

-- 4. CANADA
MERGE INTO table_canada AS tgt
USING (SELECT * FROM stg_members WHERE country_iso3 = 'CAN') AS src
ON tgt.member_id = src.member_id
WHEN MATCHED AND src.record_updated_at >= tgt.updated_at THEN UPDATE SET
    tgt.member_name = src.member_name, tgt.last_flight_date = src.last_flight_date,
    tgt.tier_code = src.tier_code, tgt.state = src.state, tgt.post_code = src.post_code,
    tgt.age = src.age, tgt.is_active = src.is_active, tgt.stale_member = src.stale_member,
    tgt.updated_at = src.record_updated_at
WHEN NOT MATCHED THEN INSERT VALUES (
    src.member_id, src.member_name, src.enrollment_date, src.last_flight_date,
    src.tier_code, src.agent_name, src.state, src.post_code, src.dob, src.age,
    src.is_active, src.stale_member, src.record_updated_at
);
DELETE FROM table_canada tgt USING stg_members src WHERE tgt.member_id = src.member_id AND src.country_iso3 <> 'CAN';

-- 5. PHILIPPINES
MERGE INTO table_philippines AS tgt
USING (SELECT * FROM stg_members WHERE country_iso3 = 'PHL') AS src
ON tgt.member_id = src.member_id
WHEN MATCHED AND src.record_updated_at >= tgt.updated_at THEN UPDATE SET
    tgt.member_name = src.member_name, tgt.last_flight_date = src.last_flight_date,
    tgt.tier_code = src.tier_code, tgt.state = src.state, tgt.post_code = src.post_code,
    tgt.age = src.age, tgt.is_active = src.is_active, tgt.stale_member = src.stale_member,
    tgt.updated_at = src.record_updated_at
WHEN NOT MATCHED THEN INSERT VALUES (
    src.member_id, src.member_name, src.enrollment_date, src.last_flight_date,
    src.tier_code, src.agent_name, src.state, src.post_code, src.dob, src.age,
    src.is_active, src.stale_member, src.record_updated_at
);
DELETE FROM table_philippines tgt USING stg_members src WHERE tgt.member_id = src.member_id AND src.country_iso3 <> 'PHL';
