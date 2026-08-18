"""Fast, fail-closed Dynomax context and Run Data Pool bridge.

The runtime keeps a stat-validated in-process cache, performs one atomic compact JSON write
per step boundary, and preserves the existing secret/output semantics. External Core writes
are detected from the file stamp before a cached context is reused.
"""
from __future__ import annotations

import base64
import copy
import json
import os
import tempfile
from datetime import datetime, timezone
from pathlib import Path
from typing import Any, Dict, Tuple

from robot.api.deco import keyword, library

_CACHE: Dict[str, Tuple[int, int, Dict[str, Any]]] = {}


def _stamp(target: Path) -> Tuple[int, int]:
    stat = target.stat()
    return stat.st_mtime_ns, stat.st_size


def _load(path: str) -> Dict[str, Any]:
    target = Path(path)
    key = str(target.resolve())
    stamp = _stamp(target)
    cached = _CACHE.get(key)
    if cached is not None and cached[0:2] == stamp:
        return cached[2]
    context = json.loads(target.read_text(encoding="utf-8"))
    _CACHE[key] = (stamp[0], stamp[1], context)
    return context


def _save(path: str, context: Dict[str, Any]) -> None:
    target = Path(path)
    target.parent.mkdir(parents=True, exist_ok=True)
    fd, temp_name = tempfile.mkstemp(prefix=target.name + ".", suffix=".tmp", dir=str(target.parent))
    try:
        with os.fdopen(fd, "w", encoding="utf-8", newline="\n") as stream:
            json.dump(context, stream, ensure_ascii=False, separators=(",", ":"), default=str)
            stream.write("\n")
            stream.flush()
            os.fsync(stream.fileno())
        os.replace(temp_name, target)
        stamp = _stamp(target)
        _CACHE[str(target.resolve())] = (stamp[0], stamp[1], context)
    except Exception:
        try:
            os.unlink(temp_name)
        except OSError:
            pass
        raise


def _decode_specs(output_specs_b64: str) -> list[dict[str, Any]]:
    try:
        value = json.loads(base64.b64decode(str(output_specs_b64)).decode("utf-8")) if output_specs_b64 else []
    except Exception as exc:
        raise RuntimeError("Dynomax Action output metadata is invalid.") from exc
    return value if isinstance(value, list) else []


def _data_pool(context: Dict[str, Any]) -> Dict[str, Any]:
    pool = context.setdefault("runDataPool", {})
    pool.setdefault("schemaVersion", 1)
    pool.setdefault("steps", {})
    return pool


def _resolve_step_output_entry(context: Dict[str, Any], source_step_id: str, output_name: str) -> Dict[str, Any]:
    step = (_data_pool(context).get("steps") or {}).get(str(source_step_id))
    output = ((step or {}).get("outputs") or {}).get(str(output_name))
    if not output or not bool(output.get("available")):
        raise RuntimeError(f"Required Dynomax output '{output_name}' from source step '{source_step_id}' is unavailable.")
    return output


def _resolve_step_output(context: Dict[str, Any], source_step_id: str, output_name: str) -> Any:
    return _resolve_step_output_entry(context, source_step_id, output_name).get("value")


def get_continuation_decision(context_path: str, step_id: str) -> str:
    context = _load(context_path)
    continuation = context.get("continuation")
    if continuation is None:
        return "EXECUTE"
    plan = continuation.get("plan") if isinstance(continuation, dict) else None
    if not isinstance(plan, dict):
        raise RuntimeError("Continuation context has no immutable plan.")
    matches = [item for item in (plan.get("items") or []) if isinstance(item, dict) and str(item.get("targetStepId") or "") == str(step_id)]
    if len(matches) != 1:
        raise RuntimeError(f"Continuation plan has no unique decision for physical step '{step_id}'.")
    decision = str(matches[0].get("decision") or "").upper()
    if decision not in {"EXECUTE", "REUSE", "RERUNCONTEXT", "INVALIDATED", "BLOCKED"}:
        raise RuntimeError(f"Continuation plan decision '{decision}' is invalid.")
    return decision


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
    value = (context.get("runtimeValues") or {}).get(key)
    if value is None or (isinstance(value, str) and not value.strip()):
        raise RuntimeError(f"RuntimeValue '{key}' is unavailable for this Run.")
    return value


