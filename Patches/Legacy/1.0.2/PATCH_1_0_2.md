# Dynomax 1.0.2 Cumulative Runtime Patch

This patch is cumulative and includes the 1.0.1 prerequisite logging correction.

## Fixed

1. Expensive Robot Browser and Playwright post-install commands run only when Dynomax installs the missing package in that execution.
2. Prerequisite commands show command start, PID, live stdout/stderr, heartbeat, elapsed time and exit code.
3. SQL binary parameters are bound explicitly as `varbinary(max)` and remain `System.Byte[]`.
4. Artifact compression output is explicitly cast to `byte[]` before SQL persistence.
5. Installation validation now runs an end-to-end SQL binary parameter probe.
6. Workflow processes stream output and show a heartbeat by configuration.
7. Failed workflows print the first persisted problem, or state that no action result was persisted.
8. Artifact warnings now identify the exact file that failed ingestion.

## Apply

Extract this ZIP to `C:\` and replace matching files under `C:\Dynomax`.

Do not rerun the full installer. Run:

1. `C:\Dynomax\Config-And-Setup\04-Validate-Installation\Run.bat`
2. `C:\Dynomax\Run-Initial-Validation.bat`

The existing `Dynomax` database and historical run rows are preserved.
