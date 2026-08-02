*** Keywords ***
ATX Verify Shared Context
    ${title}=    Get Dynomax Context Value    websiteTitle
    ${url}=    Get Dynomax Context Value    websiteUrl
    ${reachable}=    Get Dynomax Context Value    websiteReachable
    ${navigation_result}=    Get Dynomax Context Value    navigationResult
    ${heading_count}=    Get Dynomax Context Value    headingCount    0
    ${link_count}=    Get Dynomax Context Value    linkCount    0
    ${screenshot}=    Get Dynomax Context Value    screenshotFile
    ${resource_entries}=    Get Dynomax Context Value    resourceEntriesObserved    0
    ${current_title}=    Get Title
    ${current_url}=    Get Url
    Should Be True    ${reachable}
    Should Not Be Empty    ${navigation_result}
    Should Be Equal    ${current_title}    ${title}
    Should Be Equal    ${current_url}    ${url}
    Should Be True    ${heading_count} >= 0
    Should Be True    ${link_count} >= 0
    Should Be True    ${resource_entries} >= 0
    Should Not Be Empty    ${screenshot}
    Set Dynomax Context Value    sharedContextVerified    ${True}
