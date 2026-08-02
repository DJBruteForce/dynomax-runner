*** Settings ***
Library    Collections
Library    OperatingSystem
Library    String
Library    ${CURDIR}${/}ATX_D2C3_FixtureLibrary.py

*** Keywords ***
ATX D2C3 Safe Click
    [Arguments]    ${selector}
    Evaluate JavaScript    css=html    (element) => { const banner=document.getElementById('cookieConsentBanner'); if(banner){banner.style.display='none';} }
    Click    ${selector}

ATX D2C3 Progress
    [Arguments]    ${current}    ${total}    ${status}    ${description}
    ${line}=    Set Variable    [D2-C3 progress ${current}/${total}] ${status} - ${description}
    Log To Console    ${line}
    Log    ${line}
    Set Dynomax Context Value    d2c3LastProgress    ${line}

ATX D2C3 Wait For Payment Evidence Preview Or Fail
    [Arguments]    ${success_label}
    FOR    ${attempt}    IN RANGE    60
        ${error_count}=    Get Element Count    css=[data-payment-evidence-error]:visible
        ${preview_count}=    Get Element Count    css=#pane-sub-import > div.card.border-0.shadow-sm:not(.mb-4):visible
        IF    ${error_count} > 1 or ${preview_count} > 1
            ATX D2C3 Capture Current Page    ${success_label}-ambiguous-result
            Fail Dynomax Action    TEST_INVALID    Payment Evidence returned ${error_count} visible errors and ${preview_count} visible preview cards; one recognized result was required.
        END
        IF    ${error_count} == 1
            ATX D2C3 Capture Current Page    ${success_label}-application-error
            ${message}=    Get Text    css=[data-payment-evidence-error-message]:visible
            Fail Dynomax Action    FAIL    Payment Evidence returned a visible ATX error after preview submission: ${message}
        END
        IF    ${preview_count} == 1
            ATX D2C3 Capture Current Page    ${success_label}
            RETURN    css=#pane-sub-import > div.card.border-0.shadow-sm:not(.mb-4):visible
        END
        Sleep    500ms
    END
    ATX D2C3 Capture Current Page    ${success_label}-unrecognized-result
    ${feedback}=    ATX D2C3 Visible Feedback
    Fail Dynomax Action    TEST_INVALID    Payment Evidence produced neither one visible preview card nor one visible error block within 30 seconds. Visible feedback: ${feedback}

ATX D2C3 Capture Current Page
    [Arguments]    ${label}
    ${payload}=    Evaluate JavaScript    css=html    (element) => { const clean=(value)=>String(value||'').replace(/\s+/g,' ').trim(); const clone=document.documentElement.cloneNode(true); clone.querySelectorAll('script,style,noscript,template,iframe').forEach((node)=>node.remove()); clone.querySelectorAll('*').forEach((node)=>{ Array.from(node.attributes||[]).forEach((attribute)=>{ const name=attribute.name.toLowerCase(); if(name.startsWith('on')){node.removeAttribute(attribute.name);return;} if(/token|secret|password|csrf|antiforgery|requestverification|authorization|nonce/i.test(name)){node.setAttribute(attribute.name,'[REDACTED]');return;} if((name==='src'||name==='href'||name==='value')&&/^(data|blob):/i.test(attribute.value||'')){node.setAttribute(attribute.name,'[REDACTED_URL]');} }); }); clone.querySelectorAll('input,textarea,select').forEach((node)=>{ const key=String(node.getAttribute('name')||'')+' '+String(node.getAttribute('id')||''); const sensitive=/password|secret|token|csrf|antiforgery|requestverification|authorization/i.test(key); if(node.tagName==='INPUT'){ const type=String(node.getAttribute('type')||'text').toLowerCase(); if(type==='password'||sensitive){node.setAttribute('value','[REDACTED]');}else if(type==='file'){node.removeAttribute('value');}else{node.setAttribute('value',String(node.value||''));} if(node.checked){node.setAttribute('checked','checked');}else{node.removeAttribute('checked');} }else if(node.tagName==='TEXTAREA'){node.textContent=sensitive?'[REDACTED]':String(node.value||'');}else if(node.tagName==='SELECT'){Array.from(node.options||[]).forEach((option)=>{if(option.selected){option.setAttribute('selected','selected');}else{option.removeAttribute('selected');}});} }); const tabCount=(label)=>{ const link=Array.from(document.querySelectorAll('.bp-tabs a')).find((item)=>clean(item.textContent).startsWith(label)); const badge=link?link.querySelector('.badge'):null; const parsed=parseInt(clean(badge?badge.textContent:''),10); return Number.isFinite(parsed)?parsed:null; }; const selected=(id)=>{ const control=document.getElementById(id); if(!control){return null;} const option=control.options&&control.selectedIndex>=0?control.options[control.selectedIndex]:null; return {value:String(control.value||''),text:clean(option?option.textContent:'')}; }; const cards=Array.from(document.querySelectorAll('.bp-profile-card')).map((card)=>{ const heading=card.querySelector('h2'); const muted=card.querySelector('.small.text-muted'); const badges=Array.from(card.querySelectorAll('.badge')).map((badge)=>clean(badge.textContent)).filter(Boolean); const links=Array.from(card.querySelectorAll('a[href]')).map((link)=>({text:clean(link.textContent),href:String(link.getAttribute('href')||'')})); return {name:clean(heading?heading.textContent:''),detail:clean(muted?muted.textContent:''),badges:badges,links:links}; }); const alerts=Array.from(document.querySelectorAll('.alert')).filter((item)=>item.offsetParent!==null).map((item)=>clean(item.textContent)).filter(Boolean); const headings=Array.from(document.querySelectorAll('h1,h2,h3')).filter((item)=>item.offsetParent!==null).map((item)=>clean(item.textContent)).filter(Boolean); const workspaceNode=document.querySelector('button.atx-topbar-chip-workspace .atx-topbar-chip-label')||document.querySelector('[data-atx-workspace-switcher-open] .atx-topbar-chip-label'); const metadata={url:String(location.href),title:String(document.title||''),workspace:clean(workspaceNode?workspaceNode.textContent:''),headings:headings,alerts:alerts,userProfileTabCount:tabCount('User Profiles'),systemProfileTabCount:tabCount('System Profiles'),selectedPurpose:selected('profilePurpose'),selectedStatus:selected('profileStatus'),profileCardCount:cards.length,profileCards:cards,bodyText:clean(document.body?document.body.innerText:'').slice(0,100000)}; return JSON.stringify({html:'<!DOCTYPE html>'+clone.outerHTML,metadata:metadata}); }
    ${evidence}=    Write D2c3 Page Evidence    ${OUTPUT DIR}    ${DYNOMAX_STEP_ORDER}    ${DYNOMAX_ACTION_ID}    ${label}    ${payload}
    Set Dynomax Context Value    d2c3LastPageEvidence    ${evidence}[relativePath]
    Set Dynomax Context Value    d2c3PageEvidenceCount    ${evidence}[pageCount]
    Log    D2-C3 page HTML captured: ${evidence}[relativePath]

