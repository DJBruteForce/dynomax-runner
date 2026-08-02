*** Keywords ***
ATX Authenticate Test Manager
    ${already}=    Get Element Count    css=.atx-authenticated-root
    IF    ${already} > 0
        ${url}=    Get Url
        Set Dynomax Context Value    authenticated    ${True}
        Set Dynomax Context Value    authenticatedRole    Manager
        Set Dynomax Context Value    authenticatedUrl    ${url}
        RETURN
    END
    Go To    ${DYNOMAX_BASE_URL}Login?returnUrl=%2FManager%2FDashboard
    Wait For Elements State    css=#loginForm    visible    timeout=30s
    Fill Text    css=#Email    %{ATX_TEST_USERNAME}
    Fill Secret    css=#Password    %ATX_TEST_PASSWORD
    Click    css=#loginButton
    Wait Until Keyword Succeeds    30s    500ms    ATX Authentication Outcome Exists
    ATX Resolve Authentication Outcome
    Wait For Elements State    css=.atx-authenticated-root    attached    timeout=30s
    ${url}=    Get Url
    Set Dynomax Context Value    authenticated    ${True}
    Set Dynomax Context Value    authenticatedRole    Manager
    Set Dynomax Context Value    authenticatedUrl    ${url}

ATX Authentication Outcome Exists
    ${authenticated}=    Get Element Count    css=.atx-authenticated-root
    ${profiles}=    Get Element Count    css=#profileSelectionModal
    ${two_factor}=    Get Element Count    css=#twoFactorModal
    ${login_error}=    Get Element Count    css=#loginForm .alert-danger:visible, .card-body > .alert-danger:visible
    ${total}=    Evaluate    int($authenticated)+int($profiles)+int($two_factor)+int($login_error)
    Should Be True    ${total} > 0

ATX Resolve Authentication Outcome
    ${two_factor}=    Get Element Count    css=#twoFactorModal
    IF    ${two_factor} > 0
        Fail Dynomax Action    BLOCKED    Login requires an interactive two-factor code.
    END
    ${login_error}=    Get Element Count    css=#loginForm .alert-danger:visible, .card-body > .alert-danger:visible
    IF    ${login_error} > 0
        ${message}=    Get Text    css=#loginForm .alert-danger:visible, .card-body > .alert-danger:visible >> nth=0
        Fail Dynomax Action    ERROR    Runtime test authentication failed: ${message}
    END
    ${profiles}=    Get Element Count    css=#profileSelectionModal
    IF    ${profiles} > 0
        Wait For Elements State    css=.profile-selection-item    visible    timeout=15s
        ${manager}=    Get Element Count    css=.profile-selection-item:visible:has-text("Manager")
        IF    ${manager} != 1
            Fail Dynomax Action    BLOCKED    Manager login profile resolved to ${manager} visible choices.
        END
        Click    css=.profile-selection-item:visible:has-text("Manager")
        Wait Until Keyword Succeeds    30s    500ms    ATX Authenticated Root Exists
    END

ATX Authenticated Root Exists
    ${count}=    Get Element Count    css=.atx-authenticated-root
    Should Be True    ${count} > 0
