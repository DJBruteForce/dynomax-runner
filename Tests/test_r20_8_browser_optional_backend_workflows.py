from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
WORKFLOW = (ROOT / "Core" / "Execution" / "Dynomax.Workflow.ps1").read_text(encoding="utf-8")
VERSION = (ROOT / "VERSION.txt").read_text(encoding="utf-8").strip()
CONTRACT = (ROOT / "Core" / "RUNTIME_CONTRACT.json").read_text(encoding="utf-8")


def test_runtime_revision_is_r20_8():
    assert VERSION == "R20.9"
    assert '"runtimeRevision": "R20.9"' in CONTRACT


def test_robot_suite_browser_lifecycle_is_conditional():
    assert "$requiresBrowser=@($Steps|Where-Object" in WORKFLOW
    assert "DynomaxSessionBehavior" in WORKFLOW
    assert "-ne 'DoesNotUseBrowser'" in WORKFLOW
    assert "if($requiresBrowser){" in WORKFLOW
    assert "$lines.Add('Suite Setup    Start Dynomax Browser')" in WORKFLOW
    assert "$lines.Add('Suite Teardown    Complete Dynomax Browser Suite')" in WORKFLOW


def test_no_unconditional_browser_suite_setup_remains():
    marker = "$lines.Add('Suite Setup    Start Dynomax Browser')"
    position = WORKFLOW.index(marker)
    guard = WORKFLOW.rfind("if($requiresBrowser){", 0, position)
    assert guard >= 0
    assert position - guard < 300


def test_runtime_contract_advertises_browser_optional_workflows():
    import json
    contract = json.loads((ROOT / "Core" / "RUNTIME_CONTRACT.json").read_text(encoding="utf-8"))
    assert contract["runtimeRevision"] == "R20.9"
    assert "browser-optional-workflow-v1" in contract["capabilities"]


def test_core_browser_library_is_loaded_only_when_browser_is_started():
    resource = (ROOT / "Core" / "Robot" / "Dynomax.resource").read_text(encoding="utf-8")
    settings = resource.split("*** Keywords ***", 1)[0]
    assert "Library    Browser" not in settings
    normalized = resource.replace("\r\n", "\n")
    assert "Start Dynomax Browser\n    ${browser_library_loaded}=    Run Keyword And Return Status    Get Library Instance    Browser" in normalized
    assert "Import Library    Browser" in normalized
