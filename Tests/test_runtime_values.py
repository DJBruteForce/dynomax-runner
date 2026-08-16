from __future__ import annotations

import importlib.util
import json
import sys
import tempfile
import types
import unittest
from pathlib import Path

# The deployment test exercises the pure context functions without requiring Robot Framework
# to be installed in the packaging environment. Production still imports the real decorators.
robot = types.ModuleType("robot")
robot_api = types.ModuleType("robot.api")
robot_deco = types.ModuleType("robot.api.deco")
robot_deco.keyword = lambda name=None: (lambda func: func)
robot_deco.library = lambda **kwargs: (lambda cls: cls)
sys.modules.setdefault("robot", robot)
sys.modules.setdefault("robot.api", robot_api)
sys.modules.setdefault("robot.api.deco", robot_deco)

ROOT = Path(__file__).resolve().parents[1]
MODULE_PATH = ROOT / "Core" / "Robot" / "DynomaxContext.py"
spec = importlib.util.spec_from_file_location("dynomax_context_runtime_values", MODULE_PATH)
module = importlib.util.module_from_spec(spec)
assert spec.loader is not None
spec.loader.exec_module(module)


class RuntimeValueTests(unittest.TestCase):
    def test_all_runtime_values_resolve_and_attempt_refreshes(self) -> None:
        with tempfile.TemporaryDirectory() as temp:
            context_path = Path(temp) / "context.json"
            context_path.write_text(
                json.dumps(
                    {
                        "schemaVersion": 2,
                        "secretKeys": [],
                        "values": {"value": "prior"},
                        "runDataPool": {"schemaVersion": 1, "steps": {}},
                        "runtimeValues": {
                            "RunId": "11111111-1111-1111-1111-111111111111",
                            "OperationId": "22222222-2222-2222-2222-222222222222",
                            "ProjectId": "33333333-3333-3333-3333-333333333333",
                            "EnvironmentKey": "prod",
                        },
                        "stepInputs": {
                            "step-1": {
                                "nodePath": "call-child::node:marker",
                                "values": {},
                                "secretKeys": [],
                                "deferredBindings": [
                                    {"inputName": "run", "kind": "RuntimeValue", "name": "RunId"},
                                    {"inputName": "operation", "kind": "RuntimeValue", "name": "OperationId"},
                                    {"inputName": "project", "kind": "RuntimeValue", "name": "ProjectId"},
                                    {"inputName": "environment", "kind": "RuntimeValue", "name": "EnvironmentKey"},
                                    {"inputName": "utc", "kind": "RuntimeValue", "name": "CurrentUtc"},
                                    {"inputName": "attempt", "kind": "RuntimeValue", "name": "AttemptNumber"},
                                    {"inputName": "node", "kind": "RuntimeValue", "name": "NodePath"},
                                ],
                            }
                        },
                    },
                    indent=2,
                ),
                encoding="utf-8",
            )

            module.activate_step_inputs(str(context_path), "step-1")
            first = json.loads(context_path.read_text(encoding="utf-8"))
            self.assertEqual(1, first["values"]["attempt"])
            self.assertEqual("call-child::node:marker", first["values"]["node"])
            self.assertEqual("prod", first["values"]["environment"])

            module.refresh_runtime_step_inputs(str(context_path), "step-1", 2)
            second = json.loads(context_path.read_text(encoding="utf-8"))
            self.assertEqual(2, second["values"]["attempt"])
            self.assertEqual(2, second["runtimeValues"]["AttemptNumber"])
            self.assertTrue(second["values"]["utc"])

            module.clear_step_inputs(str(context_path), "step-1")
            final = json.loads(context_path.read_text(encoding="utf-8"))
            self.assertNotIn("attempt", final["values"])
            self.assertNotIn("run", final["values"])
            self.assertEqual("prior", final["values"]["value"])

    def test_missing_static_runtime_value_fails_closed(self) -> None:
        context = {"runtimeValues": {}}
        entry = {"nodePath": "node:a"}
        with self.assertRaisesRegex(RuntimeError, "RunId"):
            module._resolve_runtime_value(context, entry, "RunId", 1)


if __name__ == "__main__":
    unittest.main()
