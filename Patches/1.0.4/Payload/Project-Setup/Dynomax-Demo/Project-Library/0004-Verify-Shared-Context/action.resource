*** Keywords ***
Demo Verify Shared Action Context
    ${title}=    Get Dynomax Context Value    websiteTitle
    ${url}=    Get Dynomax Context Value    websiteUrl
    ${body_length}=    Get Dynomax Context Value    bodyTextLength    0
    ${heading_count}=    Get Dynomax Context Value    headingCount    0
    ${link_count}=    Get Dynomax Context Value    linkCount    0
    ${screenshot}=    Get Dynomax Context Value    screenshotFile
    Should Not Be Empty    ${title}
    Should Not Be Empty    ${url}
    Should Be True    ${body_length} > 0
    Should Be True    ${heading_count} >= 0
    Should Be True    ${link_count} >= 0
    Should Not Be Empty    ${screenshot}
    Set Dynomax Context Value    sharedContextVerified    ${True}
