*** Settings ***
Library    Browser
Library    OperatingSystem
Library    Process
Library    Collections
Library    ${CURDIR}${/}DynomaxTimeout.py
Library    ${CURDIR}${/}DynomaxContext.py
Library    ${CURDIR}${/}DynomaxDiscovery.py

*** Keywords ***
Start Dynomax Browser
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
    Run Keyword And Ignore Error    Close Browser

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
    ${result}=    Run Process
    ...    ${DYNOMAX_POWERSHELL}
    ...    -NoLogo
    ...    -NoProfile
    ...    -ExecutionPolicy
    ...    Bypass
    ...    -File
    ...    ${DYNOMAX_CONTROL_FLOW_SCRIPT}
    ...    -Mode
    ...    AssertDiscoveryTarget
    ...    -DynomaxRoot
    ...    ${DYNOMAX_ROOT}
    ...    -WorkflowPath
    ...    ${DYNOMAX_WORKFLOW_PATH}
    ...    -ContextPath
    ...    ${DYNOMAX_CONTEXT_PATH}
    ...    -RunDirectory
    ...    ${DYNOMAX_RUN_DIR}
    ...    -RunId
    ...    ${DYNOMAX_RUN_ID}
    ...    -NodeId
    ...    ${target_node}
    ...    stdout=PIPE
    ...    stderr=PIPE
    Should Be Equal As Integers    ${result.rc}    0    ${result.stderr}

Fail Dynomax Control Flow Action
    [Arguments]    ${node_id}
    ${result}=    Run Process
    ...    ${DYNOMAX_POWERSHELL}
    ...    -NoLogo
    ...    -NoProfile
    ...    -ExecutionPolicy
    ...    Bypass
    ...    -File
    ...    ${DYNOMAX_CONTROL_FLOW_SCRIPT}
    ...    -Mode
    ...    FailAction
    ...    -DynomaxRoot
    ...    ${DYNOMAX_ROOT}
    ...    -WorkflowPath
    ...    ${DYNOMAX_WORKFLOW_PATH}
    ...    -ContextPath
    ...    ${DYNOMAX_CONTEXT_PATH}
    ...    -RunDirectory
    ...    ${DYNOMAX_RUN_DIR}
    ...    -RunId
    ...    ${DYNOMAX_RUN_ID}
    ...    -NodeId
    ...    ${node_id}
    ...    stdout=PIPE
    ...    stderr=PIPE
    Should Be Equal As Integers    ${result.rc}    0    Control-flow failure notification failed: ${result.stderr}
    Set Suite Variable    ${DYNOMAX_CONTROL_FLOW_TERMINAL}    ${True}

Should Run Dynomax Control Flow Action
    [Arguments]    ${node_id}
    ${terminal}=    Get Variable Value    \${DYNOMAX_CONTROL_FLOW_TERMINAL}    ${False}
    IF    ${terminal}
        RETURN    SKIP_FINAL
    END
    ${result}=    Run Process
    ...    ${DYNOMAX_POWERSHELL}
    ...    -NoLogo
    ...    -NoProfile
    ...    -ExecutionPolicy
    ...    Bypass
    ...    -File
    ...    ${DYNOMAX_CONTROL_FLOW_SCRIPT}
    ...    -Mode
    ...    BeforeAction
    ...    -DynomaxRoot
    ...    ${DYNOMAX_ROOT}
    ...    -WorkflowPath
    ...    ${DYNOMAX_WORKFLOW_PATH}
    ...    -ContextPath
    ...    ${DYNOMAX_CONTEXT_PATH}
    ...    -RunDirectory
    ...    ${DYNOMAX_RUN_DIR}
    ...    -RunId
    ...    ${DYNOMAX_RUN_ID}
    ...    -NodeId
    ...    ${node_id}
    ...    stdout=PIPE
    ...    stderr=PIPE
    Should Be Equal As Integers    ${result.rc}    0    Control-flow decision failed: ${result.stderr}
    ${decision}=    Evaluate    str($result.stdout).strip().upper()
    Should Match Regexp    ${decision}    ^(RUN|DEFER|SKIP_FINAL)$    Unexpected control-flow decision: ${decision}
    RETURN    ${decision}

