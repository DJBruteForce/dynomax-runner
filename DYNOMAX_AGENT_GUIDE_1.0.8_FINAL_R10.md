# Dynomax Agent Guide

**Framework:** Dynomax  
**Authoritative guide version:** 1.0.8  
**Guide revision:** 1.0.8-r10 - versioned installer state and post-PASS completion recovery  
**Minimum supported Dynomax version:** 1.0.8  
**Framework status:** Dynomax Core V1 accepted and complete  
**Default root:** `C:\Dynomax`  
**Primary technologies:** BAT, PowerShell, JSON, SQL Server, Robot Framework Browser and Playwright

## 1. Mission

Dynomax is a project-independent Windows testing framework. Its core must never contain ATX-specific or other target-specific behaviour. Each target is introduced only through a project under `C:\Dynomax\Project-Setup`.

Dynomax uses:

```text
Windows folders and scripts  -> portable shell and executable definitions
Dynomax SQL database         -> authoritative catalogue, versions, runs and evidence
Robot/Playwright             -> browser execution
PowerShell                    -> setup, orchestration, import, reporting and packaging
```

No compiled application is required.

## 2. Non-negotiable boundaries

1. Keep `Core`, `Config-And-Setup`, SQL schema and generic templates project-neutral.
2. Put all target URLs, credentials references, selectors, routes, permissions and test data under the applicable project.
3. The Dynomax database stores framework data only. It is not a target application's database.
4. Browser tests must use browser-observable evidence unless the project contract explicitly authorises another engine and evidence source.
5. Never embed passwords, tokens, connection strings or customer data in packages, SQL result text, screenshots or logs.
6. Use environment variables or another configured secret reference.
7. Reuse existing certified actions. Do not rewrite login, navigation, cleanup or result readers for every workflow.
8. One action must prove one independently meaningful observable outcome.
9. One workflow composes actions. It must not duplicate action implementations.
10. Any object created by a test must register exact cleanup immediately.
11. Browser, child processes and console execution must close automatically at the end of a successful run.
12. A failed run must keep its controlling console open, display the exit code and full error, and preserve a transcript.
13. Result ZIPs must be validated, copied to the Windows clipboard as a file, and stored under `C:\Dynomax\Exports`.
14. Do not open Explorer or leave unnecessary console windows, browser tabs, contexts or browser processes running.
15. Do not change Dynomax Core for project-specific selectors, routes, reports or workflows.
16. Never guess Dynomax Core script, module or function names.
17. Inspect the installed Core or supplied authoritative Core source before creating a project installer.
18. Use the documented canonical project import and workflow execution interface for the installed framework version.
19. Validate the exact command path, command name and parameter contract before copying project files.
20. A missing, renamed or incorrectly assumed Core entry point is `TEST_INVALID`.
21. Do not modify Dynomax Core merely to support a package that used an invented integration interface.
22. Compatibility discovery, when genuinely required, must be read-only, deterministic and report the exact selected command.
23. Static validation must distinguish finding a plausible command from proving that its parameter contract supports the supplied project definitions.
24. New-project onboarding installers must be safely repeatable.
25. An existing project destination must be validated through its `projectKey` before any change.
26. A destination owned by another project must never be changed.
27. An existing destination owned by the same project may be resumed or updated safely.
28. Package-managed files and unrelated project-local files must be distinguished.
29. Unrelated project-local files must be preserved.
30. Recursive deletion of an existing same-project folder is prohibited unless the user explicitly approves that exact deletion.
31. Treat `databaseConfig.sql` as an opaque Dynomax Core configuration object.
32. Never reconstruct Dynomax SQL configuration from guessed property names.
33. Source-contract validation and runtime function availability are separate gates.
34. Dot-source exact Core dependency scripts in the current installer scope before calling their functions.
35. A source-confirmed function that was not loaded before invocation is `TEST_INVALID`.
36. Reusable project actions must follow the accepted Robot, context and PowerShell invocation contracts documented below.
37. Stable `actionId` is the authoritative identity of a reusable action; folder names are not action identity.
38. Package-source uniqueness and installed-library uniqueness are separate certification gates.
39. Before SQL import or workflow execution, recursively scan the installed `Project-Library` and group definitions by `actionId`.
40. Every workflow-referenced action must resolve to exactly one installed project-library definition.
41. Stale same-project duplicate action folders must be backed up intact before being retired from `Project-Library`.
42. Never silently delete a duplicate action folder.
43. Never alter a duplicate definition whose `projectKey` differs from the destination project.
44. After reconciliation, rescan the installed library and block execution while any referenced `actionId` remains ambiguous.
45. A compatible previously allocated workflow session must be reused during retry instead of consuming another SQL-backed number.
46. Treat every PowerShell function's pipeline output as potentially zero, one or many objects.
47. Normalize collection output at the caller with `@(...)` before using `.Count`, indexing, concatenation, collection-specific loops or array-shaped JSON/state persistence.
48. A function containing `return @($items)` does not by itself guarantee caller-side array shape.
49. Collection-returning helpers must be certified with zero, one and multiple results.
50. StrictMode collection logic must not depend on scalar objects exposing a compatibility `Count` property.
51. Every external Dynomax Core command used by a package must map to its exact defining Core file.
52. A general Core contract or AST source check does not prove that every required command is loaded at runtime.
53. Dot-source the complete direct dependency set in the same PowerShell scope that invokes the commands.
54. Run exact `Get-Command -CommandType Function` checks for every external Core function after loading.
55. Never assume that `Dynomax.Common.ps1` defines process, database, catalogue, results or workflow functions.
56. `Resolve-DynomaxCommand` is defined by `Core\Execution\Dynomax.Process.ps1`, not `Core\Common\Dynomax.Common.ps1`.
57. A source-confirmed Core command invoked without loading its defining script is `TEST_INVALID`.
58. Static certification must prove command dependency closure for every package installer, helper and workflow wrapper.
59. Normal Robot actions and cleanup Robot actions may execute in separate Robot blocks with separate browser lifecycles.
60. Cleanup actions must not assume that authentication, cookies, selected workspace, current page or transient UI state survived the normal Robot block.
61. Every cleanup Robot block must establish its own complete prerequisite chain.
62. Authenticated tenant-scoped cleanup must reuse certified authentication, overlay-settling and workspace-selection actions before destructive cleanup.
63. Workflow context may carry non-secret exact object identifiers between Robot blocks, but it does not carry browser or session state.
64. Cleanup dependency closure must be certified separately from normal action dependency closure.
65. A structurally complete non-PASS result ZIP is authoritative evidence and must be validated through the same manifest/hash contract as a PASS ZIP.
66. `Definitions` and `TestEvidence` are mandatory in every structurally complete result ZIP; `ProjectFindings` is conditional on findings actually being generated.
67. A wrapper must preserve, report and copy a valid non-PASS result ZIP to the clipboard before returning the original non-zero workflow exit code.
68. A wrapper must not reject a valid non-PASS ZIP merely because optional `ProjectFindings` is absent.
69. Installer state schemas must be explicit, complete and versioned.
70. Normalize loaded legacy installer state into the complete current schema before mutation.
71. Do not add undeclared properties directly to JSON-derived `PSCustomObject` instances under StrictMode.
72. Completion, failure and recovery fields must exist from initial `INCOMPLETE.json` creation.
73. A validated live PASS must not be rerun merely because package-state finalization failed.
74. Completion recovery must validate the matching prior PASS ZIP, write `COMPLETE.json` durably and only then remove or archive `INCOMPLETE.json`.
75. Post-PASS recovery must reuse the recorded workflow session and must not consume another SQL-backed session number.

## 3. Core layout

```text
C:\Dynomax
|-- Config-And-Setup
|-- Core
|-- Exports
|-- Logs
|-- Patches
|-- Project-Setup
|-- Temp\Runs
|-- dynomax.json
|-- VERSION.txt
`-- DYNOMAX_AGENT_GUIDE.md
```

Core framework patches belong only under:

```text
C:\Dynomax\Patches\<framework-version>
```

Do not leave patch PS1, notes or payload files in the Dynomax root.

Project packages belong inside their project, normally under:

```text
C:\Dynomax\Project-Setup\<Project>\Project-Workflow\Packages
```

Executable workflows belong under:

```text
C:\Dynomax\Project-Setup\<Project>\Project-Workflow\Sessions
```

## 4. Project layout

Every project must use this shape:

```text
Project-Setup\<Project-Folder>
|-- README.md
|-- Project-And-Config
|   |-- Run.bat
|   |-- Configure-Project.ps1
|   `-- project.json
|-- Project-Library
|   |-- 0001-Action-Name
|   |   |-- Run.bat
|   |   |-- Execute-Action.ps1
|   |   |-- action.json
|   |   `-- action.resource OR action.ps1
|   `-- ...
`-- Project-Workflow
    |-- Packages
    `-- Sessions
        `-- 000001-Workflow-Name
            |-- Run.bat
            |-- Execute-Workflow.ps1
            |-- workflow.json
            `-- Payload
```

`project.json` owns environment configuration. Example fields:

```json
{
  "projectKey": "abc",
  "displayName": "ABC",
  "projectType": "WebApplication",
  "defaultEngine": "RobotBrowser",
  "evidenceBoundary": "WebsiteOnly",
  "browser": "chromium",
  "headless": false,
  "secretReferences": {},
  "environments": [
    {
      "key": "production",
      "baseUrl": "https://www.abc.com",
      "allowedHosts": ["www.abc.com"]
    }
  ]
}
```

Do not hardcode environment values inside generic PS1 files.

## 5. Action rules

An action is a reusable unit such as:

```text
Open the configured website
Open the login page
Submit valid login credentials
Verify authenticated state
Select one workspace
Read one result card
Upload one file
Delete one exact disposable object
```

Avoid broad actions such as `Test all banking` or `Test the entire website`.

Each `action.json` must declare:

```text
actionId
projectKey
displayName
engine
entryPoint
keyword for Robot actions
sessionBehavior
inputs and outputs where applicable
timeoutSeconds
evidencePolicy
```

Action IDs are stable. Changed implementations create new immutable SQL versions.

Use these browser-session values:

```text
RequiresNewBrowser
RequiresExistingBrowser
RequiresNewOrExistingBrowser
DoesNotUseBrowser
```

Robot actions should normally be `.resource` files. Consecutive Robot actions are composed into one generated suite and share one browser session.


### 5.1 Accepted Dynomax 1.0.8 action-definition contract

The live 1.0.8 Core importer requires these top-level `action.json` fields:

```text
actionId
displayName
projectKey
engine
entryPoint
```

The accepted demo establishes these additional project-facing fields as required for reusable actions:

```text
schemaVersion
sessionBehavior
timeoutSeconds
outputs
evidencePolicy
keyword                 required for RobotBrowser actions
inputs                  required when inputs are consumed
```

Robot action example:

```json
{
  "schemaVersion": 1,
  "actionId": "abc.website.open",
  "displayName": "Open configured website",
  "projectKey": "abc",
  "engine": "RobotBrowser",
  "entryPoint": "action.resource",
  "keyword": "ABC Open Configured Website",
  "sessionBehavior": "RequiresNewOrExistingBrowser",
  "timeoutSeconds": 60,
  "outputs": [
    {
      "name": "websiteTitle",
      "type": "String",
      "required": true
    }
  ],
  "evidencePolicy": {
    "onPass": "StructuredOnly",
    "onFailure": "ScreenshotAndDiagnostics"
  }
}
```

PowerShell action rules:

```text
engine must be PowerShell
entryPoint must be the actual Core-executed PS1 file
sessionBehavior must be DoesNotUseBrowser
keyword is omitted
```

Certification must prove:

1. The declared entry point exists.
2. The Robot keyword exists exactly once when required.
3. Engine and implementation agree.
4. Session behaviour agrees with the workflow.
5. Declared required outputs are actually produced.
6. Output names and types match the implementation.
7. Evidence policy is present and compatible.
8. The action is independently meaningful and reusable.
9. `Execute-Action.ps1` is not assumed to be the entry point merely because it exists.

### 5.2 Accepted PowerShell reusable-action execution contract

Dynomax Core 1.0.8 invokes every `engine: PowerShell` action with these exact named parameters:

```text
DynomaxRoot
RunId
StepOrder
ContextPath
OutputPath
```

The declared entry-point script must accept:

```powershell
[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$DynomaxRoot,
    [Parameter(Mandatory)][Guid]$RunId,
    [Parameter(Mandatory)][int]$StepOrder,
    [Parameter(Mandatory)][string]$ContextPath,
    [Parameter(Mandatory)][string]$OutputPath
)
```

The action must:

1. Use strict mode and terminating errors.
2. Dot-source only the exact Core helpers it needs.
3. Read context with `Read-DynomaxJson -Path $ContextPath`.
4. Read workflow values from `$context.values`.
5. Preserve the context envelope when updating it.
6. Write context through `Write-DynomaxJson`.
7. Write valid structured JSON to the exact `$OutputPath` on every normal completion path.
8. Include at least `status` and `message`.
9. Use a supported Dynomax classification.
10. Include all required outputs declared in `action.json`.
11. Write project findings under `<run-directory>\project-export`.
12. Exit non-zero for a process-level failure or failed cleanup as appropriate.

Minimum valid result:

```json
{
  "status": "PASS",
  "message": "Action completed."
}
```

If the process exits successfully without a valid output JSON, Dynomax classifies it as `TEST_INVALID`.



### 5.3 Action identity and installed project-library uniqueness

`actionId` is the authoritative identity of a reusable action.

The following are not action identity:

```text
folder number
folder name
display name
entry-point filename
Robot keyword
SQL version GUID
```

Different folders containing `action.json` files with the same `actionId` are duplicate installed definitions, even when their folder names differ.

Before project import or workflow execution, a repeatable installer must recursively scan:

```text
C:\Dynomax\Project-Setup\<Project>\Project-Library
```

For every `action.json`, record:

```text
actionId
projectKey
absolute folder path
relative folder path
definition SHA-256
implementation SHA-256
whether the path is package-managed
whether the path is the package canonical path
```

Group the scan by `actionId`.

Required states:

```text
UNIQUE
Exactly one installed definition exists.

PACKAGE_DUPLICATE_SAME_PROJECT
The package canonical definition exists and one or more additional definitions
use the same actionId and the same destination projectKey.

OTHER_PROJECT_COLLISION
A duplicate actionId exists whose projectKey does not match the destination project.

AMBIGUOUS
Multiple definitions exist and no safe canonical package path can be proven.
```

Required behaviour:

```text
UNIQUE
Continue.

PACKAGE_DUPLICATE_SAME_PROJECT
Back up every stale duplicate folder intact, record the reconciliation, remove
only the stale duplicate from Project-Library, and rescan.

OTHER_PROJECT_COLLISION
Stop without changing the conflicting definition.

AMBIGUOUS
Stop without changing any ambiguous definition.
```

A package may reconcile a same-project duplicate only when all of the following are true:

1. The package supplies one declared canonical definition for that `actionId`.
2. The canonical destination path is listed in `PACKAGE_MANIFEST.json`.
3. The duplicate definition's `projectKey` matches the destination project.
4. The duplicate path is not the canonical path.
5. The complete duplicate folder is copied to the install-specific backup tree.
6. Every backed-up file hash is verified.
7. The backup manifest records the original path, backup path, hashes, action ID and reason.
8. `INCOMPLETE.json` records the reconciliation before the stale folder is removed.
9. The stale folder is removed only from `Project-Library`, never silently discarded.
10. The installed library is rescanned after all reconciliation.

The installer must print one reconciliation record for every retired definition:

```text
Action ID:      <actionId>
Original path:  <stale installed folder>
Canonical path: <package canonical folder>
Backup path:    <install-specific backup folder>
Reason:         duplicate same-project installed definition
```

The workflow may begin only when every referenced `actionId` resolves to exactly one installed definition.

Static validation of the package ZIP proves only package-source uniqueness. It does not prove installed-library uniqueness.

A workflow failure such as:

```text
Expected one project-library action definition for '<actionId>', found 2.
```

is `TEST_INVALID` when repeatable onboarding failed to reconcile an earlier package-managed same-project duplicate.


## 6. Workflow rules

A workflow references action IDs in order:

```json
{
  "workflowId": "abc.auth.smoke",
  "projectKey": "abc",
  "environment": "production",
  "steps": [
    { "order": 10, "actionId": "abc.website.open" },
    { "order": 20, "actionId": "abc.login.open" },
    { "order": 30, "actionId": "abc.login.submit-valid" },
    { "order": 40, "actionId": "abc.auth.verify" },
    { "order": 90, "actionId": "abc.auth.logout", "cleanup": true }
  ]
}
```

Use order increments of ten so future actions can be inserted safely.

The last action or actions may be newly created acceptance actions. Earlier steps should reuse the project library.


### 6.1 Normal and cleanup Robot block dependency closure

Dynomax may compose normal Robot actions and cleanup Robot actions into separate generated Robot suites or blocks.

Each Robot block owns its own browser lifecycle unless the installed framework contract explicitly proves otherwise.

Therefore, a cleanup block starts with no guaranteed browser state from the normal block.

Cleanup must not assume survival of:

```text
browser process
browser context
page or tab
authentication cookie
authenticated DOM
active tenant
active workspace
current route
expanded menu
modal state
toast state
overlay state
transient JavaScript state
```

