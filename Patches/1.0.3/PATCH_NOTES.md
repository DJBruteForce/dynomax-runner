# Dynomax Patch 1.0.3

## Purpose

This patch removes the accidental root-level ATX validation link and fixes Robot resource path generation on Windows.

## Changes

1. `Run-Dynomax-Self-Test.bat` is a project-neutral framework self-test.
2. The compatibility `Run-Initial-Validation.bat` now calls the same generic self-test and no longer calls an ATX workflow.
3. The self-test uses a temporary local HTML fixture. It does not contact any external website or load a project.
4. Framework self-test history and evidence are stored in dedicated SQL tables.
5. Robot resource paths are converted from Windows backslashes to forward slashes correctly.
6. ATX remains only under `Project-Setup\ATX-Solutions` and is run only from its own workflow folder.
7. Patch files now live under `C:\Dynomax\Patches\<Version>`.
8. Existing root-level 1.0.1 and 1.0.2 patch files are moved into `Patches\Legacy\1.0.2` when this patch is applied.

## Apply

1. Extract the patch ZIP to `C:\`.
2. Run `C:\Dynomax\Patches\1.0.3\Apply-Patch.bat`.
3. Run `C:\Dynomax\Run-Dynomax-Self-Test.bat`.

The existing Dynomax database, project definitions and historical runs are preserved.