Advance Dynomax Control Flow After Action
    [Arguments]    ${node_id}
    ${result}=    Run Process
    ...    ${DYNOMAX_POWERSHELL}
    ...    -NoLogo
    ...    -NoProfile
    ...    -ExecutionPolicy
    ...    Bypass
    ...    -File
    ...    ${DYNOMAX_CONTROL_FLOW_SCRIPT}
    ...    -Mode
    ...    AfterAction
    ...    -DynomaxRoot
    ...    ${DYNOMAX_ROOT}
    ...    -WorkflowPath
    ...    ${DYNOMAX_WORKFLOW_PATH}
    ...    -ContextPath
    ...    ${DYNOMAX_CONTEXT_PATH}
    ...    -RunDirectory
    ...    ${DYNOMAX_RUN_DIR}
    ...    -RunId
    ...    ${DYNOMAX_RUN_ID}
    ...    -NodeId
    ...    ${node_id}
    ...    stdout=PIPE
    ...    stderr=PIPE
    Should Be Equal As Integers    ${result.rc}    0    Control-flow advance failed: ${result.stderr}
    ${advance_state}=    Evaluate    str($result.stdout).strip().upper()
    Should Match Regexp    ${advance_state}    ^(CONTINUE|TERMINAL_PASS|TERMINAL_FAIL|TERMINAL_BLOCKED)$    Unexpected control-flow advance state: ${advance_state}
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
        Set Dynomax Context Value    currentClassification.${DYNOMAX_ACTION_ID}    ${None}
        ${elapsed_before_attempt}=    Evaluate    time.time() - $workflow_started    modules=time
        ${remaining_before_attempt}=    Evaluate    int($DYNOMAX_OVERALL_TIMEOUT_SECONDS) - int($elapsed_before_attempt)
        IF    ${remaining_before_attempt} <= 0
            Fail    Overall execution timeout expired before attempt ${attempt}.
        END
        ${effective_timeout}=    Evaluate    max(1, min(int($DYNOMAX_ATTEMPT_TIMEOUT_SECONDS), int($remaining_before_attempt)))
        ${attempt_started}=    Evaluate    datetime.datetime.now(datetime.timezone.utc).isoformat()    modules=datetime
        ${png_snapshot}=    Capture Dynomax Png Snapshot
        IF    '${DYNOMAX_ATTEMPT_EVIDENCE_POLICY}' == 'FinalFailureOnly'
            ${previous_log_level}=    Set Log Level    NONE
            TRY
                ${attempt_status}    ${attempt_message}    ${timed_out}=    Run Dynomax Keyword With Timeout    ${keyword_name}    ${effective_timeout}s
            FINALLY
                Set Log Level    ${previous_log_level}
            END
        ELSE
            ${attempt_status}    ${attempt_message}    ${timed_out}=    Run Dynomax Keyword With Timeout    ${keyword_name}    ${effective_timeout}s
        END
        ${attempt_ended}=    Evaluate    datetime.datetime.now(datetime.timezone.utc).isoformat()    modules=datetime
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
        IF    '${DYNOMAX_ATTEMPT_EVIDENCE_POLICY}' == 'EveryFailedAttempt'
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
    [Arguments]    ${attempt}    ${attempt_started}    ${attempt_ended}    ${attempt_status}    ${message64}    ${proposed_delay}    ${attempt_wait}    ${forced_final}    ${is_cleanup}    ${timed_out}    ${declared_classification}
    ${attempt_recorder_dir}=    Set Variable    ${DYNOMAX_RUN_DIR}${/}attempt-recorder${/}${DYNOMAX_STEP_ORDER}${/}${attempt}
    Create Directory    ${attempt_recorder_dir}
    ${attempt_recorder_stdout}=    Set Variable    ${attempt_recorder_dir}${/}stdout.log
    ${attempt_recorder_stderr}=    Set Variable    ${attempt_recorder_dir}${/}stderr.log
    ${invoke_status}    ${record_or_error}=    Run Keyword And Ignore Error    Run Process
    ...    ${DYNOMAX_POWERSHELL}
    ...    -NoLogo
    ...    -NoProfile
    ...    -ExecutionPolicy
    ...    Bypass
    ...    -File
    ...    ${DYNOMAX_ATTEMPT_RECORDER_SCRIPT}
    ...    -DynomaxRoot
    ...    ${DYNOMAX_ROOT}
    ...    -RunDirectory
    ...    ${DYNOMAX_RUN_DIR}
    ...    -RunId
    ...    ${DYNOMAX_RUN_ID}
    ...    -StepOrder
    ...    ${DYNOMAX_STEP_ORDER}
    ...    -StepId
    ...    ${DYNOMAX_STEP_ID}
    ...    -ActionKey
    ...    ${DYNOMAX_ACTION_ID}
    ...    -ActionVersion
    ...    ${DYNOMAX_RESOLVED_ACTION_VERSION}
    ...    -ActionVersionId
    ...    ${DYNOMAX_ACTION_VERSION_ID}
    ...    -AttemptNumber
    ...    ${attempt}
    ...    -StartedAtUtc
    ...    ${attempt_started}
    ...    -EndedAtUtc
    ...    ${attempt_ended}
    ...    -Status
    ...    ${attempt_status}
    ...    -MessageBase64
    ...    ${message64}
    ...    -RetryOnCsv
    ...    ${DYNOMAX_RETRY_ON_CSV}
    ...    -WaitBeforeExecutionSeconds
    ...    ${attempt_wait}
    ...    -DelayBeforeNextAttemptSeconds
    ...    ${proposed_delay}
    ...    -BrowserSessionDecision
    ...    ${DYNOMAX_BROWSER_SESSION_RETRY_MODE}
    ...    -EvidencePolicy
    ...    ${DYNOMAX_ATTEMPT_EVIDENCE_POLICY}
    ...    -IsFinalAttempt
    ...    ${forced_final}
    ...    -IsCleanup
    ...    ${is_cleanup}
    ...    -TimedOut
    ...    ${timed_out}
    ...    -SensitiveAction
    ...    ${DYNOMAX_SENSITIVE_ACTION}
    ...    -DeclaredClassification
    ...    ${declared_classification}
    ...    stdout=${attempt_recorder_stdout}
    ...    stderr=${attempt_recorder_stderr}
    ${record_stdout}=    Read Dynomax Optional Text File    ${attempt_recorder_stdout}
    ${record_stderr}=    Read Dynomax Optional Text File    ${attempt_recorder_stderr}
    IF    '${invoke_status}' != 'PASS'
        ${record_stderr}=    Evaluate    (str($record_stderr) + '; invocation=' + str($record_or_error))[:4000]
        RETURN    ${False}    ${None}    ${record_stdout}    ${record_stderr}
    END
    ${record}=    Set Variable    ${record_or_error}
    ${json_status}    ${record_data_or_error}=    Run Keyword And Ignore Error    Evaluate    json.loads($record_stdout)    modules=json
    ${exit_ok}=    Evaluate    int($record.rc) == 0
    IF    not ${exit_ok} or '${json_status}' != 'PASS'
        IF    '${json_status}' != 'PASS'
            ${record_stderr}=    Evaluate    (str($record_stderr) + '; json=' + str($record_data_or_error))[:4000]
        END
        RETURN    ${False}    ${None}    ${record_stdout}    ${record_stderr}
    END
    RETURN    ${True}    ${record_data_or_error}    ${record_stdout}    ${record_stderr}

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
    ${text}=    Get File    ${DYNOMAX_CONTEXT_PATH}
    ${context}=    Evaluate    json.loads($text)    modules=json
    RETURN    ${context}

