*** Keywords ***
ATX D2B Wait For Statement Profile Initialization
    Wait For Elements State    css=.statement-profile-page    visible    timeout=30s
    Wait For Elements State    css=#statementProfileForm    visible    timeout=30s
    Wait Until Keyword Succeeds    30s    250ms    ATX D2B Statement Controllers Should Be Ready

ATX D2B Statement Controllers Should Be Ready
    ${ready}=    Evaluate JavaScript    css=.statement-profile-page    (page) => Boolean(page && page.dataset && page.dataset.profileMode && document.querySelector('#statementProfileForm') && typeof window.__atxStatementProfileCleanup === 'function')
    Should Be True    ${ready}

ATX D2B Profile Mode Should Be Advanced
    ${mode}=    Get Attribute    css=.statement-profile-page    data-profile-mode
    Should Be Equal    ${mode}    advanced

ATX D2B Ensure Exact Profile Open
    ${profile_url}=    Get Dynomax Context Value    statementProfileUrl
    ${profile_id}=    Get Dynomax Context Value    statementProfileId
    Should Not Be Empty    ${profile_url}
    Should Not Be Empty    ${profile_id}
    ${page_count}=    Get Element Count    css=.statement-profile-page
    ${form_id_count}=    Get Element Count    css=#Form_Id
    ${already_exact}=    Set Variable    ${False}
    IF    ${page_count} == 1 and ${form_id_count} == 1
        ${current_id}=    Get Property    css=#Form_Id    value
        ${already_exact}=    Evaluate    str($current_id).strip().lower() == str($profile_id).strip().lower()
    END
    IF    not ${already_exact}
        Go To    ${profile_url}
        ATX D2B Wait For Statement Profile Initialization
        ${actual_id}=    Get Property    css=#Form_Id    value
        Should Be Equal    ${actual_id}    ${profile_id}
    ELSE
        ATX D2B Wait For Statement Profile Initialization
    END
    ${mode}=    Get Attribute    css=.statement-profile-page    data-profile-mode
    IF    $mode != 'advanced'
        Click    css=button[data-profile-mode-button="advanced"]:visible
        Wait Until Keyword Succeeds    10s    250ms    ATX D2B Profile Mode Should Be Advanced
    END

ATX D2B Active Sample Should Be Available
    [Arguments]    ${stage}
    ${input_count}=    Get Element Count    css=#SampleEvidence
    IF    ${input_count} != 1
        Fail Dynomax Action    TEST_INVALID    ${stage} sample input resolved to ${input_count} controls.
    END
    ${selected_files}=    Evaluate JavaScript    css=#SampleEvidence    (input) => input.files ? input.files.length : 0
    ${token_count}=    Get Element Count    css=#statementProfileForm input[name="SampleCacheToken"]
    IF    ${token_count} != 1
        Fail Dynomax Action    TEST_INVALID    ${stage} sample cache token resolved to ${token_count} controls.
    END
    ${token}=    Get Property    css=#statementProfileForm input[name="SampleCacheToken"]    value
    ${has_token}=    Evaluate    bool(str($token).strip())
    IF    ${selected_files} < 1 and not ${has_token}
        Fail Dynomax Action    TEST_INVALID    ${stage} lost the active sample between workflow actions; the test must preserve the exact profile page instead of reloading it.
    END

ATX D2B Open Detailed Statement Section
    [Arguments]    ${section}
    ${nav}=    Set Variable    css=.statement-config-nav button[data-section-target="${section}"]:visible
    ${count}=    Get Element Count    ${nav}
    IF    ${count} < 1
        Fail Dynomax Action    TEST_INVALID    Detailed section ${section} was unavailable.
    END
    Click    ${nav} >> nth=0
    Wait For Elements State    css=#${section}.statement-section.is-active:visible    visible    timeout=10s

