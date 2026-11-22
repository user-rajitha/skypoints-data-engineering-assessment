-- ============================================================================
-- DELIVERABLE 1: DUCKDB DDL (Local Execution & Live Interview Demo)
-- ============================================================================

CREATE TABLE IF NOT EXISTS raw_member_feed (
    record_type       VARCHAR,
    member_name       VARCHAR,
    member_id         VARCHAR,
    enrollment_date   VARCHAR,
    last_flight_date  VARCHAR,
    tier_code         VARCHAR,
    agent_name        VARCHAR,
    state             VARCHAR,
    country           VARCHAR,
    post_code         VARCHAR,
    dob               VARCHAR,
    is_active         VARCHAR,
    source_file_name  VARCHAR,
    ingested_at       TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS raw_redemptions_json (
    raw_payload       JSON,
    source_file_name  VARCHAR,
    ingested_at       TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS quarantine_member_records (
    raw_record        VARCHAR,
    failure_reasons   VARCHAR,
    source_file_name  VARCHAR,
    quarantined_at    TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS validated_members_load (
    member_id         VARCHAR(18),
    member_name       VARCHAR(255),
    enrollment_date   DATE,
    last_flight_date  DATE,
    tier_code         VARCHAR(5),
    agent_name        VARCHAR(255),
    state             VARCHAR(5),
    country_iso3      VARCHAR(3),
    post_code         INTEGER,
    dob               DATE,
    is_active         VARCHAR(1),
    source_file_name  VARCHAR(255),
    record_updated_at TIMESTAMP
);

CREATE TABLE IF NOT EXISTS stg_members (
    member_id         VARCHAR(18) PRIMARY KEY,
    member_name       VARCHAR(255) NOT NULL,
    enrollment_date   DATE NOT NULL,
    last_flight_date  DATE,
    tier_code         VARCHAR(5),
    agent_name        VARCHAR(255),
    state             VARCHAR(5),
    country_iso3      VARCHAR(3) NOT NULL,
    post_code         INTEGER,
    dob               DATE,
    age               INTEGER,
    is_active         VARCHAR(1),
    stale_member      BOOLEAN,
    source_file_name  VARCHAR(255),
    record_updated_at TIMESTAMP NOT NULL
);

CREATE TABLE IF NOT EXISTS table_india (
    member_id         VARCHAR(18) PRIMARY KEY,
    member_name       VARCHAR(255) NOT NULL,
    enrollment_date   DATE NOT NULL,
    last_flight_date  DATE,
    tier_code         VARCHAR(5),
    agent_name        VARCHAR(255),
    state             VARCHAR(5),
    post_code         INTEGER,
    dob               DATE,
    age               INTEGER,
    is_active         VARCHAR(1),
    stale_member      BOOLEAN,
    updated_at        TIMESTAMP NOT NULL
);

CREATE TABLE IF NOT EXISTS table_usa (
    member_id         VARCHAR(18) PRIMARY KEY,
    member_name       VARCHAR(255) NOT NULL,
    enrollment_date   DATE NOT NULL,
    last_flight_date  DATE,
    tier_code         VARCHAR(5),
    agent_name        VARCHAR(255),
    state             VARCHAR(5),
    post_code         INTEGER,
    dob               DATE,
    age               INTEGER,
    is_active         VARCHAR(1),
    stale_member      BOOLEAN,
    updated_at        TIMESTAMP NOT NULL
);

CREATE TABLE IF NOT EXISTS table_australia (
    member_id         VARCHAR(18) PRIMARY KEY,
    member_name       VARCHAR(255) NOT NULL,
    enrollment_date   DATE NOT NULL,
    last_flight_date  DATE,
    tier_code         VARCHAR(5),
    agent_name        VARCHAR(255),
    state             VARCHAR(5),
    post_code         INTEGER,
    dob               DATE,
    age               INTEGER,
    is_active         VARCHAR(1),
    stale_member      BOOLEAN,
    updated_at        TIMESTAMP NOT NULL
);

CREATE TABLE IF NOT EXISTS table_canada (
    member_id         VARCHAR(18) PRIMARY KEY,
    member_name       VARCHAR(255) NOT NULL,
    enrollment_date   DATE NOT NULL,
    last_flight_date  DATE,
    tier_code         VARCHAR(5),
    agent_name        VARCHAR(255),
    state             VARCHAR(5),
    post_code         INTEGER,
    dob               DATE,
    age               INTEGER,
    is_active         VARCHAR(1),
    stale_member      BOOLEAN,
    updated_at        TIMESTAMP NOT NULL
);

CREATE TABLE IF NOT EXISTS table_philippines (
    member_id         VARCHAR(18) PRIMARY KEY,
    member_name       VARCHAR(255) NOT NULL,
    enrollment_date   DATE NOT NULL,
    last_flight_date  DATE,
    tier_code         VARCHAR(5),
    agent_name        VARCHAR(255),
    state             VARCHAR(5),
    post_code         INTEGER,
    dob               DATE,
    age               INTEGER,
    is_active         VARCHAR(1),
    stale_member      BOOLEAN,
    updated_at        TIMESTAMP NOT NULL
);

CREATE TABLE IF NOT EXISTS fact_redemptions (
    txn_id            VARCHAR(32) PRIMARY KEY,
    member_id         VARCHAR(18) NOT NULL,
    feed_date         DATE NOT NULL,
    txn_date          DATE NOT NULL,
    partner           VARCHAR(100) NOT NULL,
    miles_redeemed    DOUBLE NOT NULL,
    status            VARCHAR(20) NOT NULL,
    ingested_at       TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

