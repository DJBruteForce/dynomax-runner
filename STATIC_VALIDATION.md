# Dynomax 1.0.2 Static Validation

Generated: 2026-07-31

## Passed in the build environment

- Required package and cumulative patch files are present.
- JSON configuration and definition files parse successfully.
- BAT, PowerShell, SQL and Robot resource files contain no UTF-8 BOM.
- BAT and executable PowerShell files use Windows CRLF line endings.
- PowerShell delimiter and here-string structural scan passed.
- SQL migration ordering and existing schema contract remain unchanged.
- Prerequisite post-install actions are configured as `InstalledThisRun`, not unconditional.
- Native prerequisite and workflow execution supports live output, heartbeat, elapsed time, timeout and exit-code reporting.
- SQL binary parameters use explicit `varbinary(max)` binding.
- Artifact source and compressed payload values are explicitly typed as `byte[]`.
- Installation validation contains an end-to-end `DATALENGTH(@Payload)` binary parameter probe.
- Package content hashes are recorded in `PACKAGE_MANIFEST.json`.

## Must run on the target Windows machine

- Windows PowerShell 5.1 or PowerShell 7 parser execution.
- Prerequisite check-only pass with Browser and Playwright post-install actions skipped.
- SQL binary parameter persistence probe against the local Dynomax database.
- Browser launch and live website reachability through the initial workflow.

Static validation is not presented as live Windows, SQL or browser acceptance.
