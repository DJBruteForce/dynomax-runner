# Dynomax Core 1.0.9 Acceptance Guide

## Installer acceptance

The patch must report PASS for:

- payload SHA-256 and length verification;
- Windows PowerShell 5.1 parsing of all payload executables;
- exact-version source-contract checks;
- installed payload SHA-256 verification;
- installed modified-file parser gate;
- complete installed Core parser gate.

## Required runtime proof before V2 publication is enabled

Use a disposable action and workflow fixture:

1. Import action v1.
2. Change the implementation and import action v2 so v2 is current.
3. Run a workflow that explicitly requests v1.
4. Confirm the v1 implementation executes.
5. Confirm `dmx.TestRun.WorkflowVersionId` is the exact imported workflow version.
6. Confirm `dmx.ActionRun.ActionVersionId` is v1.
7. Confirm `ActionResults.json` reports requested v1 and resolved v1.
8. Confirm `WorkflowManifest.json` reports v1, the exact action-version ID and `sourceVerified: true`.
9. Alter or remove the pinned v1 `action.json` or entry-point bytes before the run; preflight must fail before browser startup as `STALE`.
10. In a controlled fixture, change those same selected bytes after preflight but before action invocation; the immediate execution-boundary recheck must stop the action as `STALE`.
11. Run one legacy workflow without `actionVersion`; current-version compatibility must remain unchanged.

The package does not claim these runtime checks passed. They require the Windows Dynomax machine, SQL Server, Robot Framework Browser and the disposable acceptance fixture.
## Source-integrity boundary

Core 1.0.9 certifies the files represented by the existing V1 action catalogue: `action.json` and the declared entry point. A Robot entry point may itself import shared project resources. Those transitive resource files are not represented by an `ActionVersion` hash in the current V1 schema and therefore cannot yet be version-pinned independently. They must not be edited while a run is active. The later V2 compiler/publication bridge must either package transitive resources into an immutable payload or extend the catalogue manifest before publication is enabled.

