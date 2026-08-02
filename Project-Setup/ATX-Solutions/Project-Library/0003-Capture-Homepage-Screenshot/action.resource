*** Keywords ***
ATX Capture Homepage Screenshot
    ${screenshot_file}=    Set Variable    ${DYNOMAX_RUN_DIR}${/}screenshots${/}homepage-full-page.png
    Take Screenshot    ${screenshot_file}    fullPage=${True}
    File Should Exist    ${screenshot_file}
    Set Dynomax Context Value    screenshotFile    homepage-full-page.png
