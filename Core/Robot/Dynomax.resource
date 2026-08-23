*** Settings ***
Library    OperatingSystem
Library    Process
Library    Collections
Library    ${CURDIR}${/}DynomaxTimeout.py
Library    ${CURDIR}${/}DynomaxContext.py
Library    ${CURDIR}${/}DynomaxDiscovery.py
Library    ${CURDIR}${/}DynomaxRuntimeBridge.py

*** Keywords ***
Start Dynomax Browser
    ${browser_library_loaded}=    Run Keyword And Return Status    Get Library Instance    Browser
    IF    not ${browser_library_loaded}
        Import Library    Browser
    END
    Create Directory    ${DYNOMAX_RUN_DIR}${/}screenshots
    New Browser    ${DYNOMAX_BROWSER}    headless=${DYNOMAX_HEADLESS}
    ${discovery_enabled}=    Get Variable Value    \${DYNOMAX_DISCOVERY_ENABLED}    ${False}
    IF    ${discovery_enabled}
        ${har_path}=    Set Variable    ${DYNOMAX_RUN_DIR}${/}discovery-network.raw.har
        ${har}=    Create Dictionary    path=${har_path}    omitContent=${False}
        New Context    viewport=${DYNOMAX_VIEWPORT}    recordHar=${har}
    ELSE
        New Context    viewport=${DYNOMAX_VIEWPORT}
    END
    New Page    about:blank

Stop Dynomax Browser
    ${close_status}    ${close_message}    ${close_timed_out}=    Run Dynomax Keyword With Timeout    Close Browser    10s
    IF    ${close_timed_out}
        Log    Browser shutdown exceeded the bounded 10-second teardown window. Dynomax is continuing Result finalization.    WARN
    ELSE IF    '${close_status}' != 'PASS'
        Log    Browser session was already unavailable during teardown. Dynomax is continuing Result finalization.    WARN
    END

Complete Dynomax Browser Suite
    ${discovery_enabled}=    Get Variable Value    \${DYNOMAX_DISCOVERY_ENABLED}    ${False}
    IF    ${discovery_enabled}
        Run Keyword And Ignore Error    Capture Dynomax Discovery Evidence
        Run Keyword And Ignore Error    Stop Dynomax Browser
        Finalize Dynomax Discovery Evidence
        ${control_flow_enabled}=    Get Variable Value    \${DYNOMAX_CONTROL_FLOW_ENABLED}    ${False}
        IF    ${control_flow_enabled}
            Assert Dynomax Discovery Target Reached
        END
    ELSE
        Stop Dynomax Browser
    END
    Run Keyword And Ignore Error    Shutdown Dynomax Runtime Bridge

Finalize Dynomax Discovery Evidence
    ${discovery_dir}=    Set Variable    ${DYNOMAX_RUN_DIR}${/}discovery
    Create Directory    ${discovery_dir}
    ${raw_har}=    Set Variable    ${DYNOMAX_RUN_DIR}${/}discovery-network.raw.har
    ${safe_har}=    Set Variable    ${discovery_dir}${/}network.har.json
    ${har_exists}=    Run Keyword And Return Status    File Should Exist    ${raw_har}
    IF    ${har_exists}
        ${har_ok}=    Sanitize Discovery Har    ${raw_har}    ${safe_har}    ${DYNOMAX_CONTEXT_PATH}
        Should Be True    ${har_ok}    Discovery network evidence could not be sanitized safely.
    ELSE
        Create File    ${safe_har}    {"log":{"version":"1.2","creator":{"name":"Dynomax sanitized Discovery HAR","version":"2"},"entries":[]},"security":{"rawRequestBodiesIncluded":false,"rawResponseBodiesIncluded":false,"boundedSanitizedTextOrJsonBodyExcerptsMayBeIncluded":true,"cookiesIncluded":false,"authorizationHeadersIncluded":false,"queryValuesIncluded":false}}
    END
    ${safe_for_handoff}=    Validate Discovery Evidence    ${discovery_dir}    ${DYNOMAX_CONTEXT_PATH}
    Should Be True    ${safe_for_handoff}    Discovery evidence failed the mandatory agent-handoff security/completeness gate. See security-report.json.

