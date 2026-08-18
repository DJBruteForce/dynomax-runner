import hashlib
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
WORKFLOW = (ROOT / "Core" / "Invoke-DynomaxWorkflow.ps1").read_text(encoding="utf-8")
RESULTS = (ROOT / "Core" / "Results" / "Dynomax.Results.ps1").read_text(encoding="utf-8")
CONTRACT_PATH = ROOT / "Core" / "RUNTIME_CONTRACT.json"
CONTRACT = json.loads(CONTRACT_PATH.read_text(encoding="utf-8"))
VERSION = (ROOT / "VERSION.txt").read_text(encoding="utf-8").strip()


def test_r20_7_8_collects_pdf_downloads_into_result_evidence():
    assert VERSION == "R20.7.9"
    assert CONTRACT["runtimeRevision"] == "R20.7.9"
    assert "pdf-result-evidence-v1" in CONTRACT["capabilities"]
    assert "xml|html?|log|png|jpe?g|pdf|json" in WORKFLOW
    assert "StartsWith('downloads/'" in WORKFLOW
    assert "StartsWith('documents/'" in WORKFLOW
    assert "Join-Path $testEvidence 'Documents'" in WORKFLOW
    assert "foreach($documentRootName in @('downloads','documents'))" in WORKFLOW
    assert "Join-Path $documentsEvidence $documentRootName" in WORKFLOW
    assert "'.pdf' { 'application/pdf' }" in RESULTS


def test_runtime_contract_hashes_match_exact_installed_files():
    for entry in CONTRACT["files"]:
        path = ROOT / entry["path"]
        data = path.read_bytes()
        assert len(data) == entry["length"], entry["path"]
        assert hashlib.sha256(data).hexdigest() == entry["sha256"], entry["path"]
