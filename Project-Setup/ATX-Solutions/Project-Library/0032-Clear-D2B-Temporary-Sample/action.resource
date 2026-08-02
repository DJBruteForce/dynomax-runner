*** Settings ***
Resource    ../../Project-And-Config/Robot/ATX-D2B.Common.resource

*** Keywords ***
ATX Clear D2B Temporary Sample
    ${profile_created}=    Get Dynomax Context Value    statementProfileCreated    ${False}
    IF    not ${profile_created}
        Set Dynomax Context Value    d2bSampleCleared    ${True}
        Set Dynomax Context Value    d2bSampleStaged    ${False}
        RETURN
    END
    ATX D2B Ensure Exact Profile Open
    ${token}=    Get Property    css=#statementProfileForm input[name="SampleCacheToken"]    value
    ${file}=    Get Property    css=#SampleEvidence    value
    IF    $token == '' and $file == ''
        Set Dynomax Context Value    d2bSampleCleared    ${True}
        Set Dynomax Context Value    d2bSampleStaged    ${False}
        Set Dynomax Context Value    d2bCurrentSampleType    ${EMPTY}
        RETURN
    END
    ATX D2B Open Detailed Statement Section    image-preparation
    ${clear}=    Set Variable    css=#image-preparation button[formaction*="handler=ClearSample"]:visible
    ${count}=    Get Element Count    ${clear}
    IF    ${count} != 1
        Fail Dynomax Action    FAIL    Clear temporary sample action resolved to ${count} controls.
    END
    Click    ${clear}
    Wait Until Keyword Succeeds    60s    500ms    ATX D2B Statement Ajax Should Be Idle
    ATX D2B Resolve Statement Ajax Outcome    ClearSample
    Wait Until Keyword Succeeds    30s    250ms    ATX D2B No Temporary Sample Should Remain
    Set Dynomax Context Value    d2bSampleCleared    ${True}
    Set Dynomax Context Value    d2bSampleStaged    ${False}
    Set Dynomax Context Value    d2bCurrentSampleType    ${EMPTY}

ATX D2B No Temporary Sample Should Remain
    ${token}=    Get Property    css=#statementProfileForm input[name="SampleCacheToken"]    value
    ${file}=    Get Property    css=#SampleEvidence    value
    Should Be Empty    ${token}
    Should Be Empty    ${file}
