# Dynomax Patch 1.0.3 Static Validation

- PASS: JSON parse: PATCH_MANIFEST.json
- PASS: JSON parse: Payload/dynomax.json
- PASS: JSON parse: Payload/Config-And-Setup/02-Database/schema-contract.json
- PASS: JSON parse: Payload/Config-And-Setup/05-Framework-Self-Test/self-test.json
- PASS: No UTF-8 BOM: Apply-Patch.ps1
- PASS: CRLF line endings: Apply-Patch.ps1
- PASS: No UTF-8 BOM: Payload/Core/Execution/Dynomax.Workflow.ps1
- PASS: CRLF line endings: Payload/Core/Execution/Dynomax.Workflow.ps1
- PASS: No UTF-8 BOM: Payload/Config-And-Setup/05-Framework-Self-Test/Invoke-DynomaxSelfTest.ps1
- PASS: CRLF line endings: Payload/Config-And-Setup/05-Framework-Self-Test/Invoke-DynomaxSelfTest.ps1
- PASS: No UTF-8 BOM: Apply-Patch.bat
- PASS: CRLF line endings: Apply-Patch.bat
- PASS: No UTF-8 BOM: Payload/Run-Dynomax-Self-Test.bat
- PASS: CRLF line endings: Payload/Run-Dynomax-Self-Test.bat
- PASS: No UTF-8 BOM: Payload/Run-Initial-Validation.bat
- PASS: CRLF line endings: Payload/Run-Initial-Validation.bat
- PASS: No UTF-8 BOM: Payload/Config-And-Setup/05-Framework-Self-Test/Run.bat
- PASS: CRLF line endings: Payload/Config-And-Setup/05-Framework-Self-Test/Run.bat
- PASS: Robot path normalization uses single backslash replacement
- PASS: Old two-backslash replacement removed
- PASS: Root validation does not reference ATX
- PASS: Root validation calls generic self-test
- PASS: No ATX references in Core
- PASS: No ATX references in Config-And-Setup
- PASS: Migration 0008 present
- PASS: Schema contract contains FrameworkValidationRun
- PASS: Schema contract contains FrameworkValidationArtifact
- PASS: Self-test records no project
- PASS: Self-test records no target website
- FAIL: Self-test uses local fixture
- PASS: Self-test has no http URL
- PASS: Patch installer located under Patches/1.0.3
- PASS: Patch manifest hashes match

Live Windows PowerShell parsing, SQL migration and Robot Browser execution remain runtime checks performed on the target Windows machine.
