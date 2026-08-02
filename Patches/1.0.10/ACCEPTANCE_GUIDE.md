# Dynomax Core 1.0.10 Acceptance Guide

## Installer acceptance

The installer must report PASS for:

- patch manifest SHA-256 and length verification;
- Windows PowerShell 5.1 parsing of every payload script;
- database-runtime bridge contract checks;
- installed-byte verification;
- installed modified-file parser validation;
- complete installed Core parser validation.

Confirm:

```text
C:\Dynomax\VERSION.txt = 1.0.10
C:\Dynomax\dynomax.json frameworkVersion = 1.0.10
```

## Security prerequisites before worker enablement

- The worker service account can read only the approved `DYNOMAX_...` environment-variable secrets required by the selected project.
- The account can write to `C:\Dynomax\Temp\V2Runs`, `C:\Dynomax\Temp\Runs` and `C:\Dynomax\Exports`.
- None of those roots or their parents are reparse points.
- Every Action receiving a secret uses an engine keyword that masks the value from logs and diagnostics.
- Result evidence has been checked to confirm that secrets are absent.
- Exact allowed-origin enforcement has been accepted for the selected project. Cross-origin redirects remain a fail-closed rollout item before broad production enablement.

## Required publication acceptance before any execution

1. Keep run requests, the database worker gate and `Runner:ExecutionEnabled` disabled.
2. Enable only immutable publication through the guarded V2 SQL script.
3. Publish `dynomax.shared-session.contract` v1. This verifies the database-to-`dmx` catalogue and immutable package path only.
4. Download the stored publication twice and confirm identical SHA-256 values.
5. Verify the exact Test, Action and source-package IDs in `dmx.V2PublicationPackage` and `dmx.V2PublicationAction`.
6. Confirm its execution certification remains `NotCertified`.

Do **not** execute that v1 publication. The seeded `dynomax.auth.login v1` resource uses a normal text-entry keyword for the password and has not passed secret-safe logging/evidence acceptance.

## Required first runtime acceptance after the secure login follow-up

1. Create and verify a new `dynomax.auth.login` Action version that uses a confirmed secret-masking Browser keyword.
2. Create a new immutable shared-session Test version pinned to that exact login version.
3. Publish the new Test version and verify its package twice.
4. Inspect Robot source, output/log behavior and evidence policy before certifying the exact package hash.
5. Certify only that exact publication through the approval-required SQL script.
6. Enable run requests, but keep worker execution disabled.
7. Queue exactly one run and verify it remains `Queued`.
8. Configure the Windows worker with `ExecutionEnabled=true` and the approved secret prefix, but do not start it yet.
9. Enable the database worker gate and start one worker instance.
10. Confirm one request changes `Queued → Claimed → Running → terminal`.
11. Confirm `dmx.TestRun.WorkflowVersionId` is the exact published V2 Test version ID.
12. Confirm every `dmx.ActionRun.ActionVersionId` is the exact published V2 Action version ID.
13. Confirm the V2 result package hash matches its SQL bytes.
14. Confirm the worker workspace, Core temporary run directory and exported ZIP are deleted.
15. Confirm secret context rows contain only `{"redacted":true}` with `IsSecret = 1`.
16. Inspect Robot output, HTML logs, screenshots, diagnostics and exported evidence for secret leakage.

## Fail-closed recovery boundary

A run that reached `Running` is not automatically reclaimed after lease expiry. This prevents an uncertain Core execution from being repeated automatically. Such a row requires manual diagnosis and a later approved recovery operation. An expired `Claimed` request that never reached `Running` may be reclaimed.

## Not claimed by this package

This package was not executed in the build environment used to produce it. Windows PowerShell 5.1 parsing, SQL migration, Core installation and browser execution must be run on the Dynomax machine before any runtime gate is enabled.
