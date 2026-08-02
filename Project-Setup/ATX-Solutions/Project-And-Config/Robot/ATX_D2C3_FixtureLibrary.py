from __future__ import annotations

import csv
import hashlib
import json
import os
import re
import uuid
from datetime import date, datetime, timedelta, timezone
from pathlib import Path
from typing import Any


def generate_d2c3_unique_name(prefix: str) -> str:
    return f"{prefix} {uuid.uuid4()}"


def _as_int(value: Any, name: str, required: bool = True) -> int | None:
    text = "" if value is None else str(value).strip()
    if not text:
        if required:
            raise AssertionError(f"{name} is required.")
        return None
    result = int(text)
    if result < 0:
        if required:
            raise AssertionError(f"{name} must be zero or greater.")
        return None
    return result


def _date_text(value: date, date_format: str) -> str:
    formats = {
        "yyyy-MM-dd": "%Y-%m-%d",
        "dd/MM/yyyy": "%d/%m/%Y",
        "MM/dd/yyyy": "%m/%d/%Y",
        "dd-MM-yyyy": "%d-%m-%Y",
        "yyyyMMdd": "%Y%m%d",
    }
    if date_format not in formats:
        raise AssertionError(f"Unsupported structured profile date format: {date_format}")
    return value.strftime(formats[date_format])


def create_d2c3_structured_csv(
    directory: str,
    label: str,
    delimiter: str,
    date_format: str,
    has_header: Any,
    date_column: Any,
    description_column: Any,
    reference_column: Any,
    balance_column: Any,
    debit_credit_mode: str,
    debit_column: Any = None,
    credit_column: Any = None,
    amount_column: Any = None,
) -> dict[str, Any]:
    delimiter = "\t" if str(delimiter) == r"\t" else str(delimiter)
    if delimiter not in {",", ";", "\t", "|"}:
        raise AssertionError(f"Unsupported structured profile delimiter: {delimiter!r}")

    date_index = _as_int(date_column, "Date column")
    description_index = _as_int(description_column, "Description column")
    reference_index = _as_int(reference_column, "Reference column", required=False)
    balance_index = _as_int(balance_column, "Balance column", required=False)
    mode = str(debit_credit_mode).strip()
    debit_index = _as_int(debit_column, "Debit column", required=False)
    credit_index = _as_int(credit_column, "Credit column", required=False)
    amount_index = _as_int(amount_column, "Amount column", required=False)

    if mode == "SeparateColumns":
        if debit_index is None or credit_index is None:
            raise AssertionError("Separate-column profile requires debit and credit columns.")
    elif mode in {"SingleAmountColumn", "SignedAmount"}:
        if amount_index is None:
            raise AssertionError(f"{mode} profile requires an amount column.")
    else:
        raise AssertionError(f"Unsupported debit/credit mode: {mode}")

    indices = [date_index, description_index]
    indices.extend(index for index in [reference_index, balance_index, debit_index, credit_index, amount_index] if index is not None)
    column_count = max(indices) + 1
    token = uuid.uuid4().hex[:12].upper()
    safe_label = "".join(ch if ch.isalnum() else "-" for ch in label).strip("-") or "Import"
    file_name = f"ATX_D2C3_{safe_label}_{token}.csv"
    os.makedirs(directory, exist_ok=True)
    path = os.path.join(directory, file_name)

    header = [f"Column {index + 1}" for index in range(column_count)]
    header[date_index] = "Date"
    header[description_index] = "Description"
    if reference_index is not None:
        header[reference_index] = "Reference"
    if balance_index is not None:
        header[balance_index] = "Balance"
    if debit_index is not None:
        header[debit_index] = "Debit"
    if credit_index is not None:
        header[credit_index] = "Credit"
    if amount_index is not None:
        header[amount_index] = "Amount"

    base_date = date(2026, 7, 28)
    definitions = [
        ("Alpha", 100.00, 1000.00),
        ("Beta", -25.00, 975.00),
        ("Gamma", 75.00, 1050.00),
    ]
    rows: list[list[str]] = []
    for offset, (name, signed_amount, balance) in enumerate(definitions):
        row = ["" for _ in range(column_count)]
        row[date_index] = _date_text(base_date + timedelta(days=offset), str(date_format))
        row[description_index] = f"Dynomax D2C3 {label} {name}"
        if reference_index is not None:
            row[reference_index] = f"D2C3-{token}-{offset + 1}"
        if balance_index is not None:
            row[balance_index] = f"{balance:.2f}"
        if mode == "SeparateColumns":
            if signed_amount < 0:
                row[debit_index] = f"{abs(signed_amount):.2f}"
                row[credit_index] = ""
            else:
                row[debit_index] = ""
                row[credit_index] = f"{signed_amount:.2f}"
        else:
            row[amount_index] = f"{signed_amount:.2f}"
        rows.append(row)

    header_enabled = str(has_header).strip().lower() in {"true", "1", "yes"}
    with open(path, "w", newline="", encoding="utf-8") as handle:
        writer = csv.writer(handle, delimiter=delimiter, quoting=csv.QUOTE_MINIMAL, lineterminator="\r\n")
        if header_enabled:
            writer.writerow(header)
        writer.writerows(rows)

    return {
        "path": path,
        "fileName": file_name,
        "rowCount": len(rows),
        "token": token,
        "columnCount": column_count,
    }


