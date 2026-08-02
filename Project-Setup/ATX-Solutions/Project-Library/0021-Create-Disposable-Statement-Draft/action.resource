*** Keywords ***
ATX Create Disposable Statement Draft
    ${name}=    Get Dynomax Context Value    statementProfileName    ${EMPTY}
    IF    $name == ''
        ${name}=    Evaluate    'Dynomax TEST Statement Draft ' + datetime.datetime.now().strftime('%Y%m%d%H%M%S') + '-' + uuid.uuid4().hex[:8]    modules=datetime,uuid
    END
    Set Dynomax Context Value    statementProfileName    ${name}
    Set Dynomax Context Value    statementProfileCreationAttempted    ${True}
    Set Dynomax Context Value    statementProfileCreated    ${False}
    Set Dynomax Context Value    statementProfileDeleted    ${False}
    Set Dynomax Context Value    cleanupOutcome    pending
    Go To    ${DYNOMAX_BASE_URL}Banking/Profiles?tab=user
    Wait For Elements State    css=.atx-authenticated-root    attached    timeout=30s
    ${existing}=    ATX Exact Profile Card Count    ${name}
    IF    ${existing} != 0
        Fail Dynomax Action    TEST_INVALID    Generated disposable profile name already resolved to ${existing} exact cards.
    END
    Go To    ${DYNOMAX_BASE_URL}Banking/Profiles?tab=system
    Wait For Elements State    css=.atx-authenticated-root    attached    timeout=30s
    ${copy}=    Set Variable    css=button[data-copy-profile][data-template-key="absa-statement"]:visible
    ${copy_count}=    Get Element Count    ${copy}
    IF    ${copy_count} != 1
        Fail Dynomax Action    BLOCKED    ABSA statement starter copy action resolved to ${copy_count} visible controls.
    END
    Click    ${copy}
    Wait For Elements State    css=#copyProfileModal    visible    timeout=15s
    ${source}=    Get Text    css=#copyProfileSource
    Should Contain    ${source}    ABSA bank statement starter
    Fill Text    css=#copyProfileName    ${name}
    Click    css=#copyProfileModal button[type="submit"]:visible
    Wait Until Keyword Succeeds    30s    500ms    ATX Exact Profile Card Should Exist    ${name}
    ${card}=    ATX Exact Profile Card    ${name}
    ${text}=    Get Text    ${card}
    Should Contain    ${text}    Draft
    Should Not Contain    ${text}    Published
    ${configure}=    Set Variable    ${card} >> css=a[href*="/Banking/Profiles/Statement"][href*="id="]
    ${configure_count}=    Get Element Count    ${configure}
    IF    ${configure_count} != 1
        Fail Dynomax Action    TEST_INVALID    Exact disposable Draft resolved to ${configure_count} configure links.
    END
    ${href}=    Get Attribute    ${configure}    href
    ${profile_id}=    Evaluate    re.search(r'(?i)[?&]id=([0-9a-f-]{36})', $href).group(1) if re.search(r'(?i)[?&]id=([0-9a-f-]{36})', $href) else ''    modules=re
    IF    $profile_id == ''
        Fail Dynomax Action    TEST_INVALID    Exact Draft configure link did not expose a GUID.
    END
    ${profile_url}=    Set Variable    ${DYNOMAX_BASE_URL}Banking/Profiles/Statement?id=${profile_id}
    Set Dynomax Context Value    statementProfileId    ${profile_id}
    Set Dynomax Context Value    statementProfileUrl    ${profile_url}
    Set Dynomax Context Value    statementProfileCreated    ${True}
    Set Dynomax Context Value    statementProfileState    Draft

ATX Exact Profile Card
    [Arguments]    ${name}
    ${card}=    Set Variable    xpath=//div[contains(concat(' ',normalize-space(@class),' '),' bp-profile-card ')][.//h2[normalize-space()='${name}']]
    RETURN    ${card}

ATX Exact Profile Card Count
    [Arguments]    ${name}
    ${card}=    ATX Exact Profile Card    ${name}
    ${count}=    Get Element Count    ${card}
    RETURN    ${count}

ATX Exact Profile Card Should Exist
    [Arguments]    ${name}
    ${count}=    ATX Exact Profile Card Count    ${name}
    Should Be Equal As Integers    ${count}    1