Capture Dynomax Discovery Evidence
    ${discovery_dir}=    Set Variable    ${DYNOMAX_RUN_DIR}${/}discovery
    Create Directory    ${discovery_dir}

    ${previous_log_level}=    Set Log Level    NONE
    TRY
        ${structure_script}=    Get Discovery Script    structure    ${DYNOMAX_CONTEXT_PATH}
        ${structure_status}    ${structure}=    Run Keyword And Ignore Error    Evaluate JavaScript    css=html    ${structure_script}
        IF    '${structure_status}' == 'PASS'
            ${structure_raw}=    Evaluate    json.dumps($structure, ensure_ascii=False)    modules=json
            ${structure_json}=    Sanitize Discovery Json    ${structure_raw}    ${DYNOMAX_CONTEXT_PATH}
            Create File    ${discovery_dir}${/}page-structure.json    ${structure_json}
        ELSE
            Create File    ${discovery_dir}${/}page-structure.json    {"captureWarning":"Rich page-structure capture failed."}
        END

        ${dom_script}=    Get Discovery Script    dom    ${DYNOMAX_CONTEXT_PATH}
        ${dom_status}    ${dom}=    Run Keyword And Ignore Error    Evaluate JavaScript    css=html    ${dom_script}
        IF    '${dom_status}' == 'PASS'
            ${safe_dom}=    Sanitize Discovery Text    ${dom}    ${DYNOMAX_CONTEXT_PATH}    1500000
            Create File    ${discovery_dir}${/}page-dom.html    ${safe_dom}
        ELSE
            Create File    ${discovery_dir}${/}page-dom.html    <!-- Dynomax Discovery DOM capture failed -->
        END

        ${text_script}=    Get Discovery Script    text    ${DYNOMAX_CONTEXT_PATH}
        ${text_status}    ${text}=    Run Keyword And Ignore Error    Evaluate JavaScript    css=html    ${text_script}
        IF    '${text_status}' == 'PASS'
            ${safe_text}=    Sanitize Discovery Text    ${text}    ${DYNOMAX_CONTEXT_PATH}    100000
            Create File    ${discovery_dir}${/}page-text.txt    ${safe_text}
        ELSE
            Create File    ${discovery_dir}${/}page-text.txt    [Dynomax Discovery visible-text capture failed]
        END

        ${timing_script}=    Get Discovery Script    timing    ${DYNOMAX_CONTEXT_PATH}
        ${timing_status}    ${timing}=    Run Keyword And Ignore Error    Evaluate JavaScript    css=html    ${timing_script}
        IF    '${timing_status}' == 'PASS'
            ${timing_raw}=    Evaluate    json.dumps($timing, ensure_ascii=False)    modules=json
            ${timing_json}=    Sanitize Discovery Json    ${timing_raw}    ${DYNOMAX_CONTEXT_PATH}
            Create File    ${discovery_dir}${/}resource-timing.json    ${timing_json}
        ELSE
            Create File    ${discovery_dir}${/}resource-timing.json    {"captureWarning":"Resource timing capture failed."}
        END

        ${console_status}    ${console}=    Run Keyword And Ignore Error    Get Console Log    full=True
        IF    '${console_status}' == 'PASS'
            ${console_raw}=    Evaluate    json.dumps($console, ensure_ascii=False)    modules=json
            ${console_safe}=    Sanitize Discovery Json    ${console_raw}    ${DYNOMAX_CONTEXT_PATH}
            Create File    ${discovery_dir}${/}console.json    ${console_safe}
        ELSE
            Create File    ${discovery_dir}${/}console.json    []
        END

        ${errors_status}    ${page_errors}=    Run Keyword And Ignore Error    Get Page Errors    full=True
        IF    '${errors_status}' == 'PASS'
            ${errors_raw}=    Evaluate    json.dumps($page_errors, ensure_ascii=False)    modules=json
            ${errors_safe}=    Sanitize Discovery Json    ${errors_raw}    ${DYNOMAX_CONTEXT_PATH}
            Create File    ${discovery_dir}${/}page-errors.json    ${errors_safe}
        ELSE
            Create File    ${discovery_dir}${/}page-errors.json    []
        END

        ${mask_script}=    Get Discovery Script    mask    ${DYNOMAX_CONTEXT_PATH}
        ${mask_status}    ${mask_result}=    Run Keyword And Ignore Error    Evaluate JavaScript    css=html    ${mask_script}
        IF    '${mask_status}' == 'PASS'
            ${mask_json_raw}=    Evaluate    json.dumps($mask_result, ensure_ascii=False)    modules=json
            ${mask_json}=    Sanitize Discovery Json    ${mask_json_raw}    ${DYNOMAX_CONTEXT_PATH}
            Create File    ${discovery_dir}${/}screenshot-mask.json    ${mask_json}
        ELSE
            Create File    ${discovery_dir}${/}screenshot-mask.json    {"applied":false,"formControlsMasked":false,"captureWarning":"Screenshot masking failed."}
        END
        Run Keyword And Ignore Error    Take Screenshot    ${discovery_dir}${/}screenshot-viewport.png
        Run Keyword And Ignore Error    Take Screenshot    ${discovery_dir}${/}screenshot-full-page.png    fullPage=True
        ${unmask_script}=    Get Discovery Script    unmask    ${DYNOMAX_CONTEXT_PATH}
        Run Keyword And Ignore Error    Evaluate JavaScript    css=html    ${unmask_script}
    FINALLY
        Set Log Level    ${previous_log_level}
    END

    ${capture_metadata}=    Evaluate    json.dumps({'schemaVersion':3,'capture':'Dynomax Discovery comprehensive agent evidence','secretValuesIncluded':False,'secretReferenceDescriptionsIncluded':False,'cookiesIncluded':False,'browserStorageIncluded':False,'rawRequestBodiesIncluded':False,'rawResponseBodiesIncluded':False,'boundedSanitizedJsonOrTextBodyExcerptsMayBeIncluded':True,'unsanitizedDomIncluded':False,'screenshotsMaskFormControls':True,'screenshotsMaskKnownRuntimeSecretsAndEmailLikeIdentityText':True,'mandatorySecurityReport':True}, indent=2)    modules=json
    Create File    ${discovery_dir}${/}capture-metadata.json    ${capture_metadata}

Assert Dynomax Discovery Target Reached
    ${target_node}=    Get Variable Value    \${DYNOMAX_DISCOVERY_TARGET_NODE_ID}    ${EMPTY}
    ${result}=    Dynomax Host Control Flow    AssertDiscoveryTarget    ${target_node}    ${DYNOMAX_POWERSHELL}    ${DYNOMAX_ROOT}    ${DYNOMAX_WORKFLOW_PATH}    ${DYNOMAX_CONTEXT_PATH}    ${DYNOMAX_RUN_DIR}    ${DYNOMAX_RUN_ID}
    Should Be Equal    ${result}    OK    Discovery target assertion failed.