Workflow context may carry non-secret exact cleanup data between blocks, including:

```text
created object name
created object GUID
profile ID
workspace ID
tenant-safe lookup key
creation timestamp
source action ID
```

Context does not carry an authenticated browser session.

#### Required authenticated cleanup chain

For authenticated tenant-scoped cleanup in a fresh Robot block, compose certified atomic actions in this order where applicable:

```text
certified login
settle cookie banners, overlays and blocking UI
select or verify the exact workspace/tenant
navigate to the exact protected catalogue or object route
locate the exact context-recorded object
delete the exact object
verify absence
logout
```

A second login during cleanup is expected and correct when cleanup owns a new browser.

Prefer reusable atomic prerequisite actions:

```text
atx.auth.login
atx.ui.settle-overlays
atx.workspace.select
```

Do not duplicate login or workspace logic inside a giant destructive cleanup action merely to hide missing workflow dependencies.

#### Cleanup dependency graph

Every cleanup action must declare or be statically associated with:

```text
required browser state
required authentication state
required tenant/workspace state
required route or navigation state
required context keys
cleanup action ID
post-cleanup verification action or assertion
```

Certification must build two dependency graphs:

```text
NORMAL ACTION GRAPH
Dependencies available in the normal execution block.

CLEANUP ACTION GRAPH
Dependencies independently established in each cleanup block.
```

A dependency satisfied only in the normal graph is not satisfied in a separate cleanup graph.

#### Failure classification

When a cleanup action enters a fresh anonymous browser and fails because login or workspace prerequisites were omitted:

```text
reported workflow result: CLEANUP_FAILED
causal package defect:     TEST_INVALID
```

Do not classify this as failure of the target's delete capability until the cleanup prerequisite chain is certified and the destructive action itself is reached.

## 7. Context between actions

Actions pass declared outputs through the active workflow context. Typical values include:

```text
websiteTitle
websiteUrl
authenticated
workspaceId
profileId
batchId
uploadedFilename
```

SQL is authoritative for persisted run context. The temporary `context.json` is transport for the active run only.

Never place secrets in context.


### 7.1 Authoritative Dynomax context transport

The accepted 1.0.8 context shape is:

```json
{
  "schemaVersion": 1,
  "values": {
    "workflowBlocked": false,
    "projectKey": "abc",
    "environment": "production"
  }
}
```

All project action values belong under `values`.

Robot actions must use:

```text
Set Dynomax Context Value
Get Dynomax Context Value
```

PowerShell actions must use:

```powershell
$context = Read-DynomaxJson -Path $ContextPath
$values = $context.values
```

When updating context, preserve `schemaVersion`, preserve the `values` object and write the complete envelope with `Write-DynomaxJson`.

Prohibited:

```text
flat replacement of context.json
custom incompatible context schema
values outside context.values
direct Robot overwrite of ${DYNOMAX_CONTEXT_PATH}
custom context files that Core does not ingest
```

Replacing Dynomax context transport is `TEST_INVALID`.


## 8. Result classifications

```text
PASS            Certified assertion passed.
FAIL            Target violated a certified functional contract.
TEST_INVALID    Test definition, selector, package or expectation was invalid.
BLOCKED         Required target prerequisite was unavailable.
ERROR           Runner, browser, PowerShell, SQL or dependency failed.
STALE           Relevant source dependency changed.
SKIPPED         Dependency prevented execution.
CLEANUP_FAILED  Required cleanup failed.
```

Do not classify a package, selector, path or runner defect as a target application failure.

A workflow-level result and its causal defect classification may differ.

Example:

```text
workflow result: CLEANUP_FAILED
causal defect:   TEST_INVALID
```

Use `CLEANUP_FAILED` to record that required cleanup did not complete. Use `TEST_INVALID` as the causal classification when the cleanup workflow omitted its own certified authentication, tenant, workspace, route or other prerequisites.

Do not report an application delete defect until the destructive action is reached under a certified cleanup prerequisite chain.


## 9. Evidence and cleanup

Every workflow result ZIP must be self-contained and include all non-secret information for every action that ran, whether the overall result is PASS or non-PASS.

On non-PASS, include:

```text
first failing action
message and classification
output.xml
Robot console log
relevant screenshot
relevant DOM/report evidence
cleanup result
```

Project-generated reports must be written under:

```text
<active-run-directory>\project-export
```

Dynomax adds that folder to the compact result ZIP and stores those files as SQL artifacts.

Every modifying action must record the exact created identifier. Cleanup runs in reverse dependency order and reports actual deletion separately from a no-op.

Cleanup execution must also satisfy section 6.1. Reverse order does not establish authentication, workspace or browser-state prerequisites.

A structurally complete non-PASS result ZIP remains authoritative evidence. Validate it using the same integrity contract as a PASS result.

Required wrapper behaviour for a valid non-PASS ZIP:

```text
validate required files
validate ZIP readability
validate manifest sizes
validate SHA-256 hashes
preserve the ZIP under C:\Dynomax\Exports
copy the ZIP to the clipboard as a file
print the ZIP path
retain INCOMPLETE.json and package recovery state
return the original non-zero workflow exit code
keep the console open according to failure policy
```

Do not transform a valid non-PASS workflow result into a wrapper-level missing-evidence error merely because the workflow did not generate optional project findings.




## 9.1 Mandatory complete result ZIP contract

Every Dynomax workflow ZIP must contain:

```text
RunSummary.json
RunSummary.md
ActionResults.json
ContextSnapshot.json
Assertions.json
Events.json
CleanupSummary.json
ArtifactManifest.json
WorkflowManifest.json
TemporaryWorkspaceCleanup.json
DynomaxExportManifest.json
Definitions/
TestEvidence/
ProjectFindings/              when the project generated findings
```

Requirements:

1. `ActionResults.json` contains one complete result for every executed or skipped action, including cleanup actions, status, classification, message, Stopwatch-based millisecond timing, version, hashes, evidence references and declared output.
2. `ContextSnapshot.json` contains all persisted non-secret context and excludes secret values.
3. `WorkflowManifest.json` identifies the exact project, environment, workflow, ordered actions, cleanup flags and action implementation hashes.
4. `Definitions` contains snapshots of the project definition, workflow definition and every action folder used by the run.
5. `TestEvidence` contains the generated Robot suite, output.xml, log.html, report.html, streamed console log, action logs and screenshots relevant to the run.
6. `ArtifactManifest.json` maps SQL artifact IDs to filenames, SHA-256 values, sizes and compression.
7. `TemporaryWorkspaceCleanup.json` proves whether the temporary run directory was deleted after SQL ingestion and export staging.
8. `DynomaxExportManifest.json` inventories every exported file with a forward-slash ZIP path, size and SHA-256.
9. ZIP member names must use `/`, never Windows backslashes.
10. The ZIP must be built atomically, reopened, every entry read, every declared hash and size checked, and only then copied to the clipboard.
11. The package must not include secret values, credentials, tokens or target application database data unless a project-specific evidence contract explicitly and safely permits it.

12. `Definitions/` and `TestEvidence/` are mandatory for every structurally complete PASS or non-PASS result.
13. `ProjectFindings/` is mandatory only when the workflow generated project findings.
14. PASS and non-PASS ZIPs use the same ZIP readability, manifest, size, SHA-256 and forward-slash path validation.
15. A wrapper must not require `ProjectFindings/` when the workflow did not generate findings.
16. A valid `FAIL`, `TEST_INVALID`, `BLOCKED`, `ERROR` or `CLEANUP_FAILED` ZIP must be preserved and copied to the clipboard before the wrapper returns the original non-zero exit code.
17. ZIP validation success does not change the workflow classification or exit code.
18. Wrapper failure state and incomplete package state remain active after a validated non-PASS result.



## 10. Package types

### A. New project onboarding package

The agent returns one ZIP containing:

```text
Run-Installer.bat
Installer\Install-Project.ps1
Payload\Project-Setup\<Project>\...
PACKAGE_MANIFEST.json
STATIC_VALIDATION.md
```

Running the BAT must:

1. Locate `C:\Dynomax`.
2. Validate the minimum framework version.
3. Inspect and preflight the exact installed Core interface documented in section 17.1.
4. Prove the exact file path, command name and parameter names by parsing the installed PowerShell source.
5. Reject invented function names, broad wildcard discovery and merely plausible commands.
6. Resolve the intended destination under `C:\Dynomax\Project-Setup`.
7. If the destination does not exist, prepare a new project installation.
8. If the destination exists, read `Project-And-Config\project.json` and compare its `projectKey` with the package project key.
9. If the existing destination belongs to another project, stop without changing any file.
10. If the existing destination belongs to the same project, resume or update it through the safe recovery contract in section 17.2.
11. If no readable `project.json` exists, resume only when a matching incomplete-install marker proves ownership by the same package/project; otherwise stop without changing the folder.
12. Write the incomplete-install marker before copying files, importing SQL definitions, allocating a workflow session or executing a workflow.
13. Stage and hash-validate all package-managed files before installation.
14. Back up every changed package-managed destination file before replacement.
15. Install managed files atomically and preserve all unrelated project-local files.
16. Scan package-source action definitions and require unique `actionId` values.
17. Scan the installed `Project-Library` separately and group every installed `action.json` by `actionId`.
18. Reconcile stale package-managed same-project duplicate action folders through section 17.3.
19. Back up duplicate folders intact and record their original, canonical and backup paths before retirement.
20. Never change a duplicate whose `projectKey` differs from the destination project.
21. Rescan the installed library and require every package/workflow `actionId` to resolve exactly once.
22. Import project and action definitions through the project `Configure-Project.ps1` wrapper or the exact `Import-DynomaxProjectFolder` contract.
23. Treat identical existing SQL definitions as an idempotent success.
24. Treat changed project, action and workflow definitions as new immutable SQL versions.
25. Reuse a compatible workflow session already recorded in the incomplete marker.
26. Allocate a new workflow session only when no compatible recorded session exists.
27. Allocate through `Core\Catalogue\New-DynomaxWorkflowSession.ps1` only after project registration and installed-library reconciliation.
28. Record the allocated session path in the incomplete marker immediately.
29. Copy the workflow definition into the allocated or safely resumed session folder.
30. Run a final installed-library uniqueness gate before workflow execution.
31. Execute the installed workflow through `Core\Invoke-DynomaxWorkflow.ps1 -WorkflowDirectory <session-folder>`.
32. Allow the workflow runner to import the workflow, run actions, persist results and own complete result export.
33. Generate and validate a result ZIP.
34. Copy the ZIP to the clipboard.
35. Normalize installer state to the current versioned schema before setting completion fields.
36. Record the validated result ZIP path, ZIP hash, workflow identity, run identity and completion UTC.
37. Write `COMPLETE.json` atomically only after reconciliation, import and the requested live workflow all succeed.
38. Reread and validate `COMPLETE.json` before removing or archiving `INCOMPLETE.json`.
39. If live PASS succeeded but completion bookkeeping failed, preserve the PASS ZIP, session and incomplete state for completion-only recovery.
40. Close browser, child processes and the console automatically after successful state finalization.
41. On failure, retain normalized incomplete state, backups and reconciliation state, print diagnostics, pause and preserve the non-zero exit code.
42. A retry must not require deletion of the entire project folder.
43. A retry must reuse a compatible recorded session instead of consuming another SQL-backed number.
44. A validated live PASS must not be rerun solely because completion-state finalization failed.
45. Do not recursively delete an existing same-project folder unless explicitly approved.
46. Do not open Explorer.

### B. Project workflow/session package

The agent returns one ZIP containing an incremental, sensible session folder plus any new action payload. Running the BAT installs the package under the correct project, imports new versions and executes the workflow.

### C. Core patch

Use only when changing Dynomax itself. Install under:

```text
C:\Dynomax\Patches\<version>
```

A project change must not be disguised as a core patch.

## 11. Incremental naming

Use SQL-backed session numbering where available:

```text
000001-Initial-Reachability
000002-Login-Smoke
000003-Profile-Create-And-Cleanup
```

Never derive the next number only by counting folders.

## 12. Agent workflow for a new project

When the user says a new project is starting:

1. Read this entire guide.
2. Confirm the current Dynomax version and installation path from supplied evidence.
3. Inspect the actual installed Core source or a supplied authoritative export of that exact version.
4. Map the exact project import, action import, workflow import, session allocation, workflow execution and result-export contracts.
5. Validate exact script paths, function names and parameter names by PowerShell AST inspection before package generation.
6. Never create a guessed list of possible Core function names.
7. Ask only for genuinely missing target information that cannot be discovered safely.
8. Obtain or inspect the newest project source when selectors and handlers depend on source.
9. Create `project.json` with no secrets.
10. Create the smallest useful first actions.
11. Create one initial workflow definition.
12. Produce a self-installing and safely repeatable project ZIP.
13. Include a package manifest that distinguishes managed files from unrelated project-local files.
14. Define the exact incomplete marker, completion marker, backup root and managed-file state paths.
15. Statically validate JSON, BAT encoding, Windows PowerShell 5.1 parsing, exact Core interface contracts, destination ownership logic, recovery behaviour, Robot dry-run, paths, package layout and secret absence.
16. Report source-confirmed interface validation separately from live execution.
17. During installation, validate the destination's `projectKey` before any change.
18. Stop without change when the folder belongs to another project.
19. Resume safely when the existing folder belongs to the same project.
20. Preserve extra project-local files.
21. Back up changed managed files.
22. Write the incomplete marker before the first filesystem or SQL mutation.
23. Register the project before consuming a SQL-backed session number.
24. If a prior matching incomplete marker already contains a valid allocated session path, resume that session rather than consuming another number.
25. Otherwise allocate the session through the exact 1.0.8 session script.
26. Record the allocated path immediately in the incomplete marker.
27. Install the workflow into the allocated session folder and execute it through the canonical workflow runner.
28. Write the completion marker only after SQL import and live workflow success.
29. Retain the incomplete marker and backups after failure.
30. Do not require manual deletion of the whole project folder before retry.
31. After the user returns a result ZIP, inspect the full result before creating a correction.
32. Update reusable actions or project contracts before issuing another workflow when the failure exposed a framework/test defect.
33. Classify an invented Core entry point or unsafe same-project destination conflict as `TEST_INVALID`, not a Core or target failure.

## 13. Minimum information an agent needs

For a public website reachability project:

```text
project display name
project key
base URL
allowed host names
environment name
headless or visible browser preference
```

For authenticated testing, also obtain only secret references, not secret values:

```text
username environment-variable name
password environment-variable name
required role or account type
```

For source-derived tests, obtain the newest code/source package and any project-specific source-of-truth file.

## 14. Static package certification

Before delivering a ZIP, verify:

