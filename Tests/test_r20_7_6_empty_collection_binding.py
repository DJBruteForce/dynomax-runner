from pathlib import Path
import re

ROOT = Path(__file__).resolve().parents[1]
INVOKE = (ROOT / "Core" / "Invoke-DynomaxWorkflow.ps1").read_text(encoding="ascii").replace("\r\n", "\n")
VERSION = (ROOT / "VERSION.txt").read_text(encoding="ascii").strip()


def _function(name: str) -> str:
    match = re.search(rf"function {re.escape(name)} \{{(?P<body>.*?)(?=\nfunction |\n\$mainSteps=)", INVOKE, re.S)
    assert match is not None, f"Function {name} was not found"
    return match.group(0)


def test_r20_7_6_revision_and_main_only_empty_cleanup_binding():
    assert VERSION == "R20.7.9"
    eligibility = _function("Test-DynomaxPreservedCleanupBrowserSessionEligible")
    assert "[Parameter(Mandatory)][AllowEmptyCollection()][object[]]$MainSteps" in eligibility
    assert "[Parameter(Mandatory)][AllowEmptyCollection()][object[]]$CleanupSteps" in eligibility
    assert "$MainSteps.Count -eq 0 -or $CleanupSteps.Count -eq 0" in eligibility
    assert "return $false" in eligibility


def test_cleanup_only_workflow_allows_empty_main_sequence():
    sequence = _function("Invoke-DynomaxStepSequence")
    assert "[Parameter(Mandatory)][AllowEmptyCollection()][object[]]$Sequence" in sequence
    assert "while($index -lt $Sequence.Count)" in sequence


def test_nonempty_main_and_cleanup_preserve_existing_eligibility_rules():
    eligibility = _function("Test-DynomaxPreservedCleanupBrowserSessionEligible")
    assert "DynomaxEngine" in eligibility
    assert "RobotBrowser" in eligibility
    assert "RequiresNewBrowser" in eligibility
    assert "return $true" in eligibility