Fail Dynomax Control Flow Action
    [Arguments]    ${node_id}
    ${result}=    Dynomax Host Control Flow    FailAction    ${node_id}    ${DYNOMAX_POWERSHELL}    ${DYNOMAX_ROOT}    ${DYNOMAX_WORKFLOW_PATH}    ${DYNOMAX_CONTEXT_PATH}    ${DYNOMAX_RUN_DIR}    ${DYNOMAX_RUN_ID}
    Should Be Equal    ${result}    OK    Control-flow failure notification failed.
    Set Suite Variable    ${DYNOMAX_CONTROL_FLOW_TERMINAL}    ${True}

Should Run Dynomax Control Flow Action
    [Arguments]    ${node_id}
    ${terminal}=    Get Variable Value    \${DYNOMAX_CONTROL_FLOW_TERMINAL}    ${False}
    IF    ${terminal}
        RETURN    SKIP_FINAL
    END
    ${decision}=    Dynomax Host Control Flow    BeforeAction    ${node_id}    ${DYNOMAX_POWERSHELL}    ${DYNOMAX_ROOT}    ${DYNOMAX_WORKFLOW_PATH}    ${DYNOMAX_CONTEXT_PATH}    ${DYNOMAX_RUN_DIR}    ${DYNOMAX_RUN_ID}
    ${decision}=    Evaluate    str($decision).strip().upper()
    Should Match Regexp    ${decision}    ^(RUN|DEFER|SKIP_FINAL)$    Unexpected control-flow decision: ${decision}
    RETURN    ${decision}

Advance Dynomax Control Flow After Action
    [Arguments]    ${node_id}
    ${advance_state}=    Dynomax Host Control Flow    AfterAction    ${node_id}    ${DYNOMAX_POWERSHELL}    ${DYNOMAX_ROOT}    ${DYNOMAX_WORKFLOW_PATH}    ${DYNOMAX_CONTEXT_PATH}    ${DYNOMAX_RUN_DIR}    ${DYNOMAX_RUN_ID}
    ${advance_state}=    Evaluate    str($advance_state).strip().upper()
    Should Match Regexp    ${advance_state}    ^(CONTINUE|TERMINAL_PASS|TERMINAL_FAIL|TERMINAL_BLOCKED)$    Unexpected control-flow advance state: ${advance_state}
    IF    '${advance_state}' != 'CONTINUE'
        Set Suite Variable    ${DYNOMAX_CONTROL_FLOW_TERMINAL}    ${True}
    END
    RETURN    ${advance_state}

Get Dynomax Continuation Decision
    [Arguments]    ${context_path}    ${step_id}
    ${decision}=    Resolve Dynomax Continuation Decision    ${context_path}    ${step_id}
    RETURN    ${decision}

