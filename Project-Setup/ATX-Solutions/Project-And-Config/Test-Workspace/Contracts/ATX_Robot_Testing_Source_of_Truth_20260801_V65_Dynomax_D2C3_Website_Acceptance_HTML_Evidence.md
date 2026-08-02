# ATX Robot Testing Source of Truth V65 - Dynomax D2-C3 Website Acceptance with HTML Evidence

## Superseded contract

V64 is retired. Its shared Structured-profile fixture step ran before Payment Evidence, so a missing Structured profile incorrectly skipped a scenario that did not depend on that profile. V64 also allowed filtered profile results to be described as total workspace inventory without captured page HTML.

## Scope

This contract verifies the deployed website behavior after Phase 25H-D2-C final-import and preview-usage implementation. It is browser-only and must not query the ATX database.

The workflow covers:

1. Payment Evidence first and independently: create one disposable profile, preview the same file twice under one operation, import one exact batch, verify the batch, and delete both batch and profile.
2. Structured prerequisite discovery after Payment Evidence: capture the unfiltered User Profiles page, then capture the Structured source plus Published / available filtered page.
3. Guided Banking: use `ATX UI TEST BANK` and a dynamically discovered non-protected Published user Structured CSV profile, complete preview through final import, capture the exact batch, and undo it.
4. Manager Data Management: use `/Manager/DataManagement/Import`, preview, go Back, preview again, prove the hidden operation and artifact IDs remain unchanged, import one exact batch, and undo it.
5. Fresh-browser cleanup: independently re-establish login/workspace and remove only exact IDs carried in Dynomax context.

## Mandatory HTML evidence

Every distinct page URL and every major wizard/form state used for a factual assertion must be captured after the expected page state becomes visible.

Each capture must produce:

- a sanitized dynamic DOM HTML file under `TestEvidence/Robot/PageHtml/`;
- a JSON metadata sidecar containing URL, title, active workspace, visible headings and alerts, selected profile filters, profile-tab counts, and profile-card facts when present;
- one append-only `PageEvidenceIndex.json` listing every HTML and metadata file with size and SHA-256.

Sanitization must remove scripts, styles, frames and inline event handlers; redact password, anti-forgery, authorization, token and secret fields; remove file-input values; and retain non-secret operation/artifact IDs needed for acceptance evidence.

HTML capture is evidence only. It must never change application state and must never query the ATX database.

## Profile discovery truth rules

- First capture `/Banking/Profiles?tab=user` without Purpose or Status filters and record its User Profiles and System Profiles totals.
- Then capture `/Banking/Profiles?tab=user&Purpose=StructuredTransactionSource&Status=active` and record the matching card count.
- A zero result on the filtered page means zero matching Structured Published/available profiles. It must never be reported as zero total profiles in the workspace.
- A blocker message must include the active workspace, unfiltered user/system totals, selected filter meaning and matching count.

## Protected state

Never modify or select as the structured acceptance profile:

- `ABSA bank statement`
- `Phase 25J TEST A1`
- `Phase 25J OCR IMAGE TEST`
- the protected 77-row production baseline

If no suitable non-protected Published user Structured CSV profile exists, classify the Structured-dependent continuation as `BLOCKED`. Do not create and publish a disposable profile because Published profile versions are immutable and would leave permanent test state.

## Scenario dependency boundary

Payment Evidence has no Structured-profile dependency and must execute before Structured-profile discovery. A missing Structured profile may block Guided Banking and Manager Data Management, but it must not prevent Payment Evidence from running.

## Usage boundary

Browser evidence proves the visible preview-to-import flows, stable operation transport, exact final result, retry/back behavior, and cleanup. Source/unit/relational tests prove the internal `BankingUsageEvents` rows and manager attribution. Robot must never query SQL.

## Expected outcomes

- Payment Evidence duplicate submission explicitly replays the same original non-empty `PreviewOperationId`.
- Guided import completes one disposable structured CSV batch and exact undo when its prerequisite exists.
- Manager Data Management Back/Preview retains one non-empty `ImportOperationId` and `ImportSourceArtifactId` when its prerequisite exists.
- Final imports complete with no visible errors.
- All exact batches are deleted or reversed; the disposable Payment Evidence profile is absent; no Guided session remains.
- Credentials are entered only through `Fill Secret`.
- Returned evidence contains the complete page HTML index and all declared capture files.

## Classification

- `PASS`: all three website paths and cleanup pass.
- `FAIL`: ATX violates a current source-certified website contract.
- `TEST_INVALID`: selector, dependency chain, cardinality, page interpretation or expectation is stale/incorrect.
- `BLOCKED`: a required account, safe Published Structured profile, permission or environment prerequisite is unavailable after all independent runnable scenarios have executed.
- `ERROR`: Dynomax, Robot, Browser, PowerShell, SQL-framework or result packaging fails.
