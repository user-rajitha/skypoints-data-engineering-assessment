# SkyPoints Loyalty Data Pipeline — Incubyte Data Engineer Assessment

A production-oriented ETL/ELT pipeline built for **SkyPoints**, a global airline loyalty program processing daily member profile feeds (pipe-delimited flat files, regional CSV/XLSX extracts) and partner airline mileage redemption JSON feeds into country-partitioned target tables (`table_india`, `table_usa`, `table_australia`, `table_canada`, `table_philippines`).

---

## 1. Architecture & Design Decisions

```text
  [Source Feeds: Pipe-Delimited .dat | Regional .csv/.xlsx | Partner .json]
                                      │
                                      ▼
                    ┌───────────────────────────────────┐
                    │   Python Ingestion & Validation   │
                    │  (src/ingestion.py, validation.py) │
                    └─────────────────┬─────────────────┘
                                      │
                     ┌────────────────┴────────────────┐
                     ▼                                 ▼
       ┌──────────────────────────┐      ┌──────────────────────────┐
       │ quarantine_member_records│      │   raw_member_feed &      │
       │  (Invalid dates, nulls,  │      │   raw_redemptions_json   │
       │   schema/domain errors)  │      └─────────────┬────────────┘
       └──────────────────────────┘                    │
                                                       ▼
                                         ┌──────────────────────────┐
                                         │       stg_members        │
                                         │ • Deduplicated (Latest)  │
                                         │ • Age & Stale_Member     │
                                         └─────────────┬────────────┘
                                                       │
                             ┌─────────────────────────┴─────────────────────────┐
                             ▼                                                   ▼
             ┌───────────────────────────────┐                   ┌───────────────────────────────┐
             │   Country Target Tables       │                   │       fact_redemptions        │
             │ (table_india, table_usa, ...) │                   │  (Flattened JSON array)      │
             │ • Upsert latest country       │                   └───────────────┬───────────────┘
             │ • Delete from prior country   │                                   │
             └───────────────┬───────────────┘                                   │
                             └─────────────────────────┬─────────────────────────┘
                                                       ▼
                                         ┌──────────────────────────┐
                                         │  vw_member_redemptions   │
                                         │ (Unified BI / Analytics) │
                                         └──────────────────────────┘
```

### Why Dual SQL Dialects (`sql/snowflake/` + `sql/duckdb/`)?
* **Production Cloud Warehouse (`sql/snowflake/`):** Uses native Snowflake constructs (`VARIANT`, `LATERAL FLATTEN`, `MERGE`, `QUALIFY ROW_NUMBER()`, and `CLUSTER BY` keys) designed for **billions of daily records**.
* **Zero-Setup Local Execution (`sql/duckdb/`):** Mirrors the exact Snowflake SQL transformations in **DuckDB** so the entire pipeline and `pytest` suite run locally in under 1 second without requiring cloud credentials.

---

## 2. Data Anomalies & Spec Traps Discovered

Auditing the design specification against the sample datasets (`members_flat.dat`, `AUS.xlsx`, `USA.csv`, `IND.csv`) revealed several real-world data quality issues that this pipeline explicitly handles:

| Anomaly Found | Where Observed | How This Pipeline Solves It |
| :--- | :--- | :--- |
| **Schema Drift (`Post Code` omitted)** | Spec defines 11 columns including `Post Code` at position 9, but the sample flat file only contains 10 data fields. | `parse_pipe_delimited_file()` dynamically detects 10-field vs. 11-field detail (`\|D\|`) rows and defaults `post_code = NULL` without breaking column alignment. |
| **Inconsistent & Corrupted Dates** | Flat file mixes `YYYYMMDD` (`20101012`) and `DDMMYYYY` (`03051985`); staging strips leading zeros (`3051985`); `USA.csv` uses `6152022`; `IND.csv` contains invalid date `2021-13-13`. | `parse_flexible_date()` zero-pads 7-digit integers (`3051985` → `03051985`), parses multi-format dates, and routes impossible dates (`2021-13-13`) to `quarantine_member_records`. |
| **Key Column Spec Flaw & ID Collisions** | Spec marks `Member Name` as Key (`Y`) instead of `Member ID`. Regional files (`USA.csv`, `IND.csv`, `AUS.xlsx`) reuse `ID = 1, 2, 3`. | Enforces `member_id` as the true primary key (matching `member_id` in the JSON redemption feed) and namespaces colliding regional IDs (`USA-1`, `IND-1`, `AUS-1`). |
| **Inconsistent Country Codes & Typos** | Flat file mixes ISO-3 (`USA`, `IND`, `CAN`), ISO-2 (`AU`), and 4-letter codes (`PHIL`); staging DDL has typo `County`. | `COUNTRY_ISO3_MAP` normalizes all variants (`AU` → `AUS`, `PHIL` → `PHL`) into a standardized `country_iso3` column. |
| **Cross-Country Member Relocation** | Members moving countries would leave stale duplicate profiles if only `INSERT`/`UPSERT` were used. | **Deliverable 3** executes an atomic upsert into the member's new country table followed by a `DELETE` from all other country tables (`latest record wins`). |

