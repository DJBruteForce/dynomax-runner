*** Settings ***
Resource    ../../Project-And-Config/Robot/ATX-D2B.Common.resource

*** Keywords ***
ATX Run D2B Image OCR Processing
    ATX D2B Ensure Exact Profile Open
    ATX D2B Active Sample Should Be Available    ImageOcr
    ${action}=    ATX D2B Resolve Advanced Extraction Action
    Set Browser Timeout    240s
    Click    ${action}
    Wait Until Keyword Succeeds    240s    500ms    ATX D2B Statement Ajax Should Be Idle
    Set Browser Timeout    30s
    ATX D2B Wait For Statement Profile Initialization
    ATX D2B Resolve Statement Ajax Outcome    ImageOcr
    ATX D2B Open Detailed Statement Section    test-results
    Wait For Elements State    css=#test-results .statement-test-summary-grid:visible    visible    timeout=30s
    ${mode}=    ATX D2B Read Result Extraction Mode
    IF    $mode != 'Ocr'
        Fail Dynomax Action    FAIL    OCR result mode was ${mode}; expected Ocr.
    END
    ${pages}=    ATX D2B Read Summary Metric    Pages processed
    ${extract}=    ATX D2B Get Extraction Run Count
    ${remap}=    ATX D2B Get Remap Run Count
    IF    ${pages} != 1 or ${extract} != 1 or ${remap} != 0
        Fail Dynomax Action    FAIL    Image OCR pages=${pages}, extraction=${extract}, remap=${remap}; expected 1/1/0.
    END
    Set Dynomax Context Value    d2bOcrVerified    ${True}
    Set Dynomax Context Value    d2bOcrUnits    ${pages}
    Set Dynomax Context Value    d2bOcrExtractionRuns    ${extract}
    Set Dynomax Context Value    d2bOcrRemapRuns    ${remap}