```text
ZIP opens and all members are non-zero where required
BAT, CMD and PS1 files are ASCII-only and use CRLF
BAT files contain no BOM
Executable files contain no smart quotes, em dash, en dash or decorative Unicode
Windows PowerShell 5.1 parses every delivered PS1 file
PowerShell AST variable-use certification passes every delivered PS1 file
ordinary assignment, declaration, mutation or collection use of automatic variable Matches is absent
intentional read-only use of $Matches is explicitly justified and traceable to regex capture use
parser success is not treated as proof against automatic-variable type collisions
PowerShell scripts use strict mode and terminating error handling
JSON files parse
projectKey/actionId/workflowId values agree
all action IDs resolve exactly once
all entry-point files exist
Robot resource paths are converted to forward slashes by Dynomax
no secrets are embedded
no stale package names remain
installer copies only declared destinations
workflow BAT has no pause on success
workflow BAT pauses on failure and preserves the exit code
failure transcript location is printed
browser teardown exists
result ZIP clipboard copy is enabled
database configuration is resolved only from dynomax.json.paths.databaseConfig
database JSON is loaded with Resolve-DynomaxPath and Read-DynomaxJson
databaseConfig.sql is passed unchanged to Core functions
SQL validation uses Open-DynomaxConnection -SqlConfig $databaseConfig.sql
no guessed SQL properties or reconstructed connection string exist
no recursive database-config JSON discovery exists
exact Core scripts are dot-sourced in canonical dependency order
runtime Get-Command checks prove required functions are loaded before invocation
source AST confirmation is not confused with runtime command availability
PowerShell CommandAst inventory lists every external Dynomax command used by the package
every external Dynomax command maps to one exact installed defining file
the defining file's exact function and required parameter contract are AST-validated
the complete defining-file dependency set is dot-sourced in deterministic order
runtime Get-Command checks cover every mapped external Dynomax function
runtime checks execute in the same scope that later invokes each function
Core contract objects expose every defining file needed by their callers
no helper loads only Common while calling a Process, Database, Catalogue, Results or Workflow function
Resolve-DynomaxCommand maps to Core\Execution\Dynomax.Process.ps1 with mandatory Candidates
installed project helper dependencies used by workflow wrappers are preflighted before mutation
generic 'Core contract passed' output is not accepted as command dependency closure
shared-session Robot actions do not create a browser/context/page merely to begin each action
Robot actions use Dynomax context keywords rather than replacing context.json
PowerShell actions accept DynomaxRoot, RunId, StepOrder, ContextPath and OutputPath
every PowerShell action normal path writes structured JSON to OutputPath
PowerShell actions read values from context.values
project findings are written under project-export
action JSON engine, entry point, keyword, session behavior, outputs and evidence policy match implementation
package-source action IDs are unique
workflow action IDs resolve exactly once in package source
installed project-library action IDs are checked separately from package source IDs
installed action scan records actionId, projectKey, path and hashes
reconciliation runs after managed-file installation but before SQL import
the canonical definition path exists exactly once after reconciliation
duplicate same-project definitions are backed up intact before retirement
backup manifest records retired actionId, original path, canonical path and backup path
duplicate definitions with another projectKey are never changed
the installed library is rescanned after reconciliation
every workflow-referenced actionId resolves exactly once after reconciliation
workflow execution is blocked while any referenced actionId is ambiguous
a compatible recorded session is reused during retry
every helper result used with .Count is provably normalized as an array at the call site
every helper result used for indexing or array concatenation is wrapped with @(...), unless a structurally guaranteed array type is proven
function-internal `return @($items)` is not treated as caller-side array certification
collection-returning helpers are tested with zero results
collection-returning helpers are tested with one result
collection-returning helpers are tested with multiple results
StrictMode collection code does not depend on scalar Count compatibility
installer state and JSON output preserve required array shape for zero, one and many records
descriptive plural variable names are used only after caller-side normalization
installed Core source was inspected or an authoritative exact-version Core export was supplied
exact project import script/function path was proven
exact action import function and parameters were proven
exact workflow import function and parameters were proven
exact session allocator path and parameters were proven
exact workflow runner path and parameters were proven
export ownership by the workflow runner was proven
a plausible command was not treated as a certified command
no wildcard or guessed function-name list is used
preflight occurs before project files are copied
destination ownership is resolved from project.json projectKey
another project's destination is never modified
same-project destination resume/update is supported
a missing project.json is accepted only with a matching incomplete marker
PACKAGE_MANIFEST.json identifies every package-managed file and expected hash
unrelated project-local files are preserved
changed managed files are backed up before replacement
managed files are staged and hash-validated before installation
managed-file replacement is atomic per file
incomplete marker is written before copy, SQL import, session allocation or execution
failure leaves the incomplete marker and backups intact
completion marker is written only after import and live workflow PASS
retry reuses a recorded allocated session when safe
recursive deletion of a same-project folder is absent
existing immutable SQL versions are handled idempotently or reported clearly
normal Robot block and cleanup Robot block boundaries are identified
cleanup dependency graph is certified separately from the normal dependency graph
every cleanup action has all prerequisites available inside its cleanup block
authenticated cleanup begins with a certified authentication action
blocking overlays are settled inside the cleanup block where applicable
tenant-scoped cleanup re-establishes the exact workspace or tenant
protected cleanup navigation occurs only after authentication and workspace selection
context-carried cleanup names and GUIDs contain no secrets
cleanup actions do not assume normal-block cookies, page, route or transient UI state
a fresh-browser cleanup path is represented in the generated Robot suite
PASS and non-PASS ZIPs use the same manifest/hash validator
Definitions and TestEvidence are required for every structurally complete ZIP
ProjectFindings is required only when findings were generated
non-PASS ZIP validation does not require optional ProjectFindings
valid non-PASS ZIPs are copied to the clipboard before wrapper failure return
the original non-zero workflow exit code is preserved after ZIP validation
incomplete package state remains after a validated non-PASS workflow
installer state schema has an explicit schemaVersion
initial INCOMPLETE.json includes completion, failure and recovery fields with null/default values
loaded JSON state is normalized into a complete current-schema object before mutation
legacy migration preserves project key, workflow ID, session path, started UTC, reconciliations and prior errors
no direct assignment adds undeclared properties to a JSON-derived PSCustomObject
completion, failure and recovery state tests pass under StrictMode
post-PASS bookkeeping failure does not trigger workflow rerun
completion recovery validates exactly one prior PASS ZIP by timestamp, project key, workflow ID, status, entries, sizes and hashes
completion recovery reuses the recorded SQL-backed session
COMPLETE.json is atomically written and reread before INCOMPLETE.json removal
resultZip, resultZipSha256, completedAtUtc and failedAtUtc exist in the initial current schema
```

## 15. Standard starting prompt for a new chat

```text
Read the attached DYNOMAX_AGENT_GUIDE.md completely before responding.

We are starting a new Dynomax project for https://www.abc.com.
Create the initial project-onboarding package using the established Dynomax folder, SQL, action-library and workflow conventions. The package must be a ZIP I can extract anywhere and run through one BAT file. Its installer must place files under C:\Dynomax\Project-Setup, import the project/actions/workflow into Dynomax SQL, execute the requested initial workflow, generate a compact findings ZIP, copy that ZIP to the Windows clipboard, close the browser and console, and avoid opening Explorer.

First give a read-only confirmation of the project-neutral design and identify any concrete target details still required. Do not change Dynomax Core unless the requested project cannot be supported by the current documented framework.
```

## 16. Current framework acceptance rule

The generic framework self-test proves prerequisites, SQL, binary artifacts and local Chromium. A composed demo workflow must additionally prove project import, multiple reusable actions, shared browser context, PowerShell reporting, per-action SQL results, project findings export, result ZIP creation, clipboard handoff and automatic shutdown.



## 17. Accepted Dynomax 1.0.8 baseline

Dynomax Core V1 is complete. Normal work is now project onboarding, reusable action creation, workflow composition, execution and result analysis.

The project-neutral framework self-test proved:

```text
Windows and PowerShell prerequisites
Python, Node, npm and Robot imports
Robot Framework Browser import
SQL connection to localhost\SQLEXPRESS / Dynomax
schema validation
explicit System.Byte[] to varbinary(max) persistence
local Chromium execution
no project or external website dependency
```

The canonical framework self-test is:

```text
C:\Dynomax\Run-Dynomax-Self-Test.bat
```

The old `Run-Initial-Validation.bat` name was only a compatibility wrapper and may be absent. A root-level framework validation must never invoke ATX or any other project.

The accepted project-pipeline closeout proved:

```text
project import
six reusable actions
one shared Chromium session
context transfer between actions
PowerShell reporting action
per-action SQL persistence
screenshots and Robot evidence
project findings
cleanup execution and verification
complete result ZIP
forward-slash ZIP paths
clipboard handoff
temporary workspace deletion
automatic shutdown on success
console retention on failure
```

Accepted closeout:

```text
Dynomax version: 1.0.8
Run ID: bc849235-a286-4922-ba9c-6d34c3a4774a
Overall status: PASS
Actions: 6 passed
```

Do not rebuild or re-prove Dynomax Core for each project.


### 17.1 Source-confirmed Dynomax 1.0.8 project-facing integration contract

This contract is version-specific to Dynomax 1.0.8. It was confirmed again from the user's actual installed Dynomax snapshot supplied on 31 July 2026. The live snapshot reports `VERSION.txt` as `1.0.8`, contains the exact Core paths below and contains an existing `ATX-Solutions` project whose `project.json` owns `projectKey` `atx-solutions`. A package must still compare these paths and parameter names with the actual installed files before copying project content.

Dynomax 1.0.8 does not expose a formal PowerShell module manifest with exported public commands. It uses standalone scripts plus functions loaded by dot-sourcing Core files. The following exact interfaces are the supported integration contract.

#### A. Canonical installed-workflow orchestration

**Exact path**

```text
C:\Dynomax\Core\Invoke-DynomaxWorkflow.ps1
```

**Exact command**

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File `
    C:\Dynomax\Core\Invoke-DynomaxWorkflow.ps1 `
    -WorkflowDirectory <installed-session-folder>
```

**Parameters**

```text
-WorkflowDirectory   Mandatory string. Folder containing workflow.json.
-DynomaxConfigPath   Optional string. Defaults to C:\Dynomax\dynomax.json after root discovery.
```

**Accepted input**

A filesystem directory containing `workflow.json`. The workflow's `projectKey` must resolve to exactly one project folder under `Project-Setup`.

**Behaviour**

Before creating the run, the script:

1. Locates the Dynomax root.
2. Loads Common, Process, Database, Catalogue, Results and Workflow Core scripts.
3. Reads Dynomax and SQL configuration.
4. Resolves the project folder by `projectKey`.
5. Calls `Import-DynomaxProjectFolder`.
6. Imports any payload actions under the workflow session.
7. Calls `Import-DynomaxWorkflowDefinition`.
8. Creates the run, executes actions, runs cleanup, persists SQL evidence and builds the complete result ZIP.

**Return and failure**

The script is process-oriented and calls `exit`:

```text
exit 0   overall PASS
exit 1   any non-PASS overall status
```

It writes the Run ID, overall status and result ZIP path to the console. A caller that needs to continue after execution must launch it as a child PowerShell process and capture the native exit code immediately. Do not dot-source it into a long-lived installer process.

Failures after run creation normally enter final evidence/export handling. Failures before run creation, including invalid import interfaces or invalid definitions, may produce no result ZIP; the outer installer transcript and failure pause are therefore mandatory.

**Stability**

This is the canonical project-facing workflow execution interface for Dynomax 1.0.8. Use it instead of separately invoking internal execution or export functions.

#### B. Canonical project-folder import

**Exact source path**

```text
C:\Dynomax\Core\Catalogue\Dynomax.Catalogue.ps1
```

**Exact function**

```powershell
Import-DynomaxProjectFolder
```

**Mandatory parameters**

```text
-ProjectFolder   String path to the project root.
-SqlConfig       PowerShell object containing the Dynomax SQL configuration.
```

**Accepted input**

`ProjectFolder` must contain:

```text
Project-And-Config\project.json
Project-Library\...\action.json
Project-Workflow\Sessions\...\workflow.json
```

`SqlConfig` is the `.sql` object read from the configured Dynomax database JSON.

**Behaviour**

It imports, in this order:

1. `project.json`
2. every `action.json` recursively, sorted by full path
3. every `workflow.json` recursively, sorted by full path

**Return and failure**

It has no structured aggregate return. Lower-level import functions return version GUIDs. Validation or SQL errors throw terminating exceptions through the caller.

**Stability**

This is the de facto bulk project-import function for 1.0.8. It is not exported through a formal module manifest, so packages must validate its exact source and parameters for the installed version.

**Live source-confirmed destination resolver**

`C:\Dynomax\Core\Common\Dynomax.Common.ps1` defines:

```powershell
Get-DynomaxProjectFolder
    -DynomaxRoot <string>
    -ProjectKey <string>
```

It scans project folders, reads `Project-And-Config\project.json` and requires exactly one folder whose `projectKey` matches. This confirms that project ownership is key-based, not based merely on whether a folder name exists.

**Live source-confirmed SQL idempotency**

The installed import functions already support safe repeat imports:

```text
Project definition:
same definition hash -> returns existing ProjectVersionId
changed definition hash -> creates the next project version

Action definition:
same definition hash plus implementation hash -> returns existing ActionVersionId
changed definition or implementation -> creates the next immutable action version

Workflow definition:
same definition hash -> returns existing WorkflowVersionId
changed definition hash -> creates the next workflow version
```

Therefore, an installer retry must not delete the project folder or invent destructive SQL cleanup merely because the same project already exists.

#### C. Preferred project-local import wrapper

Every generated project should contain:

```text
C:\Dynomax\Project-Setup\<Project>\Project-And-Config\Configure-Project.ps1
```

The accepted wrapper:

1. Locates `C:\Dynomax`.
2. Dot-sources:
   - `Core\Common\Dynomax.Common.ps1`
   - `Core\Database\Dynomax.Database.ps1`
   - `Core\Catalogue\Dynomax.Catalogue.ps1`
3. Reads `dynomax.json`.
4. Reads the configured database JSON.
5. Calls:

```powershell
Import-DynomaxProjectFolder -ProjectFolder <project-folder> -SqlConfig $databaseConfig.sql
```

It takes no parameters in the accepted template and throws on failure.

Use this wrapper for an import/update-only operation after project files have been installed. When immediately executing a workflow, the canonical workflow runner already performs project-folder import, so a separate full import is optional unless needed before session allocation.

#### D. Lower-level immutable definition imports

All are defined in:

```text
C:\Dynomax\Core\Catalogue\Dynomax.Catalogue.ps1
```

##### Project definition

```powershell
Import-DynomaxProjectDefinition `
    -ProjectJsonPath <path-to-project.json> `
    -SqlConfig <sql-config-object>
```

Return:

```text
System.Guid ProjectVersionId
```

It is idempotent by canonical definition hash and creates a new current project version when the definition changes.

##### Action definition

```powershell
Import-DynomaxActionDefinition `
    -ActionJsonPath <path-to-action.json> `
    -SqlConfig <sql-config-object>
```

Return:

```text
System.Guid ActionVersionId
```

It validates the declared action entry point, requires the project to exist and is idempotent by definition hash plus implementation hash.

##### Workflow definition

```powershell
Import-DynomaxWorkflowDefinition `
    -WorkflowJsonPath <path-to-workflow.json> `
    -SqlConfig <sql-config-object>
```

Return:

```text
System.Guid WorkflowVersionId
```

It requires the project to exist, stores ordered steps and is idempotent by workflow definition hash.

These lower-level functions accept file paths, not JSON strings and not arbitrary project objects. They are useful for controlled staged installation, but the preferred bulk operation is `Import-DynomaxProjectFolder`.

#### E. SQL-backed workflow session allocation

**Exact path**

```text
C:\Dynomax\Core\Catalogue\New-DynomaxWorkflowSession.ps1
```

**Exact command and parameters**

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File `
    C:\Dynomax\Core\Catalogue\New-DynomaxWorkflowSession.ps1 `
    -ProjectKey <project-key> `
    -Name <descriptive-session-name>
```

Both parameters are mandatory strings.

**Prerequisites**

The project folder must already exist and the project must already be registered in Dynomax SQL.

**Behaviour**

The script:

1. Resolves exactly one project folder matching `projectKey`.
2. Locks the project's SQL sequence row.
3. consumes and increments `NextSessionNumber`.
4. creates a zero-padded folder such as `000001-Initial-Reachability`.
5. copies the Core workflow template into that folder.
6. prints:

```text
Created workflow session: <absolute-path>
```

**Return and failure**

It does not return a structured object or path. It writes the created path to the host and throws on failure. When run as a child PowerShell process, a failure produces a non-zero process exit.

The allocation is not a read-only "peek". Calling it consumes a session number and creates a folder. Never invoke it during static preflight.

**Stability**

The script path and parameters are the supported 1.0.8 allocator contract. Its console-only return is a compatibility weakness. Packages may capture the exact `Created workflow session:` output deterministically, but must reject zero or multiple matching lines.

Do not use the root `New-Workflow-Session.bat` as an unattended package API because the 1.0.8 wrapper is interactive and contains an unconditional `pause`.

#### F. Result export and validation

Complete export is owned by:

```text
C:\Dynomax\Core\Invoke-DynomaxWorkflow.ps1
```

Packages should not separately call exporter functions.

Internal functions are defined in:

```text
C:\Dynomax\Core\Results\Dynomax.Results.ps1
```

The exact internal functions are:

```powershell
Export-DynomaxRunSummary
    -SqlConfig <object>
    -RunId <Guid>
    -OutputDirectory <string>
```

Returns an object containing `Summary`, `Actions`, `Context`, `Artifacts` and `Cleanup`.

```powershell
Write-DynomaxExportManifest
    -ExportDirectory <string>
    -RunId <Guid>
    -FrameworkVersion <string>
    -TemporaryCleanup <object>
```

Returns the export-manifest object.

```powershell
New-DynomaxStandardZip
    -SourceDirectory <string>
    -DestinationPath <string>
```

Returns the destination path after creating a non-empty ZIP, reopening it, reading every member and rejecting backslash entry paths.

```powershell
Set-DynomaxClipboardFile
    -Path <string>
```

Copies an existing file to the Windows clipboard and throws when the file does not exist.

These are internal workflow-export helpers, not the preferred project-package API.

#### G. Opaque Dynomax SQL configuration object

The live 1.0.8 source confirms this exact configuration flow:

```powershell
$config = Read-DynomaxJson -Path (Join-Path $DynomaxRoot 'dynomax.json')

$databaseConfigPath = Resolve-DynomaxPath `
    -Root $DynomaxRoot `
    -ConfiguredPath $config.paths.databaseConfig

$databaseConfig = Read-DynomaxJson -Path $databaseConfigPath
$sqlConfig = $databaseConfig.sql
```

Treat `$databaseConfig.sql` as an opaque Dynomax Core configuration object.

Permanent rules:

```text
resolve only dynomax.json.paths.databaseConfig
load it through Resolve-DynomaxPath and Read-DynomaxJson
take the top-level .sql object
pass that exact object unchanged to Core functions
validate through Open-DynomaxConnection -SqlConfig $databaseConfig.sql
```

Do not infer or require:

```text
connectionString
server
database
username
password
```

Do not construct a replacement SQL object or connection string. Do not recursively scan unrelated JSON files or properties for a plausible database configuration.

Core owns the internal interpretation of the object. Its current internal fields are not a project-package reconstruction contract.

A package that reconstructs SQL configuration from guessed property names is `TEST_INVALID`.

#### H. Canonical Core bootstrap and dependency-loading contract

Dynomax 1.0.8 is not a PowerShell module with automatic command loading. Its functions become available only after the exact scripts that define them have been dot-sourced into the scope that calls them.

Source confirmation and runtime availability are separate gates:

```text
AST/source gate:
proves that a function exists in the expected installed file with expected parameters

