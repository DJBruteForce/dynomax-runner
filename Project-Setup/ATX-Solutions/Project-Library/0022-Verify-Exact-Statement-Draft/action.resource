*** Keywords ***
ATX Verify Exact Statement Draft
    ${profile_id}=    Get Dynomax Context Value    statementProfileId
    ${profile_name}=    Get Dynomax Context Value    statementProfileName
    ${profile_url}=    Get Dynomax Context Value    statementProfileUrl
    Should Not Be Empty    ${profile_id}
    Should Not Be Empty    ${profile_name}
    Should Not Be Empty    ${profile_url}
    Go To    ${profile_url}
    Wait For Elements State    css=.statement-profile-page    visible    timeout=30s
    Wait For Elements State    css=#statementProfileForm    visible    timeout=30s
    Wait Until Keyword Succeeds    30s    250ms    ATX Statement Controllers Should Be Ready
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
    Set Dynomax Context Value    statementDraftVerified    ${True}
    Set Dynomax Context Value    statementProfileState    Draft
    Set Dynomax Context Value    lifecycleBadgeSelector    ${badge_selector}

ATX Statement Controllers Should Be Ready
    ${ready}=    Evaluate JavaScript    css=.statement-profile-page    (page) => Boolean(page && page.dataset && page.dataset.profileMode && document.querySelector('#statementProfileForm') && typeof window.__atxStatementProfileCleanup === 'function')
    Should Be True    ${ready}
