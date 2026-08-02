*** Settings ***
Resource    ../../Project-And-Config/Robot/ATX-D2B.Common.resource

*** Keywords ***
ATX Run D2B Bounded Recovery
    ATX D2B Ensure Exact Profile Open
    ATX D2B Active Sample Should Be Available    BoundedRecovery
    ATX D2B Open Detailed Statement Section    validation-rules
    ATX D2B Normalize Validation Rules
    ATX D2B Configure Validation Rule    ProviderSuccess    BlockPublication    ${EMPTY}
    ATX D2B Configure Validation Rule    MinimumOcrConfidence    RequiresReview    100
    ATX D2B Configure Validation Rule    MinimumRowCount    RequiresReview    4
    ATX D2B Open Detailed Statement Section    recovery-strategy
    ATX D2B Ensure Checkbox State    css=#RecoveryEnabled    ${True}
    Fill Text    css=#RecoveryMaximumAttempts    3
    Fill Text    css=#RecoveryMaximumElapsedSeconds    300
    Fill Text    css=#RecoveryPerAttemptTimeoutSeconds    90
    Fill Text    css=#RecoveryMinimumAcceptedRowCount    4
    ATX D2B Ensure Checkbox State    css=#RecoveryRetryOnRequiresReview    ${True}
    ATX D2B Ensure Checkbox State    css=#RecoveryStopAnchors    ${False}
    ATX D2B Ensure Checkbox State    css=#RecoveryStopConfidence    ${True}
    ATX D2B Ensure Checkbox State    css=#RecoveryStopColumns    ${False}
    ATX D2B Ensure Checkbox State    css=#RecoveryStopBalance    ${False}
    ATX D2B Ensure Checkbox State    css=#RecoveryStopRows    ${True}
    ATX D2B Normalize Recovery Attempts To Zero
    Click    css=#addRecoveryAttempt
    Click    css=#addRecoveryAttempt
    Wait Until Keyword Succeeds    5s    100ms    ATX D2B Recovery Attempt Count Should Be    2
    ATX D2B Configure Recovery Attempt    0    Screenshot retry    Screenshot    SingleBlock    300
    ATX D2B Configure Recovery Attempt    1    High contrast retry    HighContrast    SparseText    300
    ${strategy_json}=    Get Property    css=#RetryStrategyJson    value
    ${valid}=    Evaluate    len(json.loads($strategy_json).get('attempts',[])) == 2 and json.loads($strategy_json).get('maximumAttempts') == 3    modules=json
    IF    not ${valid}
        Fail Dynomax Action    TEST_INVALID    Visible recovery editor did not serialize two retries and maximumAttempts=3.
    END
    ${action}=    ATX D2B Resolve Advanced Extraction Action
    Set Browser Timeout    360s
    Click    ${action}
    ${done}=    Run Keyword And Return Status    Wait Until Keyword Succeeds    360s    500ms    ATX D2B Statement Ajax Should Be Idle
    Set Browser Timeout    30s
    IF    not ${done}
        Fail Dynomax Action    FAIL    Bounded recovery extraction did not complete within 360 seconds.
    END
    ATX D2B Wait For Statement Profile Initialization
    ATX D2B Resolve Statement Ajax Outcome    BoundedRecovery
    ATX D2B Open Detailed Statement Section    test-results
    Click    css=button[data-bs-target="#resultRecovery"]:visible
    Wait Until Keyword Succeeds    20s    250ms    ATX D2B Recovery History Should Be Complete
    ${total}=    Get Element Count    css=#resultRecovery .statement-recovery-history-item
    ${notrun}=    Get Element Count    css=#resultRecovery .statement-recovery-history-item.is-notrun
    ${accepted}=    Get Element Count    css=#resultRecovery .statement-recovery-history-item.is-accepted
    ${executed}=    Evaluate    int($total)-int($notrun)
    ${extract}=    ATX D2B Get Extraction Run Count
    IF    ${total} != 3 or ${executed} != 3 or ${accepted} != 1 or ${extract} != 2
        Fail Dynomax Action    FAIL    Recovery total=${total}, executed=${executed}, accepted=${accepted}, extractionRuns=${extract}; expected 3/3/1/2.
    END
    Set Dynomax Context Value    d2bBoundedRecoveryVerified    ${True}
    Set Dynomax Context Value    d2bRecoveryHistoryTotal    ${total}
    Set Dynomax Context Value    d2bRecoveryAttemptsExecuted    ${executed}
    Set Dynomax Context Value    d2bRecoveryAttemptsNotRun    ${notrun}
    Set Dynomax Context Value    d2bRecoveryAcceptedResults    ${accepted}
    Set Dynomax Context Value    d2bRecoveryExtractionRunsTotal    ${extract}