runtime load gate:
dot-sources the exact dependency files and proves Get-Command can resolve the function
```

For project import and SQL validation, use this exact script-scope bootstrap:

```powershell
$commonPath = Join-Path $DynomaxRoot 'Core\Common\Dynomax.Common.ps1'
$databasePath = Join-Path $DynomaxRoot 'Core\Database\Dynomax.Database.ps1'
$cataloguePath = Join-Path $DynomaxRoot 'Core\Catalogue\Dynomax.Catalogue.ps1'

. $commonPath
. $databasePath
. $cataloguePath

$requiredFunctions = @(
    'Read-DynomaxJson',
    'Resolve-DynomaxPath',
    'Open-DynomaxConnection',
    'Import-DynomaxProjectFolder'
)

foreach ($functionName in $requiredFunctions) {
    $command = Get-Command -Name $functionName -CommandType Function -ErrorAction Stop
    if ($command.Name -ne $functionName) {
        throw "Required Dynomax function was not loaded: $functionName"
    }
}
```

Canonical order:

```text
1. Core\Common\Dynomax.Common.ps1
2. Core\Database\Dynomax.Database.ps1
3. Core\Catalogue\Dynomax.Catalogue.ps1
```

`Open-DynomaxConnection` is defined in `Core\Database\Dynomax.Database.ps1`. Confirming that name in source does not make the command callable.

Load the files in the installer script scope before defining or calling helpers that rely on them. Dot-sourcing in a temporary child process, nested disposable scope or separate validation process does not guarantee availability in the scope that later calls the function.

Do not use:

```text
Import-Module against these PS1 files
wildcard dot-sourcing of every Core script
function-name guessing
AST confirmation as a substitute for runtime Get-Command
a helper that calls Open-DynomaxConnection before Database.ps1 is loaded
```

Correct SQL validation after bootstrap:

```powershell
$connection = Open-DynomaxConnection -SqlConfig $databaseConfig.sql
try {
    Write-Host 'Dynomax SQL connection validated.'
}
finally {
    $connection.Dispose()
}
```

For workflow execution, do not reproduce the full Core load graph in the installer. Launch the canonical child script:

```text
Core\Invoke-DynomaxWorkflow.ps1
```

It loads, in order:

```text
Common
Process
Database
Catalogue
Results
Workflow
```

A package that proves a function exists but invokes it before loading its defining script is `TEST_INVALID`.

#### H.1 Exact Core command-to-file dependency map

Dynomax 1.0.8 uses standalone PowerShell scripts. Functions are not automatically loaded merely because their source files exist or their contracts passed AST validation.

Project packages must map every external Core command they call.

Confirmed mappings include:

```text
Core\Common\Dynomax.Common.ps1
- Read-DynomaxJson -Path
- Resolve-DynomaxPath -Root -ConfiguredPath
- Get-DynomaxProjectFolder -DynomaxRoot -ProjectKey

Core\Execution\Dynomax.Process.ps1
- Resolve-DynomaxCommand -Candidates
- Invoke-DynomaxProcess

Core\Database\Dynomax.Database.ps1
- Open-DynomaxConnection -SqlConfig

Core\Catalogue\Dynomax.Catalogue.ps1
- Import-DynomaxProjectFolder -ProjectFolder -SqlConfig
- Import-DynomaxProjectDefinition -ProjectJsonPath -SqlConfig
- Import-DynomaxActionDefinition -ActionJsonPath -SqlConfig
- Import-DynomaxWorkflowDefinition -WorkflowJsonPath -SqlConfig

Core\Results\Dynomax.Results.ps1
- internal result-export functions used by the canonical workflow runner

Core\Workflow\Dynomax.Workflow.ps1
- internal workflow-execution functions used by the canonical workflow runner
```

A package should not call internal Results or Workflow functions directly when `Core\Invoke-DynomaxWorkflow.ps1` owns that operation.

#### H.2 Dependency closure for Python and Robot dry-run resolution

A package that resolves the configured Python command for a Robot dry run requires both Common and Process:

```powershell
$commonPath = Join-Path $DynomaxRoot 'Core\Common\Dynomax.Common.ps1'
$processPath = Join-Path $DynomaxRoot 'Core\Execution\Dynomax.Process.ps1'

. $commonPath
. $processPath

$requiredFunctions = @(
    'Read-DynomaxJson',
    'Resolve-DynomaxPath',
    'Resolve-DynomaxCommand'
)

foreach ($functionName in $requiredFunctions) {
    Get-Command `
        -Name $functionName `
        -CommandType Function `
        -ErrorAction Stop | Out-Null
}

$dynomaxConfig = Read-DynomaxJson `
    -Path (Join-Path $DynomaxRoot 'dynomax.json')

$prerequisitePath = Resolve-DynomaxPath `
    -Root $DynomaxRoot `
    -ConfiguredPath $dynomaxConfig.paths.prerequisiteConfig

$prerequisite = Read-DynomaxJson -Path $prerequisitePath

$pythonCommand = Resolve-DynomaxCommand `
    -Candidates @($prerequisite.pythonCommandCandidates)
```

The Core contract object returned to the caller must include the exact Process path when the caller uses `Resolve-DynomaxCommand`.

For example:

```powershell
[pscustomobject]@{
    CoreCommonFile  = $coreCommon
    CoreProcessFile = $coreProcess
    CoreDatabaseFile = $coreDatabase
}
```

The source contract must also validate:

```powershell
Test-AtxFunctionContract `
    -Path $coreProcess `
    -FunctionName 'Resolve-DynomaxCommand' `
    -RequiredParameters @('Candidates')
```

Do not create a package-local replacement named `Resolve-DynomaxCommand` when the installed Core already provides the exact supported function.

#### H.3 General package command-dependency closure gate

For every delivered PS1 file:

1. Parse the file and inventory `CommandAst` nodes.
2. Identify commands defined locally in that file or package helper files.
3. Identify external Dynomax commands.
4. Map every external command to one exact installed Core file.
5. Validate the function and parameter contract in that file.
6. Prove the defining file is dot-sourced before the first invocation.
7. Prove dot-sourcing occurs in the same scope that invokes the command.
8. Run exact `Get-Command` checks after loading.
9. Reject any unmapped or unloaded external Dynomax command.
10. Repeat the check for installed workflow wrappers and project helper dependencies.

The following are not sufficient:

```text
the file exists
the function name appears somewhere under Core
another process loaded the function
a helper loaded it in a scope that already returned
the generic Core validation reported PASS
Common.ps1 was loaded
the canonical workflow runner would load it later
```

A package helper that calls a Core function must load its own required dependency or call a documented wrapper that does.

#### I. Canonical onboarding sequence for Dynomax 1.0.8

A new project installer must use this exact order:

```text
1. Validate Dynomax version and SQL.
2. Parse the installed Core source and prove the exact 1.0.8 contracts above.
3. Copy Project-And-Config and Project-Library files into the new project folder.
4. Run the project Configure-Project.ps1 wrapper, or source-confirmedly call
   Import-DynomaxProjectFolder, so the project and actions exist in SQL.
5. Invoke New-DynomaxWorkflowSession.ps1 once to allocate the SQL-backed session.
6. Capture exactly one "Created workflow session:" path.
7. Copy workflow.json, Execute-Workflow.ps1, Run.bat and any payload into that
   allocated folder.
8. Launch Core\Invoke-DynomaxWorkflow.ps1 as a child process with
   -WorkflowDirectory set to the installed session folder.
9. Allow the workflow runner to import the workflow and own persistence/export.
10. Capture its exit code immediately.
11. On PASS, verify the complete ZIP and clipboard handoff.
12. On failure, keep the console open and show the transcript/result locations.
```

Do not call `Config-And-Setup\03-Core\Initialize-DynomaxCore.ps1` as a project installer. That script registers framework/machine state and imports every installed project; it is broader than a single project package.

#### J. Command discovery policy

For Dynomax 1.0.8, broad command discovery is not acceptable, even as a normal compatibility mechanism. The exact interfaces are known.

A package must not:

```text
guess Import-DynomaxProject
try several possible function names
scan wildcard command names and select the first match
treat file existence as proof of parameter compatibility
modify Core because an invented function was absent
```

If a future version differs and no updated guide is available, compatibility discovery may occur only when it is:

```text
read-only
deterministic
based on source/AST inspection
restricted to authoritative installed Core paths
validated against exact required parameters
reported with exact selected path and command
performed before project files are copied
```

Finding a plausible command is not certification. The package must prove that the selected command's parameter contract accepts the supplied file paths and SQL configuration form.

#### K. Current framework-gap decision

The failed ATX package does not require a Core correction. Existing 1.0.8 interfaces are sufficient when called exactly.

A separate project-neutral hardening opportunity remains: Dynomax does not yet provide one versioned public project-package wrapper with a structured result for import, session allocation and execution. The smallest future Core enhancement would be a `Core\Public` script or module that:

```text
accepts project folder and workflow source
imports project/actions
allocates and returns a structured session object
installs workflow files
executes the canonical runner
returns run ID, status and ZIP path
publishes a machine-readable parameter contract
```

That enhancement requires explicit approval and a new framework version. It is not justified merely to repair a package that guessed function names.


### 17.2 Safe repeatable project onboarding and recovery contract

This is a project-package contract. Dynomax Core does not need to be changed for an installer to comply.

#### A. Destination ownership states

A project installer must classify the destination before any mutation.

```text
ABSENT
The destination folder does not exist.

SAME_PROJECT
A readable Project-And-Config\project.json exists and projectKey equals the package projectKey.

SAME_PROJECT_INCOMPLETE
project.json may be missing or incomplete, but a valid incomplete-install marker identifies
the same project key and package/install identity.

OTHER_PROJECT
A readable project.json exists and projectKey differs from the package projectKey.

UNCLAIMED_OR_AMBIGUOUS
The folder exists but neither a matching project.json nor a valid matching incomplete marker
proves ownership.
```

Allowed behaviour:

```text
ABSENT                  create safely
SAME_PROJECT            resume or update safely
SAME_PROJECT_INCOMPLETE resume the recorded transaction safely
OTHER_PROJECT           stop without changing anything
UNCLAIMED_OR_AMBIGUOUS  stop without changing anything
```

Folder-name equality is not ownership proof. The `projectKey` is authoritative.

#### B. Package-managed files

`PACKAGE_MANIFEST.json` must identify every file managed by the package, including:

```text
package ID and version
project key
relative source path
relative destination path
expected source SHA-256
file role
replace policy
```

A file is package-managed only when declared in that manifest or in the prior successful managed-file state for the same project/package lineage.

Files not owned by the package must be preserved.

Examples of files that may be unrelated and must not be deleted merely because they are under the project folder:

```text
manually maintained project notes
newer workflow sessions
result catalogues
source-of-truth files
project-specific scripts from another approved package
local support files
```

#### C. Installer state paths and explicit versioned schema

Use this project-local state area:

```text
C:\Dynomax\Project-Setup\<Project>\Project-And-Config\Install-State
```

Required files:

```text
INCOMPLETE.json
COMPLETE.json
ManagedFiles.json
Backups\<install-id>\...
```

Installer state schemas must be explicit and versioned. `INCOMPLETE.json` must be written atomically before the first copy, SQL import, session allocation or live execution.

The current schema must declare every field that may later be mutated, including null/default values. Minimum schema:

```json
{
  "schemaVersion": 2,
  "installId": null,
  "packageId": null,
  "packageVersion": null,
  "projectKey": null,
  "destination": null,
  "workflowId": null,
  "workflowSourceHash": null,
  "managedFileManifestHash": null,
  "backupRoot": null,
  "sessionPath": null,
  "runId": null,
  "startedAtUtc": null,
  "updatedAtUtc": null,
  "completedAtUtc": null,
  "failedAtUtc": null,
  "currentPhase": null,
  "overallStatus": null,
  "resultZip": null,
  "resultZipSha256": null,
  "reconciliations": [],
  "backupRecords": [],
  "priorErrors": [],
  "lastError": null,
  "recovery": {
    "mode": null,
    "sourceStateVersion": null,
    "validatedPassZip": false,
    "recoveredAtUtc": null
  }
}
```

#### C.1 JSON-derived `PSCustomObject` mutation rule

`ConvertFrom-Json` returns `PSCustomObject`. Under StrictMode, assigning a missing property may throw.

Unsafe when the legacy object lacks the property:

```powershell
$state = Get-Content $statePath -Raw | ConvertFrom-Json
$state.completedAtUtc = [DateTime]::UtcNow.ToString('o')
```

Required approach:

```text
read legacy state
inspect its schemaVersion and available properties
construct a complete new current-schema object
preserve existing identity, session, reconciliation and error values
mutate only fields declared by the current schema
write atomically
```

Using `Add-Member` is allowed only inside an explicit versioned migration routine. Constructing a complete new state object is preferred.

#### C.2 State migration preservation contract

Migration must preserve, when present:

```text
project key and destination
package identity
workflow ID and workflow source hash
allocated session path and run ID
started time and current phase
managed-file manifest hash and backup root
reconciliation and backup records
prior errors and last error
```

Completion, failure and recovery fields must exist from initial state creation. Do not add them opportunistically after execution.

On failure, set declared `failedAtUtc`, `lastError` and phase fields and retain `INCOMPLETE.json`, backups and the recorded session.

On success, set declared `runId`, `overallStatus`, `resultZip`, `resultZipSha256` and `completedAtUtc`, write `COMPLETE.json` atomically, reread it, and only then remove or archive `INCOMPLETE.json`.

A static-only installation is not complete when the package includes live execution.

#### D. Backup and atomic replacement

Before replacing a changed managed file:

1. Calculate the existing destination hash.
2. If it already equals the package hash, treat it as idempotently installed.
3. If it differs, copy the existing file to the install-specific backup tree.
4. Verify the backup hash.
5. Write the new file to a staging or sibling temporary path on the same volume.
6. Verify the staged hash.
7. Atomically move/replace the staged file at the destination.
8. Verify the final destination hash.
9. Record the operation in installer state.

Never recursively delete the existing same-project folder as a normal update strategy.

#### D.1 Collection shape in backup, reconciliation and installer-state helpers

PowerShell pipeline output is automatically enumerated. A function that writes collection members to the success pipeline has a caller-visible cardinality of:

```text
zero results     -> $null
one result       -> one scalar object
multiple results -> an array
```

This remains true when the function contains:

```powershell
return @($items)
```

The array expression inside the function is normally enumerated onto the pipeline. It does not prove that the caller receives an array.

Unsafe pattern:

```powershell
$workflowBackup = Backup-ChangedManagedFiles `
    -ExistingRoot $existingRoot `
    -SourceRoot $sourceRoot `
    -BackupRoot $backupRoot

if ($workflowBackup.Count -gt 0) {
    $backupInventory += $workflowBackup
}
```

When the helper returns exactly one `PSCustomObject`, the caller receives that scalar. Under StrictMode, code must not assume that scalar exposes the required collection `Count` contract.

Required caller-side normalization:

```powershell
$backupRecords = @(
    Backup-ChangedManagedFiles `
        -ExistingRoot $existingRoot `
        -SourceRoot $sourceRoot `
        -BackupRoot $backupRoot
)