def _activate_inputs(context: Dict[str, Any], step_id: str) -> None:
    if context.get("activeStepInput") is not None:
        raise RuntimeError("A Dynomax step-input scope is already active; the previous Action did not restore its context.")
    entry = (context.get("stepInputs") or {}).get(str(step_id))
    if not entry:
        return
    values = context.setdefault("values", {})
    current_secret_keys = {str(value) for value in (context.get("secretKeys") or [])}
    current_sensitive_keys = {str(value) for value in (context.get("sensitiveKeys") or [])}
    step_values = dict(entry.get("values") or {})
    deferred_sensitive_keys: set[str] = set()
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
            source_output = _resolve_step_output_entry(context, source_step_id, source_output_name)
            step_values[input_name] = source_output.get("value")
            if str(source_output.get("classification") or "Normal") == "SensitiveRedacted":
                deferred_sensitive_keys.add(input_name)
        elif kind == "RuntimeValue":
            name = str(binding.get("name") or "")
            if not name:
                raise RuntimeError("A Dynomax runtime-value binding is incomplete.")
            step_values[input_name] = _resolve_runtime_value(context, entry, name, 1)
        else:
            raise RuntimeError(f"Deferred Dynomax binding kind '{kind}' is not supported by this Core release.")
    step_secret_keys = {str(value) for value in (entry.get("secretKeys") or [])}
    step_sensitive_keys = {str(value) for value in (entry.get("sensitiveKeys") or [])} | deferred_sensitive_keys
    prior_values: Dict[str, Any] = {}
    prior_secret_flags: Dict[str, bool] = {}
    prior_sensitive_flags: Dict[str, bool] = {}
    for name, value in step_values.items():
        key = str(name)
        prior_values[key] = {"exists": key in values, "value": values.get(key)}
        prior_secret_flags[key] = key in current_secret_keys
        prior_sensitive_flags[key] = key in current_sensitive_keys
        values[key] = value
        if key in step_secret_keys:
            current_secret_keys.add(key)
        else:
            current_secret_keys.discard(key)
        if key in step_sensitive_keys or key in step_secret_keys:
            current_sensitive_keys.add(key)
        else:
            current_sensitive_keys.discard(key)
    context["secretKeys"] = sorted(current_secret_keys)
    context["sensitiveKeys"] = sorted(current_sensitive_keys)
    context["activeStepInput"] = {
        "stepId": str(step_id),
        "priorValues": prior_values,
        "priorSecretFlags": prior_secret_flags,
        "priorSensitiveFlags": prior_sensitive_flags,
    }


def _prepare_outputs(context: Dict[str, Any], step_id: str, specs: list[dict[str, Any]]) -> None:
    active = context.get("activeStepInput")
    if active is None:
        active = {"stepId": str(step_id), "priorValues": {}, "priorSecretFlags": {}, "priorSensitiveFlags": {}}
        context["activeStepInput"] = active
    if str(active.get("stepId") or "") != str(step_id):
        raise RuntimeError("The active Dynomax step-input scope belongs to a different execution slot.")
    values = context.setdefault("values", {})
    secret_keys = {str(value) for value in (context.get("secretKeys") or [])}
    sensitive_keys = {str(value) for value in (context.get("sensitiveKeys") or [])}
    prior_outputs: Dict[str, Any] = {}
    prior_output_secret_flags: Dict[str, bool] = {}
    prior_output_sensitive_flags: Dict[str, bool] = {}
    for spec in specs:
        name = str(spec.get("name") or "")
        if not name:
            continue
        prior_outputs[name] = {"exists": name in values, "value": values.get(name)}
        prior_output_secret_flags[name] = name in secret_keys
        prior_output_sensitive_flags[name] = name in sensitive_keys
        if name not in (active.get("priorValues") or {}):
            values.pop(name, None)
            secret_keys.discard(name)
            sensitive_keys.discard(name)
    active["priorOutputValues"] = prior_outputs
    active["priorOutputSecretFlags"] = prior_output_secret_flags
    active["priorOutputSensitiveFlags"] = prior_output_sensitive_flags
    context["secretKeys"] = sorted(secret_keys)
    context["sensitiveKeys"] = sorted(sensitive_keys)


