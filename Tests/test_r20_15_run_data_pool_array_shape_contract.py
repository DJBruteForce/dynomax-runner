from pathlib import Path
import hashlib
import json
import re

ROOT = Path(__file__).resolve().parents[1]
RESULTS = (ROOT / "Core" / "Results" / "Dynomax.Results.ps1").read_text(encoding="ascii")


def _function(name: str) -> str:
    match = re.search(rf"function {re.escape(name)} \{{(?P<body>.*?)(?=\nfunction |\Z)", RESULTS, re.S)
    assert match is not None, f"Function {name} was not found"
    return match.group(0)


def test_safe_run_data_pool_projection_preserves_json_collection_identity():
    safe_step = _function("ConvertTo-DynomaxSafeRunDataPoolStep")

    # Do not retrieve output.value through a PowerShell function call. Function
    # output enumerates collections, collapsing one-element arrays to a scalar
    # and losing empty arrays before RunDataPool.json is persisted.
    assert "$valueProperty=$output.PSObject.Properties['value']" in safe_step
    assert "if($null -ne $valueProperty){$safeValue=$valueProperty.Value}" in safe_step
    assert "value=$safeValue" in safe_step
    assert "Get-DynomaxPropertyValue -Object $output -Name 'value'" not in safe_step


def test_safe_run_data_pool_projection_keeps_existing_exposure_gate():
    safe_step = _function("ConvertTo-DynomaxSafeRunDataPoolStep")

    assert "$safeValue=$null" in safe_step
    assert "if($canExpose){" in safe_step
    assert "$canExpose=$available -and $classification -eq 'Normal' -and $persist" in safe_step
    assert "redacted=(-not $canExpose -and $available)" in safe_step


def test_results_runtime_contract_is_line_ending_stable():
    manifest = json.loads((ROOT / "Core" / "RUNTIME_CONTRACT.json").read_text(encoding="ascii"))
    entry = next(item for item in manifest["files"] if item["path"] == "Core/Results/Dynomax.Results.ps1")

    assert entry["hashMode"] == "Utf8CanonicalCrLfV1"

    text = (ROOT / entry["path"]).read_text(encoding="ascii")
    canonical_text = text.replace("\r\n", "\n").replace("\r", "\n").replace("\n", "\r\n")
    canonical_bytes = canonical_text.encode("utf-8")

    assert len(canonical_bytes) == entry["length"]
    assert hashlib.sha256(canonical_bytes).hexdigest() == entry["sha256"]
