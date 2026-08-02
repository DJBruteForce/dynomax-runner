*** Keywords ***
ATX Open User Profiles Catalogue
    Go To    ${DYNOMAX_BASE_URL}Banking/Profiles?tab=user
    Wait For Elements State    css=.atx-authenticated-root    attached    timeout=30s
    Wait For Elements State    css=.bp-panel    visible    timeout=30s
    ${active}=    Get Element Count    css=.bp-tabs a.nav-link.active:visible:has-text("User Profiles")
    IF    ${active} != 1
        Fail Dynomax Action    FAIL    User Profiles catalogue did not render as the active workspace.
    END
    ${url}=    Get Url
    Set Dynomax Context Value    profilesCatalogueOpen    ${True}
    Set Dynomax Context Value    profilesCatalogueUrl    ${url}
