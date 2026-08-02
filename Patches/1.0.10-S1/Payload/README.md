# Dynomax Core 1.0.10

Dynomax Core is the project-neutral Windows execution runtime. Robot Framework Browser, Playwright, PowerShell and SQL Server are installed once on the runner. Dynomax V2 stores authored Action source, immutable Test publications, run requests and result packages in SQL.

## Database-publication execution mode

Core 1.0.10 adds a guarded bridge for exact Dynomax V2 database publications:

```text
SQL publication package
-> local worker verifies every package hash
-> worker creates a disposable project/workflow directory
-> worker resolves approved environment-variable secrets into a temporary context file
-> Core executes the already-published exact workflow and Action versions
-> Core stores TestRun/ActionRun/evidence in dmx
-> worker imports the result ZIP into SQL
-> temporary source, secret context and exported ZIP are deleted
```

A database-published workflow sets:

```json
{
  "catalogueAlreadyPublished": true,
  "workflowVersionId": "<exact immutable dmx workflow version ID>"
}
```

In this mode Core does not import project, Action or workflow definitions from disk. It verifies the exact published catalogue version and uses disposable source files only for execution.

## Secret boundary

The V2 worker resolves only explicitly allowed environment-variable references. It supplies a `secretKeys` list in the temporary context seed. Core keeps the secret values available to the running Action but persists only a redacted marker to `dmx.RunContextValue` with `IsSecret = 1`. `context.json` is excluded from evidence ingestion.

Action authors must still use secret-safe engine keywords. A password or token must never be printed, returned as an output, added to diagnostics, embedded in a screenshot, or passed to a keyword that records its value.

## Existing exact-version behavior

Core 1.0.10 preserves the accepted 1.0.9 guarantees:

- explicit workflow and Action versions are authoritative;
- exact `ActionVersionId` and `WorkflowVersionId` values are recorded;
- action definition and entry-point hashes are verified before execution and immediately before invocation;
- missing or changed pinned source fails closed as `TEST_INVALID` or `STALE`;
- legacy unversioned workflows retain current-version compatibility;
- pinned workflows remain fail-fast and use one contiguous normal Robot block plus one independent cleanup block.

## Runtime arguments added in 1.0.10

`Core\Invoke-DynomaxWorkflow.ps1` now supports:

- `-RuntimeProjectFolder`
- `-ContextSeedPath`
- `-RunContractPath`
- `-SuppressClipboard`

These parameters are intended for the local Dynomax V2 worker. Existing project-folder runners remain compatible.

## Persistent and temporary storage

Persistent project source no longer needs to exist under `C:\Dynomax\Project-Setup` for V2 database publications. Temporary execution material is still required by Robot Framework and PowerShell and is created only for the duration of a run.

Core continues to use:

- `C:\Dynomax\Temp\Runs` for its internal run workspace;
- `C:\Dynomax\Exports` for a completed result ZIP;
- the V2 worker's `C:\Dynomax\Temp\V2Runs` directory for disposable publication materialization.

## Installation

Install this patch only after Dynomax Core 1.0.9 is present. The patch installer supports an idempotent rerun when 1.0.10 is already installed. It performs no SQL changes and starts no workflow.

## Secret-safe context bridge hotfix S1

Core remains version `1.0.10` so existing exact-version publication and worker contracts remain valid. The S1 hotfix adds `Fill Dynomax Secret`, which accepts only a selector and a context-key name, suppresses ordinary Robot logging while reading the temporary secret context, requires the key to be listed in `secretKeys`, and passes the value directly to Browser Library `Fill Secret`. The hotfix does not enable Playwright debug logging and does not change SQL.
