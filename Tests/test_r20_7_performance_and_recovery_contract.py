import base64
import hashlib
import importlib.util
import json
import sys
import tempfile
import types
from pathlib import Path

import pytest

ROOT = Path(__file__).resolve().parents[1]
INVOKE = (ROOT / "Core" / "Invoke-DynomaxWorkflow.ps1").read_text(encoding="utf-8")
RESULTS = (ROOT / "Core" / "Results" / "Dynomax.Results.ps1").read_text(encoding="utf-8")
WORKFLOW = (ROOT / "Core" / "Execution" / "Dynomax.Workflow.ps1").read_text(encoding="utf-8")
HOST = (ROOT / "Core" / "Execution" / "Invoke-DynomaxRunOrchestrationHost.ps1").read_text(encoding="utf-8")
RESOURCE = (ROOT / "Core" / "Robot" / "Dynomax.resource").read_text(encoding="utf-8")
MANIFEST_PATH = ROOT / "Core" / "RUNTIME_CONTRACT.json"


def _load_context_module():
    robot = types.ModuleType("robot")
    robot_api = types.ModuleType("robot.api")
    robot_deco = types.ModuleType("robot.api.deco")
    robot_deco.keyword = lambda name=None: (lambda func: func)
    robot_deco.library = lambda **kwargs: (lambda cls: cls)
    sys.modules.setdefault("robot", robot)
    sys.modules.setdefault("robot.api", robot_api)
    sys.modules.setdefault("robot.api.deco", robot_deco)
    path = ROOT / "Core" / "Robot" / "DynomaxContext.py"
    spec = importlib.util.spec_from_file_location("dynomax_context_r20_7", path)
    module = importlib.util.module_from_spec(spec)
    assert spec.loader is not None
    spec.loader.exec_module(module)
    return module


def test_contract_is_checkpointed_before_fallible_finalization_and_tracks_exact_step():
    initial = INVOKE.index("-FinalizationStatus 'NotStarted' -FinalizationStep 'NotStarted'")
    normal_export = INVOKE.index("Export-DynomaxRunSummary")
    assert initial < normal_export
    assert "function Write-DynomaxRunContractAtomic" in INVOKE
    assert "Move-Item -LiteralPath $temporary -Destination $resolved -Force" in INVOKE
    assert "function Set-DynomaxFinalizationStep" in INVOKE
    for step in (
        "FinalContextCheckpoint", "SqlEvidenceIngestion", "PrepareExportStaging",
        "ExportRunSummary", "CopyEvidence", "CopyDefinitions", "WriteWorkflowManifest",
        "CleanupTemporaryWorkspace", "WriteExportManifest", "BuildResultZip",
        "Recovery.ExportRunSummary", "Recovery.BuildResultZip",
    ):
        assert step in INVOKE
    assert "finalizationStep=$FinalizationStep" in INVOKE
    assert "FinalizationRecovery.json" in INVOKE
    assert "$finalizationStatus='Recovered'" in INVOKE


def test_run_data_pool_persists_one_bounded_step_row_instead_of_rewriting_history():
    assert "function Set-DynomaxRunDataPoolStepInSql" in RESULTS
    assert "__dynomax.runDataPool.step." in RESULTS
    assert "[System.Security.Cryptography.SHA256]::Create()" in RESULTS
    assert "@ContextKey AS ContextKey" in RESULTS
    assert "JSON_MODIFY(@Current,@JsonPath,JSON_QUERY(@StepJson))" not in RESULTS
    assert "-PersistRunDataPool:$false -InspectRunDataPool:$false" in RESULTS
    assert "Set-DynomaxContextStepInSql" in RESULTS
    assert "$runDataPoolStepPrefix='__dynomax.runDataPool.step.'" in RESULTS
    assert "Set-DynomaxContextObjectProperty -Object $steps -Name $stepId -Value $safeStep" in RESULTS
    assert "DELETE FROM dmx.RunContextValue" in RESULTS
    assert "ContextKey LIKE N'__dynomax.runDataPool.step.%'" in RESULTS


def test_batched_context_write_rolls_back_its_transaction_before_rethrow():
    assert "BEGIN TRY" in RESULTS
    assert "IF XACT_STATE()<>0 ROLLBACK TRANSACTION;" in RESULTS
    assert "THROW;" in RESULTS