if ($backupRecords.Count -gt 0) {
    $backupInventory += $backupRecords
}
```

Permanent rules:

1. Treat helper output as zero, one or many.
2. Normalize at the call site with `@(...)` before:
   - `.Count`;
   - numeric indexing;
   - slicing;
   - `+=` into another array;
   - collection-shape comparisons;
   - array-shaped installer-state persistence;
   - array-shaped JSON output.
3. Use descriptive plural variables only after normalization, for example:
   - `$backupRecords`;
   - `$databaseCandidates`;
   - `$retiredDefinitions`;
   - `$sessionOutputRecords`.
4. Do not rely on function-internal `@(...)` or `return @(...)`.
5. Do not rely on scalar compatibility properties under StrictMode.
6. Test every collection helper at all three cardinalities:
   - zero;
   - exactly one;
   - multiple.
7. Verify that installer-state JSON preserves arrays at all cardinalities, including:
   - `[]` for zero;
   - `[ { ... } ]` for one;
   - `[ { ... }, { ... } ]` for many.
8. Do not allow a one-record state to collapse into a JSON object when the schema requires an array.
9. Do not use `Write-Output -NoEnumerate` as an undocumented substitute for caller-side normalization. If a helper intentionally returns one collection object, document that distinct structural contract and certify every caller.
10. A caller using `.Count`, indexing or array concatenation without a proven normalized collection is `TEST_INVALID`.

For backup and reconciliation helpers specifically, normalize before adding records to:

```text
backup inventory
retired-action inventory
managed-file state
incomplete-install state
completion state
export or audit JSON
```

#### D.2 Post-PASS completion-state recovery

A validated live workflow PASS remains authoritative when only package-state finalization failed. Do not rerun the workflow merely because writing `completedAtUtc`, `resultZip`, `COMPLETE.json` or another bookkeeping field failed.

Completion-only recovery requires exactly one prior PASS ZIP matching all of:

```text
ZIP timestamp is at or after the recorded install start time
project key matches
workflow ID matches
session/workflow identity matches
RunSummary overall status is PASS
Definitions and TestEvidence exist
every ZIP entry is readable
manifest sizes and SHA-256 hashes validate
ZIP file SHA-256 is recorded
```

Do not select a candidate only because it has the newest filename. Zero or multiple fully matching candidates block automatic recovery without rerunning the workflow.

Recovery sequence:

```text
1. Load INCOMPLETE.json.
2. Normalize/migrate it to the current state schema.
3. Validate recorded project, workflow and session identity.
4. Locate and fully validate exactly one matching prior PASS ZIP.
5. Set runId, overallStatus, resultZip, resultZipSha256, completedAtUtc and recovery fields.
6. Preserve startedAtUtc, sessionPath, reconciliations, backups and prior errors.
7. Write COMPLETE.json to a sibling temporary file.
8. Flush, hash and atomically replace the final COMPLETE.json.
9. Reread COMPLETE.json and validate its required fields.
10. Only then remove or archive INCOMPLETE.json.
11. Do not allocate another workflow session.
12. Do not execute the workflow again.
```

If recovery fails, retain normalized incomplete state and the validated PASS ZIP and report `TEST_INVALID` state finalization.

#### E. Resume rules

On retry, read `INCOMPLETE.json` first.

The installer may resume only when:

```text
project key matches
package identity or declared compatible package lineage matches
managed-file manifest is compatible
recorded destination matches
recorded session path, when present, is under the same project
workflow source hash matches the workflow being resumed
```

If files were already installed and their hashes match, skip them.

If a session was already allocated and recorded, reuse it when its folder and workflow identity are still valid. Do not allocate a new session merely because the prior run failed after allocation.

Before any workflow rerun, determine whether the state may represent a completed live PASS whose bookkeeping failed. Apply section 17.2 D.2 first.

If the marker is incompatible or corrupt, stop and report the exact conflict. Do not delete the folder, allocate another session or rerun a previously validated PASS.

#### F. SQL retry behaviour

The live 1.0.8 import functions are hash-idempotent. A retry should:

```text
accept an existing identical ProjectVersionId
accept existing identical ActionVersionIds
accept an existing identical WorkflowVersionId
create new immutable versions only when definitions or implementations changed
report SQL validation or uniqueness conflicts clearly
never delete prior immutable versions as a retry shortcut
```

#### G. Failure classification

The following is `TEST_INVALID`:

```text
the package treats every existing same-project folder as an unrecoverable conflict
the package requires manual deletion of the whole project folder before retry
the package deletes unrelated local files
the package overwrites changed managed files without backup
the package allocates repeated sessions because it failed to record the first one
the package writes a completion marker before live execution succeeds
the package mutates undeclared properties on a JSON-derived PSCustomObject
the package does not migrate legacy state before mutation
the package reruns a validated live PASS because completion bookkeeping failed
the package removes INCOMPLETE.json before durable COMPLETE.json verification
the package consumes another session during completion-only recovery
```

A destination owned by another project is a valid safety block, not a test defect.

#### H. Current Core decision

No Core implementation change is required for safe repeatable onboarding.

The installed Core already provides:

```text
project-key-based folder resolution
hash-idempotent project/action/workflow imports
SQL-backed session allocation
canonical workflow execution and result export
```

The project installer must supply transaction state, managed-file ownership, backup, atomic replacement and retry orchestration.

A future project-neutral public installer API could centralise these behaviours, but it requires separate approval and a new Dynomax version.


### 17.3 Installed project-library reconciliation contract

This contract applies after package-managed files have been installed, but before SQL import and workflow execution.

#### A. Separate package-source and installed-library scans

Perform two independent scans:

```text
PACKAGE SOURCE SCAN
Scans action.json files supplied by the current package.

INSTALLED LIBRARY SCAN
Scans every action.json recursively under the destination Project-Library,
including files left by earlier complete, incomplete or superseded packages.
```

Package-source uniqueness does not prove installed-library uniqueness.

The package source must contain exactly one canonical definition for each supplied `actionId`.

Every workflow action must resolve exactly once in package source where applicable and exactly once in the installed library after reconciliation.

#### B. Reconciliation order

Use this order:

```text
1. Validate package-source actionId uniqueness.
2. Install package-managed files atomically.
3. Scan the complete installed Project-Library.
4. Group installed definitions by actionId.
5. Identify workflow-referenced and package-supplied action IDs.
6. Reconcile safe same-project duplicates.
7. Rescan the installed library.
8. Require exactly one installed definition for every referenced action ID.
9. Only then import project/action definitions into SQL.
10. Only then allocate or resume the workflow session.
11. Run the uniqueness gate again immediately before workflow execution.
```

Reconciliation must run after managed-file installation so the declared canonical path exists.

It must run before SQL import so ambiguous filesystem definitions are not imported or selected incorrectly.

#### C. Canonical definition selection

The canonical definition is the exact destination path declared by `PACKAGE_MANIFEST.json`.

Do not choose it by:

```text
lowest folder number
newest modification date
alphabetical path
first recursive match
largest version value
display name
```

If one exact canonical path cannot be proven, stop as `TEST_INVALID`.

#### D. Safe retirement

For every additional same-project definition using the same `actionId`:

1. Verify its `projectKey` matches the destination project.
2. Verify it is not the canonical path.
3. Copy the complete folder into:

```text
<Project>\Project-And-Config\Install-State\Backups\<install-id>\
    Retired-Actions\<actionId-safe-name>\<original-relative-path>\
```

4. Calculate and verify hashes for every backed-up file.
5. Record:
   - action ID;
   - project key;
   - original path;
   - canonical path;
   - backup path;
   - definition hash;
   - implementation hashes;
   - reason;
   - reconciliation UTC.
6. Update `INCOMPLETE.json` with the pending retirement.
7. Remove the stale folder from `Project-Library`.
8. Verify the original folder is absent.
9. Mark the reconciliation complete.
10. Print the original, canonical and backup paths.

Never silently delete a duplicate folder. Preserve the backup after success.

#### E. Other-project or ambiguous definitions

When a duplicate definition has another `projectKey` or ownership cannot be proven:

```text
do not alter it
do not retire it as if owned by the destination project
do not import or execute the ambiguous workflow
report the actionId and every conflicting path
```

#### F. Mandatory fresh rescan

After reconciliation, rescan the installed library from disk.

For each package-supplied or workflow-referenced `actionId`, require:

```text
installed definition count = 1
installed projectKey = destination projectKey
installed path = canonical path when supplied by the package
entry point exists
definition and implementation hashes are readable
```

Do not rely only on the pre-reconciliation in-memory list.

Workflow execution is prohibited while any referenced `actionId` remains ambiguous.

#### G. Retry and workflow-session reuse

Record in `INCOMPLETE.json`:

```text
reconciliation status
retired-definition records
backup-manifest path
post-reconciliation scan hash
allocated workflow-session path
workflow-definition hash
```

On retry:

1. Revalidate completed reconciliation records.
2. Reuse existing verified backups.
3. Do not back up the same retired definition repeatedly.
4. Reuse a compatible previously allocated SQL-backed session.
5. Allocate a new session only when no valid recorded session exists.

Consuming another session number after the same workflow session was already safely allocated is `TEST_INVALID`.

#### H. SQL history

Retiring a stale filesystem definition does not delete historical SQL versions.

After filesystem uniqueness is proven, normal import may return existing identical version IDs or create new immutable versions for changed canonical definitions.

Never perform destructive SQL cleanup merely because a stale folder was retired.

#### I. Failure classification

These are `TEST_INVALID` project-package recovery defects:

```text
workflow execution begins while a referenced actionId has multiple installed definitions
only package-source uniqueness is checked
a stale same-project duplicate is silently deleted
a stale duplicate is removed without an intact verified backup
another project's duplicate definition is changed
reconciliation occurs after SQL import
the installed library is not rescanned
a retry consumes another session despite a compatible recorded session
```

No Dynomax Core change is required. This is installed-project catalogue reconciliation and package recovery behaviour.


## 18. Required console and process behaviour

### Successful execution

A successful installer or workflow must:

```text
close all created browser pages, contexts and processes
finish or terminate child processes safely
validate the result ZIP
copy the ZIP to the Windows clipboard as a file
close the controlling console automatically
not display pause
not open Explorer
not leave extra console windows or browser tabs
```

### Failed execution

A failed installer or workflow must:

```text
attempt browser and child-process teardown
print a clear failure heading
print the non-zero exit code
print the exception type and message
print the script, line and position where available
print the transcript path
detect whether a workflow result ZIP was created
validate any created PASS or non-PASS ZIP through the standard manifest/hash contract
copy a structurally valid non-PASS ZIP to the clipboard
print the validated result ZIP path
retain incomplete package and recovery state
keep the controlling console open
pause only on failure
return the original non-zero workflow/package exit code
```

Failure logs must be preserved even when the failure occurs before a result ZIP can be created.

When a valid non-PASS result ZIP exists, preserve both:

```text
the authoritative result ZIP
the original failure exit code and incomplete state
```

Successful ZIP validation is evidence validation, not workflow success.


Recommended patch transcript location:

```text
C:\Dynomax\Logs\Patches\<Version>\Dynomax-Patch-<Version>-<Timestamp>.log
```

Project installers and workflow packages must use similarly project-scoped log folders.

Every outer BAT wrapper must use this logic:

```text
run one controlling PowerShell script
capture %ERRORLEVEL% immediately
exit normally when it is 0
show diagnostics and pause when it is non-zero
exit with the same error code
```

Do not use multiple `start` commands that create unmanaged consoles.

## 19. Windows PowerShell 5.1 compatibility contract

Dynomax executable files must remain compatible with Windows PowerShell 5.1.

For every `.ps1`, `.bat` and `.cmd` file:

```text
ASCII-only content
CRLF line endings
no BAT BOM
no smart quotes
no em dash
no en dash
no decorative Unicode
```

Markdown and JSON may use UTF-8. Executable scripts may not contain Unicode punctuation unless a future certified framework version changes this contract.

Before copying a package:

1. Parse every delivered PS1 using Windows PowerShell 5.1.
2. Reject the package on any parser error.
3. Report the exact file, line and column.
4. Check every executable for non-ASCII bytes.

After copying:

1. Re-run the parser gate against the installed files.
2. For a Core patch, parse affected files under `Core`, `Config-And-Setup` and `Project-Setup`.
3. Do not start a workflow when parser validation fails.

Use:

```powershell
[System.Management.Automation.Language.Parser]::ParseFile(...)
```

All PowerShell scripts must use:

```powershell
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
```

Use `try/catch/finally` for transcript handling, process cleanup, result packaging and temporary-workspace deletion.

### PowerShell automatic-variable collision contract

Windows PowerShell variable names are case-insensitive. A local variable named `$matches`, `$MATCHES` or another case variation is the same variable as the automatic `$Matches` variable.

`$Matches` is an automatic hashtable populated or changed by regex `-match` and `-notmatch` operations in the current scope. It must never be repurposed as an ordinary array, list, candidate collection, accumulator, temporary object, parameter or loop variable.

Prohibited examples:

```powershell
$matches = @()
$matches += [pscustomobject]@{ Name = 'Candidate' }

param(
    $matches
)

foreach ($matches in $items) {
    # ...
}
```

A later regex operation in the same scope can replace the expected collection value with the automatic hashtable. A subsequent collection operation can then fail with:

```text
A hash table can only be added to another hash table.
```

Use descriptive names instead:

```powershell
$databaseCandidates
$functionDefinitions
$sessionOutputMatches
$regexCaptureValues
$matchingProjectFolders
```

The rule applies to all PowerShell automatic variables. Do not repurpose automatic variables such as:

```text
$Matches
$Error
$Input
$Args
$PSItem
$_
$LASTEXITCODE
$PSScriptRoot
$MyInvocation
$Host
$Home
$PID
```

Some automatic variables are intentionally read by scripts. They must not be redeclared or used as unrelated mutable storage.

#### Mandatory AST certification gate

Parser success alone does not detect automatic-variable type collisions.

Static certification must parse each PS1 file and inspect every `VariableExpressionAst` case-insensitively.

For the variable name `Matches`, certification must reject:

```text
assignment targets
compound assignment targets such as +=
increment or decrement targets
parameter declarations
foreach iterator variables
catch variables
ordinary temporary or collection use
case-variant spellings such as $matches or $MATCHES
```

Read-only `$Matches` access is permitted only when regex captures are genuinely required. The certification report must identify the exact file and line and confirm that the read is associated with an intentional `-match` or `-notmatch` capture flow in the same function or script scope.

A package with any unexplained `Matches` variable use fails static certification.

The automatic-variable AST gate applies to every script delivered or modified by the package. It does not require a project package to recertify or patch untouched accepted Core files. A Core file is subject to the gate when the package proposes to modify that Core file.

Recommended certification output:

```text
Automatic-variable collision gate: PASS
Matches writes/declarations: 0
Intentional Matches reads: <count and locations>
```

If the package does not need regex capture groups, the preferred count is zero.

### Dynomax PowerShell action invocation and output gate

For every project action declared with `engine: PowerShell`, static certification must prove the declared entry-point PS1 accepts all five exact Core parameters:

```text
DynomaxRoot
RunId
StepOrder
ContextPath
OutputPath
```

Names are case-insensitive but may not be replaced by custom aliases because Core invokes them by name.

Certification must also prove that every normal completion path writes valid JSON to `$OutputPath` containing at least:

```text
status
message
```

Checking only that `param()` exists is insufficient. Control-flow review must detect branches that can exit successfully without writing the structured result.

The entry point may call helper scripts, but it remains responsible for receiving the Core parameters and ensuring the final result exists.

### Core function loading in project installers

PowerShell parser success and AST source inspection do not load Dynomax functions.

Core loading is dependency-specific. Loading `Dynomax.Common.ps1` does not load functions defined in Process, Database, Catalogue, Results or Workflow scripts.

Before a package helper invokes an external Core command, it must know:

```text
exact command name
exact defining file
required parameters
required defining-file dependencies
scope in which the command will be invoked
```

A project installer must:

1. Dot-source the exact Core files in the documented order.
2. Do so in the scope that will invoke the functions.
3. Run exact `Get-Command -CommandType Function` checks after loading.
4. Call functions only after the runtime-load gate passes.
5. Avoid broad or wildcard script loading.
6. Avoid defining a helper that references an unloaded Core command and assuming later source validation is enough.
7. Build a command-to-file map for every external Dynomax command in the package.
8. Validate dependency closure for package helpers separately from the canonical workflow runner.
9. Include `Core\Execution\Dynomax.Process.ps1` whenever calling `Resolve-DynomaxCommand`.
10. Preflight installed project helper files referenced by workflow wrappers before modifying project state.

### PowerShell pipeline output cardinality contract

PowerShell functions communicate through the success output pipeline unless they return a separately documented typed object contract.

Pipeline output is cardinality-sensitive:

```text
no emitted objects       -> $null
one emitted object       -> scalar object
two or more emitted      -> Object[] array
```

A function's local variable type or `return @($items)` statement does not force the caller to receive an array because pipeline enumeration occurs after the function writes the value.

Required caller pattern:

```powershell
$records = @(
    Get-SomeRecords
)
```

Use caller-side `@(...)` normalization before any code that requires a collection contract.

Examples requiring normalization:

```powershell
$records.Count
$records[0]
$records += $newRecords
$records | ConvertTo-Json
$state.records = $records
Compare-Object $records $expectedRecords
```

A plain `foreach ($record in $possibleScalar)` can enumerate zero, one or many safely, but normalize when:

```text
the variable is persisted as an array
the code later uses Count or indexing
the variable is concatenated with another collection
the schema distinguishes one object from an array containing one object
```

Certification must distinguish:

```text
function-internal construction shape
caller-visible pipeline shape
persisted JSON/state shape
```

These are three separate contracts.

#### Mandatory zero/one/many test matrix

Every helper documented as collection-returning must have tests proving:

```text
ZERO
caller receives a normalized empty array
Count equals 0
JSON/state contains []

ONE
caller receives an array containing one object
Count equals 1
index 0 works
JSON/state contains an array with one object

