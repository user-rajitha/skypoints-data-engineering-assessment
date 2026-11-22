from __future__ import annotations

from datetime import datetime
from pathlib import Path
from typing import Any

import duckdb
import pandas as pd

from src.ingestion import (
    load_json_redemptions,
    parse_pipe_delimited_file,
    parse_regional_tabular_file,
)
from src.validation import validate_batch

SQL_DIR = Path("sql/duckdb")

RAW_COLUMNS = [
    "record_type",
    "member_name",
    "member_id",
    "enrollment_date",
    "last_flight_date",
    "tier_code",
    "agent_name",
    "state",
    "country",
    "post_code",
    "dob",
    "is_active",
    "source_file_name",
]


def run_sql_file(con: duckdb.DuckDBPyConnection, sql_path: Path) -> None:
    """Executes each SQL statement in a file sequentially so DuckDB closes every cursor cleanly."""
    script = sql_path.read_text(encoding="utf-8")
    for stmt in script.split(";"):
        cleaned = "\n".join(
            line for line in stmt.splitlines() if not line.strip().startswith("--")
        ).strip()
        if cleaned:
            con.execute(cleaned)


def init_db(con: duckdb.DuckDBPyConnection) -> None:
    run_sql_file(con, SQL_DIR / "01_ddl.sql")


def ingest_and_transform_members(
    con: duckdb.DuckDBPyConnection,
    raw_rows: list[dict[str, Any]],
    batch_ts: datetime | None = None,
) -> dict[str, int]:
    """Loads raw rows, runs data validations, routes bad rows to quarantine, and runs SQL transforms."""
    if not raw_rows:
        return {"valid": 0, "quarantined": 0}

    # 1. Normalize column presence and store untouched raw rows
    normalized_raw = [{col: row.get(col) for col in RAW_COLUMNS} for row in raw_rows]
    raw_df = pd.DataFrame(normalized_raw)
    con.register("tmp_raw_df", raw_df)
    con.execute("""
        INSERT INTO raw_member_feed (
            record_type, member_name, member_id, enrollment_date, last_flight_date,
            tier_code, agent_name, state, country, post_code, dob, is_active, source_file_name
        )
        SELECT
            record_type, member_name, member_id, enrollment_date, last_flight_date,
            tier_code, agent_name, state, country, post_code, dob, is_active, source_file_name
        FROM tmp_raw_df
    """)
    con.unregister("tmp_raw_df")

    # 2. Validate & split into valid vs quarantine
    summary = validate_batch(raw_rows, batch_timestamp=batch_ts)

    if summary.quarantined_rows:
        q_df = pd.DataFrame(summary.quarantined_rows)
        con.register("tmp_q_df", q_df)
        con.execute("""
            INSERT INTO quarantine_member_records (raw_record, failure_reasons, source_file_name)
            SELECT raw_record, failure_reasons, source_file_name FROM tmp_q_df
        """)
        con.unregister("tmp_q_df")

    if summary.valid_rows:
        con.execute("DELETE FROM validated_members_load")
        v_df = pd.DataFrame(summary.valid_rows)
        con.register("tmp_v_df", v_df)
        con.execute("""
            INSERT INTO validated_members_load
            SELECT
                member_id, member_name, CAST(enrollment_date AS DATE),
                CAST(last_flight_date AS DATE), tier_code, agent_name, state,
                country_iso3, post_code, CAST(dob AS DATE), is_active,
                source_file_name, CAST(record_updated_at AS TIMESTAMP)
            FROM tmp_v_df
        """)
        con.unregister("tmp_v_df")

        # 3. Execute Deliverable 2 (Staging + Derived Columns) & Deliverable 3 (Country Merge)
        run_sql_file(con, SQL_DIR / "02_stage_transform.sql")
        run_sql_file(con, SQL_DIR / "03_country_merge.sql")

    return {"valid": len(summary.valid_rows), "quarantined": len(summary.quarantined_rows)}


def ingest_and_flatten_redemptions(con: duckdb.DuckDBPyConnection, json_rows: list[dict[str, Any]]) -> None:
    if not json_rows:
        return
    j_df = pd.DataFrame(json_rows)
    con.register("tmp_j_df", j_df)
    con.execute("""
        INSERT INTO raw_redemptions_json (raw_payload, source_file_name)
        SELECT raw_payload::JSON, source_file_name FROM tmp_j_df
    """)
    con.unregister("tmp_j_df")
    run_sql_file(con, SQL_DIR / "04_json_flatten.sql")


def run_demo(sample_dir: Path = Path("sample_data")) -> None:
    con = duckdb.connect("skypoints_demo.duckdb")
    init_db(con)

    all_member_rows: list[dict[str, Any]] = []
    if (sample_dir / "members_flat.dat").exists():
        all_member_rows.extend(parse_pipe_delimited_file(sample_dir / "members_flat.dat"))
    if (sample_dir / "USA.csv").exists():
        all_member_rows.extend(parse_regional_tabular_file(sample_dir / "USA.csv", "USA"))
    if (sample_dir / "IND.csv").exists():
        all_member_rows.extend(parse_regional_tabular_file(sample_dir / "IND.csv", "IND"))
    if (sample_dir / "AUS.xlsx").exists():
        all_member_rows.extend(parse_regional_tabular_file(sample_dir / "AUS.xlsx", "AUS"))

    stats = ingest_and_transform_members(con, all_member_rows)
    print(f"Member Ingestion Complete -> Valid: {stats['valid']}, Quarantined: {stats['quarantined']}")

    if (sample_dir / "redemptions.json").exists():
        json_rows = load_json_redemptions(sample_dir / "redemptions.json")
        ingest_and_flatten_redemptions(con, json_rows)

    print("\n--- STAGING MEMBERS (with Age & Stale_Member) ---")
    print(con.execute("SELECT member_id, member_name, country_iso3, dob, age, stale_member FROM stg_members").df())

    print("\n--- QUARANTINED RECORDS ---")
    print(con.execute("SELECT source_file_name, failure_reasons FROM quarantine_member_records").df())

    print("\n--- JOINED MEMBER REDEMPTIONS ---")
    print(con.execute("SELECT * FROM vw_member_redemptions").df())


if __name__ == "__main__":
    run_demo()
