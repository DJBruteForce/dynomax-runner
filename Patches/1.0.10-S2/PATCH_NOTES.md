# Dynomax Core 1.0.10-S2

This cumulative hotfix keeps the installed framework version at `1.0.10` and replaces the S1 secret bridge with the corrected implementation.

## Fixes

- Browser Library `Fill Secret` now receives Robot's protected variable form (`$secret_value`).
- Secret context keys are removed before `dmx.ActionRun.OutputJson` is written.
- Run export applies a second redaction pass to action outputs using `dmx.RunContextValue.IsSecret`.
- Existing non-secret context persistence, exact-version execution, result generation, and cleanup remain unchanged.

## Database

No schema or data script is included or executed.