Save Dynomax Context
    [Arguments]    ${context}
    ${text}=    Evaluate    json.dumps($context, indent=2, default=str)    modules=json
    Create File    ${DYNOMAX_CONTEXT_PATH}    ${text}

Get Dynomax Context Value
    [Arguments]    ${name}    ${default}=${None}
    ${context}=    Get Dynomax Context
    ${value}=    Evaluate    $context.get('values', {}).get($name, $default)
    RETURN    ${value}

Set Dynomax Context Value
    [Arguments]    ${name}    ${value}
    ${context}=    Get Dynomax Context
    Evaluate    $context.setdefault('values', {}).__setitem__($name, $value)
    Save Dynomax Context    ${context}

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

Persist Dynomax Explicit Robot Action Result
    [Arguments]    ${robot_status}    ${robot_message}
    ${message64}=    Evaluate    base64.b64encode(str($robot_message).encode('utf-8')).decode('ascii')    modules=base64
    IF    '${robot_status}' == 'FAIL' and not ${DYNOMAX_SENSITIVE_ACTION}
        ${safe_name}=    Evaluate    re.sub(r'[^A-Za-z0-9_.-]+','_', $DYNOMAX_ACTION_ID)    modules=re
        Run Keyword And Ignore Error    Take Screenshot    ${DYNOMAX_RUN_DIR}${/}screenshots${/}${DYNOMAX_STEP_ORDER}-${safe_name}.png
    END
    ${result}=    Run Process
    ...    ${DYNOMAX_POWERSHELL}
    ...    -NoLogo
    ...    -NoProfile
    ...    -ExecutionPolicy
    ...    Bypass
    ...    -File
    ...    ${DYNOMAX_PERSIST_SCRIPT}
    ...    -DynomaxRoot
    ...    ${DYNOMAX_ROOT}
    ...    -RunId
    ...    ${DYNOMAX_RUN_ID}
    ...    -StepOrder
    ...    ${DYNOMAX_STEP_ORDER}
    ...    -ActionKey
    ...    ${DYNOMAX_ACTION_ID}
    ...    -ActionVersionId
    ...    ${DYNOMAX_ACTION_VERSION_ID}
    ...    -RobotStatus
    ...    ${robot_status}
    ...    -MessageBase64
    ...    ${message64}
    ...    -IsCleanup
    ...    ${DYNOMAX_IS_CLEANUP}
    ...    -ContextPath
    ...    ${DYNOMAX_CONTEXT_PATH}
    ...    stdout=${DYNOMAX_RUN_DIR}${/}persist-${DYNOMAX_STEP_ORDER}.stdout.log
    ...    stderr=${DYNOMAX_RUN_DIR}${/}persist-${DYNOMAX_STEP_ORDER}.stderr.log
    Should Be Equal As Integers    ${result.rc}    0    Dynomax could not persist action result.

