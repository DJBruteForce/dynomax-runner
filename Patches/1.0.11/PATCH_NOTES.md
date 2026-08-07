# Dynomax Core 1.0.11 R4 patch notes

This runtime hotfix corrects two failures exposed by the first target-agnostic Open Page run.

## Fixed

- Replaces the nonexistent Robot keyword `Run Keyword With Timeout` with the supported configurable user-keyword `[Timeout]` pattern.
- Converts command-line Boolean values strictly inside `Record-DynomaxExecutionAttempt.ps1`, allowing the exact `True` and `False` values emitted by Robot Framework on Windows PowerShell 5.1.
- Captures attempt-recorder stdout and stderr in deterministic per-step/per-attempt evidence folders.
- Preserves the original Action failure when attempt-evidence persistence also fails, while recording a separate runtime diagnostic.
- A successful Action whose mandatory attempt evidence cannot be written still fails closed.
- Adds a real Robot and recorder runtime smoke gate before files are replaced and again after installation.

No SQL, Portal source, Worker source, Action definition, Workflow definition, Test version, publication or certification changes are included.

R4 R2 correction: the packaged contract test now checks the literal `$PSScriptRoot` token without PowerShell variable expansion. The Core runtime payload is unchanged from R4.
