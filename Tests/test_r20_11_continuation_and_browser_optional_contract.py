import hashlib
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
CONTRACT = ROOT / "Core" / "RUNTIME_CONTRACT.json"
VERSION = ROOT / "VERSION.txt"
WORKFLOW = ROOT / "Core" / "Execution" / "Dynomax.Workflow.ps1"
RESOURCE = ROOT / "Core" / "Robot" / "Dynomax.resource"


def test_r20_11_identity_and_capabilities():
    contract = json.loads(CONTRACT.read_text(encoding="utf-8"))
    assert VERSION.read_text(encoding="utf-8").strip() == "R20.11"
    assert contract["coreVersion"] == "1.0.20"
    assert contract["runtimeRevision"] == "R20.11"
    assert "bounded-parallel-fork-v1" in contract["capabilities"]
    assert "browser-optional-action-timeout-v1" in contract["capabilities"]


def test_core_side_continuation_gate_accepts_r20_11_not_r20_9():
    text = WORKFLOW.read_text(encoding="utf-8")
    assert "$runtimeRevision -cne 'R20.11'" in text
    assert "$runtimeRevision -cne 'R20.9'" not in text
    assert "R20.11 overlay" in text


def test_non_browser_actions_do_not_require_browser_timeout_keyword():
    text = RESOURCE.read_text(encoding="utf-8").replace("\r\n", "\n")
    start = text.index("Execute Dynomax Action With Policy")
    end = text.rindex("Invoke Dynomax Attempt Recorder")
    policy = text[start:end]
    guard = "${browser_library_loaded}=    Run Keyword And Return Status    Get Library Instance    Browser"
    apply = "${previous_browser_timeout}=    Set Browser Timeout    ${effective_timeout}s    scope=Test"
    assert guard in policy
    assert "IF    ${browser_library_loaded}\n            " + apply in policy
    assert policy.count("Set Browser Timeout") == 2


def test_manifest_closure_matches_full_overlay():
    contract = json.loads(CONTRACT.read_text(encoding="utf-8"))
    required = {
        "Core/Database/Dynomax.Database.ps1",
        "Core/Robot/Dynomax.resource",
        "Core/Robot/DynomaxContext.py",
        "Core/Robot/DynomaxRuntimeBridge.py",
        "Core/Results/Dynomax.Results.ps1",
        "Core/Execution/Dynomax.ControlFlow.ps1",
        "Core/Execution/Dynomax.RuntimeContext.ps1",
        "Core/Execution/Dynomax.Parallel.ps1",
        "Core/Execution/Invoke-DynomaxParallelBranch.ps1",
        "Core/Execution/Dynomax.Orchestration.ps1",
        "Core/Execution/Invoke-DynomaxRunOrchestrationHost.ps1",
        "Core/Execution/Dynomax.Workflow.ps1",
        "Core/Invoke-DynomaxWorkflow.ps1",
    }
    entries = {item["path"]: item for item in contract["files"]}
    assert required <= entries.keys()
    for rel, entry in entries.items():
        data = (ROOT / rel).read_bytes()
        assert entry["length"] == len(data)
        assert entry["sha256"] == hashlib.sha256(data).hexdigest()
