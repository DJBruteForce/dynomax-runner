*** Settings ***
Resource    ../../Project-And-Config/Robot/ATX-D2B.Common.resource

*** Keywords ***
ATX Prepare D2B Image Without Extraction
    ATX D2B Ensure Exact Profile Open
    ${sample}=    Set Variable    ${DYNOMAX_ROOT}${/}Project-Setup${/}ATX-Solutions${/}Project-And-Config${/}Test-Workspace${/}Samples${/}ATX_Phase25H_D2B_OCR_Statement.png
    ${exists}=    Evaluate    os.path.isfile($sample) and os.path.getsize($sample) > 0    modules=os
    IF    not ${exists}
        Fail Dynomax Action    TEST_INVALID    Packaged OCR sample is missing or empty: ${sample}
    END
    ATX D2B Open Detailed Statement Section    source-sample
    Click    css=button.statement-source-card[data-source-type="Image"]:visible
    ${source}=    Get Property    css=#SampleSourceType    value
    Should Be Equal    ${source}    Image
    ATX D2B Set OCR Mode    Force
    Upload File By Selector    css=#SampleEvidence    ${sample}
    ${files}=    Evaluate JavaScript    css=#SampleEvidence    (input) => input.files ? input.files.length : 0
    Should Be Equal As Integers    ${files}    1
    Set Dynomax Context Value    d2bSampleStaged    ${True}
    Set Dynomax Context Value    d2bSampleCleared    ${False}
    Set Dynomax Context Value    d2bCurrentSampleType    Image
    ATX D2B Open Detailed Statement Section    image-source
    Select Options By    css=#FormImageType    value    Screenshot
    Select Options By    css=#Form_OcrRenderDpi    value    300
    ATX D2B Select Installed OCR Language
    ATX D2B Select Installed OCR Provider
    ATX D2B Open Detailed Statement Section    image-preparation
    ATX D2B Ensure Checkbox State    css=#PreprocessingEnabled    ${True}
    Click    css=button[data-preprocessing-preset="StandardDocument"]:visible
    ${preset}=    Get Property    css=#PreprocessingPreset    value
    Should Be Equal    ${preset}    StandardDocument
    ${before_extract}=    ATX D2B Get Extraction Run Count
    ${before_remap}=    ATX D2B Get Remap Run Count
    Should Be Equal As Integers    ${before_extract}    0
    Should Be Equal As Integers    ${before_remap}    0
    ${prepare}=    Set Variable    css=#image-preparation button[formaction*="handler=PrepareImage"]:visible
    ${prepare_count}=    Get Element Count    ${prepare}
    IF    ${prepare_count} != 1
        Fail Dynomax Action    TEST_INVALID    Prepare Preview action resolved to ${prepare_count} visible controls.
    END
    Click    ${prepare}
    Wait Until Keyword Succeeds    120s    500ms    ATX D2B Statement Ajax Should Be Idle
    ATX D2B Wait For Statement Profile Initialization
    ATX D2B Resolve Statement Ajax Outcome    PrepareImage
    ATX D2B Open Detailed Statement Section    anchors-noise
    Wait Until Keyword Succeeds    60s    500ms    ATX D2B Prepared Image Should Be Fully Loaded
    ${extract}=    ATX D2B Get Extraction Run Count
    ${remap}=    ATX D2B Get Remap Run Count
    IF    ${extract} != 0 or ${remap} != 0
        Fail Dynomax Action    FAIL    Prepare Preview changed counters to extraction=${extract}, remap=${remap}; expected 0/0.
    END
    ${dims}=    Evaluate JavaScript    css=#ocrPreparedImage    (img) => String(img.naturalWidth) + "x" + String(img.naturalHeight)
    Set Dynomax Context Value    d2bImagePreparationVerified    ${True}
    Set Dynomax Context Value    d2bPreparedImageDimensions    ${dims}
    Set Dynomax Context Value    d2bPreparationExtractionRuns    ${extract}
    Set Dynomax Context Value    d2bPreparationRemapRuns    ${remap}