def _d2c3_safe_slug(value: Any, fallback: str) -> str:
    text = re.sub(r"[^A-Za-z0-9._-]+", "-", str(value or "").strip()).strip("-._")
    return (text or fallback)[:100]


def _d2c3_atomic_json(path: Path, value: Any) -> None:
    temporary = path.with_name(path.name + ".writing")
    temporary.write_text(json.dumps(value, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
    os.replace(temporary, path)


def write_d2c3_page_evidence(
    output_dir: str,
    step_order: Any,
    action_id: Any,
    label: Any,
    payload_json: str,
) -> dict[str, Any]:
    output_root = Path(str(output_dir)).resolve()
    evidence_root = output_root / "PageHtml"
    evidence_root.mkdir(parents=True, exist_ok=True)

    payload = json.loads(str(payload_json))
    html = str(payload.get("html") or "")
    metadata = payload.get("metadata")
    if not isinstance(metadata, dict):
        raise AssertionError("Page evidence metadata must be a JSON object.")
    if "<html" not in html.lower() or "</html>" not in html.lower():
        raise AssertionError("Page evidence did not contain a complete HTML document.")
    if "__RequestVerificationToken" in html and "[REDACTED]" not in html:
        raise AssertionError("Page evidence contains an unredacted request-verification token field.")
    html = html.replace("\x00", "")

    index_path = evidence_root / "PageEvidenceIndex.json"
    if index_path.exists():
        index = json.loads(index_path.read_text(encoding="utf-8"))
        if not isinstance(index, dict) or not isinstance(index.get("pages"), list):
            raise AssertionError("Existing PageEvidenceIndex.json has an invalid schema.")
    else:
        index = {"schemaVersion": 1, "pages": []}

    sequence = len(index["pages"]) + 1
    try:
        step = int(str(step_order))
    except (TypeError, ValueError):
        step = 0
    action_slug = _d2c3_safe_slug(action_id, "action")
    label_slug = _d2c3_safe_slug(label, "page")
    stem = f"{sequence:03d}-{step:06d}-{action_slug}-{label_slug}"
    html_name = stem + ".html"
    metadata_name = stem + ".json"
    html_path = evidence_root / html_name
    metadata_path = evidence_root / metadata_name

    html_path.write_text(html, encoding="utf-8", newline="\n")
    html_hash = hashlib.sha256(html_path.read_bytes()).hexdigest()
    metadata = dict(metadata)
    metadata.update(
        {
            "schemaVersion": 1,
            "sequence": sequence,
            "stepOrder": step,
            "actionId": str(action_id or ""),
            "label": str(label or ""),
            "capturedAtUtc": datetime.now(timezone.utc).isoformat(),
            "htmlFile": html_name,
            "htmlSize": html_path.stat().st_size,
            "htmlSha256": html_hash,
            "sanitization": {
                "scriptsRemoved": True,
                "stylesRemoved": True,
                "framesRemoved": True,
                "eventHandlersRemoved": True,
                "passwordsAndSecurityTokensRedacted": True,
                "fileInputValuesRemoved": True,
            },
        }
    )
    _d2c3_atomic_json(metadata_path, metadata)

    entry = {
        "sequence": sequence,
        "stepOrder": step,
        "actionId": str(action_id or ""),
        "label": str(label or ""),
        "url": str(metadata.get("url") or ""),
        "title": str(metadata.get("title") or ""),
        "workspace": str(metadata.get("workspace") or ""),
        "htmlFile": html_name,
        "metadataFile": metadata_name,
        "htmlSize": html_path.stat().st_size,
        "htmlSha256": html_hash,
    }
    index["pages"].append(entry)
    index["pageCount"] = len(index["pages"])
    index["updatedAtUtc"] = datetime.now(timezone.utc).isoformat()
    _d2c3_atomic_json(index_path, index)

    return {
        "relativePath": f"PageHtml/{html_name}",
        "metadataRelativePath": f"PageHtml/{metadata_name}",
        "indexRelativePath": "PageHtml/PageEvidenceIndex.json",
        "pageCount": len(index["pages"]),
        "sha256": html_hash,
        "size": html_path.stat().st_size,
    }
