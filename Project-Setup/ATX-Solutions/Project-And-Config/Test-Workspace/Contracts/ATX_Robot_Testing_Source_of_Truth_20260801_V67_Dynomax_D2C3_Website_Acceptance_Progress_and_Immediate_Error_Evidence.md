# ATX Robot Testing Source of Truth V67 - Dynomax D2-C3 Progress and Immediate Error Evidence

## Superseded contract

V66 is retired. V66 fixed HTML evidence transport and scenario ordering, but its Payment Evidence action waited only for the success card after form submission. Live run `028d0096-9cd6-451d-abe2-ab5d68019ea6` returned a visible ATX error caused by SQL 51074, while the test continued waiting for a success selector and reported a 30-second timeout. The result evidence still exposed the application defect, but the action did not report it directly.

V65, V64 and earlier contracts remain retired for the reasons already recorded in their successor contracts.

## Scope

This contract verifies the deployed website behavior after the Phase 25H-D2-C Payment Evidence usage-ownership repair. It remains browser-only and must never query the ATX database.

The workflow covers:

1. Payment Evidence: create one disposable profile, preview the same file twice under one operation, import one exact batch, verify it, and delete both batch and profile.
2. Structured prerequisite discovery: capture unfiltered and filtered profile evidence accurately.
3. Guided Banking: complete one disposable structured import and exact undo.
4. Manager Data Management: preview, go Back, preview again, preserve operation/artifact identity, import and exact undo.
5. Fresh-browser cleanup: independently restore login/workspace and remove only exact context-owned test data.

## Mandatory progress reporting

- Every meaningful scenario checkpoint must write a visible console line in the form `[D2-C3 progress current/total] STATUS - description`.
- Progress must identify the scenario and the state just reached; it must not predict a PASS before the assertion has completed.
- The action's normal Robot PASS/FAIL remains authoritative. Progress lines are additional operator visibility, not a replacement for evidence or assertions.

## Immediate post-submit result classification

After each Payment Evidence preview submission, the action must poll for either:

- exactly one visible preview result card; or
- exactly one visible `[data-payment-evidence-error]` block.

When the error block appears:

1. capture sanitized dynamic HTML and metadata immediately;
2. read `[data-payment-evidence-error-message]`;
3. fail the action with the visible ATX message, including any support reference;
4. do not continue waiting for a success-only selector.

When neither state appears before the bounded wait, capture the page and classify `TEST_INVALID` because the page contract is no longer recognized. Multiple success or error states are also `TEST_INVALID`.

## HTML evidence

Every distinct URL and major form/wizard state used for an assertion must produce sanitized DOM HTML, JSON metadata and an append-only evidence index. Sanitization and Robot-to-Browser JavaScript transport rules from V66 remain mandatory.

## Profile-discovery truth rules

Unfiltered total profile counts and filtered matching profile counts must remain separate. A filtered zero must never be described as zero total profiles.

## Protected state

Never modify or use these as disposable structured test profiles:

- `ABSA bank statement`
- `Phase 25J TEST A1`
- `Phase 25J OCR IMAGE TEST`
- the protected 77-row production baseline

## Usage boundary

Browser evidence proves visible preview-to-import behavior, operation transport, exact outcomes and cleanup. Source/unit/relational tests and the repaired SQL trigger prove internal manager attribution. Robot must not query SQL.

## Expected outcomes

- Payment Evidence preview no longer returns SQL 51074 after the approved trigger repair.
- Duplicate preview replays the exact original non-empty operation ID.
- Guided and Manager imports complete and their exact disposable batches are reversed.
- Manager Back/Preview retains the same non-empty operation and artifact IDs.
- Cleanup removes the disposable Payment Evidence profile and batch and abandons only the exact guided session when necessary.
- Page HTML and progress evidence are present in the result package.

## Classification

- `PASS`: all website paths and cleanup pass.
- `FAIL`: ATX visibly violates the current source-certified contract.
- `TEST_INVALID`: selectors, cardinality, dependency interpretation, JavaScript transport or recognized success/error states are stale or incorrect.
- `BLOCKED`: a required safe prerequisite is absent after independent runnable work has completed.
- `ERROR`: Dynomax, Robot, Browser, PowerShell, packaging or result-export infrastructure fails.