ATX D2C3 Absolute URL
    [Arguments]    ${href}
    ${url}=    Evaluate    urllib.parse.urljoin($DYNOMAX_BASE_URL, $href)    modules=urllib.parse
    RETURN    ${url}

ATX D2C3 Read Optional Context
    [Arguments]    ${name}
    ${status}    ${value}=    Run Keyword And Ignore Error    Get Dynomax Context Value    ${name}
    IF    '${status}' != 'PASS'
        RETURN    ${EMPTY}
    END
    ${missing}=    Evaluate    $value is None or str($value).strip().lower() in ('', 'none', 'null')
    IF    ${missing}
        RETURN    ${EMPTY}
    END
    RETURN    ${value}

ATX D2C3 Require Exact Count
    [Arguments]    ${selector}    ${expected}    ${description}
    ${count}=    Get Element Count    ${selector}
    IF    ${count} != ${expected}
        ATX D2C3 Capture Current Page    cardinality-${description}
        Fail Dynomax Action    TEST_INVALID    ${description} resolved to ${count} controls; expected ${expected}.
    END

ATX D2C3 Visible Feedback
    ${count}=    Get Element Count    css=.alert-danger:visible, .alert-warning:visible, .alert-success:visible
    IF    ${count} == 0
        RETURN    No visible feedback.
    END
    ${text}=    Get Text    css=.alert-danger:visible, .alert-warning:visible, .alert-success:visible >> nth=0
    RETURN    ${text}

