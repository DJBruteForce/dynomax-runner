# ATX Dynomax Phase 25H-D2-C3 Website Acceptance 1.0.5

V1.0.5 continues the valid V1.0.4 BLOCKED run after Payment Evidence passed completely.

The user approved one permanent manager-owned Published test profile:

- `Dynomax D2C3 Structured TEST`
- workspace `CIPC Example Holdings`
- canonical six-column CSV mapping

The workflow now:

- reuses the exact profile when already canonical and Published;
- creates, tests and publishes it when absent;
- repairs only that exact dedicated test profile when incomplete or incompatible;
- never changes the protected Phase 25J profiles;
- creates separate disposable Guided and Manager CSV fixtures;
- runs Guided Banking and `/Manager/DataManagement/Import` acceptance;
- undoes exact disposable batches;
- preserves and re-verifies the reusable Published profile during cleanup;
- retains Payment Evidence HTML evidence and form-scoped selector safety;
- prints the actual Dynomax result classification instead of relabelling `BLOCKED` as generic failure.

No SQL or ATX application deployment is required for this package.
