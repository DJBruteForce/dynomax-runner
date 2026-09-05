import hashlib
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
CORE = ROOT / "Core"
CONTROL = (CORE / "Execution" / "Dynomax.ControlFlow.ps1").read_text(encoding="utf-8")
PARALLEL = (CORE / "Execution" / "Dynomax.Parallel.ps1").read_text(encoding="utf-8")
BRANCH = (CORE / "Execution" / "Invoke-DynomaxParallelBranch.ps1").read_text(encoding="utf-8")
WORKFLOW = (CORE / "Execution" / "Dynomax.Workflow.ps1").read_text(encoding="utf-8")
MAIN = (CORE / "Invoke-DynomaxWorkflow.ps1").read_text(encoding="utf-8")


def test_r20_9_contract_identity_capability_and_hash_closure():
    contract = json.loads((CORE / "RUNTIME_CONTRACT.json").read_text(encoding="utf-8"))
    assert (ROOT / "VERSION.txt").read_text(encoding="utf-8").strip() == "R20.9"
    assert contract["coreVersion"] == "1.0.20"
    assert contract["runtimeRevision"] == "R20.9"
    assert "1.19.20" in contract["compilerVersions"]
    assert "bounded-parallel-fork-v1" in contract["capabilities"]
    required = {
        "Core/Execution/Dynomax.ControlFlow.ps1",
        "Core/Execution/Dynomax.RuntimeContext.ps1",
        "Core/Execution/Dynomax.Parallel.ps1",
        "Core/Execution/Invoke-DynomaxParallelBranch.ps1",
        "Core/Execution/Dynomax.Workflow.ps1",
        "Core/Invoke-DynomaxWorkflow.ps1",
    }
    entries = {item["path"]: item for item in contract["files"]}
    assert required <= entries.keys()
    for relative, item in entries.items():
        payload = (ROOT / relative).read_bytes()
        assert len(payload) == item["length"]
        assert hashlib.sha256(payload).hexdigest() == item["sha256"]


def test_control_flow_exposes_explicit_bounded_parallel_wait_and_join():
    assert "maximumParallelism" in CONTROL
    assert "-gt 16" in CONTROL
    assert "executionMode=$executionMode" in CONTROL
    assert "'Parallel'" in CONTROL
    assert "Disposition='PARALLEL_WAIT'" in CONTROL
    assert "function Complete-DynomaxParallelFork" in CONTROL
    assert "Sort-Object index" in CONTROL
    assert "ForkBranchCompletedParallel" in CONTROL
    assert "ForkBranchFailedParallel" in CONTROL


def test_parallel_parent_uses_bounded_isolated_process_pool_and_deterministic_order():
    assert "System.Diagnostics.ProcessStartInfo" in PARALLEL
    assert "$activeProcesses.Count -lt $max" in PARALLEL
    assert "Sort-Object Index" in PARALLEL
    assert "executionSlot' -DefaultValue 1) -eq $slot" in PARALLEL
    assert "Copy-Item -LiteralPath $ContextPath -Destination $branchContext" in PARALLEL
    assert "Merge-DynomaxParallelBranchContexts" in PARALLEL
    assert "parallel-execution.jsonl" in PARALLEL
    assert "startedAtUtc" in PARALLEL and "endedAtUtc" in PARALLEL
    assert "finally{" in PARALLEL and ".Process.Kill()" in PARALLEL


def test_parallel_siblings_use_fork_visit_occurrence_not_branch_index_as_execution_slot():
    # executionSlot represents repeated occurrence of one logical Action. Distinct Fork branches
    # already have distinct node IDs, so branch index must never be used as an occurrence number.
    assert "$slot=$index+1" not in PARALLEL
    assert "forkHistory" in PARALLEL
    assert "$completedForkVisits" in PARALLEL
    assert "$slot=1+[int]$completedForkVisits" in PARALLEL

    # Model the runtime selection contract: on the first Fork visit every sibling selects slot 1;
    # on a later bounded revisit every sibling advances together to slot 2.
    branch_indices = list(range(7))
    first_visit_slots = [1 + 0 for _ in branch_indices]
    second_visit_slots = [1 + 1 for _ in branch_indices]
    assert first_visit_slots == [1] * 7
    assert second_visit_slots == [2] * 7