ATX D2C3 Ensure Reusable Published Structured Profile And Create Samples
    ${target}=    Get Dynomax Context Value    targetWorkspace    CIPC Example Holdings
    ${profile_name}=    Set Variable    Dynomax D2C3 Structured TEST
    ${temp}=    Evaluate    os.path.join(tempfile.gettempdir(),'Dynomax','ATX-Solutions','D2C3')    modules=os,tempfile
    ${profile_sample}=    Create D2c3 Structured Csv    ${temp}    Profile    ,    yyyy-MM-dd    ${True}    0    1    2    5    SeparateColumns    3    4    ${EMPTY}
    ATX D2C3 Progress    2    5    START    Inspecting the exact reusable Structured profile in ${target}.
    Go To    ${DYNOMAX_BASE_URL}Banking/Profiles?tab=user
    Wait For Elements State    css=.bp-shell    visible    timeout=30s
    ATX D2C3 Capture Current Page    profiles-unfiltered-user
    ${inventory_json}=    Evaluate JavaScript    css=.bp-shell    (root) => JSON.stringify({ userTotal:(()=>{const link=Array.from(root.querySelectorAll('.bp-tabs a')).find(item=>String(item.textContent||'').includes('User Profiles'));const badge=link?link.querySelector('.badge'):null;const value=parseInt(String(badge?badge.textContent:''),10);return Number.isFinite(value)?value:0;})(), systemTotal:(()=>{const link=Array.from(root.querySelectorAll('.bp-tabs a')).find(item=>String(item.textContent||'').includes('System Profiles'));const badge=link?link.querySelector('.badge'):null;const value=parseInt(String(badge?badge.textContent:''),10);return Number.isFinite(value)?value:0;})(), profiles:Array.from(root.querySelectorAll('.bp-profile-card')).map(card=>({name:String(card.querySelector('h2')?.textContent||'').trim(),detail:String(card.querySelector('.small.text-muted')?.textContent||'').trim(),badges:Array.from(card.querySelectorAll('.badge')).map(item=>String(item.textContent||'').trim())})) })
    ${inventory}=    Evaluate    json.loads($inventory_json)    modules=json
    ${unfiltered_user}=    Set Variable    ${inventory}[userTotal]
    ${unfiltered_system}=    Set Variable    ${inventory}[systemTotal]
    Set Dynomax Context Value    d2c3UnfilteredUserProfileCount    ${unfiltered_user}
    Set Dynomax Context Value    d2c3UnfilteredSystemProfileCount    ${unfiltered_system}
    Set Dynomax Context Value    d2c3UnfilteredProfileInventoryJson    ${inventory_json}
    ${exact_card}=    Set Variable    xpath=//div[contains(concat(' ',normalize-space(@class),' '),' bp-profile-card ')][.//h2[normalize-space()='${profile_name}']]
    ${exact_count}=    Get Element Count    ${exact_card}
    IF    ${exact_count} > 1
        Fail Dynomax Action    TEST_INVALID    Reusable Structured profile ${profile_name} resolved to ${exact_count} cards; exactly zero or one is allowed.
    END
    ${existing}=    Evaluate    int($exact_count) == 1
    IF    ${existing}
        ${edit_link}=    Set Variable    ${exact_card} >> css=a[href*="/Banking/Profiles/Structured"]
        ATX D2C3 Require Exact Count    ${edit_link}    1    Reusable Structured profile edit link
        ${href}=    Get Attribute    ${edit_link}    href
        ${url}=    ATX D2C3 Absolute URL    ${href}
        Go To    ${url}
        Wait For Elements State    css=#structuredProfileForm    visible    timeout=30s
        ATX D2C3 Capture Current Page    reusable-structured-profile-existing
        ${canonical}=    Run Keyword And Return Status    ATX D2C3 Structured Profile Form Should Be Canonical    ${profile_name}
        ${published}=    Get Element Count    css=.sp-hero span.badge.bg-success:visible
        IF    ${canonical} and ${published} == 1
            ${profile_id}=    Get Property    css=#Form_Id    value
            Should Not Be Empty    ${profile_id}
            Set Dynomax Context Value    d2c3StructuredProfileId    ${profile_id}
            Go To    ${DYNOMAX_BASE_URL}Banking/Profiles/Lifecycle?id=${profile_id}
            Wait Until Keyword Succeeds    30s    500ms    ATX D2C3 Published Lifecycle Should Be Visible
            ATX D2C3 Capture Current Page    reusable-structured-profile-reuse-lifecycle
            ${current_archive}=    Set Variable    css=.row.g-3.mb-3 .col-lg-7 form[action*="handler=Archive"]:visible
            ATX D2C3 Require Exact Count    ${current_archive}    1    Reusable Structured current Published version form
            ${version_id}=    Get Property    ${current_archive} >> css=input[name="versionId"]    value
            Should Not Be Empty    ${version_id}
            Set Dynomax Context Value    d2c3StructuredProfileVersionId    ${version_id}
            Set Dynomax Context Value    d2c3StructuredProfileName    ${profile_name}
            Set Dynomax Context Value    d2c3StructuredProfileReused    ${True}
            Set Dynomax Context Value    d2c3StructuredProfilePublished    ${True}
            ATX D2C3 Progress    3    5    PASS    Existing Published reusable Structured profile is canonical and will be reused.
        ELSE
            ATX D2C3 Progress    3    5    START    Exact reusable profile exists but requires canonical test mapping and publication.
            ATX D2C3 Configure Test And Publish Reusable Structured Profile    ${profile_name}    ${profile_sample}[path]    ${True}
        END
    ELSE
        ATX D2C3 Progress    3    5    START    Reusable Structured profile is absent and will be created, tested and published.
        Go To    ${DYNOMAX_BASE_URL}Banking/Profiles/Structured
        Wait For Elements State    css=#structuredProfileForm    visible    timeout=30s
        ATX D2C3 Capture Current Page    reusable-structured-profile-new
        ATX D2C3 Configure Test And Publish Reusable Structured Profile    ${profile_name}    ${profile_sample}[path]    ${False}
    END
    ATX D2C3 Progress    4    5    START    Creating disposable Guided and Manager CSV fixtures from the canonical mapping.
    ${guided}=    Create D2c3 Structured Csv    ${temp}    Guided    ,    yyyy-MM-dd    ${True}    0    1    2    5    SeparateColumns    3    4    ${EMPTY}
    ${manager}=    Create D2c3 Structured Csv    ${temp}    Manager    ,    yyyy-MM-dd    ${True}    0    1    2    5    SeparateColumns    3    4    ${EMPTY}
    Set Dynomax Context Value    d2c3StructuredProfileName    ${profile_name}
    Set Dynomax Context Value    d2c3GuidedSamplePath    ${guided}[path]
    Set Dynomax Context Value    d2c3GuidedSampleName    ${guided}[fileName]
    Set Dynomax Context Value    d2c3ManagerSamplePath    ${manager}[path]
    Set Dynomax Context Value    d2c3ManagerSampleName    ${manager}[fileName]
    Set Dynomax Context Value    d2c3FixtureProfileDiscovered    ${True}
    Set Dynomax Context Value    d2c3StructuredProfilePreservationApproved    ${True}
    ATX D2C3 Progress    5    5    PASS    Reusable Published Structured profile and both disposable CSV fixtures are ready.