ATX D2B Set OCR Mode
    [Arguments]    ${mode}
    ATX D2B Open Detailed Statement Section    extraction-method
    ${card}=    Set Variable If    $mode == 'Off'    css=label.statement-mode-card[data-ocr-mode-card="Off"]:visible    css=label.statement-mode-card[data-ocr-mode-card="Force"]:visible
    ${radio}=    Set Variable If    $mode == 'Off'    css=#OcrModeOff    css=#OcrModeForce
    ${count}=    Get Element Count    ${card}
    IF    ${count} != 1
        Fail Dynomax Action    TEST_INVALID    OCR mode ${mode} resolved to ${count} visible source-certified cards.
    END
    Click    ${card}
    ${is_checked}=    Get Property    ${radio}    checked
    Should Be Equal    ${is_checked}    ${True}
    ${selected_value}=    Get Property    css=input[name="Form.OcrMode"]:checked    value
    Should Be Equal    ${selected_value}    ${mode}

ATX D2B Resolve Advanced Extraction Action
    ATX D2B Open Detailed Statement Section    test-results
    ${basic_visible}=    Get Element Count    css=#test-results .statement-basic-only button[formaction*="handler=Test"]:visible
    IF    ${basic_visible} != 0
        Fail Dynomax Action    TEST_INVALID    Hidden Basic Test branch unexpectedly exposed ${basic_visible} visible controls while the profile is Advanced.
    END
    ${action}=    Set Variable    css=#test-results .statement-test-lab-actions button[formaction*="handler=RerunExtraction"]:visible
    ${count}=    Get Element Count    ${action}
    IF    ${count} != 1
        Fail Dynomax Action    TEST_INVALID    Advanced Test Lab extraction action resolved to ${count} visible controls.
    END
    ${label}=    Get Text    ${action}
    ${label_ok}=    Run Keyword And Return Status    Should Contain    ${label}    Extraction
    IF    not ${label_ok}
        Fail Dynomax Action    TEST_INVALID    Advanced extraction action had an unexpected label: ${label}
    END
    RETURN    ${action}

ATX D2B Statement Ajax Should Be Idle
    ${busy}=    Get Element Count    css=.statement-profile-page.is-ajax-busy
    Should Be Equal As Integers    ${busy}    0

ATX D2B Resolve Statement Ajax Outcome
    [Arguments]    ${stage}
    ${summary}=    Get Element Count    css=#statementProfileValidationSummary:not(.d-none):visible
    IF    ${summary} > 0
        ${text}=    Get Text    css=#statementProfileValidationSummary:not(.d-none):visible
        Fail Dynomax Action    FAIL    ${stage} returned visible validation errors: ${text}
    END
    ${feedback_count}=    Get Element Count    css=.statement-ajax-feedback:visible
    IF    ${feedback_count} > 1
        Fail Dynomax Action    TEST_INVALID    ${stage} rendered ${feedback_count} simultaneous AJAX feedback alerts.
    END
    IF    ${feedback_count} == 1
        ${classes}=    Get Attribute    css=.statement-ajax-feedback:visible    class
        ${text}=    Get Text    css=.statement-ajax-feedback:visible
        ${danger}=    Evaluate    'alert-danger' in str($classes).split()
        IF    ${danger}
            Fail Dynomax Action    FAIL    ${stage} returned an application error: ${text}
        END
    END

ATX D2B Read Visible Ajax Feedback
    ${count}=    Get Element Count    css=.statement-ajax-feedback:visible
    IF    ${count} != 1
        Fail Dynomax Action    FAIL    Expected exactly one visible AJAX feedback alert; found ${count}.
    END
    ${classes}=    Get Attribute    css=.statement-ajax-feedback:visible    class
    ${text}=    Get Text    css=.statement-ajax-feedback:visible
    ${danger}=    Evaluate    'alert-danger' in str($classes).split()
    IF    ${danger}
        Fail Dynomax Action    FAIL    AJAX feedback reported an application error: ${text}
    END
    RETURN    ${text}

