from __future__ import annotations
import json
import os
import time
from pathlib import Path
from urllib.parse import urlparse
from typing import Any

class AtxDynomaxRuntime:
    ROBOT_LIBRARY_SCOPE = "SUITE"

    def __init__(self) -> None:
        self.context_path = Path(os.environ.get("DYNOMAX_CONTEXT_PATH", "context.json")).resolve()
        self.run_dir = Path(os.environ.get("DYNOMAX_RUN_DIRECTORY", self.context_path.parent)).resolve()
        self.project_root = Path(os.environ.get("DYNOMAX_PROJECT_ROOT", Path(__file__).resolve().parents[2])).resolve()
        self.context_path.parent.mkdir(parents=True, exist_ok=True)
        self.run_dir.mkdir(parents=True, exist_ok=True)
        if not self.context_path.exists():
            self._write_json(self.context_path, {})

    def _read_json(self, path: Path, default: Any) -> Any:
        try:
            return json.loads(path.read_text(encoding="utf-8"))
        except FileNotFoundError:
            return default

    def _write_json(self, path: Path, value: Any) -> None:
        path.parent.mkdir(parents=True, exist_ok=True)
        temporary = path.with_suffix(path.suffix + ".tmp")
        temporary.write_text(json.dumps(value, indent=2, ensure_ascii=True) + "\n", encoding="utf-8")
        temporary.replace(path)

    def _context(self) -> dict[str, Any]:
        value = self._read_json(self.context_path, {})
        if not isinstance(value, dict):
            raise AssertionError("Dynomax context transport is not a JSON object.")
        return value

    def load_project_environment(self, environment_key: str = "production") -> dict[str, Any]:
        definition = self._read_json(self.project_root / "Project-And-Config" / "project.json", {})
        environments = definition.get("environments") or []
        environment = next((item for item in environments if str(item.get("key", "")).lower() == environment_key.lower()), None)
        if not environment:
            raise AssertionError(f"Project environment was not found: {environment_key}")
        return {
            "baseUrl": environment["baseUrl"],
            "allowedHosts": environment.get("allowedHosts", []),
            "browser": definition.get("browser", "chromium"),
            "headless": bool(definition.get("headless", False)),
        }

    def set_context_value(self, name: str, value: Any) -> None:
        context = self._context()
        context[name] = value
        self._write_json(self.context_path, context)

    def get_context_value(self, name: str) -> Any:
        context = self._context()
        if name not in context:
            raise AssertionError(f"Required shared context value is missing: {name}")
        return context[name]

    def begin_action(self, action_id: str) -> None:
        self._record_action(action_id, "RUNNING", "Action started", None)

    def end_action(self, action_id: str, message: str = "Action completed") -> None:
        self._record_action(action_id, "PASS", message, None)

    def _record_action(self, action_id: str, status: str, message: str, details: Any) -> None:
        path = self.run_dir / "project-export" / "action-telemetry.json"
        items = self._read_json(path, [])
        items.append({"actionId": action_id, "status": status, "message": message, "details": details, "timestampUtc": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime())})
        self._write_json(path, items)

    def record_navigation(self, final_url: str, title: str, navigation_result: Any, allowed_hosts: Any) -> None:
        if isinstance(allowed_hosts, str):
            allowed_hosts = json.loads(allowed_hosts)
        host = (urlparse(final_url).hostname or "").lower()
        normalized = {str(item).lower() for item in allowed_hosts}
        if host not in normalized:
            raise AssertionError(f"Final host '{host}' is outside the configured allowed hosts.")
        self.set_context_value("websiteUrl", final_url)
        self.set_context_value("websiteTitle", title)
        self.set_context_value("navigationResult", str(navigation_result))
        self.set_context_value("websiteReachable", True)

    def record_homepage_inspection(self, first_h1: str, page_language: str, heading_count: int, link_count: int, button_count: int, form_count: int, image_count: int, input_count: int, console_status: str, console_value: Any, resources: Any) -> None:
        console_errors = []
        if console_status == "PASS":
            values = console_value if isinstance(console_value, list) else [console_value]
            for item in values:
                text = str(item)
                if "error" in text.lower():
                    console_errors.append(text)
        resource_values = resources if isinstance(resources, list) else []
        failed_candidates = [item for item in resource_values if item.get("duration", 0) == 0 and item.get("transferSize", 0) == 0]
        findings = {
            "firstVisibleH1": first_h1,
            "pageLanguage": page_language,
            "counts": {"headings": int(heading_count), "links": int(link_count), "buttons": int(button_count), "forms": int(form_count), "images": int(image_count), "inputs": int(input_count)},
            "consoleObservation": {"available": console_status == "PASS", "errors": console_errors},
            "resourceObservation": {"mode": "performance-resource-timing", "entriesObserved": len(resource_values), "failedCandidates": failed_candidates, "note": "Zero-duration and zero-transfer entries are candidates, not definitive HTTP failures."},
        }
        self.set_context_value("homepageInspection", findings)

    def get_evidence_path(self, filename: str) -> str:
        path = self.run_dir / "TestEvidence" / filename
        path.parent.mkdir(parents=True, exist_ok=True)
        return str(path)

    def record_screenshot(self, path: str) -> None:
        evidence = Path(path)
        if not evidence.exists() or evidence.stat().st_size == 0:
            raise AssertionError(f"Homepage screenshot was not created: {path}")
        self.set_context_value("homepageScreenshot", str(evidence))

    def assert_shared_context_values(self, current_url: str, current_title: str) -> None:
        context = self._context()
        required = ["websiteUrl", "websiteTitle", "navigationResult", "websiteReachable", "homepageInspection", "homepageScreenshot"]
        missing = [name for name in required if name not in context]
        if missing:
            raise AssertionError("Missing shared context values: " + ", ".join(missing))
        if context["websiteUrl"] != current_url:
            raise AssertionError("Shared websiteUrl does not match the active browser URL.")
        if context["websiteTitle"] != current_title:
            raise AssertionError("Shared websiteTitle does not match the active page title.")
        self.set_context_value("sharedContextVerified", True)
