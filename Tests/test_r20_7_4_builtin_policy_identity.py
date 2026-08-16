from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
WORKFLOW = (ROOT / "Core" / "Execution" / "Dynomax.Workflow.ps1").read_text(encoding="utf-8")
POLICY = (ROOT / "Core" / "Execution" / "BUILTIN_CORE_CONTRACTS.json").read_text(encoding="utf-8")
CONTRACT = (ROOT / "Core" / "RUNTIME_CONTRACT.json").read_text(encoding="utf-8")
VERSION = (ROOT / "VERSION.txt").read_text(encoding="utf-8").strip()

def test_builtin_policy_separates_semantic_version_from_runtime_revision():
    assert '"coreVersion": "1.0.20"' in POLICY
    assert '"coreVersion": "1.0.20"' in CONTRACT
    assert '"runtimeRevision": "R20.7.6"' in CONTRACT
    assert VERSION == 'R20.7.6'
    assert "$declaredCoreVersion -cne $installedCoreVersion" in WORKFLOW
    assert "$runtimeContractRevision -cne $installedRuntimeRevision" in WORKFLOW
    assert "$declaredCoreVersion -cne $installedRuntimeRevision" not in WORKFLOW

def test_builtin_policy_reads_semantic_core_version_from_runtime_contract():
    assert "$installedCoreVersion = [string](Get-DynomaxPropertyValue -Object $runtimeContract -Name 'coreVersion'" in WORKFLOW
    assert "InstalledRuntimeRevision = $installedRuntimeRevision" in WORKFLOW
