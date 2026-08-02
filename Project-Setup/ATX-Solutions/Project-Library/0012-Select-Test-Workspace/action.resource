*** Keywords ***
ATX Select Test Workspace
    ${target}=    Get Dynomax Context Value    targetWorkspace    CIPC Example Holdings
    ${trigger}=    Set Variable    css=button.atx-topbar-chip-workspace[data-atx-workspace-switcher-open="true"]:visible:not([disabled])
    ${trigger_count}=    Get Element Count    ${trigger}
    IF    ${trigger_count} != 1
        Fail Dynomax Action    BLOCKED    Visible desktop workspace trigger resolved to ${trigger_count} controls.
    END
    ${label}=    Get Text    ${trigger} >> css=.atx-topbar-chip-label
    Set Dynomax Context Value    workspaceBefore    ${label}
    ${correct}=    Run Keyword And Return Status    Should Contain    ${label}    ${target}
    IF    not ${correct}
        Wait Until Keyword Succeeds    15s    500ms    ATX Open Workspace Switcher    ${trigger}
        ${link}=    Set Variable    css=#workspaceSwitcherModal.show .workspace-switcher-card[data-workspace-row]:has(.workspace-switcher-name:has-text("${target}")) a[data-workspace-switch-link]:visible
        ${count}=    Get Element Count    ${link}
        IF    ${count} != 1
            Fail Dynomax Action    BLOCKED    Workspace ${target} resolved to ${count} exact switch actions.
        END
        Click    ${link}
        Wait Until Keyword Succeeds    30s    500ms    ATX Workspace Label Should Match    ${target}
    END
    Set Dynomax Context Value    targetWorkspace    ${target}
    Set Dynomax Context Value    workspaceSelected    ${True}

ATX Open Workspace Switcher
    [Arguments]    ${trigger}
    Click    ${trigger}
    Wait For Elements State    css=#workspaceSwitcherModal.show    visible    timeout=3s

ATX Workspace Label Should Match
    [Arguments]    ${target}
    ${label}=    Get Text    css=button.atx-topbar-chip-workspace:visible .atx-topbar-chip-label
    Should Contain    ${label}    ${target}
