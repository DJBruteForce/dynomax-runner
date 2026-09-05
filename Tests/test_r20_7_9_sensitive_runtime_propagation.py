from __future__ import annotations

import base64
import importlib.util
import json
import sys
import tempfile
import types
from pathlib import Path

# Exercise the context implementation without requiring Robot Framework in the
# packaging environment. Production imports the actual decorators.
robot = types.ModuleType("robot")
robot_api = types.ModuleType("robot.api")
robot_deco = types.ModuleType("robot.api.deco")
robot_deco.keyword = lambda name=None: (lambda func: func)
robot_deco.library = lambda **kwargs: (lambda cls: cls)
sys.modules.setdefault("robot", robot)
sys.modules.setdefault("robot.api", robot_api)
sys.modules.setdefault("robot.api.deco", robot_deco)

ROOT = Path(__file__).resolve().parents[1]
CONTEXT_PATH = ROOT / "Core" / "Robot" / "DynomaxContext.py"
RESOURCE_PATH = ROOT / "Core" / "Robot" / "Dynomax.resource"
DISCOVERY_PATH = ROOT / "Core" / "Robot" / "DynomaxDiscovery.py"
RESULTS_PATH = ROOT / "Core" / "Results" / "Dynomax.Results.ps1"
WORKFLOW_PATH = ROOT / "Core" / "Execution" / "Dynomax.Workflow.ps1"
INVOKE_PATH = ROOT / "Core" / "Invoke-DynomaxWorkflow.ps1"
VERSION_PATH = ROOT / "VERSION.txt"
CONTRACT_PATH = ROOT / "Core" / "RUNTIME_CONTRACT.json"

spec = importlib.util.spec_from_file_location("dynomax_context_sensitive_runtime", CONTEXT_PATH)
context_module = importlib.util.module_from_spec(spec)
assert spec.loader is not None
spec.loader.exec_module(context_module)


def _specs(*specs: dict) -> str:
    payload = json.dumps(list(specs), separators=(",", ":")).encode("utf-8")
    return base64.b64encode(payload).decode("ascii")


def test_sensitive_step_output_propagates_through_dynamic_output_without_persistence() -> None:
    sentinel = "483921"
    with tempfile.TemporaryDirectory() as temp:
        context_path = Path(temp) / "context.json"
        context = {
            "schemaVersion": 2,
            "secretKeys": [],
            "sensitiveKeys": [],
            "values": {},
            "runDataPool": {
                "schemaVersion": 1,
                "steps": {
                    "mail": {
                        "outputs": {
                            "message": {
                                "available": True,
                                "value": {"body": f"Verification code {sentinel}"},
                                "classification": "SensitiveRedacted",
                                "persistInResult": False,
                            }
                        }
                    }
                },
            },
            "stepInputs": {
                "body": {
                    "values": {"path": "body"},
                    "secretKeys": [],
                    "deferredBindings": [
                        {
                            "inputName": "json",
                            "kind": "StepOutput",
                            "sourceStepId": "mail",
                            "sourceOutputName": "message",
                        }
                    ],
                }
            },
        }
        context_path.write_text(json.dumps(context), encoding="utf-8")

        output_specs = _specs(
            {
                "name": "value",
                "classification": "Normal",
                "persistInResult": True,
                "sensitiveWhenInputsSensitive": ["json"],
            }
        )
        context_module.begin_step_scope(str(context_path), "body", output_specs)
        active = json.loads(context_path.read_text(encoding="utf-8"))
        assert "json" in active["sensitiveKeys"]
        assert active["values"]["json"]["body"].endswith(sentinel)

        # Simulate the sensitivity-preserving Built-in writing its derived value.
        active["values"]["value"] = f"Verification code {sentinel}"
        context_path.write_text(json.dumps(active), encoding="utf-8")
        context_module.complete_step_scope(str(context_path), "body", "body", "1", "data.json.get-string", output_specs)

        completed = json.loads(context_path.read_text(encoding="utf-8"))
        derived = completed["runDataPool"]["steps"]["body"]["outputs"]["value"]
        assert derived["classification"] == "SensitiveRedacted"
        assert derived["persistInResult"] is False
        assert derived["value"].endswith(sentinel)  # runtime-only pool remains usable by later steps
        assert "value" in completed["sensitiveKeys"]


