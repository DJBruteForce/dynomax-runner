*** Keywords ***
Demo Capture Homepage Screenshot
    ${screenshot_file}=    Set Variable    ${DYNOMAX_RUN_DIR}${/}screenshots${/}homepage-observation.png
    Take Screenshot    ${screenshot_file}
    File Should Exist    ${screenshot_file}
    Set Dynomax Context Value    screenshotFile    homepage-observation.png
