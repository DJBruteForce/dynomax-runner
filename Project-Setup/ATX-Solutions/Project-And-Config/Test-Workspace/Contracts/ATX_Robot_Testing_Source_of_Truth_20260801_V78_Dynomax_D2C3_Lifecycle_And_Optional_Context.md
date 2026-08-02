# ATX Robot Testing Source of Truth V78

## Phase 25H-D2-C3 final package-certification and exact-cleanup contract

### Authority

This contract supersedes V73 for the D2-C3 website-acceptance package. It retains the accepted Payment Evidence, reusable Structured profile, exact-version acknowledgement and HTML-evidence contracts, and adds the final package, selector, scenario-independence, BatchDetail and cleanup rules proven necessary by the V1.0.6 audit.

### Approved permanent test profile

- Workspace: `CIPC Example Holdings`
- Owner: authenticated test manager and selected tenant
- Exact name: `Dynomax D2C3 Structured TEST`
- Purpose: Structured transaction source
- Source format: CSV
- Lifecycle: Published exact tested version
- Persistence: intentional and approved; normal cleanup must preserve it

### Package namespaces

`PACKAGE_MANIFEST.json` must contain one `packageLayout` object with:

```json
{
  "packageRootRequiredFiles": [],
  "payloadRequiredFiles": [],
  "installedRequiredFiles": [],
  "rootToInstallCopies": []
}
```

The builder and installer must consume that same object. Every installed requirement must have exactly one declared producer. The final ZIP must be extracted into a new folder and the copy graph repeated against those final bytes.

### Generated Python artifact prohibition

The package root, Payload tree, simulated install and installed ATX Dynomax project tree must contain no:

```text
__pycache__
*.pyc
*.pyo
```

Python source checks run outside the package tree. The installer sets `PYTHONDONTWRITEBYTECODE=1`, uses Python `-B` for direct validation/dry-run processes, removes generated artifacts left by older D2-C3 packages, and rescans before Chromium.

### Credential contract

```robot
Fill Text      css=#Email       %{ATX_TEST_USERNAME}
Fill Secret    css=#Password    %ATX_TEST_PASSWORD
```

Literal credentials and `Fill Secret` for the username are prohibited.

### Payment Evidence contract

- Run before Structured-profile preparation.
- Use `form[action*="handler=UploadPreview"] select[name="PreviewProfileId"]:visible` for all three profile interactions.
- Preserve one stable preview operation through repeated preview and final import.
- Delete the exact batch and then navigate directly to `/Banking/PaymentEvidence/Batch?id=<GUID>`.
- Prove zero `#paymentEvidenceBatchWorkspace`, exactly one `#pane-sub-import .alert-danger:visible`, and message `Payment evidence batch not found`.
- Delete and prove absence of the exact disposable profile.

### Guided native profile-selection contract

The native `#guidedProfile` control is authoritative:

1. Read its rendered option text.
2. Require the exact reusable profile label.
3. Select by exact label.
4. Read the selected option's own value.
5. Verify selected text equals the exact profile name.
6. Verify `data-profile-scope=user`.

XPath/cardinality checks against `#guidedProfile option` and cross-page route-GUID inference are prohibited.

### BatchDetail import-outcome contract

For both Guided Banking and Manager Data Management, read `OnGetBatchDetailAsync` through the exact history-row trigger and verify together:

```text
fileName = exact runtime fixture
importedRows = 3
transactionCount = 3
processedRowCount = 3
duplicateRows = 0
skippedRows = 0
errorCount = 0
status = derived from warningCount/errorCount/importedRows
```

Status derivation:

```text
errors > 0 and importedRows = 0 -> Failed
warnings > 0 or errors > 0     -> Partial
otherwise                       -> Completed
```

A warning-bearing successful import must not be rejected merely because it is `Partial`.

### Exact Undo contract

1. Read exact BatchDetail before Undo.
2. If already `Reversed`, prove `transactionCount=0` and `canUndo=false`.
3. Otherwise require `canUndo=true` and submit the exact batch-ID Undo form.
4. Accept the source-confirmed redirect to the default Guided tab.
5. Explicitly navigate back to `activeTab=history`.
6. Re-resolve the exact history row and BatchDetail trigger.
7. Prove `status=Reversed`, `transactionCount=0`, and `canUndo=false`.

A missing history row is unresolved cleanup state and must never return success silently.

### Scenario independence

- `stopOnFunctionalFailure=false`.
- Payment Evidence, fixture preparation, Guided Banking and Manager Data Management each report their own result.
- Guided and Manager validate their own fixture context and return `BLOCKED` when the shared approved prerequisite was not prepared.
- A Guided failure must not prevent Manager Data Management evidence collection.
- Cleanup remains a separate fresh-browser block.