def test_parallel_branch_workflow_uses_synthetic_system_start_before_action_entry():
    # Control-flow initialization marks startNodeId through Set-DynomaxSystemNodeState.
    # Pointing startNodeId directly at the branch's first Action causes every isolated
    # branch to fail before executing an Action because Actions are not system nodes.
    assert "type='Start';displayName='Parallel branch start'" in PARALLEL
    assert "$controlFlow.startNodeId=$startNodeId" in PARALLEL
    assert "fromNodeId=$startNodeId" in PARALLEL
    assert "toNodeId=$startTargetNodeId" in PARALLEL
    assert "when='Success'" in PARALLEL
    assert "$controlFlow.startNodeId=$(if($region.Count -eq 0){$terminalNodeId}else{$targetNodeId})" not in PARALLEL


def test_branch_worker_reuses_standard_action_semantics_with_isolated_runtime_plan():
    assert "Dynomax.RuntimeContext.ps1" in BRANCH
    assert "Invoke-DynomaxRobotBlock" in BRANCH
    assert "Invoke-DynomaxPowerShellAction" in BRANCH
    assert "Enter-DynomaxStepInputContext" in BRANCH
    assert "Exit-DynomaxStepInputContext" in BRANCH
    assert "RuntimeWorkflowPath $BranchWorkflowPath" in BRANCH
    assert "DYNOMAX_PARALLEL_BRANCH_FAILED" in BRANCH
    assert "startedAtUtc" in BRANCH and "endedAtUtc" in BRANCH
    assert "if([int]$process.ExitCode -ne 0)" in BRANCH


def test_main_scheduler_keeps_parallel_branch_slots_out_of_parent_robot_process():
    assert "Get-DynomaxParallelForkRegionNodeIds" in MAIN
    assert "Invoke-DynomaxPendingParallelFork" in MAIN
    assert "$parallelConsumedOrders.Contains($candidateOrder)" in MAIN
    assert "$parallelRegionNodeIds.Contains($candidateNodeId)" in MAIN
    assert "escaped isolated branch scheduling" in MAIN
    assert "Physical Action slot was not selected by bounded parallel Fork execution." in MAIN
    assert "if($parallelRegions.Count -gt 0){return $false}" in MAIN


def test_portable_parallel_evidence_excludes_branch_context_and_worker_log():
    assert "parallel-execution.jsonl" in MAIN
    assert "-Filter 'branch-result.json'" in MAIN
    assert "Copy-Item -LiteralPath $parallelEvidence -Destination" not in MAIN
    candidate_line = next(line for line in MAIN.splitlines() if "parallel-execution\\.jsonl" in line and "return $relative -match" in line)
    assert "branch-result\\.json" in candidate_line
    assert "parallel/.+" not in candidate_line


def test_robot_suite_accepts_branch_local_control_flow_plan_without_changing_action_source_directory():
    assert "[string]$RuntimeWorkflowPath" in WORKFLOW
    assert "if($RuntimeWorkflowPath){$RuntimeWorkflowPath}" in WORKFLOW
    assert "-RuntimeWorkflowPath $RuntimeWorkflowPath" in WORKFLOW



def test_transient_pre_action_rpc_bootstrap_is_retried_once_without_masking_action_failures():
    assert "DYNOMAX_PARALLEL_BRANCH_TRANSIENT_BOOTSTRAP" in BRANCH
    assert "0x800706ba" in BRANCH.lower()
    assert "executed.Count -eq 0" in BRANCH
    assert "branchAttempt=[int]$BranchAttempt" in BRANCH
    assert "Runtime.ParallelBranchBootstrapRetry" in PARALLEL
    assert "$branchAttempt -lt 2" in PARALLEL
    assert "Copy-Item -LiteralPath $ContextPath -Destination ([string]$descriptor.ContextPath) -Force" in PARALLEL
    assert "if($activeProcesses.Count -gt 0){Start-Sleep -Milliseconds 100}" in PARALLEL
    assert "if([string]$result.status -ne 'Passed'){$failObserved=$true}" in PARALLEL

def test_empty_parallel_region_set_is_returned_as_one_object_for_linear_control_flow():
    # Windows PowerShell enumerates IEnumerable values written to the pipeline. An empty
    # HashSet therefore becomes $null at the caller unless it is explicitly non-enumerated.
    # The main scheduler immediately calls .Contains(), so preserve the HashSet object.
    assert CONTROL is not None
    assert PARALLEL.count("Write-Output -NoEnumerate $result") >= 2
    assert "$parallelRegionNodeIds=Get-DynomaxParallelForkRegionNodeIds" in MAIN
    assert "$parallelRegionNodeIds.Contains($logicalNodeId)" in MAIN
