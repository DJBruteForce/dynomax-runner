# Dynomax Core Patch 1.0.10 — Database Runtime Bridge

## Purpose

This patch allows the local Dynomax V2 worker to execute an exact immutable publication whose authoritative source and publication package are stored in SQL. Permanent per-project source folders are not required for this path.

## Changes

- Adds an already-published catalogue mode to `Invoke-DynomaxWorkflow.ps1`.
- Accepts a disposable runtime project folder instead of requiring `Project-Setup\<Project>`.
- Accepts a temporary context seed created by the V2 worker.
- Accepts a run-contract output path so the worker can ingest the exact Core result.
- Allows clipboard interaction to be suppressed for unattended execution.
- Preserves exact workflow/Action version resolution and fail-closed source verification from Core 1.0.9.
- Redacts worker-designated secret context values before they are persisted to `dmx.RunContextValue`.
- Keeps legacy project-folder execution compatible.

## Database impact

None. The patch contains no SQL. Dynomax V2 schema changes are delivered by the separate Portal/Infrastructure migration.

## Install

1. Copy this complete `1.0.10` folder to `C:\Dynomax\Patches\1.0.10`.
2. Run `Apply-Patch.bat`.
3. Review the transcript under `C:\Dynomax\Logs\Patches\1.0.10`.
4. Do not enable the V2 worker database gate until the installer and runtime acceptance guide pass.

## Rollback

Run `Rollback-Patch.bat` while the V2 worker gate is disabled. The newest timestamped backup is restored. No SQL rollback is performed by the Core patch.
