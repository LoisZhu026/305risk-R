"""Rebuild source-input CSVs from the original exports in this repository.

Optional source traceability step; normal Q1/Q2/Q3 work starts with the CSVs in data/.
Requires Python 3.10+ and openpyxl. Run with --check to verify, or --rebuild to write.
This script merges exports, validates source keys and builds the market calendar.
Returns, risk-free conversion, portfolios and all coursework calculations stay in R.
"""
from __future__ import annotations

import argparse
import csv
import hashlib
import io
import json
import math
import warnings
import zipfile
from collections import defaultdict
from datetime import date, datetime, timedelta
from pathlib import Path

from openpyxl import load_workbook

PREPARATION = Path(__file__).resolve().parent
ROOT = PREPARATION.parent
ADJUSTED_IDS = ["145844747", "150133482", "150231186", "150412834", "151012648"]
RAW_IDS = ["075105684", "075205345", "075247758", "075230413", "075254889"]
FIELDS = ["TradingDate", "Symbol", "ShortName", "Filling", "ClosePrice", "Distance", "StateCode"]
SYMBOLS = ["000651", "002032", "600060", "600690", "600839"]
# These historical internal IDs are cross-checked below against every actual
# trading date and the relationship between raw and adjusted daily price moves.
SECURITY_IDS = {"000651": "201000000304", "002032": "201000000738",
                "600060": "201000003412", "600690": "201000003968",
                "600839": "201000004117"}
START, END, PREHISTORY = "2010-01-01", "2024-12-31", "2009-12-31"


def normalized_date(value):
    if isinstance(value, (date, datetime)):
        return value.strftime("%Y-%m-%d")
    result = str(value)
    if date.fromisoformat(result).isoformat() != result:
        raise ValueError(f"Nonstandard date: {value!r}")
    return result


def source_archive(kind, number):
    matches = list((PREPARATION / "CSMAR_stock_originalsource" / kind).glob(f"*{number}*.zip"))
    if len(matches) != 1:
        raise ValueError(f"Expected one {kind} archive {number}; found {len(matches)}")
    return matches[0]


def read_excel_export(path, member, expected_fields):
    with zipfile.ZipFile(path) as archive:
        workbook_bytes = archive.read(member)
        descriptions = {name: archive.read(name).decode("utf-8-sig").replace("\r\n", "\n")
                        for name in archive.namelist() if name.lower().endswith(".txt")}
    with warnings.catch_warnings():
        warnings.filterwarnings("ignore", message="Workbook contains no default style")
        workbook = load_workbook(io.BytesIO(workbook_bytes), read_only=True, data_only=True)
    try:
        worksheet = workbook.active
        # CSMAR exports can declare only column A although later columns contain
        # data. Read the real XML cell extent instead of trusting that dimension.
        worksheet.reset_dimensions()
        rows = iter(worksheet.iter_rows(values_only=True))
        if list(next(rows)) != expected_fields:
            raise ValueError(f"Unexpected columns in {path.name}")
        labels, units = list(next(rows)), list(next(rows))
        records = [dict(zip(expected_fields, row)) for row in rows
                   if any(value is not None for value in row)]
        if any(len(record) != len(expected_fields) for record in records):
            raise ValueError(f"Incomplete source row in {path.name}")
    finally:
        workbook.close()
    return records, descriptions, labels, units


def csv_content(fields, rows):
    output = io.StringIO(newline="")
    writer = csv.DictWriter(output, fieldnames=fields, lineterminator="\n")
    writer.writeheader()
    writer.writerows(rows)
    return output.getvalue()


