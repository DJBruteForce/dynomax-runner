import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]

def test_runtime_self_preflight_matches_manifest_revision():
    contract = json.loads((ROOT / "Core" / "RUNTIME_CONTRACT.json").read_text(encoding="utf-8"))
    workflow = (ROOT / "Core" / "Execution" / "Dynomax.Workflow.ps1").read_text(encoding="utf-8")
    revision = contract["runtimeRevision"]
    assert revision == "R20.7.7"
    assert f"$runtimeRevision -cne '{revision}'" in workflow
    assert f"Core 1.0.20 {revision} overlay" in workflow
    assert "R20.2 overlay" not in workflow

def test_runtime_contract_retains_compiler_compatibility_floor():
    contract = json.loads((ROOT / "Core" / "RUNTIME_CONTRACT.json").read_text(encoding="utf-8"))
    assert "1.19.15" in contract["compilerVersions"]