### Cleanup truthfulness

- Context flags are set only after exact website proof succeeds.
- No-op cleanup does not claim object deletion, Undo execution or session abandonment. Separate `Absent`/`ReversedVerified` flags record already-clean state.
- Exact Payment Evidence batch/profile, Guided batch/session and Manager batch are cleaned when recorded.
- The approved reusable Published profile remains exactly one profile with the recorded ID.

### Website-only boundary and Dynomax control-database exception

Functional acceptance evidence is website-only. The executable package must not connect to, query, or read configuration for the ATX application database.

The Dynomax framework may use its own **Dynomax control database** solely for project catalogue, workflow-session allocation, orchestration and durable runner state. This exception does not permit target-application assertions, ATX table queries, ATX connection strings, `appsettings.json` database lookup, or reading `BankingUsageEvents`/application artifacts from SQL.

### Result classification

- Certified application mismatch: `FAIL`
- Package, selector, schema or expectation defect: `TEST_INVALID`
- Missing safe prerequisite: `BLOCKED`
- Runner/environment failure: `ERROR`
- Exact cleanup failure: `CLEANUP_FAILED`

The BAT/installer must preserve the result ZIP classification.

### Final certification

Before delivery and again at installation:

- JSON parses;
- PowerShell parser passes;
- executable bytes are ASCII CRLF with no BOM/bare LF;
- Robot action blocks dry-run from packaged and installed copies;
- no duplicate Robot keywords/sections;
- no generated Python artifacts;
- native Guided profile selector contract is present and option XPath absent;
- exact BatchDetail and post-Undo checks are present;
- Payment Evidence batch absence proof is present;
- package layout and one-producer copy graph pass;
- final extracted bytes match manifest hashes.
## Windows PowerShell interpolated-variable delimiter rule

Before delivery, scan every `.ps1` file for an unbraced variable immediately followed by a colon. In an expandable string, `$Name:` is parsed as a scoped/drive-style variable reference and can prevent the entire installer from parsing.

Required form:

```powershell
"Validation failed for ${Name}: $Path"
```

Prohibited form:

```powershell
"Validation failed for $Name: $Path"
```

The top-level BAT launcher must run the actual target Windows PowerShell parser across every packaged `.ps1` file before executing the installer. Any parser error is `TEST_INVALID` and must stop before installation, credentials, Robot or Chromium.



## Normalized Robot keyword certification

Before delivery, installation and Chromium, scan every packaged and installed `.robot` and `.resource` file.

Within each `*** Keywords ***` section:

- an unindented non-comment line is a keyword header;
- a valid keyword header contains exactly one Robot cell;
- argument rows and keyword-body calls must remain indented;
- normalize names case-insensitively with spaces and underscores treated as equivalent;
- require the keyword-header count to equal the unique normalized-name count;
- reject duplicate normalized names and top-level lines containing unintended argument cells.

Required result:

```text
keyword headers = unique normalized keyword names
duplicate normalized keyword names = 0
malformed top-level keyword calls = 0
```

Run this certification against the extracted package tree, the simulated installed tree, the actual installed action/common-resource set and a fresh extraction of the exact final ZIP. A mismatch is `TEST_INVALID` and must stop before Robot dry-run or Chromium.


## Dynomax 1.0.9 exact action-version pinning

Dynomax Core 1.0.9 introduced exact action-version metadata in generated Robot workflows. A live unversioned D2-C3 workflow proved that the backward-compatible null path is unsafe because Core generated:

```robot
Set Test Variable    ${DYNOMAX_REQUESTED_ACTION_VERSION}
```

with no value. Robot attempted to resolve the undefined variable before the keyword could create it, so every normal and cleanup action failed before login.

For this workflow, every step must declare an explicit positive integer `actionVersion`. The exact certified map is:

```text
10  atx.auth.login                                      v3
20  atx.ui.settle-overlays                              v1
30  atx.workspace.select                                v1
40  atx.banking.d2c3.payment-evidence-acceptance        v5
50  atx.banking.d2c3.prepare-import-fixtures            v6
60  atx.banking.d2c3.guided-banking-acceptance          v4
70  atx.banking.d2c3.manager-data-management-acceptance v4
200 atx.banking.d2c3.cleanup                            v9
```

`atx.auth.login` becomes v3 because the canonical username input changed from `Fill Secret` to `Fill Text`; its action definition must therefore change together with its implementation so Dynomax creates a new immutable version.

Before installation and again after installation:

- require exactly 8 workflow steps;
- require every step to contain `actionVersion`;
- require the exact order/action/version map above;
- reject null, blank, zero or unexpected versions;
- require Dynomax Core 1.0.9 or newer;
- allow the Core exact-version preflight to verify catalogue hashes before Chromium.

