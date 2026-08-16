import hashlib
import json
from pathlib import Path
import unittest


ROOT = Path(__file__).resolve().parents[1]
RESOURCE = ROOT / "Core" / "Robot" / "Dynomax.resource"
MANIFEST = ROOT / "Core" / "RUNTIME_CONTRACT.json"


class BrowserAttemptTimeoutContractTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.resource_bytes = RESOURCE.read_bytes()
        cls.resource = cls.resource_bytes.decode("utf-8").replace("\r\n", "\n")
        start = cls.resource.index("Execute Dynomax Action With Policy")
        end = cls.resource.rindex("Invoke Dynomax Attempt Recorder")
        cls.policy = cls.resource[start:end]

    def test_effective_attempt_timeout_is_applied_inside_each_retry_attempt(self):
        loop = self.policy.index("FOR    ${attempt}")
        effective = self.policy.index(
            "${effective_timeout}=    Evaluate    max(1, min(int($DYNOMAX_ATTEMPT_TIMEOUT_SECONDS), int($remaining_before_attempt)))"
        )
        apply = self.policy.index(
            "${previous_browser_timeout}=    Set Browser Timeout    ${effective_timeout}s    scope=Test"
        )
        execute = self.policy.index(
            "Run Dynomax Keyword With Timeout    ${keyword_name}    ${effective_timeout}s"
        )
        self.assertLess(loop, effective)
        self.assertLess(effective, apply)
        self.assertLess(apply, execute)

    def test_previous_browser_timeout_is_always_restored_before_retry_reset(self):
        restore = self.policy.index(
            "FINALLY\n            Set Browser Timeout    ${previous_browser_timeout}    scope=Test"
        )
        reset = self.policy.index(
            "IF    '${DYNOMAX_BROWSER_SESSION_RETRY_MODE}' == 'Reset'"
        )
        self.assertLess(restore, reset)
        self.assertEqual(2, self.policy.count("Set Browser Timeout"))

    def test_outer_attempt_timeout_and_browser_timeout_share_the_same_effective_budget(self):
        self.assertIn(
            "Run Dynomax Keyword With Timeout    ${keyword_name}    ${effective_timeout}s",
            self.policy,
        )
        self.assertIn("browserOperation=${effective_timeout}s", self.policy)

    def test_manifest_closes_and_advertises_the_modified_runtime_resource(self):
        manifest = json.loads(MANIFEST.read_text(encoding="utf-8"))
        self.assertIn("browser-attempt-timeout-v1", manifest["capabilities"])
        entry = next(
            item
            for item in manifest["files"]
            if item["path"] == "Core/Robot/Dynomax.resource"
        )
        self.assertEqual(len(self.resource_bytes), entry["length"])
        self.assertEqual(hashlib.sha256(self.resource_bytes).hexdigest(), entry["sha256"])


if __name__ == "__main__":
    unittest.main()
