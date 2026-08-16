# Dynomax Core 1.0.20 R20 cumulative overlay

Baseline: installed `C:\Dynomax` Core 1.0.19 R19 from the authoritative 2026-08-12 export.

```text
Overlay payload files: 18
Changed/new versus R19: 11
Carried byte-identical for cumulative safety: 7
Target VERSION.txt: 1.0.20
```

Stop Portal/Worker and extract the payload root directly into `C:\Dynomax`, preserving paths. The overlay is cumulative for the supplied R19 baseline and includes its executable runtime contract plus regression tests.

Changed/new versus R19:

- `Core/Execution/BUILTIN_CORE_CONTRACTS.json`
- `Core/Execution/Dynomax.ControlFlow.ps1`
- `Core/Execution/Dynomax.Orchestration.ps1`
- `Core/Execution/Dynomax.Workflow.ps1`
- `Core/Execution/Invoke-DynomaxControlFlow.ps1`
- `Core/Invoke-DynomaxWorkflow.ps1`
- `Core/Results/Dynomax.Results.ps1`
- `Core/Robot/Dynomax.resource`
- `Core/Robot/DynomaxContext.py`
- `Tests/test_continuation_contract.py`
- `VERSION.txt`

Carried byte-identical from R19:

- `Core/Database/Dynomax.Database.ps1`
- `Core/Execution/Invoke-DynomaxRunOrchestrationHost.ps1`
- `Core/Execution/Persist-DynomaxRobotAction.ps1`
- `Core/Execution/Record-DynomaxExecutionAttempt.ps1`
- `Core/Robot/DynomaxRuntimeBridge.py`
- `Tests/test_runtime_bridge.py`
- `Tests/test_runtime_values.py`