ATX D2C3 Structured Profile Form Should Be Canonical
    [Arguments]    ${profile_name}
    ${actual_name}=    Get Property    css=#Form_ProfileName    value
    ${format}=    Get Property    css=#structuredSourceFormat    value
    ${delimiter}=    Get Property    css=#Form_Delimiter    value
    ${date_format}=    Get Property    css=#Form_DateFormat    value
    ${has_header}=    Get Property    css=#Form_HasHeader    checked
    ${date_col}=    Get Property    css=#Form_DateColumn    value
    ${desc_col}=    Get Property    css=#Form_DescriptionColumn    value
    ${ref_col}=    Get Property    css=#Form_ReferenceColumn    value
    ${debit_col}=    Get Property    css=#Form_DebitColumn    value
    ${credit_col}=    Get Property    css=#Form_CreditColumn    value
    ${amount_col}=    Get Property    css=#Form_AmountColumn    value
    ${balance_col}=    Get Property    css=#Form_BalanceColumn    value
    ${mode}=    Get Property    css=#debitCreditMode    value
    ${duplicate_action}=    Get Property    css=#Form_DuplicateAction    value
    ${missing_reference_action}=    Get Property    css=#Form_MissingReferenceAction    value
    ${missing_description_action}=    Get Property    css=#Form_MissingDescriptionAction    value
    ${zero_amount_action}=    Get Property    css=#Form_ZeroAmountAction    value
    Should Be Equal As Strings    ${actual_name}    ${profile_name}
    Should Be Equal As Strings    ${format}    Csv
    Should Be Equal As Strings    ${delimiter}    ,
    Should Be Equal As Strings    ${date_format}    yyyy-MM-dd
    Should Be True    ${has_header}
    Should Be Equal As Strings    ${date_col}    0
    Should Be Equal As Strings    ${desc_col}    1
    Should Be Equal As Strings    ${ref_col}    2
    Should Be Equal As Strings    ${debit_col}    3
    Should Be Equal As Strings    ${credit_col}    4
    Should Be Empty    ${amount_col}
    Should Be Equal As Strings    ${balance_col}    5
    Should Be Equal As Strings    ${mode}    SeparateColumns
    Should Be Equal As Strings    ${duplicate_action}    Skip
    Should Be Equal As Strings    ${missing_reference_action}    Warn
    Should Be Equal As Strings    ${missing_description_action}    Error
    Should Be Equal As Strings    ${zero_amount_action}    Warn

ATX D2C3 Configure Test And Publish Reusable Structured Profile
    [Arguments]    ${profile_name}    ${sample_path}    ${existing}
    Fill Text    css=#Form_ProfileName    ${profile_name}
    Select Options By    css=#structuredSourceFormat    value    Csv
    Select Options By    css=#Form_Delimiter    value    ,
    Select Options By    css=#Form_DateFormat    value    yyyy-MM-dd
    ${has_header}=    Get Property    css=#Form_HasHeader    checked
    IF    not ${has_header}
        ATX D2C3 Safe Click    css=#Form_HasHeader
    END
    Fill Text    css=#Form_DateColumn    0
    Fill Text    css=#Form_DescriptionColumn    1
    Fill Text    css=#Form_ReferenceColumn    2
    Select Options By    css=#debitCreditMode    value    SeparateColumns
    Fill Text    css=#Form_DebitColumn    3
    Fill Text    css=#Form_CreditColumn    4
    Evaluate JavaScript    css=#Form_AmountColumn    (element) => { element.value=''; element.dispatchEvent(new Event('input',{bubbles:true})); element.dispatchEvent(new Event('change',{bubbles:true})); }
    Fill Text    css=#Form_BalanceColumn    5
    Select Options By    css=#Form_DuplicateAction    value    Skip
    Select Options By    css=#Form_MissingReferenceAction    value    Warn
    Select Options By    css=#Form_MissingDescriptionAction    value    Error
    Select Options By    css=#Form_ZeroAmountAction    value    Warn
    Upload File By Selector    css=#SampleFile    ${sample_path}
    ATX D2C3 Capture Current Page    reusable-structured-profile-before-save-test
    ${save_test}=    Set Variable    css=#structuredProfileForm button[formaction*="handler=SaveAndTest"]:visible
    ATX D2C3 Require Exact Count    ${save_test}    1    Structured profile Save Draft and Record Test action
    ATX D2C3 Safe Click    ${save_test}
    Wait Until Keyword Succeeds    60s    500ms    ATX D2C3 Structured Lifecycle Publish Outcome Should Exist
    ATX D2C3 Capture Current Page    reusable-structured-profile-tested-lifecycle
    ${errors}=    Get Element Count    css=.alert-danger:visible
    IF    ${errors} > 0
        ${feedback}=    ATX D2C3 Visible Feedback
        Fail Dynomax Action    FAIL    Reusable Structured profile could not be saved and tested. ${feedback}
    END
    ${publish_form}=    Set Variable    css=form[action*="handler=Publish"]:visible
    ATX D2C3 Require Exact Count    ${publish_form}    1    Structured profile exact-version Publish form
    ${profile_id}=    Get Property    ${publish_form} >> css=input[name="id"]    value
    ${version_id}=    Get Property    ${publish_form} >> css=input[name="versionId"]    value
    Should Not Be Empty    ${profile_id}
    Should Not Be Empty    ${version_id}
    ${disabled}=    Get Property    ${publish_form} >> css=button[type="submit"]    disabled
    IF    ${disabled}
        ATX D2C3 Progress    3    5    START    Exact tested Structured profile version requires acknowledgement before publication.
        ${ack_form}=    Set Variable    css=form[action*="handler=Acknowledge"]:visible:has(input[name="id"][value="${profile_id}"]):has(input[name="versionId"][value="${version_id}"])
        ATX D2C3 Require Exact Count    ${ack_form}    1    Structured profile exact-version acknowledgement form
        ${ack_text}=    Set Variable    Dynomax D2-C3 accepts the tested reusable Structured profile review outcome for website acceptance.
        Fill Text    ${ack_form} >> css=textarea[name="AcknowledgementText"]    ${ack_text}
        ATX D2C3 Capture Current Page    reusable-structured-profile-before-acknowledgement
        ATX D2C3 Safe Click    ${ack_form} >> css=button[type="submit"]
        Wait Until Keyword Succeeds    45s    500ms    ATX D2C3 Structured Lifecycle Publish Enabled Should Exist    ${profile_id}    ${version_id}
        ATX D2C3 Capture Current Page    reusable-structured-profile-acknowledged-lifecycle
        ${errors}=    Get Element Count    css=.alert-danger:visible
        IF    ${errors} > 0
            ${feedback}=    ATX D2C3 Visible Feedback
            Fail Dynomax Action    FAIL    Reusable Structured profile acknowledgement failed. ${feedback}
        END
        ATX D2C3 Progress    3    5    PASS    Exact tested Structured profile version acknowledgement was recorded and publication is enabled.
        ${publish_form}=    Set Variable    css=form[action*="handler=Publish"]:visible:has(input[name="id"][value="${profile_id}"]):has(input[name="versionId"][value="${version_id}"])
        ATX D2C3 Require Exact Count    ${publish_form}    1    Acknowledged Structured profile exact-version Publish form
    END
    ${publish_profile_id}=    Get Property    ${publish_form} >> css=input[name="id"]    value
    ${publish_version_id}=    Get Property    ${publish_form} >> css=input[name="versionId"]    value
    Should Be Equal As Strings    ${publish_profile_id}    ${profile_id}
    Should Be Equal As Strings    ${publish_version_id}    ${version_id}
    ${disabled}=    Get Property    ${publish_form} >> css=button[type="submit"]    disabled
    IF    ${disabled}
        Fail Dynomax Action    TEST_INVALID    Exact tested Structured profile version remained disabled after its required acknowledgement was completed.
    END
    Set Dynomax Context Value    d2c3StructuredProfileId    ${profile_id}
    Set Dynomax Context Value    d2c3StructuredProfileVersionId    ${version_id}
    ATX D2C3 Safe Click    ${publish_form} >> css=button[type="submit"]
    Wait Until Keyword Succeeds    45s    500ms    ATX D2C3 Published Lifecycle Should Be Visible
    ATX D2C3 Capture Current Page    reusable-structured-profile-published-lifecycle
    Set Dynomax Context Value    d2c3StructuredProfileName    ${profile_name}
    Set Dynomax Context Value    d2c3StructuredProfilePublished    ${True}
    Set Dynomax Context Value    d2c3StructuredProfileCreatedByWorkflow    ${True}
    Set Dynomax Context Value    d2c3StructuredProfileReused    ${existing}
    ATX D2C3 Progress    3    5    PASS    Exact reusable Structured profile version was tested and published.

