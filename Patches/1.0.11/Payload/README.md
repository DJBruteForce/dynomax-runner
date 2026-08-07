# Dynomax Core 1.0.11

This runtime extends the accepted Core 1.0.10 secret-safe S2 baseline with generic configurable Action execution policies.

Core 1.0.11 supports:

- Action and Workflow-node execution settings;
- wait-before execution;
- per-attempt and overall timeouts;
- bounded retry with fixed, linear or exponential backoff;
- typed transient-failure classifications;
- replay-safety and sensitive-evidence enforcement;
- Robot Browser and PowerShell Actions;
- structured execution-attempt evidence;
- historical Core 1.0.10 publication compatibility.

The behavior is driven entirely by immutable Action definitions and compiled Workflow-node settings. It contains no self-test-specific, Portal-specific or Action-ID-specific retry logic.
