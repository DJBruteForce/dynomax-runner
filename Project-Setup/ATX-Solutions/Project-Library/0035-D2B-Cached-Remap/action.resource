*** Settings ***
Resource    ../../Project-And-Config/Robot/ATX-D2B.Common.resource

*** Keywords ***
ATX Run D2B Cached Remap Without OCR
    ATX D2B Ensure Exact Profile Open
    ATX D2B Active Sample Should Be Available    CachedRemap
    ${before_extract}=    ATX D2B Get Extraction Run Count
    ${before_remap}=    ATX D2B Get Remap Run Count
    ATX D2B Open Detailed Statement Section    ordering-duplicates
    ${current}=    Get Property    css=#Form_SkipSummaryRows    checked
    ${target}=    Evaluate    not bool($current)
    ATX D2B Ensure Checkbox State    css=#Form_SkipSummaryRows    ${target}
    ATX D2B Open Detailed Statement Section    test-results
    Wait Until Keyword Succeeds    10s    250ms    ATX D2B Canonical Remap Action Should Be Enabled
    ${action}=    Set Variable    css=#test-results .statement-test-lab-actions button[formaction*="handler=Remap"]:visible
    Click    ${action}
    Wait Until Keyword Succeeds    120s    500ms    ATX D2B Statement Ajax Should Be Idle
    ATX D2B Wait For Statement Profile Initialization
    ATX D2B Resolve Statement Ajax Outcome    CachedRemap
    Wait Until Keyword Succeeds    4s    100ms    ATX D2B Visible Ajax Feedback Should Contain    without rerunning OCR
    ${feedback}=    ATX D2B Read Visible Ajax Feedback
    ATX D2B Open Detailed Statement Section    test-results
    ${after_extract}=    ATX D2B Get Extraction Run Count
    ${after_remap}=    ATX D2B Get Remap Run Count
    IF    ${after_extract} != ${before_extract} or ${after_remap} != ${before_remap + 1}
        Fail Dynomax Action    FAIL    Cached Remap counters changed from ${before_extract}/${before_remap} to ${after_extract}/${after_remap}; expected unchanged extraction and one Remap.
    END
    Set Dynomax Context Value    d2bCachedRemapVerified    ${True}
    Set Dynomax Context Value    d2bCachedRemapExtractionBefore    ${before_extract}
    Set Dynomax Context Value    d2bCachedRemapExtractionAfter    ${after_extract}
    Set Dynomax Context Value    d2bCachedRemapRunsBefore    ${before_remap}
    Set Dynomax Context Value    d2bCachedRemapRunsAfter    ${after_remap}
    Set Dynomax Context Value    d2bCachedRemapDidNotRerunOcr    ${True}
