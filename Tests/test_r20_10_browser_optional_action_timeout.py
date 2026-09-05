import hashlib
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
RESOURCE = ROOT / "Core" / "Robot" / "Dynomax.resource"
CONTRACT = ROOT / "Core" / "RUNTIME_CONTRACT.json"
VERSION = ROOT / "VERSION.txt"


def _policy():
    text = RESOURCE.read_text(encoding="utf-8").replace("\r\n", "\n")
    start = text.index("Execute Dynomax Action With Policy")
    end = text.rindex("Invoke Dynomax Attempt Recorder")
    return text[start:end]


def test_runtime_revision_is_r20_10():
    assert VERSION.read_text(encoding="utf-8").strip() == "R20.10"
    contract = json.loads(CONTRACT.read_text(encoding="utf-8"))
    assert contract["runtimeRevision"] == "R20.10"
    assert "browser-optional-action-timeout-v1" in contract["capabilities"]


def test_non_browser_actions_do_not_require_browser_timeout_keyword():
    policy = _policy()
    guard = "${browser_library_loaded}=    Run Keyword And Return Status    Get Library Instance    Browser"
    apply = "${previous_browser_timeout}=    Set Browser Timeout    ${effective_timeout}s    scope=Test"
    execute = "Run Dynomax Keyword With Timeout    ${keyword_name}    ${effective_timeout}s"
    assert guard in policy
    assert "IF    ${browser_library_loaded}\n            " + apply in policy
    assert policy.index(guard) < policy.index(apply) < policy.index(execute)


def test_browser_timeout_is_restored_only_when_browser_library_is_loaded():
    policy = _policy()
    restore = (
        "FINALLY\n"
        "            IF    ${browser_library_loaded}\n"
        "                Set Browser Timeout    ${previous_browser_timeout}    scope=Test\n"
        "            END"
    )
    assert restore in policy
    assert policy.count("Set Browser Timeout") == 2


def test_runtime_manifest_hash_matches_modified_resource():
    data = RESOURCE.read_bytes()
    contract = json.loads(CONTRACT.read_text(encoding="utf-8"))
    entry = next(item for item in contract["files"] if item["path"] == "Core/Robot/Dynomax.resource")
    assert entry["length"] == len(data)
    assert entry["sha256"] == hashlib.sha256(data).hexdigest()
