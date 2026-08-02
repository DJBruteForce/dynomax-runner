*** Keywords ***
ATX Settle Nonfunctional UI Overlays
    Evaluate JavaScript    css=html    (element) => { document.cookie='atx_cookie_consent='+encodeURIComponent('N=1;A=0;M=0')+';path=/;Secure;SameSite=Lax'; const banner=document.getElementById('cookieConsentBanner'); if(banner){banner.style.display='none';} }
    Wait Until Keyword Succeeds    5s    100ms    ATX Cookie Banner Should Not Be Visible
    Set Dynomax Context Value    overlaysSettled    ${True}

ATX Cookie Banner Should Not Be Visible
    ${count}=    Get Element Count    css=#cookieConsentBanner:visible
    Should Be Equal As Integers    ${count}    0
