# D2-C3 Guided Banking action v6 avoids Robot object variables inside nested Python generator scopes.
*** Settings ***
Resource    ../../Project-And-Config/Robot/ATX-D2C3.Common.resource

*** Keywords ***
ATX Verify D2C3 Guided Banking Acceptance
    ATX D2C3 Progress    1    3    START    Guided Banking website acceptance started.
    ${account}=    Get Dynomax Context Value    targetBankAccount    ATX UI TEST BANK
    ${profile}=    ATX D2C3 Read Optional Context    d2c3StructuredProfileName
    ${sample}=    ATX D2C3 Read Optional Context    d2c3GuidedSamplePath
    ${sample_name}=    ATX D2C3 Read Optional Context    d2c3GuidedSampleName
    IF    $profile == '' or $sample == '' or $sample_name == ''
        Fail Dynomax Action    BLOCKED    Guided Banking prerequisites were not prepared. The reusable Structured profile and Guided CSV fixture are required.
    END
    File Should Exist    ${sample}
    Go To    ${DYNOMAX_BASE_URL}Banking/Imports?activeTab=guided&currentStep=1
    Wait For Elements State    css=#pane-guided    attached    timeout=30s
    ATX D2C3 Capture Current Page    guided-import-entry
    ${active}=    Evaluate JavaScript    css=html    (element) => window.__importSession || null
    IF    $active is not None
        ${schema_valid}=    Evaluate    set(['id','step','status','selectedProfileId','selectedBankAccountId','originalFileName','storedFileName','hasPersistedFile','hasOwnerScopedArtifact','hasPreview','hasValidation']).issubset(set($active.keys()))
        IF    not ${schema_valid}
            Fail Dynomax Action    TEST_INVALID    Guided Import session JSON did not match the certified serializer schema.
        END
        ${existing_name}=    Evaluate    str($active.get('originalFileName') or '')
        ${existing_id}=    Evaluate    str($active.get('id') or '')
        ${ours}=    Evaluate    'ATX_D2C3_' in $existing_name
        IF    ${ours}
            ATX D2C3 Abandon Guided Session If Present    ${existing_id}
        ELSE
            Fail Dynomax Action    BLOCKED    An unrelated Guided Import session is active. Complete or cancel it before D2-C3 acceptance.
        END
    END
    Go To    ${DYNOMAX_BASE_URL}Banking/Imports?activeTab=guided&currentStep=1
    Wait For Elements State    css=#stepPane1    visible    timeout=30s
    ATX D2C3 Capture Current Page    guided-step-1-account-profile
    ${account_option}=    Set Variable    xpath=//select[@id='guidedBankAccount']/option[starts-with(normalize-space(.),'${account}')]
    ATX D2C3 Require Exact Count    ${account_option}    1    Guided test bank account option
    ${account_id}=    Get Attribute    ${account_option}    value
    Select Options By    css=#guidedBankAccount    value    ${account_id}
    ${profile_text}=    Get Text    css=#guidedProfile
    ${profile_present}=    Evaluate    str($profile) in str($profile_text)
    IF    not ${profile_present}
        Fail Dynomax Action    BLOCKED    The exact Published Structured profile '${profile}' is absent from the Guided Import profile control.
    END
    Select Options By    css=#guidedProfile    label    ${profile}
    ${profile_id}=    Get Property    css=#guidedProfile    value
    ${selected_profile_text}=    Get Text    css=#guidedProfile option:checked
    ${selected_profile_scope}=    Get Attribute    css=#guidedProfile option:checked    data-profile-scope
    Should Be Equal    ${selected_profile_text}    ${profile}
    Should Be Equal    ${selected_profile_scope}    user
    Should Not Be Empty    ${profile_id}
    Wait Until Keyword Succeeds    10s    250ms    ATX D2C3 Guided Next Should Be Enabled
    ATX D2C3 Safe Click    css=#btnStep1Next
    Wait For Elements State    css=#stepPane2    visible    timeout=30s
    ATX D2C3 Capture Current Page    guided-step-2-file
    ${session}=    Evaluate JavaScript    css=html    (element) => window.__importSession || null
    ${session_schema_valid}=    Evaluate    $session is not None and set(['id','step','status','selectedProfileId','selectedBankAccountId','originalFileName','storedFileName','hasPersistedFile','hasOwnerScopedArtifact','hasPreview','hasValidation']).issubset(set($session.keys()))
    IF    not ${session_schema_valid}
        Fail Dynomax Action    TEST_INVALID    Guided Import did not expose the certified session JSON schema after Start Session.
    END
    ${session_id}=    Evaluate    str($session.get('id') or '')
    ${session_step}=    Evaluate    int($session.get('step'))
    Should Be Equal As Integers    ${session_step}    2
    Should Not Be Empty    ${session_id}
    Set Dynomax Context Value    d2c3GuidedSessionId    ${session_id}
    Upload File By Selector    css=#guidedFile    ${sample}
    ATX D2C3 Safe Click    css=#btnStep2Next
    Wait Until Keyword Succeeds    90s    500ms    ATX D2C3 Guided Upload Outcome Should Exist
    ATX D2C3 Capture Current Page    guided-upload-outcome
    ${review}=    Get Element Count    css=#pdfExtractionReviewForm:visible
    IF    ${review} == 1
        ${review_session}=    Get Property    css=#SessionId    value
        Should Be Equal    ${review_session}    ${session_id}
        ${accept_warnings}=    Get Element Count    css=#AcceptWarnings:visible
        IF    ${accept_warnings} == 1
            ${checked}=    Get Property    css=#AcceptWarnings    checked
            IF    not ${checked}
                ATX D2C3 Safe Click    css=#AcceptWarnings
            END
        END
        ${accept}=    Set Variable    css=#pdfReviewAcceptButton:visible
        ATX D2C3 Require Exact Count    ${accept}    1    Guided Extraction Review accept action
        ATX D2C3 Safe Click    ${accept}
    END
    Wait For Elements State    css=#stepPane3    visible    timeout=60s
    ATX D2C3 Capture Current Page    guided-step-3-preview
    ${session3}=    Get Property    css=#step3AdvanceForm input[name="sessionId"]    value
    Should Be Equal    ${session3}    ${session_id}
    ATX D2C3 Safe Click    css=#step3AdvanceForm button[name="targetStep"][value="4"]:visible
    Wait For Elements State    css=#stepPane4    visible    timeout=45s
    ATX D2C3 Capture Current Page    guided-step-4-validation
    ${ready}=    Get Element Count    css=.bank-import-validation-ready:visible
    IF    ${ready} != 1
        ${feedback}=    ATX D2C3 Visible Feedback
        Fail Dynomax Action    FAIL    Guided structured validation did not become ready. ${feedback}
    END
    ${disabled}=    Get Property    css=#btnStep4Next    disabled
    IF    ${disabled}
        Fail Dynomax Action    FAIL    Guided Continue action remained disabled after valid preview.
    END
    ATX D2C3 Safe Click    css=#btnStep4Next
    Wait For Elements State    css=#stepPane5    visible    timeout=30s
    ATX D2C3 Capture Current Page    guided-step-5-summary
    ${session5}=    Get Property    css=#guidedImportForm input[name="sessionId"]    value
    Should Be Equal    ${session5}    ${session_id}
    ATX D2C3 Safe Click    css=#btnConfirmImport
    Wait For Elements State    css=#historyListView    visible    timeout=60s
    ATX D2C3 Capture Current Page    guided-import-history-result
    ${row}=    Set Variable    xpath=//div[@id='historyListView']//div[contains(@class,'d-md-block')]//tbody/tr[.//div[contains(concat(' ',normalize-space(@class),' '),' fw-semibold ') and normalize-space(.)='${sample_name}']]
    ATX D2C3 Require Exact Count    ${row}    1    Guided exact imported batch row
    ${trigger}=    Set Variable    ${row} >> css=button.js-batch-detail-trigger
    ${batch_id}=    Get Attribute    ${trigger}    data-batch-id
    Should Not Be Empty    ${batch_id}
    Set Dynomax Context Value    d2c3GuidedBatchId    ${batch_id}
    Set Dynomax Context Value    d2c3GuidedBatchCreated    ${True}
    ${detail}=    ATX D2C3 Read Exact Banking Batch Detail    ${batch_id}    Guided imported batch    FAIL
    ATX D2C3 Validate Imported Banking Batch    ${detail}    ${sample_name}    3    Guided
    ATX D2C3 Progress    2    3    PASS    Guided preview and final-import BatchDetail outcome passed.
    ${undone_now}=    ATX D2C3 Undo Exact Banking Batch    ${batch_id}    Guided
    Should Be True    ${undone_now}
    Set Dynomax Context Value    d2c3GuidedBatchReversed    ${True}
    Set Dynomax Context Value    d2c3GuidedAcceptancePassed    ${True}
    ATX D2C3 Progress    3    3    PASS    Guided Banking import and exact reversed-state cleanup passed.

ATX D2C3 Guided Next Should Be Enabled
    ${disabled}=    Get Property    css=#btnStep1Next    disabled
    Should Not Be True    ${disabled}

ATX D2C3 Guided Upload Outcome Should Exist
    ${review}=    Get Element Count    css=#pdfExtractionReviewForm:visible
    ${step3}=    Get Element Count    css=#stepPane3:visible
    ${feedback}=    Get Element Count    css=.alert-danger:visible, .alert-warning:visible
    ${total}=    Evaluate    int($review)+int($step3)+int($feedback)
    Should Be True    ${total} > 0