ATX D2C3 Structured Lifecycle Publish Outcome Should Exist
    ${publish}=    Get Element Count    css=form[action*="handler=Publish"]:visible
    ${error}=    Get Element Count    css=.alert-danger:visible
    ${total}=    Evaluate    int($publish)+int($error)
    Should Be True    ${total} > 0

ATX D2C3 Structured Lifecycle Publish Enabled Should Exist
    [Arguments]    ${profile_id}    ${version_id}
    ${publish_form}=    Set Variable    css=form[action*="handler=Publish"]:visible:has(input[name="id"][value="${profile_id}"]):has(input[name="versionId"][value="${version_id}"])
    ${count}=    Get Element Count    ${publish_form}
    Should Be Equal As Integers    ${count}    1
    ${disabled}=    Get Property    ${publish_form} >> css=button[type="submit"]    disabled
    Should Not Be True    ${disabled}

ATX D2C3 Published Lifecycle Should Be Visible
    ${published}=    Get Element Count    xpath=//*[self::h2 or self::h3 or self::h4][normalize-space()='Version history']/following::table[1]//span[normalize-space()='Published']
    ${publish_forms}=    Get Element Count    css=form[action*="handler=Publish"]:visible
    Should Be True    ${published} >= 1
    Should Be Equal As Integers    ${publish_forms}    0

ATX D2C3 Verify Reusable Structured Profile Preserved
    ${profile_id}=    ATX D2C3 Read Optional Context    d2c3StructuredProfileId
    ${published_flag}=    ATX D2C3 Read Optional Context    d2c3StructuredProfilePublished
    IF    '${profile_id}' == '' or '${published_flag}' != 'True'
        RETURN
    END
    ${profile_name}=    Get Dynomax Context Value    d2c3StructuredProfileName    Dynomax D2C3 Structured TEST
    Go To    ${DYNOMAX_BASE_URL}Banking/Profiles?tab=user&Purpose=StructuredTransactionSource&Status=active
    Wait For Elements State    css=.bp-shell    visible    timeout=30s
    ${card}=    Set Variable    xpath=//div[contains(concat(' ',normalize-space(@class),' '),' bp-profile-card ')][.//h2[normalize-space()='${profile_name}']]
    ATX D2C3 Require Exact Count    ${card}    1    Preserved reusable Structured profile card
    ${published}=    Get Element Count    ${card} >> css=span.badge.bg-success
    IF    ${published} != 1
        Fail Dynomax Action    CLEANUP_FAILED    Reusable Structured profile ${profile_name} was not preserved as one Published profile.
    END
    ${edit_link}=    Set Variable    ${card} >> css=a[href*="/Banking/Profiles/Structured"]
    ATX D2C3 Require Exact Count    ${edit_link}    1    Preserved reusable Structured profile edit link
    ${href}=    Get Attribute    ${edit_link}    href
    ${same_profile}=    Evaluate    str($profile_id).lower() in str($href).lower()
    IF    not ${same_profile}
        Fail Dynomax Action    CLEANUP_FAILED    Preserved reusable Structured profile ID did not match the recorded profile ID.
    END
    ATX D2C3 Capture Current Page    reusable-structured-profile-preserved
    Set Dynomax Context Value    d2c3StructuredProfilePreserved    ${True}