ATX D2B Visible Ajax Feedback Should Contain
    [Arguments]    ${expected}
    ${text}=    ATX D2B Read Visible Ajax Feedback
    Should Contain    ${text}    ${expected}

ATX D2B Read Integer From Exact Selector
    [Arguments]    ${selector}    ${description}
    ${count}=    Get Element Count    ${selector}
    IF    ${count} != 1
        Fail Dynomax Action    TEST_INVALID    ${description} resolved to ${count} visible DOM values.
    END
    ${raw}=    Get Text    ${selector}
    ${raw}=    Evaluate    str($raw).strip()
    ${numeric}=    Evaluate    $raw.isdigit()
    IF    not ${numeric}
        Fail Dynomax Action    TEST_INVALID    ${description} was not an integer: ${raw}
    END
    ${value}=    Convert To Integer    ${raw}
    RETURN    ${value}

ATX D2B Read Exact Test Lab Metric
    [Arguments]    ${label}
    ${supported}=    Evaluate    $label in ('Extraction runs','Remaps')
    IF    not ${supported}
        Fail Dynomax Action    TEST_INVALID    Unsupported Test Lab metric label requested: ${label}
    END
    ${selector}=    Set Variable    xpath=//*[@id='test-results']//*[contains(concat(' ',normalize-space(@class),' '),' statement-test-lab-metrics ')]/span[small[normalize-space(.)='${label}']]/strong
    ${value}=    ATX D2B Read Integer From Exact Selector    ${selector}    Test Lab metric ${label}
    RETURN    ${value}

ATX D2B Get Extraction Run Count
    ${value}=    ATX D2B Read Exact Test Lab Metric    Extraction runs
    RETURN    ${value}

ATX D2B Get Remap Run Count
    ${value}=    ATX D2B Read Exact Test Lab Metric    Remaps
    RETURN    ${value}

ATX D2B Read Summary Metric
    [Arguments]    ${label}
    IF    $label != 'Pages processed'
        Fail Dynomax Action    TEST_INVALID    Unsupported summary metric label requested: ${label}
    END
    ${selector}=    Set Variable    xpath=//*[@id='test-results']//*[contains(concat(' ',normalize-space(@class),' '),' statement-test-summary-card ')][*[contains(concat(' ',normalize-space(@class),' '),' statement-muted ') and normalize-space(.)='${label}']]/*[contains(concat(' ',normalize-space(@class),' '),' value ')]
    ${value}=    ATX D2B Read Integer From Exact Selector    ${selector}    Summary metric ${label}
    RETURN    ${value}

ATX D2B Read Result Extraction Mode
    ${selector}=    Set Variable    xpath=//*[@id='test-results']//*[contains(concat(' ',normalize-space(@class),' '),' statement-muted ')][contains(normalize-space(.),'Provider:') and contains(normalize-space(.),'Mode:')]/strong[2]
    ${count}=    Get Element Count    ${selector}
    IF    ${count} != 1
        Fail Dynomax Action    TEST_INVALID    Result Provider/Mode footer resolved to ${count} mode values.
    END
    ${mode}=    Get Text    ${selector}
    ${mode}=    Evaluate    str($mode).strip()
    Should Not Be Empty    ${mode}
    RETURN    ${mode}


