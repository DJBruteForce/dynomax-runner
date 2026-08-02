# Dynomax Patch 1.0.6

This is a cumulative closeout patch based on 1.0.6.

## Changes

- Keeps the console open after every failed outer installer, workflow, or action BAT entry point.
- Closes consoles automatically after successful execution.
- Writes a complete patch/closeout transcript under `C:\Dynomax\Logs\Patches\1.0.6`.
- Prints the exception type, script, line, position, exit code, log location, and result ZIP location where available.
- Updates the reusable Action and Workflow BAT templates so future project packages inherit the failure-pause rule.
- Retains the complete 1.0.6 export, evidence, cleanup, and ZIP closeout changes.

## Run

Run `Run-Dynomax-Framework-Closeout.bat` from the extracted package.
