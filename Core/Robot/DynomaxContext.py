"""Per-step Dynomax Action input context bridge.

Compiled bindings remain scoped to the physical execution slot. Immediately before an
Action runs, only that slot's inputs are overlaid onto the legacy shared ``values`` map
used by existing Action resources. The previous values/secret classifications are then
restored after execution. No secret value is returned from Robot keywords or logged.
"""
from __future__ import annotations

import json
import os
import tempfile
from pathlib import Path
from typing import Any, Dict

from robot.api.deco import keyword, library


def _load(path: str) -> Dict[str, Any]:
    return json.loads(Path(path).read_text(encoding="utf-8"))


def _save(path: str, context: Dict[str, Any]) -> None:
    target = Path(path)
    target.parent.mkdir(parents=True, exist_ok=True)
    fd, temp_name = tempfile.mkstemp(prefix=target.name + ".", suffix=".tmp", dir=str(target.parent))
    try:
        with os.fdopen(fd, "w", encoding="utf-8", newline="\n") as stream:
            json.dump(context, stream, ensure_ascii=False, indent=2, default=str)
            stream.write("\n")
        os.replace(temp_name, target)
    except Exception:
        try:
            os.unlink(temp_name)
        except OSError:
            pass
        raise


def activate_step_inputs(context_path: str, step_id: str) -> None:
    context = _load(context_path)
    if context.get("activeStepInput") is not None:
        raise RuntimeError("A Dynomax step-input scope is already active; the previous Action did not restore its context.")

    entry = (context.get("stepInputs") or {}).get(str(step_id))
    if not entry:
        return

    values = context.setdefault("values", {})
    current_secret_keys = {str(value) for value in (context.get("secretKeys") or [])}
    step_values = entry.get("values") or {}
    step_secret_keys = {str(value) for value in (entry.get("secretKeys") or [])}
    prior_values: Dict[str, Any] = {}
    prior_secret_flags: Dict[str, bool] = {}

    for name, value in step_values.items():
        key = str(name)
        prior_values[key] = {"exists": key in values, "value": values.get(key)}
        prior_secret_flags[key] = key in current_secret_keys
        values[key] = value
        if key in step_secret_keys:
            current_secret_keys.add(key)
        else:
            current_secret_keys.discard(key)

    context["secretKeys"] = sorted(current_secret_keys)
    context["activeStepInput"] = {
        "stepId": str(step_id),
        "priorValues": prior_values,
        "priorSecretFlags": prior_secret_flags,
    }
    _save(context_path, context)


def clear_step_inputs(context_path: str, step_id: str) -> None:
    context = _load(context_path)
    active = context.get("activeStepInput")
    if not active:
        return
    if str(active.get("stepId") or "") != str(step_id):
        raise RuntimeError("The active Dynomax step-input scope belongs to a different execution slot.")

    values = context.setdefault("values", {})
    current_secret_keys = {str(value) for value in (context.get("secretKeys") or [])}
    prior_values = active.get("priorValues") or {}
    prior_secret_flags = active.get("priorSecretFlags") or {}

    for name, previous in prior_values.items():
        if bool((previous or {}).get("exists")):
            values[name] = (previous or {}).get("value")
        else:
            values.pop(name, None)
        if bool(prior_secret_flags.get(name)):
            current_secret_keys.add(name)
        else:
            current_secret_keys.discard(name)

    context["secretKeys"] = sorted(current_secret_keys)
    context.pop("activeStepInput", None)
    _save(context_path, context)


@library(scope="GLOBAL", auto_keywords=False)
class DynomaxContext:
    @keyword("Activate Dynomax Step Inputs")
    def activate_dynomax_step_inputs(self, context_path: str, step_id: str) -> None:
        activate_step_inputs(str(context_path), str(step_id))

    @keyword("Clear Dynomax Step Inputs")
    def clear_dynomax_step_inputs(self, context_path: str, step_id: str) -> None:
        clear_step_inputs(str(context_path), str(step_id))