ATX D2B Verify Test Lab Status Layout
    ${payload}=    Evaluate JavaScript    css=#test-results .statement-test-lab-status:visible    (status) => { const main=status.querySelector('.statement-test-lab-status-main'); const heading=main?.querySelector('.fw-semibold'); if(!main||!heading){return JSON.stringify({valid:false,reason:'missing status main or heading'});} const mainRect=main.getBoundingClientRect(); const headingRect=heading.getBoundingClientRect(); const style=getComputedStyle(heading); const fontSize=parseFloat(style.fontSize)||16; const parsedLineHeight=parseFloat(style.lineHeight); const lineHeight=Number.isFinite(parsedLineHeight)?parsedLineHeight:fontSize*1.2; const lines=Math.max(1,Math.ceil(headingRect.height/lineHeight)); return JSON.stringify({valid:true,mainWidth:Math.round(mainRect.width),headingLines:lines,statusWidth:Math.round(status.getBoundingClientRect().width),statusScrollWidth:Math.round(status.scrollWidth),statusClientWidth:Math.round(status.clientWidth)}); }
    ${layout}=    Evaluate    json.loads($payload)    modules=json
    IF    not $layout['valid']
        ${reason}=    Evaluate    str($layout.get('reason', 'unknown'))
        Fail Dynomax Action    TEST_INVALID    Test Lab layout contract could not be evaluated: ${reason}
    END
    ${main_width}=    Evaluate    int($layout['mainWidth'])
    ${heading_lines}=    Evaluate    int($layout['headingLines'])
    ${scroll_width}=    Evaluate    int($layout['statusScrollWidth'])
    ${client_width}=    Evaluate    int($layout['statusClientWidth'])
    IF    $main_width < 220 or $heading_lines > 3 or $scroll_width > $client_width + 2
        Fail Dynomax Action    FAIL    Test Lab status layout collapsed or overflowed: mainWidth=${main_width}, headingLines=${heading_lines}, scrollWidth=${scroll_width}, clientWidth=${client_width}.
    END
    Set Dynomax Context Value    d2bTestLabLayoutVerified    ${True}

ATX D2B Ensure Checkbox State
    [Arguments]    ${selector}    ${expected}
    ${current}=    Get Property    ${selector}    checked
    IF    bool($current) != bool($expected)
        Click    ${selector}
    END
    ${actual}=    Get Property    ${selector}    checked
    Should Be Equal    ${actual}    ${expected}

ATX D2B Select Installed OCR Language
    ${count}=    Get Element Count    css=#Form_OcrLanguage option
    IF    ${count} < 1
        Fail Dynomax Action    BLOCKED    No installed OCR language option is available.
    END
    ${has_eng}=    Evaluate JavaScript    css=#Form_OcrLanguage    (select) => Array.from(select.options).some(o => o.value === 'eng')
    IF    ${has_eng}
        Select Options By    css=#Form_OcrLanguage    value    eng
    END

ATX D2B Select Installed OCR Provider
    ATX D2B Open Detailed Statement Section    ocr-engine
    ${disabled}=    Get Property    css=#Form_OcrProviderKey    disabled
    IF    ${disabled}
        Fail Dynomax Action    BLOCKED    No OCR provider is registered on the deployed ATX instance.
    END
    ${options}=    Evaluate JavaScript    css=#Form_OcrProviderKey    (select) => Array.from(select.options).filter(o=>o.value).map(o=>o.value)
    ${length}=    Get Length    ${options}
    IF    ${length} < 1
        Fail Dynomax Action    BLOCKED    OCR provider selector contains no non-empty option.
    END
    ${has_local}=    Evaluate    'local-tesseract' in $options
    IF    ${has_local}
        Select Options By    css=#Form_OcrProviderKey    value    local-tesseract
    ELSE
        ${first}=    Evaluate    $options[0]
        Select Options By    css=#Form_OcrProviderKey    value    ${first}
    END

ATX D2B Prepared Image Should Be Fully Loaded
    ${ready}=    Evaluate JavaScript    css=#ocrPreparedImage    (img) => Boolean(img && img.complete && img.naturalWidth > 0 && img.naturalHeight > 0)
    Should Be True    ${ready}

ATX D2B Canonical Remap Action Should Be Enabled
    ${action}=    Set Variable    css=#test-results .statement-test-lab-actions button[formaction*="handler=Remap"]:visible
    ${count}=    Get Element Count    ${action}
    IF    ${count} != 1
        Fail Dynomax Action    TEST_INVALID    Canonical Advanced Remap action resolved to ${count} visible controls.
    END
    ${disabled}=    Get Property    ${action}    disabled
    IF    ${disabled}
        Fail Dynomax Action    FAIL    Canonical Advanced Remap action remained disabled after interpretation settings changed.
    END

