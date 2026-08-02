# ATX Robot Testing Source of Truth V68 - Dynomax D2-C3 Form-Scoped Payment Evidence Profile Selector

## Superseded contract

V67 is retired. V67 correctly added progress reporting and immediate Payment Evidence error evidence, and live run `ca3e5628-801e-4c5a-bb78-c1edffb6b005` proved the SQL 51074 ownership repair by reaching a recognized successful first preview. The run then became `TEST_INVALID` because the action reused `css=#PreviewProfileId` after preview.

The returned page contains two elements with `id="PreviewProfileId"`:

1. the visible profile `<select>` in the Upload Preview form; and
2. the hidden profile `<input>` in the Execute Import form.

Browser strict mode therefore rejected the broad ID selector before the repeated preview could be submitted. V67, V66 and earlier contracts remain retired for the reasons recorded in their successor contracts.

## Confirmed live evidence

Run `ca3e5628-801e-4c5a-bb78-c1edffb6b005` confirmed:

- login, overlay handling and `CIPC Example Holdings` workspace selection passed;
- the disposable Payment Evidence profile was created and resolved by exact ID;
- the first preview succeeded with five classified rows and one duplicate warning;
- the original non-empty preview operation ID was present;
- the failure occurred only when the broad selector resolved to both the visible select and hidden input;
- fresh-browser cleanup removed the exact disposable profile and logout passed.

The SQL repair is therefore no longer the blocker. The immediate failure is a stale test selector. The duplicate HTML ID is also an ATX markup defect, but it does not prevent safe browser acceptance when the selector is scoped to the correct form and element type.

## Mandatory selector contract

Every Payment Evidence upload/retry interaction must target exactly:

```text
css=form[action*="handler=UploadPreview"] select[name="PreviewProfileId"]:visible
```

The action must not use:

```text
css=#PreviewProfileId
```

for upload-preview profile selection.

The exact selector must be used for:

1. the initial visibility wait;
2. the first profile selection; and
3. the repeated-preview profile selection.

Package and installed-resource preflight must assert exactly three occurrences of the form-scoped selector and zero occurrences of the broad selector.

## Cleanup context reconciliation

Fresh-browser cleanup must update the persisted context after the exact delete helpers prove the Payment Evidence batch and profile are absent. It must set:

```text
d2c3PaymentEvidenceBatchDeleted = true
d2c3PaymentEvidenceProfileDeleted = true
```

This keeps structured context consistent with the captured cleanup HTML and prevents a successful cleanup from leaving stale `false` flags.

## Scope

The browser-only workflow continues to verify:

1. Payment Evidence: create one disposable profile, preview the same file twice under one operation, import one exact batch, verify it, and delete both batch and profile.
2. Structured prerequisite discovery: capture unfiltered and filtered profile evidence accurately.
3. Guided Banking: complete one disposable structured import and exact undo.
4. Manager Data Management: preview, go Back, preview again, preserve operation/artifact identity, import and exact undo.
5. Fresh-browser cleanup: independently restore login/workspace and remove only exact context-owned test data.

## Progress and evidence rules

- Every meaningful checkpoint must emit `[D2-C3 progress current/total] STATUS - description`.
- Every distinct URL and major form/wizard state used for an assertion must produce sanitized dynamic HTML, JSON metadata and an append-only evidence index.
- After each Payment Evidence preview submission, the action must classify exactly one success card or exactly one visible `[data-payment-evidence-error]` block.
- Unknown or ambiguous result states are `TEST_INVALID`.
- Unfiltered total profile counts and filtered matching counts must remain separate.

## Protected state

Never modify or use these as disposable structured test profiles:

- `ABSA bank statement`
- `Phase 25J TEST A1`
- `Phase 25J OCR IMAGE TEST`
- the protected 77-row production baseline

## Usage boundary

Browser evidence proves visible preview-to-import behavior, operation transport, exact outcomes and cleanup. Source/unit/relational tests and the repaired SQL trigger prove internal manager attribution. Robot must not query SQL.

## Classification

- `PASS`: all website paths and cleanup pass.
- `FAIL`: ATX visibly violates the current source-certified contract.
- `TEST_INVALID`: selectors, cardinality, dependency interpretation, JavaScript transport or recognized success/error states are stale or incorrect.
- `BLOCKED`: a required safe prerequisite is absent after independent runnable work has completed.
- `ERROR`: Dynomax, Robot, Browser, PowerShell, packaging or result-export infrastructure fails.
