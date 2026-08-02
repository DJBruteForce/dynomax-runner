# Dynomax Patch 1.0.8

This cumulative patch corrects the Windows PowerShell 5.1 parser failure exposed by 1.0.8.

## Root cause

`Core\Results\Dynomax.Results.ps1` contained UTF-8 em dashes while the executable file had no UTF-8 BOM. Windows PowerShell 5.1 decoded those bytes using the legacy Windows code page. One of the resulting characters was treated as a quote delimiter, so parsing failed before the closeout workflow could begin.

## Correction

- Replaced every decorative Unicode character in executable BAT/PS1/CMD files with ASCII text.
- `Dynomax.Results.ps1` is now ASCII-only.
- Added a pre-copy Windows PowerShell 5.1 parser gate for every executable in the payload.
- Added post-copy parser gates for active Core, Config-And-Setup and Project-Setup scripts.
- Parser-gate output identifies the exact file, line, column and message.
- Non-ASCII executable bytes are rejected even when PowerShell could otherwise parse them.
- The closeout workflow cannot start unless all parser gates pass.
- Console close-on-success and pause-on-failure behaviour is retained.
