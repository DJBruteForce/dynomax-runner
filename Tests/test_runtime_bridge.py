import importlib.util
import json
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch


ROOT = Path(__file__).resolve().parents[1]
BRIDGE_PATH = ROOT / "Core" / "Robot" / "DynomaxRuntimeBridge.py"
spec = importlib.util.spec_from_file_location("dynomax_runtime_bridge", BRIDGE_PATH)
bridge_module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(bridge_module)


class _FakeReader:
    def __init__(self, process, stderr=False):
        self._process = process
        self._stderr = stderr

    def readline(self):
        if self._stderr:
            return ""
        if not self._process.responses:
            return ""
        return self._process.responses.pop(0)

    def close(self):
        pass


class _FakeWriter:
    def __init__(self, process):
        self._process = process

    def write(self, text):
        for line in text.splitlines():
            if not line:
                continue
            request = json.loads(line)
            operation = request["operation"]
            if operation in ("Ping", "Shutdown"):
                result = "OK"
            elif operation == "ControlFlow":
                result = "RUN" if request["arguments"]["mode"] == "BeforeAction" else "CONTINUE"
            elif operation == "RecordAttempt":
                result = {"classification": None, "retryable": False, "evidenceRetained": False, "timedOut": False, "record": {"attemptNumber": 1}}
            elif operation == "PersistActionResult":
                result = {"status": "PASS"}
            else:
                raise AssertionError(operation)
            self._process.responses.append(json.dumps({"id": request["id"], "ok": True, "result": result}, separators=(",", ":")) + "\n")
            if operation == "Shutdown":
                self._process.returncode = 0
        return len(text)

    def flush(self):
        pass


class _FakeProcess:
    _next_pid = 1000

    def __init__(self):
        type(self)._next_pid += 1
        self.pid = type(self)._next_pid
        self.returncode = None
        self.responses = []
        self.stdin = _FakeWriter(self)
        self.stdout = _FakeReader(self)
        self.stderr = _FakeReader(self, stderr=True)

    def poll(self):
        return self.returncode

    def wait(self, timeout=None):
        self.returncode = 0
        return 0

    def kill(self):
        self.returncode = -9


class RuntimeBridgeTests(unittest.TestCase):
    def test_one_host_is_reused_and_timings_are_separated(self):
        created = []

        def factory(*args, **kwargs):
            process = _FakeProcess()
            created.append(process)
            return process

        with tempfile.TemporaryDirectory() as temp_dir:
            run_dir = Path(temp_dir) / "run"
            run_dir.mkdir()
            workflow = Path(temp_dir) / "workflow.json"
            context = Path(temp_dir) / "context.json"
            workflow.write_text("{}", encoding="utf-8")
            context.write_text("{}", encoding="utf-8")
            bridge = bridge_module.DynomaxRuntimeBridge()
            with patch.object(bridge_module.subprocess, "Popen", side_effect=factory):
                common = ("powershell.exe", str(ROOT), str(workflow), str(context), str(run_dir), "00000000-0000-0000-0000-000000000001")
                self.assertEqual("RUN", bridge.dynomax_host_control_flow("BeforeAction", "node-1", *common))
                ok, result, _, _ = bridge.dynomax_host_record_attempt(
                    1, "2026-08-11T00:00:00+00:00", "2026-08-11T00:00:00.001+00:00", "PASS", "", 0, 0,
                    True, False, False, "", 1.25, *common, 10, "step-10", "test.action", 1,
                    "00000000-0000-0000-0000-000000000002", "", "Reuse", "FinalFailureOnly", False)
                self.assertTrue(ok)
                self.assertFalse(result["retryable"])
                bridge.dynomax_host_persist_action_result(
                    "PASS", "", *common, 10, "step-10", "test.action",
                    "00000000-0000-0000-0000-000000000002", False)
                self.assertEqual(1, len(created), "Per-operation helper process creation regressed.")
                bridge.shutdown_dynomax_runtime_bridge()

            metrics = [json.loads(line) for line in (run_dir / "orchestration-performance.jsonl").read_text(encoding="utf-8").splitlines()]
            self.assertEqual(
                ["hostStartup", "controlFlow", "attemptPersistence", "evidencePersistence"],
                [item["operation"] for item in metrics])
            self.assertEqual(1.25, metrics[2]["actualActionMilliseconds"])
            self.assertTrue((run_dir / "attempt-recorder" / "10" / "1" / "stdout.log").exists())
            self.assertTrue((run_dir / "persist-10.stdout.log").exists())

    def test_forty_action_cycles_still_create_only_one_host(self):
        created = []

        def factory(*args, **kwargs):
            process = _FakeProcess()
            created.append(process)
            return process

        with tempfile.TemporaryDirectory() as temp_dir:
            run_dir = Path(temp_dir) / "run"
            run_dir.mkdir()
            workflow = Path(temp_dir) / "workflow.json"
            context = Path(temp_dir) / "context.json"
            workflow.write_text("{}", encoding="utf-8")
            context.write_text("{}", encoding="utf-8")
            bridge = bridge_module.DynomaxRuntimeBridge()
            with patch.object(bridge_module.subprocess, "Popen", side_effect=factory):
                common = ("powershell.exe", str(ROOT), str(workflow), str(context), str(run_dir), "00000000-0000-0000-0000-000000000011")
                for index in range(1, 41):
                    node = f"node-{index}"
                    step = f"step-{index}"
                    self.assertEqual("RUN", bridge.dynomax_host_control_flow("BeforeAction", node, *common))
                    ok, _, _, _ = bridge.dynomax_host_record_attempt(
                        1, "2026-08-11T00:00:00+00:00", "2026-08-11T00:00:00.001+00:00", "PASS", "",
                        0, 0, True, False, False, "", 1.0, *common, index, step, "test.action", 1,
                        "00000000-0000-0000-0000-000000000012", "", "Reuse", "FinalFailureOnly", False)
                    self.assertTrue(ok)
                    bridge.dynomax_host_persist_action_result(
                        "PASS", "", *common, index, step, "test.action",
                        "00000000-0000-0000-0000-000000000012", False)
                    self.assertEqual("CONTINUE", bridge.dynomax_host_control_flow("AfterAction", node, *common))
                self.assertEqual(1, len(created), "A 40-Action sequential Workflow must not create per-Action orchestration hosts.")
                bridge.shutdown_dynomax_runtime_bridge()

            metrics = [json.loads(line) for line in (run_dir / "orchestration-performance.jsonl").read_text(encoding="utf-8").splitlines()]
            self.assertEqual(1 + (40 * 4), len(metrics))
            self.assertEqual(80, sum(1 for item in metrics if item["operation"] == "controlFlow"))
            self.assertEqual(40, sum(1 for item in metrics if item["operation"] == "attemptPersistence"))
            self.assertEqual(40, sum(1 for item in metrics if item["operation"] == "evidencePersistence"))

    def test_robot_boolean_strings_are_not_truthy_by_accident(self):
        bridge = bridge_module.DynomaxRuntimeBridge()
        self.assertFalse(bridge._to_bool("False", "flag"))
        self.assertTrue(bridge._to_bool("True", "flag"))
        with self.assertRaises(ValueError):
            bridge._to_bool("maybe", "flag")


if __name__ == "__main__":
    unittest.main()
