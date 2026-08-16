from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
INVOKE = (ROOT / "Core" / "Invoke-DynomaxWorkflow.ps1").read_text(encoding="utf-8")
WORKFLOW = (ROOT / "Core" / "Execution" / "Dynomax.Workflow.ps1").read_text(encoding="utf-8")
RESULTS = (ROOT / "Core" / "Results" / "Dynomax.Results.ps1").read_text(encoding="utf-8")
RESOURCE = (ROOT / "Core" / "Robot" / "Dynomax.resource").read_text(encoding="utf-8")


def test_cleanup_preserves_main_browser_by_default_when_robot_blocks_are_compatible():
    assert "function Test-DynomaxPreservedCleanupBrowserSessionEligible" in INVOKE
    assert "$combined=@($MainSteps)+@($CleanupSteps)" in INVOKE
    assert "Runtime.CleanupBrowserSessionPreserved" in INVOKE
    assert "-PreserveCleanupBrowserSession:$true" in INVOKE
    assert "$preserveCleanupBrowserSession=$alwaysRunCleanup" in INVOKE


def test_explicit_requires_new_browser_keeps_isolated_cleanup_fallback():
    assert "RequiresNewBrowser on any Cleanup step is an explicit isolation request" in INVOKE
    assert "-eq 'RequiresNewBrowser'){return $false}" in INVOKE
    assert "Invoke-DynomaxStepSequence -Sequence $cleanupSteps" in INVOKE


def test_preserved_suite_jumps_directly_from_main_terminal_into_cleanup():
    assert "$useControlFlowDriver=$controlFlowEnabled -and $containsMainStep" in WORKFLOW
    assert "$usePreservedCleanupDriver=$useControlFlowDriver -and $PreserveCleanupBrowserSession -and $containsCleanupStep" in WORKFLOW
    assert "Execute Dynomax Cleanup Schedule" in WORKFLOW
    assert "IF    `${DYNOMAX_CLEANUP_STOP_REQUESTED}" in WORKFLOW
    assert "Suite Setup    Start Dynomax Browser" in WORKFLOW
    assert "Suite Teardown    Complete Dynomax Browser Suite" in WORKFLOW
    assert "$useControlFlowDriver=$controlFlowEnabled -and $containsMainStep -and -not $PreserveCleanupBrowserSession" not in WORKFLOW


def test_stop_cleanup_uses_explicit_persistence_and_batched_missing_slot_evidence():
    assert "Set Suite Variable    ${DYNOMAX_CLEANUP_STOP_REQUESTED}    ${True}" in RESOURCE
    assert "[bool]$IsCleanup = $false" in RESULTS
    assert "$batchSize=200" in RESULTS
    assert "UNION ALL" in RESULTS
    assert "-IsCleanup:$true" in INVOKE
    assert "Cleanup stopped after the first failed Cleanup Action because continueOnFailure is false." in INVOKE
