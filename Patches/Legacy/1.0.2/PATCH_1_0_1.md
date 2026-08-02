# Dynomax 1.0.1 Prerequisite Logging Patch

This patch corrects the V1.0.0 prerequisite setup behaviour.

## Defect fixed

V1.0.0 ran configured post-install commands whenever a package probe passed. This caused the following expensive commands to run again even when the components were already installed:

- `python -B -m Browser.entry init`
- `npx playwright install chromium`

## New behaviour

- Post-install actions default to `runWhen: InstalledThisRun`.
- Browser and Playwright initialization run only when Dynomax installs the corresponding missing package in that execution.
- Every native prerequisite command now displays its start, process ID, timeout, live stdout/stderr, periodic heartbeat, elapsed time and exit code.
- Probe and install timeouts are configurable in `prerequisites.json`.
- `runWhen` may be changed to `Always`, `InstalledThisRun` or `Never` per post-install action.

## Apply

Extract the patch to `C:\` and replace the matching files under `C:\Dynomax`.

Do not rerun the complete Dynomax installation. Run only:

`C:\Dynomax\Config-And-Setup\01-Prerequisites\Run.bat`

On a machine where the components are already installed, the output must explicitly state that the two post-install actions were skipped.