def test_normal_dynamic_transformation_remains_normal_and_persistable() -> None:
    with tempfile.TemporaryDirectory() as temp:
        context_path = Path(temp) / "context.json"
        context_path.write_text(
            json.dumps(
                {
                    "schemaVersion": 2,
                    "secretKeys": [],
                    "sensitiveKeys": [],
                    "values": {},
                    "runDataPool": {
                        "schemaVersion": 1,
                        "steps": {
                            "source": {
                                "outputs": {
                                    "json": {
                                        "available": True,
                                        "value": {"name": "ordinary"},
                                        "classification": "Normal",
                                        "persistInResult": True,
                                    }
                                }
                            }
                        },
                    },
                    "stepInputs": {
                        "read": {
                            "values": {"path": "name"},
                            "secretKeys": [],
                            "deferredBindings": [
                                {
                                    "inputName": "json",
                                    "kind": "StepOutput",
                                    "sourceStepId": "source",
                                    "sourceOutputName": "json",
                                }
                            ],
                        }
                    },
                }
            ),
            encoding="utf-8",
        )
        output_specs = _specs(
            {
                "name": "value",
                "classification": "Normal",
                "persistInResult": True,
                "sensitiveWhenInputsSensitive": ["json"],
            }
        )
        context_module.begin_step_scope(str(context_path), "read", output_specs)
        active = json.loads(context_path.read_text(encoding="utf-8"))
        assert "json" not in active["sensitiveKeys"]
        active["values"]["value"] = "ordinary"
        context_path.write_text(json.dumps(active), encoding="utf-8")
        context_module.complete_step_scope(str(context_path), "read", "read", "1", "data.json.get-string", output_specs)
        completed = json.loads(context_path.read_text(encoding="utf-8"))
        output = completed["runDataPool"]["steps"]["read"]["outputs"]["value"]
        assert output["classification"] == "Normal"
        assert output["persistInResult"] is True


def test_r20_7_9_contract_keeps_sensitive_values_runtime_only_and_masks_browser_evidence() -> None:
    version = VERSION_PATH.read_text(encoding="utf-8").strip()
    contract = json.loads(CONTRACT_PATH.read_text(encoding="utf-8"))
    resource = RESOURCE_PATH.read_text(encoding="utf-8")
    results = RESULTS_PATH.read_text(encoding="utf-8")
    workflow = WORKFLOW_PATH.read_text(encoding="utf-8")
    invoke = INVOKE_PATH.read_text(encoding="utf-8")
    discovery = DISCOVERY_PATH.read_text(encoding="utf-8")

    assert version == "R20.9"
    assert contract["runtimeRevision"] == "R20.9"
    assert "1.19.18" in contract["compilerVersions"]
    assert "sensitive-runtime-propagation-v1" in contract["capabilities"]

    # Runtime input/output taint and durable-context redaction.
    assert "sensitiveWhenInputsSensitive" in workflow
    assert "sensitiveWhenInputsSensitive" in results
    assert "sensitiveKeys" in invoke
    assert "$sensitiveLookup.ContainsKey($contextKey)" in results
    assert "classification -ne 'Normal' -or -not $persist" in results

    # Sensitive Actions never expose failure details or retry screenshots.
    assert "IF    ${DYNOMAX_SENSITIVE_ACTION} or '${DYNOMAX_ATTEMPT_EVIDENCE_POLICY}' == 'FinalFailureOnly'" in resource
    assert "Sensitive Dynomax Action failed; diagnostic value details are redacted." in resource
    assert "EveryFailedAttempt' and not ${DYNOMAX_SENSITIVE_ACTION} and not ${runtime_sensitive_browser_state}" in resource
    assert "Has Dynomax Runtime Sensitive Browser State" in resource
    assert "Fill Dynomax Sensitive" in resource
    assert "Register Dynomax Sensitive Selector" in resource

    # Discovery treats derived sensitive values exactly like secret values and
    # masks runtime-registered browser selectors without persisting the values.
    assert "_load_sensitive_values" in discovery
    assert "sensitiveKeys" in discovery
    assert "_load_runtime_sensitive_selectors" in discovery
    assert "__dynomaxRuntimeSensitiveSelectors" in discovery
    assert "runtimeSensitiveSelectorCount" in discovery


def test_sensitive_runtime_metadata_never_contains_the_sensitive_value_itself() -> None:
    # The runtime selector registry stores selector metadata only. Sensitive values
    # are looked up from context at execution time and are never copied into that registry.
    resource = RESOURCE_PATH.read_text(encoding="utf-8")
    registry_block = resource.split("Register Dynomax Sensitive Selector", 1)[1].split("\n\n", 1)[0]
    assert "${selector}" in registry_block
    assert "sensitive_value" not in registry_block
    assert "secret_value" not in registry_block
