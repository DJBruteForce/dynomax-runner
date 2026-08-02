# Dynomax Core 1.0.9 exact-version runtime acceptance fixture 1.0.1

This package performs the real runtime acceptance for the Dynomax Core 1.0.9 exact-action-version patch.

## Version 1.0.1 correction

Fixture 1.0.0 completed all three Core scenarios and all SQL/evidence checks, but Windows PowerShell 5.1 threw `Argument types do not match` while converting the in-memory generic check list during final report generation. Version 1.0.1 uses explicit typed arrays for the JSON and Markdown reports. No Core source, workflow contract, database schema or acceptance expectation changed.

## What it proves

One BAT file runs three isolated workflows:

1. **Pinned version test** - action v2 is current, but a workflow explicitly requesting v1 must execute v1.
2. **Legacy compatibility test** - an unversioned workflow must retain current-version behaviour and execute v2.
3. **Stale source test** - a workflow pinned to v1 without exact v1 source bytes must fail as `STALE` before the action is invoked.

The fixture checks exported evidence and performs read-only SQL verification that `TestRun.WorkflowVersionId` and `ActionRun.ActionVersionId` match the exact versions recorded in `WorkflowManifest.json` and `ActionResults.json`.

## Safety boundary

- No ATX project, ATX action, tenant, browser, credential or website is used.
- No database migration or schema change is performed.
- No direct SQL data cleanup is performed.
- The fixture creates or reuses one clearly labelled isolated Dynomax test project through the standard Core catalogue APIs.
- Re-running the package is idempotent: exact action and workflow definitions are reused instead of creating duplicate versions.
- The fixture replaces only its own folder under `C:\Dynomax\Project-Setup\Dynomax-Core-1.0.9-Exact-Version-Acceptance-R1`.
- Catalogue and run records are retained as acceptance evidence.

## How to run

1. Extract the package to:

   `C:\Dynomax\Patches.0.9\Exact-Version-Acceptance-Fixture`

2. Double-click:

   `Run-Exact-Version-Acceptance.bat`

3. Wait for the final `ACCEPTANCE RESULT: PASS` or `FAIL` message.

4. The script creates a result package under:

   `C:\Dynomax\Patches.0.9\Exact-Version-Acceptance-Fixture\Results`

Upload the generated `Dynomax_Core_1.0.9_ExactVersion_Acceptance_*.zip` for review.

## Prerequisites

- Dynomax Core 1.0.9 installed under `C:\Dynomax`.
- `C:\Dynomax\Patches.0.9\InstalledReceipt.json` exists.
- The existing Dynomax SQL Server database is reachable using `C:\Dynomax\Config-And-Setup-Database\database.json`.
- Windows PowerShell 5.1 and the normal Dynomax prerequisites are installed.

## Expected checks

The final report must show:

- Core and installed receipt version 1.0.9.
- Fixture action v1 and v2 imported, with v2 current.
- Pinned workflow output marker `VERSION-1`.
- Legacy workflow output marker `VERSION-2`.
- Pinned workflow SQL and result evidence identify action v1.
- Legacy workflow SQL and result evidence identify action v2.
- Stale workflow ends as `STALE`, identifies requested v1, and produces no action output file.

## Database classification

**DATA CHANGE - isolated acceptance data only.**

The standard Dynomax catalogue and runner APIs create or reuse the clearly labelled fixture project, immutable action/workflow versions and run evidence. No SQL script is supplied or manually executed, and no existing project data is updated or deleted.
