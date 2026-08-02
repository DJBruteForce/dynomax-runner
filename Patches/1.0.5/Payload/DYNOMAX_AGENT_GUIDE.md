# Dynomax Agent Guide

**Framework:** Dynomax  
**Minimum guide version:** 1.0.5  
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
11. Browser, child processes and console execution must close automatically at the end of a normal run.
12. Result ZIPs must be validated, copied to the Windows clipboard as a file, and stored under `C:\Dynomax\Exports`.

## 3. Core layout

```text
C:\Dynomax
|-- Config-And-Setup
|-- Core
|-- Exports
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

1. `ActionResults.json` contains one complete result for every executed or skipped action, including cleanup actions, status, message, timing, version, hashes and declared output.
2. `ContextSnapshot.json` contains all persisted non-secret context and excludes secret values.
3. `WorkflowManifest.json` identifies the exact project, environment, workflow, ordered actions, cleanup flags and action implementation hashes.
4. `Definitions` contains snapshots of the project definition, workflow definition and every action folder used by the run.
5. `TestEvidence` contains the generated Robot suite, output.xml, log.html, report.html, streamed console log, action logs and screenshots relevant to the run.
6. `ArtifactManifest.json` maps SQL artifact IDs to filenames, SHA-256 values, sizes and compression.
7. `TemporaryWorkspaceCleanup.json` proves whether the temporary run directory was deleted after SQL ingestion and export staging.
8. `DynomaxExportManifest.json` inventories every exported file with a forward-slash ZIP path, size and SHA-256.
9. ZIP member names must use `/`, never Windows backslashes.
10. The ZIP must be built atomically, reopened, every entry read, and only then copied to the clipboard.
11. The package must not include secret values, credentials, tokens or target application database data unless a project-specific evidence contract explicitly and safely permits it.


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
3. Copy files only into the new project folder.
4. Import project, actions and workflows into Dynomax SQL.
5. Run an initial project-neutral or requested smoke workflow.
6. Generate and validate a result ZIP.
7. Copy the ZIP to the clipboard.
8. Close browser and console without `pause`.

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
3. Ask only for genuinely missing target information that cannot be discovered safely.
4. Obtain or inspect the newest project source when selectors and handlers depend on source.
5. Create `project.json` with no secrets.
6. Create the smallest useful first actions.
7. Create one initial workflow.
8. Produce a self-installing project ZIP.
9. Statically validate JSON, BAT encoding, PowerShell parsing where available, Robot dry-run, paths, package layout and secret absence.
10. Report static validation separately from live execution.
11. After the user returns a result ZIP, inspect the full result before creating a correction.
12. Update reusable actions or project contracts before issuing another workflow when the failure exposed a framework/test defect.

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
BAT files are ASCII or UTF-8 without BOM and use CRLF
PowerShell scripts use strict mode and terminating error handling
JSON files parse
projectKey/actionId/workflowId values agree
all action IDs resolve exactly once
all entry-point files exist
Robot resource paths are converted to forward slashes by Dynomax
no secrets are embedded
no stale package names remain
installer copies only declared destinations
workflow BAT has no pause
browser teardown exists
result ZIP clipboard copy is enabled
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


## 18. Framework completion baseline

Dynomax Core is considered complete only after the generic self-test and the project pipeline closeout both pass. The project pipeline closeout must prove reusable action composition, one shared browser block, PowerShell action execution, context transfer, SQL persistence, cleanup execution, complete self-contained export, standard ZIP paths, clipboard handoff and temporary-workspace deletion.
