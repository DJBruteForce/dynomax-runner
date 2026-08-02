*** Keywords ***
ATX Delete Exact Disposable Statement Draft
    ${attempted}=    Get Dynomax Context Value    statementProfileCreationAttempted    ${False}
    ${name}=    Get Dynomax Context Value    statementProfileName    ${EMPTY}
    ${expected_id}=    Get Dynomax Context Value    statementProfileId    ${EMPTY}
    ${created}=    Get Dynomax Context Value    statementProfileCreated    ${False}
    ${previously_deleted}=    Get Dynomax Context Value    statementProfileDeleted    ${False}
    IF    not $previously_deleted
        Set Dynomax Context Value    statementProfileDeleted    ${False}
        Set Dynomax Context Value    deletedProfileId    ${EMPTY}
    END
    IF    not $attempted or $name == ''
        Set Dynomax Context Value    cleanupOutcome    not-created
        RETURN
    END
    Go To    ${DYNOMAX_BASE_URL}Banking/Profiles?tab=user
    Wait For Elements State    css=.atx-authenticated-root    attached    timeout=30s
    ${card}=    ATX Cleanup Exact Profile Card    ${name}
    ${count}=    Get Element Count    ${card}
    IF    ${count} == 0
        IF    $previously_deleted
            Set Dynomax Context Value    cleanupOutcome    already-deleted
            RETURN
        END
        Set Dynomax Context Value    cleanupOutcome    already-absent
        IF    $created
            Fail Dynomax Action    TEST_INVALID    The recorded exact Draft was already absent before cleanup, so deletion could not be attributed truthfully.
        END
        RETURN
    END
    IF    ${count} != 1
        Fail Dynomax Action    TEST_INVALID    Cleanup exact Draft resolved to ${count} cards.
    END
    ${text}=    Get Text    ${card}
    Should Contain    ${text}    Draft
    Should Not Contain    ${text}    Published
    ${configure}=    Set Variable    ${card} >> css=a[href*="/Banking/Profiles/Statement"][href*="id="]
    ${configure_count}=    Get Element Count    ${configure}
    IF    ${configure_count} != 1
        Fail Dynomax Action    TEST_INVALID    Cleanup exact Draft resolved to ${configure_count} configure links.
    END
    ${href}=    Get Attribute    ${configure}    href
    ${actual_id}=    Evaluate    re.search(r'(?i)[?&]id=([0-9a-f-]{36})', $href).group(1) if re.search(r'(?i)[?&]id=([0-9a-f-]{36})', $href) else ''    modules=re
    IF    $actual_id == ''
        Fail Dynomax Action    TEST_INVALID    Cleanup could not resolve the exact Draft GUID.
    END
    IF    $expected_id != '' and $actual_id != $expected_id
        Fail Dynomax Action    TEST_INVALID    Cleanup GUID ${actual_id} did not match recorded GUID ${expected_id}.
    END
    Set Dynomax Context Value    statementProfileId    ${actual_id}
    ${delete_form}=    Set Variable    ${card} >> css=form[action*="handler=Delete"]:has(input[name="profileId"][value="${actual_id}"])
    ${form_count}=    Get Element Count    ${delete_form}
    IF    ${form_count} != 1
        Fail Dynomax Action    TEST_INVALID    Exact Draft delete form resolved to ${form_count} forms.
    END
    ${actions}=    Set Variable    ${card} >> css=button.dropdown-toggle:has-text("Actions")
    ${actions_count}=    Get Element Count    ${actions}
    IF    ${actions_count} != 1
        Fail Dynomax Action    TEST_INVALID    Cleanup exact Draft Actions dropdown resolved to ${actions_count} controls.
    END
    Evaluate JavaScript    css=body    (element) => { window.confirm=()=>true; }
    Click    ${actions}
    ${delete}=    Set Variable    ${delete_form} >> css=button[type="submit"]:visible
    Wait For Elements State    ${delete}    visible    timeout=10s
    Click    ${delete}
    Wait Until Keyword Succeeds    30s    500ms    ATX Cleanup Exact Profile Card Should Be Absent    ${name}
    Set Dynomax Context Value    statementProfileDeleted    ${True}
    Set Dynomax Context Value    deletedProfileId    ${actual_id}
    Set Dynomax Context Value    cleanupOutcome    deleted

ATX Cleanup Exact Profile Card
    [Arguments]    ${name}
    ${card}=    Set Variable    xpath=//div[contains(concat(' ',normalize-space(@class),' '),' bp-profile-card ')][.//h2[normalize-space()='${name}']]
    RETURN    ${card}

ATX Cleanup Exact Profile Card Should Be Absent
    [Arguments]    ${name}
    ${card}=    ATX Cleanup Exact Profile Card    ${name}
    ${count}=    Get Element Count    ${card}
    Should Be Equal As Integers    ${count}    0
