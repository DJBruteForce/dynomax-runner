from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
CORE = ROOT / "Core"
RESULTS = (CORE / "Results" / "Dynomax.Results.ps1").read_text(encoding="ascii")
CONTRACT = (CORE / "RUNTIME_CONTRACT.json").read_text(encoding="ascii")


def test_runtime_revision_is_r20_7_2():
    assert '"runtimeRevision": "R20.9"' in CONTRACT


def test_new_object_generic_object_list_is_not_used_anywhere_in_core():
    offenders = []
    needle = "New-Object System.Collections.Generic.List[object]"
    for path in CORE.rglob("*.ps1"):
        text = path.read_text(encoding="ascii")
        if needle in text:
            offenders.append(str(path.relative_to(ROOT)))
    assert offenders == []


def test_initial_context_pending_list_uses_constructor_and_to_array():
    assert "$pendingValues=[System.Collections.Generic.List[object]]::new()" in RESULTS
    assert "foreach($pending in $pendingValues.ToArray())" in RESULTS
    assert "foreach($pending in @($pendingValues))" not in RESULTS


def test_context_batch_fallback_remains_present():
    assert "Runtime.ContextBatchFallback" in RESULTS
    assert "Set-DynomaxContextValuesIndividuallyInSql" in RESULTS
