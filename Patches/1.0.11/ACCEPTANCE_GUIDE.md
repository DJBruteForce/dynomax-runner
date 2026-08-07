# Core 1.0.11 R4 acceptance guide

1. Stop `Dynomax.Runner.Worker` in Visual Studio.
2. Run `Install-Dynomax-Core-1.0.11-R4.bat`.
3. Confirm packaged and installed Robot runtime contract checks pass.
4. Start `Dynomax.Runner.Worker` through Visual Studio Debug.
5. Queue the same certified Workflow revision r2 package again.
6. Confirm `web.page.open` records attempt 1 and returns `pageOpened`, `pageTitle`, and `currentUrl`.

Do not create a new Action, Workflow revision, Test version, publication or certification.

R4 R2 correction: the packaged contract test now checks the literal `$PSScriptRoot` token without PowerShell variable expansion. The Core runtime payload is unchanged from R4.