Execute Dynomax Scheduled Slot
    [Arguments]    ${action_id}    ${step_order}    ${step_id}    ${workflow_node_id}    ${execution_slot}    ${output_specs_b64}    ${is_cleanup}    ${continue_on_failure}    ${action_version_id}    ${requested_version}    ${resolved_version}    ${wait_before_seconds}    ${attempt_timeout_seconds}    ${maximum_attempts}    ${retry_delay_seconds}    ${backoff}    ${maximum_retry_delay_seconds}    ${overall_timeout_seconds}    ${retry_on_csv}    ${evidence_policy}    ${browser_session_retry_mode}    ${sensitive_action}    ${action_keyword}
    Set Test Variable    ${DYNOMAX_ACTION_METADATA_READY}    False
    Set Test Variable    ${DYNOMAX_ACTION_ID}    ${action_id}
    Set Test Variable    ${DYNOMAX_STEP_ORDER}    ${step_order}
    Set Test Variable    ${DYNOMAX_STEP_ID}    ${step_id}
    Set Test Variable    ${DYNOMAX_WORKFLOW_NODE_ID}    ${workflow_node_id}
    Set Test Variable    ${DYNOMAX_EXECUTION_SLOT}    ${execution_slot}
    Set Test Variable    ${DYNOMAX_OUTPUT_SPECS_B64}    ${output_specs_b64}
    Set Test Variable    ${DYNOMAX_IS_CLEANUP}    ${is_cleanup}
    Set Test Variable    ${DYNOMAX_CONTINUE_ON_FAILURE}    ${continue_on_failure}
    Set Test Variable    ${DYNOMAX_ACTION_VERSION_ID}    ${action_version_id}
    Set Test Variable    ${DYNOMAX_REQUESTED_ACTION_VERSION}    ${requested_version}
    Set Test Variable    ${DYNOMAX_RESOLVED_ACTION_VERSION}    ${resolved_version}
    Set Test Variable    ${DYNOMAX_WAIT_BEFORE_SECONDS}    ${wait_before_seconds}
    Set Test Variable    ${DYNOMAX_ATTEMPT_TIMEOUT_SECONDS}    ${attempt_timeout_seconds}
    Set Test Variable    ${DYNOMAX_MAXIMUM_ATTEMPTS}    ${maximum_attempts}
    Set Test Variable    ${DYNOMAX_RETRY_DELAY_SECONDS}    ${retry_delay_seconds}
    Set Test Variable    ${DYNOMAX_BACKOFF}    ${backoff}
    Set Test Variable    ${DYNOMAX_MAXIMUM_RETRY_DELAY_SECONDS}    ${maximum_retry_delay_seconds}
    Set Test Variable    ${DYNOMAX_OVERALL_TIMEOUT_SECONDS}    ${overall_timeout_seconds}
    Set Test Variable    ${DYNOMAX_RETRY_ON_CSV}    ${retry_on_csv}
    Set Test Variable    ${DYNOMAX_ATTEMPT_EVIDENCE_POLICY}    ${evidence_policy}
    Set Test Variable    ${DYNOMAX_BROWSER_SESSION_RETRY_MODE}    ${browser_session_retry_mode}
    Set Test Variable    ${DYNOMAX_SENSITIVE_ACTION}    ${sensitive_action}
    Set Test Variable    ${DYNOMAX_ACTION_METADATA_READY}    True
    IF    ${is_cleanup}
        ${cleanup_stop_requested}=    Get Variable Value    \${DYNOMAX_CLEANUP_STOP_REQUESTED}    ${False}
        IF    ${cleanup_stop_requested}
            Set Test Variable    ${DYNOMAX_ACTION_METADATA_READY}    False
            RETURN
        END
    ELSE
        ${control_flow_decision}=    Should Run Dynomax Control Flow Action    ${workflow_node_id}
        IF    '${control_flow_decision}' == 'DEFER'
            Set Test Variable    ${DYNOMAX_ACTION_METADATA_READY}    False
            RETURN
        END
        IF    '${control_flow_decision}' == 'SKIP_FINAL'
            Set Suite Variable    ${DYNOMAX_CONTROL_FLOW_TERMINAL}    True
            Set Test Variable    ${DYNOMAX_ACTION_METADATA_READY}    False
            RETURN
        END
    END
    ${continuation_decision}=    Get Dynomax Continuation Decision    ${DYNOMAX_CONTEXT_PATH}    ${step_id}
    IF    '${continuation_decision}' == 'BLOCKED'
        Set Test Variable    ${DYNOMAX_ACTION_METADATA_READY}    False
        Fail    Continuation is blocked at physical step '${step_id}'. Inspect the immutable continuation plan for the safety reason.
    END
    IF    '${continuation_decision}' == 'REUSE'
        IF    not ${is_cleanup}
            Advance Dynomax Control Flow After Reused Action    ${workflow_node_id}
        END
        Set Test Variable    ${DYNOMAX_ACTION_METADATA_READY}    False
        RETURN
    END
    Begin Dynomax Step Scope    ${DYNOMAX_CONTEXT_PATH}    ${step_id}    ${DYNOMAX_OUTPUT_SPECS_B64}
    ${runtime_sensitive}=    Is Dynomax Active Step Sensitive    ${DYNOMAX_CONTEXT_PATH}    ${step_id}
    IF    ${runtime_sensitive}
        Set Test Variable    ${DYNOMAX_SENSITIVE_ACTION}    True
    END
    Mark Dynomax Action Running
    TRY
        ${action_status}    ${action_message}=    Run Keyword And Ignore Error    Execute Dynomax Action With Policy    ${action_keyword}    ${is_cleanup}
    FINALLY
        Complete Dynomax Step Scope    ${DYNOMAX_CONTEXT_PATH}    ${step_id}    ${workflow_node_id}    ${execution_slot}    ${action_id}    ${DYNOMAX_OUTPUT_SPECS_B64}
    END
    Persist Dynomax Explicit Robot Action Result    ${action_status}    ${action_message}
    IF    ${is_cleanup}
        Set Test Variable    ${DYNOMAX_ACTION_METADATA_READY}    False
        RETURN
    END
    IF    '${action_status}' == 'FAIL'
        Fail Dynomax Control Flow Action    ${workflow_node_id}
        Set Test Variable    ${DYNOMAX_ACTION_METADATA_READY}    False
        RETURN
    END
    ${advance_state}=    Advance Dynomax Control Flow After Action    ${workflow_node_id}
    Set Test Variable    ${DYNOMAX_ACTION_METADATA_READY}    False
    IF    '${advance_state}' != 'CONTINUE'
        RETURN
    END

Advance Dynomax Control Flow After Reused Action
    [Arguments]    ${node_id}
    ${advance_state}=    Dynomax Host Control Flow    ReuseAction    ${node_id}    ${DYNOMAX_POWERSHELL}    ${DYNOMAX_ROOT}    ${DYNOMAX_WORKFLOW_PATH}    ${DYNOMAX_CONTEXT_PATH}    ${DYNOMAX_RUN_DIR}    ${DYNOMAX_RUN_ID}
    ${advance_state}=    Evaluate    str($advance_state).strip().upper()
    Should Match Regexp    ${advance_state}    ^(CONTINUE|TERMINAL_PASS|TERMINAL_FAIL|TERMINAL_BLOCKED)$    Unexpected control-flow reuse advance state: ${advance_state}
    IF    '${advance_state}' != 'CONTINUE'
        Set Suite Variable    ${DYNOMAX_CONTROL_FLOW_TERMINAL}    ${True}
    END
    RETURN    ${advance_state}

