*** Settings ***
Library    Browser
Library    OperatingSystem
Library    Process
Library    Collections

*** Keywords ***
Start Dynomax Browser
    Create Directory    ${DYNOMAX_RUN_DIR}${/}screenshots
    New Browser    ${DYNOMAX_BROWSER}    headless=${DYNOMAX_HEADLESS}
    New Context    viewport=${DYNOMAX_VIEWPORT}
    New Page    about:blank

Stop Dynomax Browser
    Run Keyword And Ignore Error    Close Browser

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
                ${attempt_status}    ${attempt_message}=    Run Keyword And Ignore Error    Run Keyword With Timeout    ${effective_timeout}s    ${keyword_name}
            FINALLY
                Set Log Level    ${previous_log_level}
            END
        ELSE
            ${attempt_status}    ${attempt_message}=    Run Keyword And Ignore Error    Run Keyword With Timeout    ${effective_timeout}s    ${keyword_name}
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
        ${record}=    Run Process
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
        ...    -SensitiveAction
        ...    ${DYNOMAX_SENSITIVE_ACTION}
        ...    -DeclaredClassification
        ...    ${declared_classification}
        Should Be Equal As Integers    ${record.rc}    0    Dynomax could not persist execution-attempt evidence.
        ${record_data}=    Evaluate    json.loads($record.stdout)    modules=json
        ${retryable}=    Evaluate    bool($record_data.get('retryable', False))
        IF    '${attempt_status}' == 'PASS'
            RETURN
        END
        IF    not ${retryable}
            IF    ${DYNOMAX_SENSITIVE_ACTION}
                Fail    Sensitive Action failed; detailed message suppressed.
            ELSE
                Fail    ${attempt_message}
            END
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

Persist Dynomax Robot Action Result
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
