*** Settings ***
Resource    ../../Project-And-Config/Robot/ATX-D2B.Common.resource

*** Keywords ***
ATX Prepare D2B Statement Workspace
    ${profile_id}=    Get Dynomax Context Value    statementProfileId
    ${profile_name}=    Get Dynomax Context Value    statementProfileName
    ${profile_url}=    Get Dynomax Context Value    statementProfileUrl
    Should Not Be Empty    ${profile_id}
    Should Not Be Empty    ${profile_name}
    Should Not Be Empty    ${profile_url}
    Go To    ${profile_url}
    ATX D2B Wait For Statement Profile Initialization
    ${actual_id}=    Get Property    css=#Form_Id    value
    ${actual_name}=    Get Property    css=#Form_ProfileName    value
    Should Be Equal    ${actual_id}    ${profile_id}
    Should Be Equal    ${actual_name}    ${profile_name}
    ${badge_selector}=    Set Variable    css=.statement-page-header .statement-header-meta .statement-state-badge:visible
    ${badge_count}=    Get Element Count    ${badge_selector}
    IF    ${badge_count} != 1
        Fail Dynomax Action    TEST_INVALID    Visible desktop Statement lifecycle badge resolved to ${badge_count} elements.
    END
    ${badge}=    Get Text    ${badge_selector}
    Should Contain    ${badge}    Draft
    Should Not Contain    ${badge}    Published
    Click    css=button[data-profile-mode-button="advanced"]:visible
    Wait Until Keyword Succeeds    10s    250ms    ATX D2B Profile Mode Should Be Advanced
    Set Dynomax Context Value    d2bWorkspacePrepared    ${True}
    Set Dynomax Context Value    d2bSourceTruthVersion    V63
    Set Dynomax Context Value    d2bNoImportExecuted    ${True}
