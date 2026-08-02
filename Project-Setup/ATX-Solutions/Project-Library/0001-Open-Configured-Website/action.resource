*** Keywords ***
ATX Open Configured Website
    ${navigation_status}    ${navigation_message}=    Run Keyword And Ignore Error    Go To    ${DYNOMAX_BASE_URL}
    IF    '${navigation_status}' == 'FAIL'
        Fail Dynomax Action    BLOCKED    The configured ATX Solutions website could not be reached: ${navigation_message}
    END
    ${load_status}    ${load_message}=    Run Keyword And Ignore Error    Wait For Load State    domcontentloaded
    IF    '${load_status}' == 'FAIL'
        Fail Dynomax Action    BLOCKED    The ATX Solutions homepage did not finish loading: ${load_message}
    END
    Wait For Elements State    css=body    visible    timeout=30s
    ${title}=    Get Title
    ${url}=    Get Url
    Should Not Be Empty    ${title}
    ${allowed_host}=    Evaluate    str($url).startswith('https://atxsolutions.co.za') or str($url).startswith('https://www.atxsolutions.co.za')
    Should Be True    ${allowed_host}
    ${navigation_result}=    Convert To String    ${navigation_message}
    Set Dynomax Context Value    websiteTitle    ${title}
    Set Dynomax Context Value    websiteUrl    ${url}
    Set Dynomax Context Value    navigationResult    ${navigation_result}
    Set Dynomax Context Value    websiteReachable    ${True}
