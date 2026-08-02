*** Keywords ***
Demo Open Configured Website
    ${navigation_status}    ${navigation_message}=    Run Keyword And Ignore Error    Go To    ${DYNOMAX_BASE_URL}
    IF    '${navigation_status}' == 'FAIL'
        Fail Dynomax Action    BLOCKED    The configured website could not be reached: ${navigation_message}
    END
    ${load_status}    ${load_message}=    Run Keyword And Ignore Error    Wait For Load State    domcontentloaded
    IF    '${load_status}' == 'FAIL'
        Fail Dynomax Action    BLOCKED    The website did not finish loading: ${load_message}
    END
    Wait For Elements State    css=body    visible    timeout=30s
    ${title}=    Get Title
    ${url}=    Get Url
    Should Not Be Empty    ${title}
    Should Start With    ${url}    ${DYNOMAX_BASE_URL}
    Set Dynomax Context Value    websiteTitle    ${title}
    Set Dynomax Context Value    websiteUrl    ${url}
