# Dynomax Core Patch 1.0.9

## Purpose

This patch makes explicit workflow and action versions authoritative during execution. It fixes the V1 1.0.8 mismatch where a workflow recorded `RequestedActionVersion` but execution and result persistence could use the current action version instead.

## Changes

- Retains the exact `WorkflowVersionId` returned by workflow import and writes it to `TestRun`.
- Resolves every explicit `actionVersion` to one exact `ActionVersionId`.
- Verifies canonical action-definition, exact `action.json` bytes and entry-point hashes during preflight, then re-verifies them immediately before Robot-suite generation or PowerShell invocation.
- Fails closed as `TEST_INVALID` when a requested catalogue version is absent and as `STALE` when its exact source bytes are unavailable.
- Persists the exact `ActionVersionId` for Robot and PowerShell action results.
- Adds requested/resolved versions and source verification to `ActionResults.json` and `WorkflowManifest.json` schema v2.
- Requires every step to be version-pinned when any step is pinned.
- Restricts pinned workflows to fail-fast execution, one contiguous normal Robot block and one independent cleanup Robot block.
- Preserves current-version fallback for existing workflows that contain no `actionVersion`.
- Stops a pinned action as `STALE` if its selected source changes after preflight and before invocation.

## Database impact

None. Existing columns are used; no SQL file or migration is included.

## Install

1. Copy the `1.0.9` folder to `C:\Dynomax\Patches\1.0.9`.
2. Run `Apply-Patch.bat`.
3. The installer validates payload hashes, runs a Windows PowerShell 5.1 parser gate, backs up every replaced file, installs the patch, verifies installed hashes and reruns contract/parser checks.
4. No workflow is run automatically.

## Rollback

Run `Rollback-Patch.bat`. It restores the newest timestamped backup. A specific backup may be supplied with `-BackupDirectory` to `Rollback-Patch.ps1`. No SQL rollback is required.