Execute Dynomax Action With Policy
    [Arguments]    ${keyword_name}    ${is_cleanup}=False
    ${blocked}=    Get Dynomax Context Value    workflowBlocked    ${False}
    IF    ${blocked} and not ${is_cleanup}
        Skip    A previous workflow action blocked dependent actions.
    END
    ${workflow_started}=    Evaluate    time.time()    modules=time
    IF    ${DYNOMAX_WAIT_BEFORE_SECONDS} > 0
        Sleep    ${DYNOMAX_WAIT_BEFORE_SECONDS}s
    END
    ${maximum_plus_one}=    Evaluate    int($DYNOMAX_MAXIMUM_ATTEMPTS) + 1
    FOR    ${attempt}    IN RANGE    1    ${maximum_plus_one}
        Set Test Variable    ${DYNOMAX_ATTEMPT_NUMBER}    ${attempt}
        Refresh Dynomax Runtime Step Inputs    ${DYNOMAX_CONTEXT_PATH}    ${DYNOMAX_STEP_ID}    ${attempt}
        Set Dynomax Context Value    currentClassification.${DYNOMAX_ACTION_ID}    ${None}
        ${elapsed_before_attempt}=    Evaluate    time.time() - $workflow_started    modules=time
        ${remaining_before_attempt}=    Evaluate    int($DYNOMAX_OVERALL_TIMEOUT_SECONDS) - int($elapsed_before_attempt)
        IF    ${remaining_before_attempt} <= 0
            Fail    Overall execution timeout expired before attempt ${attempt}.
        END
        ${effective_timeout}=    Evaluate    max(1, min(int($DYNOMAX_ATTEMPT_TIMEOUT_SECONDS), int($remaining_before_attempt)))
        ${attempt_started}=    Evaluate    datetime.datetime.now(datetime.timezone.utc).isoformat()    modules=datetime
        ${png_snapshot}=    Capture Dynomax Png Snapshot
        ${actual_action_started}=    Evaluate    time.perf_counter()    modules=time
        ${semantic_timeout}=    Get Dynomax Context Value    timeoutSeconds    ${EMPTY}
        ${browser_available}=    Get Variable Value    \${DYNOMAX_BROWSER_AVAILABLE}    ${False}
        Log    Dynomax timeout hierarchy: authoredAttempt=${DYNOMAX_ATTEMPT_TIMEOUT_SECONDS}s; effectiveAttempt=${effective_timeout}s; browserOperation=${effective_timeout}s when Browser is active; semanticTimeout=${semantic_timeout}; overallRemaining=${remaining_before_attempt}s.
        ${previous_browser_timeout}=    Set Variable    ${EMPTY}
        IF    ${browser_available}
            ${previous_browser_timeout}=    Set Browser Timeout    ${effective_timeout}s    scope=Test
        END
        TRY
            IF    ${DYNOMAX_SENSITIVE_ACTION} or '${DYNOMAX_ATTEMPT_EVIDENCE_POLICY}' == 'FinalFailureOnly'
                ${previous_log_level}=    Set Log Level    NONE
                TRY
                    ${attempt_status}    ${attempt_message}    ${timed_out}=    Run Dynomax Keyword With Timeout    ${keyword_name}    ${effective_timeout}s
                FINALLY
                    Set Log Level    ${previous_log_level}
                END
            ELSE
                ${attempt_status}    ${attempt_message}    ${timed_out}=    Run Dynomax Keyword With Timeout    ${keyword_name}    ${effective_timeout}s
            END
        FINALLY
            IF    ${browser_available}
                Set Browser Timeout    ${previous_browser_timeout}    scope=Test
            END
        END
        ${actual_action_duration_ms}=    Evaluate    (time.perf_counter() - float($actual_action_started)) * 1000.0    modules=time
        ${attempt_ended}=    Evaluate    datetime.datetime.now(datetime.timezone.utc).isoformat()    modules=datetime
        IF    ${DYNOMAX_SENSITIVE_ACTION} and '${attempt_status}' != 'PASS'
            ${attempt_message}=    Set Variable    Sensitive Dynomax Action failed; diagnostic value details are redacted.
        END
        ${is_last_numbered_attempt}=    Evaluate    int($attempt) >= int($DYNOMAX_MAXIMUM_ATTEMPTS)
        ${proposed_delay}=    Calculate Dynomax Retry Delay    ${attempt}
        ${elapsed_after_attempt}=    Evaluate    time.time() - $workflow_started    modules=time
        ${has_time_for_retry}=    Evaluate    ($elapsed_after_attempt + int($proposed_delay)) < int($DYNOMAX_OVERALL_TIMEOUT_SECONDS)
        ${forced_final}=    Evaluate    bool($is_last_numbered_attempt) or not bool($has_time_for_retry)
        ${message64}=    Evaluate    base64.b64encode(str($attempt_message).encode('utf-8')).decode('ascii')    modules=base64
        ${declared_classification}=    Get Dynomax Context Value    currentClassification.${DYNOMAX_ACTION_ID}    ${EMPTY}
        ${attempt_wait}=    Evaluate    int($DYNOMAX_WAIT_BEFORE_SECONDS) if int($attempt) == 1 else 0
        ${recorder_ok}    ${record_data}    ${record_stdout}    ${record_stderr}=    Invoke Dynomax Attempt Recorder
        ...    ${attempt}
        ...    ${attempt_started}
        ...    ${attempt_ended}
        ...    ${attempt_status}
        ...    ${message64}
        ...    ${proposed_delay}
        ...    ${attempt_wait}
        ...    ${forced_final}
        ...    ${is_cleanup}
        ...    ${timed_out}
        ...    ${declared_classification}
        ...    ${actual_action_duration_ms}
        IF    not ${recorder_ok}
            ${recorder_diagnostic}=    Evaluate    ('stdout=' + str($record_stdout) + '; stderr=' + str($record_stderr))[:4000]
            Log    Dynomax attempt recorder failed. ${recorder_diagnostic}    ERROR
            Run Keyword And Ignore Error    Set Dynomax Context Value    attemptRecorderFailure.${DYNOMAX_ACTION_ID}.${attempt}    ${recorder_diagnostic}
            IF    '${attempt_status}' == 'PASS'
                Fail    Dynomax Action passed but mandatory execution-attempt evidence could not be persisted.
            END
            Fail Dynomax Preserving Action Failure    ${attempt_message}
        END
        ${retryable}=    Evaluate    bool($record_data.get('retryable', False))
        IF    '${attempt_status}' == 'PASS'
            RETURN
        END
        IF    not ${retryable}
            Fail Dynomax Preserving Action Failure    ${attempt_message}
        END
        ${runtime_sensitive_browser_state}=    Has Dynomax Runtime Sensitive Browser State
        IF    '${DYNOMAX_ATTEMPT_EVIDENCE_POLICY}' == 'EveryFailedAttempt' and not ${DYNOMAX_SENSITIVE_ACTION} and not ${runtime_sensitive_browser_state}
            ${attempt_evidence_dir}=    Set Variable    ${DYNOMAX_RUN_DIR}${/}attempt-evidence${/}${DYNOMAX_STEP_ORDER}${/}${attempt}
            Create Directory    ${attempt_evidence_dir}
            Run Keyword And Ignore Error    Take Screenshot    ${attempt_evidence_dir}${/}browser.png
        ELSE
            Remove Dynomax Intermediate Attempt Evidence    ${png_snapshot}
        END
        IF    '${DYNOMAX_BROWSER_SESSION_RETRY_MODE}' == 'Reset'
            Stop Dynomax Browser
            Start Dynomax Browser
        END
        IF    ${proposed_delay} > 0
            Sleep    ${proposed_delay}s
        END
    END
    Fail    Action execution ended without a final result.

