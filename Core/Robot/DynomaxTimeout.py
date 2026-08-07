"""Dynomax Robot keyword timeout bridge.

Runs a dynamically named Robot keyword under the installed Robot Framework
keyword timeout implementation, but returns timeout as structured Dynomax
attempt state so the generic retry/evidence loop can persist the attempt and
make its configured retry decision.
"""
from __future__ import annotations

from typing import Any, Tuple

from robot.api.deco import keyword, library
from robot.errors import ExecutionFailed, TimeoutExceeded
from robot.libraries.BuiltIn import BuiltIn
from robot.running.timeouts import KeywordTimeout


@library(scope="GLOBAL", auto_keywords=False)
class DynomaxTimeout:
    @keyword("Run Dynomax Keyword With Timeout")
    def run_keyword_with_timeout(
        self, keyword_name: str, timeout: str
    ) -> Tuple[str, Any, bool]:
        if not str(keyword_name).strip():
            raise ValueError("Dynomax keyword name cannot be empty.")
        if not str(timeout).strip():
            raise ValueError("Dynomax timeout cannot be empty.")

        timer = KeywordTimeout(str(timeout), start=True)
        try:
            result = timer.run(BuiltIn().run_keyword, args=(keyword_name,))
            return "PASS", "" if result is None else result, False
        except TimeoutExceeded as error:
            return "FAIL", str(error), True
        except ExecutionFailed as error:
            # Fatal execution controls must keep Robot's normal semantics.
            if error.syntax or error.exit or error.skip or error.test_timeout:
                raise
            return "FAIL", str(error), bool(error.keyword_timeout)
