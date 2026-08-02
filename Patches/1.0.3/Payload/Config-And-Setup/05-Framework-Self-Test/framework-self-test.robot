*** Settings ***
Library    Browser
Suite Teardown    Close Dynomax Browser Safely

*** Test Cases ***
Dynomax Local Browser Engine Self Test
    New Browser    ${SELF_TEST_BROWSER}    headless=${SELF_TEST_HEADLESS}
    New Context
    New Page    ${SELF_TEST_URL}
    Wait For Elements State    css=#dynomax-self-test    visible    timeout=10s
    ${text}=    Get Text    css=#dynomax-self-test
    Should Be Equal    ${text}    Dynomax local browser self-test
    ${state}=    Get Attribute    css=#dynomax-self-test    data-dynomax-state
    Should Be Equal    ${state}    ready
    Take Screenshot

*** Keywords ***
Close Dynomax Browser Safely
    Run Keyword And Ignore Error    Close Browser
