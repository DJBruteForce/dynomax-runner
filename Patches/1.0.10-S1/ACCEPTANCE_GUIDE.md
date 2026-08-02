# Acceptance guide

1. Keep Portal and Runner Worker stopped.
2. Extract under `C:\Dynomax` so `C:\Dynomax\Patches\1.0.10-S1\Apply-Patch.bat` exists.
3. Run `Apply-Patch.bat` as Administrator.
4. Confirm the PowerShell 5.1 parser gate and secret-bridge contract checks pass.
5. Confirm `VERSION.txt` remains `1.0.10`.
6. Do not enable run requests or worker execution yet.
7. Apply the separate guarded SQL only after this patch succeeds.