ATX D2C3 Exact Payment Profile Row
    [Arguments]    ${name}
    ${row}=    Set Variable    xpath=//div[@id='pane-sub-profiles']//div[contains(concat(' ',normalize-space(@class),' '),' list-group-item ')][.//div[contains(concat(' ',normalize-space(@class),' '),' fw-semibold ') and normalize-space()='${name}']]
    RETURN    ${row}

ATX D2C3 Read Unique Hidden Value
    [Arguments]    ${name}    ${description}
    ${payload}=    Evaluate JavaScript    css=body    (body) => JSON.stringify(Array.from(document.querySelectorAll('input[name="${name}"]')).map(item => String(item.value || '').trim()))
    ${values}=    Evaluate    json.loads($payload)    modules=json
    ${count}=    Get Length    ${values}
    IF    ${count} < 1
        Fail Dynomax Action    TEST_INVALID    ${description} resolved to zero hidden inputs.
    END
    ${unique}=    Evaluate    sorted(set(item for item in $values if item))
    ${unique_count}=    Get Length    ${unique}
    IF    ${unique_count} != 1
        Fail Dynomax Action    TEST_INVALID    ${description} did not resolve to one non-empty value. Values=${values}
    END
    ${value}=    Get From List    ${unique}    0
    RETURN    ${value}

ATX D2C3 Read Exact Banking Batch Detail
    [Arguments]    ${batch_id}    ${label}    ${failure_status}=FAIL
    IF    '${batch_id}' == ''
        Fail Dynomax Action    ${failure_status}    ${label} has no recorded batch ID.
    END
    Go To    ${DYNOMAX_BASE_URL}Banking/Imports?activeTab=history
    Wait For Elements State    css=#historyListView    visible    timeout=30s
    ${row}=    Set Variable    xpath=//div[@id='historyListView']//div[contains(@class,'d-md-block')]//tbody/tr[.//button[@data-batch-id='${batch_id}']]
    ${row_count}=    Get Element Count    ${row}
    IF    ${row_count} != 1
        ATX D2C3 Capture Current Page    banking-history-${label}-batch-cardinality
        Fail Dynomax Action    ${failure_status}    ${label} batch ${batch_id} resolved to ${row_count} desktop history rows; exactly one was required.
    END
    ${trigger}=    Set Variable    ${row} >> css=button.js-batch-detail-trigger[data-batch-id="${batch_id}"]
    ATX D2C3 Require Exact Count    ${trigger}    1    ${label} exact BatchDetail trigger
    ${detail}=    Evaluate JavaScript    ${trigger}    async (button) => { const response=await fetch(button.dataset.batchDetailUrl,{credentials:'same-origin'}); return await response.json(); }
    ${success}=    Evaluate    bool($detail.get('success'))
    IF    not ${success}
        ${message}=    Evaluate    str($detail.get('message') or 'Unknown BatchDetail failure')
        ATX D2C3 Capture Current Page    banking-history-${label}-batch-detail-error
        Fail Dynomax Action    ${failure_status}    ${label} BatchDetail failed for ${batch_id}: ${message}
    END
    ${detail_id}=    Evaluate    str(($detail.get('batch') or {}).get('id') or '')
    IF    '${detail_id}'.lower() != '${batch_id}'.lower()
        Fail Dynomax Action    TEST_INVALID    ${label} BatchDetail returned batch ID ${detail_id} instead of ${batch_id}.
    END
    RETURN    ${detail}

ATX D2C3 Validate Imported Banking Batch
    [Arguments]    ${detail}    ${expected_file_name}    ${expected_rows}    ${label}
    ${batch}=    Evaluate    $detail.get('batch') or {}
    ${file_name}=    Evaluate    str($batch.get('fileName') or '')
    ${status}=    Evaluate    str($batch.get('status') or '')
    ${imported_rows}=    Evaluate    int($batch.get('importedRows') or 0)
    ${duplicate_rows}=    Evaluate    int($batch.get('duplicateRows') or 0)
    ${skipped_rows}=    Evaluate    int($batch.get('skippedRows') or 0)
    ${error_count}=    Evaluate    int($batch.get('errorCount') or 0)
    ${warning_count}=    Evaluate    int($batch.get('warningCount') or 0)
    ${processed_rows}=    Evaluate    int($batch.get('processedRowCount') or 0)
    ${transaction_count}=    Evaluate    int($batch.get('transactionCount') or 0)
    ${expected_status}=    Evaluate    'Failed' if int($error_count) > 0 and int($imported_rows) == 0 else ('Partial' if int($warning_count) > 0 or int($error_count) > 0 else 'Completed')
    ${valid}=    Evaluate    str($file_name)==str($expected_file_name) and int($imported_rows)==int($expected_rows) and int($transaction_count)==int($expected_rows) and int($processed_rows)==int($expected_rows) and int($duplicate_rows)==0 and int($skipped_rows)==0 and int($error_count)==0 and str($status)==str($expected_status)
    IF    not ${valid}
        Fail Dynomax Action    FAIL    ${label} BatchDetail mismatch. file=${file_name}; status=${status}; expectedStatus=${expected_status}; imported=${imported_rows}; transactions=${transaction_count}; processed=${processed_rows}; duplicates=${duplicate_rows}; skipped=${skipped_rows}; errors=${error_count}; warnings=${warning_count}; expectedRows=${expected_rows}.
    END
    Set Dynomax Context Value    d2c3LastValidatedBatchStatus    ${status}
    Set Dynomax Context Value    d2c3LastValidatedBatchWarnings    ${warning_count}