def test_runtime_context_combines_step_boundaries_and_uses_atomic_cache():
    context = _load_context_module()
    specs = base64.b64encode(json.dumps([
        {"name": "result", "classification": "Normal", "persistInResult": True}
    ]).encode()).decode()
    with tempfile.TemporaryDirectory() as temp:
        path = Path(temp) / "context.json"
        path.write_text(json.dumps({
            "schemaVersion": 2,
            "secretKeys": [],
            "values": {"keep": "yes"},
            "runDataPool": {"schemaVersion": 1, "steps": {}},
            "stepInputs": {"step-1": {"values": {"input": "abc"}, "secretKeys": [], "deferredBindings": []}}
        }), encoding="utf-8")
        context.begin_step_scope(str(path), "step-1", specs)
        during = json.loads(path.read_text(encoding="utf-8"))
        assert during["values"]["input"] == "abc"
        during["values"]["result"] = "ok"
        path.write_text(json.dumps(during), encoding="utf-8")
        context.complete_step_scope(str(path), "step-1", "node-1", "1", "data.string.replace", specs)
        final = json.loads(path.read_text(encoding="utf-8"))
        assert final["values"]["keep"] == "yes"
        assert "input" not in final["values"]
        assert final["runDataPool"]["steps"]["step-1"]["outputs"]["result"]["value"] == "ok"
        assert not list(path.parent.glob("*.tmp"))


def test_control_flow_is_kept_in_memory_and_checkpointed_in_bounded_intervals():
    assert "$controlFlowCheckpointInterval=25" in HOST
    assert "-State $controlFlowState -SkipStateWrite" in HOST
    assert "Save-DynomaxHostControlFlowCheckpoint -Force:([bool]$terminal)" in HOST
    assert "Save-DynomaxHostControlFlowCheckpoint -Force" in HOST


def test_robot_schedule_and_result_definitions_are_compact_and_deduplicated():
    assert "Execute Dynomax Scheduled Slot" in WORKFLOW
    assert "Begin Dynomax Step Scope" in RESOURCE
    assert "Complete Dynomax Step Scope" in RESOURCE
    assert "$fingerprintsByActionVersionId=@{}" in WORKFLOW
    assert "$copiedActionDefinitions=@{}" in INVOKE
    assert "uniqueActionDefinitionCount" in INVOKE
    assert "definitionRelativePath" in INVOKE
    assert "function Test-DynomaxSqlEvidenceCandidate" in INVOKE
    assert "$File.Length -le 0" in INVOKE
    assert "Copy-DynomaxAttemptRecorderEvidence" in INVOKE


def test_runtime_contract_closes_the_exact_r20_7_overlay():
    manifest = json.loads(MANIFEST_PATH.read_text(encoding="utf-8"))
    assert manifest["runtimeRevision"] == "R20.7.6"
    expected = {
        "run-contract-finalization-recovery-v1",
        "run-data-pool-delta-persistence-v1",
        "runtime-context-cache-v1",
        "control-flow-checkpoint-v1",
        "compact-robot-schedule-v1",
        "result-definition-deduplication-v1",
        "control-flow-event-batch-v1",
        "context-value-batch-persistence-v1",
        "result-evidence-compaction-v1",
        "structured-form-actions-v1",
        "context-value-batch-fallback-v1",
        "core-diagnostics-jsonl-v1",
    }
    assert expected.issubset(set(manifest["capabilities"]))
    for entry in manifest["files"]:
        payload = (ROOT / entry["path"]).read_bytes()
        assert entry["length"] == len(payload)
        assert entry["sha256"] == hashlib.sha256(payload).hexdigest()


def test_context_batch_has_deterministic_per_key_fallback_and_startup_contract():
    assert "function Set-DynomaxContextValuesIndividuallyInSql" in RESULTS
    assert "Runtime.ContextBatchFallback" in RESULTS
    assert "__dynomax.contextBatchDisabled" in RESULTS
    assert "CORE_CONTEXT_INITIALIZATION_FAILED" in INVOKE
    assert "InitialContextPersistence" in INVOKE
    assert "core-diagnostics.jsonl" in INVOKE