Persist Dynomax Robot Action Result
    ${metadata_ready}=    Get Variable Value    \${DYNOMAX_ACTION_METADATA_READY}    ${False}
    IF    not ${metadata_ready}
        Log    Dynomax Action metadata was not initialized; result persistence was skipped so the runtime failure is classified as ERROR.    WARN
        RETURN
    END
    ${control_flow_enabled}=    Get Variable Value    \${DYNOMAX_CONTROL_FLOW_ENABLED}    ${False}
    ${is_cleanup}=    Get Variable Value    \${DYNOMAX_IS_CLEANUP}    ${False}
    IF    ${control_flow_enabled} and not ${is_cleanup} and '${TEST_STATUS}' == 'FAIL'
        Fail Dynomax Control Flow Action    ${DYNOMAX_WORKFLOW_NODE_ID}
    END
    ${message64}=    Evaluate    base64.b64encode($TEST_MESSAGE.encode('utf-8')).decode('ascii')    modules=base64
    IF    '${TEST_STATUS}' == 'FAIL' and not ${DYNOMAX_SENSITIVE_ACTION}
        ${safe_name}=    Evaluate    re.sub(r'[^A-Za-z0-9_.-]+','_', $DYNOMAX_ACTION_ID)    modules=re
        Run Keyword And Ignore Error    Take Screenshot    ${DYNOMAX_RUN_DIR}${/}screenshots${/}${DYNOMAX_STEP_ORDER}-${safe_name}.png
    END
    ${result}=    Run Process
    ...    ${DYNOMAX_POWERSHELL}
    ...    -NoLogo
    ...    -NoProfile
    ...    -ExecutionPolicy
    ...    Bypass
    ...    -File
    ...    ${DYNOMAX_PERSIST_SCRIPT}
    ...    -DynomaxRoot
    ...    ${DYNOMAX_ROOT}
    ...    -RunId
    ...    ${DYNOMAX_RUN_ID}
    ...    -StepOrder
    ...    ${DYNOMAX_STEP_ORDER}
    ...    -ActionKey
    ...    ${DYNOMAX_ACTION_ID}
    ...    -ActionVersionId
    ...    ${DYNOMAX_ACTION_VERSION_ID}
    ...    -RobotStatus
    ...    ${TEST_STATUS}
    ...    -MessageBase64
    ...    ${message64}
    ...    -IsCleanup
    ...    ${DYNOMAX_IS_CLEANUP}
    ...    -ContextPath
    ...    ${DYNOMAX_CONTEXT_PATH}
    ...    stdout=${DYNOMAX_RUN_DIR}${/}persist-${DYNOMAX_STEP_ORDER}.stdout.log
    ...    stderr=${DYNOMAX_RUN_DIR}${/}persist-${DYNOMAX_STEP_ORDER}.stderr.log
    Should Be Equal As Integers    ${result.rc}    0    Dynomax could not persist action result.
