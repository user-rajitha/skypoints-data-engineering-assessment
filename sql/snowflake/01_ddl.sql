-- ============================================================================
-- DELIVERABLE 1 SNOWFLAKE DDL (Raw, Quarantine, Staging, Redemptions, Targets)
-- ============================================================================

-- 1. Raw Landing Tables (Schema-on-read  all VARCHAR to prevent load failures)
CREATE OR REPLACE TABLE raw_member_feed (
    record_type       VARCHAR(5),
    member_name       VARCHAR(255),
    member_id         VARCHAR(50),
    enrollment_date   VARCHAR(20),
    last_flight_date  VARCHAR(20),
    tier_code         VARCHAR(10),
    agent_name        VARCHAR(255),
    state             VARCHAR(20),
    country           VARCHAR(20),
    post_code         VARCHAR(20),
    dob               VARCHAR(20),
    is_active         VARCHAR(5),
    source_file_name  VARCHAR(255),
    ingested_at       TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP()
);

CREATE OR REPLACE TABLE raw_redemptions_json (
    raw_payload       VARIANT,
    source_file_name  VARCHAR(255),
    ingested_at       TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP()
);

-- 2. Quarantine Table (Captures rejected rows without halting billion-row loads)
CREATE OR REPLACE TABLE quarantine_member_records (
    quarantine_id     NUMBER AUTOINCREMENT,
    raw_record        VARIANT,
    failure_reasons   ARRAY,
    source_file_name  VARCHAR(255),
    quarantined_at    TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP()
);

-- 3. Staging Table (Standardized types + derived Age & Stale_Member flag)
CREATE OR REPLACE TABLE stg_members (
    member_id         VARCHAR(18)   NOT NULL,
    member_name       VARCHAR(255)  NOT NULL,
    enrollment_date   DATE          NOT NULL,
    last_flight_date  DATE,
    tier_code         VARCHAR(5),
    agent_name        VARCHAR(255),
    state             VARCHAR(5),
    country_iso3      VARCHAR(3)    NOT NULL,
    post_code         INT,
    dob               DATE,
    age               INT,
    is_active         CHAR(1),
    stale_member      BOOLEAN,
    source_file_name  VARCHAR(255),
    record_updated_at TIMESTAMP_NTZ NOT NULL,
    CONSTRAINT pk_stg_members PRIMARY KEY (member_id)
)
CLUSTER BY (country_iso3, member_id);

-- 4. Country-Specific Target Tables (Clustered on member_id for fast MERGEDELETE)
CREATE OR REPLACE TABLE table_india (
    member_id         VARCHAR(18)   NOT NULL PRIMARY KEY,
    member_name       VARCHAR(255)  NOT NULL,
    enrollment_date   DATE          NOT NULL,
    last_flight_date  DATE,
    tier_code         VARCHAR(5),
    agent_name        VARCHAR(255),
    state             VARCHAR(5),
    post_code         INT,
    dob               DATE,
    age               INT,
    is_active         CHAR(1),
    stale_member      BOOLEAN,
    updated_at        TIMESTAMP_NTZ NOT NULL
)
CLUSTER BY (member_id);

CREATE OR REPLACE TABLE table_usa LIKE table_india;
CREATE OR REPLACE TABLE table_australia LIKE table_india;
CREATE OR REPLACE TABLE table_canada LIKE table_india;
CREATE OR REPLACE TABLE table_philippines LIKE table_india;

-- 5. Flattened Partner Redemption Transactions
CREATE OR REPLACE TABLE fact_redemptions (
    txn_id            VARCHAR(32)   NOT NULL PRIMARY KEY,
    member_id         VARCHAR(18)   NOT NULL,
    feed_date         DATE          NOT NULL,
    txn_date          DATE          NOT NULL,
    partner           VARCHAR(100)  NOT NULL,
    miles_redeemed    NUMBER(12, 2) NOT NULL,
    status            VARCHAR(20)   NOT NULL,
    ingested_at       TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP()
)
CLUSTER BY (txn_date, member_id);
