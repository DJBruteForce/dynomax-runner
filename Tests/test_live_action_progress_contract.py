import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]

def read(relative):
    return (ROOT / relative).read_text(encoding="utf-8")

def test_runtime_contract_advertises_live_action_progress():
    contract = json.loads(read("Core/RUNTIME_CONTRACT.json"))
    assert contract["runtimeRevision"] == "R20.7.6"
    assert "live-action-progress-v1" in contract["capabilities"]

def test_action_start_uses_existing_run_event_channel_without_actionrun_schema_change():
    workflow = read("Core/Execution/Dynomax.Workflow.ps1")
    orchestration = read("Core/Execution/Dynomax.Orchestration.ps1")
    assert "Runtime.ActionStarted" in workflow
    assert "Runtime.ActionStarted" in orchestration
    assert "Start-DynomaxActionRun" not in workflow
    assert "Start-DynomaxActionRun" not in orchestration

def test_robot_and_powershell_paths_mark_selected_action_running():
    workflow = read("Core/Execution/Dynomax.Workflow.ps1")
    resource = read("Core/Robot/Dynomax.resource")
    bridge = read("Core/Robot/DynomaxRuntimeBridge.py")
    host = read("Core/Execution/Invoke-DynomaxRunOrchestrationHost.ps1")
    assert workflow.count("Mark Dynomax Action Running") >= 1
    assert "Execute Dynomax Scheduled Slot" in workflow
    assert "EventType 'Runtime.ActionStarted'" in workflow
    assert "Dynomax Host Mark Action Running" in resource
    assert "def dynomax_host_mark_action_running" in bridge
    assert '"MarkActionRunning"' in bridge
    assert "'MarkActionRunning'" in host
