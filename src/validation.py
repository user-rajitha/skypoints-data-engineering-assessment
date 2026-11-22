from __future__ import annotations

import json
from dataclasses import dataclass, field
from datetime import date, datetime
from typing import Any

COUNTRY_ISO3_MAP = {
    "USA": "USA",
    "US": "USA",
    "IND": "IND",
    "IN": "IND",
    "AU": "AUS",
    "AUS": "AUS",
    "CAN": "CAN",
    "CA": "CAN",
    "PHIL": "PHL",
    "PHL": "PHL",
}


@dataclass
class BatchValidationSummary:
    valid_rows: list[dict[str, Any]] = field(default_factory=list)
    quarantined_rows: list[dict[str, Any]] = field(default_factory=list)


def parse_flexible_date(raw_val: Any, prefer_ddmmyyyy: bool = False) -> date | None:
    """Parses varied date formats and restores stripped leading zeros (e.g. '3051985' -> '03051985')."""
    if raw_val is None:
        return None
    val = str(raw_val).strip()
    if not val or val.upper() in {"NULL", "NONE", "NA", "NAN", "NAT"}:
        return None

    # Strip Excel timestamp suffix if present (e.g., '2022-05-11 00:00:00' -> '2022-05-11')
    if " " in val:
        val = val.split()[0]

    if val.isdigit() and len(val) == 7:
        val = val.zfill(8)

    formats = (
        ("%d%m%Y", "%Y%m%d", "%m%d%Y", "%Y-%m-%d", "%m/%d/%Y")
        if prefer_ddmmyyyy
        else ("%Y%m%d", "%m%d%Y", "%d%m%Y", "%Y-%m-%d", "%m/%d/%Y")
    )
    for fmt in formats:
        try:
            return datetime.strptime(val, fmt).date()
        except ValueError:
            continue
    return None


def validate_batch(raw_rows: list[dict[str, Any]], batch_timestamp: datetime | None = None) -> BatchValidationSummary:
    """
    Validates mandatory fields, key uniqueness within batch, date validity (e.g. '2021-13-13'),
    chronological order, field lengths, and country code normalization.
    """
    ts = (batch_timestamp or datetime.utcnow()).isoformat(sep=" ")
    summary = BatchValidationSummary()
    seen_keys: set[str] = set()

    for row in raw_rows:
        errors: list[str] = []
        source_file = str(row.get("source_file_name") or "unknown")

        member_id = str(row.get("member_id") or "").strip()
        member_name = str(row.get("member_name") or "").strip()
        raw_enroll = row.get("enrollment_date")
        raw_flight = row.get("last_flight_date")
        raw_dob = row.get("dob")
        raw_country = row.get("country")

        # 1. Mandatory fields & max lengths per spec
        if not member_id:
            errors.append("MISSING_MANDATORY_MEMBER_ID")
        elif len(member_id) > 18:
            errors.append("MEMBER_ID_EXCEEDS_MAX_LEN_18")

        if not member_name or member_name.upper() in {"NULL", "NONE", "NAN"}:
            errors.append("MISSING_MANDATORY_MEMBER_NAME")
        elif len(member_name) > 255:
            errors.append("MEMBER_NAME_EXCEEDS_MAX_LEN_255")

        enroll_dt = parse_flexible_date(raw_enroll, prefer_ddmmyyyy=False)
        if not enroll_dt:
            errors.append(f"INVALID_OR_MISSING_ENROLLMENT_DATE:{raw_enroll}")

        # 2. Optional dates (reject malformed strings like '2021-13-13' while allowing NULL)
        flight_dt = parse_flexible_date(raw_flight, prefer_ddmmyyyy=False)
        if raw_flight and str(raw_flight).strip().upper() not in {"", "NULL", "NONE", "NAN", "NAT"} and not flight_dt:
            errors.append(f"INVALID_LAST_FLIGHT_DATE:{raw_flight}")

        dob_dt = parse_flexible_date(raw_dob, prefer_ddmmyyyy=True)
        if raw_dob and str(raw_dob).strip().upper() not in {"", "NULL", "NONE", "NAN", "NAT"} and not dob_dt:
            errors.append(f"INVALID_DOB:{raw_dob}")

        # 3. Chronological sanity checks
        if dob_dt and enroll_dt and enroll_dt < dob_dt:
            errors.append("ENROLLMENT_DATE_BEFORE_DOB")
        if enroll_dt and flight_dt and flight_dt < enroll_dt:
            errors.append("LAST_FLIGHT_DATE_BEFORE_ENROLLMENT")

        # 4. Country standardization
        country_iso3 = COUNTRY_ISO3_MAP.get(str(raw_country or "").strip().upper())
        if not country_iso3:
            errors.append(f"UNKNOWN_OR_MISSING_COUNTRY:{raw_country}")

        # 5. Active flag check
        is_active = str(row.get("is_active") or "A").strip().upper()
        if is_active not in {"A", "I", "Y", "N"}:
            errors.append(f"INVALID_ACTIVE_FLAG:{is_active}")

        # 6. Duplicate key check within same feed file
        dedup_key = f"{source_file}:{member_id}"
        if member_id and dedup_key in seen_keys:
            errors.append(f"DUPLICATE_MEMBER_ID_IN_FILE:{member_id}")
        elif member_id:
            seen_keys.add(dedup_key)

        if errors:
            summary.quarantined_rows.append({
                "raw_record": json.dumps(row, default=str),
                "failure_reasons": json.dumps(errors),
                "source_file_name": source_file,
            })
        else:
            raw_post = str(row.get("post_code") or "").strip()
            summary.valid_rows.append({
                "member_id": member_id,
                "member_name": member_name,
                "enrollment_date": enroll_dt.isoformat(),
                "last_flight_date": flight_dt.isoformat() if flight_dt else None,
                "tier_code": (str(row.get("tier_code") or "").strip().upper() or None),
                "agent_name": (str(row.get("agent_name") or "").strip() or None),
                "state": (str(row.get("state") or "").strip().upper() or None),
                "country_iso3": country_iso3,
                "post_code": int(raw_post) if raw_post.isdigit() else None,
                "dob": dob_dt.isoformat() if dob_dt else None,
                "is_active": "A" if is_active in {"A", "Y"} else "I",
                "source_file_name": source_file,
                "record_updated_at": ts,
            })

    return summary
