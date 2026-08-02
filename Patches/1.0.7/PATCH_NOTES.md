# Dynomax Patch 1.0.7

This cumulative patch corrects the 1.0.7 closeout wrapper failure.

## Corrected defect

The 1.0.7 wrapper invoked PowerShell scripts in-process and then read `$LASTEXITCODE`. Under `Set-StrictMode -Version Latest`, `$LASTEXITCODE` is undefined until a native process has run, so the wrapper failed before the closeout workflow started.

## Correction

- Every setup/validation/configuration step is now launched as an explicit child PowerShell process.
- Every step has a real, immediately captured native exit code.
- `$LASTEXITCODE` is never read after an in-process PowerShell script call.
- The console still closes on success and pauses on failure.
- Full transcripts are written under `C:\Dynomax\Logs\Patches.0.7`.
- The complete 1.0.7/1.0.5 framework closeout payload is retained and safely reapplied.
