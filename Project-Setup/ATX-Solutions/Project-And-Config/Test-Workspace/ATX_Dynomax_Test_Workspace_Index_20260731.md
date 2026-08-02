# ATX Dynomax Test Workspace Index

**Generated:** 2026-07-31 14:55 SAST  
**Project:** ATX Solutions  
**Project key:** `atx-solutions`  
**Dynomax:** 1.0.8  
**Current active phase:** Phase 25H-D2-B acceptance migration

## Governing decision

The legacy standalone Robot V1.1 package will not be rebuilt. Historical Robot evidence and V52 contracts are migration inputs. New execution occurs through the installed Dynomax project library and SQL-backed workflow sessions.

## Authority

1. Current user instruction.
2. `Project Context File(15).zip` and `schema(7).zip`.
3. `ATX_Robot_Testing_Source_of_Truth_20260731_V55_Dynomax_Credential_Redaction.md`.
4. `ATX_Agent_Context_Index_20260731(1).md`.
5. Historical Robot suites and results.

## Current phase position

| Scope | Status |
|---|---|
| Phase 25J | Complete and closed |
| Phase 25H-D0 | Complete |
| Phase 25H-D1-A | Complete |
| Phase 25H-D2-A | Complete and accepted |
| Phase 25H-D2-B code | Implemented |
| Phase 25H-D2-B acceptance | Pending valid Dynomax execution |
| D2-C and D3-D6 | Outstanding |
| Phase 25I | Pending |
| Phase 26 | Blocked |

## Registry inventory

The machine-readable registry contains 228 unique indexed items across core, source-certified, historical semantic and composite-scenario layers. It preserves dependency chains where the supplied library declared them.

Registry files:

- `ATX_Dynomax_Action_Migration_Registry_20260731.json`
- `ATX_Dynomax_Action_Migration_Registry_20260731.csv`

## Foundation workflow

**Workflow ID:** `atx.foundation.authenticated-workspace-draft`  
**Expected SQL-backed session:** `000002-Authenticated-Workspace-Draft-Foundation`

Ordered reusable actions:

1. `atx.auth.login`
2. `atx.ui.settle-overlays`
3. `atx.workspace.select`
4. `atx.banking.profiles.recover-stale-foundation-drafts`
5. `atx.banking.profiles.open-user-catalogue`
6. `atx.banking.profiles.create-statement-draft`
7. `atx.banking.statement.verify-exact-draft`
8. `atx.auth.login` — cleanup block prerequisite
9. `atx.ui.settle-overlays` — cleanup block prerequisite
10. `atx.workspace.select` — cleanup block prerequisite
11. `atx.banking.profiles.delete-exact-draft` — cleanup
12. `atx.auth.logout` — cleanup

Acceptance proves:

- runtime-secret login with username and password values redacted from Robot evidence;
- exact Manager profile resolution when required;
- exact workspace selection;
- exact generated Draft name and GUID transport;
- corrected desktop lifecycle-badge selector;
- exact Draft deletion;
- truthful cleanup context;
- protected production profiles untouched.

## Context/state keys

```text
authenticated
authenticatedRole
authenticatedUrl
targetWorkspace
workspaceBefore
workspaceSelected
profilesCatalogueOpen
statementProfileName
statementProfileId
statementProfileUrl
statementProfileCreationAttempted
statementProfileCreated
statementProfileState
statementDraftVerified
staleFoundationDraftsFound
staleFoundationDraftsDeleted
staleFoundationDraftIds
staleFoundationCleanupOutcome
statementProfileDeleted
deletedProfileId
cleanupOutcome
loggedOut
```

Secret values are never stored in context.

## Next gate

Do not build or run the complete D2-B processing workflow until this foundation result ZIP is returned and audited as PASS. After PASS, create the next SQL-backed workflow session and port `SCN-D2B-001` without rerunning unrelated closed Phase 25J scope.

## SQL

**NO SQL SCRIPT IS REQUIRED.**


## Cleanup-session correction

Dynomax executes cleanup Robot actions in a separate browser block. A second login during cleanup is expected and required. Session `000002` is reused for the corrected workflow package. The package first removes only exact Draft-only cards with the package-owned `Dynomax TEST Statement Draft ` prefix, then creates and cleans the new exact Draft.

- V60 adds the approved component-responsive Test Lab layout contract and JSON-safe Browser JavaScript argument handling.

- V61 replaces dynamic JavaScript metric lookup with exact rendered-DOM selectors for Test Lab counters, Pages processed and extraction mode.

- V62 removes Robot/JavaScript template interpolation from image-dimension checks and adds a package/runtime gate that rejects `${...}` template syntax inside `Evaluate JavaScript` Robot arguments.

- V63 preserves the exact active Statement page between D2-B actions so Prepare Preview sample state survives into OCR, Remap and recovery; it adds browser-observable sample continuity preconditions.
