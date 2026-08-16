import hashlib
import json
from pathlib import Path
import unittest


class FinalizationRecoveryContractTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.runtime_root = Path(__file__).resolve().parents[1]
        cls.resource_path = cls.runtime_root / "Core" / "Robot" / "Dynomax.resource"
        cls.contract_path = cls.runtime_root / "Core" / "RUNTIME_CONTRACT.json"
        cls.resource = cls.resource_path.read_text(encoding="utf-8")
        cls.contract = json.loads(cls.contract_path.read_text(encoding="utf-8"))

    def test_browser_teardown_is_bounded_and_non_fatal(self):
        self.assertIn(
            "Run Dynomax Keyword With Timeout    Close Browser    10s",
            self.resource,
        )
        self.assertIn(
            "Dynomax is continuing Result finalization.",
            self.resource,
        )

    def test_runtime_contract_advertises_bounded_teardown(self):
        self.assertIn(
            "bounded-browser-teardown-v1",
            self.contract["capabilities"],
        )

    def test_runtime_contract_closes_over_current_resource(self):
        resource_entry = next(
            entry
            for entry in self.contract["files"]
            if entry["path"] == "Core/Robot/Dynomax.resource"
        )
        resource_bytes = self.resource_path.read_bytes()
        self.assertEqual(len(resource_bytes), resource_entry["length"])
        self.assertEqual(
            hashlib.sha256(resource_bytes).hexdigest(),
            resource_entry["sha256"],
        )


if __name__ == "__main__":
    unittest.main()
