import json
import os
import subprocess
import threading
import time
import uuid
from collections import deque
from pathlib import Path


class DynomaxRuntimeBridge:
    ROBOT_LIBRARY_SCOPE = "SUITE"
    ROBOT_LIBRARY_VERSION = "1.0"

    def __init__(self):
        self._process = None
        self._identity = None
        self._lock = threading.RLock()
        self._stderr_tail = deque(maxlen=40)
        self._stderr_thread = None
        self._run_directory = None


    @staticmethod
    def _to_bool(value, name):
        if isinstance(value, bool):
            return value
        if value is None:
            return False
        text = str(value).strip().lower()
        if text in ("true", "1"):
            return True
        if text in ("false", "0", ""):
            return False
        raise ValueError(f"{name} must be True, False, 1 or 0.")

    def _metric(self, operation, elapsed_ms, *, step_order=None, step_id=None,
                action_key=None, attempt_number=None, phase=None,
                actual_action_ms=None):
        if not self._run_directory:
            return
        record = {
            "schemaVersion": 1,
            "recordedAtUtc": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()),
            "operation": operation,
            "durationMilliseconds": round(float(elapsed_ms), 3),
        }
        if phase is not None:
            record["phase"] = str(phase)
        if step_order not in (None, ""):
            record["stepOrder"] = int(step_order)
        if step_id not in (None, ""):
            record["stepId"] = str(step_id)
        if action_key not in (None, ""):
            record["actionKey"] = str(action_key)
        if attempt_number not in (None, ""):
            record["attemptNumber"] = int(attempt_number)
        if actual_action_ms not in (None, ""):
            record["actualActionMilliseconds"] = round(float(actual_action_ms), 3)
        path = Path(self._run_directory) / "orchestration-performance.jsonl"
        path.parent.mkdir(parents=True, exist_ok=True)
        with path.open("a", encoding="utf-8", newline="\n") as handle:
            handle.write(json.dumps(record, separators=(",", ":"), ensure_ascii=True))
            handle.write("\n")
            handle.flush()

    def _drain_stderr(self, stream):
        try:
            for line in iter(stream.readline, ""):
                if not line:
                    break
                self._stderr_tail.append(line.rstrip("\r\n")[:1000])
        finally:
            try:
                stream.close()
            except Exception:
                pass

    def _start_host(self, powershell, dynomax_root, workflow_path, context_path,
                    run_directory, run_id):
        identity = (
            os.path.normcase(os.path.abspath(str(dynomax_root))),
            os.path.normcase(os.path.abspath(str(workflow_path))),
            os.path.normcase(os.path.abspath(str(context_path))),
            os.path.normcase(os.path.abspath(str(run_directory))),
            str(run_id).lower(),
        )
        if self._process is not None and self._process.poll() is None:
            if identity != self._identity:
                raise RuntimeError("Dynomax runtime bridge cannot switch Run identity inside one Robot suite.")
            return
        if self._process is not None:
            self._process = None

        host_script = os.path.join(str(dynomax_root), "Core", "Execution", "Invoke-DynomaxRunOrchestrationHost.ps1")
        if not os.path.isfile(host_script):
            raise RuntimeError(f"Dynomax orchestration host is missing: {host_script}")
        self._run_directory = str(run_directory)
        self._stderr_tail.clear()
        command = [
            str(powershell), "-NoLogo", "-NoProfile", "-ExecutionPolicy", "Bypass",
            "-File", host_script,
            "-DynomaxRoot", str(dynomax_root),
            "-WorkflowPath", str(workflow_path),
            "-ContextPath", str(context_path),
            "-RunDirectory", str(run_directory),
            "-RunId", str(run_id),
        ]
        started = time.perf_counter()
        self._process = subprocess.Popen(
            command,
            stdin=subprocess.PIPE,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            text=True,
            encoding="utf-8",
            errors="replace",
            bufsize=1,
            creationflags=getattr(subprocess, "CREATE_NO_WINDOW", 0),
        )
        self._identity = identity
        self._stderr_thread = threading.Thread(
            target=self._drain_stderr, args=(self._process.stderr,), daemon=True
        )
        self._stderr_thread.start()
        response = self._send_request("Ping", {})
        if response != "OK":
            raise RuntimeError("Dynomax orchestration host did not acknowledge startup.")
        self._metric("hostStartup", (time.perf_counter() - started) * 1000.0)

    def _send_request(self, operation, arguments):
        process = self._process
        if process is None or process.poll() is not None:
            tail = "; ".join(self._stderr_tail)
            raise RuntimeError(f"Dynomax orchestration host is not running. {tail}".strip())
        request_id = uuid.uuid4().hex
        payload = json.dumps(
            {"id": request_id, "operation": operation, "arguments": arguments},
            separators=(",", ":"), ensure_ascii=True,
        )
        try:
            process.stdin.write(payload + "\n")
            process.stdin.flush()
            line = process.stdout.readline()
        except (BrokenPipeError, OSError) as exc:
            tail = "; ".join(self._stderr_tail)
            raise RuntimeError(f"Dynomax orchestration host IPC failed: {exc}. {tail}".strip()) from exc
        if line == "":
            tail = "; ".join(self._stderr_tail)
            raise RuntimeError(f"Dynomax orchestration host exited without a response. {tail}".strip())
        try:
            response = json.loads(line)
        except json.JSONDecodeError as exc:
            raise RuntimeError("Dynomax orchestration host returned malformed JSON.") from exc
        if str(response.get("id", "")) != request_id:
            raise RuntimeError("Dynomax orchestration host response identity did not match the request.")
        if not bool(response.get("ok")):
            message = str(response.get("message") or "Dynomax orchestration request failed.")
            raise RuntimeError(message[:4000])
        return response.get("result")

    def _ensure(self, powershell, dynomax_root, workflow_path, context_path,
                run_directory, run_id):
        with self._lock:
            self._start_host(powershell, dynomax_root, workflow_path, context_path, run_directory, run_id)

    def dynomax_host_control_flow(self, mode, node_id, powershell, dynomax_root,
                                         workflow_path, context_path, run_directory, run_id):
        with self._lock:
            self._start_host(powershell, dynomax_root, workflow_path, context_path, run_directory, run_id)
            started = time.perf_counter()
            result = self._send_request("ControlFlow", {"mode": str(mode), "nodeId": str(node_id)})
            self._metric("controlFlow", (time.perf_counter() - started) * 1000.0,
                         step_id=node_id, phase=mode)
            return str(result)

    def dynomax_host_record_attempt(
        self, attempt, started_at_utc, ended_at_utc, status, message_base64,
        proposed_delay, attempt_wait, forced_final, is_cleanup, timed_out,
        declared_classification, action_duration_ms, powershell, dynomax_root,
        workflow_path, context_path, run_directory, run_id, step_order, step_id,
        action_key, action_version, action_version_id, retry_on_csv,
        browser_session_decision, evidence_policy, sensitive_action
    ):
        attempt_dir = Path(str(run_directory)) / "attempt-recorder" / str(step_order) / str(attempt)
        attempt_dir.mkdir(parents=True, exist_ok=True)
        stdout_path = attempt_dir / "stdout.log"
        stderr_path = attempt_dir / "stderr.log"
        try:
            with self._lock:
                self._start_host(powershell, dynomax_root, workflow_path, context_path, run_directory, run_id)
                started = time.perf_counter()
                result = self._send_request("RecordAttempt", {
                    "stepOrder": int(step_order),
                    "stepId": str(step_id),
                    "actionKey": str(action_key),
                    "actionVersion": int(action_version),
                    "actionVersionId": str(action_version_id),
                    "attemptNumber": int(attempt),
                    "startedAtUtc": str(started_at_utc),
                    "endedAtUtc": str(ended_at_utc),
                    "status": str(status),
                    "messageBase64": str(message_base64 or ""),
                    "retryOnCsv": str(retry_on_csv or ""),
                    "waitBeforeExecutionSeconds": int(attempt_wait),
                    "delayBeforeNextAttemptSeconds": int(proposed_delay),
                    "browserSessionDecision": str(browser_session_decision),
                    "evidencePolicy": str(evidence_policy),
                    "isFinalAttempt": self._to_bool(forced_final, "isFinalAttempt"),
                    "isCleanup": self._to_bool(is_cleanup, "isCleanup"),
                    "timedOut": self._to_bool(timed_out, "timedOut"),
                    "sensitiveAction": self._to_bool(sensitive_action, "sensitiveAction"),
                    "declaredClassification": str(declared_classification or ""),
                })
                elapsed = (time.perf_counter() - started) * 1000.0
                self._metric("attemptPersistence", elapsed, step_order=step_order,
                             step_id=step_id, action_key=action_key,
                             attempt_number=attempt, actual_action_ms=action_duration_ms)
            stdout = json.dumps(result, separators=(",", ":"), ensure_ascii=False)
            stdout_path.write_text(stdout, encoding="utf-8")
            stderr_path.write_text("", encoding="utf-8")
            return True, result, stdout, ""
        except Exception as exc:
            error = str(exc)[:4000]
            try:
                stdout_path.write_text("", encoding="utf-8")
                stderr_path.write_text(error, encoding="utf-8")
            except Exception:
                pass
            return False, None, "", error

    def dynomax_host_mark_action_running(
        self, powershell, dynomax_root, workflow_path, context_path,
        run_directory, run_id, step_order, step_id, action_key,
        action_version_id, is_cleanup
    ):
        with self._lock:
            self._start_host(powershell, dynomax_root, workflow_path, context_path, run_directory, run_id)
            started = time.perf_counter()
            result = self._send_request("MarkActionRunning", {
                "stepOrder": int(step_order),
                "stepId": str(step_id),
                "actionKey": str(action_key),
                "actionVersionId": str(action_version_id),
                "isCleanup": self._to_bool(is_cleanup, "isCleanup"),
            })
            self._metric("actionStarted", (time.perf_counter() - started) * 1000.0,
                         step_order=step_order, step_id=step_id, action_key=action_key)
            return result

    def dynomax_host_persist_action_result(
        self, robot_status, message_base64, powershell, dynomax_root, workflow_path,
        context_path, run_directory, run_id, step_order, step_id, action_key,
        action_version_id, is_cleanup
    ):
        stdout_path = Path(str(run_directory)) / f"persist-{step_order}.stdout.log"
        stderr_path = Path(str(run_directory)) / f"persist-{step_order}.stderr.log"
        try:
            with self._lock:
                self._start_host(powershell, dynomax_root, workflow_path, context_path, run_directory, run_id)
                started = time.perf_counter()
                result = self._send_request("PersistActionResult", {
                    "stepOrder": int(step_order),
                    "stepId": str(step_id),
                    "actionKey": str(action_key),
                    "actionVersionId": str(action_version_id),
                    "robotStatus": str(robot_status),
                    "messageBase64": str(message_base64 or ""),
                    "isCleanup": self._to_bool(is_cleanup, "isCleanup"),
                })
                self._metric("evidencePersistence", (time.perf_counter() - started) * 1000.0,
                             step_order=step_order, step_id=step_id, action_key=action_key)
            stdout_path.write_text("", encoding="utf-8")
            stderr_path.write_text("", encoding="utf-8")
            return result
        except Exception as exc:
            error = str(exc)[:4000]
            try:
                stdout_path.write_text("", encoding="utf-8")
                stderr_path.write_text(error, encoding="utf-8")
            except Exception:
                pass
            raise RuntimeError("Dynomax could not persist action result through the persistent runtime host.") from exc

    def shutdown_dynomax_runtime_bridge(self):
        with self._lock:
            process = self._process
            if process is None:
                return
            try:
                if process.poll() is None:
                    try:
                        self._send_request("Shutdown", {})
                    except Exception:
                        pass
                    try:
                        process.wait(timeout=3)
                    except subprocess.TimeoutExpired:
                        process.kill()
                        process.wait(timeout=3)
            finally:
                self._process = None
                self._identity = None

    def __del__(self):
        try:
            self.shutdown_dynomax_runtime_bridge()
        except Exception:
            pass