def _capture_outputs(context: Dict[str, Any], step_id: str, workflow_node_id: str, execution_slot: str, action_key: str, specs: list[dict[str, Any]]) -> None:
    values = context.setdefault("values", {})
    secret_keys = {str(value) for value in (context.get("secretKeys") or [])}
    sensitive_keys = {str(value) for value in (context.get("sensitiveKeys") or [])}
    outputs: Dict[str, Any] = {}
    for spec in specs:
        name = str(spec.get("name") or "")
        if not name:
            continue
        propagation_sources = [str(value) for value in (spec.get("sensitiveWhenInputsSensitive") or []) if str(value)]
        effective_sensitive = any(source in sensitive_keys or source in secret_keys for source in propagation_sources)
        classification = "SensitiveRedacted" if effective_sensitive else str(spec.get("classification") or "Normal")
        persist = False if effective_sensitive else bool(spec.get("persistInResult", True))
        outputs[name] = {
            "available": name in values,
            "value": values.get(name) if name in values else None,
            "classification": classification,
            "persistInResult": persist,
        }
    _data_pool(context)["steps"][str(step_id)] = {
        "stepId": str(step_id),
        "workflowNodeId": str(workflow_node_id),
        "executionSlot": int(execution_slot or 1),
        "actionKey": str(action_key),
        "capturedAtUtc": datetime.now(timezone.utc).isoformat(),
        "outputs": outputs,
    }


def _clear_inputs(context: Dict[str, Any], step_id: str) -> None:
    active = context.get("activeStepInput")
    if active:
        if str(active.get("stepId") or "") != str(step_id):
            raise RuntimeError("The active Dynomax step-input scope belongs to a different execution slot.")
        values = context.setdefault("values", {})
        current_secret_keys = {str(value) for value in (context.get("secretKeys") or [])}
        current_sensitive_keys = {str(value) for value in (context.get("sensitiveKeys") or [])}
        for field, secret_field, sensitive_field in (
            ("priorValues", "priorSecretFlags", "priorSensitiveFlags"),
            ("priorOutputValues", "priorOutputSecretFlags", "priorOutputSensitiveFlags"),
        ):
            for name, previous in (active.get(field) or {}).items():
                if bool((previous or {}).get("exists")):
                    values[name] = (previous or {}).get("value")
                else:
                    values.pop(name, None)
                if bool((active.get(secret_field) or {}).get(name)):
                    current_secret_keys.add(name)
                else:
                    current_secret_keys.discard(name)
                if bool((active.get(sensitive_field) or {}).get(name)):
                    current_sensitive_keys.add(name)
                else:
                    current_sensitive_keys.discard(name)
        context["secretKeys"] = sorted(current_secret_keys)
        context["sensitiveKeys"] = sorted(current_sensitive_keys)
        context.pop("activeStepInput", None)
    step = ((_data_pool(context).get("steps") or {}).get(str(step_id)) or {})
    values = context.setdefault("values", {})
    sensitive_keys = {str(value) for value in (context.get("sensitiveKeys") or [])}
    for name, output in (step.get("outputs") or {}).items():
        if bool((output or {}).get("available")):
            values[str(name)] = (output or {}).get("value")
            if str((output or {}).get("classification") or "Normal") == "SensitiveRedacted":
                sensitive_keys.add(str(name))
            else:
                sensitive_keys.discard(str(name))
    context["sensitiveKeys"] = sorted(sensitive_keys)


def begin_step_scope(context_path: str, step_id: str, output_specs_b64: str) -> None:
    context = _load(context_path)
    _activate_inputs(context, step_id)
    _prepare_outputs(context, step_id, _decode_specs(output_specs_b64))
    _save(context_path, context)


def complete_step_scope(context_path: str, step_id: str, workflow_node_id: str, execution_slot: str, action_key: str, output_specs_b64: str) -> None:
    context = _load(context_path)
    _capture_outputs(context, step_id, workflow_node_id, execution_slot, action_key, _decode_specs(output_specs_b64))
    _clear_inputs(context, step_id)
    _save(context_path, context)


def activate_step_inputs(context_path: str, step_id: str) -> None:
    context = _load(context_path); _activate_inputs(context, step_id); _save(context_path, context)


def prepare_step_outputs(context_path: str, step_id: str, output_specs_b64: str) -> None:
    context = _load(context_path); _prepare_outputs(context, step_id, _decode_specs(output_specs_b64)); _save(context_path, context)


def capture_step_outputs(context_path: str, step_id: str, workflow_node_id: str, execution_slot: str, action_key: str, output_specs_b64: str) -> None:
    context = _load(context_path); _capture_outputs(context, step_id, workflow_node_id, execution_slot, action_key, _decode_specs(output_specs_b64)); _save(context_path, context)