Invoke Dynomax Attempt Recorder
    [Arguments]    ${attempt}    ${attempt_started}    ${attempt_ended}    ${attempt_status}    ${message64}    ${proposed_delay}    ${attempt_wait}    ${forced_final}    ${is_cleanup}    ${timed_out}    ${declared_classification}    ${actual_action_duration_ms}
    ${recorder_ok}    ${record_data}    ${record_stdout}    ${record_stderr}=    Dynomax Host Record Attempt
    ...    ${attempt}
    ...    ${attempt_started}
    ...    ${attempt_ended}
    ...    ${attempt_status}
    ...    ${message64}
    ...    ${proposed_delay}
    ...    ${attempt_wait}
    ...    ${forced_final}
    ...    ${is_cleanup}
    ...    ${timed_out}
    ...    ${declared_classification}
    ...    ${actual_action_duration_ms}
    ...    ${DYNOMAX_POWERSHELL}
    ...    ${DYNOMAX_ROOT}
    ...    ${DYNOMAX_WORKFLOW_PATH}
    ...    ${DYNOMAX_CONTEXT_PATH}
    ...    ${DYNOMAX_RUN_DIR}
    ...    ${DYNOMAX_RUN_ID}
    ...    ${DYNOMAX_STEP_ORDER}
    ...    ${DYNOMAX_STEP_ID}
    ...    ${DYNOMAX_ACTION_ID}
    ...    ${DYNOMAX_RESOLVED_ACTION_VERSION}
    ...    ${DYNOMAX_ACTION_VERSION_ID}
    ...    ${DYNOMAX_RETRY_ON_CSV}
    ...    ${DYNOMAX_BROWSER_SESSION_RETRY_MODE}
    ...    ${DYNOMAX_ATTEMPT_EVIDENCE_POLICY}
    ...    ${DYNOMAX_SENSITIVE_ACTION}
    RETURN    ${recorder_ok}    ${record_data}    ${record_stdout}    ${record_stderr}

Read Dynomax Optional Text File
    [Arguments]    ${path}
    ${exists}=    Run Keyword And Return Status    File Should Exist    ${path}
    IF    not ${exists}
        RETURN    <file not created: ${path}>
    END
    ${read_status}    ${content_or_error}=    Run Keyword And Ignore Error    Get File    ${path}
    IF    '${read_status}' != 'PASS'
        RETURN    <file unreadable: ${content_or_error}>
    END
    RETURN    ${content_or_error}

Fail Dynomax Preserving Action Failure
    [Arguments]    ${attempt_message}
    IF    ${DYNOMAX_SENSITIVE_ACTION}
        Fail    Sensitive Action failed; detailed message suppressed.
    END
    ${safe_message}=    Convert To String    ${attempt_message}
    IF    $safe_message == ''
        Fail    Dynomax Action failed without an error message.
    END
    Fail    ${safe_message}

Capture Dynomax Png Snapshot
    ${output_dir}=    Set Variable    ${OUTPUT DIR}
    ${paths}=    Evaluate    [str(p.resolve()) for root in [pathlib.Path($DYNOMAX_RUN_DIR) / 'screenshots', pathlib.Path($output_dir)] if root.exists() for p in root.rglob('*.png')]    modules=pathlib
    RETURN    ${paths}

