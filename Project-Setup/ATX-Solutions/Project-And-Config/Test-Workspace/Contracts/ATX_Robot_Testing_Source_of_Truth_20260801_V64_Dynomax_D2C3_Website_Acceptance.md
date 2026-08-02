# ATX Robot Testing Source of Truth V64 - Dynomax D2-C3 Website Acceptance

## Scope

This contract verifies the deployed website behavior after Phase 25H-D2-C final-import and preview-usage implementation. It is browser-only and must not query the ATX database.

The workflow covers:

1. Payment Evidence: create one disposable profile, preview the same file twice under one operation, import one exact batch, verify the batch, and delete both batch and profile.
2. Guided Banking: use `ATX UI TEST BANK` and a dynamically discovered non-protected Published user Structured CSV profile, complete preview through final import, capture the exact batch, and undo it.
3. Manager Data Management: use `/Manager/DataManagement/Import`, preview, go Back, preview again, prove the hidden operation and artifact IDs remain unchanged, import one exact batch, and undo it.
4. Fresh-browser cleanup: independently re-establish login/workspace and remove only exact IDs carried in Dynomax context.

## Protected state

Never modify or select as the structured acceptance profile:

- `ABSA bank statement`
- `Phase 25J TEST A1`
- `Phase 25J OCR IMAGE TEST`
- the protected 77-row production baseline

If no suitable non-protected Published user Structured CSV profile exists, classify the workflow as `BLOCKED`. Do not create and publish a disposable profile because Published profile versions are immutable and would leave permanent test state.

## Usage boundary

Browser evidence proves the visible preview-to-import flows, stable operation transport, exact final result, retry/back behavior, and cleanup. Source/unit/relational tests prove the internal `BankingUsageEvents` rows and manager attribution. Robot must never query SQL.

## Expected outcomes

- Payment Evidence duplicate submission explicitly replays the same original non-empty `PreviewOperationId`; the page may rotate the next-operation token after each completed response.
- Guided import completes one disposable structured CSV batch and exact undo.
- Manager Data Management Back/Preview retains one non-empty `ImportOperationId` and `ImportSourceArtifactId`.
- Final imports complete with no visible errors.
- All exact batches are deleted or reversed; the disposable Payment Evidence profile is absent; no Guided session remains.
- Credentials are entered only through `Fill Secret`.

## Classification

- `PASS`: all three website paths and cleanup pass.
- `FAIL`: ATX violates a current source-certified website contract.
- `TEST_INVALID`: selector, prerequisite chain, cardinality, or expectation is stale/incorrect.
- `BLOCKED`: required account, safe Published Structured profile, permission, or environment prerequisite is unavailable.
- `ERROR`: Dynomax, Robot, Browser, PowerShell, SQL-framework, or result packaging fails.
