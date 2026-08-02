*** Settings ***
Resource    ../../Project-And-Config/Robot/ATX-D2B.Common.resource

*** Keywords ***
ATX Run D2B Direct Text Processing
    ATX D2B Ensure Exact Profile Open
    ${sample}=    Set Variable    ${DYNOMAX_ROOT}${/}Project-Setup${/}ATX-Solutions${/}Project-And-Config${/}Test-Workspace${/}Samples${/}ATX_Phase25H_D2B_Direct_Text_Statement.pdf
    ${exists}=    Evaluate    os.path.isfile($sample) and os.path.getsize($sample) > 0    modules=os
    IF    not ${exists}
        Fail Dynomax Action    TEST_INVALID    Packaged direct-text sample is missing or empty: ${sample}
    END
    ATX D2B Open Detailed Statement Section    source-sample
    Click    css=button.statement-source-card[data-source-type="SelectablePdf"]:visible
    ${source}=    Get Property    css=#SampleSourceType    value
    Should Be Equal    ${source}    SelectablePdf
    ATX D2B Set OCR Mode    Off
    Upload File By Selector    css=#SampleEvidence    ${sample}
    ${files}=    Evaluate JavaScript    css=#SampleEvidence    (input) => input.files ? input.files.length : 0
    Should Be Equal As Integers    ${files}    1
    Set Dynomax Context Value    d2bSampleStaged    ${True}
    Set Dynomax Context Value    d2bSampleCleared    ${False}
    Set Dynomax Context Value    d2bCurrentSampleType    DirectTextPdf
    ${action}=    ATX D2B Resolve Advanced Extraction Action
    Set Browser Timeout    180s
    Click    ${action}
    Wait Until Keyword Succeeds    180s    500ms    ATX D2B Statement Ajax Should Be Idle
    Set Browser Timeout    30s
    ATX D2B Wait For Statement Profile Initialization
    ATX D2B Resolve Statement Ajax Outcome    DirectText
    ATX D2B Open Detailed Statement Section    test-results
    Wait For Elements State    css=#test-results .statement-test-summary-grid:visible    visible    timeout=30s
    ATX D2B Verify Test Lab Status Layout
    ${mode}=    ATX D2B Read Result Extraction Mode
    IF    $mode != 'DirectText'
        Fail Dynomax Action    FAIL    Direct-text result mode was ${mode}; expected DirectText.
    END
    ${pages}=    ATX D2B Read Summary Metric    Pages processed
    ${extract}=    ATX D2B Get Extraction Run Count
    ${remap}=    ATX D2B Get Remap Run Count
    IF    ${pages} != 1 or ${extract} != 1 or ${remap} != 0
        Fail Dynomax Action    FAIL    Direct-text result pages=${pages}, extraction=${extract}, remap=${remap}; expected 1/1/0.
    END
    Set Dynomax Context Value    d2bDirectTextVerified    ${True}
    Set Dynomax Context Value    d2bDirectTextPages    ${pages}
    Set Dynomax Context Value    d2bDirectTextExtractionRuns    ${extract}
    Set Dynomax Context Value    d2bDirectTextRemapRuns    ${remap}
    Set Dynomax Context Value    d2bDirectTextOcrNotUsed    ${True}
