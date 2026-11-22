-- ============================================================================
-- DELIVERABLE 3: COUNTRY SPLIT & "LATEST RECORD WINS" (DuckDB Local Execution)
-- 1. Upserts members into their latest country table
-- 2. Removes members from previous country tables if they relocated
-- ============================================================================

-- INDIA
INSERT INTO table_india
SELECT member_id, member_name, enrollment_date, last_flight_date, tier_code, agent_name, state, post_code, dob, age, is_active, stale_member, record_updated_at
FROM stg_members WHERE country_iso3 = 'IND'
ON CONFLICT (member_id) DO UPDATE SET
    member_name = EXCLUDED.member_name, last_flight_date = EXCLUDED.last_flight_date,
    tier_code = EXCLUDED.tier_code, state = EXCLUDED.state, post_code = EXCLUDED.post_code,
    age = EXCLUDED.age, is_active = EXCLUDED.is_active, stale_member = EXCLUDED.stale_member,
    updated_at = EXCLUDED.updated_at;

DELETE FROM table_india WHERE member_id IN (SELECT member_id FROM stg_members WHERE country_iso3 <> 'IND');

-- USA
INSERT INTO table_usa
SELECT member_id, member_name, enrollment_date, last_flight_date, tier_code, agent_name, state, post_code, dob, age, is_active, stale_member, record_updated_at
FROM stg_members WHERE country_iso3 = 'USA'
ON CONFLICT (member_id) DO UPDATE SET
    member_name = EXCLUDED.member_name, last_flight_date = EXCLUDED.last_flight_date,
    tier_code = EXCLUDED.tier_code, state = EXCLUDED.state, post_code = EXCLUDED.post_code,
    age = EXCLUDED.age, is_active = EXCLUDED.is_active, stale_member = EXCLUDED.stale_member,
    updated_at = EXCLUDED.updated_at;

DELETE FROM table_usa WHERE member_id IN (SELECT member_id FROM stg_members WHERE country_iso3 <> 'USA');

-- AUSTRALIA
INSERT INTO table_australia
SELECT member_id, member_name, enrollment_date, last_flight_date, tier_code, agent_name, state, post_code, dob, age, is_active, stale_member, record_updated_at
FROM stg_members WHERE country_iso3 = 'AUS'
ON CONFLICT (member_id) DO UPDATE SET
    member_name = EXCLUDED.member_name, last_flight_date = EXCLUDED.last_flight_date,
    tier_code = EXCLUDED.tier_code, state = EXCLUDED.state, post_code = EXCLUDED.post_code,
    age = EXCLUDED.age, is_active = EXCLUDED.is_active, stale_member = EXCLUDED.stale_member,
    updated_at = EXCLUDED.updated_at;

DELETE FROM table_australia WHERE member_id IN (SELECT member_id FROM stg_members WHERE country_iso3 <> 'AUS');

-- CANADA
INSERT INTO table_canada
SELECT member_id, member_name, enrollment_date, last_flight_date, tier_code, agent_name, state, post_code, dob, age, is_active, stale_member, record_updated_at
FROM stg_members WHERE country_iso3 = 'CAN'
ON CONFLICT (member_id) DO UPDATE SET
    member_name = EXCLUDED.member_name, last_flight_date = EXCLUDED.last_flight_date,
    tier_code = EXCLUDED.tier_code, state = EXCLUDED.state, post_code = EXCLUDED.post_code,
    age = EXCLUDED.age, is_active = EXCLUDED.is_active, stale_member = EXCLUDED.stale_member,
    updated_at = EXCLUDED.updated_at;

DELETE FROM table_canada WHERE member_id IN (SELECT member_id FROM stg_members WHERE country_iso3 <> 'CAN');

-- PHILIPPINES
INSERT INTO table_philippines
SELECT member_id, member_name, enrollment_date, last_flight_date, tier_code, agent_name, state, post_code, dob, age, is_active, stale_member, record_updated_at
FROM stg_members WHERE country_iso3 = 'PHL'
ON CONFLICT (member_id) DO UPDATE SET
    member_name = EXCLUDED.member_name, last_flight_date = EXCLUDED.last_flight_date,
    tier_code = EXCLUDED.tier_code, state = EXCLUDED.state, post_code = EXCLUDED.post_code,
    age = EXCLUDED.age, is_active = EXCLUDED.is_active, stale_member = EXCLUDED.stale_member,
    updated_at = EXCLUDED.updated_at;

DELETE FROM table_philippines WHERE member_id IN (SELECT member_id FROM stg_members WHERE country_iso3 <> 'PHL');
