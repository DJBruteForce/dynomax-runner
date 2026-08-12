"""Per-step Dynomax input/output context bridge with a structured Run Data Pool.

Step-local inputs are overlaid only while an Action executes. Declared Action outputs are
captured before the overlay is restored, keyed by physical step ID, so downstream
StepOutput bindings can resolve an exact source step/output even when input/output names
differ. Secret/sensitive values are never logged by these keywords.
"""
from __future__ import annotations

import base64
import json
import os
import tempfile
from datetime import datetime, timezone
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


def _data_pool(context: Dict[str, Any]) -> Dict[str, Any]:
    pool = context.setdefault("runDataPool", {})
    pool.setdefault("schemaVersion", 1)
    pool.setdefault("steps", {})
    return pool


def _resolve_step_output(context: Dict[str, Any], source_step_id: str, output_name: str) -> Any:
    step = (_data_pool(context).get("steps") or {}).get(str(source_step_id))
    output = ((step or {}).get("outputs") or {}).get(str(output_name))
    if not output or not bool(output.get("available")):
        raise RuntimeError(f"Required Dynomax output '{output_name}' from source step '{source_step_id}' is unavailable.")
    return output.get("value")


def _resolve_runtime_value(context: Dict[str, Any], entry: Dict[str, Any], name: str, attempt_number: int) -> Any:
    key = str(name or "")
    if key == "CurrentUtc":
        return datetime.now(timezone.utc).isoformat()
    if key == "AttemptNumber":
        return max(1, int(attempt_number))
    if key == "NodePath":
        node_path = str(entry.get("nodePath") or "")
        if not node_path:
            raise RuntimeError("RuntimeValue NodePath is unavailable for this Action step.")
        return node_path
    runtime_values = context.get("runtimeValues") or {}
    value = runtime_values.get(key)
    if value is None or (isinstance(value, str) and not value.strip()):
        raise RuntimeError(f"RuntimeValue '{key}' is unavailable for this Run.")
    return value


def activate_step_inputs(context_path: str, step_id: str) -> None:
    context = _load(context_path)
    if context.get("activeStepInput") is not None:
        raise RuntimeError("A Dynomax step-input scope is already active; the previous Action did not restore its context.")

    entry = (context.get("stepInputs") or {}).get(str(step_id))
    if not entry:
        return

    values = context.setdefault("values", {})
    current_secret_keys = {str(value) for value in (context.get("secretKeys") or [])}
    step_values = dict(entry.get("values") or {})
    for binding in entry.get("deferredBindings") or []:
        kind = str(binding.get("kind") or "")
        input_name = str(binding.get("inputName") or "")
        if not input_name:
            raise RuntimeError("A Dynomax deferred binding has no inputName.")
        if kind == "StepOutput":
            source_step_id = str(binding.get("sourceStepId") or "")
            source_output_name = str(binding.get("sourceOutputName") or "")
            if not source_step_id or not source_output_name:
                raise RuntimeError("A Dynomax step-output binding is incomplete.")
            step_values[input_name] = _resolve_step_output(context, source_step_id, source_output_name)
        elif kind == "RuntimeValue":
            name = str(binding.get("name") or "")
            if not name:
                raise RuntimeError("A Dynomax runtime-value binding is incomplete.")
            step_values[input_name] = _resolve_runtime_value(context, entry, name, 1)
        else:
            raise RuntimeError(f"Deferred Dynomax binding kind '{kind}' is not supported by this Core release.")

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


def refresh_runtime_step_inputs(context_path: str, step_id: str, attempt_number: int) -> None:
    context = _load(context_path)
    active = context.get("activeStepInput")
    if active is None:
        return
    if str(active.get("stepId") or "") != str(step_id):
        raise RuntimeError("The active Dynomax step-input scope belongs to a different execution slot.")
    entry = (context.get("stepInputs") or {}).get(str(step_id))
    if not entry:
        return
    values = context.setdefault("values", {})
    changed = False
    for binding in entry.get("deferredBindings") or []:
        if str(binding.get("kind") or "") != "RuntimeValue":
            continue
        input_name = str(binding.get("inputName") or "")
        name = str(binding.get("name") or "")
        if not input_name or not name:
            raise RuntimeError("A Dynomax runtime-value binding is incomplete.")
        values[input_name] = _resolve_runtime_value(context, entry, name, int(attempt_number))
        changed = True
    if changed:
        runtime_values = context.setdefault("runtimeValues", {})
        runtime_values["AttemptNumber"] = max(1, int(attempt_number))
        runtime_values["CurrentUtc"] = datetime.now(timezone.utc).isoformat()
        _save(context_path, context)