def clear_step_inputs(context_path: str, step_id: str) -> None:
    context = _load(context_path); _clear_inputs(context, step_id); _save(context_path, context)


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
        input_name, name = str(binding.get("inputName") or ""), str(binding.get("name") or "")
        if not input_name or not name:
            raise RuntimeError("A Dynomax runtime-value binding is incomplete.")
        values[input_name] = _resolve_runtime_value(context, entry, name, int(attempt_number)); changed = True
    if changed:
        runtime_values = context.setdefault("runtimeValues", {})
        runtime_values["AttemptNumber"] = max(1, int(attempt_number))
        runtime_values["CurrentUtc"] = datetime.now(timezone.utc).isoformat()
        _save(context_path, context)


@library(scope="GLOBAL", auto_keywords=False)
class DynomaxContext:
    @keyword("Resolve Dynomax Continuation Decision")
    def resolve_dynomax_continuation_decision(self, context_path: str, step_id: str) -> str:
        return get_continuation_decision(str(context_path), str(step_id))

    @keyword("Begin Dynomax Step Scope")
    def begin_dynomax_step_scope(self, context_path: str, step_id: str, output_specs_b64: str) -> None:
        begin_step_scope(str(context_path), str(step_id), str(output_specs_b64))

    @keyword("Complete Dynomax Step Scope")
    def complete_dynomax_step_scope(self, context_path: str, step_id: str, workflow_node_id: str, execution_slot: str, action_key: str, output_specs_b64: str) -> None:
        complete_step_scope(str(context_path), str(step_id), str(workflow_node_id), str(execution_slot), str(action_key), str(output_specs_b64))

    @keyword("Activate Dynomax Step Inputs")
    def activate_dynomax_step_inputs(self, context_path: str, step_id: str) -> None:
        activate_step_inputs(str(context_path), str(step_id))

    @keyword("Refresh Dynomax Runtime Step Inputs")
    def refresh_dynomax_runtime_step_inputs(self, context_path: str, step_id: str, attempt_number: int) -> None:
        refresh_runtime_step_inputs(str(context_path), str(step_id), int(attempt_number))

    @keyword("Is Dynomax Active Step Sensitive")
    def is_dynomax_active_step_sensitive(self, context_path: str, step_id: str) -> bool:
        context = _load(str(context_path))
        active = context.get("activeStepInput") or {}
        if str(active.get("stepId") or "") != str(step_id):
            return False
        input_names = {str(name) for name in (active.get("priorValues") or {}).keys()}
        sensitive = {str(value) for value in (context.get("sensitiveKeys") or [])}
        sensitive.update(str(value) for value in (context.get("secretKeys") or []))
        return bool(input_names & sensitive)

    @keyword("Prepare Dynomax Step Outputs")
    def prepare_dynomax_step_outputs(self, context_path: str, step_id: str, output_specs_b64: str) -> None:
        prepare_step_outputs(str(context_path), str(step_id), str(output_specs_b64))

    @keyword("Capture Dynomax Step Outputs")
    def capture_dynomax_step_outputs(self, context_path: str, step_id: str, workflow_node_id: str, execution_slot: str, action_key: str, output_specs_b64: str) -> None:
        capture_step_outputs(str(context_path), str(step_id), str(workflow_node_id), str(execution_slot), str(action_key), str(output_specs_b64))

    @keyword("Clear Dynomax Step Inputs")
    def clear_dynomax_step_inputs(self, context_path: str, step_id: str) -> None:
        clear_step_inputs(str(context_path), str(step_id))

    @keyword("Read Dynomax Context")
    def read_dynomax_context(self, context_path: str) -> Dict[str, Any]:
        return copy.deepcopy(_load(str(context_path)))

    @keyword("Write Dynomax Context")
    def write_dynomax_context(self, context_path: str, context: Dict[str, Any]) -> None:
        _save(str(context_path), context)

    @keyword("Read Dynomax Context Value")
    def read_dynomax_context_value(self, context_path: str, name: str, default: Any = None) -> Any:
        return (_load(str(context_path)).get("values") or {}).get(str(name), default)

    @keyword("Write Dynomax Context Value")
    def write_dynomax_context_value(self, context_path: str, name: str, value: Any) -> None:
        context = _load(str(context_path))
        context.setdefault("values", {})[str(name)] = value
        _save(str(context_path), context)
