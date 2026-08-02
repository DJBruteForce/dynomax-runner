*** Settings ***
Resource    ../../Project-And-Config/Robot/ATX-D2C3.Common.resource

*** Keywords ***
ATX Verify D2C3 Manager Data Management Acceptance
    ATX D2C3 Progress    1    3    START    Manager Data Management website acceptance started.
    ${account}=    Get Dynomax Context Value    targetBankAccount    ATX UI TEST BANK
    ${profile}=    ATX D2C3 Read Optional Context    d2c3StructuredProfileName
    ${sample}=    ATX D2C3 Read Optional Context    d2c3ManagerSamplePath
    ${sample_name}=    ATX D2C3 Read Optional Context    d2c3ManagerSampleName
    IF    $profile == '' or $sample == '' or $sample_name == ''
        Fail Dynomax Action    BLOCKED    Manager Data Management prerequisites were not prepared. The reusable Structured profile and Manager CSV fixture are required.
    END
    File Should Exist    ${sample}
    Go To    ${DYNOMAX_BASE_URL}Manager/DataManagement/Import
    Wait For Elements State    css=.dm-page    visible    timeout=30s
    Wait For Elements State    css=#SourceFile    visible    timeout=30s
    ATX D2C3 Capture Current Page    manager-data-management-step-1-file
    Upload File By Selector    css=#SourceFile    ${sample}
    ATX D2C3 Safe Click    css=form[action*="handler=NextFromFile"] button[type="submit"]:visible
    Wait For Elements State    css=#SelectedBankAccountId    visible    timeout=45s
    ATX D2C3 Capture Current Page    manager-data-management-step-2-settings
    ${account_option}=    Set Variable    xpath=//select[@id='SelectedBankAccountId']/option[starts-with(normalize-space(.),'${account}')]
    ATX D2C3 Require Exact Count    ${account_option}    1    Manager Data Management test account
    ${account_id}=    Get Attribute    ${account_option}    value
    Select Options By    css=#SelectedBankAccountId    value    ${account_id}
    ${profile_text}=    Get Text    css=#SelectedBankImportProfileId
    ${profile_present}=    Evaluate    str($profile) in str($profile_text)
    IF    not ${profile_present}
        Fail Dynomax Action    BLOCKED    The exact Published Structured profile '${profile}' is absent from Manager Data Management.
    END
    Select Options By    css=#SelectedBankImportProfileId    label    ${profile}
    ${profile_id}=    Get Property    css=#SelectedBankImportProfileId    value
    ${selected_profile_text}=    Get Text    css=#SelectedBankImportProfileId option:checked
    Should Be Equal    ${selected_profile_text}    ${profile}
    Should Not Be Empty    ${profile_id}
    ATX D2C3 Safe Click    css=form[action*="handler=Preview"] button.dm-btn-primary:visible
    Wait For Elements State    css=.dm-card h2:has-text("Step 3")    visible    timeout=60s
    ATX D2C3 Capture Current Page    manager-data-management-preview-first
    ${operation1}=    ATX D2C3 Read Unique Hidden Value    ImportOperationId    Manager preview operation ID
    ${artifact1}=    ATX D2C3 Read Unique Hidden Value    ImportSourceArtifactId    Manager preview source artifact ID
    Should Not Be Empty    ${operation1}
    Should Not Be Empty    ${artifact1}
    Set Dynomax Context Value    d2c3ManagerOperationId    ${operation1}
    Set Dynomax Context Value    d2c3ManagerArtifactId    ${artifact1}
    ${can_import}=    Get Element Count    css=form[action*="handler=Import"] button.dm-btn-primary:not([disabled]):visible
    IF    ${can_import} != 1
        ${feedback}=    ATX D2C3 Visible Feedback
        Fail Dynomax Action    FAIL    Manager Data Management preview could not proceed to import. ${feedback}
    END
    ATX D2C3 Safe Click    css=form[action*="handler=BackToSettings"] button[type="submit"]:visible
    Wait For Elements State    css=#SelectedBankAccountId    visible    timeout=30s
    ATX D2C3 Capture Current Page    manager-data-management-back-to-settings
    ${back_operation}=    ATX D2C3 Read Unique Hidden Value    ImportOperationId    Manager settings operation ID
    ${back_artifact}=    ATX D2C3 Read Unique Hidden Value    ImportSourceArtifactId    Manager settings source artifact ID
    Should Be Equal    ${back_operation}    ${operation1}
    Should Be Equal    ${back_artifact}    ${artifact1}
    Select Options By    css=#SelectedBankAccountId    value    ${account_id}
    Select Options By    css=#SelectedBankImportProfileId    label    ${profile}
    ${repeat_profile_id}=    Get Property    css=#SelectedBankImportProfileId    value
    Should Be Equal    ${repeat_profile_id}    ${profile_id}
    ATX D2C3 Safe Click    css=form[action*="handler=Preview"] button.dm-btn-primary:visible
    Wait For Elements State    css=.dm-card h2:has-text("Step 3")    visible    timeout=60s
    ATX D2C3 Capture Current Page    manager-data-management-preview-repeated
    ${operation2}=    ATX D2C3 Read Unique Hidden Value    ImportOperationId    Manager repeated-preview operation ID
    ${artifact2}=    ATX D2C3 Read Unique Hidden Value    ImportSourceArtifactId    Manager repeated-preview source artifact ID
    IF    '${operation2}' != '${operation1}' or '${artifact2}' != '${artifact1}'
        Fail Dynomax Action    FAIL    Manager Data Management Back/Preview changed operation or artifact identity.
    END
    Set Dynomax Context Value    d2c3ManagerOperationStable    ${True}
    ATX D2C3 Safe Click    css=form[action*="handler=Import"] button.dm-btn-primary:visible
    Wait For Elements State    css=.dm-card h2:has-text("Step 4")    visible    timeout=90s
    ATX D2C3 Capture Current Page    manager-data-management-import-result
    ${history}=    Set Variable    css=a[href*="/Manager/DataManagement/History"][href*="batchId="]:visible
    ATX D2C3 Require Exact Count    ${history}    1    Manager Data Management exact history link
    ${href}=    Get Attribute    ${history}    href
    ${ids}=    Get Regexp Matches    ${href}    (?i)batchId=([0-9a-f-]{36})    1
    Length Should Be    ${ids}    1
    ${batch_id}=    Get From List    ${ids}    0
    Set Dynomax Context Value    d2c3ManagerBatchId    ${batch_id}
    Set Dynomax Context Value    d2c3ManagerBatchCreated    ${True}
    ${failed}=    Get Text    xpath=//section[contains(concat(' ',normalize-space(@class),' '),' dm-kpi-grid ')]//div[contains(concat(' ',normalize-space(@class),' '),' dm-kpi-card ')][.//div[normalize-space()='Failed']]//div[contains(concat(' ',normalize-space(@class),' '),' dm-kpi-value ')]
    Should Be Equal    ${failed}    0
    ${detail}=    ATX D2C3 Read Exact Banking Batch Detail    ${batch_id}    Manager Data Management imported batch    FAIL
    ATX D2C3 Validate Imported Banking Batch    ${detail}    ${sample_name}    3    Manager Data Management
    ATX D2C3 Progress    2    3    PASS    Manager preview identity and final-import BatchDetail outcome passed.
    ${undone_now}=    ATX D2C3 Undo Exact Banking Batch    ${batch_id}    Manager Data Management
    Should Be True    ${undone_now}
    Set Dynomax Context Value    d2c3ManagerBatchReversed    ${True}
    Set Dynomax Context Value    d2c3ManagerAcceptancePassed    ${True}
    ATX D2C3 Progress    3    3    PASS    Manager preview identity, import and exact reversed-state cleanup passed.
