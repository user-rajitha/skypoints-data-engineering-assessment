from __future__ import annotations

import json
from pathlib import Path
from typing import Any

import openpyxl
import pandas as pd


def parse_pipe_delimited_file(file_path: Path) -> list[dict[str, Any]]:
    """
    Parses the SkyPoints pipe-delimited flat file:

    |H|Member_Name|Member_Id|Enrollment_Date|Last_Flight_Date|Tier_Code|Agent_Name|State|Country|DOB|Is_Active
    |D|Elena|223457|20101012|20121013|GLD|Sam|CA|USA|03051985|A
    Handles schema drift where Post_Code (position 9 in spec) is omitted in the sample feed.
    """
    records: list[dict[str, Any]] = []
    with file_path.open("r", encoding="utf-8") as f:
        for line in f:
            stripped = line.strip()
            if not stripped:
                continue
            parts = [p.strip() for p in stripped.lstrip("|").split("|")]
            rec_type = parts[0].upper()
            if rec_type == "H":
                continue
            if rec_type != "D":
                continue

            # 11 tokens = ['D', Name, Id, Enroll, Flight, Tier, Agent, State, Country, DOB, Active]
            # 12 tokens = includes Post_Code before DOB
            if len(parts) == 11:
                records.append({
                    "record_type": "D",
                    "member_name": parts[1],
                    "member_id": parts[2],
                    "enrollment_date": parts[3],
                    "last_flight_date": parts[4],
                    "tier_code": parts[5],
                    "agent_name": parts[6],
                    "state": parts[7],
                    "country": parts[8],
                    "post_code": None,
                    "dob": parts[9],
                    "is_active": parts[10],
                    "source_file_name": file_path.name,
                })
            elif len(parts) >= 12:
                records.append({
                    "record_type": "D",
                    "member_name": parts[1],
                    "member_id": parts[2],
                    "enrollment_date": parts[3],
                    "last_flight_date": parts[4],
                    "tier_code": parts[5],
                    "agent_name": parts[6],
                    "state": parts[7],
                    "country": parts[8],
                    "post_code": parts[9],
                    "dob": parts[10],
                    "is_active": parts[11],
                    "source_file_name": file_path.name,
                })
    return records


def parse_regional_tabular_file(file_path: Path, default_country: str) -> list[dict[str, Any]]:
    """
    Parses regional extracts (USA.csv, IND.csv, AUS.xlsx) with heterogeneous column headers.
    Prefixes colliding local IDs (1, 2, 3) with country code if purely numeric small integers.
    """
    if file_path.suffix.lower() == ".xlsx":
        df = pd.read_excel(file_path, dtype=str)
    else:
        df = pd.read_csv(file_path, dtype=str)

    df.columns = [c.strip().lower().replace(" ", "_") for c in df.columns]
    records: list[dict[str, Any]] = []

    for _, row in df.iterrows():
        raw_id = str(row.get("id") or row.get("unique_id") or row.get("member_id") or "").strip()
        # Prevent cross-country ID collisions (e.g., ID=1 in USA, IND, AUS)
        scoped_id = f"{default_country}-{raw_id}" if raw_id and len(raw_id) <= 4 else raw_id

        records.append({
            "record_type": "D",
            "member_name": row.get("name") or row.get("member_name"),
            "member_id": scoped_id,
            "enrollment_date": row.get("enrollmentdate") or row.get("date_of_enrollment"),
            "last_flight_date": row.get("flightdate") or row.get("flight_date") or row.get("date_of_flight"),
            "tier_code": row.get("tiercode") or row.get("tier_type"),
            "agent_name": row.get("agent_name"),
            "state": row.get("state"),
            "country": row.get("country") or default_country,
            "post_code": row.get("post_code"),
            "dob": row.get("dob") or row.get("date_of_birth"),
            "is_active": row.get("is_active") or "A",
            "source_file_name": file_path.name,
        })
    return records


def load_json_redemptions(file_path: Path) -> list[dict[str, Any]]:
    """Reads single JSON object or NDJSON array of partner airline redemption feeds."""
    text = file_path.read_text(encoding="utf-8").strip()
    payload = json.loads(text)
    items = payload if isinstance(payload, list) else [payload]
    return [{"raw_payload": json.dumps(item), "source_file_name": file_path.name} for item in items]
