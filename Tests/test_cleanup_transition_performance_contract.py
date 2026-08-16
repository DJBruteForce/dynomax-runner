from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
WORKFLOW = (ROOT / "Core" / "Execution" / "Dynomax.Workflow.ps1").read_text(encoding="utf-8")
RESULTS = (ROOT / "Core" / "Results" / "Dynomax.Results.ps1").read_text(encoding="utf-8")


def test_preserved_control_flow_does_not_fall_back_to_one_robot_test_per_physical_slot():
    assert "$useControlFlowDriver=$controlFlowEnabled -and $containsMainStep" in WORKFLOW
    assert "Execute Dynomax Control Flow Schedule" in WORKFLOW
    assert "Execute Dynomax Cleanup Schedule" in WORKFLOW
    assert "if(-not $useControlFlowDriver){$lines.Add('Test Teardown    Persist Dynomax Robot Action Result')}" in WORKFLOW


def test_missing_slot_finalization_is_batched_not_one_insert_round_trip_per_slot():
    assert "$batchSize=200" in RESULTS
    assert "$desiredSql=[string]::Join" in RESULTS
    assert "WITH desired AS (" in RESULTS
    assert "WHERE NOT EXISTS(SELECT 1 FROM dmx.ActionRun" in RESULTS
