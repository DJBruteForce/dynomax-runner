from pathlib import Path
import hashlib
import json

ROOT = Path(__file__).resolve().parents[1]
CORE = ROOT / "Core"


def read(rel: str) -> str:
    return (ROOT / rel).read_text(encoding="utf-8")


def test_runtime_contract_identity_and_hash_closure():
    manifest = json.loads(read("Core/RUNTIME_CONTRACT.json"))
    assert manifest["coreVersion"] == "1.0.20"
    assert manifest["runtimeRevision"] == "R20.14"
    assert "1.19.20" in manifest["compilerVersions"]
    assert "1.19.22" in manifest["compilerVersions"]
    assert "same-run-user-interaction-checkpoint-v1" in manifest["capabilities"]
    for item in manifest["files"]:
        p = ROOT / item["path"]
        data = p.read_bytes()
        assert len(data) == item["length"], item["path"]
        assert hashlib.sha256(data).hexdigest() == item["sha256"], item["path"]


def test_control_flow_pauses_and_resumes_same_state():
    control = read("Core/Execution/Dynomax.ControlFlow.ps1")
    assert "'UserInteraction' {" in control
    assert "$State.waitingForUser=$true" in control
    assert "$State.interactionCheckpoint=" in control
    assert "function Resume-DynomaxControlFlowInteraction" in control
    assert "$state.waitingForUser=$false" in control
    assert "InteractionCheckpointResumed" in control
    assert "Move-DynomaxControlFlowToNextExecutable -Workflow $Workflow -Context $context -State $state -FromNodeId $NodeId -Outcome 'Success'" in control


def test_invoke_reuses_core_run_and_defers_cleanup_result_finalization():
    invoke = read("Core/Invoke-DynomaxWorkflow.ps1")
    results = read("Core/Results/Dynomax.Results.ps1")
    assert "$runId=$resumeRunId" in invoke
    assert "Resume-DynomaxTestRun -SqlConfig $sqlConfig -RunId $runId" in invoke
    assert "if(-not $waitingAfterMain -and $alwaysRunCleanup" in invoke
    assert "$hasUserInteraction=(Test-DynomaxControlFlowEnabled -Workflow $workflow) -and" in invoke
    assert "$hasUserInteraction=Test-DynomaxControlFlowEnabled -Workflow $workflow -and" not in invoke
    assert "Set-DynomaxTestRunWaitingForUser" in invoke
    assert "FinalizationStatus 'DeferredForUser'" in invoke
    assert "FinalizationStep 'InteractionCheckpointPersisted'" in invoke
    assert "ResultZipPath $null" in invoke
    assert "[string]$InteractionCheckpointPath" in invoke
    assert "Write-DynomaxJson -Value $checkpointPayload -Path $checkpointHandoffPath" in invoke
    assert "function Resume-DynomaxTestRun" in results
    assert "function Set-DynomaxTestRunWaitingForUser" in results
    assert "RunContinuation" not in invoke


def test_robot_stops_physical_slots_at_waiting_checkpoint():
    robot = read("Core/Robot/Dynomax.resource")
    orchestration = read("Core/Execution/Dynomax.Orchestration.ps1")
    assert "^(RUN|DEFER|SKIP_FINAL|WAITING_FOR_USER)$" in robot
    assert "^(CONTINUE|WAITING_FOR_USER|TERMINAL_PASS|TERMINAL_FAIL|TERMINAL_BLOCKED)$" in robot
    assert "${DYNOMAX_CONTROL_FLOW_WAITING_FOR_USER}" in robot
    assert "return 'WAITING_FOR_USER'" in orchestration
