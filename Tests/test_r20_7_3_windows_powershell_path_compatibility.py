from pathlib import Path
import json

ROOT = Path(__file__).resolve().parents[1]
INVOKE = (ROOT / "Core" / "Invoke-DynomaxWorkflow.ps1").read_text(encoding="ascii")
RESULTS = (ROOT / "Core" / "Results" / "Dynomax.Results.ps1").read_text(encoding="ascii")
WORKFLOW = (ROOT / "Core" / "Execution" / "Dynomax.Workflow.ps1").read_text(encoding="ascii")
CONTRACT = json.loads((ROOT / "Core" / "RUNTIME_CONTRACT.json").read_text(encoding="utf-8"))


def test_runtime_revision_is_r20_7_3():
    assert CONTRACT["runtimeRevision"] == "R20.9"


def test_windows_powershell_runtime_does_not_call_path_getrelativepath():
    # Windows PowerShell 5.1 runs on .NET Framework, whose System.IO.Path does not
    # expose GetRelativePath. Core must use its own containment-aware helper.
    runtime_text = "\n".join((INVOKE, RESULTS, WORKFLOW))
    assert "[System.IO.Path]::GetRelativePath" not in runtime_text
    assert "function Get-DynomaxRelativePath" in RESULTS
    assert "Get-DynomaxRelativePath -BasePath $RunDirectory -TargetPath $File.FullName" in INVOKE
    assert "Get-DynomaxRelativePath -BasePath $source -TargetPath $file.FullName" in RESULTS


def test_relative_path_helper_is_containment_aware():
    assert "GetFullPath($BasePath)" in RESULTS
    assert "GetFullPath($TargetPath)" in RESULTS
    assert "StartsWith($prefix,[System.StringComparison]::OrdinalIgnoreCase)" in RESULTS
    assert "outside base path" in RESULTS
    assert "Substring($prefix.Length)" in RESULTS
