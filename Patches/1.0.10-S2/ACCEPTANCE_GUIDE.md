# Acceptance guide — Core 1.0.10-S2

1. Stop every Dynomax Worker.
2. Run `Apply-Patch.bat`.
3. Confirm all parser and contract gates pass.
4. Confirm `C:\Dynomax\VERSION.txt` remains `1.0.10`.
5. Start one Worker only after a new exact run is queued.
6. Verify login succeeds without the Browser `Fill Secret` direct-assignment error.
7. Download the new result and confirm `ActionResults.json` contains neither declared secret key.
8. Confirm the disposable workspace cleanup status is `Completed`.

No SQL is required.