def load_sources():
    adjusted, provenance = {}, defaultdict(list)
    inventory, descriptions, overlaps = [], {}, []
    all_adjusted_rows = 0
    for number in ADJUSTED_IDS:
        path = source_archive("adjusted", number)
        rows, text, labels, units = read_excel_export(path, "TRD_BwardQuotation.xlsx", FIELDS)
        seen = set()
        for row in rows:
            row["TradingDate"] = normalized_date(row["TradingDate"])
            row["Symbol"] = str(row["Symbol"]).zfill(6)
            row["ShortName"] = str(row["ShortName"])
            row["Filling"], row["StateCode"] = int(row["Filling"]), int(row["StateCode"])
            row["ClosePrice"] = float(row["ClosePrice"])
            row["Distance"] = None if row["Distance"] is None else int(row["Distance"])
            if row["Symbol"] not in SYMBOLS:
                raise ValueError(f"Unexpected stock in {path.name}: {row['Symbol']}")
            if not PREHISTORY <= row["TradingDate"] <= END:
                raise ValueError(f"Source date outside requested period: {row['TradingDate']}")
            if not math.isfinite(row["ClosePrice"]) or row["ClosePrice"] <= 0:
                raise ValueError(f"Invalid adjusted price in {path.name}")
            if row["StateCode"] not in (0, 1, 2) or row["Filling"] != row["StateCode"]:
                raise ValueError(f"Unexpected or inconsistent state/filling codes in {path.name}")
            key = (row["Symbol"], row["TradingDate"])
            if key in seen:
                raise ValueError(f"Duplicate within source archive: {path.name}, {key}")
            seen.add(key)
            if key in adjusted:
                if row != adjusted[key]:
                    raise ValueError(f"Conflicting overlap at {key}: {path.name}")
                overlaps.append({"Symbol": key[0], "Date": key[1],
                                 "EarlierArchive": provenance[key][0], "AdditionalArchive": path.name})
            else:
                adjusted[key] = row
            provenance[key].append(path.name)
        all_adjusted_rows += len(rows)
        inventory.append({"Kind": "adjusted", "Archive": path.name, "Rows": len(rows),
                          "Securities": len({r['Symbol'] for r in rows}),
                          "Start": min(r['TradingDate'] for r in rows),
                          "End": max(r['TradingDate'] for r in rows),
                          "NonfilledRows": sum(r['Filling'] == 0 for r in rows)})
        descriptions[f"{number}_fields.txt"] = "\n\n".join(text.values())
    raw = {}
    for number in RAW_IDS:
        path = source_archive("raw", number)
        rows, text, labels, units = read_excel_export(path, "LS_SymbolQuotationD.xlsx",
                                                    ["TradingDate", "SecurityID", "ClosePrice"])
        for row in rows:
            row["TradingDate"] = normalized_date(row["TradingDate"])
            row["SecurityID"], row["ClosePrice"] = str(row["SecurityID"]), float(row["ClosePrice"])
            if row["SecurityID"] not in SECURITY_IDS.values() or not START <= row["TradingDate"] <= END:
                raise ValueError(f"Unexpected raw identifier/date in {path.name}")
            if not math.isfinite(row["ClosePrice"]) or row["ClosePrice"] <= 0:
                raise ValueError(f"Invalid raw price in {path.name}")
            row["SourceArchive"] = path.name
            key = (row["SecurityID"], row["TradingDate"])
            if key in raw:
                raise ValueError(f"Duplicate raw price key: {key}")
            raw[key] = row
        inventory.append({"Kind": "raw", "Archive": path.name, "Rows": len(rows),
                          "Securities": len({r['SecurityID'] for r in rows}),
                          "Start": min(r['TradingDate'] for r in rows),
                          "End": max(r['TradingDate'] for r in rows), "NonfilledRows": len(rows)})
        descriptions[f"{number}_fields.txt"] = "\n\n".join(text.values())
    if len(raw) != 17886:
        raise ValueError(f"Expected 17886 original raw rows, got {len(raw)}")
    if all_adjusted_rows - len(adjusted) != len(overlaps):
        raise ValueError("Deduplication did not reconcile source counts")
    return adjusted, provenance, raw, inventory, descriptions, overlaps, all_adjusted_rows


def treasury_quotes():
    """Merge the original 3-month annual quotes, without converting to returns."""
    archive = PREPARATION / "ChinaBond_original" / "中债3个月国债收益率（原文件）.zip"
    quotes = {}
    with zipfile.ZipFile(archive) as source:
        for member in source.namelist():
            with warnings.catch_warnings():
                warnings.filterwarnings("ignore", message="Workbook contains no default style")
                workbook = load_workbook(io.BytesIO(source.read(member)), read_only=True,
                                         data_only=True)
            try:
                sheet = workbook.active
                sheet.reset_dimensions()
                rows = iter(sheet.iter_rows(values_only=True))
                if list(next(rows))[:3] != ["曲线名称", "日期", "3月"]:
                    raise ValueError(f"Unexpected ChinaBond columns: {member}")
                for row in rows:
                    if not any(value is not None for value in row):
                        continue
                    day = normalized_date(row[1])
                    if not PREHISTORY <= day <= END:
                        continue
                    if row[0] != "中债国债收益率曲线":
                        raise ValueError(f"Unexpected yield curve: {member}")
                    value = float(row[2])
                    if not math.isfinite(value):
                        raise ValueError(f"Invalid yield quote: {member}, {day}")
                    if day in quotes and quotes[day] != value:
                        raise ValueError(f"Conflicting ChinaBond quote: {day}")
                    quotes[day] = value
            finally:
                workbook.close()
    return [{"QuoteDate": day, "AnnualYieldPct": f"{quotes[day]:.4f}"}
            for day in sorted(quotes)]


