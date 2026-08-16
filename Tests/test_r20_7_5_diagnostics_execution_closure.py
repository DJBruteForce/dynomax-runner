from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
INVOKE = (ROOT / "Core" / "Invoke-DynomaxWorkflow.ps1").read_text(encoding="ascii")
CONTRACT = (ROOT / "Core" / "RUNTIME_CONTRACT.json").read_text(encoding="ascii")
VERSION = (ROOT / "VERSION.txt").read_text(encoding="ascii").strip()


def test_r20_7_5_revision_and_explicit_diagnostic_handoff():
    assert VERSION == "R20.7.6"
    assert '"runtimeRevision": "R20.7.6"' in CONTRACT
    assert "[string]$CoreDiagnosticPath" in INVOKE
    assert "$coreDiagnosticHandoffPath" in INVOKE
    assert "foreach($diagnosticPath in $coreDiagnosticPaths)" in INVOKE
    assert "'core-diagnostics.jsonl'" in INVOKE


def test_execution_exception_is_durable_and_diagnostic():
    assert "-Stage 'Execution.Main'" in INVOKE
    assert "-Stage 'Execution.Cleanup'" in INVOKE
    assert "-Stage 'Execution.Unhandled'" in INVOKE
    assert "Workflow execution failed before normal Action completion" in INVOKE
    assert "Complete-DynomaxTestRun -SqlConfig $sqlConfig -RunId $runId -Status $overall" in INVOKE
