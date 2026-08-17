import json
import pathlib
import unittest

ROOT = pathlib.Path(__file__).resolve().parents[1]


class CleanupRuntimeSafetyContractTests(unittest.TestCase):
    def test_robot_suite_preserves_caller_sequence(self) -> None:
        workflow = (ROOT / "Core" / "Execution" / "Dynomax.Workflow.ps1").read_text(encoding="utf-8")
        self.assertIn("$driverMainSteps=@($Steps|Where-Object", workflow)
        self.assertIn("$driverCleanupSteps=@($Steps|Where-Object", workflow)
        self.assertIn("foreach($scheduledStep in $driverMainSteps)", workflow)
        self.assertIn("foreach($scheduledStep in $driverCleanupSteps)", workflow)
        self.assertIn("foreach($step in $Steps)", workflow)
        self.assertNotIn("foreach($scheduledStep in ($Steps|Sort-Object order))", workflow)
        self.assertNotIn("foreach($step in ($Steps|Sort-Object order))", workflow)

    def test_stop_cleanup_contract_is_wired_through_robot_teardown(self) -> None:
        workflow = (ROOT / "Core" / "Execution" / "Dynomax.Workflow.ps1").read_text(encoding="utf-8")
        resource = (ROOT / "Core" / "Robot" / "Dynomax.resource").read_text(encoding="utf-8")
        self.assertIn("${DYNOMAX_CLEANUP_STOP_REQUESTED}", workflow)
        self.assertIn("${DYNOMAX_CONTINUE_ON_FAILURE}", workflow)
        self.assertIn("Execute Dynomax Cleanup Schedule", workflow)
        self.assertIn("IF    `${DYNOMAX_CLEANUP_STOP_REQUESTED}", workflow)
        self.assertIn("Set Suite Variable    ${DYNOMAX_CLEANUP_STOP_REQUESTED}    ${True}", resource)

    def test_runtime_contract_hashes_match_cleanup_closure(self) -> None:
        manifest = json.loads((ROOT / "Core" / "RUNTIME_CONTRACT.json").read_text(encoding="utf-8"))
        self.assertEqual("R20.7.7", manifest["runtimeRevision"])
        self.assertIn("cleanup-execution-order-v1", manifest["capabilities"])
        self.assertIn("cleanup-stop-on-failure-v1", manifest["capabilities"])
        self.assertIn("live-action-progress-v1", manifest["capabilities"])
        self.assertIn("cleanup-browser-session-continuity-v1", manifest["capabilities"])
        self.assertIn("cleanup-transition-fast-path-v1", manifest["capabilities"])
        for entry in manifest["files"]:
            payload = (ROOT / entry["path"]).read_bytes()
            self.assertEqual(entry["length"], len(payload))
            import hashlib
            self.assertEqual(entry["sha256"], hashlib.sha256(payload).hexdigest())


if __name__ == "__main__":
    unittest.main()
