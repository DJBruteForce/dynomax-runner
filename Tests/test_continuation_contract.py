from __future__ import annotations

import importlib.util
import hashlib
import json
import sys
import tempfile
import types
import unittest
from pathlib import Path

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
spec = importlib.util.spec_from_file_location("dynomax_context_continuation", MODULE_PATH)
module = importlib.util.module_from_spec(spec)
assert spec.loader is not None
spec.loader.exec_module(module)


class ContinuationContractTests(unittest.TestCase):
    def _context(self, path: Path, items) -> None:
        path.write_text(
            json.dumps(
                {
                    "schemaVersion": 3,
                    "values": {},
                    "runDataPool": {"schemaVersion": 2, "steps": {}},
                    "continuation": {
                        "schemaVersion": 1,
                        "plan": {"schemaVersion": 1, "items": items},
                    },
                },
                indent=2,
            ),
            encoding="utf-8",
        )

    def test_reuse_decision_is_exact_and_does_not_mutate_context(self) -> None:
        with tempfile.TemporaryDirectory() as temp:
            path = Path(temp) / "context.json"
            self._context(path, [{"targetStepId": "step-1", "decision": "Reuse"}])
            before = path.read_bytes()

            self.assertEqual("REUSE", module.DynomaxContext().resolve_dynomax_continuation_decision(str(path), "step-1"))
            self.assertEqual(before, path.read_bytes())

    def test_missing_or_duplicate_physical_visit_fails_closed(self) -> None:
        with tempfile.TemporaryDirectory() as temp:
            path = Path(temp) / "context.json"
            self._context(path, [{"targetStepId": "step-1", "decision": "Execute"}])
            with self.assertRaisesRegex(RuntimeError, "no unique decision"):
                module.DynomaxContext().resolve_dynomax_continuation_decision(str(path), "step-2")

            self._context(
                path,
                [
                    {"targetStepId": "step-1", "decision": "Execute"},
                    {"targetStepId": "step-1", "decision": "Reuse"},
                ],
            )
            with self.assertRaisesRegex(RuntimeError, "no unique decision"):
                module.DynomaxContext().resolve_dynomax_continuation_decision(str(path), "step-1")

    def test_invalid_decision_fails_closed(self) -> None:
        with tempfile.TemporaryDirectory() as temp:
            path = Path(temp) / "context.json"
            self._context(path, [{"targetStepId": "step-1", "decision": "Guess"}])
            with self.assertRaisesRegex(RuntimeError, "invalid"):
                module.DynomaxContext().resolve_dynomax_continuation_decision(str(path), "step-1")

    def test_normal_run_without_continuation_executes(self) -> None:
        with tempfile.TemporaryDirectory() as temp:
            path = Path(temp) / "context.json"
            path.write_text(json.dumps({"schemaVersion": 2, "values": {}}), encoding="utf-8")
            self.assertEqual("EXECUTE", module.DynomaxContext().resolve_dynomax_continuation_decision(str(path), "step-1"))

    def test_public_resource_keyword_closes_robot_library_scope(self) -> None:
        resource = (ROOT / "Core" / "Robot" / "Dynomax.resource").read_text(encoding="utf-8").replace("\r\n", "\n")
        context_source = MODULE_PATH.read_text(encoding="utf-8")
        self.assertIn("\nGet Dynomax Continuation Decision\n    [Arguments]    ${context_path}    ${step_id}\n", resource)
        self.assertIn("Resolve Dynomax Continuation Decision    ${context_path}    ${step_id}", resource)
        self.assertIn('@keyword("Resolve Dynomax Continuation Decision")', context_source)

    def test_runtime_contract_hashes_match_required_closure(self) -> None:
        manifest = json.loads((ROOT / "Core" / "RUNTIME_CONTRACT.json").read_text(encoding="utf-8"))
        self.assertEqual("1.0.20", manifest["coreVersion"])
        self.assertEqual("R20.7.6", manifest["runtimeRevision"])
        self.assertIn("continuation-decision-v1", manifest["capabilities"])
        self.assertIn("cleanup-execution-order-v1", manifest["capabilities"])
        self.assertIn("cleanup-stop-on-failure-v1", manifest["capabilities"])
        self.assertIn("live-action-progress-v1", manifest["capabilities"])
        self.assertIn("cleanup-browser-session-continuity-v1", manifest["capabilities"])
        for entry in manifest["files"]:
            payload = (ROOT / entry["path"]).read_bytes()
            self.assertEqual(entry["length"], len(payload))
            self.assertEqual(entry["sha256"], hashlib.sha256(payload).hexdigest())


if __name__ == "__main__":
    unittest.main()