Remove Dynomax Intermediate Attempt Evidence
    [Arguments]    ${before}
    ${output_dir}=    Set Variable    ${OUTPUT DIR}
    Evaluate    [p.unlink() for root in [pathlib.Path($DYNOMAX_RUN_DIR) / 'screenshots', pathlib.Path($output_dir)] if root.exists() for p in root.rglob('*.png') if str(p.resolve()) not in set($before)]    modules=pathlib

Calculate Dynomax Retry Delay
    [Arguments]    ${completed_attempt_number}
    ${delay}=    Evaluate    int($DYNOMAX_RETRY_DELAY_SECONDS)
    IF    '${DYNOMAX_BACKOFF}' == 'Linear'
        ${delay}=    Evaluate    int($DYNOMAX_RETRY_DELAY_SECONDS) * int($completed_attempt_number)
    ELSE IF    '${DYNOMAX_BACKOFF}' == 'Exponential'
        ${delay}=    Evaluate    int($DYNOMAX_RETRY_DELAY_SECONDS) * (2 ** max(0, int($completed_attempt_number) - 1))
    END
    IF    ${DYNOMAX_MAXIMUM_RETRY_DELAY_SECONDS} > 0
        ${delay}=    Evaluate    min(int($delay), int($DYNOMAX_MAXIMUM_RETRY_DELAY_SECONDS))
    END
    RETURN    ${delay}

Execute Dynomax Action Keyword
    [Arguments]    ${keyword_name}    ${is_cleanup}=False
    ${blocked}=    Get Dynomax Context Value    workflowBlocked    ${False}
    IF    ${blocked} and not ${is_cleanup}
        Skip    A previous workflow action blocked dependent actions.
    END
    Run Keyword    ${keyword_name}

Get Dynomax Context
    ${context}=    Read Dynomax Context    ${DYNOMAX_CONTEXT_PATH}
    RETURN    ${context}

Save Dynomax Context
    [Arguments]    ${context}
    Write Dynomax Context    ${DYNOMAX_CONTEXT_PATH}    ${context}

Get Dynomax Context Value
    [Arguments]    ${name}    ${default}=${None}
    ${value}=    Read Dynomax Context Value    ${DYNOMAX_CONTEXT_PATH}    ${name}    ${default}
    RETURN    ${value}

Set Dynomax Context Value
    [Arguments]    ${name}    ${value}
    Write Dynomax Context Value    ${DYNOMAX_CONTEXT_PATH}    ${name}    ${value}

Set Dynomax Action Classification
    [Arguments]    ${classification}
    Set Dynomax Context Value    currentClassification.${DYNOMAX_ACTION_ID}    ${classification}

Fail Dynomax Action
    [Arguments]    ${classification}    ${message}
    Set Dynomax Action Classification    ${classification}
    Fail    ${classification}: ${message}

Fill Dynomax Secret
    [Arguments]    ${selector}    ${context_key}
    ${previous_log_level}=    Set Log Level    NONE
    TRY
        ${context}=    Get Dynomax Context
        ${secret_keys}=    Evaluate    set($context.get('secretKeys', []))
        ${is_declared_secret}=    Evaluate    $context_key in $secret_keys
        IF    not ${is_declared_secret}
            Fail    The requested Dynomax context key is not declared as a secret.
        END
        ${secret_value}=    Evaluate    $context.get('values', {}).get($context_key)
        ${is_missing}=    Evaluate    $secret_value is None or str($secret_value) == ''
        IF    ${is_missing}
            Fail    The requested Dynomax secret value is unavailable.
        END
        Fill Secret    ${selector}    $secret_value
    FINALLY
        Set Log Level    ${previous_log_level}
    END

Fill Dynomax Sensitive
    [Arguments]    ${selector}    ${context_key}
    ${previous_log_level}=    Set Log Level    NONE
    TRY
        ${context}=    Get Dynomax Context
        ${secret_keys}=    Evaluate    set($context.get('secretKeys', []))
        ${sensitive_keys}=    Evaluate    set($context.get('sensitiveKeys', []))
        ${is_declared_sensitive}=    Evaluate    $context_key in $secret_keys or $context_key in $sensitive_keys
        IF    not ${is_declared_sensitive}
            Fail    The requested Dynomax context key is not declared as sensitive.
        END
        ${sensitive_value}=    Evaluate    $context.get('values', {}).get($context_key)
        ${is_missing}=    Evaluate    $sensitive_value is None or str($sensitive_value) == ''
        IF    ${is_missing}
            Fail    The requested Dynomax sensitive value is unavailable.
        END
        Fill Secret    ${selector}    $sensitive_value
    FINALLY
        Set Log Level    ${previous_log_level}
    END

Register Dynomax Sensitive Selector
    [Arguments]    ${selector}
    ${previous_log_level}=    Set Log Level    NONE
    TRY
        ${existing}=    Get Dynomax Context Value    __dynomaxRuntimeSensitiveSelectors    ${EMPTY}
        ${selectors}=    Evaluate    list($existing) if isinstance($existing, list) else ([] if $existing in (None, '') else [str($existing)])
        ${updated}=    Evaluate    list(dict.fromkeys($selectors + [str($selector)]))
        Set Dynomax Context Value    __dynomaxRuntimeSensitiveSelectors    ${updated}
    FINALLY
        Set Log Level    ${previous_log_level}
    END

Has Dynomax Runtime Sensitive Browser State
    ${existing}=    Get Dynomax Context Value    __dynomaxRuntimeSensitiveSelectors    ${EMPTY}
    ${has_sensitive_state}=    Evaluate    bool($existing)
    RETURN    ${has_sensitive_state}