ATX D2C3 Banking Batch Should Be Reversed
    [Arguments]    ${detail}    ${batch_id}    ${label}
    ${batch}=    Evaluate    $detail.get('batch') or {}
    ${status}=    Evaluate    str($batch.get('status') or '')
    ${transaction_count}=    Evaluate    int($batch.get('transactionCount') or 0)
    ${can_undo}=    Evaluate    bool($batch.get('canUndo'))
    IF    '${status}' != 'Reversed' or ${transaction_count} != 0 or ${can_undo}
        Fail Dynomax Action    CLEANUP_FAILED    ${label} batch ${batch_id} was not proven Reversed with zero transactions and Undo disabled. status=${status}; transactionCount=${transaction_count}; canUndo=${can_undo}.
    END

ATX D2C3 Undo Exact Banking Batch
    [Arguments]    ${batch_id}    ${label}
    IF    '${batch_id}' == ''
        RETURN    ${False}
    END
    ${before}=    ATX D2C3 Read Exact Banking Batch Detail    ${batch_id}    ${label} before undo    CLEANUP_FAILED
    ${before_batch}=    Evaluate    $before.get('batch') or {}
    ${before_status}=    Evaluate    str($before_batch.get('status') or '')
    IF    '${before_status}' == 'Reversed'
        ATX D2C3 Banking Batch Should Be Reversed    ${before}    ${batch_id}    ${label}
        ATX D2C3 Capture Current Page    banking-history-${label}-already-reversed
        RETURN    ${False}
    END
    ${can_undo}=    Evaluate    bool($before_batch.get('canUndo'))
    IF    not ${can_undo}
        ${reason}=    Evaluate    str($before_batch.get('undoBlockedReason') or '')
        Fail Dynomax Action    CLEANUP_FAILED    ${label} batch ${batch_id} is not Reversed and cannot be undone. ${reason}
    END
    ${row}=    Set Variable    xpath=//div[@id='historyListView']//div[contains(@class,'d-md-block')]//tbody/tr[.//button[@data-batch-id='${batch_id}']]
    ATX D2C3 Require Exact Count    ${row}    1    ${label} exact batch row before Undo
    ${undo}=    Set Variable    ${row} >> css=form[action*="handler=Undo"]:has(input[name="batchId"][value="${batch_id}"])
    ATX D2C3 Require Exact Count    ${undo}    1    ${label} exact Undo form
    Evaluate JavaScript    ${undo}    (form) => { form.onsubmit=null; form.removeAttribute('onsubmit'); }
    ATX D2C3 Capture Current Page    banking-history-before-${label}-undo
    ATX D2C3 Safe Click    ${undo} >> css=button[type="submit"]
    Wait For Elements State    css=#pane-guided    attached    timeout=30s
    Go To    ${DYNOMAX_BASE_URL}Banking/Imports?activeTab=history
    Wait For Elements State    css=#historyListView    visible    timeout=30s
    ${after}=    ATX D2C3 Read Exact Banking Batch Detail    ${batch_id}    ${label} after undo    CLEANUP_FAILED
    ATX D2C3 Banking Batch Should Be Reversed    ${after}    ${batch_id}    ${label}
    ATX D2C3 Capture Current Page    banking-history-after-${label}-undo-verified
    RETURN    ${True}

ATX D2C3 Read Active Guided Session Id
    ${session}=    Evaluate JavaScript    css=html    (element) => window.__importSession || null
    IF    $session is None
        RETURN    ${EMPTY}
    END
    ${schema_valid}=    Evaluate    set(['id','step','status','selectedProfileId','selectedBankAccountId','originalFileName','storedFileName','hasPersistedFile','hasOwnerScopedArtifact','hasPreview','hasValidation']).issubset(set($session.keys()))
    IF    not ${schema_valid}
        Fail Dynomax Action    TEST_INVALID    Guided cleanup session JSON did not match the certified serializer schema.
    END
    ${active_id}=    Evaluate    str($session.get('id') or '')
    RETURN    ${active_id}

ATX D2C3 Abandon Guided Session If Present
    [Arguments]    ${session_id}
    IF    '${session_id}' == ''
        RETURN    ${False}
    END
    Go To    ${DYNOMAX_BASE_URL}Banking/Imports?activeTab=guided&currentStep=1
    Wait For Elements State    css=#pane-guided    attached    timeout=30s
    ATX D2C3 Capture Current Page    guided-cleanup-session-check
    ${active_id}=    ATX D2C3 Read Active Guided Session Id
    IF    '${active_id}' == ''
        RETURN    ${False}
    END
    IF    '${active_id}'.lower() != '${session_id}'.lower()
        ATX D2C3 Capture Current Page    guided-cleanup-recorded-session-absent
        RETURN    ${False}
    END
    ${form}=    Set Variable    css=form[action*="handler=AbandonSession"]:has(input[name="sessionId"][value="${session_id}"]):visible
    ${count}=    Get Element Count    ${form}
    IF    ${count} == 0
        ${trigger_count}=    Get Element Count    css=button[data-guided-cancel-import]:visible
        IF    ${trigger_count} != 1
            Fail Dynomax Action    CLEANUP_FAILED    Guided session ${session_id} is active but its visible cancel trigger resolved to ${trigger_count} elements.
        END
        ATX D2C3 Safe Click    css=button[data-guided-cancel-import]:visible
        Wait For Elements State    css=#cancelSessionModal.show    visible    timeout=10s
        ${count}=    Get Element Count    ${form}
    END
    IF    ${count} != 1
        Fail Dynomax Action    CLEANUP_FAILED    Guided session ${session_id} resolved to ${count} visible abandon forms.
    END
    Evaluate JavaScript    ${form}    (item) => { item.onsubmit=null; item.removeAttribute('onsubmit'); }
    ATX D2C3 Safe Click    ${form} >> css=button[type="submit"]
    Wait For Elements State    css=#pane-guided    attached    timeout=30s
    ${after_id}=    ATX D2C3 Read Active Guided Session Id
    IF    '${after_id}'.lower() == '${session_id}'.lower()
        Fail Dynomax Action    CLEANUP_FAILED    Guided session ${session_id} remained active after Abandon Session.
    END
    ATX D2C3 Capture Current Page    guided-cleanup-session-absence-proven
    RETURN    ${True}

