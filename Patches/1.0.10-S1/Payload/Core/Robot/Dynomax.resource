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
        Fill Secret    ${selector}    ${secret_value}
    FINALLY
        Set Log Level    ${previous_log_level}
    END

Persist Dynomax Robot Action Result
    ${message64}=    Evaluate    base64.b64encode($TEST_MESSAGE.encode('utf-8')).decode('ascii')    modules=base64
    IF    '${TEST_STATUS}' == 'FAIL'
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
