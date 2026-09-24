from pathlib import Path
import json

ROOT = Path(__file__).resolve().parents[1]


def test_r20_16_is_cumulative_and_enforces_deferred_network_targets():
    contract = json.loads((ROOT / "Core" / "RUNTIME_CONTRACT.json").read_text(encoding="utf-8"))
    context = (ROOT / "Core" / "Robot" / "DynomaxContext.py").read_text(encoding="utf-8")
    workflow = (ROOT / "Core" / "Execution" / "Dynomax.Workflow.ps1").read_text(encoding="utf-8")
    version = (ROOT / "VERSION.txt").read_text(encoding="utf-8").strip()

    assert version == "R20.16"
    assert contract["runtimeRevision"] == "R20.16"
    assert "runtime-deferred-network-target-policy-v1" in contract["capabilities"]

    # R20.16 is an overlay on the current R20.15 runner, never a rollback to
    # the stale packaging baseline used when CM-001148 first emitted its manifest.
    for capability in {
        "user-interaction-response-materialization-v1",
        "action-source-preflight-dedup-v1",
        "post-action-context-reuse-v1",
        "sanitized-run-performance-summary-v1",
        "runtime-contract-canonical-text-hash-v1",
    }:
        assert capability in contract["capabilities"]

    assert "_validate_runtime_network_target" in context
    assert '"StepOutput", "RuntimeValue", "RuntimeInput"' in context
    assert "DMX-AUTO-HOST-BOUNDARY" in context
    assert "runtimePolicy" in context
    assert "allowedOrigins" in context
    assert "$runtimeRevision -cne 'R20.16'" in workflow
    assert "Core 1.0.20 R20.16 overlay" in workflow
    assert "'runtime-deferred-network-target-policy-v1' -notin $capabilities" in workflow