Mark Dynomax Action Running
    Dynomax Host Mark Action Running    ${DYNOMAX_POWERSHELL}    ${DYNOMAX_ROOT}    ${DYNOMAX_WORKFLOW_PATH}    ${DYNOMAX_CONTEXT_PATH}    ${DYNOMAX_RUN_DIR}    ${DYNOMAX_RUN_ID}    ${DYNOMAX_STEP_ORDER}    ${DYNOMAX_STEP_ID}    ${DYNOMAX_ACTION_ID}    ${DYNOMAX_ACTION_VERSION_ID}    ${DYNOMAX_IS_CLEANUP}

Persist Dynomax Explicit Robot Action Result
    [Arguments]    ${robot_status}    ${robot_message}
    ${is_cleanup}=    Get Variable Value    \${DYNOMAX_IS_CLEANUP}    ${False}
    IF    ${is_cleanup} and '${robot_status}' == 'FAIL'
        ${continue_on_failure}=    Get Variable Value    \${DYNOMAX_CONTINUE_ON_FAILURE}    ${False}
        IF    not ${continue_on_failure}
            Set Suite Variable    ${DYNOMAX_CLEANUP_STOP_REQUESTED}    ${True}
        END
    END
    ${message64}=    Evaluate    base64.b64encode(str($robot_message).encode('utf-8')).decode('ascii')    modules=base64
    ${runtime_sensitive_browser_state}=    Has Dynomax Runtime Sensitive Browser State
    IF    '${robot_status}' == 'FAIL' and not ${DYNOMAX_SENSITIVE_ACTION} and not ${runtime_sensitive_browser_state}
        ${safe_name}=    Evaluate    re.sub(r'[^A-Za-z0-9_.-]+','_', $DYNOMAX_ACTION_ID)    modules=re
        Run Keyword And Ignore Error    Take Screenshot    ${DYNOMAX_RUN_DIR}${/}screenshots${/}${DYNOMAX_STEP_ORDER}-${safe_name}.png
    END
    Dynomax Host Persist Action Result    ${robot_status}    ${message64}    ${DYNOMAX_POWERSHELL}    ${DYNOMAX_ROOT}    ${DYNOMAX_WORKFLOW_PATH}    ${DYNOMAX_CONTEXT_PATH}    ${DYNOMAX_RUN_DIR}    ${DYNOMAX_RUN_ID}    ${DYNOMAX_STEP_ORDER}    ${DYNOMAX_STEP_ID}    ${DYNOMAX_ACTION_ID}    ${DYNOMAX_ACTION_VERSION_ID}    ${DYNOMAX_IS_CLEANUP}

Persist Dynomax Robot Action Result
    ${metadata_ready}=    Get Variable Value    \${DYNOMAX_ACTION_METADATA_READY}    ${False}
    IF    not ${metadata_ready}
        ${control_flow_enabled}=    Get Variable Value    \${DYNOMAX_CONTROL_FLOW_ENABLED}    ${False}
        IF    ${control_flow_enabled}
            RETURN
        END
        Log    Dynomax Action metadata was not initialized; result persistence was skipped so the runtime failure is classified as ERROR.    WARN
        RETURN
    END
    ${control_flow_enabled}=    Get Variable Value    \${DYNOMAX_CONTROL_FLOW_ENABLED}    ${False}
    ${is_cleanup}=    Get Variable Value    \${DYNOMAX_IS_CLEANUP}    ${False}
    IF    ${control_flow_enabled} and not ${is_cleanup} and '${TEST_STATUS}' == 'FAIL'
        Fail Dynomax Control Flow Action    ${DYNOMAX_WORKFLOW_NODE_ID}
    END
    IF    ${is_cleanup} and '${TEST_STATUS}' == 'FAIL'
        ${continue_on_failure}=    Get Variable Value    \${DYNOMAX_CONTINUE_ON_FAILURE}    ${False}
        IF    not ${continue_on_failure}
            Set Suite Variable    ${DYNOMAX_CLEANUP_STOP_REQUESTED}    ${True}
        END
    END
    ${message64}=    Evaluate    base64.b64encode($TEST_MESSAGE.encode('utf-8')).decode('ascii')    modules=base64
    ${runtime_sensitive_browser_state}=    Has Dynomax Runtime Sensitive Browser State
    IF    '${TEST_STATUS}' == 'FAIL' and not ${DYNOMAX_SENSITIVE_ACTION} and not ${runtime_sensitive_browser_state}
        ${safe_name}=    Evaluate    re.sub(r'[^A-Za-z0-9_.-]+','_', $DYNOMAX_ACTION_ID)    modules=re
        Run Keyword And Ignore Error    Take Screenshot    ${DYNOMAX_RUN_DIR}${/}screenshots${/}${DYNOMAX_STEP_ORDER}-${safe_name}.png
    END
    Dynomax Host Persist Action Result    ${TEST_STATUS}    ${message64}    ${DYNOMAX_POWERSHELL}    ${DYNOMAX_ROOT}    ${DYNOMAX_WORKFLOW_PATH}    ${DYNOMAX_CONTEXT_PATH}    ${DYNOMAX_RUN_DIR}    ${DYNOMAX_RUN_ID}    ${DYNOMAX_STEP_ORDER}    ${DYNOMAX_STEP_ID}    ${DYNOMAX_ACTION_ID}    ${DYNOMAX_ACTION_VERSION_ID}    ${DYNOMAX_IS_CLEANUP}
