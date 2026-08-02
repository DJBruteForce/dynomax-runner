# Dynomax Core 1.0.10 Secret Bridge Hotfix S1

- Adds `Fill Dynomax Secret` to `Core/Robot/Dynomax.resource`.
- Reads only context keys declared in the run `secretKeys` collection.
- Suppresses ordinary Robot logging while the temporary value is read.
- Passes the value to Browser Library `Fill Secret`.
- Does not enable Playwright debug logging.
- Keeps `VERSION.txt` and `dynomax.json` at `1.0.10` for compatibility with exact runtime publications.
- Performs no SQL and starts no workflow.