def prepare_source_outputs():
    """Build source tables only; Q1 constructs returns and its sample in R."""
    adjusted, provenance, raw, inventory, _, overlaps, original_count = load_sources()
    by_date = defaultdict(list)
    for row in adjusted.values():
        by_date[row["TradingDate"]].append(row)

    expected_weekdays = []
    day, last = date.fromisoformat(PREHISTORY), date.fromisoformat(END)
    while day <= last:
        if day.weekday() < 5:
            expected_weekdays.append(day.isoformat())
        day += timedelta(days=1)
    if sorted(by_date) != expected_weekdays:
        raise ValueError("Source exports do not cover every weekday in the requested period")
    for day, rows in by_date.items():
        if sorted(row["Symbol"] for row in rows) != SYMBOLS:
            raise ValueError(f"Expected exactly five stocks on {day}")
        if len({row["StateCode"] == 2 for row in rows}) != 1:
            raise ValueError(f"Contradictory market-holiday states on {day}")

    sessions = sorted(day for day, rows in by_date.items()
                      if rows[0]["StateCode"] in (0, 1))
    if sorted({day for _, day in raw}) != [day for day in sessions if day >= START]:
        raise ValueError("Market calendar differs from the original raw-date union")
    expected_raw_keys = {(SECURITY_IDS[symbol], day)
                         for (symbol, day), row in adjusted.items()
                         if day >= START and row["Filling"] == 0}
    if set(raw) != expected_raw_keys:
        raise ValueError("Observed adjusted-price keys do not match original raw-price keys")
    calendar = [{"Date": day, "SessionIndex": i + 1,
                 "NormalStocks": sum(row["StateCode"] == 0 for row in by_date[day]),
                 "HaltedStocks": sum(row["StateCode"] == 1 for row in by_date[day]),
                 "Source": "CSMAR TRD_BwardQuotation explicit StateCode 0/1"}
                for i, day in enumerate(sessions)]
    adjusted_rows = [{**row, "SourceArchives": " | ".join(provenance[key])}
                     for key, row in sorted(adjusted.items())]
    quotes = treasury_quotes()
    outputs = {
        "data/csmar_adjusted_long.csv": csv_content(FIELDS + ["SourceArchives"], adjusted_rows),
        "data/trading_calendar.csv": csv_content(list(calendar[0]), calendar),
        "data/treasury_3m_quotes.csv": csv_content(["QuoteDate", "AnnualYieldPct"], quotes),
        "preparation/csmar_raw_long.csv": csv_content(
            ["TradingDate", "SecurityID", "ClosePrice", "SourceArchive"],
            [raw[key] for key in sorted(raw)]),
        "preparation/input_inventory.csv": csv_content(list(inventory[0]), inventory),
    }
    # Archive hashes document the immutable exports used by this preparation step.
    archives = sorted(PREPARATION.rglob("*.zip"))
    audit = {
        "adjusted_original_rows": original_count,
        "adjusted_unique_rows": len(adjusted),
        "identical_overlapping_rows": len(overlaps),
        "conflicting_overlapping_rows": 0,
        "raw_rows": len(raw),
        "all_original_raw_keys_matched": True,
        "market_sessions_including_prehistory": len(sessions),
        "market_sessions_2010_2024": sum(day >= START for day in sessions),
        "treasury_quote_rows": len(quotes),
        "security_id_mapping": SECURITY_IDS,
        "archive_sha256": {path.relative_to(ROOT).as_posix():
                           hashlib.sha256(path.read_bytes()).hexdigest() for path in archives},
        "scope": "Source-table assembly only. Returns and portfolio analysis are calculated in R."
    }
    outputs["preparation/source_audit.json"] = json.dumps(audit, ensure_ascii=False, indent=2) + "\n"
    return outputs, audit


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    mode = parser.add_mutually_exclusive_group(required=True)
    mode.add_argument("--check", action="store_true", help="Verify included source tables")
    mode.add_argument("--rebuild", action="store_true", help="Rebuild source tables from exports")
    args = parser.parse_args()
    outputs, audit = prepare_source_outputs()
    for name, content in outputs.items():
        path = ROOT / name
        if args.rebuild:
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_text(content, encoding="utf-8-sig" if name.endswith(".csv") else "utf-8",
                            newline="")
        elif name.endswith(".csv"):
            with path.open(encoding="utf-8-sig", newline="") as existing:
                if list(csv.reader(existing)) != list(csv.reader(io.StringIO(content))):
                    raise ValueError(f"Source rebuild differs from included CSV: {name}")
        elif json.loads(path.read_text()) != json.loads(content):
            raise ValueError(f"Source audit differs from original exports: {name}")
    manifest_path = PREPARATION / "input_manifest.csv"
    with manifest_path.open(encoding="utf-8-sig", newline="") as manifest_file:
        reader = csv.DictReader(manifest_file)
        manifest_fields, manifest = reader.fieldnames, list(reader)
    for row in manifest:
        digest = hashlib.sha256((ROOT / row["File"]).read_bytes()).hexdigest()
        if args.rebuild:
            row["SHA256"] = digest
        elif row["SHA256"] != digest:
            raise ValueError(f"Input checksum mismatch: {row['File']}")
    if args.rebuild:
        with manifest_path.open("w", encoding="utf-8", newline="") as manifest_file:
            writer = csv.DictWriter(manifest_file, fieldnames=manifest_fields)
            writer.writeheader()
            writer.writerows(manifest)
    print(json.dumps({"mode": "check" if args.check else "rebuild",
                      "verified_or_written_files": len(outputs),
                      "adjusted_rows": audit["adjusted_unique_rows"],
                      "raw_rows": audit["raw_rows"],
                      "treasury_quotes": audit["treasury_quote_rows"]}, indent=2))


if __name__ == "__main__":
    main()