ATX D2C3 Verify Payment Evidence Batch Absent
    [Arguments]    ${batch_id}
    Go To    ${DYNOMAX_BASE_URL}Banking/PaymentEvidence/Batch?id=${batch_id}
    Wait For Elements State    css=body    visible    timeout=30s
    ${workspace}=    Get Element Count    css=#paymentEvidenceBatchWorkspace
    ${not_found}=    Get Element Count    css=#pane-sub-import .alert-danger:visible
    IF    ${workspace} != 0 or ${not_found} != 1
        ATX D2C3 Capture Current Page    payment-evidence-batch-absence-unproven
        Fail Dynomax Action    CLEANUP_FAILED    Payment Evidence batch ${batch_id} was not proven absent through the website. workspaceCount=${workspace}; notFoundAlertCount=${not_found}.
    END
    ${message}=    Get Text    css=#pane-sub-import .alert-danger:visible
    ${correct_message}=    Evaluate    'payment evidence batch not found' in str($message).lower()
    IF    not ${correct_message}
        Fail Dynomax Action    CLEANUP_FAILED    Payment Evidence batch ${batch_id} returned an unexpected not-found message: ${message}
    END
    ATX D2C3 Capture Current Page    payment-evidence-batch-absence-proven

ATX D2C3 Delete Payment Evidence Batch If Present
    [Arguments]    ${batch_id}
    IF    '${batch_id}' == ''
        RETURN    ${False}
    END
    Go To    ${DYNOMAX_BASE_URL}Banking/PaymentEvidence/Batch?id=${batch_id}
    Wait For Elements State    css=body    visible    timeout=30s
    ${workspace}=    Get Element Count    css=#paymentEvidenceBatchWorkspace
    IF    ${workspace} == 0
        ATX D2C3 Verify Payment Evidence Batch Absent    ${batch_id}
        RETURN    ${False}
    END
    ${delete}=    Set Variable    css=#paymentEvidenceBatchWorkspace form[action*="handler=Delete"] button[type="submit"]:visible
    ATX D2C3 Require Exact Count    ${delete}    1    Payment Evidence batch Delete action
    Evaluate JavaScript    css=html    (element) => { window.confirm=() => true; }
    ATX D2C3 Safe Click    ${delete}
    Wait For Elements State    css=#pane-sub-import    visible    timeout=30s
    ATX D2C3 Capture Current Page    payment-evidence-batch-after-delete
    ATX D2C3 Verify Payment Evidence Batch Absent    ${batch_id}
    RETURN    ${True}

ATX D2C3 Delete Payment Evidence Profile If Present
    [Arguments]    ${profile_name}    ${profile_id}
    IF    '${profile_name}' == '' or '${profile_id}' == ''
        RETURN    ${False}
    END
    Go To    ${DYNOMAX_BASE_URL}Banking/PaymentEvidence?activeEvidenceTab=profiles
    Wait For Elements State    css=#pane-sub-profiles    visible    timeout=30s
    ATX D2C3 Capture Current Page    payment-evidence-profiles-before-delete
    ${row}=    ATX D2C3 Exact Payment Profile Row    ${profile_name}
    ${count}=    Get Element Count    ${row}
    IF    ${count} == 0
        ATX D2C3 Payment Profile Should Be Absent    ${profile_name}
        RETURN    ${False}
    END
    IF    ${count} != 1
        Fail Dynomax Action    CLEANUP_FAILED    Payment Evidence profile ${profile_name} resolved to ${count} rows.
    END
    ${form}=    Set Variable    ${row} >> css=form[action*="handler=DeletePaymentEvidenceProfile"]:has(input[name="profileId"][value="${profile_id}"])
    ATX D2C3 Require Exact Count    ${form}    1    Payment Evidence exact profile delete form
    Evaluate JavaScript    css=html    (element) => { window.confirm=() => true; }
    ATX D2C3 Safe Click    ${form} >> css=button[type="submit"]
    Wait Until Keyword Succeeds    20s    250ms    ATX D2C3 Payment Profile Should Be Absent    ${profile_name}
    ATX D2C3 Capture Current Page    payment-evidence-profile-after-delete
    RETURN    ${True}

ATX D2C3 Payment Profile Should Be Absent
    [Arguments]    ${profile_name}
    ${row}=    ATX D2C3 Exact Payment Profile Row    ${profile_name}
    ${count}=    Get Element Count    ${row}
    Should Be Equal As Integers    ${count}    0
