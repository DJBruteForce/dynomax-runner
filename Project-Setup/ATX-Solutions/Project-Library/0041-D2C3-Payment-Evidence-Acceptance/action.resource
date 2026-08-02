*** Settings ***
Resource    ../../Project-And-Config/Robot/ATX-D2C3.Common.resource

*** Keywords ***
ATX Verify D2C3 Payment Evidence Acceptance
    ATX D2C3 Progress    1    10    START    Payment Evidence acceptance started.
    ${sample}=    Set Variable    ${DYNOMAX_ROOT}${/}Project-Setup${/}ATX-Solutions${/}Project-And-Config${/}Test-Workspace${/}Samples${/}ATX_Phase25H_D2C3_Payment_Evidence.csv
    File Should Exist    ${sample}
    ${profile_name}=    Generate D2c3 Unique Name    Dynomax D2C3 Payment Evidence
    Set Dynomax Context Value    d2c3PaymentEvidenceProfileName    ${profile_name}
    Set Dynomax Context Value    d2c3PaymentEvidenceProfileDeleted    ${False}
    Set Dynomax Context Value    d2c3PaymentEvidenceBatchDeleted    ${False}
    ATX D2C3 Progress    2    10    RUNNING    Opening Payment Evidence profiles.
    Go To    ${DYNOMAX_BASE_URL}Banking/PaymentEvidence?activeEvidenceTab=profiles
    Wait For Elements State    css=#pane-sub-profiles    visible    timeout=30s
    ATX D2C3 Capture Current Page    payment-evidence-profiles-start
    ${new}=    Set Variable    css=#pane-sub-profiles button[data-bs-target="#paymentEvidenceProfileModal"][data-profile-mode="new"]:visible
    ATX D2C3 Require Exact Count    ${new}    1    New Payment Evidence profile action
    ATX D2C3 Safe Click    ${new}
    Wait For Elements State    css=#paymentEvidenceProfileModal:visible    visible    timeout=15s
    Fill Text    css=#PaymentEvidenceProfileForm_ProfileName    ${profile_name}
    Upload File By Selector    css=#paymentEvidenceProfilePreviewFile    ${sample}
    ATX D2C3 Safe Click    css=#paymentEvidenceProfilePreviewButton
    Wait For Elements State    css=#paymentEvidenceProfilePreviewArea    visible    timeout=30s
    ATX D2C3 Capture Current Page    payment-evidence-profile-mapper-preview
    ATX D2C3 Progress    3    10    PASS    Sample CSV exposed the mapping preview.
    ${mapper_count}=    Get Element Count    css=#paymentEvidenceProfileMapperTable .payment-evidence-profile-mapper-select
    IF    ${mapper_count} != 12
        Fail Dynomax Action    FAIL    Payment Evidence mapper exposed ${mapper_count} columns instead of 12.
    END
    ATX D2C3 Safe Click    css=#paymentEvidenceDuplicateHeading button
    Wait For Elements State    css=#paymentEvidenceDuplicateRules    visible    timeout=10s
    Select Options By    css=#PaymentEvidenceProfileForm_DuplicateAction    value    Warn
    ATX D2C3 Safe Click    css=#paymentEvidenceProfileFormElement button[type="submit"]:visible
    Wait For Elements State    css=#pane-sub-profiles    visible    timeout=30s
    ATX D2C3 Capture Current Page    payment-evidence-profile-saved
    ${row}=    ATX D2C3 Exact Payment Profile Row    ${profile_name}
    Wait Until Keyword Succeeds    20s    250ms    ATX D2C3 Require Exact Count    ${row}    1    Saved Payment Evidence profile
    ${edit}=    Set Variable    ${row} >> css=a[href*="paymentEvidenceProfileId="]
    ${href}=    Get Attribute    ${edit}    href
    ${ids}=    Get Regexp Matches    ${href}    (?i)paymentEvidenceProfileId=([0-9a-f-]{36})    1
    Length Should Be    ${ids}    1
    ${profile_id}=    Get From List    ${ids}    0
    Set Dynomax Context Value    d2c3PaymentEvidenceProfileId    ${profile_id}
    Set Dynomax Context Value    d2c3PaymentEvidenceProfileCreated    ${True}
    ATX D2C3 Progress    4    10    PASS    Disposable Payment Evidence profile was saved and resolved by exact ID.
    Go To    ${DYNOMAX_BASE_URL}Banking/PaymentEvidence?activeEvidenceTab=import
    Wait For Elements State    css=form[action*="handler=UploadPreview"] select[name="PreviewProfileId"]:visible    visible    timeout=30s
    ATX D2C3 Capture Current Page    payment-evidence-import-upload
    Select Options By    css=form[action*="handler=UploadPreview"] select[name="PreviewProfileId"]:visible    value    ${profile_id}
    ${operation_id}=    Get Property    css=#PreviewOperationId    value
    Should Not Be Empty    ${operation_id}
    Set Dynomax Context Value    d2c3PaymentEvidenceOperationId    ${operation_id}
    Upload File By Selector    css=#PreviewFile    ${sample}
    ATX D2C3 Progress    5    10    RUNNING    Submitting the first Payment Evidence preview.
    ATX D2C3 Safe Click    css=form[action*="handler=UploadPreview"] button[type="submit"]:visible
    ${card}=    ATX D2C3 Wait For Payment Evidence Preview Or Fail    payment-evidence-preview-first
    ATX D2C3 Progress    6    10    PASS    First Payment Evidence preview returned a recognized success state.
    Select Options By    css=form[action*="handler=UploadPreview"] select[name="PreviewProfileId"]:visible    value    ${profile_id}
    Upload File By Selector    css=#PreviewFile    ${sample}
    Evaluate JavaScript    css=#PreviewOperationId    (input) => { input.value='${operation_id}'; }
    ${retry_operation}=    Get Property    css=#PreviewOperationId    value
    Should Be Equal    ${retry_operation}    ${operation_id}
    ATX D2C3 Progress    7    10    RUNNING    Replaying the preview with the original operation ID.
    ATX D2C3 Safe Click    css=form[action*="handler=UploadPreview"] button[type="submit"]:visible
    ${card}=    ATX D2C3 Wait For Payment Evidence Preview Or Fail    payment-evidence-preview-repeated
    ATX D2C3 Progress    8    10    PASS    Repeated preview returned a recognized success state under the original operation.
    ${header}=    Get Text    ${card} >> css=.card-header
    Should Contain    ${header}    5 row(s) detected
    ${execute}=    Set Variable    ${card} >> css=form[action*="handler=ExecuteImport"] button[type="submit"]:visible
    ATX D2C3 Require Exact Count    ${execute}    1    Payment Evidence Execute Import action
    ATX D2C3 Progress    9    10    RUNNING    Executing the exact Payment Evidence import.
    ATX D2C3 Safe Click    ${execute}
    Wait For Elements State    css=#paymentEvidenceBatchWorkspace    visible    timeout=45s
    ATX D2C3 Capture Current Page    payment-evidence-import-result
    ${url}=    Get Url
    ${batch_ids}=    Get Regexp Matches    ${url}    (?i)[?&]id=([0-9a-f-]{36})    1
    Length Should Be    ${batch_ids}    1
    ${batch_id}=    Get From List    ${batch_ids}    0
    Set Dynomax Context Value    d2c3PaymentEvidenceBatchId    ${batch_id}
    Set Dynomax Context Value    d2c3PaymentEvidenceBatchCreated    ${True}
    ${rows}=    Get Text    xpath=//div[contains(concat(' ',normalize-space(@class),' '),' pe-kpi-pill ')][.//div[normalize-space()='Rows']]//div[contains(concat(' ',normalize-space(@class),' '),' fw-semibold ')]
    Should Be Equal    ${rows}    5
    ${batch_deleted_now}=    ATX D2C3 Delete Payment Evidence Batch If Present    ${batch_id}
    Should Be True    ${batch_deleted_now}
    Set Dynomax Context Value    d2c3PaymentEvidenceBatchDeleted    ${True}
    Set Dynomax Context Value    d2c3PaymentEvidenceBatchAbsent    ${True}
    ${profile_deleted_now}=    ATX D2C3 Delete Payment Evidence Profile If Present    ${profile_name}    ${profile_id}
    Should Be True    ${profile_deleted_now}
    Set Dynomax Context Value    d2c3PaymentEvidenceProfileDeleted    ${True}
    Set Dynomax Context Value    d2c3PaymentEvidenceProfileAbsent    ${True}
    Set Dynomax Context Value    d2c3PaymentEvidenceOperationStable    ${True}
    Set Dynomax Context Value    d2c3PaymentEvidenceAccepted    ${True}
    ATX D2C3 Progress    10    10    PASS    Payment Evidence preview, repeated preview, import and exact cleanup passed.
