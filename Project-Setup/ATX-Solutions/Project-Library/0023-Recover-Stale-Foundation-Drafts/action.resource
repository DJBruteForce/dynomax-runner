*** Keywords ***
ATX Recover Stale Foundation Drafts
    Go To    ${DYNOMAX_BASE_URL}Banking/Profiles?tab=user
    Wait For Elements State    css=.atx-authenticated-root    attached    timeout=30s
    Wait For Elements State    css=.bp-panel    visible    timeout=30s
    ${found}=    Set Variable    0
    ${deleted}=    Set Variable    0
    ${ids}=    Set Variable    ${EMPTY}
    FOR    ${index}    IN RANGE    0    20
        ${card}=    Set Variable    xpath=(//div[contains(concat(' ',normalize-space(@class),' '),' bp-profile-card ')][.//h2[starts-with(normalize-space(),'Dynomax TEST Statement Draft ')]])[1]
        ${count}=    Get Element Count    ${card}
        IF    ${count} == 0
            BREAK
        END
        ${found}=    Evaluate    int($found) + 1
        ${name}=    Get Text    ${card} >> css=h2
        Should Start With    ${name}    Dynomax TEST Statement Draft
        ${text}=    Get Text    ${card}
        Should Contain    ${text}    Draft
        Should Not Contain    ${text}    Published
        ${configure}=    Set Variable    ${card} >> css=a[href*="/Banking/Profiles/Statement"][href*="id="]
        ${configure_count}=    Get Element Count    ${configure}
        IF    ${configure_count} != 1
            Fail Dynomax Action    TEST_INVALID    Stale package-owned Draft ${name} resolved to ${configure_count} configure links.
        END
        ${href}=    Get Attribute    ${configure}    href
        ${actual_id}=    Evaluate    re.search(r'(?i)[?&]id=([0-9a-f-]{36})', $href).group(1) if re.search(r'(?i)[?&]id=([0-9a-f-]{36})', $href) else ''    modules=re
        IF    $actual_id == ''
            Fail Dynomax Action    TEST_INVALID    Stale package-owned Draft ${name} did not expose an exact GUID.
        END
        ${delete_form}=    Set Variable    ${card} >> css=form[action*="handler=Delete"]:has(input[name="profileId"][value="${actual_id}"])
        ${form_count}=    Get Element Count    ${delete_form}
        IF    ${form_count} != 1
            Fail Dynomax Action    TEST_INVALID    Stale package-owned Draft ${name} / ${actual_id} resolved to ${form_count} exact delete forms.
        END
        ${actions}=    Set Variable    ${card} >> css=button.dropdown-toggle:has-text("Actions")
        ${actions_count}=    Get Element Count    ${actions}
        IF    ${actions_count} != 1
            Fail Dynomax Action    TEST_INVALID    Stale package-owned Draft ${name} resolved to ${actions_count} Actions controls.
        END
        Evaluate JavaScript    css=body    (element) => { window.confirm=()=>true; }
        Click    ${actions}
        ${delete}=    Set Variable    ${delete_form} >> css=button[type="submit"]:visible
        Wait For Elements State    ${delete}    visible    timeout=10s
        Click    ${delete}
        Wait Until Keyword Succeeds    30s    500ms    ATX Stale Foundation Draft Should Be Absent    ${name}
        ${deleted}=    Evaluate    int($deleted) + 1
        ${ids}=    Evaluate    str($actual_id) if str($ids)=='' else str($ids)+','+str($actual_id)
    END
    ${remaining}=    Get Element Count    xpath=//div[contains(concat(' ',normalize-space(@class),' '),' bp-profile-card ')][.//h2[starts-with(normalize-space(),'Dynomax TEST Statement Draft ')]]
    IF    ${remaining} != 0
        Fail Dynomax Action    TEST_INVALID    More than 20 stale foundation Drafts or an undeletable exact Draft remains.
    END
    Set Dynomax Context Value    staleFoundationDraftsFound    ${found}
    Set Dynomax Context Value    staleFoundationDraftsDeleted    ${deleted}
    Set Dynomax Context Value    staleFoundationDraftIds    ${ids}
    IF    ${deleted} > 0
        Set Dynomax Context Value    staleFoundationCleanupOutcome    deleted
    ELSE
        Set Dynomax Context Value    staleFoundationCleanupOutcome    none-found
    END

ATX Stale Foundation Draft Should Be Absent
    [Arguments]    ${name}
    ${count}=    Get Element Count    xpath=//div[contains(concat(' ',normalize-space(@class),' '),' bp-profile-card ')][.//h2[normalize-space()='${name}']]
    Should Be Equal As Integers    ${count}    0
