from datetime import datetime, timedelta
from pathlib import Path
import json

import duckdb
import pytest

from src.ingestion import parse_pipe_delimited_file
from src.pipeline import ingest_and_flatten_redemptions, ingest_and_transform_members, init_db
from src.validation import parse_flexible_date, validate_batch


@pytest.fixture
def db_con():
    con = duckdb.connect(":memory:")
    init_db(con)
    yield con
    con.close()


def test_parse_flexible_date_repairs_stripped_leading_zeros():
    assert parse_flexible_date("3051985", prefer_ddmmyyyy=True).isoformat() == "1985-05-03"
    assert parse_flexible_date("20101012").isoformat() == "2010-10-12"
    assert parse_flexible_date("12/1/1998").isoformat() == "1998-12-01"
    assert parse_flexible_date("2021-13-13") is None


def test_validation_quarantines_bad_dates_and_missing_mandatory_fields():
    rows = [
        {
            "member_id": "IND-2",
            "member_name": "Jonnathan",
            "enrollment_date": "2021-13-13",
            "last_flight_date": "2022-01-05",
            "country": "IND",
            "dob": "1997-12-13",
            "source_file_name": "IND.csv",
        },
        {
            "member_id": "",
            "member_name": "Ghost",
            "enrollment_date": "2022-01-01",
            "country": "USA",
            "source_file_name": "USA.csv",
        },
    ]
    res = validate_batch(rows)
    assert len(res.valid_rows) == 0
    assert len(res.quarantined_rows) == 2
    assert "INVALID_OR_MISSING_ENROLLMENT_DATE:2021-13-13" in res.quarantined_rows[0]["failure_reasons"]
    assert "MISSING_MANDATORY_MEMBER_ID" in res.quarantined_rows[1]["failure_reasons"]


def test_pipe_delimited_schema_drift_and_derived_columns(db_con, tmp_path: Path):
    flat_file = tmp_path / "members.dat"
    recent_flight = (datetime.utcnow().date() - timedelta(days=10)).strftime("%Y%m%d")
    old_flight = (datetime.utcnow().date() - timedelta(days=120)).strftime("%Y%m%d")

    flat_file.write_text(
        "|H|Member_Name|Member_Id|Enrollment_Date|Last_Flight_Date|Tier_Code|Agent_Name|State|Country|DOB|Is_Active\n"
        f"|D|Elena|223457|20101012|{old_flight}|GLD|Sam|CA|USA|03051985|A\n"
        f"|D|Jacob|2256|20101012|{recent_flight}|SLV|Sam|VIC|AU|03051985|A\n",
        encoding="utf-8",
    )

    parsed = parse_pipe_delimited_file(flat_file)
    stats = ingest_and_transform_members(db_con, parsed, batch_ts=datetime(2026, 11, 22, 10, 0, 0))
    assert stats == {"valid": 2, "quarantined": 0}

    elena_rows = db_con.execute("SELECT age, stale_member FROM table_usa WHERE member_id = '223457'").fetchall()
    assert len(elena_rows) == 1
    assert elena_rows[0][0] >= 40
    assert elena_rows[0][1] is True

    jacob_rows = db_con.execute("SELECT stale_member FROM table_australia WHERE member_id = '2256'").fetchall()
    assert len(jacob_rows) == 1
    assert jacob_rows[0][0] is False


def test_latest_record_wins_when_member_moves_country(db_con):
    day1 = [{
        "member_id": "223458",
        "member_name": "Ravi",
        "enrollment_date": "20101012",
        "last_flight_date": "20260101",
        "country": "IND",
        "dob": "03051985",
        "source_file_name": "day1.dat",
    }]
    ingest_and_transform_members(db_con, day1, batch_ts=datetime(2026, 11, 21, 9, 0, 0))
    assert db_con.execute("SELECT COUNT(*) FROM table_india WHERE member_id = '223458'").fetchall() == [(1,)]

    day2 = [{
        "member_id": "223458",
        "member_name": "Ravi",
        "enrollment_date": "20101012",
        "last_flight_date": "20261120",
        "country": "USA",
        "dob": "03051985",
        "source_file_name": "day2.dat",
    }]
    ingest_and_transform_members(db_con, day2, batch_ts=datetime(2026, 11, 22, 9, 0, 0))

    assert db_con.execute("SELECT COUNT(*) FROM table_india WHERE member_id = '223458'").fetchall() == [(0,)]
    assert db_con.execute("SELECT COUNT(*) FROM table_usa WHERE member_id = '223458'").fetchall() == [(1,)]


def test_json_redemption_flattening_and_member_join(db_con):
    members = [{
        "member_id": "223457",
        "member_name": "Elena",
        "enrollment_date": "20101012",
        "last_flight_date": "20261101",
        "tier_code": "GLD",
        "country": "USA",
        "dob": "03051985",
        "source_file_name": "members.dat",
    }]
    ingest_and_transform_members(db_con, members, batch_ts=datetime(2026, 11, 22, 10, 0, 0))

    payload = {
        "member_id": "223457",
        "feed_date": "20240115",
        "redemptions": [
            {"txn_id": "RX10091", "txn_date": "20240110", "partner": "AeroLink", "miles_redeemed": 12000, "status": "COMPLETED"},
            {"txn_id": "RX10092", "txn_date": "20240113", "partner": "SkyPoints", "miles_redeemed": 5000, "status": "PENDING"},
        ],
    }
    ingest_and_flatten_redemptions(db_con, [{"raw_payload": json.dumps(payload), "source_file_name": "feed.json"}])

    joined = db_con.execute("SELECT txn_id, member_name, partner, miles_redeemed FROM vw_member_redemptions ORDER BY txn_id").fetchall()
    assert joined == [
        ("RX10091", "Elena", "AeroLink", 12000.0),
        ("RX10092", "Elena", "SkyPoints", 5000.0),
    ]