A generated workflow containing an empty requested-action-version assignment is `TEST_INVALID`. The live result classification must not be reported as an ATX application or cleanup failure when no browser action ran.


## Dynomax 1.0.9 independent-cleanup wrapper contract

Live V1.0.10 and V1.0.11 results proved that Dynomax Core 1.0.9 validates cleanup block ownership using descending order but generated and executed the cleanup Robot tests in ascending order. A multi-step cleanup block therefore cannot safely satisfy both paths.

D2-C3 must use one cleanup workflow step:

```text
200 atx.banking.d2c3.cleanup v9
```

The cleanup action must declare:

```text
sessionBehavior = RequiresNewBrowser
keyword = ATX Run Independent D2C3 Cleanup Block
```

That single action internally performs:

```text
login -> settle overlays -> select workspace -> exact cleanup -> logout
```

`TRY/FINALLY` must guarantee logout after any cleanup failure occurring after authentication.

Mandatory validation before workflow import:

- require exactly one `cleanup=true` workflow step;
- require action ID `atx.banking.d2c3.cleanup`;
- require exact action version v7;
- require `sessionBehavior=RequiresNewBrowser`;
- require the wrapper to invoke login, overlays, workspace selection, exact cleanup and logout in that order;
- reject separate cleanup login, workspace or logout workflow steps.

This wrapper is a package workaround for the Dynomax Core 1.0.9 validation/execution ordering inconsistency. It does not change ATX application behavior.

## Published lifecycle verification contract

After exact-version acknowledgement and Publish submission, publication is proven from the rendered lifecycle page:

```text
Version history -> at least one visible Published badge
visible exact-version Publish forms -> 0
```

The obsolete `.sp-hero span.badge.bg-success` selector is prohibited because the live page can be successfully Published without rendering that badge at that location.



## V76 supported independent-cleanup session contract

Dynomax 1.0.9 accepts these Robot browser session values:

```text
RequiresNewBrowser
RequiresExistingBrowser
RequiresNewOrExistingBrowser
DoesNotUseBrowser
```

The D2-C3 cleanup action is one independent cleanup block and therefore declares:

```text
sessionBehavior = RequiresNewBrowser
```

The action does not create an invented session mode. Dynomax owns the new browser block, while the cleanup keyword performs the application sequence:

```text
login -> settle overlays -> select workspace -> exact cleanup -> logout
```

`StartsNewBrowser` is prohibited because it is not supported by Dynomax 1.0.9. The installer must reject it before workflow import.

## V77 immutable cleanup action-version correction

The V1.0.13 runtime preflight correctly rejected cleanup action v7 as `STALE`.

The v7 catalogue record retained the earlier action-definition hash, while the package changed only
`action.json` from the unsupported session behavior to the supported `RequiresNewBrowser` value.
Although the implementation bytes were unchanged, Dynomax action versions are immutable across both
definition and implementation hashes. Changing action metadata while continuing to request v7 is invalid.

Permanent contract:

```text
cleanup action ID          atx.banking.d2c3.cleanup
new immutable version      v8
sessionBehavior            RequiresNewBrowser
workflow cleanup pin       v8
v7                         retained as historical and never rewritten
```

The installer must reject any workflow that requests cleanup v7 or any unversioned cleanup action.
The workflow may resume the existing D2-C3 session because the previous workflow hash is explicitly
listed as compatible, but exact action resolution must use cleanup v8.


## V78 lifecycle-page and optional-context corrections

Live V1.0.15 evidence established two package defects after Payment Evidence passed:

1. The reusable Structured profile was already canonical and Published. The test navigated to
   `/Banking/Profiles/Lifecycle` and waited for `.sp-shell`. `Lifecycle.cshtml` uses a
   `container-fluid` root and does not render `.sp-shell`. Reuse must wait on the rendered
   Published lifecycle contract: the Version history table contains `Published`, and no visible
   Publish form remains.
2. `Get Dynomax Context Value` can return a successful result whose value is Python `None` when an
   optional key has not been created. Optional-context readers must normalize `None`, `null`, and
   blank text to `${EMPTY}`. Cleanup must not invoke Guided, Manager, or session cleanup paths unless
   their exact IDs are non-empty.

The corrected immutable action pins are:

```text
50  atx.banking.d2c3.prepare-import-fixtures v6
200 atx.banking.d2c3.cleanup                 v9
```

This correction is test-package only. It does not change ATX application behavior, SQL, ownership,
or production data. The V1.0.15 Payment Evidence batch and disposable profile were already proven
absent through the website; Guided and Manager imports were skipped and created no batch IDs.
