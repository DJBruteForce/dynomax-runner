# D2-C3 prepare fixtures action v6 uses the lifecycle page's rendered Published state without assuming a .sp-shell root.
*** Settings ***
Resource    ../../Project-And-Config/Robot/ATX-D2C3.Common.resource

*** Keywords ***
ATX Prepare D2C3 Import Fixtures
    ATX D2C3 Progress    1    5    START    Reusable Structured profile preparation started.
    ATX D2C3 Capture Current Page    post-workspace-before-profile-preparation
    ATX D2C3 Ensure Reusable Published Structured Profile And Create Samples
    Set Dynomax Context Value    d2c3FixturesPrepared    ${True}
