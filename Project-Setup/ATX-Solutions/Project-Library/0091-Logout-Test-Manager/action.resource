*** Keywords ***
ATX Logout Test Manager
    ${authenticated}=    Get Element Count    css=.atx-authenticated-root
    IF    ${authenticated} == 0
        Set Dynomax Context Value    loggedOut    ${True}
        RETURN
    END
    ${menu}=    Set Variable    css=a.atx-user-menu-toggle:visible
    ${menu_count}=    Get Element Count    ${menu}
    IF    ${menu_count} != 1
        Fail Dynomax Action    TEST_INVALID    Visible user menu toggle resolved to ${menu_count} controls.
    END
    Click    ${menu}
    ${logout}=    Set Variable    css=ul.dropdown-menu.show a.dropdown-item[href="/Logout"]:visible
    Wait For Elements State    ${logout}    visible    timeout=10s
    Click    ${logout}
    Wait Until Keyword Succeeds    30s    500ms    ATX Logout Should Be Complete
    Go To    ${DYNOMAX_BASE_URL}Banking/Profiles?tab=user
    Wait For Elements State    css=#loginForm    visible    timeout=30s
    ${protected_root}=    Get Element Count    css=.atx-authenticated-root
    Should Be Equal As Integers    ${protected_root}    0
    Set Dynomax Context Value    loggedOut    ${True}

ATX Logout Should Be Complete
    ${auth}=    Get Element Count    css=.atx-authenticated-root
    Should Be Equal As Integers    ${auth}    0
    ${url}=    Get Url
    ${public}=    Evaluate    '/Login' in str($url) or '/Logout' in str($url) or not str($url).startswith('https://atxsolutions.co.za/Banking')
    Should Be True    ${public}
