# D2-C3 cleanup action v10 uses generator-scope-safe Guided session validation through the shared resource.
*** Settings ***
Resource    ../../Project-And-Config/Robot/ATX-D2C3.Common.resource
Resource    ../0010-Authenticate-Test-Manager/action.resource
Resource    ../0011-Settle-Ui-Overlays/action.resource
Resource    ../0012-Select-Test-Workspace/action.resource
Resource    ../0091-Logout-Test-Manager/action.resource

*** Keywords ***
ATX Run Independent D2C3 Cleanup Block
    ATX Authenticate Test Manager
    TRY
        ATX Settle Nonfunctional UI Overlays
        ATX Select Test Workspace
        ATX Clean D2C3 Website Acceptance State
    FINALLY
        ATX Logout Test Manager
    END

ATX Clean D2C3 Website Acceptance State
    ATX D2C3 Progress    1    2    START    Fresh-browser exact cleanup started.
    ATX D2C3 Capture Current Page    cleanup-start
    ${pe_batch}=    ATX D2C3 Read Optional Context    d2c3PaymentEvidenceBatchId
    ${pe_profile}=    ATX D2C3 Read Optional Context    d2c3PaymentEvidenceProfileName
    ${pe_profile_id}=    ATX D2C3 Read Optional Context    d2c3PaymentEvidenceProfileId
    ${guided_batch}=    ATX D2C3 Read Optional Context    d2c3GuidedBatchId
    ${guided_session}=    ATX D2C3 Read Optional Context    d2c3GuidedSessionId
    ${manager_batch}=    ATX D2C3 Read Optional Context    d2c3ManagerBatchId
    IF    '${pe_batch}' != ''
        ${batch_deleted_now}=    ATX D2C3 Delete Payment Evidence Batch If Present    ${pe_batch}
        Set Dynomax Context Value    d2c3PaymentEvidenceBatchAbsent    ${True}
        IF    ${batch_deleted_now}
            Set Dynomax Context Value    d2c3PaymentEvidenceBatchDeleted    ${True}
        END
    END
    IF    '${pe_profile}' != '' and '${pe_profile_id}' != ''
        ${profile_deleted_now}=    ATX D2C3 Delete Payment Evidence Profile If Present    ${pe_profile}    ${pe_profile_id}
        Set Dynomax Context Value    d2c3PaymentEvidenceProfileAbsent    ${True}
        IF    ${profile_deleted_now}
            Set Dynomax Context Value    d2c3PaymentEvidenceProfileDeleted    ${True}
        END
    END
    IF    '${guided_batch}' != ''
        ${guided_undone_now}=    ATX D2C3 Undo Exact Banking Batch    ${guided_batch}    Guided
        Set Dynomax Context Value    d2c3GuidedBatchReversedVerified    ${True}
        IF    ${guided_undone_now}
            Set Dynomax Context Value    d2c3GuidedBatchReversed    ${True}
        END
    END
    IF    '${manager_batch}' != ''
        ${manager_undone_now}=    ATX D2C3 Undo Exact Banking Batch    ${manager_batch}    Manager Data Management
        Set Dynomax Context Value    d2c3ManagerBatchReversedVerified    ${True}
        IF    ${manager_undone_now}
            Set Dynomax Context Value    d2c3ManagerBatchReversed    ${True}
        END
    END
    IF    '${guided_session}' != ''
        ${guided_abandoned_now}=    ATX D2C3 Abandon Guided Session If Present    ${guided_session}
        Set Dynomax Context Value    d2c3GuidedSessionAbsent    ${True}
        IF    ${guided_abandoned_now}
            Set Dynomax Context Value    d2c3GuidedSessionAbandoned    ${True}
        END
    END
    ATX D2C3 Verify Reusable Structured Profile Preserved
    ATX D2C3 Capture Current Page    cleanup-final-page
    Set Dynomax Context Value    d2c3CleanupComplete    ${True}
    ATX D2C3 Progress    2    2    PASS    Fresh-browser exact cleanup passed.