def prepare_step_outputs(context_path: str, step_id: str, output_specs_b64: str) -> None:
    context = _load(context_path)
    try:
        specs = json.loads(base64.b64decode(str(output_specs_b64)).decode("utf-8")) if output_specs_b64 else []
    except Exception as exc:
        raise RuntimeError("Dynomax Action output metadata is invalid.") from exc
    active = context.get("activeStepInput")
    if active is None:
        active = {"stepId": str(step_id), "priorValues": {}, "priorSecretFlags": {}}
        context["activeStepInput"] = active
    if str(active.get("stepId") or "") != str(step_id):
        raise RuntimeError("The active Dynomax step-input scope belongs to a different execution slot.")
    values = context.setdefault("values", {})
    secret_keys = {str(value) for value in (context.get("secretKeys") or [])}
    prior_outputs: Dict[str, Any] = {}
    prior_output_secret_flags: Dict[str, bool] = {}
    for spec in specs or []:
        name = str(spec.get("name") or "")
        if not name:
            continue
        prior_outputs[name] = {"exists": name in values, "value": values.get(name)}
        prior_output_secret_flags[name] = name in secret_keys
        # If an Action intentionally uses the same contract name for an input and an output,
        # keep the overlaid input available to the Action. Otherwise remove an older flat output
        # so it cannot be mistaken for this step's newly produced value.
        if name not in (active.get("priorValues") or {}):
            values.pop(name, None)
            secret_keys.discard(name)
    active["priorOutputValues"] = prior_outputs
    active["priorOutputSecretFlags"] = prior_output_secret_flags
    context["secretKeys"] = sorted(secret_keys)
    _save(context_path, context)


def capture_step_outputs(context_path: str, step_id: str, workflow_node_id: str, execution_slot: str, action_key: str, output_specs_b64: str) -> None:
    context = _load(context_path)
    values = context.setdefault("values", {})
    try:
        specs = json.loads(base64.b64decode(str(output_specs_b64)).decode("utf-8")) if output_specs_b64 else []
    except Exception as exc:
        raise RuntimeError("Dynomax Action output metadata is invalid.") from exc

    outputs: Dict[str, Any] = {}
    for spec in specs or []:
        name = str(spec.get("name") or "")
        if not name:
            continue
        outputs[name] = {
            "available": name in values,
            "value": values.get(name) if name in values else None,
            "classification": str(spec.get("classification") or "Normal"),
            "persistInResult": bool(spec.get("persistInResult", True)),
        }

    _data_pool(context)["steps"][str(step_id)] = {
        "stepId": str(step_id),
        "workflowNodeId": str(workflow_node_id),
        "executionSlot": int(execution_slot or 1),
        "actionKey": str(action_key),
        "capturedAtUtc": datetime.now(timezone.utc).isoformat(),
        "outputs": outputs,
    }
    _save(context_path, context)


def clear_step_inputs(context_path: str, step_id: str) -> None:
    context = _load(context_path)
    active = context.get("activeStepInput")
    if active:
        if str(active.get("stepId") or "") != str(step_id):
            raise RuntimeError("The active Dynomax step-input scope belongs to a different execution slot.")
        values = context.setdefault("values", {})
        current_secret_keys = {str(value) for value in (context.get("secretKeys") or [])}
        for name, previous in (active.get("priorValues") or {}).items():
            if bool((previous or {}).get("exists")):
                values[name] = (previous or {}).get("value")
            else:
                values.pop(name, None)
            if bool((active.get("priorSecretFlags") or {}).get(name)):
                current_secret_keys.add(name)
            else:
                current_secret_keys.discard(name)
        for name, previous in (active.get("priorOutputValues") or {}).items():
            if bool((previous or {}).get("exists")):
                values[name] = (previous or {}).get("value")
            else:
                values.pop(name, None)
            if bool((active.get("priorOutputSecretFlags") or {}).get(name)):
                current_secret_keys.add(name)
            else:
                current_secret_keys.discard(name)
        context["secretKeys"] = sorted(current_secret_keys)
        context.pop("activeStepInput", None)

    # Backward-compatible flat context: replay this step's captured outputs after restoring inputs.
    step = ((_data_pool(context).get("steps") or {}).get(str(step_id)) or {})
    values = context.setdefault("values", {})
    for name, output in (step.get("outputs") or {}).items():
        if bool((output or {}).get("available")):
            values[str(name)] = (output or {}).get("value")
    _save(context_path, context)


@library(scope="GLOBAL", auto_keywords=False)
class DynomaxContext:
    @keyword("Activate Dynomax Step Inputs")
    def activate_dynomax_step_inputs(self, context_path: str, step_id: str) -> None:
        activate_step_inputs(str(context_path), str(step_id))

    @keyword("Refresh Dynomax Runtime Step Inputs")
    def refresh_dynomax_runtime_step_inputs(self, context_path: str, step_id: str, attempt_number: int) -> None:
        refresh_runtime_step_inputs(str(context_path), str(step_id), int(attempt_number))

    @keyword("Prepare Dynomax Step Outputs")
    def prepare_dynomax_step_outputs(self, context_path: str, step_id: str, output_specs_b64: str) -> None:
        prepare_step_outputs(str(context_path), str(step_id), str(output_specs_b64))

    @keyword("Capture Dynomax Step Outputs")
    def capture_dynomax_step_outputs(self, context_path: str, step_id: str, workflow_node_id: str, execution_slot: str, action_key: str, output_specs_b64: str) -> None:
        capture_step_outputs(str(context_path), str(step_id), str(workflow_node_id), str(execution_slot), str(action_key), str(output_specs_b64))

    @keyword("Clear Dynomax Step Inputs")
    def clear_dynomax_step_inputs(self, context_path: str, step_id: str) -> None:
        clear_step_inputs(str(context_path), str(step_id))
