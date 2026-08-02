# ATX Robot Testing Source of Truth V69

## Phase 25H-D2-C3 reusable Structured profile acceptance

### Authority

This contract supersedes V68 for the D2-C3 website-acceptance workflow. It preserves the accepted Payment Evidence selector correction and adds the user-approved reusable Published Structured profile required by Guided Banking and Manager Data Management acceptance.

### Approved permanent test profile

- Workspace: `CIPC Example Holdings`
- Owner: the authenticated ATX test manager and its selected tenant
- Exact name: `Dynomax D2C3 Structured TEST`
- Purpose: Structured transaction source
- Source format: CSV
- Lifecycle: Published exact tested version
- Persistence: intentional and approved; do not delete or archive during normal cleanup

### Canonical mapping

| Field | Value |
|---|---|
| Delimiter | comma |
| Date format | `yyyy-MM-dd` |
| Header | yes |
| Date column | 0 |
| Description column | 1 |
| Reference column | 2 |
| Debit column | 3 |
| Credit column | 4 |
| Balance column | 5 |
| Amount layout | Separate columns |
| Duplicate action | Skip |
| Missing reference | Warn |
| Missing description | Error |
| Zero amount | Warn |

### Creation and recovery contract

1. Open the unfiltered User Profiles page and capture sanitized HTML.
2. Resolve the exact reusable profile name to zero or one card. More than one is `TEST_INVALID`.
3. When absent, create the profile through `/Banking/Profiles/Structured`.
4. When present and already canonical Published CSV, reuse it without modification.
5. When present but incomplete, Draft, Tested or incompatible, update only that exact dedicated test profile to the canonical mapping.
6. Generate a representative CSV, run **Save Draft & Record Test**, and require the Lifecycle page.
7. Publish the exact tested version through the Lifecycle Publish form.
8. Record the exact profile and version identifiers in Dynomax context.
9. Create separate disposable Guided and Manager CSV files from the same canonical mapping.
10. Never modify `ABSA bank statement`, `Phase 25J TEST A1`, or `Phase 25J OCR IMAGE TEST`.

### Scenario independence

- Payment Evidence executes before Structured-profile preparation and remains independently valid.
- Guided Banking requires the reusable Published profile and its own disposable CSV.
- Manager Data Management requires the same Published profile and a different disposable CSV.
- The browser/context is shared across normal actions.
- Independent cleanup always runs in a fresh browser block.

### Cleanup contract

Cleanup must:

- delete the exact disposable Payment Evidence batch and profile;
- undo the exact Guided Banking batch;
- undo the exact Manager Data Management batch;
- abandon only the exact D2-C3 Guided session when present;
- verify the reusable profile remains exactly one Published profile;
- preserve the reusable profile and its Published history;
- capture sanitized HTML after cleanup.

### Payment Evidence selector contract retained from V68

All three Payment Evidence profile interactions must use:

```text
form[action*="handler=UploadPreview"] select[name="PreviewProfileId"]:visible
```

The broad selector `#PreviewProfileId` is prohibited because the returned page contains both a visible select and a hidden import input with that ID.

### Result classification

- Missing or ambiguous exact controls: `TEST_INVALID`.
- Application-visible functional error: `FAIL`.
- External prerequisite that the workflow is not approved to create: `BLOCKED`.
- Cleanup failure: `CLEANUP_FAILED`.
- The installer and BAT wrapper must not relabel a valid `BLOCKED` result as a generic application failure.

### Evidence boundary

- Website-only Robot Browser and Playwright evidence.
- No direct ATX database access.
- Capture sanitized HTML for every major page and wizard state.
- Preserve result ZIP integrity and declared hashes.
- Runtime credentials only; never package or log secrets.