MANY
caller receives an array containing all objects
Count equals expected value
ordering and hashes are preserved
JSON/state contains an array
```

Run the matrix with StrictMode enabled.

#### AST and source-review gate

Static certification must identify command-expression results that are:

```text
assigned to a variable
later accessed through .Count
later indexed
later used with +=
later persisted into a field requiring an array
```

For those flows, require caller-side `@(...)` normalization unless the command's return type is structurally guaranteed and documented.

A plural variable name is not proof of array shape.

A package that fails because a one-result helper became a scalar is `TEST_INVALID`.

### JSON-derived `PSCustomObject` schema and mutation contract

Under Windows PowerShell 5.1, `ConvertFrom-Json` returns `PSCustomObject`. Parser success does not detect missing-property mutation failures under StrictMode.

Required:

```text
explicit versioned state schema
every mutable property declared initially
legacy state normalized into a complete current-schema object
only declared properties mutated afterward
```

Certification must test current-state completion, current-state failure, recovery mutation, and legacy states missing completion or failure fields. A package-state failure after a validated live PASS is `TEST_INVALID` and does not invalidate the workflow PASS.

### `$LASTEXITCODE`

`$LASTEXITCODE` exists only after a native executable has run.

Correct native-process pattern:

```powershell
& $exe @args
$exitCode = $LASTEXITCODE
if ($exitCode -ne 0) {
    throw "Command failed with exit code $exitCode."
}
```

Capture it immediately before any other native process runs.

For a PowerShell script or function invoked in-process, use its return value or allow a terminating exception to propagate. Never read `$LASTEXITCODE` merely because a PowerShell script or function ran.

When intentionally launching a child `powershell.exe`, capture `$LASTEXITCODE` immediately after that child process returns.

## 20. Robot Framework Browser and path rules

Robot actions should normally be `.resource` files. Consecutive compatible Robot actions must be composed into one generated suite and share one browser session.


### Accepted shared-browser project-action contract

Dynomax owns browser startup and teardown for a compatible Robot block through:

```text
Start Dynomax Browser
Stop Dynomax Browser
```

Core starts one browser, context and initial page for the block.

Project actions using:

```text
RequiresExistingBrowser
RequiresNewOrExistingBrowser
```

must use the existing Dynomax-managed browser and page.

They must not call these merely to start every reusable action:

```text
New Browser
New Context
New Page
Close Browser
```

An additional page, context or browser is allowed only when the certified action purpose explicitly requires it and cleanup is declared.

Use:

```text
${DYNOMAX_BASE_URL}
Set Dynomax Context Value
Get Dynomax Context Value
```

Do not hardcode configured base URLs in reusable actions. Do not directly overwrite `${DYNOMAX_CONTEXT_PATH}`.

A shared-session Robot action that creates a fresh browser for ordinary startup is `TEST_INVALID`.

### Cleanup Robot block browser-lifecycle contract

The shared-browser rule applies within one compatible Robot block. It does not guarantee one browser across the normal and cleanup phases.

Dynomax may:

```text
start normal Robot block
run normal actions in one browser
close that browser
start cleanup Robot block in a new browser
run cleanup actions
close the cleanup browser
```

A cleanup action using `RequiresExistingBrowser` receives the cleanup block's browser, not the earlier normal block's authenticated state.

The generated cleanup Robot suite must include every required prerequisite action before protected or tenant-scoped cleanup.

For example:

```text
atx.auth.login
atx.ui.settle-overlays
atx.workspace.select
atx.banking.profiles.open-user-catalogue
atx.banking.profiles.delete-exact-draft
atx.auth.logout
```

The exact object name or GUID may come from Dynomax context. Credentials remain secret references and are never written into context.

A cleanup block containing only a protected delete action and logout, with no authentication/workspace setup, is `TEST_INVALID`.



Required behaviour:

```text
suite setup starts the shared browser
suite teardown closes it
actions reuse the existing page/context
long commands stream stdout and stderr
process ID, timeout, elapsed time and exit code are shown
a heartbeat is emitted during long-running commands
output.xml, log.html, report.html and console logs are retained
```

Windows paths written into Robot files must be converted to forward slashes.

Incorrect:

```text
C:DynomaxCoreRobotDynomax.resource
```

Correct:

```text
C:/Dynomax/Core/Robot/Dynomax.resource
```

Do not use Windows backslashes directly in generated Robot resource declarations.

Prerequisite checks must verify import or installed version first. They must not run `rfbrowser init`, `playwright install` or another lengthy installation merely to check whether an already installed dependency exists. Installation or repair must be explicit and visibly logged.

## 21. SQL and artifact persistence rules

Dynomax SQL is the authoritative framework backbone. It stores project/action/workflow versions, runs, per-action results, events, assertions, non-secret context, cleanup records and artifact metadata/content.

Rules:

1. Use the dedicated `Dynomax` database.
2. Never place framework tables in a target application's database.
3. Bind binary SQL parameters explicitly as `System.Byte[]`.
4. Never pass a PowerShell `Object[]` to `varbinary(max)`.
5. Record SHA-256 and size before persistence.
6. Keep the binary persistence self-test.
7. Treat SQL write or binary conversion failures as `ERROR`.
8. Export SQL artifact IDs, filenames, hashes and sizes in `ArtifactManifest.json`.
9. Do not expose target database data unless the project evidence contract explicitly authorises it.

## 22. Durable framework-development lessons

Future agents must not repeat these failures.

### Root validation was linked to ATX

The initial root validation invoked an ATX workflow. This violated project neutrality.

**Permanent rule:** root validation uses only local project-neutral fixtures. ATX and every other target run only from their project folder.

### Robot resource paths lost their separators

Generated paths became:

```text
C:DynomaxCoreRobotDynomax.resource
```

Robot could not load Core or project resources.

**Permanent rule:** write forward-slash paths into generated Robot files and statically inspect the generated path contract.

### Prerequisite checks performed installations

Browser and Playwright checks took minutes because installation commands ran even though dependencies were already installed.

**Permanent rule:** checks verify first. Installation is a separate repair operation. Long-running processes must stream progress and heartbeat output.

### SQL binary persistence received `Object[]`

The framework reported:

```text
Failed to convert parameter value from a Object[] to a Byte[].
```

**Permanent rule:** read and bind artifact content as `System.Byte[]` explicitly.

### A failure console closed immediately

The user could not see what failed.

**Permanent rule:** success closes; failure pauses, prints diagnostics and preserves a transcript.

### `$LASTEXITCODE` was read before it existed

Strict mode raised:

```text
The variable '$LASTEXITCODE' cannot be retrieved because it has not been set.
```

**Permanent rule:** only read `$LASTEXITCODE` immediately after a native process. Use explicit PowerShell returns or exceptions for in-process scripts.

### Post-PASS state finalization mutated a missing legacy property

Observed live workflow:

```text
Normal Robot block: 7 passed.
Cleanup Robot block: 5 passed.
Overall workflow status: PASS.
Exact Draft cleanup: PASS.
Result ZIP was created, fully validated and copied to the clipboard.
```

Package failure after the accepted PASS:

```text
Exception setting "completedAtUtc":
The property 'completedAtUtc' cannot be found on this object.
```

Confirmed root cause:

```text
existing state was loaded through ConvertFrom-Json
the legacy schema omitted completedAtUtc, resultZip and failedAtUtc
the package directly assigned a missing PSCustomObject property
StrictMode rejected the mutation
the workflow and cleanup PASS had already completed
```

Classification:

```text
live workflow: PASS
package bookkeeping: TEST_INVALID
```

The live PASS remains valid and must not be rerun solely for this defect. Recovery must migrate state, validate exactly one matching prior PASS ZIP, write and reread COMPLETE.json, remove INCOMPLETE.json only afterward, reuse the recorded session and consume no new session number.

No Dynomax Core or ATX application change is required.

### Cleanup block omitted authentication and workspace prerequisites

Observed normal execution:

```text
atx.auth.login                                  PASS
atx.ui.settle-overlays                          PASS
atx.workspace.select                            PASS
atx.banking.profiles.open-user-catalogue        PASS
atx.banking.profiles.create-statement-draft     PASS
atx.banking.statement.verify-exact-draft        PASS
```

Observed cleanup execution:

```text
Dynomax closed the normal browser.
Dynomax started a separate cleanup Robot block in a fresh browser.
The cleanup block contained:
- atx.banking.profiles.delete-exact-draft
- atx.auth.logout
```

Failure:

```text
The delete action navigated to a protected route in the anonymous cleanup browser.
It waited for .atx-authenticated-root and failed.
The workflow result was CLEANUP_FAILED.
```

Confirmed causal root cause:

```text
the cleanup block omitted certified login
the cleanup block omitted overlay settling
the cleanup block omitted workspace selection
the cleanup action assumed normal-block browser/session state survived
the protected delete operation itself was not validly reached
```

Classification:

```text
workflow result: CLEANUP_FAILED
causal defect:   TEST_INVALID
```

This was not an ATX draft-deletion defect.

Required prevention:

```text
certify normal and cleanup dependency graphs separately
assume a fresh browser for every cleanup Robot block
reuse atomic login, overlay and workspace actions
re-establish the exact tenant/workspace
carry only non-secret exact cleanup identifiers through context
verify deletion only after prerequisite closure passes
```

A second login during cleanup is expected when the cleanup block owns a fresh browser.

No Dynomax Core or ATX application change is required.

### Valid non-PASS ZIP was rejected because optional findings were absent

A non-PASS workflow may still generate a structurally complete authoritative result ZIP.

Permanent evidence contract:

```text
PASS and non-PASS ZIPs use the same manifest and hash validation
Definitions is mandatory
TestEvidence is mandatory
ProjectFindings is conditional on findings being generated
a wrapper must not require optional ProjectFindings
a valid non-PASS ZIP is preserved and copied to the clipboard
the original non-zero exit code is retained
INCOMPLETE.json and recovery state remain active
```

A wrapper that rejects an otherwise valid `FAIL`, `TEST_INVALID`, `BLOCKED`, `ERROR` or `CLEANUP_FAILED` ZIP solely because `ProjectFindings/` is absent has a `TEST_INVALID` evidence-validation contract.

No Dynomax Core or ATX application change is required.

### Process helper was source-confirmed but never loaded

Observed execution boundary:

```text
Dynomax version 1.0.8 validated.
Exact Core, package parser, encoding and Robot resource-contract validation began.
Package ZIP integrity and manifest hashes were valid.
Package-source action IDs were unique.
Failure occurred while resolving the configured Python command for Robot dry-run validation.
Project managed files were not copied.
Project, action and workflow SQL import did not occur.
No SQL-backed workflow session was allocated.
The canonical workflow runner did not start.
Chromium did not start.
The ATX website was not tested.
```

Failure:

```text
The term 'Resolve-DynomaxCommand' is not recognized.
```

Confirmed root cause:

```text
Resolve-DynomaxCommand is defined in:
C:\Dynomax\Core\Execution\Dynomax.Process.ps1

The package's Get-AtxDynomaxPythonCommand helper dot-sourced only:
C:\Dynomax\Core\Common\Dynomax.Common.ps1

The Core contract validator did not include Dynomax.Process.ps1 or validate the
Resolve-DynomaxCommand -Candidates contract.