ATX D2B Normalize Validation Rules
    ${removed}=    Evaluate JavaScript    css=#validationRulesList    (list) => { const keep=new Set(['ProviderSuccess','MinimumOcrConfidence','MinimumRowCount']); const card=Array.from(list.querySelectorAll('.statement-validation-rule-card')).find(item=>!keep.has(item.querySelector('[data-rule-field="ruleKey"]')?.value||'')); if(!card)return false; card.querySelector('[data-remove-rule]')?.click(); return true; }
    WHILE    ${removed}
        Sleep    50ms
        ${removed}=    Evaluate JavaScript    css=#validationRulesList    (list) => { const keep=new Set(['ProviderSuccess','MinimumOcrConfidence','MinimumRowCount']); const card=Array.from(list.querySelectorAll('.statement-validation-rule-card')).find(item=>!keep.has(item.querySelector('[data-rule-field="ruleKey"]')?.value||'')); if(!card)return false; card.querySelector('[data-remove-rule]')?.click(); return true; }
    END
    ${count}=    Get Element Count    css=#validationRulesList .statement-validation-rule-card
    IF    ${count} != 3
        Fail Dynomax Action    TEST_INVALID    Validation rule editor retained ${count} rules instead of the certified three.
    END

ATX D2B Configure Validation Rule
    [Arguments]    ${key}    ${severity}    ${value}
    ${card}=    Set Variable    css=#validationRulesList .statement-validation-rule-card:has(input[data-rule-field="ruleKey"][value="${key}"])
    ${count}=    Get Element Count    ${card}
    IF    ${count} != 1
        Fail Dynomax Action    TEST_INVALID    Validation rule ${key} resolved to ${count} cards.
    END
    ATX D2B Ensure Checkbox State    ${card} >> css=input[data-rule-field="enabled"]    ${True}
    Select Options By    ${card} >> css=select[data-rule-field="severity"]    value    ${severity}
    IF    $value != ''
        Fill Text    ${card} >> css=input[data-rule-field="value"]    ${value}
    END

ATX D2B Normalize Recovery Attempts To Zero
    ${count}=    Get Element Count    css=#recoveryAttemptList .statement-recovery-attempt-card
    WHILE    ${count} > 0
        Click    css=#recoveryAttemptList .statement-recovery-attempt-card:last-child [data-remove-attempt]
        ${count}=    Get Element Count    css=#recoveryAttemptList .statement-recovery-attempt-card
    END

ATX D2B Recovery Attempt Count Should Be
    [Arguments]    ${expected}
    ${count}=    Get Element Count    css=#recoveryAttemptList .statement-recovery-attempt-card
    Should Be Equal As Integers    ${count}    ${expected}

ATX D2B Configure Recovery Attempt
    [Arguments]    ${index}    ${name}    ${preset}    ${psm}    ${dpi}
    ${card}=    Set Variable    css=#recoveryAttemptList .statement-recovery-attempt-card[data-attempt-index="${index}"]
    Wait For Elements State    ${card}    visible    timeout=5s
    Fill Text    ${card} >> css=input[data-attempt-field="name"]    ${name}
    Select Options By    ${card} >> css=select[data-attempt-field="preprocessingPreset"]    value    ${preset}
    Select Options By    ${card} >> css=select[data-attempt-field="pageSegmentationMode"]    value    ${psm}
    Select Options By    ${card} >> css=select[data-attempt-field="renderDpi"]    value    ${dpi}

ATX D2B Recovery History Should Be Complete
    ${count}=    Get Element Count    css=#resultRecovery .statement-recovery-history-item
    Should Be Equal As Integers    ${count}    3