---

## 3. Scaling to Billions of Records Daily

To sustain billion-row daily throughput across flat files and JSON feeds:
1. **Quarantine Pattern Instead of Batch Failure:** Bad records are isolated into `quarantine_member_records` so a single malformed row never halts a billion-row ingestion job.
2. **Set-Based SQL Pushdown:** All deduplication (`QUALIFY ROW_NUMBER()`), derived column computation (`Age`, `Stale_Member`), JSON flattening (`LATERAL FLATTEN`), and cross-country routing execute as set-based operations rather than row-by-row Python loops.
3. **Micro-Partition Pruning (`CLUSTER BY`):**
   * `stg_members` is clustered by `(country_iso3, member_id)` for fast country-slice filtering.
   * Country target tables (`table_india`, etc.) are clustered by `(member_id)` to minimize micro-partition scans during `MERGE` and `DELETE` operations.
   * `fact_redemptions` is clustered by `(txn_date, member_id)` for fast time-bounded joins against member profiles.
4. **Idempotent Incremental Loads:** `MERGE` statements keyed on `member_id` and `txn_id` allow safe retries without duplicating records.

---

## 4. Quickstart & Live Demo Instructions

### Prerequisites
* Python 3.10+

### Setup & Run
```bash
# 1. Install dependencies
pip install -r requirements.txt

# 2. Run automated unit & integration tests (Deliverable 5)
pytest -v

# 3. Run the end-to-end local pipeline on sample_data/
python -m src.pipeline
```

---

## 5. Project Structure

```text
skypoints-etl/
├── README.md
├── requirements.txt
├── sample_data/                # Sample flat file, JSON feed, and regional CSV/XLSX datasets
├── sql/
│   ├── duckdb/                 # Local runnable SQL scripts (Deliverables 1–4)
│   │   ├── 01_ddl.sql
│   │   ├── 02_stage_transform.sql
│   │   ├── 03_country_merge.sql
│   │   └── 04_json_flatten.sql
│   └── snowflake/              # Production Snowflake SQL scripts (Deliverables 1–4)
│       ├── 01_ddl.sql
│       ├── 02_stage_transform.sql
│       ├── 03_country_merge.sql
│       └── 04_json_flatten.sql
├── src/
│   ├── __init__.py
│   ├── ingestion.py            # Multi-format parser (.dat, .csv, .xlsx, .json)
│   ├── validation.py           # Data quality rules & quarantine routing
│   └── pipeline.py             # End-to-end local pipeline orchestrator
└── tests/
    ├── __init__.py
    └── test_pipeline.py        # Pytest suite covering anomalies, moves, and JSON joins
```

---

## 6. Intentional Use of AI Tools

In line with the assessment guidelines, AI assistance was used intentionally as an engineering accelerator while maintaining strict human ownership of architecture and correctness:
* **Problem & Data Audit:** Manually inspected the specification PDF and sample datasets (`AUS.xlsx`, `USA.csv`, `IND.csv`) first to identify schema drift (`Post Code`), date anomalies (`2021-13-13`, `3051985`), and cross-country ID collisions before designing the pipeline.
* **Accelerated Scaffolding:** Used AI to draft boilerplate Snowflake/DuckDB DDLs and multi-country `MERGE` templates.
* **Verification & Hardening:** Reviewed all generated SQL for idempotency (`record_updated_at` guards), verified local execution via DuckDB, and wrote targeted `pytest` assertions to prove edge cases fail safely into quarantine.