The package therefore proved a general Core contract but did not prove complete
runtime dependency closure for the commands used by that helper.
```

Classification:

```text
TEST_INVALID
```

This was not a Dynomax Core, SQL, Robot, browser or ATX website failure.

Required prevention:

```text
map every external Core command to its exact defining file
include Core\Execution\Dynomax.Process.ps1 in the contract object
AST-validate Resolve-DynomaxCommand with mandatory Candidates
dot-source Common and Process in the helper's invocation scope
run Get-Command checks after loading
do not invent a local replacement for an existing Core command
certify command dependency closure for every installer helper and workflow wrapper
```

**Permanent rule:** follow sections 17.1 H.1-H.3 and section 19. A generic Core-contract PASS does not prove that every Core command used by the package is callable.

No Dynomax Core change is required.

### Single PowerShell helper result collapsed to a scalar

Observed execution boundary:

```text
Dynomax 1.0.8 validation passed.
Package, encoding and parser gates passed.
Exact Core contract validation passed.
Dynomax SQL validation passed.
Same-project recovery passed.
Session 000001-Public-Homepage-Observation was reused.
Duplicate reusable-action reconciliation passed.
Installed action-catalogue uniqueness validation passed.
Project and action SQL import passed.
Workflow execution had not started.
Chromium had not started.
The ATX website was not tested.
```

Failure:

```text
The property 'Count' cannot be found on this object.
```

Failing pattern:

```powershell
$workflowBackup = Backup-ChangedManagedFiles ...
if ($workflowBackup.Count -gt 0) {
    ...
}
```

Confirmed root cause:

```text
PowerShell pipeline output was automatically unrolled.
Zero helper results would produce $null.
One helper result produced a scalar PSCustomObject.
Multiple helper results would produce an array.
The helper returned exactly one backup record.
The caller assumed an array and used .Count under StrictMode.
The helper's internal return @($items) did not guarantee caller-side array shape.
```

Classification:

```text
TEST_INVALID
```

This was a project-package PowerShell collection-shape and certification defect. It was not a Dynomax Core, SQL, browser or ATX website failure.

Required prevention:

```text
normalize collection output at the caller with @(...)
normalize before Count, indexing, += or array-shaped persistence
test zero, one and multiple results
do not infer caller shape from return @($items)
use plural variable names only after normalization
preserve array shape in incomplete state, backup manifests and JSON
run the tests with StrictMode enabled
```

Recommended safe pattern:

```powershell
$backupRecords = @(
    Backup-ChangedManagedFiles `
        -ExistingRoot $existingRoot `
        -SourceRoot $sourceRoot `
        -BackupRoot $backupRoot
)

if ($backupRecords.Count -gt 0) {
    $backupInventory += $backupRecords
}
```

**Permanent rule:** follow sections 17.2 D.1 and 19. Any helper output consumed as a collection must be normalized at the caller and certified for zero, one and many results.

No Dynomax Core change is required.

### Duplicate installed `actionId` blocked the canonical workflow runner

Observed execution boundary:

```text
Dynomax 1.0.8 validation passed.
Package, encoding and parser gates passed.
Exact Core contract validation passed.
Dynomax SQL connection validation passed.
Same-project recovery passed.
Project and reusable-action installation passed.
Project and action SQL import passed.
A SQL-backed workflow session was allocated.
The workflow was installed.
The canonical workflow runner started.
Chromium did not start.
```

Failure:

```text
Expected one project-library action definition for
'atx.website.open', found 2.
```

Root cause:

```text
package-source action IDs were unique
the installed Project-Library contained a stale same-project duplicate folder
folder paths were treated as identity instead of actionId
the installer did not separately scan and reconcile the installed library
workflow execution began while the referenced actionId was ambiguous
```

Classification:

```text
TEST_INVALID
```

This was not a Dynomax Core, SQL or ATX website failure.

Required prevention:

```text
treat actionId as authoritative identity
scan package source and installed Project-Library separately
reconcile after managed-file installation and before SQL import
back up stale same-project duplicate folders intact
never silently delete a duplicate
never change another project's definition
rescan the installed library after reconciliation
require exactly one installed definition for every workflow actionId
reuse a compatible previously allocated session on retry
```

**Permanent rule:** follow sections 5.3 and 17.3. Static uniqueness inside the ZIP does not certify the installed project catalogue.

No Dynomax Core change is required.

### SQL configuration was reconstructed from guessed fields

Observed execution boundary:

```text
Dynomax version validation passed.
Package, encoding and parser gates passed.
The configured database JSON and top-level sql object were found.
The package attempted to reconstruct a connection string from assumed sql-property names.
Project and action definitions were not imported.
No SQL-backed workflow session was allocated.
Chromium did not start.
The ATX website was not tested.
```

Failure:

```text
The configured Dynomax sql object contains neither a connection string nor server/database fields.
```

Root cause:

```text
databaseConfig.sql was not treated as an opaque Core configuration object
the package guessed field names
the package attempted to rebuild configuration instead of passing it unchanged
```

Classification:

```text
TEST_INVALID
```

Required prevention:

```text
resolve only dynomax.json.paths.databaseConfig
load through Resolve-DynomaxPath and Read-DynomaxJson
pass databaseConfig.sql unchanged
validate through Open-DynomaxConnection -SqlConfig $databaseConfig.sql
never infer connectionString, server, database, username or password
never recursively discover plausible database JSON
```

No Dynomax Core change is required.

### Source-confirmed Core function was not loaded

Observed execution boundary:

```text
Dynomax version 1.0.8 validated.
Package, encoding and parser gates passed.
Exact Core source contracts were reported.
Project import was identified as Import-DynomaxProjectFolder.
Workflow runner was identified as Invoke-DynomaxWorkflow.ps1.
SQL validation attempted to call Open-DynomaxConnection.
Open-DynomaxConnection was not available in the calling scope.
Project and action definitions were not imported.
No SQL-backed workflow session was allocated.
Chromium did not start.
The ATX website was not tested.
```

Failure:

```text
The term 'Open-DynomaxConnection' is not recognized.
```

Root cause:

```text
the package confirmed the function in source
the package did not dot-source Core\Database\Dynomax.Database.ps1 in the calling scope
source-contract validation was confused with runtime command availability
```

Classification:

```text
TEST_INVALID
```

Required prevention:

```text
dot-source Common, Database and Catalogue in canonical order
load them in the scope that calls the functions
run exact Get-Command checks after loading
do not use AST confirmation as runtime availability proof
launch Invoke-DynomaxWorkflow.ps1 for execution instead of reproducing its complete load graph
```

No Dynomax Core change is required.

### Automatic `$Matches` collision broke database discovery

Observed execution boundary:

```text
Dynomax 1.0.8 validation passed.
Package encoding and parser gates passed.
Failure occurred while resolving the configured database JSON.
Project definitions were not imported.
No SQL-backed workflow session was allocated.
Chromium did not start.
The ATX website was not tested.
```

Failure:

```text
A hash table can only be added to another hash table.
```

Confirmed root cause:

```text
Windows PowerShell variable names are case-insensitive.
$Matches is an automatic hashtable used by -match and -notmatch.
The package used $matches as a normal array.
A regex operation in the same scope replaced that array through the automatic $Matches variable.
The next += [pscustomobject] operation attempted to add an object to a hashtable.
```

Classification:

```text
TEST_INVALID
```

This was a project-package coding and certification defect. It was not a Dynomax Core, SQL or ATX website failure.

Required prevention:

```text
never repurpose PowerShell automatic variables
never use $matches as a collection or temporary variable
use descriptive names such as $databaseCandidates, $functionDefinitions or $sessionOutputMatches
inspect VariableExpressionAst nodes case-insensitively
reject assignment, declaration or mutation of Matches
do not treat parser success as proof against automatic-variable collisions
```

**Permanent rule:** section 19's automatic-variable AST gate is mandatory for every delivered PowerShell package.

### Unicode punctuation broke PowerShell 5.1 parsing

An em dash in `Dynomax.Results.ps1` was decoded incorrectly and caused parser errors.

**Permanent rule:** executable files are ASCII CRLF and pass Windows PowerShell 5.1 parser gates before and after installation.

### The early result ZIP was incomplete

It referenced a screenshot but did not export it and omitted formal manifests.

**Permanent rule:** the ZIP contains complete information for every action and all mandatory manifests, definitions, Robot evidence, screenshots, cleanup proof and SQL artifact references.

### ZIP members used Windows backslashes

Early entries used:

```text
ProjectFindings\WebsiteFindings.json
```

**Permanent rule:** ZIP member names always use `/`.

### Structured durations showed zero

Coarse SQL timestamps produced `durationMs: 0`, although Robot retained accurate timings.

**Permanent rule:** use a Stopwatch for structured millisecond duration and preserve Robot `output.xml` as raw timing authority.

### Patch files cluttered the Dynomax root

**Permanent rule:** all patches live under `C:\Dynomax\Patches\<Version>`, with old material moved under `Patches\Legacy`.


### Project installer guessed Core import entry points

Observed sequence:

```text
Dynomax version 1.0.8 validated.
Dynomax SQL connection validated.
Package failed while validating assumed Core project-import entry points.
No project files were copied.
No SQL project/action/workflow import occurred.
No browser or website workflow ran.
```

Root cause:

```text
The package guessed Core integration function names.
The guide did not document the exact certified project-facing integration contract.
```

Classification:

```text
TEST_INVALID
```

This was not a Dynomax Core execution failure and not an ATX website failure.

Required prevention:

```text
source-confirmed Core interface mapping before package generation
exact preflight against the installed interface
no invented function-name lists
exact parameter-contract validation, not command-name matching
no Core modification merely to satisfy an invented interface
```

**Permanent rule:** use section 17.1. A missing or renamed assumed command is `TEST_INVALID` until the package proves it used the documented installed contract.


### Same-project destination was treated as an unrecoverable conflict

Observed sequence:

```text
Dynomax version 1.0.8 validated.
Dynomax SQL connection validated.
Project import interface validated as Function:Import-DynomaxProjectFolder.
Workflow execution interface validated as Script:Invoke-DynomaxWorkflow.
C:\Dynomax\Project-Setup\ATX-Solutions already existed.
The package stopped before copying, SQL import or browser execution.
```

Live installation finding:

```text
The existing ATX-Solutions\Project-And-Config\project.json owns projectKey atx-solutions.
The installed Core resolves project folders through project.json projectKey.
The installed SQL import functions are hash-idempotent.
```

Root cause:

```text
The package treated every existing destination as an unrecoverable conflict.
It did not distinguish another project from the same project.
It had no incomplete-install marker, managed-file ownership or safe resume contract.
```

Classification:

```text
TEST_INVALID
```

This was not a Dynomax Core, SQL or ATX website failure.

Required prevention:

```text
validate destination ownership through projectKey
resume/update a same-project folder safely
preserve unrelated project-local files
back up changed managed files
install managed files atomically
write INCOMPLETE.json before mutation
retain it after failure
write COMPLETE.json only after import and live PASS
reuse a recorded allocated session on retry
never recursively delete the same-project folder without explicit approval
```

**Permanent rule:** follow section 17.2. A user must not have to delete the entire project folder to retry a valid same-project installer.

### Successful executions left too many windows

**Permanent rule:** do not open Explorer, do not create unnecessary consoles, and close every browser tab/context/process on success.

## 23. Full end-to-end workflow expected from an agent

### Starting a new project

1. Read this guide completely.
2. Give a read-only confirmation that Dynomax Core remains project-neutral.
3. Confirm the Dynomax root and minimum version.
4. Inspect the actual installed Core or an authoritative exact-version Core export.
5. Produce an exact interface map matching section 17.1.
6. Prove paths, commands, parameters, inputs, returns and failure behaviour.
7. Reject guessed names and broad command discovery.
8. Inventory every external Dynomax command used by installers, package helpers and workflow wrappers.
9. Map each command to its exact installed defining file and parameter contract.
10. Prove the complete dependency set is dot-sourced in the same invocation scope.
11. Run runtime `Get-Command` checks for every mapped function.
12. Preflight installed project helper files referenced by workflow wrappers.
13. Collect only genuinely missing project facts.
14. Obtain current project source contracts when selectors or handlers depend on source.
15. Create `project.json` with secret references only.
16. Create the smallest reusable action set.
17. Treat `actionId` as identity and declare one canonical path per package action.
18. Create one initial workflow definition.
19. Register exact cleanup for target modifications.
20. Build `PACKAGE_MANIFEST.json` with exact managed paths and hashes.
21. Validate package-source action uniqueness and workflow resolution.
22. Define incomplete, completion, managed-file, reconciliation and backup state.
23. Define an explicit current installer-state schema version with all completion, failure and recovery fields.
24. Define and test legacy-state migration before any state mutation.
25. Preserve project, workflow, session, start-time, reconciliation and prior-error identity during migration.
26. Build separate normal-action and cleanup-action dependency graphs.
27. Assume each cleanup Robot block may receive a fresh anonymous browser.
28. Add certified login, overlay and tenant/workspace prerequisites to every authenticated cleanup block.
29. Validate that cleanup context keys are exact, non-secret and sufficient to locate the created object.
30. Generate and dry-run the cleanup Robot block independently from the normal block.
31. Create one safely repeatable self-installing ZIP.
32. Statically certify interfaces, ownership, recovery, action contracts, source uniqueness and installed-library reconciliation.
33. Identify every collection-returning installer helper used by backup, reconciliation, discovery, state or manifest code.
34. Normalize every such helper result at the caller before `.Count`, indexing, concatenation or array-shaped persistence.
35. Run zero-result, one-result and multiple-result tests under StrictMode.
36. Verify array shape in installer state and JSON for all three cardinalities.
37. Classify the destination ownership state.
38. Stop without mutation for another project or ambiguous ownership.
39. Write `INCOMPLETE.json` before the first mutation.
40. Stage and verify all managed files.
41. Back up changed managed files.
42. Atomically install managed files.
43. Preserve unrelated project-local files.
44. Scan the complete installed `Project-Library` separately.
45. Group definitions by `actionId`.
46. Back up and retire only safe stale same-project duplicates.
47. Never alter another project's duplicate.
48. Rescan the installed library from disk.
49. Require every package/workflow actionId to resolve exactly once.
50. Import project and actions only after uniqueness passes.
51. Accept identical SQL definitions idempotently.
52. Create immutable versions only for actual changes.
53. Reuse a compatible session recorded by the incomplete marker.
54. Allocate one new session only when no compatible session exists.
55. Record the session path immediately.
56. Install the workflow into that session.
57. Run the uniqueness gate again immediately before execution.
58. Execute through `Core\Invoke-DynomaxWorkflow.ps1 -WorkflowDirectory`.
59. Let Core own workflow import, persistence and export.
60. Validate the result ZIP and clipboard handoff.
61. Validate PASS and non-PASS ZIPs with the same required manifest/hash contract.
62. Require Definitions and TestEvidence, but require ProjectFindings only when generated.
63. On a valid non-PASS result, copy the ZIP to the clipboard and print its path before returning the original non-zero exit code.
64. Retain incomplete package and safe retry state after non-PASS execution.
65. After a live PASS, normalize state before assigning completion fields.
66. Write and reread COMPLETE.json before removing or archiving INCOMPLETE.json.
67. If bookkeeping fails after a validated PASS, recover completion from exactly one matching PASS ZIP.
68. Do not rerun the validated workflow or allocate another session during completion recovery.
69. Write completion state only after reconciliation, SQL import and live PASS.
70. Retain incomplete state, backups, reconciliation records and session path after failure.
71. Close automatically on success.
72. Keep the console open with exact retry information on failure.
73. Never require deletion of the same-project folder.
74. Never recursively delete it without explicit approval.
75. Classify unresolved installed action duplicates as `TEST_INVALID`, not a Core or target failure.

### Creating a new test in an existing project

1. Read this guide and the project's latest source-of-truth/context files.
2. Inspect the existing action catalogue.
3. Reuse certified actions.
4. Add only missing versioned actions.
5. Compose the normal action graph.
6. Compose and certify the cleanup dependency graph separately.
7. Assume authenticated cleanup may run in a fresh browser and include login, overlay and workspace prerequisites.
8. Validate non-secret context keys required for exact cleanup.
9. Reuse or allocate the correct SQL-backed session according to package recovery state.
10. Return one self-installing workflow ZIP.
11. Preserve and hand back a valid non-PASS result ZIP while retaining its non-zero exit code.
12. Normalize or migrate installer state before completion, failure or recovery mutation.
13. If a validated live PASS exists and only bookkeeping failed, recover completion without rerunning or allocating another session.
14. Do not modify Core for a project-specific requirement.

### Analysing a returned result ZIP

1. Verify ZIP integrity.
2. Parse all manifests.
3. Validate declared hashes.
4. Inspect every action result, not only the summary.
5. Inspect Robot evidence and screenshots.
6. Inspect context, assertions, events and cleanup.
7. Verify SQL artifact references.
8. Verify temporary workspace deletion.
9. Identify the first causal failure.
10. Classify it as `FAIL`, `TEST_INVALID`, `BLOCKED`, `ERROR`, `STALE`, `SKIPPED` or `CLEANUP_FAILED`.
11. State what was wrong.
12. State what needs to change.
13. Create the smallest corrected project package when justified.
14. Do not rerun already proven unrelated scope.
15. Never claim a fix is proven until the corrected live run passes.

## 24. Expanded static package certification

Before returning any package, verify:

```text
ZIP opens
all required members exist
PACKAGE_MANIFEST.json parses
all JSON files parse
projectKey/actionId/workflowId values agree
action IDs resolve exactly once
entry-point files exist
Robot keywords exist
BAT/CMD/PS1 files are ASCII-only CRLF
BAT files have no BOM
Windows PowerShell 5.1 parses every PS1
PowerShell AST automatic-variable collision gate passes every PS1
VariableExpressionAst names are compared case-insensitively
Matches is not assigned, mutated, declared as a parameter or used as a loop/catch variable
every intentional read of $Matches is listed and tied to regex capture logic
parser success is not accepted as automatic-variable collision certification
strict mode and terminating errors are enabled
no smart quotes or Unicode dashes exist in executable files
no secret values are embedded
only secret-reference names are stored
installer writes only to declared Dynomax destinations
project package does not alter Core
Core patch contains no project-specific content
Robot paths use forward slashes
no `C:Dynomax...` resource path can be generated
no stale package/project names remain
one controlling BAT is used
success has no pause
failure pauses and preserves the exit code
transcript path is printed
browser teardown exists
child process cleanup exists
Explorer is not opened
result ZIP creation is enabled
clipboard file copy is enabled
all mandatory result files are generated
every executed/skipped/cleanup action has a result
SQL artifacts are mapped
ZIP member hashes and sizes are generated
the ZIP is reopened and every member is read
temporary workspace deletion is verified
static certification is reported separately from live execution
installed Core source path is authoritative for the detected version
Catalogue script contains Import-DynomaxProjectFolder with ProjectFolder and SqlConfig
Catalogue script contains the three exact lower-level import functions and parameters
session allocator script has mandatory ProjectKey and Name parameters
workflow runner script has mandatory WorkflowDirectory and optional DynomaxConfigPath
workflow execution is launched as a child process because the runner calls exit
result exporter helpers are not called as project-facing APIs
Initialize-DynomaxCore.ps1 is not used as a single-project installer
session allocation is not called during read-only preflight
exactly one created-session path is captured
no guessed function-name list exists
no wildcard command selection exists
parameter compatibility is proven, not inferred from command existence
interface preflight completes before project files are copied
destination ownership state is deterministically classified
projectKey is used as ownership authority
same-project resume/update is supported
other-project and ambiguous folders are unchanged
package-managed files are explicitly listed
unrelated project-local files are preserved
changed managed files are backed up and backup hashes verified
managed replacements are atomic and final hashes verified
INCOMPLETE.json is written before any mutation
INCOMPLETE.json remains after failure
COMPLETE.json requires SQL import plus live workflow PASS
managed-file state is written only after successful installation
recorded session paths are reused safely on retry
session allocation is not repeated after a recorded allocation
recursive same-project deletion is prohibited
SQL imports are verified as idempotent for identical hashes
database config path comes only from dynomax.json.paths.databaseConfig
databaseConfig.sql remains the original loaded object
no SQL field-name reconstruction exists
Open-DynomaxConnection receives databaseConfig.sql unchanged
Core Common, Database and Catalogue scripts are loaded in canonical order
runtime Get-Command proves Read-DynomaxJson, Resolve-DynomaxPath, Open-DynomaxConnection and Import-DynomaxProjectFolder are loaded
runtime load checks occur in the same scope as function invocation
AST source confirmation is separate from runtime availability
shared Robot actions contain no ordinary per-action New Browser/New Context/New Page startup
Robot resources use Set/Get Dynomax Context Value
PowerShell action parameters exactly match Core invocation names
PowerShell actions read context.values
every normal PowerShell action path writes OutputPath JSON with status and message
project-export is used for project findings
action.json schema and implementation are cross-validated
package-source actionId values are unique
workflow action IDs resolve exactly once in package source
installed Project-Library is scanned independently from package source
installed definitions are grouped by actionId
canonical action paths come from PACKAGE_MANIFEST.json
reconciliation runs after managed-file installation and before SQL import
same-project duplicate folders are backed up intact
backup hashes are verified before stale folders are retired
backup manifest records actionId, original path, canonical path and backup path
INCOMPLETE.json records pending and completed reconciliations
other-project duplicate definitions are never changed
ambiguous ownership stops installation without destructive action
installed library is rescanned from disk after reconciliation
every workflow-referenced actionId resolves exactly once
package-supplied action IDs resolve at canonical paths
workflow execution is blocked while any referenced actionId is ambiguous
a final uniqueness gate runs immediately before workflow execution
a compatible recorded session is reused during retry
retry does not consume another session number unnecessarily
retiring a stale filesystem definition does not delete immutable SQL history
every helper result used with .Count is initialized through caller-side @(...)
every helper result used for indexing is normalized or has a documented structural array return type
every helper result used with += as a collection is normalized at the caller
function-internal return @($items) is not accepted as caller-side array proof
collection helper zero-result tests pass under StrictMode
collection helper one-result tests pass under StrictMode
collection helper multiple-result tests pass under StrictMode
empty collection state persists as []
single collection state persists as an array containing one object
multiple collection state persists as an array
backup inventory preserves array shape at zero, one and many records
reconciliation inventory preserves array shape at zero, one and many records
AST/source review traces .Count, indexing and += consumers back to normalized command results
PowerShell CommandAst inventory covers every delivered installer, helper and workflow wrapper
local package functions are distinguished from external Dynomax Core commands
every external Core command maps to exactly one authoritative defining file
every mapped function's required parameter contract is validated
the exact defining files are loaded before first invocation
runtime Get-Command confirms every mapped function in the same invocation scope
Core contract objects return every defining-file path required by their callers
Resolve-DynomaxCommand is validated in and loaded from Core\Execution\Dynomax.Process.ps1
helpers do not assume Common.ps1 contains Process, Database, Catalogue, Results or Workflow functions
installed project helper scripts referenced by workflow wrappers exist and expose their required commands
no generic Core-contract PASS substitutes for command dependency closure
normal and cleanup Robot blocks are identified independently
cleanup actions are grouped into their actual generated cleanup block
cleanup prerequisite closure is certified separately from normal prerequisite closure
every authenticated cleanup block begins with a certified login action
overlay/cookie blockers are settled in the cleanup block where applicable
tenant-scoped cleanup re-selects or verifies the exact workspace
protected cleanup navigation occurs after authentication and tenant establishment
cleanup object names and GUIDs are read from non-secret context values
cleanup context does not contain credentials, cookies or tokens
cleanup dry-run proves prerequisite actions precede destructive actions
a second cleanup login is not rejected as duplicate logic
CLEANUP_FAILED results are inspected for causal TEST_INVALID dependency defects
PASS and non-PASS ZIP validation uses one required-member/manifest/hash implementation
Definitions and TestEvidence are mandatory for PASS and non-PASS results
ProjectFindings is conditional on generated findings
optional ProjectFindings absence does not invalidate a non-PASS ZIP
valid non-PASS ZIPs are preserved under Exports
valid non-PASS ZIPs are copied to the clipboard before failure return
original workflow classification and non-zero exit code are preserved
incomplete package state remains after valid non-PASS execution
installer state schemaVersion is explicit and supported
initial state contains completedAtUtc, failedAtUtc, resultZip, resultZipSha256 and recovery fields
legacy JSON state is normalized into a complete current-schema object
migration preserves project, workflow, session, time, reconciliation, backup and prior-error identity
no code directly adds undeclared properties to JSON-derived PSCustomObject state
completion, failure and recovery mutation tests pass under StrictMode
legacy states missing completion and failure fields migrate successfully
post-PASS bookkeeping failure preserves the validated PASS ZIP
completion recovery validates exactly one matching PASS ZIP
matching validates timestamp, project key, workflow ID, session identity, PASS status, entries, sizes and SHA-256 hashes
COMPLETE.json is atomically written, hashed and reread before INCOMPLETE.json removal
completion-only recovery does not execute the workflow or allocate a session
plural variable names are used only after array normalization
```


## 25. Framework completion baseline

Dynomax Core V1 is complete and accepted as of version 1.0.8. The generic self-test and full project-pipeline closeout both passed. Normal future work is project onboarding, reusable action creation, workflow composition, execution and returned-result analysis. Change Core only when live evidence proves a project-independent framework defect. The 1.0.8 project-facing integration contract is version-specific and consists of the exact scripts and functions in section 17.1. The absence of one formal structured public onboarding wrapper is a hardening opportunity, not evidence that the accepted Core is broken. The live 1.0.8 audit also confirms that safely repeatable same-project installation can be implemented entirely in the project package; no Core correction is required for the ATX V2 existing-folder failure. The live source and accepted demo also confirm the opaque SQL-object, canonical Core bootstrap, shared-browser, context-envelope and PowerShell action contracts. The V5 and V6 failures are project-package implementation/certification defects and require no Core change. The V7 duplicate-action failure likewise requires installed-project catalogue reconciliation in the onboarding package, not a Core change. The V8 collection-cardinality failure requires caller-side PowerShell normalization and zero/one/many package certification, not a Core change. The foundation package's missing `Resolve-DynomaxCommand` runtime dependency requires package command-dependency closure and correct Process-script loading, not a Core change. The foundation V1.0.1 cleanup failure requires cleanup-block prerequisite closure and correct non-PASS ZIP handoff in the project package, not a Dynomax Core or ATX application change. The foundation V1.0.2 post-PASS failure requires versioned package-state migration and completion-only recovery; its validated workflow PASS remains accepted and requires no rerun, new session, Core change or ATX change.


## 26. Standard prompt for a new project

```text
Read the attached DYNOMAX_AGENT_GUIDE.md completely before responding.

We are starting a new Dynomax project for https://www.abc.com.

Create the initial project-onboarding package using the documented Dynomax project, SQL, reusable-action and workflow conventions. Return one ZIP that I can extract anywhere and run through one BAT file.

The installer must:
- validate C:\Dynomax and the minimum framework version;
- inspect the actual installed Core and prove the exact section 17.1 interface paths and parameter contracts;
- never guess Core function names or use broad wildcard command discovery;
- complete exact interface preflight before copying project files;
- inventory every external Dynomax command used by package helpers and workflow wrappers;
- map each command to its exact defining Core file and parameter contract;
- dot-source the complete dependency set in the same scope as invocation;
- run exact runtime Get-Command checks for every external Core function;
- load Core\Execution\Dynomax.Process.ps1 before using Resolve-DynomaxCommand;
- preflight installed project helper files referenced by workflow wrappers;
- dot-source Core Common, Database and Catalogue in canonical order and prove required functions are loaded with Get-Command;
- resolve only dynomax.json.paths.databaseConfig;
- pass databaseConfig.sql unchanged and validate it with Open-DynomaxConnection;
- never reconstruct SQL configuration from guessed properties;
- create Robot actions that reuse the Dynomax-managed shared browser and context keywords;
- model normal and cleanup Robot blocks as separate browser lifecycles;
- include certified login, overlay and workspace prerequisites in authenticated cleanup blocks;
- carry only non-secret exact cleanup identifiers through Dynomax context;
- certify cleanup dependency closure separately from normal dependency closure;
- create PowerShell actions with the exact five Core parameters and structured OutputPath results;
- safely support an absent or existing same-project destination;
- treat actionId as authoritative identity and declare one canonical path for every package action;
- validate package-source action IDs and workflow references;
- scan the installed Project-Library separately after managed-file installation;
- back up and retire stale same-project duplicate definitions before SQL import;
- never alter another project's duplicate definition;
- rescan and require exactly one installed definition for every workflow actionId;
- block workflow execution while any referenced actionId remains ambiguous;
- reuse a compatible recorded session during retry;
- normalize all collection-returning helper calls with @(...) before Count, indexing, concatenation or array-shaped persistence;
- test collection helpers with zero, one and multiple results under StrictMode;
- preserve collection array shape in incomplete state, backup manifests and JSON;
- validate destination ownership through project.json projectKey;
- leave another project's or ambiguous destination unchanged;
- preserve unrelated project-local files;
- back up and atomically replace changed package-managed files;
- write and retain an incomplete marker across failure;
- use an explicit versioned installer-state schema containing all completion, failure and recovery fields;
- normalize legacy JSON state before mutation;
- recover a validated prior live PASS without rerunning or allocating another session when only completion bookkeeping failed;
- write and reread COMPLETE.json before removing or archiving INCOMPLETE.json;
- write a completion marker only after SQL import and live workflow PASS;
- reuse a valid recorded workflow session during retry;
- never require deletion of the entire same-project folder;
- create files only under C:\Dynomax\Project-Setup\<Project>;
- register the project/actions, allocate or resume the SQL-backed session and install the workflow in the documented order;
- execute the installed workflow through Core\Invoke-DynomaxWorkflow.ps1 -WorkflowDirectory;
- allow the canonical runner to import the workflow and own result export;
- generate the complete Dynomax result ZIP;
- validate PASS and non-PASS ZIPs through the same manifest/hash contract;
- require Definitions and TestEvidence but require ProjectFindings only when generated;
- copy a valid non-PASS ZIP to the clipboard before returning its original non-zero exit code;
- validate every ZIP member and hash;
- save it under C:\Dynomax\Exports;
- copy it to the Windows clipboard as a file;
- close the browser, child processes and console on success;
- keep the console open and preserve a transcript on failure;
- not open Explorer.

First give a read-only confirmation of the project-neutral design and identify only concrete target details that cannot be safely discovered. Do not change Dynomax Core unless live evidence proves a generic framework defect.
```

## 27. Standard prompt for a new test

```text
Read DYNOMAX_AGENT_GUIDE.md and the latest files for this project completely.

Create the next Dynomax workflow package for the requested test. Reuse the current project action library and create only the missing versioned actions. Reuse or allocate the correct SQL-backed session according to recovery state. Include exact cleanup for every modifying action and certify the cleanup Robot block separately, including its own login, overlay and tenant/workspace prerequisites when it may run in a fresh browser. Use a versioned complete installer-state schema, migrate legacy state before mutation, and recover completion from an already validated matching PASS ZIP without rerunning or allocating another session when only bookkeeping failed.

Return one ZIP that I can extract anywhere and run through one BAT file. It must install the new project files, import the new versions, execute the workflow, create the complete result ZIP, copy it to my clipboard, close automatically on success and remain open with a transcript on failure.

Do not modify Dynomax Core unless returned evidence proves a generic framework defect.
```

## 28. Standard prompt for returned-result analysis

```text
Read the attached Dynomax result ZIP completely.

Validate its hashes and manifests, inspect every action result, Robot evidence, screenshots, context, assertions, events, cleanup and temporary-workspace proof.

Classify the first causal failure as PASS, FAIL, TEST_INVALID, BLOCKED, ERROR, STALE, SKIPPED or CLEANUP_FAILED.

Then:
1. state what was wrong;
2. state what must be fixed;
3. create the smallest corrected project workflow package if justified;
4. do not rerun already proven unrelated scope;
5. do not modify Dynomax Core unless the evidence proves a generic framework defect.
```

## 29. Final agent checklist

```text
[ ] I read this guide completely.
[ ] I kept Dynomax Core project-neutral.
[ ] I used the correct project folder.
[ ] I reused existing actions where possible.
[ ] I created only small independently meaningful actions.
[ ] I created immutable versions.
[ ] I registered exact cleanup.
[ ] I used one shared browser session where appropriate.
[ ] I used forward-slash Robot paths.
[ ] I excluded secret values.
[ ] Executable files are ASCII CRLF.
[ ] Windows PowerShell 5.1 parsed every PS1.
[ ] I ran the AST automatic-variable collision gate.
[ ] I did not use $matches or another case variant as ordinary storage.
[ ] Matches has no assignment, declaration, mutation, loop-variable or parameter use.
[ ] Every intentional $Matches read is documented and linked to regex capture logic.
[ ] I did not rely on parser success to detect automatic-variable collisions.
[ ] I inventoried every external Dynomax command in installers, helpers and workflow wrappers.
[ ] Every external command maps to one exact authoritative defining file.
[ ] I validated every mapped function's required parameters.
[ ] The complete defining-file dependency set is dot-sourced before invocation.
[ ] Runtime Get-Command checks pass in the same scope that calls each function.
[ ] I did not assume Common.ps1 contains Process, Database, Catalogue, Results or Workflow functions.
[ ] I load Core\Execution\Dynomax.Process.ps1 before Resolve-DynomaxCommand.
[ ] My Core contract object exposes every defining-file path required by its callers.
[ ] I preflight installed project helper files referenced by workflow wrappers.
[ ] A generic Core-contract PASS is not used as dependency-closure proof.
[ ] I did not misuse $LASTEXITCODE.
[ ] I streamed command progress and preserved logs.
[ ] Success closes automatically.
[ ] Failure keeps the console open.
[ ] I did not open Explorer.
[ ] I generated the complete result ZIP contract.
[ ] I validated ZIP entries, hashes and paths.
[ ] I copied the ZIP to the clipboard.
[ ] I separated static certification from live execution.
[ ] I will inspect the returned ZIP before issuing a correction.
[ ] I will change Core only when live evidence proves a generic framework defect.
[ ] I inspected the installed Core or an authoritative exact-version export.
[ ] I used the exact 1.0.8 integration contract from section 17.1.
[ ] I did not guess or wildcard-select Core commands.
[ ] I proved exact mandatory and optional parameter names.
[ ] I ran interface preflight before copying project files.
[ ] I did not consume a workflow session number during read-only validation.
[ ] I launched the workflow runner as a child process.
[ ] I let the workflow runner own complete result export.
[ ] I classified an invented or missing assumed entry point as TEST_INVALID.
[ ] I validated an existing destination through projectKey.
[ ] I stop without mutation for another project or ambiguous ownership.
[ ] My installer resumes or updates the same project safely.
[ ] PACKAGE_MANIFEST.json distinguishes managed files from unrelated files.
[ ] I preserve extra project-local files.
[ ] I back up changed managed files and verify backup hashes.
[ ] I install managed files atomically and verify final hashes.
[ ] I write INCOMPLETE.json before any mutation.
[ ] I retain incomplete state and backups on failure.
[ ] I write COMPLETE.json only after SQL import and live workflow PASS.
[ ] I reuse a valid recorded session during retry.
[ ] I do not recursively delete an existing same-project folder.
[ ] I rely on the installed hash-idempotent SQL import behaviour.
[ ] I resolve database configuration only from dynomax.json.paths.databaseConfig.
[ ] I pass databaseConfig.sql unchanged to Core.
[ ] I validate SQL with Open-DynomaxConnection after loading Database.ps1.
[ ] I did not infer SQL connectionString/server/database/username/password fields.
[ ] I dot-sourced Common, Database and Catalogue in canonical order.
[ ] I proved required Core functions are loaded at runtime with Get-Command.
[ ] Runtime load checks occur in the same scope as invocation.
[ ] I did not confuse AST source confirmation with command availability.
[ ] Shared Robot actions reuse the Dynomax browser/page.
[ ] Robot actions use Set/Get Dynomax Context Value.
[ ] PowerShell actions accept the exact five Core parameters.
[ ] PowerShell actions read context.values.
[ ] Every normal PowerShell action path writes valid OutputPath JSON.
[ ] Project findings are written under project-export.
[ ] action.json and implementation contracts agree.
[ ] I treat actionId as authoritative identity, not the folder name.
[ ] Package-source action IDs are unique.
[ ] Workflow action IDs resolve exactly once in package source.
[ ] I scanned the installed Project-Library separately.
[ ] I grouped installed definitions by actionId.
[ ] Every package action has one declared canonical destination path.
[ ] Reconciliation occurs after managed-file installation and before SQL import.
[ ] I backed up stale same-project duplicate folders intact.
[ ] I verified backup hashes before retiring stale folders.
[ ] I printed and recorded original, canonical and backup paths.
[ ] I did not alter another project's duplicate definition.
[ ] I rescanned the installed library from disk.
[ ] Every workflow-referenced actionId resolves exactly once.
[ ] Workflow execution is blocked while any actionId is ambiguous.
[ ] I reuse a compatible previously allocated session during retry.
[ ] I did not delete immutable SQL action-version history.
[ ] I identified every collection-returning installer helper.
[ ] I treat helper output as zero, one or many.
[ ] I normalize helper output at the caller with @(...).
[ ] Every .Count consumer receives a proven array.
[ ] Every indexed helper result receives a proven array.
[ ] Every collection used with += is normalized first.
[ ] I did not rely on function-internal return @($items).
[ ] Zero-result collection tests pass under StrictMode.
[ ] One-result collection tests pass under StrictMode.
[ ] Multiple-result collection tests pass under StrictMode.
[ ] Empty state and JSON persist [] where an array is required.
[ ] One-record state and JSON persist an array containing one object.
[ ] Plural collection variable names are used only after normalization.
[ ] I identified normal and cleanup Robot block boundaries.
[ ] I certified cleanup dependencies separately from normal dependencies.
[ ] Every authenticated cleanup block begins with certified login.
[ ] Cleanup settles cookie banners and blocking overlays where applicable.
[ ] Tenant-scoped cleanup re-establishes the exact workspace.
[ ] Protected cleanup navigation occurs only after authentication and workspace selection.
[ ] Cleanup context contains exact non-secret object names or GUIDs.
[ ] Cleanup does not assume normal-block cookies, pages, routes or transient state survived.
[ ] A second login during a fresh-browser cleanup is accepted.
[ ] Destructive cleanup actions remain atomic and reuse prerequisite actions.
[ ] I classify omitted cleanup prerequisites as causal TEST_INVALID even when the result is CLEANUP_FAILED.
[ ] PASS and non-PASS ZIPs use the same manifest/hash validation.
[ ] Definitions and TestEvidence are mandatory in every structurally complete result ZIP.
[ ] ProjectFindings is required only when the workflow generated findings.
[ ] A valid non-PASS ZIP is not rejected because ProjectFindings is absent.
[ ] I copy a valid non-PASS ZIP to the clipboard before returning failure.
[ ] I preserve the original non-zero exit code and incomplete state after ZIP validation.
[ ] Installer state has an explicit supported schemaVersion.
[ ] Initial INCOMPLETE.json declares every completion, failure and recovery field.
[ ] I normalize legacy JSON-derived state before mutation.
[ ] I do not assign undeclared properties directly to PSCustomObject state.
[ ] Migration preserves project key, workflow identity, session path and started time.
[ ] Migration preserves reconciliations, backup records and prior errors.
[ ] Completion, failure and recovery mutation tests pass under StrictMode.
[ ] A validated live PASS is not rerun because completion bookkeeping failed.
[ ] Completion recovery locates exactly one matching PASS ZIP.
[ ] The recovered ZIP matches time, project key, workflow ID, session and PASS status.
[ ] Every recovered ZIP entry, size and SHA-256 hash validates.
[ ] COMPLETE.json is written atomically and reread before INCOMPLETE.json is removed.
[ ] Completion recovery reuses the recorded session and consumes no new session number.
```


## 29.1 Revision 1.0.8-r10 change record

This guide revision retains the earlier interface, recovery, SQL, reusable-action, installed-catalogue, collection-cardinality, Core dependency-closure, cleanup and evidence contracts and adds the durable lesson from ATX foundation V1.0.2: installer state must use an explicit versioned schema, legacy JSON-derived state must be normalized before StrictMode mutation, and a validated live PASS must be completed through bookkeeping recovery without rerunning the workflow or allocating another session.

Changed sections:

```text
2. Non-negotiable boundaries
10. New project onboarding package
14. Static package certification
17.2 Safe repeatable project onboarding and recovery contract
19. Windows PowerShell 5.1 compatibility contract
22. Durable framework-development lessons
23. Full end-to-end workflow expected from an agent
24. Expanded static package certification
25. Framework completion baseline
26. Standard prompt for a new project
27. Standard prompt for a new test
29. Final agent checklist
```

The ATX onboarding interface, recovery, automatic-variable, SQL-configuration, Core-loading, installed-action-catalogue, collection-cardinality, command-dependency-closure, cleanup-prerequisite, non-PASS evidence-validation and post-PASS state-finalization failures require documentation and project-package corrections. No Dynomax Core or ATX application change is required.

## 30. Permanent file location

Store this file as:

```text
C:\Dynomax\DYNOMAX_AGENT_GUIDE.md
```

Update it only when a durable framework-wide rule, accepted capability or recurring failure lesson changes.
