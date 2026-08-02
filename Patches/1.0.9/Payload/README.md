# Dynomax 1.0.9

Dynomax is a project-neutral Windows testing framework driven by BAT, PowerShell, JSON and SQL migration files. Robot Framework Browser and Playwright are execution engines. SQL Server is the persistent catalogue, framework-validation history, project catalogue and test-result store.

## Framework boundary

Dynomax Core contains no target-project URLs, credentials, selectors, workflows or business rules.

Target-specific details exist only below:

```text
Project-Setup\<Project Name>
```

Deleting or moving one project folder does not change Dynomax Core. Adding another project requires project configuration, reusable actions and workflow sessions under its own folder.

## Initial requirements

- Windows Server or Windows workstation
- Windows PowerShell 5.1 or PowerShell 7
- SQL Server or SQL Server Express reachable from the machine
- Permission to create or update the configured `Dynomax` database
- Python, Node.js, Robot Framework Browser and Playwright, which Dynomax can check and optionally install
- Network access to each website configured by a project

Anything else is configuration-based.

## Main folders

- `Config-And-Setup`: framework prerequisite, database, core, installation-validation and generic self-test tasks.
- `Core`: project-neutral PowerShell orchestration, SQL, process, Robot and result logic.
- `Project-Setup`: isolated project folders containing project configuration, reusable actions and workflow sessions.
- `Patches`: versioned patch installers, notes, payloads and legacy patch files.
- `Temp\Runs`: temporary execution data; deleted after successful SQL ingestion when configured.
- `Exports`: compact project-workflow handback ZIP files.

## Install

1. Extract the top-level `Dynomax` folder to `C:\Dynomax`.
2. Review:
   - `Config-And-Setup\01-Prerequisites\prerequisites.json`
   - `Config-And-Setup\02-Database\database.json`
3. Run `Install-Dynomax.bat` as a Windows account allowed to create the configured SQL database.
4. Run `Run-Dynomax-Self-Test.bat`.

## Generic framework self-test

`Run-Dynomax-Self-Test.bat` validates:

- Windows and PowerShell
- required execution libraries
- the Dynomax SQL connection, schema and binary persistence
- Robot Framework Browser
- Chromium against a temporary local HTML fixture
- SQL storage of the validation result and selected evidence

It does not load a project, contact an external website or use project credentials.

`Run-Initial-Validation.bat` remains only as a compatibility wrapper and now runs the same project-neutral self-test.


## Exact workflow and action versions

Dynomax 1.0.9 makes explicit workflow and action versions authoritative during execution. A workflow step that contains `actionVersion` is resolved to that exact immutable catalogue version. Dynomax verifies the selected `action.json` and entry-point hashes during preflight and re-verifies them immediately before Robot-suite generation or PowerShell invocation. Missing, changed or mismatched historical source bytes fail closed as `TEST_INVALID` or `STALE` before the action starts.

`TestRun.WorkflowVersionId`, `ActionRun.ActionVersionId`, `ActionResults.json` and `WorkflowManifest.json` now identify the same exact versions. Existing workflows without `actionVersion` retain current-version compatibility. Version-pinned workflows are fail-fast and support one contiguous normal Robot block plus one independent cleanup Robot block.

## Project execution

Project workflows are run only from their project folder, for example:

```text
Project-Setup\<Project Name>\Project-Workflow\Sessions\NNNNNN-Workflow-Name\Run.bat
```

The Dynomax root does not call or select a project automatically.

## Database boundary

The configured SQL Server database stores Dynomax configuration, immutable action/workflow versions, framework validation, project test runs, logs and artifacts. A target application's database is not used unless a future project explicitly defines an approved database-testing action.

## Workflow packages

Future workflow ZIP files should contain only a new incrementally named session folder for:

```text
Project-Setup\<Project>\Project-Workflow\Sessions\NNNNNN-Meaningful-Name
```

The session BAT calls the installed Dynomax Core. It must not contain another framework copy.

## Patches

All patch installers, PowerShell patch scripts, notes and payloads belong under:

```text
C:\Dynomax\Patches\<Version>
```

Root-level patch files are not used from version 1.0.3 onward.
