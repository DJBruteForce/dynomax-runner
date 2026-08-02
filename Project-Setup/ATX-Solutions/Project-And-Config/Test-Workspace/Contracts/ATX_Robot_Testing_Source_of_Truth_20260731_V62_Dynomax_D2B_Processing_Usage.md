# V59 Dynomax Phase 25H-D2-B Complete Result-Contract Certification

## V59 authoritative correction

The V1.0.2 live run proved the Advanced `RerunExtraction` control and failed only because the test read a non-existent `data-tone` attribute from `.statement-ajax-feedback`. Current Razor/JavaScript renders severity through Bootstrap classes (`alert-success`, `alert-warning`, `alert-danger`) and does not render `data-tone`. The causal classification is `TEST_INVALID`, not an ATX processing failure.

V59 certifies the complete remaining D2-B browser contract in one pass:

- AJAX severity is read from the rendered `alert-*` class, never an invented attribute.
- Result mode is resolved from the source-certified Provider/Mode footer, independent of Bootstrap layout classes.
- Test Lab and summary metrics require one exact labelled DOM item; a missing metric may never silently become zero.
- Direct-text and image-OCR actions wait for the replaced Statement workspace to reinitialise before asserting results.
- Cached Remap requires one non-danger visible feedback message containing `without rerunning OCR`, unchanged extraction count and exactly one additional Remap.
- Prepare Preview proves the prepared image loaded while extraction and Remap counters remain exactly zero.
- Bounded recovery reuses the canonical Advanced extraction resolver and certifies three history items, three executed attempts, one accepted result and the expected cumulative extraction count.
- Normal and cleanup action blocks retain independent helper dependency closure and exact cleanup.

The workflow remains website-only and reuses SQL-backed session `000003`. No ATX application, ATX database or Dynomax Core change is required.

---

# V58 Dynomax Phase 25H-D2-B Advanced Test-Lab Action Correction

**Supersedes:** V57 for the D2-B processing workflow and later ATX Dynomax workflows.

## V58 authoritative correction

The V1.0.1 live run reached the exact Advanced Statement Draft and then classified the direct-text action as `TEST_INVALID` because it resolved zero visible `handler=Test` controls. Cleanup passed completely and deleted the exact disposable Draft. No processing assertion ran and no ATX application, ATX database or Dynomax Core change is justified.

Current `Statement.cshtml` renders two mode-specific branches inside `#test-results`:

- **Basic branch:** `button[formaction*="handler=Test"]`, hidden while the profile is Advanced.
- **Advanced Test Lab branch:** `.statement-test-lab-actions button[formaction*="handler=RerunExtraction"]`, rendered as **Run Extraction** before the first extraction and **Rerun Extraction** afterward.

Canonical Advanced extraction action:

```text
css=#test-results .statement-test-lab-actions button[formaction*="handler=RerunExtraction"]:visible
```

Required contract:

1. The exact profile remains in Advanced mode.
2. Open `test-results`.
3. Require zero visible Basic `handler=Test` controls.
4. Require exactly one visible Advanced Test Lab `handler=RerunExtraction` control.
5. Require its visible label to contain `Extraction`.
6. Submit it through the existing AJAX transport and classify the immediate response before reading results.
7. Both direct-text and image-OCR processing actions reuse this same source-certified action resolver.

The page handler is `StatementModel.OnPostRerunExtractionAsync`; `OnPostTestAsync` is a Basic-mode alias and must not be selected in the Advanced D2-B workflow.

**SQL requirement: NONE.**

---

# V57 Dynomax Phase 25H-D2-B Processing-Usage Contract Correction

**Supersedes:** V56 for the D2-B processing workflow and later ATX Dynomax workflows.

## Scope

This revision promotes the source-certified website-only D2-B processing scenario into reusable Dynomax actions. It reuses the accepted V55 authentication, workspace, Draft identity and cleanup actions. It does not query the ATX database and it does not claim browser proof of internal usage rows.

## Required action chain

```text
atx.auth.login
atx.ui.settle-overlays
atx.workspace.select
atx.banking.profiles.recover-stale-foundation-drafts
atx.banking.profiles.open-user-catalogue
atx.banking.profiles.create-statement-draft
atx.banking.statement.verify-exact-draft
atx.banking.d2b.prepare-statement-workspace
atx.banking.d2b.direct-text-processing
atx.banking.d2b.clear-sample
atx.banking.d2b.image-preparation
atx.banking.d2b.ocr-processing
atx.banking.d2b.cached-remap
atx.banking.d2b.bounded-recovery
atx.banking.d2b.clear-sample
cleanup: login -> overlays -> workspace -> clear sample -> exact Draft delete -> logout
```

## Acceptance contracts

- Direct selectable-PDF processing renders `Mode: DirectText`, processes one page, has extraction/remap counters `1/0`, and does not use OCR.
- Clear Sample removes both the file input and `SampleCacheToken`.
- Prepare Preview for the synthetic image creates a fully loaded prepared image while extraction/remap counters remain `0/0`.
- Image OCR renders `Mode: Ocr` with extraction/remap counters `1/0`.
- Cached Remap renders feedback containing `without rerunning OCR`, leaves extraction count unchanged, and increments Remap exactly once.
- Bounded recovery renders exactly three history items, exactly three executed results, exactly one accepted result, zero NotRun results, and exactly two total extraction runs for the image test state.
- No Guided Import, import batch or BankTransaction action is executed.
- Cleanup is a fresh authenticated tenant-scoped Robot block, clears any staged sample, deletes the exact name/GUID Draft, and records `statementProfileDeleted=true`.
- OCR/provider absence is `BLOCKED`; stale selectors/action assumptions are `TEST_INVALID`; only a certified ATX contradiction is `FAIL`.

## Synthetic evidence fixtures

- `ATX_Phase25H_D2B_Direct_Text_Statement.pdf` — SHA-256 `ab09baa9941fcb9319aeeea35f53718f06d7731e9ce136642e5d31443b17cb6e`
- `ATX_Phase25H_D2B_OCR_Statement.png` — SHA-256 `fdef0c68b6760ddbb29ff24a5815d0746d484bdba0e9f01f4cfcccbc84f81e08`

Both files are synthetic one-page Banking Statement evidence and contain no customer data.


## V57 package-contract correction

- **V1.0.0 aggregate result:** `CLEANUP_FAILED`, with causal classification `TEST_INVALID`.
- **Processing failure:** the direct-text action attempted to click `label:has(#OcrModeOff):visible` while the `source-sample` section remained active. The source-certified OCR controls are inside section `#extraction-method` and use `label.statement-mode-card[data-ocr-mode-card="Off"]` and `label.statement-mode-card[data-ocr-mode-card="Force"]`.
- **Required OCR-mode action:** open `extraction-method`, require exactly one visible source-certified mode card, click it, then verify the hidden radio's live `checked` property and selected value.
- **Cleanup failure:** `atx.banking.d2b.clear-sample` called `ATX D2B Ensure Exact Profile Open`, but that helper existed only in the earlier prepare-action resource and was not imported into the fresh cleanup Robot block.
- **Permanent action rule:** no reusable action may depend implicitly on a keyword becoming available because another action happened to run earlier. Every action must import its complete shared helper dependency set.
- **Shared helper:** every D2-B action imports `Project-And-Config/Robot/ATX-D2B.Common.resource`.
- **Dry-run rule:** normal and cleanup Robot blocks are certified separately, and dry-run test cases invoke every action keyword so unresolved nested keywords fail before installation or Chromium.
- **Observed cleanup:** the exact disposable Draft deletion passed. No import batch or BankTransaction was created.
- **ATX application/source/database change:** none required.

## Source certification manifest

- `AtxSolutions/Pages/Banking/Profiles/Statement.cshtml` — `2eedf0f8401a20a16b8490e648aee49c5e51c8e71b30d7c583392ee74183e56f`
- `AtxSolutions/Pages/Banking/Profiles/Statement.cshtml.cs` — `9bf33caddee62a723117072108610973abc23f7663947b39b63a676d244ad2fd`
- `AtxSolutions/Features/Banking/Services/SourceIngestion/BankStatementProfileTestArtifactStore.cs` — `e78e2f5966b7d383e5f2773096c4f2485bd0783e7f2ae6c8e315ea2c0109fd5d`
- `AtxSolutions/Features/Banking/Services/SourceIngestion/BankingContentExtractionService.cs` — `7fa33cd8c3bdb1781a4bca945c964b308cb56d5fc543c2201e845644055f2f04`
- `AtxSolutions/Features/Banking/Services/SourceIngestion/BankImportSourceService.cs` — `0408c09ff29a54418e7fe11d98d91cb0b7b559c69fb2f910e77d263f4ec958ba`
- `AtxSolutions/Features/Banking/Services/SourceIngestion/BankImportPdfOcrNormalizer.cs` — `df0ddbd69b9a53ae7d616b80798a4d1d03dc1b27c6abe893e318b00ab50612e7`
- `AtxSolutions/Features/Banking/Services/Usage/BankingUsageEventService.cs` — `90e333407e330a617ac0255210fa41a7e21e8398a2a5bdf49007dc02ba529eb1`

**SQL requirement: NONE.**

---

# V55 Dynomax Credential-Redaction Correction Overlay

**Supersedes:** V54 for executable Dynomax foundation and later workflows.

## V55 authoritative correction

The reusable `atx.auth.login` action must treat both runtime credential values as non-exportable evidence. Browser Library `Fill Text` logs the expanded text value and is prohibited for `ATX_TEST_USERNAME`. Use the secret-reference form for both fields:

```robot
Fill Secret    css=#Email       %ATX_TEST_USERNAME
Fill Secret    css=#Password    %ATX_TEST_PASSWORD
```

Permanent contract:

- Never expand or log either runtime credential value.
- Result `output.xml`, `log.html`, `report.html`, console logs, screenshots, context, SQL evidence and ZIP members must not contain the username or password values.
- Environment-variable names may appear; values may not.
- `secretValuesExcluded=true` is valid only after scanning the complete exported evidence.
- A credential value in exported evidence is `TEST_INVALID`, even when authentication functionally passed.

---

# V54 Historical Base — Foundation Cleanup-Session and Result-Evidence Correction Overlay

**Authority:** `ATX_Banking_Phase25H_D2B_Processing_Usage_20260731.zip` (`492f1926d1fee3781b2c6917631c5ba1343ee1513dbee24bac4395857a3e4b1a`) over Project Context File(15) and the closed D1-A/D2-A overlays.

D2-B instruments direct-text extraction, PDF/image OCR, actual recovery attempts, image preparation and cached Remap with deterministic owner-scoped usage events. The browser package remains website-only. It proves that the instrumented processing paths execute correctly, that Prepare Preview does not increment extraction/remap counters, that cached Remap does not rerun OCR, that recovery is bounded, and that disposable test state is removed. It does not query or claim browser proof of internal ledger rows. Internal event type, units, ownership, event keys and fail-closed behavior are certified by the D2-B source and unit contracts.

**SQL requirement: NONE.**

# ATX Robot Testing Source of Truth

**Generated:** 2026-07-31 14:55 SAST
**Document role:** Canonical ATX Robot Framework Browser / Playwright testing reference  
**Testing scope:** Package framework, lessons learned, source-action contracts, selector/handler matrix, validation boundaries, runtime classification and package-certification rules  
**Authoritative code pack recorded by the embedded contracts:** `ATX_Banking_Phase25H_D2B_Processing_Usage_20260731.zip` over `Project Context File(15).zip` and the approved D1-A/D2-A overlays
**Recorded D2-B authority SHA-256:** `492f1926d1fee3781b2c6917631c5ba1343ee1513dbee24bac4395857a3e4b1a`


## V54 authoritative correction and Dynomax migration boundary

This revision retains the V53 lifecycle-badge and truthful deletion-recorder corrections and adds the cleanup-session contract exposed by the first live Dynomax foundation run. No ATX application, ATX database or Dynomax Core change is justified by that result.

### Correct visible desktop Statement lifecycle badge

Current source hierarchy in `AtxSolutions/Pages/Banking/Profiles/Statement.cshtml`:

```text
.statement-page-header
  .statement-header-meta
    .statement-state-badge
```

Canonical visible desktop selector:

```text
css=.statement-page-header .statement-header-meta .statement-state-badge:visible
```

Mandatory rules:

- Assert exactly one visible badge inside the desktop page header.
- Do not assert global uniqueness of `.statement-state-badge`; responsive/mobile and Save Profile locations are intentional duplicates.
- Never restore `.statement-profile-header`, which does not exist in the current source.
- Verify `#Form_Id` and `#Form_ProfileName` before interpreting the lifecycle badge.

### Truthful fallback cleanup recording

When fallback/finally cleanup deletes the exact generated Draft:

- persist `statementProfileDeleted=true`;
- persist `deletedProfileId=<exact GUID>`;
- persist `cleanupOutcome=deleted`;
- do not leave the recorder false merely because the normal-path delete action did not run;
- distinguish `not-created`, `already-absent`, `deleted`, and `cleanup-failed`.

A recorder that contradicts Robot/Dynomax action evidence is `TEST_INVALID`.


### Dynomax cleanup Robot-block prerequisites

Dynomax 1.0.8 executes normal Robot actions and cleanup Robot actions as separate Robot blocks. Each block owns its own browser lifecycle. A cleanup action therefore must not assume that the browser, authentication cookie, active workspace or current page from the normal block still exists.

The failed foundation run proved:

```text
normal Robot block: login through exact Draft verification passed
normal browser block closed
cleanup Robot block started with a fresh anonymous browser
delete action waited for .atx-authenticated-root and timed out
```

Causal classification: `TEST_INVALID` workflow/action dependency contract. The result ZIP may record `CLEANUP_FAILED` as the runtime outcome, but it is not evidence that ATX rejected Draft deletion.

Mandatory cleanup chain for authenticated tenant-scoped cleanup:

```text
atx.auth.login                    cleanup
atx.ui.settle-overlays            cleanup
atx.workspace.select              cleanup
atx.banking.profiles.delete-exact-draft cleanup
atx.auth.logout                   cleanup
```

Rules:

- Cleanup actions must declare and establish their own prerequisites inside the cleanup block.
- Reusing `atx.auth.login`, `atx.ui.settle-overlays` and `atx.workspace.select` is required; do not duplicate their implementations in a giant delete action.
- A second login during cleanup is expected because the cleanup block uses a fresh browser session.
- The exact Draft name and GUID remain workflow context values and must be read by the cleanup block.
- When cleanup starts after a previous package failure, package-owned stale Drafts may be recovered only when each card is individually proven to have the exact `Dynomax TEST Statement Draft ` prefix, Draft state, no Published state, and an exact GUID-bound delete form.
- Protected Published profiles and the ABSA baseline are never eligible for this recovery.

### Non-PASS result ZIP preservation

A structurally complete Dynomax result ZIP is evidence even when its overall status is non-PASS.

Mandatory rules:

- Validate and preserve PASS and non-PASS result ZIPs using the same structural/hash contract.
- `Definitions/` and `TestEvidence/` are mandatory.
- `ProjectFindings/` is required only when the workflow generated project findings.
- A wrapper must not reject a valid `FAIL`, `TEST_INVALID`, `BLOCKED`, `ERROR` or `CLEANUP_FAILED` ZIP merely because it lacks an optional `ProjectFindings/` folder.
- Copy a validated non-PASS ZIP to the clipboard, report its path, retain incomplete package state and return the original non-zero workflow exit code.

### Dynomax foundation action contracts retained and extended by this revision

```text
atx.auth.login
atx.ui.settle-overlays
atx.workspace.select
atx.banking.profiles.open-user-catalogue
atx.banking.profiles.recover-stale-foundation-drafts
atx.banking.profiles.create-statement-draft
atx.banking.statement.verify-exact-draft
atx.banking.profiles.delete-exact-draft
atx.auth.logout
```

These are project-local reusable actions. They do not change Dynomax Core and they preserve the website-only runtime boundary. V54 supersedes V53 for the foundation workflow.

## Authority and use

This document consolidates the four ATX testing references into one source of truth:

1. Robot Framework Browser / Playwright package lessons and canonical runner rules.
2. Human-readable source-action matrix.
3. Exact machine-readable source-action contracts.
4. Source-action validation record.

The authority order remains:

1. Current user instruction.
2. Newest complete project ZIP and current deployed runtime evidence.
3. Newest schema export when database state matters.
4. Latest ATX Agent Context Index.
5. This ATX Robot Testing Source of Truth.
6. Older packages, chats and historical test results.

This document does **not** replace the newest project ZIP. Before generating a test, compare the embedded source hashes with the newest code. When any mapped source hash differs, classify the affected contract as stale and regenerate the mapping before test generation.

## Mandatory future-agent workflow

For test creation or correction:

1. Read this entire document.
2. Verify the embedded code-pack and source-file hashes against the newest project ZIP.
3. Select only mapped action IDs, or add and validate a new action contract first.
4. Produce a read-only action/handler/response/cleanup certification plan before generating a test.
5. Run package certification and read-only runtime preflight before the first mutation.
6. Reserve `FAIL` for certified application-contract violations.
7. Use `TEST_INVALID`, `BLOCKED` or `ERROR` for package, selector, prerequisite, environment or execution defects.


### Package-layout certification

Every generated package must declare and validate three separate file namespaces:

```text
extracted package root
payload root
installed test root
```

The installer and build simulator must consume the same `packageLayout` object. A single unscoped `requiredFiles` array is invalid.

## Single-file machine-readable contract

The JSON between the markers below is an exact embedded copy of the source-action contract file.

A validator may extract it by:

1. Finding `BEGIN ATX_ACTION_CONTRACTS_JSON`.
2. Reading the content of the immediately following `json` fenced block.
3. Stopping at `END ATX_ACTION_CONTRACTS_JSON`.
4. Parsing the extracted content as JSON.
5. Comparing its SHA-256 with the embedded source manifest below.

Do not manually edit only the matrix or only the JSON. Any contract update must update the matrix, embedded JSON and validation section together.

## Consolidation manifest

| Source | SHA-256 |
|---|---|
| `ATX Robot Framework / Lessons` | `a75525660f89dec3e7a1f64034cdad9eb9eb2a163354da717d9eba58a95fb7b3` |
| `ATX Robot Source–Action Matrix` | `425527eb80de7735aaff9f9d33af35ba0a33d88c1ba4ef8cf57b0d90ed2d1b98` |
| `ATX Robot Source–Action Contracts` | `a48ec26b476f2a5e1059d6791b227a897883337b15f6b6f4c7cfd6a9e98aca69` |
| `ATX Robot Source–Action Validation` | `28eef7c85deb2ed1d79f5aa742432056cfe01dc4e68591e87293b432370b013e` |
| `Project Context File(15).zip` | `27b22742edc384ec463c07a3ea9c608ec8b192b75c147795ce1bf6eb32a661c6` |
| `Phase 25H-D1-A package` | `f44a89caea6a881efefcbd1c02489e808f67e090fba17cde371a348b23a607a4` |
| `Phase 25H-D2-A package` | `511c6fcbb167b3d6a8597e15ed8088caef072a31d8c77a86dc96b1ad9d81becf` |
| `Phase 25H-D2-A website-only source/action extension` | `411e160bddca3c914955b147c738cd478cf05c82248576eddf9bd8f9000f7761` |
| `Phase 25H-D2-A trigger-compatible persistence overlay` | `f6ed6409c5351293a85c84bdf00afb3de6d9039058d49fe09192e152fcc3124a` |
| `Phase 25H-D2-A text-constraint correction overlay` | `460b72268ab15231923549c58bf454049554ddac6686e9c9e885ab4ac6240337` |
| `Phase 25H-D2-A concurrent Payment Evidence import recovery overlay` | `e0991d7b62887c3cbf4cd559fdbdf765708e979e78b8ca118fe6580d21756ef8` |
| `Phase 25H-D2-B Processing Usage package` | `492f1926d1fee3781b2c6917631c5ba1343ee1513dbee24bac4395857a3e4b1a` |

## Consolidation validation

- Embedded action contracts parsed successfully: **PASS**
- Embedded action count: **137**
- Unique action IDs: **137**
- Duplicate action IDs: **0**
- Embedded contract schema version: **2**
- Framework section present: **PASS**
- Matrix section present: **PASS**
- Validation section present: **PASS**
- Embedded JSON SHA-256: `0e5d301fbfb4129cc2746b3d49624e96a7df00a08b6ebfdcee6d5694af388baf`
- Note: V53 embeds the complete current JSON contract, including the D2-B processing actions; the hash above refers to that exact UTF-8 JSON text.


---

# Part I — ATX Robot Framework Browser / Playwright Rules and Lessons

# ATX Robot Framework Browser / Playwright Test-Package Lessons Learned

**Last updated:** 2026-07-30 — expanded after Help Center Tenant Guide Capture V1–V2, Guide Catalog POC V3, the completed Phase 25J PDF extraction-mode/tail and preprocessing regressions, and the focused password-protected PDF V1 handover
**Scope:** Lessons captured from the Phase 25J and Help Center self-installing Robot Framework Browser / Playwright packages, including installer, runner, selector, sample, JavaScript, reporting, cleanup, packaging, acceptance classification, guide annotation, media catalog publishing, and Windows PowerShell 5.1 compatibility failures encountered during the sessions.

## Purpose

These rules capture recurring defects found while building and running ATX self-installing Robot Framework Browser packages. Future agents must reuse these lessons instead of rediscovering them or patching one failure at a time.

The 2026-07-28 audit correlated these rules with the permanent V4 extraction-mode result, the V5/V5.1/V5.1.1 runner sequence, and the Image Preprocessing V1/V1.1/V1.2/V1.3 sequence. Historical FAIL and ERROR classifications remain unchanged even when a later package closes the scope successfully.

The 2026-07-29 continuation also records the password-protected-PDF test boundary, the separation between ATX login credentials and a document password, and the rule that encrypted exact-version linkage remains source/database proof unless the browser result directly verifies it.

The required ATX test-package model is:

```text
ZIP extracted by user
→ Install-And-Run.bat
→ Install-And-Run.ps1
→ package installed under AtxSolutions.UiTests\tests\ATX_Testing...
→ installed Run-Test.bat starts automatically
→ Run-Test.ps1 launches Robot Framework Browser
→ timestamped result directory
→ PASS / FAIL / ERROR classification
→ screenshots, output.xml, log.html, report.html and structured summaries
→ atomic non-zero result ZIP
→ validated ZIP copied to clipboard and selected in Explorer
```

---

## 1. Always derive selectors from the newest project source

Do not guess selectors from earlier packages, old screenshots, prior chats, or naming conventions.

Before generating a package, inspect the newest:

```text
Razor page
Razor PageModel
JavaScript
responsive/mobile controls
hidden transport inputs
Bootstrap navigation
live DOM state attributes
```

Several packages failed before testing ATX because they used obsolete or invented selectors.

### Failed example: obsolete Advanced-mode selector

Incorrect:

```robot
Click    css=button[data-workspace-mode="advanced"]
```

Current source used:

```html
<button data-profile-mode-button="advanced">
```

Correct:

```robot
Click    css=button[data-profile-mode-button="advanced"]:visible
```

### Failed example: nonexistent mode-state element

Incorrect:

```robot
Get Attribute    css=#WorkspaceMode    value
```

The current page stored its mode on:

```html
<div class="statement-profile-page" data-profile-mode="advanced">
```

Correct:

```robot
${mode}=    Get Attribute
...    css=.statement-profile-page
...    data-profile-mode
Should Be Equal    ${mode}    advanced
```

### Durable rule

Every selector must be source-confirmed against the latest full project ZIP. When repeated selector mismatches occur, stop issuing one-line patches and perform a complete selector audit before producing another package.

---

## 2. Read input values through DOM properties, not page text

Input field values are not part of an element's visible `innerText`.

A package incorrectly attempted:

```robot
${page_text}=    Get Text    css=.statement-profile-page
Should Contain    ${page_text}    ${DISPOSABLE_PROFILE_NAME}
```

The profile existed and the field was correctly populated, but the assertion could never pass because the value lived in:

```html
<input name="Form.ProfileName" value="...">
```

Correct approach:

```robot
${profile_name}=    Get Property
...    css=input[name="Form.ProfileName"]
...    value

Should Be Equal
...    ${profile_name}
...    ${DISPOSABLE_PROFILE_NAME}
```

The profile ID should similarly be read from its input property:

```robot
${profile_id}=    Get Property
...    css=input[name="Form.Id"]
...    value
```

### Durable rule

Use:

```text
Get Text       for visible text nodes
Get Property   for live input/select/checkbox values
Get Attribute  for static or data-* attributes
```

Do not use page text to verify form state.

---

## 3. Major progress navigation is not the same as section navigation

The Statement Profile page has different navigation systems:

```text
Desktop detailed section navigation
Desktop major progress navigation
Mobile overview navigation
```

A test incorrectly assumed every section had:

```css
button[data-section-target="save-profile"]
```

The Save Profile area is a major progress section and is reached on desktop through:

```css
button.statement-progress-step[data-major-target="save-profile"]
```

Mobile uses:

```css
[data-mobile-section-target="save-profile"]
```

Correct desktop action:

```robot
${count}=    Get Element Count
...    css=<correct-progress-container> button.statement-progress-step[data-major-target="save-profile"]:visible

Should Be Equal As Integers    ${count}    1

Click
...    css=<correct-progress-container> button.statement-progress-step[data-major-target="save-profile"]:visible
```

### Durable rule

Do not assume all sections use `data-section-target`. Confirm whether the destination is:

```text
a detailed section
a major progress step
a mobile overview item
an action inside the currently displayed section
```

Scope the selector to the correct container and assert exactly one visible match before clicking.

---

## 4. Responsive duplicate elements must be expected

ATX often renders the same state or action in multiple responsive locations.

Examples include:

```text
desktop header
mobile overview
Save Profile section
hidden desktop/mobile variants
```

A contextual-help package falsely failed because `.statement-state-badge` intentionally appeared three times.

Incorrect:

```robot
Get Element Count    css=.statement-state-badge
Should Be Equal As Integers    ${count}    1
```

Correct approaches:

```text
Scope to the visible desktop or mobile container.
Use :visible where supported.
Assert the expected visible count, not the total DOM count.
Avoid globally unique assumptions unless the source guarantees uniqueness.
```

Example:

```robot
${visible_count}=    Get Element Count
...    css=.statement-page-header .statement-header-meta .statement-state-badge:visible

Should Be Equal As Integers    ${visible_count}    1
```

### Durable rule

Inspect responsive duplicate controls before writing uniqueness assertions.

---

## 5. Hidden elements and ASP.NET fallback inputs must not be treated as active controls

An earlier package produced a false failure because it counted a hidden `.alert-danger`.

Incorrect:

```robot
${errors}=    Get Element Count    css=.alert-danger
Should Be Equal As Integers    ${errors}    0
```

Correct:

```robot
${visible_errors}=    Get Element Count    css=.alert-danger:visible
Should Be Equal As Integers    ${visible_errors}    0
```

Where `:visible` is unsuitable, inspect visibility explicitly.

### Failed example: ASP.NET checkbox hidden fallback

ASP.NET checkbox Tag Helpers commonly render both:

```html
<input id="Form_PreprocessingInvertColors"
       name="Form.PreprocessingInvertColors"
       type="checkbox"
       value="true">
<input name="Form.PreprocessingInvertColors"
       type="hidden"
       value="false">
```

This selector is ambiguous under Browser strict mode:

```robot
Get Property    css=input[name="Form.PreprocessingInvertColors"]    checked
```

It resolves to the visible checkbox and the hidden `false` transport input.

Use the source-confirmed checkbox ID or constrain by type and visibility:

```robot
${checked}=    Get Property
...    css=#Form_PreprocessingInvertColors
...    checked
```

or:

```robot
${checked}=    Get Property
...    css=input[type="checkbox"][name="Form.PreprocessingInvertColors"]:visible
...    checked
```

### Durable rule

A DOM element being present does not mean the user can see it or that it represents an active failure. For checkboxes, radio buttons and switches, explicitly exclude ASP.NET hidden fallback inputs. Prefer exact source-confirmed IDs where available.

---

## 6. Scan Robot suites for duplicate keyword definitions before packaging

The MT940/CAMT V1 package failed during Robot parsing because it contained:

```text
Structured Test Result Should Exist       defined twice
Disposable Structured Draft Card Should Exist
                                          defined twice
*** Keywords ***                          duplicated
```

Robot stopped before opening a browser.

Every package must statically verify:

```text
No duplicate custom keyword names.
No duplicate Settings, Variables, Test Cases or Keywords section headers.
No malformed continuation rows.
No duplicate test-case names.
No unresolved resource imports.
```

### Durable rule

A duplicate-keyword scan must be part of packaging validation, not discovered by the user.

---

## 7. Robot warnings on stderr must not terminate PowerShell

A critical V5 runner defect occurred because the suite logged:

```robot
Log    Creating one uniquely named Draft...    WARN
```

The runner used:

```powershell
$ErrorActionPreference = 'Stop'

& $PythonPath @robotArguments 2>&1 |
    Tee-Object -FilePath $consoleLog
```

Robot wrote the warning to stderr. Windows PowerShell converted the merged stderr stream into an error record, and `ErrorActionPreference = 'Stop'` terminated the pipeline before:

```powershell
$robotExitCode = $LASTEXITCODE
```

Consequences:

```text
robotExitCode remained -1
output.xml was truncated
Robot statistics were unavailable
log.html/report.html/xunit.xml became fallback files
the WARN text was incorrectly reported as the failure reason
the functional test never started
```

### Required runner implementation

Use a Windows PowerShell 5.1-compatible native-process implementation such as:

```text
System.Diagnostics.Process
RedirectStandardOutput = true
RedirectStandardError = true
UseShellExecute = false
CreateNoWindow = false
```

The runner must:

```text
Capture stdout.
Capture stderr as diagnostics.
Write both streams into console.log.
Allow Robot to finish.
Capture the real process exit code.
Preserve strict PowerShell error handling for the rest of the script.
Never classify stderr content alone as failure.
```

### Durable rule

Never launch Robot through:

```powershell
& $PythonPath @robotArguments 2>&1 | Tee-Object ...
```

while `$ErrorActionPreference = 'Stop'`.

Native stderr is diagnostic output, not automatic test failure.

### Mandatory runner regression probe

Every canonical runner must execute a small child process through the same native-process helper before Robot starts. The probe must:

```text
write a known marker to stdout
write a WARN-style line to stderr
exit with code 0
```

The runner must prove that:

```text
both streams were retained
stderr remained diagnostic
exit code 0 remained success
strict PowerShell error handling remained enabled outside the child process
```

This protects the contract itself instead of relying on the current Robot suite not to emit warnings.

---

## 8. PASS / FAIL / ERROR must remain distinct

Use the following meanings consistently:

```text
PASS
All required test assertions completed successfully.

FAIL
Robot completed normally, but one or more functional assertions failed.

ERROR
The test could not execute or complete validly because of a runner,
suite parsing, setup, browser, dependency, environment, or reporting failure.
```

Examples from this testing programme:

```text
Duplicate Robot keyword definitions
→ ERROR

PowerShell stderr handling terminated Robot
→ ERROR

Selector did not find a control during a valid running test
→ FAIL caused by test-package defect

ATX returned wrong provider/mode/rows
→ FAIL caused by application behavior

All assertions passed
→ PASS
```

Do not relabel a failed historical run after a later correction.

Correct durable history:

```text
V4: FAIL — test navigation defect after the four extraction scenarios ran.
V5: ERROR — runner stderr defect before Draft creation.
V5.1: separate future result.
```

A later PASS closes the acceptance scope but does not rewrite an earlier FAIL or ERROR.

---

## 9. Validate the result from completed Robot output, not console text

Classification must use:

```text
actual native process exit code
complete output.xml
Robot execution-error statistics
test PASS/FAIL statistics
required report-file existence
```

Do not derive the failure reason from the last console line or first stderr line.

After Robot exits:

```text
Confirm output.xml exists.
Confirm it is parseable and complete.
Read suite/test statistics.
Read execution errors separately.
Capture the first real failing keyword/assertion.
Generate fallback reports only when Robot genuinely did not produce usable output.
```

A warning line must never become the reported failure reason when Robot otherwise exited successfully.

---

## 10. Preview table row counts may be intentionally capped

In the scanned-PDF extraction result:

```text
Authoritative extraction count: 102
Rendered preview-table rows:    100
```

The page model deliberately exposed only:

```csharp
Rows.Take(100)
```

The test counted rendered rows and reported 100, while the authoritative result summary reported 102.

### Durable rule

Use the page's authoritative summary/statistic field for total extracted rows.

Use table-row counts only to verify:

```text
preview is populated
specific sample rows are visible
the expected preview cap is respected
```

Do not treat a capped UI table as the complete result set.

---

## 11. Separate runtime proof from source-contract proof

A browser test may prove:

```text
provider shown in the UI
actual extraction mode
row count
warning count
button behavior
saved field persistence
cleanup behavior
```

Static source inspection may separately confirm:

```text
direct-text-first provider ordering
forced-OCR selection contract
no-fallback behavior
mandatory Extraction Review policy
exact-version usage
password handling
```

Do not report a source-confirmed contract as though the browser directly asserted it.

Use explicit wording:

```text
Runtime-proven
Source-confirmed
Not reached
Not directly asserted
```

Example:

```text
Direct-text provider and mode: runtime-proven.
Direct-text review-policy outcome: source-confirmed because V4 did not record the decision code.
```

---

## 12. Do not rerun scenarios already proven in the same result

V4 completed all four extraction scenarios and failed only during the restoration tail.

The correct follow-up is a tail-only test for:

```text
Save Profile navigation
restoring original settings
Save Draft
fresh reload
persisted-value verification
recorder/source-contract checkpoint
Draft cleanup
```

It must not repeat:

```text
digital PDF direct text
scanned-PDF OCR fallback
forced OCR
direct-text-only rejection
```

### Durable rule

After a partial run, map every scenario as:

```text
Passed
Failed
Not reached
Cleanup completed
```

Build the next package only for the smallest unverified scope.

---

## 13. Disposable test data must be created and cleaned predictably

Every modifying test must:

```text
Create a uniquely named disposable TEST Draft.
Capture its exact profile ID.
Open and mutate only that exact ID.
Never edit the Published Phase 25J TEST A1 v1 profile.
Never edit the production ABSA bank statement profile.
Delete the disposable Draft in teardown.
Record whether creation, sample staging, saving, and deletion occurred.
```

Teardown must run even after a failed assertion where technically possible.

The structured recorder should distinguish:

```text
Profile created
Profile ID captured
Sample staged
Settings saved
Profile deleted
Cleanup succeeded
Artifact deletion deferred
```

A deferred physical artifact deletion can be acceptable when:

```text
the sample is detached from the profile/workspace
the token is cleared
the UI no longer references it
the artifact remains governed by evidence retention
```

Do not claim physical deletion when only logical detachment was proven.

---

## 14. Test Lab sample clearing requires multiple assertions

A successful clear should verify more than one signal:

```text
hidden sample token is empty
file input is empty
Clear Sample button is gone or disabled
workspace no longer displays the sample
recorder marks the sample detached
```

Do not assume that a successful button click proves both cache clearing and physical artifact deletion.

---

## 15. Runtime secrets must never enter packages or reports

Credentials and PDF passwords must be supplied only at runtime.

Approved variables:

```text
ATX_TEST_USERNAME
ATX_TEST_PASSWORD
ATX_TEST_PDF_PASSWORD
```

Rules:

```text
Never embed secrets in Robot files.
Never write secret values to console.log.
Never include them in TestResult.json or TestSummary.md.
Never package source PDFs merely because they are locally available.
Use Fill Secret for password fields.
Clear process-only PDF-password variables after the run.
Screenshots may show only masked fields.
```

Robot logs should retain only the variable reference or masked operation, never the value.


### Secret domains must remain explicit

ATX packages use three separate runtime values:

```text
ATX_TEST_USERNAME      ATX login username
ATX_TEST_PASSWORD      ATX login password
ATX_TEST_PDF_PASSWORD  Password for the protected PDF evidence under test
```

A secure fallback prompt must identify the exact secret domain and evidence file, for example:

```text
Enter the PDF password for:
C:\Users\TripleDK\Downloads\Test Files\image statement.pdf
```

It must not use an ambiguous prompt such as `Enter password`, because that can be confused with the ATX login, Windows account or folder access.

Do not print, repeat, persist or place the supplied value in a context file. The runner may retain only:

```text
the environment-variable name
the protected evidence filename/path
whether a value was supplied
whether the application accepted or rejected it
```

A generated wrong-password value used by the suite must also be treated as diagnostic-only test data and must not be presented as the real document secret.

---

## 16. Test evidence must match the exact scenario scope

The PDF extraction package used:

```text
C:\Users\TripleDK\Downloads\Test Files
```

with expected files such as:

```text
plain text statement.pdf
image statement.pdf
```

The package should validate before browser execution:

```text
test directory exists
required file exists
file size is greater than zero
extension matches expected type
```

Do not silently bundle private test PDFs into the package or result ZIP.

### Password-protected evidence must not leak into unrelated scopes

The first preprocessing package selected the local scanned PDF used by the password-protected-PDF work, while the preprocessing test deliberately did not request or use a PDF password. The sample therefore could not complete the intended preview flow.

Required rule:

```text
A no-password preprocessing test must use an unprotected image or scanned PDF.
A password-protected PDF belongs only in the focused password-handling scope.
Do not reuse a convenient local file merely because its content type looks suitable.
```

### Synthetic packaged evidence is allowed when appropriate

A focused visual/preprocessing test may package a generated, non-sensitive synthetic image when this makes the test deterministic and avoids private data or unrelated secrets.

The package must state that the sample:

```text
is synthetic and contains no customer data
is unprotected
exists only to exercise the named test scope
is not a production parsing benchmark
```

Private customer statements must still be resolved at runtime and must never be copied into result ZIPs.

---

## 17. Preserve one canonical BAT/PS1 runner

Do not rewrite the installer and runner from scratch for every package.

The canonical ATX runner must preserve:

```text
Install-And-Run.bat resolves its own extracted directory.
Install-And-Run.ps1 copies the package into a timestamped tests directory.
Installed Run-Test.bat supports later reruns.
Browser/Robot dependencies are detected and installed safely.
Credentials come from runtime environment variables.
Result directories are timestamped.
Robot process stdout/stderr are captured safely.
PASS/FAIL/ERROR are classified from completed Robot output.
Result ZIP creation is atomic.
ZIP is validated before clipboard operations.
Validated ZIP is copied to clipboard and selected in Explorer.
```

Every future package should copy the last known-good canonical runner and alter only package metadata or functional test content.

---

## 18. Running directly from a ZIP is unreliable

An early test package failed because Windows opened the BAT from a temporary compressed-folder path, while the referenced PowerShell file did not exist at the expected extracted path.

Required user flow:

```text
Extract the ZIP first.
Run Install-And-Run.bat from the extracted folder.
```

The BAT and installer must resolve files relative to their own physical directory:

```batch
%~dp0
```

Do not assume Windows Explorer's compressed-folder execution creates a stable extracted directory.

---

## 19. BAT and Windows PowerShell 5.1 source encoding matter

A prior package failed because the BAT contained a UTF-8 BOM or incompatible encoding.

Required BAT format:

```text
ASCII or UTF-8 without BOM
Windows CRLF line endings
```

Statically inspect the first bytes and ensure the file does not begin with:

```text
EF BB BF
```

### Windows PowerShell 5.1 UTF-8 parsing failure

A V5.1 runner was written as UTF-8 without BOM and contained an em dash. Windows PowerShell 5.1 decoded the bytes through the legacy code page. One byte became a smart-quote character, which PowerShell accepted as a string delimiter, producing cascading parser errors before the test started.

For executable `.ps1` files used by these packages:

```text
Prefer pure ASCII for runner and installer scripts.
Do not use smart quotes, em dashes or other decorative Unicode in executable PowerShell.
Keep user-facing Markdown/JSON free to use UTF-8 where safe.
```

The installer must parse the installed runner using the target machine's actual PowerShell parser before starting Robot:

```powershell
[System.Management.Automation.Language.Parser]::ParseFile(...)
```

If the parser returns any error, stop before functional testing and report the exact file, line and column.

### Durable rule

A brace-count or text-based syntax check is not equivalent to the Windows PowerShell 5.1 parser. The actual parser preflight is mandatory.

---

## 20. Do not depend on nonexistent Browser install commands

A previous test package assumed a command such as:

```text
install-browser
```

that did not exist in the user's environment.

The proven Browser installation flow is:

```powershell
rfbrowser init
```

or the source-confirmed current Robot Framework Browser command used by the established ATX runner.

Do not invent helper commands. Detect the installed tools and use the actual supported command.

---

## 21. Result ZIP creation must be atomic and non-zero

A previous package produced a zero-byte or incomplete result ZIP because the final ZIP path was written before packaging had completed.

Required process:

```text
Create result files.
Build <final-name>.building.zip.
Close all streams.
Validate temporary ZIP:
  exists
  size > 0
  opens successfully
  required entries exist
  no corrupt members
Move temporary ZIP atomically to the final name.
Validate the final ZIP again.
Only then copy it to the clipboard.
```

Never:

```text
write directly to the final ZIP path
rewrite the final ZIP in place
copy an unvalidated ZIP to the clipboard
claim success before file handles are closed
```

---

## 22. Structured summaries must match the actual package

The MT940/CAMT package passed, but copied summary wording still referred to:

```text
OFX, QIF and QBO
QBO persistence
```

The functional result remained valid, but the reporting metadata was stale.

Every package must validate that these agree:

```text
suite name
package name
test documentation
TestResult.json
TestSummary.md
console headings
result ZIP filename
format/source-family labels
persistence scenario wording
```

Do not copy a previous package and change only the Robot suite.

### Package-specific ZIP validation must not be hard-coded from another suite

The preprocessing V1 runner correctly produced Robot reports but packaging failed because the ZIP validator still required the V5 tail-only recorder filename:

```text
statement-pdf-extraction-mode-v5-tail-summary.md
```

The current suite produced preprocessing-specific recorder files instead.

Required rule:

```text
Required result entries must come from the current package manifest.
Do not leave previous-suite filenames embedded in Run-Test.ps1.
Validate that every required filename is produced before compression.
Validate that no stale recorder/report name from the source template remains.
```

Runner reuse means reusing the mechanism, not retaining another suite's metadata contract.

---

## 23. The newest complete project ZIP is authoritative

Repeated PDF-mode selector failures occurred because test generation used an older source pack.

When source and deployed UI may have changed:

```text
Request the newest complete project ZIP.
Audit all selectors and handlers against it.
Do not patch only the first reported selector.
Do not assume historical hotfixes were applied.
```

The authority order is:

```text
current user instruction
newest full project ZIP
newest schema and runtime evidence
current Agent Context Index
older packages and chats
```

---

## 24. Static validation must cover the whole package

Before delivering any ATX Robot package, validate:

```text
ZIP integrity
required files present
BAT has no BOM
PowerShell parses
Python helpers compile
Robot suite has no duplicate keywords or section headers
all resource paths resolve
all source-confirmed selectors exist
no secret values are embedded
package/result names agree
test documentation matches scope
runner uses safe native-process handling
atomic result packaging is enabled
functional test does not touch prohibited production data
```

Static validation cannot prove browser behavior, but it must eliminate predictable packaging, parser, and selector defects before the user runs the test.

### Do not overstate static-validation results

Statements such as `64/64 checks passed` mean only that the listed custom checks passed. They do not prove:

```text
Windows PowerShell 5.1 will parse the script unless its parser was actually invoked
Robot Browser strict-mode selectors will resolve against the deployed DOM
browser-side JavaScript will survive Robot variable parsing
the live application will return the expected runtime state
```

Report validation precisely:

```text
Static package checks: passed.
Target PowerShell parser preflight: included and must run locally.
Live browser/runtime behavior: unverified until the package is executed.
```

Do not describe static checks as runtime-equivalent evidence.

---

## 25. Test packages must explicitly state what they do not do

Every focused package should record boundaries such as:

```text
Does not publish.
Does not start Guided Import.
Does not create an ImportSession.
Does not create a BankImportBatch.
Does not create BankTransactions.
Does not modify the ABSA production profile.
Does not modify Published Phase 25J TEST A1 v1.
Does not package local evidence files.
```

This makes cleanup and production-impact analysis reliable after failures.

---

## 26. Keep Explorer result paths short

A validated PASS ZIP was created successfully and copied to the clipboard, but Explorer opened Desktop rather than selecting the ZIP. The final path was approximately 291 characters, exceeding limits commonly encountered by `explorer.exe /select` and legacy Windows components.

Required layout:

```text
Keep the installed test and detailed run folder under AtxSolutions.UiTests\tests\...
Copy or move the final validated result ZIP to a short shared folder such as:
D:\Development\VisualStudio\Websites\AtxSolutions\AtxSolutions.UiTests\results\
Run Explorer selection against that short final path.
```

Clipboard success and Explorer selection must be reported separately. Explorer fallback does not invalidate a correctly built ZIP.

---

## 27. Robot variable syntax can collide with browser-side JavaScript

The preprocessing V1.2 test passed JavaScript containing template literals:

```javascript
`${original.naturalWidth}x${original.naturalHeight}`
```

Robot interpreted `${original.naturalWidth}` as a Robot variable before the browser executed the script. The application preview had loaded correctly, but the test failed in its own JavaScript construction.

Safer approaches:

```javascript
String(original.naturalWidth) + "x" + String(original.naturalHeight)
```

or explicitly escape Robot-variable syntax when the syntax is genuinely required.

Static validation must scan embedded JavaScript for:

```text
${...} sequences that Robot may consume
unescaped Robot variables inside JavaScript template literals
JavaScript expressions copied from browser code without Robot parsing review
```

### Durable rule

Treat Robot as the first parser and JavaScript as the second parser. Code must be valid through both layers.

---

## 28. Diagnose from the full result ZIP, not the summary alone

`TestSummary.md` and the visible report headline often omit the exact failed keyword, teardown state and recorder evidence.

Before classifying or patching a failed package, inspect:

```text
output.xml
console.log
log.html/report.html where useful
structured recorder JSON/Markdown
screenshots
result manifest and ZIP structure
```

Determine:

```text
exact first failing keyword/assertion
what ran before it
whether a Draft was created
whether a sample was staged
whether settings were saved
whether teardown deleted the Draft
whether artifact deletion was immediate or deferred
whether later assertions were never reached
```

Do not generate another package from a one-line summary when the full result ZIP can resolve the failure.

---

## 29. Keep user-facing downloads minimal

For normal ATX test iterations, provide only the necessary test-package ZIP unless the user explicitly requests additional artifacts.

Do not add separate downloads for:

```text
checksum text files
validation reports
intermediate context files
manifests already contained in the package
```

Still report the package SHA-256 and relevant validation results in the response. Update durable context once at the end of the testing session unless the user requests an earlier update.

---

## 30. Preprocessing acceptance must distinguish preview work from extraction work

The successful preprocessing V1.3 test established a reusable acceptance pattern:

```text
Prepare Preview loads original and prepared images.
Original and prepared image hashes differ when preprocessing is active.
Preparing or regenerating a preview does not increment extraction or remap counters.
The original image hash remains unchanged after preprocessing edits.
Bitmap-affecting changes require Rerun Extraction.
Remap remains disabled for extraction-affecting changes.
A controlled rerun increments extraction count, not remap count.
Restored settings persist after Save Draft and an exact-ID fresh reload.
Sample clear and Draft deletion complete afterward.
```

Use image hashes or another deterministic bitmap identity check where available. A visible image alone does not prove that the prepared bitmap changed.

Keep the runtime conclusion scoped:

```text
The test proves preprocessing and counter behavior for the selected sample and controls.
It does not prove every preset, every OCR layout or every image-quality condition.
```

---


## 31. `Fill Secret` uses Browser environment-variable syntax, not Robot expansion

The first Help Center guide-capture package failed before login because the password argument was written as:

```robot
Fill Secret    css=#Password    %{ATX_TEST_PASSWORD}
```

`%{ATX_TEST_PASSWORD}` is Robot Framework environment-variable expansion. It expands the secret before Browser receives the call.

Robot Framework Browser `Fill Secret` must receive the environment-variable reference in Browser syntax:

```robot
Fill Secret    css=#Password    %ATX_TEST_PASSWORD
```

The username remains a normal Robot environment-variable expansion:

```robot
Fill Text      css=#Email       %{ATX_TEST_USERNAME}
```

### Durable rule

For ATX login packages:

```text
Username field:
  Fill Text with %{ATX_TEST_USERNAME}

Password field:
  Fill Secret with %ATX_TEST_PASSWORD
```

Static validation must check the exact two forms. A package must fail validation if `Fill Secret` receives `%{ATX_TEST_PASSWORD}` or a literal password value.

---

## 32. Repeated selector failures require a complete manifest and runtime preflight

The early tenant guide packages repeatedly failed on Accounting Mode and Directors because broad selectors matched ancestor cards or assumed DOM relationships that did not exist.

Failed patterns included:

```css
.card:has(h5:has-text("Directors"))
```

and:

```css
.tenant-detail-card ~ .tab-content
```

These failures showed that describing a selector as “source-confirmed” is not enough unless the exact source element, relationship and expected visible count were actually recorded.

The successful V2 approach used a selector manifest containing, for every guide target:

```text
Guide step
Razor source file
Source anchor
Source-file hash
Selector
Expected visible count
Required or optional status
```

The browser then validated every required selector before the first guide screenshot was captured.

### Required preflight behavior

```text
1. Load the selector manifest.
2. Navigate through all required pages and tabs.
3. Check every required selector.
4. Record actual visible match count.
5. Record pass, missing or ambiguous.
6. Produce selector-preflight.json and selector-preflight.md.
7. Stop before guide capture when any required selector fails.
8. Begin screenshots only after the complete preflight passes.
```

This prevents the user from waiting through a long capture only to discover one broken selector at the end.

### Durable rule

Source proof and runtime proof are separate requirements:

```text
Source proof:
The selector maps to an exact element in the newest supplied code.

Runtime proof:
The selector resolves to the expected number of visible controls in the deployed DOM.
```

Do not claim a guide package is selector-audited until both layers have passed.

---

## 33. Annotation overlays must be viewport-safe and use the approved guide colour

The user approved light-blue guide annotations rather than purple.

Approved annotation colour:

```text
#38BDF8
```

Use it consistently for:

```text
target boxes
arrows
arrowheads
step badges
callout borders
```

A callout may not extend outside the browser viewport. Before taking each screenshot, the annotation helper must:

```text
Scroll the target into a useful centered position.
Measure the target rectangle.
Create and measure the callout.
Try below, above, right and left placements.
Choose a placement that fits completely inside the viewport.
Clamp the fallback position to viewport bounds.
Assert the final callout rectangle is fully visible.
Only then capture the screenshot.
```

### Durable rule

A screenshot is not acceptable merely because the target is visible. The entire annotation bubble, arrow and step badge must be inside the captured viewport.

---

## 34. Normal test packages and guide-capture packages have different primary outputs

The canonical ATX functional test contract remains unchanged:

```text
Robot execution
PASS / FAIL / ERROR
output.xml
log.html
report.html
structured summaries
screenshots
validated result ZIP
```

Help Center guide capture reuses the same runner and browser evidence, but has a separate publishing pipeline after successful capture.

Do not modify or weaken the standard test-package behavior to support guide publishing.

### Guide-capture output model

A guide package should organize customer-facing artifacts by topic instead of placing every screenshot in one flat evidence folder:

```text
guide-catalog\
  index.html
  summary.html
  contact-sheet.html
  catalog.json
  sections\
    01-create-tenant\
    02-tenant-overview\
    03-business-and-contact\
    04-directors\
    05-addresses\
    06-banking\
    07-settings-and-tax\
    08-services-documents-notifications\
  media\
    slideshow.html
    contact-sheet.png
    walkthrough.gif
    walkthrough.mp4
    walkthrough.webm
```

Each section should contain ordered images plus section metadata and, where useful, a section HTML page.

### Durable rule

Treat the guide publisher as an output adapter that runs only after the proven browser flow succeeds:

```text
Shared automation core
  login
  navigation
  selector preflight
  annotation
  screenshot capture
  cleanup
  Robot evidence

Guide publisher
  section folders
  thumbnails
  catalog JSON
  HTML gallery
  contact sheet
  slideshow
  optional GIF / MP4 / WebM
```

A publishing failure must not falsify the Robot functional result. Report browser-test status and guide-publishing status separately.

---

## 35. Generated guide artifacts must be surfaced, not buried only in Robot reports

A successful V2 guide capture generated 27 annotated screenshots, `guide.json` and a complete HTML guide, but the user initially saw only the Robot PASS report.

Robot `log.html` and `report.html` do not automatically present arbitrary customer-facing files.

For guide-specific packages, a PASS should:

```text
Open the generated guide index.html.
Open or select the guide-catalog folder in Explorer.
Print the exact catalog path.
Print screenshot and section counts.
Print which media formats were generated or skipped.
Still create the validated evidence ZIP for audit and chat handback.
```

The guide catalog is the primary local deliverable. The result ZIP remains the evidence and transport artifact.

### Optional media rules

```text
slideshow.html:
Always generate; it can crossfade ordered screenshots without external tools.

contact-sheet.png:
Generate when the local image helper succeeds.

GIF / MP4 / WebM:
Generate when a compatible FFmpeg executable is available.
Record skipped formats and the reason in media-generation.json.
Do not classify the browser guide capture as failed solely because an optional media codec is unavailable.
```

### Durable rule

The summary must distinguish:

```text
Browser capture: PASS / FAIL / ERROR
Guide catalog: GENERATED / PARTIAL / FAILED
Optional media: generated formats and skipped formats
Evidence ZIP: validated path and hash
```

---


## 36. Password-protected PDF acceptance must separate runtime and source proof

A focused password regression has two distinct evidence layers.

### Runtime/browser proof

The browser package may prove:

```text
The password input is type=password and visibly masked.
Autocomplete metadata matches the intended security design.
A generated wrong password is rejected without losing the staged sample.
The correct runtime password unlocks the protected evidence.
A saved password can be resolved after an exact-ID reload while the input remains blank.
Blank-save preserves an existing secret when preserve semantics are intended.
Submitting a replacement updates the usable saved secret.
Clear removes the saved-secret state.
After clear, a blank password no longer unlocks the protected evidence.
Exported profile JSON contains no password property or secret value.
The temporary sample is detached.
The disposable Draft is deleted.
No ImportSession, BankImportBatch or BankTransaction is created.
```

### Source/database proof

The browser alone does not prove ciphertext-at-rest or the exact database relationship. Unless a safe read-only database check is included, report these separately as source-confirmed:

```text
ASP.NET Core Data Protection is used for encryption.
The secret is owner-scoped.
The secret is linked to the exact profile version.
Published/exact-version references protect required secrets from cleanup.
Profile JSON, snapshots, audit payloads and telemetry exclude password fields.
```

Do not describe source inspection as runtime encryption proof.

### Leakage checks

The result audit must inspect all generated evidence that can contain text or metadata:

```text
console.log
output.xml
log.html
report.html
xunit.xml
structured JSON and Markdown summaries
profile JSON exports
screenshot names and visible screenshot content
result ZIP member names
```

Where the runtime can safely hold the value only in process memory, scan generated text artifacts for that value before packaging, then clear the process-only variable. Do not write the secret into an intermediate scan report.

---

## 37. Current Phase 25J Robot status after preprocessing V1.3

Confirmed permanent results from the 2026-07-28/29 sequence:

```text
PDF extraction-mode V4
  FAIL — test-package Save Profile navigation defect after all four extraction
  scenarios completed successfully.
  The four provider/mode behaviours are closed and must not be rerun.

V5
  ERROR — merged Robot stderr terminated the PowerShell pipeline before Draft creation.

V5.1
  ERROR — Windows PowerShell 5.1 source-encoding/parser defect before Robot execution.

V5.1.1
  PASS — tail-only Draft creation, exact-ID identity, unsaved change/restoration,
  Advanced Save Profile navigation, Save Draft persistence, fresh reload,
  source-contract checkpoint and Draft deletion.

Image Preprocessing V1 / V1.1 / V1.2
  Test-package defects: hidden checkbox fallback selector and stale result filenames;
  protected evidence selected in a no-password scope; Robot/JavaScript `${...}` collision.

Image Preprocessing V1.3
  PASS — original/prepared preview, bitmap identity change, extraction/remap counters,
  Rerun Extraction requirement, restored persistence, sample clear and Draft deletion.
```

Current prepared package:

```text
ATX_Statement_Password_Protected_PDF_Security_Regression_V1.zip
```

Status:

```text
Prepared from the current source audit.
No ATX application source change was made.
Runtime result has not yet been supplied.
Do not mark password handling PASS or FAIL until the full result ZIP is audited.
```

Its protected runtime evidence is resolved from:

```text
C:\Users\TripleDK\Downloads\Test Files\image statement.pdf
```

and its secret is supplied through `ATX_TEST_PDF_PASSWORD` or a secure fallback prompt. Never record the actual value.

The exact next Robot action is to run this package and audit its full result ZIP. After that result is classified, continue only with the next unverified Phase 25J scope.

Remaining focused Robot work after the password result:

```text
1. Screenshot/image upload and clipboard paste.
2. Multiple screenshots, image-only ZIP and PDF-only ZIP.
3. Ordering, exact deduplication, per-file attribution and mixed PDF/image ZIP rejection.
4. Transaction/ignore regions, start/end anchors and automatic/manual column bands.
5. Wrapped rows, same-date/source ordering, amount/debit/credit signs and balance-chain repair.
6. A genuine low-confidence sample, bounded recovery and best-result selection.
7. Failed final-import retry/idempotency without duplicate sessions, batches or transactions.
8. Advanced/source-family ownership, operation, artifact, account and exact-version lineage.
9. Cross-tenant denial and focused remaining July 27 UI/runtime checks.
10. Final Phase 25J acceptance matrix and cleanup verification.
```

Mobile/responsive acceptance remains deferred unless the user reactivates it. After Phase 25J, the project sequence is Phase 25H-D, then Phase 25I, then a stop before Phase 26 automation.


## 38. Source-action coverage must include navigation and immediate-response readers

Mapping only the final field or button is insufficient when the browser must first enter a section or classify an AJAX replacement.

Before a test uses a detailed section, major progress section or AJAX handler, the source of truth must map:

```text
the exact navigation system
the exact scoped visible selector
the active-section postcondition
the immediate response/validation contract
the authoritative result reader
```

A test may not invent navigation selectors inside `Test.robot`. Missing navigation or response actions must be added and revalidated here before the package is generated.


## 39. Package root, payload and installed paths are separate namespaces

A certified OCR package failed before Robot because its manifest listed:

```text
PACKAGE_CONTENT_SHA256SUMS.txt
```

inside one ambiguous `requiredFiles` array.

The file physically existed at:

```text
<extracted package root>\PACKAGE_CONTENT_SHA256SUMS.txt
```

but the installer resolved every `requiredFiles` entry as:

```text
<extracted package root>\payload\<entry>
```

It therefore looked for the nonexistent path:

```text
payload\PACKAGE_CONTENT_SHA256SUMS.txt
```

The earlier build simulation did not catch this because it manually copied the root checksum into the simulated installed directory before running the post-install certifier. That bypassed the real installer's failing pre-copy check.

### Mandatory manifest layout

Every self-installing package must use separate properties:

```json
{
  "packageLayout": {
    "packageRootRequiredFiles": [],
    "payloadRequiredFiles": [],
    "installedRequiredFiles": [],
    "rootToInstallCopies": []
  }
}
```

Their meanings are fixed:

```text
packageRootRequiredFiles
  Resolve from the extracted ZIP root.

payloadRequiredFiles
  Resolve from the extracted ZIP's payload folder.

installedRequiredFiles
  Resolve from the timestamped installed test root after copying.

rootToInstallCopies
  Explicitly map any root file that must also exist in the installed test root.
```

The property `requiredFiles` is prohibited because its base directory is ambiguous.

### Mandatory copy-graph validation

Before creating the downloadable ZIP, the package builder must:

```text
1. Validate every package-root requirement against the extracted package root.
2. Validate every payload requirement against the payload folder.
3. Verify the package checksum manifest against the extracted package tree.
4. Create an empty simulated install directory.
5. Copy payload contents exactly as the installer does.
6. Apply only the declared rootToInstallCopies mappings.
7. Validate every installed requirement.
8. Prove every installed requirement has exactly one producer.
9. Reject undeclared manual seeding of the simulated install directory.
10. Build the ZIP, extract it again, and repeat the same simulation.
```

A post-install certifier is not a substitute for testing the pre-install layout. Both stages are required.

### Classification

Any package-root, payload, mapping or installed-file mismatch is:

```text
TEST_INVALID
```

It must stop before credentials, Robot and Chromium.


## 40. HTML `href` values are not automatically valid Browser `Go To` URLs

A certified OCR package read this valid catalogue anchor value:

```text
/Banking/Profiles/Statement?id=<GUID>
```

The package then called:

```robot
Go To    ${href}
```

Robot Framework Browser passed the root-relative string to Playwright `page.goto`, which requires an absolute URL in this context. The read-only preflight stopped with:

```text
Cannot navigate to invalid URL
```

### Approved navigation

Prefer the actual user action after identity checks:

```robot
${href}=    Get Attribute    ${exact_card_configure_anchor}    href
# verify exact GUID in ${href}
Safe Click    ${exact_card_configure_anchor}
```

When direct navigation is genuinely necessary:

```javascript
new URL(href, document.baseURI).href
```

Then verify:

```text
resolved URL is absolute
resolved origin equals the configured ATX base origin
resolved path and exact GUID match the source-action contract
```

Only then may Browser `Go To` receive the resolved URL.

### Prohibited pattern

```robot
${href}=    Get Attribute    ${selector}    href
Go To      ${href}
```

This is prohibited even when the source anchor is correct, because the browser may render an absolute, protocol-relative, root-relative or document-relative value.

### Mandatory validation gate

Before packaging, scan the complete Robot suite for every `Get Attribute ... href` flow and reject:

```text
raw href passed to Go To
unverified cross-origin resolved URL
string concatenation that assumes one fixed href form
```

A relative-href navigation defect is `TEST_INVALID` and must stop before mutation.


## 41. Repeated actions require render-location contracts, not global uniqueness

A certified OCR run reached the Advanced Save Profile section and correctly found:

```text
#save-profile button[data-visible-save-and-exit]:visible
```

The test expected one element, but the source intentionally renders two visible desktop controls inside that section:

```text
1. Primary Save card — Save Draft & Exit
2. Save-section footer — Save Draft & Exit
```

The failure screenshot showed both controls simultaneously. The source also contains a page-header variant and a mobile sticky variant.

### What was wrong

The action contract described the handler but did not enumerate every render location or its expected visibility. The test therefore used a combined selector and made an invalid uniqueness assertion:

```robot
${save_exit}=    Get Element Count
...    css=#save-profile button[data-visible-save-and-exit]:visible
Should Be Equal As Integers    ${save_exit}    1
```

The correct desktop contract is:

```text
canonical primary selector count = 1
footer equivalent selector count = 1
combined Save-section count      = 2
mobile sticky count              = 0
```

### Mandatory rule

For every repeated action, the source of truth must record:

```text
semantic action ID
every render location
viewport and mode visibility
expected count per location
canonical click target
equivalent handler proof
```

A test must never assert that an intentionally repeated action is globally unique.

### Classification

A wrong expected count or an unscoped repeated-action selector is:

```text
TEST_INVALID
```

It does not justify an application change.


## 42. Direct multi-file selection and uploaded ZIPs are different contracts

The Guided Import file input supports multiple selections, but the server treats the cases differently:

```text
multiple browser-selected images
  server creates a synthetic screenshot ZIP
  entry names receive 01_, 02_, ... prefixes in selection order

one uploaded image-only ZIP
  server retains the archive and processes image entries in FullName order

one uploaded PDF-only ZIP
  server uses the PDF archive extraction path

one uploaded mixed PDF/image ZIP
  archive safety rejects it before session-file persistence
```

Future tests must not infer user ZIP entry order from archive insertion order. Image archive processing sorts by entry `FullName`.

Screenshot deduplication is exact and uses:

```text
date + normalized description + amount + balance
```

A fuzzy-looking overlap is not a valid dedup assertion unless the runtime fields prove the exact fingerprint is identical.

Every focused archive test must:

```text
create one exact session per scenario
read immediate feedback/redirect
verify per-file summaries and row-level source properties
not accept extraction
not perform final import
abandon the exact session
```


## 43. OCR acceptance samples must be calibrated, and suite classifications must aggregate

A direct multiple-image run reached Extraction Review with both source summaries and four correctly ordered dates:

```text
2026-05-28
2026-05-29
2026-05-30
2026-05-31
```

The package required a fifth row:

```text
2026-06-01 — Bank service fee
```

That same row had already been omitted by the earlier single-image OCR baseline. Requiring it again created a preventable `BLOCKED` result.

### Evidence rule

After a deployed OCR profile has shown a synthetic row to be unstable:

```text
do not require the same row again
```

The next package must either:

```text
remove it from the acceptance dataset
or
calibrate it successfully before the combined scenario
```

A `BLOCKED` calibration outcome is useful once. Repeating the same known unstable datum is `TEST_INVALID`.

### Independent scenario rule

Do not place all independent archive scenarios in one Robot test case. A failure in the first scenario otherwise prevents evidence collection for the remaining scenarios.

Use:

```text
one Robot test case per scenario
one exact session per test
per-test cleanup
suite-level recorder finalization
```

### Classification rule

Robot's `${SUITE MESSAGE}` may contain only aggregate prose such as:

```text
1 test, 0 passed, 1 failed
```

It does not preserve the ATX classification prefix.

The custom library must record the classification before raising, and the runner must aggregate all failure messages using:

```text
ERROR > TEST_INVALID > FAIL > BLOCKED > PASS
```

Runner status, recorder status and ZIP suffix must always agree.


## 44. Browser session-state names must come from the serializer, not the entity

A mixed PDF/image ZIP was correctly rejected and visibly remained at Guided Step 2. The test nevertheless raised an application failure because it read:

```javascript
s.currentStep ?? s.CurrentStep ?? 0
```

The server actually serializes:

```csharp
step = session.CurrentStep
```

with a camelCase naming policy. The browser property is therefore:

```javascript
s.step
```

The fallback to `0` manufactured a false application violation.

### Mandatory rule

Before a Robot package reads `window.__importSession`:

```text
1. Verify the current source hash.
2. Map the exact `SerializeSessionState` property list.
3. Validate the browser object schema.
4. Reject missing or renamed properties as TEST_INVALID.
5. Read only the exact serialized names.
6. Never default a missing property to a value that can become application FAIL.
```

For mixed-archive rejection, the application assertion may run only after:

```text
exact schema present
exact session id confirmed
URL currentStep=2 confirmed
#stepPane2 visible
```

A schema-valid state violation is an application failure. A property-name or schema-mapping error is `TEST_INVALID`.


## 44. Dynamic advanced editors must be tested through visible controls

Regions, anchors and manual columns are client-rendered editors backed by hidden JSON fields.

The accepted pattern is:

```text
click the visible add/use action
→ edit generated visible controls
→ dispatch the control's normal input/change event
→ read hidden JSON only to verify normalization
```

The prohibited pattern is:

```text
write OcrRegionsJson directly
write AnchorRulesJson directly
write ColumnMappingsJson directly
```

Direct JSON writes bypass render-location, normalization and validation behavior and make the test invalid.

For the dedicated visual-layout acceptance Draft:

```text
one Transactions region
one Ignore region
two anchors
five manual columns
signed amount rules
wrapped-row settings
strict duplicate settings
running-balance validation
```

Initial OCR and cached-geometry Remap are separate actions. Column/interpretation changes use Remap & Validate rather than repeating OCR.


## 45. Route-prefix selectors must not cross action namespaces

A certified Statement Interpretation package opened the New profile dropdown and then used:

```text
a[href^="/Banking/Profiles/Statement"]:visible
```

The page contained:

```text
1 Statement create-menu link
2 existing Statement-profile Configure links
```

The package therefore saw three elements and stopped with:

```text
3 != 1
```

### Mandatory fix

Create-menu navigation must be scoped to the create dropdown and use the exact destination:

```text
ul[aria-labelledby="newProfileDropdown"]
  a.dropdown-item[href="/Banking/Profiles/Statement"]:visible
```

Existing profile Configure links must remain scoped to one exact profile card.

### Cleanup reporting lesson

The same run stopped before creating a Draft. Teardown succeeded because there was nothing to clean, but the recorder incorrectly wrote `exactDraftDeleted=true`.

No-op cleanup and object deletion are different outcomes and must never be conflated.


## 46. Visible DOM is not client-controller readiness

An Statement Interpretation run successfully navigated to a new Statement page and Browser reported:

```text
Clicks the element 'button[data-profile-mode-button="advanced"]'
```

but `data-profile-mode` remained:

```text
basic
```

The source initializes the mode listener through `initializeStatementProfilePage()` after page markup is rendered. The test clicked during the gap between DOM visibility and controller initialization.

### Permanent gate

Before any client-controlled Statement action:

```javascript
typeof window.__atxStatementProfileCleanup === 'function'
```

must return true.

This gate applies after:

```text
full page navigation
Save/Exit exact reload
Statement AJAX replacement
```

Do not fix the test by writing the page dataset or localStorage directly. The visible user action must still be used after readiness.

---

## 47. AJAX replacement completion is not prepared-image load readiness

Statement Interpretation V1 clicked the certified Prepare Preview action and received a valid replacement page. The test immediately counted `#ocrPreparedImage:visible` and raised an application failure, while the failure screenshot showed that the prepared image rendered shortly afterward.

The page replacement and controller reinitialisation complete before the browser necessarily finishes loading the processed image resource. The certified postcondition is therefore:

```text
AJAX response accepted
→ replacement Statement page initialised
→ scoped SampleCacheToken is non-empty
→ Regions & Anchors section is visible
→ #ocrPreparedImage is visible
→ image.complete is true
→ naturalWidth and naturalHeight are greater than zero
```

An immediate image-count assertion before this bounded readiness gate is `TEST_INVALID`, not an ATX application failure.

Cleanup evidence must also be written after a successful exact deletion. Do not skip `Record Cleanup` merely because the in-memory `PROFILE_DELETED` flag is already true.


## 48. Dynamic manual-column cards require stable identity

Statement Interpretation V1.1 reached the seven-card manual mapping and attempted to edit cards by `nth-child`. The column-mapping controller sorts by `leftPercent` and replaces the list DOM during every render. Boundary changes therefore moved cards while the package continued addressing positions rather than the original cards.

The result contained all seven requested fields, but `Reference`, `SignedAmount` and `Debit` were attached to different positional bands. This was a package/action-contract defect, not proof that ATX failed to persist a stable user edit.

Required sequence:

```text
reach seven cards through visible controls
→ capture each data-column-id
→ target all later inputs/selects by data-column-id
→ set boundaries using a non-crossing sequence
→ verify final visible identity order
→ verify normalized ColumnMappingsJson
→ Remap
```

Any package that continues using `nth-child` after a field/boundary re-render is `TEST_INVALID`.


## 49. Generated Python bytecode must never enter a package

Statement Interpretation V1.2 was delivered with `payload/resources/__pycache__/AtxCertifiedInterpretationLibrary.cpython-313.pyc`. The builder generated or retained that mutable bytecode inside the package tree and then compiled the Python source again after checksum generation. The `.pyc` bytes changed, so the installer correctly rejected the package before Robot started.

This failure class is permanently prohibited.

Required package contract:

```text
no __pycache__ directory
no .pyc file
no .pyo file
Python syntax validation runs outside the package tree
checksums are generated only after the tree is final
final ZIP is extracted and scanned again
installer scans package root before checksum validation
installed certifier scans installed root before Chromium
PYTHONDONTWRITEBYTECODE=1 and python -B are mandatory
```

A generated-bytecode artifact is `TEST_INVALID`. It is never an ATX application failure.


## 50. Wrapped-row calibration must not use a date-only starter line

Statement Interpretation V1.2.1 reached cached Remap, but the original synthetic sample produced three rows. Its first transaction used a date-only line above the description and values. OCR/table reconstruction merged that transaction with the following same-date row, so the sample could not prove wrapped-row reconstruction and same-date ordering independently.

Permanent sample contract:

```text
every intended transaction starts on a complete dated row
first transaction includes its date, identity, amount source and balance on that row
exactly one undated continuation-description line follows it
second same-date transaction is on a separate visual baseline
reference values avoid 0/O ambiguity
first unstable calibration is BLOCKED
do not rerun the same unstable evidence unchanged
```

This is a test-evidence calibration issue, not an ATX application defect.


## 51. Calibration fields must not include the behavior under test

Statement Interpretation V1.2.2 reproduced four rows, the expected dates, references, source file, amounts and balances. The first description still omitted the undated continuation text. The package recorded `BLOCKED` because it incorrectly included the wrapped description in source-identity calibration.

Source audit confirmed a real implementation gap: `BankStatementColumnMappingEngine` mapped every visual row independently and did not apply `JoinWrappedDescriptionLines`, `MergeWrappedRows` or `AllowContinuationRows` when building manual-column candidates.

Permanent contract:

```text
calibration: row count, dates, references and source attribution
functional behavior: description reconstruction, amounts, balances and ordering
never hide a source-confirmed functional mismatch inside sample calibration
manual visual mapping merges only undated, amountless continuation rows
merging requires all wrapped/continuation controls enabled
disabled merging preserves separate mapped rows
```

The historical package result remains recorded as `BLOCKED`; the audited implementation finding is an ATX code defect.


## 52. Cached Remap must not retain pre-mapping balance diagnostics

Statement Interpretation V1.3 produced all four expected rows after the wrapped-row hotfix. Dates, descriptions, references, amounts, balances, ordering and source attribution matched the certified contract. The run still displayed a `Running balance variance` warning calculated against the provider's pre-mapping candidates.

This is an ATX application defect because cached Remap changes the authoritative transaction candidates. Provider balance diagnostics from before interpretation are stale after manual columns, wrapped-row reconstruction, sign handling or ordering changes.

Permanent contract:

```text
before cached Remap: provider balance diagnostics may describe old candidates
during cached Remap: remove stale balance variance/check diagnostics
then map current rows and run BankStatementValidationEngine
passing current chain: no balance variance warning
failing current chain: fresh VALIDATION-RUNNINGBALANCE warning only
never preserve a pre-remap balance warning as evidence against post-remap rows
```

The exact disposable Draft was deleted and no import side effects occurred.



## 47. Low-confidence recovery must prove bounded execution and source-scored selection

A recovery test must configure validation and retry behavior through the visible Validation Rules and OCR Recovery Strategy editors. Direct writes to `ValidationRulesJson` or `RetryStrategyJson` are prohibited.

Required sequence:

```text
configure a source-confirmed low-confidence rule
→ enable bounded recovery
→ configure materially different visible retry attempts
→ run one initial extraction
→ read the complete Recovery result history
→ prove the maximum-attempt boundary
→ prove exactly one accepted result
→ independently calculate the source-confirmed score
→ verify the accepted attempt is the highest-scoring result
→ verify the final low-confidence outcome remains Requires review when no attempt meets the threshold
```

The source score is:

```text
success                     +100000
blocking validation         -10000 each
requires-review validation  -1000 each
warning validation          -100 each
transaction candidate       +10 each
provider confidence         +confidence percent
```

For a calibrated package that retains only `ProviderSuccess`, `MinimumOcrConfidence` and `MinimumRowCount`, the test may derive each attempt's validation penalties from success, candidate count and the configured thresholds.

Mandatory boundaries:

```text
- MaximumAttempts includes the primary extraction.
- Duplicate recovery fingerprints must be rejected before execution.
- A configured attempt beyond the maximum must not run.
- Exactly one history item may be Accepted.
- A tie does not replace the earlier accepted result because IsBetterResult uses strict greater-than.
- Runtime history and accepted-attempt evidence must come from the rendered Recovery result tab.
- A missing/ambiguous recovery editor contract is TEST_INVALID.
- A source-certified scoring or attempt-boundary contradiction is FAIL.
```


## 53. Recovery attempt metrics and final mapped rows are separate authorities

Low Confidence Recovery V1 rendered three recovery attempts, exactly one Accepted result, a final `RequiresReview` outcome and a Test Results summary showing four mapped transactions. The package nevertheless classified the run as `BLOCKED` because it required the Accepted recovery-history item itself to contain at least four candidates.

That requirement was invalid. Recovery-history `CandidateCount` and `ConfidencePercent` are provider-stage metrics captured by `CreateAttemptHistory` and used by `BankingContentExtractionService.Score`. The final Test Results transaction count is the post-selection, post-layout-mapping result shown by the summary card.

Permanent contract:

```text
recovery-history candidate count/confidence
  → authoritative for source-score reconstruction

Test Results Transactions detected summary
  → authoritative for final calibrated mapped-row count

never require accepted history CandidateCount == final mapped rows
never replace source scoring metrics with the final mapped-row count
verify both authorities separately
```

Cleanup evidence must also survive a functional assertion abort. Suite teardown must record whether the exact Draft was actually deleted before finalizing the recovery recorder. A successful teardown deletion may not be reported as `exactDraftDeleted=false`.

The historical V1 result remains `TEST_INVALID`; it does not prove an ATX recovery defect.

## 56. Final-import idempotency must use one session, one operation and a runtime-unique filename

The certified final-import retry test must not create two sessions or rely on repeated file names. It submits the same Step-5 form twice for the same exact session and operation, then resolves the result using a runtime-unique synthetic filename.

Permanent contract:

```text
one exact ImportSession
one exact OperationId
one owner-scoped source artifact
one exact published profile version
two bounded same-form POSTs
one BankImportBatch
transactionCount equals accepted Extraction Review row count
exact batch is reversed after assertions
```

Responsive history rows must be scoped to the desktop table before uniqueness assertions. Batch and transaction counts come from `OnGetBatchDetailAsync`, not from summary prose. Undo leaves the batch/session/audit trail but removes the disposable unlocked transactions.



## 57. Cross-page route GUIDs are not form-option selection authority

A final-import package replaced the previously proven Guided Import selection with a cross-page correlation:

```text
Banking Profiles card Configure href `id=<GUID>`
→ assume the same GUID must be the `#guidedProfile` option value
→ wait or fail before selecting the visible profile
```

That change was unnecessary and regressed a working intake action. A route parameter on another page may identify a root, snapshot, version, catalogue item or management target. It is not automatically the value submitted by a different form control.

### Permanent rule

For a select control:

```text
1. Use the control's source-confirmed selector.
2. Match the exact visible option text and scope within that control.
3. Read the matched option's own value.
4. Select by that value.
5. Verify the selected text, scope and submitted value.
```

A catalogue page may prove that a named profile exists and is Published, but it must not replace the target form control as the value authority unless current source explicitly proves the identifiers are the same contract.

Do not replace a previously runtime-proven control interaction with a broader cross-page inference without a source requirement and a focused runtime preflight.


## 58. Guided Import tests must not detour through the profile catalogue

Final Import V1.1/V1.2 added a new read-only catalogue precheck before the already-proven Guided Import selection. The precheck waited on the global selector:

```robot
Wait For Elements State    css=.bp-profile-card    visible
```

The catalogue intentionally contained two profile cards. Browser strict mode therefore rejected the wait before the package reached `#guidedProfile`. The prior intake packages did not fail because they navigated directly to Guided Import and treated the target select option as the prerequisite and submitted-value authority.

### Permanent rule

For a focused Guided Import package:

```text
navigate directly to /Banking/Imports?activeTab=guided&currentStep=1
validate #guidedBankAccount, #guidedProfile and #btnStep1Next
select the exact account
resolve the exact option inside #guidedProfile by visible text and scope
read and submit that option's own value
```

Do not navigate to `/Banking/Profiles` merely to prove a profile already represented by the Guided Import select. When catalogue evidence is independently required, every wait and assertion must use the exact scoped card selector; a global multi-match locator may never be passed to a strict single-element wait.

Any new prerequisite detour that replaces a previously passing direct control interaction without adding acceptance value is `TEST_INVALID`.


## 47. Browser `Evaluate JavaScript` must not receive raw root-relative URL arguments

A final-import idempotency package successfully completed Guided Import, created one exact batch and then failed while reading BatchDetail because it passed a root-relative URL as an unquoted `Evaluate JavaScript` argument.

The runtime value began with:

```text
/Banking/Imports?batchId=<GUID>&handler=BatchDetail
```

Robot Framework Browser treated the slash-prefixed value as JavaScript source. JavaScript parsed it as a regular-expression literal and raised:

```text
SyntaxError: Invalid regular expression flags
```

The application import and idempotency path had already completed. This was a package transport defect.

### Required pattern

Execute against the exact source-confirmed element and read its dataset inside the browser callback:

```robot
${detail}=    Evaluate JavaScript
...    ${exact_batch_detail_trigger}
...    async (button) => {
...        const response = await fetch(button.dataset.batchDetailUrl, { credentials: 'same-origin' });
...        return await response.json();
...    }
```

After navigation or mutation, resolve the exact element again rather than retaining a raw relative URL as a Robot scalar.

### Durable rule

Never pass a raw absolute-path, root-relative or document-relative URL as an unquoted `Evaluate JavaScript` argument. Use the exact element property inside the callback or explicitly JSON-serialize the string first.

Raw slash-prefixed URL arguments are `TEST_INVALID`, not application failures.

---


## 59. Python Robot libraries must expose the module-stem class

A Payment Evidence ownership package passed its custom keyword allowlist but failed Robot dry-run because the Python resource file was:

```text
resources/AtxCertifiedPaymentEvidenceSecurityLibrary.py
```

while its only Robot library class was:

```python
class AtxCertifiedPaymentEvidenceProfileLibrary:
```

Robot loaded the module but did not expose the class methods as library keywords, so setup and teardown keywords such as `Verify Package Certificate`, `Generate Disposable Profile Name`, `Infrastructure Error` and recorder methods were unresolved.

### Permanent executable rule

For every class-based Python Robot library:

```text
1. Parse the final extracted `.py` file with Python AST.
2. Derive the expected class name from the module filename stem.
3. Require exactly one public Robot library class with that exact name.
4. Require `ROBOT_LIBRARY_SCOPE`.
5. Convert required method names to Robot keyword names and prove every referenced keyword exists.
6. Reject a mismatched class/module name before package delivery.
7. Repeat the same check in the installer and installed-package certifier.
8. Run Robot dry-run on the final installed copy before Chromium.
```

A Python file existing, compiling or appearing in an external-keyword allowlist is not proof that Robot can expose its class methods.

A module/class mismatch is `ERROR` during runtime preflight and `TEST_INVALID` during package certification. It is never an ATX application failure.


## 62. Protected test state and the production baseline may belong to different workspaces

The preserved Phase 25J production baseline and the protected Phase 25J TEST profiles do not share one tenant workspace.

```text
Protected TEST profiles / Payment Evidence cleanup:
  CIPC Example Holdings

Preserved ABSA 77-row production baseline:
  Basic Beside CIPC
```

A tenant-scoped BatchDetail lookup must switch to the exact workspace recorded by the contract immediately before the request. A missing batch response caused by querying the wrong workspace is `TEST_INVALID`, not `BLOCKED` and not an application failure.

Future final-closeout packages must mechanically verify separate `ownerWorkspace` and `productionWorkspace` values in the manifest and Source of Truth.

## 63. ATX Robot tests are website-only and must never connect to the database

ATX Robot Framework Browser / Playwright packages may use only the deployed website and the evidence visible through that website.

Allowed runtime evidence:

```text
browser navigation and visible controls
HTML and DOM properties rendered by ATX
website responses reached through browser actions
browser-visible download files generated by ATX
network responses made by the page to the same ATX origin
screenshots, videos, logs and Robot reports
runtime test files selected through a website file input
```

Prohibited runtime integration:

```text
direct SQL or database connections
SqlConnection, NpgsqlConnection or any database client
reading SQLDetails, connection strings or database credentials
reading appsettings.json for database access
executing SQL scripts, SELECT statements or stored procedures
querying tables to supplement a browser assertion
calling a database through PowerShell, Python, C# or another helper
using local project source or configuration as runtime functional evidence
```

A package containing any prohibited database path is `TEST_INVALID` and must stop during package certification, before credentials or Chromium.

The Phase 25H-D2-A V1 and V1.1 packages are withdrawn because they attempted direct SQL verification. The V1 result remains historically recorded as `ERROR`, but neither V1 nor V1.1 is an approved ATX Robot package.

### D2-A browser-observable boundary

The website can prove that the deployed Payment Evidence workflow still behaves correctly after D2-A:

```text
create one exact disposable Payment Evidence profile
preview one runtime-unique synthetic CSV
show the expected preview filename, rows, classifications and duplicate warning
submit the exact Execute Import form twice through the page
show one active batch for the exact filename and one exact batch GUID
show the expected InReview batch, row totals and classifications
remove the exact disposable batch
prove the exact batch is no longer accessible through the website
remove the exact disposable profile
prove the exact profile is absent
capture screenshots and browser evidence throughout
```

The website does not currently expose `BankingUsageEvents`, the artifact byte count, the storage event key or an internal artifact ID. Therefore a Robot package must not claim runtime proof of those internal accounting facts.

D2-A internal accounting remains:

```text
source-confirmed by the approved D2-A implementation
covered by focused code-level unit/relational/source-contract tests
not directly browser-observable until ATX deliberately exposes a safe website view
```

Robot reports must label these separately:

```text
Browser runtime proof: Payment Evidence preview/import/retry/cleanup behavior.
Source/code proof: artifact storage writes one owner-scoped usage event.
Not browser-proven: exact BankingUsageEvents row, quantity, event key and persistence.
```

### Mandatory no-database package certification

Every package certifier must scan executable package files and reject database integration markers including:

```text
System.Data.SqlClient
Microsoft.Data.SqlClient
SqlConnection
Npgsql
SQLDetails
ConnectionString
appsettings.json database lookup
.psql or .sql helper execution
```

Documentation may mention that database access is prohibited, but no executable package file may contain a database connector or query path.

## Canonical final checklist for future agents

Before giving the user a Robot test package, confirm:

```text
[ ] Newest project ZIP inspected.
[ ] Exact Razor/JavaScript selectors confirmed.
[ ] Required selectors recorded in a source-mapped manifest where the package has many guide targets.
[ ] Complete runtime selector preflight runs before guide screenshot capture.
[ ] Functional runtime evidence comes only from the deployed website.
[ ] No SQL/database client, appsettings database lookup or direct table query exists anywhere in the executable package.
[ ] Internal facts not exposed by the website are reported as source/code proof, not Robot runtime proof.
[ ] Responsive duplicate controls handled.
[ ] Input state read through properties.
[ ] Hidden elements and ASP.NET hidden fallback inputs excluded.
[ ] Major progress navigation distinguished from detailed section navigation.
[ ] Duplicate Robot keywords/sections scan passed.
[ ] Embedded JavaScript scanned for Robot `${...}` collisions.
[ ] Scenario sample matches the scope and secret requirements.
[ ] Wrapped-row samples use complete dated transaction rows and only undated continuation detail lines.
[ ] Same-date ordering rows are visually separated and use OCR-stable references.
[ ] Calibration fields exclude the functional value currently under test.
[ ] Manual continuation merging is source-mapped to BankStatementColumnMappingEngine.
[ ] Cached Remap removes stale provider balance diagnostics before current validation.
[ ] Canonical BAT/PS1 runner reused.
[ ] Executable BAT/PS1 files use safe encoding and ASCII-only runner text.
[ ] No `__pycache__`, `.pyc` or `.pyo` artifact exists in package root, payload, installed tree or checksum manifest.
[ ] Python source validation ran outside the package tree.
[ ] Python child processes use `PYTHONDONTWRITEBYTECODE=1` and `-B`.
[ ] Installed Run-Test.ps1 passes the actual Windows PowerShell parser preflight.
[ ] Robot launched with safe stdout/stderr process handling.
[ ] Synthetic stderr-WARN/exit-0 runner probe passed.
[ ] Actual native exit code captured.
[ ] PASS/FAIL/ERROR derived from complete output.xml and Robot statistics.
[ ] Runtime secrets are not embedded or logged.
[ ] ATX login credentials and the PDF evidence password use separate variables and prompts.
[ ] Any password prompt names the protected evidence and never repeats the secret value.
[ ] Password preserve/replace/clear assertions are scoped to one disposable exact-ID Draft.
[ ] Runtime password behavior is reported separately from source/database encryption proof.
[ ] Generated text, JSON, HTML, screenshots and ZIP member names are checked for secret disclosure.
[ ] Login uses `%{ATX_TEST_USERNAME}` with Fill Text and `%ATX_TEST_PASSWORD` with Fill Secret.
[ ] Disposable data has exact-ID cleanup.
[ ] Already-proven scenarios are not repeated.
[ ] Summary wording and package-specific recorder filenames match the suite.
[ ] Result ZIP is built atomically and validated twice.
[ ] Final ZIP is placed at a short Explorer-safe path.
[ ] Only a validated non-zero ZIP is copied to the clipboard.
[ ] Static checks are described as static, not runtime proof.
[ ] Guide callouts use approved light blue and remain fully inside the viewport.
[ ] Guide-capture packages keep browser-test status separate from catalog/media status.
[ ] Guide catalogs organize images into named section folders and surface index.html after PASS.
[ ] Optional GIF/MP4/WebM failures do not overwrite a valid browser-capture result.
[ ] User receives only the necessary package download unless more is requested.
[ ] Final-import retry packages use one exact session/operation and a runtime-unique filename.
[ ] Exact batch transaction count is read from BatchDetail and the batch is reversed after assertions.
```

---

## Required durable runner rule

All ATX Robot Framework Browser packages must use the canonical self-installing BAT/PS1 runner.

```text
Native stderr is diagnostic output, not automatic failure.
Never merge Robot stderr into a terminating PowerShell pipeline under ErrorActionPreference Stop.
Classification must use the completed Robot result and actual native process exit code.
```

Future agents must preserve this runner contract unless a separately approved, fully tested replacement is introduced.

---


## 48. Successful imports may be Partial when warnings exist

`BankImportBatch.Status` is an execution outcome, not a synonym for whether transactions were created.

Source-confirmed status derivation:

```text
errorCount > 0 and importedRows = 0
  -> Failed

warningCount > 0 or errorCount > 0
  -> Partial

warningCount = 0 and errorCount = 0
  -> Completed
```

A final-import test must compare `status`, `warningCount`, `errorCount` and `importedRows` together. A batch that imported every accepted row but retained a warning is correctly `Partial`; expecting `Completed` is `TEST_INVALID`.

`OnPostUndoAsync` uses parameterless `RedirectToPage()`, which returns to the default Guided tab. After clicking Undo:

```text
wait for the authenticated redirect
-> explicitly navigate to /Banking/Imports?activeTab=history
-> re-resolve the exact batch trigger
-> read BatchDetail
-> prove status Reversed and transactionCount 0
```

A successful click or no-error redirect is not cleanup proof. Do not wait for visible `#historyListView` immediately after Undo, and do not mark a batch reversed until the exact BatchDetail response proves it.


# Part II — ATX Robot Source–Action Matrix

# ATX Robot Source–Action Matrix

**Generated:** 2026-07-29  
**Authoritative code pack:** `Project Context File(13).zip`  
**Code-pack SHA-256:** `b39e7ba45d6c1ec1abb99cf8f0d23a86095e32beae0a76593453166041fc38ff`  
**Machine-readable companion:** `ATX_Robot_Source_Action_Contracts_20260729.json`

## Purpose

This file is the mandatory reference for creating or correcting ATX Banking Robot Framework Browser packages. It maps visible controls to the exact current Razor source, generated selector, handler, PageModel method, transport behavior, prerequisites, postconditions, duplicate/hidden-control hazards and cleanup rules.

**A missing control, wrong button name, wrong handler assumption, unresolved keyword, stale package filename, or incorrect expected navigation is never an application failure.** It is `TEST_INVALID` and must stop before the modifying test begins.

## Mandatory use

1. Verify the code-pack and source-file hashes below before generating a test.
2. Select only actions already mapped here, or add and validate a new action contract first.
3. Verify both the selector and the server/client action semantics. A selector existing is not enough.
4. Run a read-only runtime preflight for every required control before the first mutation.
5. Inspect the immediate POST/AJAX result before waiting for a later page state.
6. Permit `FAIL` only after package certification, prerequisites, handler identity, response contract and cleanup contract pass.
7. Regenerate this matrix when any listed source hash changes.

## Result classification

| Status | Meaning |
|---|---|
| **PASS** | Certified acceptance assertions completed successfully. |
| **FAIL** | Certified package and prerequisites passed; ATX violated the source-confirmed acceptance contract. |
| **TEST_INVALID** | Selector, handler, action expectation, test data, runtime-variable wiring, cleanup or package contract is wrong. |
| **BLOCKED** | A required safe prerequisite is absent or intentionally unavailable. |
| **ERROR** | Runner, parser, Robot, Browser, authentication, environment, dependency or reporting failure. |

## Source inventory

| Key | Project-relative path | SHA-256 | Lines |
|---|---|---|---:|
| `profiles_index_razor` | `AtxSolutions/Pages/Banking/Profiles/Index.cshtml` | `22a4192c31e281e20504172cff4f57238bb8ef7d204b30cfc41062406b9e52b2` | 523 |
| `profiles_index_model` | `AtxSolutions/Pages/Banking/Profiles/Index.cshtml.cs` | `3c261f3f7d1e3aafb48a9dac54c2b10263810cfc836f510b7b1dec7e1acce7ea` | 328 |
| `statement_razor` | `AtxSolutions/Pages/Banking/Profiles/Statement.cshtml` | `2eedf0f8401a20a16b8490e648aee49c5e51c8e71b30d7c583392ee74183e56f` | 4981 |
| `statement_model` | `AtxSolutions/Pages/Banking/Profiles/Statement.cshtml.cs` | `b18d54851b4c352f1bbb4103769c73b769914919b1231b17703100511ed542ed` | 2729 |
| `imports_razor` | `AtxSolutions/Pages/Banking/Imports.cshtml` | `85d9435c7ffa43c916328ebb766533a07fd9882f7898177aa7c1a6419b805a44` | 3124 |
| `imports_model` | `AtxSolutions/Pages/Banking/Imports.cshtml.cs` | `831973308fbce32c76b9f3b070926d886750c8817a4dfdc505dd99b5690e7777` | 4619 |
| `review_razor` | `AtxSolutions/Pages/Banking/Imports/ExtractionReview.cshtml` | `725c594585ad274e7829df15dcf073095e7d65d6b8ba05a8416679f8f46895b7` | 1257 |
| `review_model` | `AtxSolutions/Pages/Banking/Imports/ExtractionReview.cshtml.cs` | `8bad735700c4aaf21f0c4257b149646393e1dba63eeb6da89744b858c6e21757` | 1054 |

## Critical handler distinctions

| User action | Handler | Actual contract | Never assume |
|---|---|---|---|
| Save Draft & Continue | `Save` / `OnPostSaveAsync` | Runs full `ValidateProfileForm`; AJAX returns workspace on valid save. | It is not the permissive incomplete-Draft path. |
| Save Draft & Exit | `SaveAndExit` / `OnPostSaveAndExitAsync` | Clears model-binding noise, permits incomplete Draft, redirects to catalogue. | It is not AJAX and does not remain in workspace. |
| Save Draft & Publish | `SaveDraftAndPublish` | Requires current exact cached non-blocking test; never reruns extraction implicitly. | A missing/stale cache is not an app failure. |
| Cancel | `Cancel` | Non-destructive; removes temporary test token and returns to catalogue. | It does not delete a persisted Draft. |
| Load JSON | `ImportJson` | Rebuilds server Form and returns Page for review; does not save. | Posted ModelState may retain visible values; do not use as hidden setup for unrelated tests. |
| Next: Preview | `UploadSessionFile` | Uploads/inspects file; review-required PdfText routes to Extraction Review. | It is not always a direct Step 3 navigation. |
| Accept & Continue | `ExtractionReview.Accept` | Saves accepted rows and redirects to Guided Step 3. | Focused no-import tests must not click it. |

## Selector and DOM hazards that must be checked every time

- `Form.Id` and `Form.ProfileName` also appear in separate header forms. Use `#Form_Id` and `#Form_ProfileName`, never broad `name=` selectors.
- ASP.NET checkbox Tag Helpers render hidden fallback inputs. Use exact checkbox IDs and `type=checkbox` where needed.
- Statement save/publish/cancel actions are duplicated across header, desktop section and mobile sticky controls. Scope to the active container and use `:visible`.
- Statement progress steps, detailed section navigation and mobile navigation are separate control systems.
- `Form.OcrRenderDpi`, `Form.OcrLanguage`, `Form.OcrProviderKey`, `Form.CurrencyCode` and `Form.ImageType` are `<select>` controls. Use Select Options, not Fill Text.
- Guided account option text contains the account number after the bank name.
- Guided system-profile option text appends `(System)`.
- An active Guided Import session overrides a requested `currentStep` query value.
- Guided Import can render both a visible direct abandon form and a hidden modal abandon form for the same session.
- Profile cards contain both a scope badge and a lifecycle badge. Never read lifecycle with `nth=1`.
- Extraction Review renders one of two `#pdfReviewAcceptButton` branches at runtime; the duplicate ID exists only in mutually exclusive Razor branches.

## Profiles catalogue action matrix

| ID | Purpose | Exact selector / resolution | Handler → method | Transport | Runtime requirement / hazard |
|---|---|---|---|---|---|
| `profiles.open-new-statement` | Open a new tenant Statement Profile workspace. | `#newProfileDropdown`<br>Click dropdown, then click `a[href^="/Banking/Profiles/Statement"]:visible`.<br>Source: `AtxSolutions/Pages/Banking/Profiles/Index.cshtml:98` | `GET /Banking/Profiles/Statement` → `StatementModel.OnGetAsync` | Full navigation | User tab loaded; manager has profile-management permission. **Hazard:** Statement link is hidden inside a Bootstrap dropdown until opened. |
| `profiles.find-exact-user-card` | Locate exactly one tenant profile by exact displayed name. | `xpath=//div[contains(@class,'bp-profile-card')][.//h2[normalize-space()='<EXACT_PROFILE_NAME>']]`<br>Get count before any action.<br>Source: `AtxSolutions/Pages/Banking/Profiles/Index.cshtml:226` | `None` → `IndexModel.OnGetAsync` | Read-only | User tab selected. **Hazard:** Never use `:has-text()` alone for destructive actions because it permits substring matches. |
| `profiles.read-card-lifecycle` | Read the exact profile lifecycle badge without positional guessing. | `Structural JS on exact card: direct top row `:scope > .d-flex > span.badge`.`<br>Read direct-child lifecycle badge text.<br>Source: `AtxSolutions/Pages/Banking/Profiles/Index.cshtml:233` | `None` → `IndexModel.OnGetAsync` | Read-only | Exact card already resolved. **Hazard:** The card also contains a `User` scope badge. Never use `span.badge >> nth=1`. |
| `profiles.configure-exact-statement` | Open the exact Statement Profile by ID. | `<exact card> >> css=a[href*="/Banking/Profiles/Statement"][href*="id="]`<br>Read and verify the href/GUID, then click the exact scoped anchor. If direct navigation is required, resolve it with `new URL(href, document.baseURI).href` and verify the ATX origin first.<br>Source: `AtxSolutions/Pages/Banking/Profiles/Index.cshtml:242` | `GET /Banking/Profiles/Statement?id=<GUID>` → `StatementModel.OnGetAsync` | Full navigation | Exact card is a Statement builder profile. **Hazard:** The anchor href is normally root-relative. Never pass a raw href to Browser `Go To`; click the exact scoped anchor or resolve and origin-check the absolute URL first. |
| `profiles.publish-tested-version` | Publish a profile already in Tested lifecycle. | `<exact card> >> css=form[action*="handler=Publish"]:has(input[name="profileId"][value="<GUID>"])`<br>Open exact card Actions dropdown; submit exact form.<br>Source: `AtxSolutions/Pages/Banking/Profiles/Index.cshtml:266` | `Publish` → `IndexModel.OnPostPublishAsync(Guid profileId, bool systemProfile = false)` | Full POST then catalogue redirect | Exact lifecycle is Tested; profile ID and tenant ownership confirmed. **Hazard:** Action is absent outside Tested lifecycle. Missing action is BLOCKED, not application FAIL. |
| `profiles.delete-never-published-draft` | Delete an exact disposable never-published, unreferenced Draft. | `<exact card> >> css=form[action*="handler=Delete"]:has(input[name="profileId"][value="<GUID>"])`<br>Open exact card Actions dropdown; remove `onsubmit` only after exact-ID and Draft checks; submit.<br>Source: `AtxSolutions/Pages/Banking/Profiles/Index.cshtml:278` | `Delete` → `IndexModel.OnPostDeleteAsync(Guid profileId)` | Full POST then catalogue redirect | Exact name, exact GUID, non-Published state, `CanRemove` action visible. **Hazard:** Never delete by name alone. Published/protected profiles intentionally have no delete form. |

## Statement Profile action matrix

| ID | Purpose | Exact selector / resolution | Handler → method | Transport | Runtime requirement / hazard |
|---|---|---|---|---|---|
| `statement.switch-advanced` | Switch the workspace into Advanced mode. | `button[data-profile-mode-button="advanced"]:visible`<br>Click, then read `.statement-profile-page[data-profile-mode]`.<br>Source: `AtxSolutions/Pages/Banking/Profiles/Statement.cshtml:1889` | `Client-side only` | No navigation; localStorage + DOM state | `.statement-profile-page` visible. **Hazard:** Do not use obsolete `data-workspace-mode` selectors. |
| `statement.profile-id` | Read the exact persisted profile ID. | `#Form_Id`<br>Get Property `value`.<br>Source: `AtxSolutions/Pages/Banking/Profiles/Statement.cshtml:2006` | `None` → `Form.Id binding` | Read-only | Workspace loaded. **Hazard:** The header Cancel/Reset forms also contain hidden `name="Form.Id"`. Never use `input[name="Form.Id"]`. |
| `statement.profile-name` | Set/read the visible profile name. | `#Form_ProfileName`<br>Fill Text; verify with Get Property `value`.<br>Source: `AtxSolutions/Pages/Banking/Profiles/Statement.cshtml:2230` | `Form binding` → `PdfProfileFormInput.ProfileName` | Client state until submit | `#profile-details` active. **Hazard:** Reset ABSA has a separate hidden `name="Form.ProfileName"`. Never use a broad name selector. |
| `statement.bank-name` | Set/read source or issuer name. | `#Form_BankName`<br>Fill Text; Get Property `value`.<br>Source: `AtxSolutions/Pages/Banking/Profiles/Statement.cshtml:2236` | `Form binding` → `PdfProfileFormInput.BankName` | Client state until submit | Advanced mode; Profile Info active. **Hazard:** Advanced-only control; hidden in Basic mode. |
| `statement.statement-type` | Set/read document type. | `#Form_StatementType`<br>Fill Text; Get Property `value`.<br>Source: `AtxSolutions/Pages/Banking/Profiles/Statement.cshtml:2240` | `Form binding` → `PdfProfileFormInput.StatementType` | Client state until submit | Advanced mode. **Hazard:** Advanced-only control. |
| `statement.currency` | Select profile currency. | `#Form_CurrencyCode`<br>Select Options By `value` (for example `ZAR`); never Fill Text.<br>Source: `AtxSolutions/Pages/Banking/Profiles/Statement.cshtml:2244` | `Form binding` → `PdfProfileFormInput.CurrencyCode` | Client state until submit | Profile Info active. **Hazard:** This is a `<select>`, not a text input. |
| `statement.choose-image-source` | Select screenshot/image evidence. | `button.statement-source-card[data-source-type="Image"]:visible`<br>Click; verify `#SampleSourceType` and `#FormImageType` properties.<br>Source: `AtxSolutions/Pages/Banking/Profiles/Statement.cshtml:2316` | `Client-side `selectSourceType(type, applyRecommendation)`` → `ResolveSampleSourceType / form binding` | No navigation | Source & Sample section active. **Hazard:** Clicking the card triggers JS side effects; setting only the hidden field does not exercise the UI contract. |
| `statement.sample-file` | Stage representative sample evidence. | `#SampleEvidence`<br>Upload File By Selector; verify `files.length` and filename.<br>Source: `AtxSolutions/Pages/Banking/Profiles/Statement.cshtml:2345` | `Multipart form binding` → `SampleEvidence binding` | Client-side until Prepare/Test/Rerun submit | Selected source card permits file extension. **Hazard:** The selected File object is lost after an AJAX page replacement unless the JS restore contract succeeds. |
| `statement.force-ocr` | Select OCR-only extraction mode. | `#OcrModeForce`<br>Click associated mode card or Check; verify `checked=true`.<br>Source: `AtxSolutions/Pages/Banking/Profiles/Statement.cshtml:2484` | `Client-side radio change` → `PdfProfileFormInput.OcrMode` | Client state until submit | Advanced mode for direct section navigation. **Hazard:** The radio is visually hidden; clicking the label card is the user-equivalent action. |
| `statement.image-type` | Set expected image type. | `#FormImageType`<br>Select Options By `value=Screenshot`.<br>Source: `AtxSolutions/Pages/Banking/Profiles/Statement.cshtml:2518` | `Form binding` → `PdfProfileFormInput.ImageType` | Client state until submit | Advanced mode; Image Source active. **Hazard:** This is a `<select>`. |
| `statement.ocr-dpi` | Set OCR/render DPI. | `#Form_OcrRenderDpi`<br>Select Options By `value=300`.<br>Source: `AtxSolutions/Pages/Banking/Profiles/Statement.cshtml:2529` | `Form binding` → `PdfProfileFormInput.OcrRenderDpi` | Client state until submit | Image Source active. **Hazard:** This is a `<select>`. `Fill Text` is invalid. |
| `statement.ocr-language` | Select installed OCR language. | `#Form_OcrLanguage`<br>Read available options; select exact installed value, preferably `eng` only when present.<br>Source: `AtxSolutions/Pages/Banking/Profiles/Statement.cshtml:2556` | `Form binding` → `DiscoverInstalledOcrLanguages / PdfProfileFormInput.OcrLanguage` | Client state until submit | At least one installed language option. **Hazard:** Do not assume `eng` exists without runtime option preflight. |
| `statement.ocr-provider` | Select an installed OCR provider. | `#Form_OcrProviderKey`<br>Verify enabled; read options; select exact preferred provider only if present.<br>Source: `AtxSolutions/Pages/Banking/Profiles/Statement.cshtml:2713` | `Form binding` → `LoadPermissionsAsync builds `OcrProviders`` | Client state until submit | Provider control enabled and at least one non-empty option. **Hazard:** No provider is a BLOCKED environment prerequisite, not application FAIL. |
| `statement.prepare-image` | Prepare or refresh the pre-OCR preview without running extraction. | `#image-preparation button[formaction*="handler=PrepareImage"]:visible`<br>Submit AJAX; validate the replacement page and controller readiness; verify the scoped `SampleCacheToken`; open Regions & Anchors; wait for `#ocrPreparedImage` to be visible with `complete=true`, `naturalWidth>0` and `naturalHeight>0`.<br>Source: `AtxSolutions/Pages/Banking/Profiles/Statement.cshtml:2685` | `PrepareImage` → `StatementModel.OnPostPrepareImageAsync` | AJAX POST with `X-ATX-Profile-Action:true`; page fragment replacement followed by asynchronous image loading | Image sample selected or cached; form values valid for preparation. **Hazard:** Fragment replacement can complete before the prepared image resource finishes loading. An immediate `:visible` count is invalid. There is also another PrepareImage button in OCR Input Preview; scope to the active section. |
| `statement.clear-sample` | Detach the temporary profile sample. | `#image-preparation button[formaction*="handler=ClearSample"]:visible`<br>Submit AJAX; verify token empty, file input empty, clear action absent/disabled and workspace no longer shows sample.<br>Source: `AtxSolutions/Pages/Banking/Profiles/Statement.cshtml:2683` | `ClearSample` → `StatementModel.OnPostClearSampleAsync` | AJAX POST and fragment replacement | Temporary sample exists. **Hazard:** Button absence when no sample is correct. |
| `statement.run-test` | Run the representative extraction test. | `#test-results button[formaction*="handler=Test"]:visible`<br>Submit AJAX; parse response before waiting for result cards.<br>Source: `AtxSolutions/Pages/Banking/Profiles/Statement.cshtml:3429` | `Test` → `StatementModel.OnPostTestAsync -> RunTestExtractionAsync` | AJAX POST and fragment replacement | CanSave; required profile fields; sample selected/cached; provider available when OCR enabled. **Hazard:** When cached extraction exists, the visible primary action may be RerunExtraction instead. |
| `statement.rerun-extraction` | Rerun provider extraction after extraction-affecting changes. | `#test-results button[formaction*="handler=RerunExtraction"]:visible`<br>Count visible matches in active branch; click the intended primary or menu action.<br>Source: `AtxSolutions/Pages/Banking/Profiles/Statement.cshtml:3423` | `RerunExtraction` → `StatementModel.OnPostRerunExtractionAsync` | AJAX POST and fragment replacement | Cached sample exists; CanSave. **Hazard:** The handler appears in multiple Razor branches and dropdowns. Never assume global uniqueness. |
| `statement.remap-validate` | Remap cached geometry without rerunning OCR. | `#test-results button[formaction*="handler=Remap"]:visible`<br>Verify enabled and `testLab.CanRemap`; submit AJAX.<br>Source: `AtxSolutions/Pages/Banking/Profiles/Statement.cshtml:3449` | `Remap` → `StatementModel.OnPostRemapAsync` | AJAX POST and fragment replacement | Cached extraction current; interpretation/mapping changed; remap allowed. **Hazard:** Disabled Remap is a prerequisite state, not application failure. |
| `statement.save-draft-continue` | Save a fully valid Draft and remain in the workspace. | `#save-profile button[data-save-draft]:visible`<br>Open `#save-profile .statement-save-more-actions` dropdown; submit AJAX; inspect validation summary and returned `#Form_Id`.<br>Source: `AtxSolutions/Pages/Banking/Profiles/Statement.cshtml:3839` | `Save` → `StatementModel.OnPostSaveAsync` | AJAX POST when `data-profile-ajax`; returns Page for workspace requests | `ValidateProfileForm()` must pass. **Hazard:** This is NOT the permissive incomplete-Draft action. Never expect SaveAndExit semantics. |
| `statement.save-draft-exit` | Permissively save an incomplete Draft and return to catalogue. | `#save-profile button[data-visible-save-and-exit]:visible`<br>Activate Save section; submit scoped visible action.<br>Source: `AtxSolutions/Pages/Banking/Profiles/Statement.cshtml:1895` | `SaveAndExit` → `StatementModel.OnPostSaveAndExitAsync` | Full POST and redirect to `/Banking/Profiles?tab=user|system` | CanSave. Full profile validation is intentionally not required. **Hazard:** Multiple responsive/header copies exist globally. Scope to active section. This is the correct incomplete-Draft action. |
| `statement.save-draft-publish` | Save and publish the exact reviewed cached test result. | `#test-results button[formaction*="handler=SaveDraftAndPublish"]:visible`<br>Verify exact cached test current/non-blocking; submit AJAX action; follow redirect/catalogue outcome.<br>Source: `AtxSolutions/Pages/Banking/Profiles/Statement.cshtml:3798` | `SaveDraftAndPublish` → `StatementModel.OnPostSaveDraftAndPublishAsync` | AJAX fetch can receive redirect; server publishes exact tested version and redirects | ValidateProfileForm passes; current cached test exists; extraction and interpretation fingerprints current; no blocking/rejected outcome. **Hazard:** Handler never reruns extraction. Publishing without a current cache must remain blocked. |
| `statement.cancel` | Leave the workspace without deleting a persisted profile. | `.statement-header-meta form[action*="handler=Cancel"] [data-cancel-profile]:visible`<br>Handle unsaved-change confirmation; submit.<br>Source: `AtxSolutions/Pages/Banking/Profiles/Statement.cshtml:1899` | `Cancel` → `StatementModel.OnPostCancelAsync` | Full POST and catalogue redirect | Workspace loaded. **Hazard:** Cancel is intentionally non-destructive. Do not assert Draft deletion. |
| `statement.reset-absa` | Load default ABSA rules into the current form. | `.statement-header-meta form[action*="handler=ResetAbsa"]`<br>Open overflow dropdown and submit exact form, or submit exact form after confirming ID/name transport.<br>Source: `AtxSolutions/Pages/Banking/Profiles/Statement.cshtml:1906` | `ResetAbsa` → `StatementModel.OnPostResetAbsaAsync` | AJAX POST and fragment replacement | Correct profile ID/name preserved. **Hazard:** This separate form contains hidden `Form.Id` and `Form.ProfileName`, causing broad selector duplicates. |
| `statement.import-json` | Load exported settings JSON into the form for review. | `#profileJsonTools button[formaction*="handler=ImportJson"]:visible`<br>Open accordion; fill exact `#ImportProfileJson`; submit AJAX; verify exact visible form properties, not page text.<br>Source: `AtxSolutions/Pages/Banking/Profiles/Statement.cshtml:3878` | `ImportJson` → `StatementModel.OnPostImportJsonAsync` | AJAX POST and fragment replacement | Advanced mode; valid exported JSON. **Hazard:** ModelState can preserve posted visible values over server Form values. JSON import needs its own focused contract and must not be used as hidden setup for unrelated tests. |

## Guided Import action matrix

| ID | Purpose | Exact selector / resolution | Handler → method | Transport | Runtime requirement / hazard |
|---|---|---|---|---|---|
| `imports.current-session` | Classify any active session before navigating or mutating. | `Evaluate `window.__importSession`.`<br>Read ID, current step, selected account/profile/version, persisted file flags and original filename.<br>Source: `AtxSolutions/Pages/Banking/Imports.cshtml:1855` | `OnGet data` → `ImportsModel.OnGetAsync` | Read-only | Page loaded. **Hazard:** An active session overrides a requested `currentStep` query parameter. |
| `imports.select-bank-account` | Select the exact protected test bank account. | `#guidedBankAccount`<br>Resolve option by exact bank-name prefix and capture option value; select by value.<br>Source: `AtxSolutions/Pages/Banking/Imports.cshtml:578` | `StartSession form binding` → `OnPostStartSessionAsync(Guid profileId, Guid bankAccountId)` | Client state until POST | Step 1 visible; account active and tenant-owned. **Hazard:** Option text is `Bank name — account number`, not exactly the bank name. |
| `imports.select-profile` | Select the exact active Published profile from the Guided Import control. | On `#guidedProfile`, match exactly one option by exact visible text and `data-profile-scope="user"`; read that option's own `value`, select it by value, then verify the selected option text, scope and submitted GUID. A catalogue card may confirm that a Published profile with the expected name exists, but its Configure-route GUID must not be used as the form-selection authority.<br>Source: `AtxSolutions/Pages/Banking/Imports.cshtml:593-613` | `StartSession` form binding → `OnPostStartSessionAsync` | Client state until POST | Step 1 is visible; exact active Published option exists in the current workspace. **Hazard:** Do not infer a form option value from another page's route parameter. The control's own submitted value is authoritative. System profile text appends `(System)`; Drafts are not selectable. |
| `imports.start-session` | Create an exact ImportSession and advance to Evidence. | `#stepPane1 form[action*="handler=StartSession"] #btnStep1Next`<br>Verify button enabled; submit exact Step 1 form.<br>Source: `AtxSolutions/Pages/Banking/Imports.cshtml:572` | `StartSession` → `ImportsModel.OnPostStartSessionAsync` | Full POST and redirect to Step 2 | Exact account/profile GUIDs selected; no conflicting active session. **Hazard:** Do not infer session ID from URL; read hidden Step 2 session input / session JSON. |
| `imports.evidence-file` | Select one or more evidence files. | `#guidedFile`<br>Upload file(s); verify FileList, summary and Next enabled.<br>Source: `AtxSolutions/Pages/Banking/Imports.cshtml:643` | `UploadSessionFile form binding` → `OnPostUploadSessionFileAsync(Guid sessionId, List<IFormFile>? sessionFiles)` | Client state until POST | Exact owned Step 2 session. **Hazard:** Multiple non-image files are intentionally rejected. Multiple images are bundled into a synthetic ZIP. |
| `imports.next-preview-upload` | Upload and inspect evidence, then route to Preview or Extraction Review. | `#btnStep2Next`<br>Submit Step 2 form; inspect final URL and visible TempData/validation message before later assertions.<br>Source: `AtxSolutions/Pages/Banking/Imports.cshtml:687` | `UploadSessionFile` → `ImportsModel.OnPostUploadSessionFileAsync` | Full multipart POST and redirect | Exact session ID; selected file(s); selected profile source format compatible. **Hazard:** A profile/source mismatch redirects to Step 1. OCR-disabled image produces a clear Step 2 error. Always classify response before waiting. |
| `imports.cancel-visible-action` | Open the cancellation path for the exact active session. | `button[data-guided-cancel-import][data-bs-target="#cancelSessionModal"]:visible`<br>Use direct visible abandon form if uniquely visible; otherwise click exact modal trigger.<br>Source: `AtxSolutions/Pages/Banking/Imports.cshtml:554` | `Client Bootstrap modal` | No navigation until form submit | Exact owned session ID known. **Hazard:** The DOM can contain both visible direct and hidden modal abandon forms. |
| `imports.abandon-session` | Abandon exactly one owned session. | `form[action*="handler=AbandonSession"]:has(input[name="sessionId"][value="<GUID>"]):visible`<br>Prefer exactly one visible form; otherwise open modal and submit exact visible modal form.<br>Source: `AtxSolutions/Pages/Banking/Imports.cshtml:486` | `AbandonSession` → `ImportsModel.OnPostAbandonSessionAsync` | Full POST and redirect to Guided Step 1 | Exact session ID, ownership and test-data classification confirmed. **Hazard:** Never assert global form count 1. Hidden duplicates are intentional. |

## Extraction Review action matrix

| ID | Purpose | Exact selector / resolution | Handler → method | Transport | Runtime requirement / hazard |
|---|---|---|---|---|---|
| `review.form` | Confirm the mandatory review page and exact session. | `#pdfExtractionReviewForm:visible`<br>Verify form and `#SessionId` property.<br>Source: `AtxSolutions/Pages/Banking/Imports/ExtractionReview.cshtml:124` | `OnGet` → `ExtractionReviewModel.OnGetAsync` | GET | Owned session has an extraction snapshot requiring review. **Hazard:** Do not use form-relative `input[name=SessionId]` when exact generated ID exists. |
| `review.rows` | Read extracted transaction rows. | `#pdfExtractionReviewTable tr[data-review-row]`<br>Count rows; read values through `data-field` input properties.<br>Source: `AtxSolutions/Pages/Banking/Imports/ExtractionReview.cshtml:231` | `OnGet/posted state` → `LoadFromSessionAsync / BuildRowsFromSnapshotOrSessionFileAsync` | Read-only | Review form loaded. **Hazard:** Use authoritative page counters where UI row rendering may be capped elsewhere. |
| `review.source-file-field` | Verify per-row source attribution. | `<row> >> css=[data-field="SourceFileName"]`<br>Get Property `value`.<br>Source: `AtxSolutions/Pages/Banking/Imports/ExtractionReview.cshtml:264` | `Row form binding` → `ExtractionReviewRowInput.SourceFileName` | Read-only until submit | Exact row selected. **Hazard:** Input values are not included in `Get Text`. |
| `review.save-corrections` | Save non-blocking review corrections without accepting. | `#pdfReviewActionBar button[formaction*="handler=Save"]:visible`<br>Submit and inspect ModelState/redirect.<br>Source: `AtxSolutions/Pages/Banking/Imports/ExtractionReview.cshtml:367` | `Save` → `ExtractionReviewModel.OnPostSaveAsync` | Full POST; Page on blocking issues, redirect back on success | Exact session; posted rows normalized. **Hazard:** Blocking issues correctly return the page and preserve posted corrections. |
| `review.accept-warnings` | Acknowledge advisory warnings before acceptance. | `#AcceptWarnings`<br>Check only after comparing advisory rows with source.<br>Source: `AtxSolutions/Pages/Banking/Imports/ExtractionReview.cshtml:362` | `Accept form binding` → `ExtractionReviewModel.AcceptWarnings` | Client state until Accept POST | Warnings present and no blocking issues. **Hazard:** ASP.NET may render a hidden checkbox fallback. Always use exact ID/type. |
| `review.accept-continue` | Accept reviewed extraction and continue to Guided Preview. | `#pdfReviewAcceptButton:visible`<br>Verify enabled and warning acknowledgement as required; submit.<br>Source: `AtxSolutions/Pages/Banking/Imports/ExtractionReview.cshtml:372` | `Accept` → `ExtractionReviewModel.OnPostAcceptAsync` | Full POST; Page on rejection/blocking/warnings, redirect to Guided Step 3 on success | No rejection/blocking; warnings acknowledged if present. **Hazard:** Focused tests that must not import should not click this button. |

## Runtime certification matrix

| Gate | Required evidence | Failure classification |
|---|---|---|
| **Package integrity** | ZIP opens, internal hashes match, required files and recorder outputs match manifest. | `TEST_INVALID or ERROR` |
| **PowerShell/Robot structure** | Windows PowerShell parser passes; Robot parser/dry-run resolves libraries, variables, setups, teardowns and every custom keyword. | `ERROR or TEST_INVALID` |
| **Runner-to-suite contract** | Exact equality between suite-required runtime variables, runner-supplied variables and installer-required files. | `TEST_INVALID` |
| **Source hash gate** | All source hashes in this matrix match the local newest code pack. | `TEST_INVALID; regenerate matrix` |
| **Action contract gate** | Selector anchor, rendered selector, handler, PageModel method, transport and expected response all match. | `TEST_INVALID` |
| **Runtime selector preflight** | Every required control resolves to expected visible count and correct type before mutation. | `TEST_INVALID or BLOCKED` |
| **Test-data preflight** | Exact workspace/account/profile/session IDs and ownership are confirmed; no unsafe duplicate data. | `BLOCKED or TEST_INVALID` |
| **Immediate response gate** | After every POST/AJAX: status, final URL, validation summary, feedback, ID/state and handler outcome are classified. | `TEST_INVALID, BLOCKED, ERROR or FAIL` |
| **Cleanup gate** | Exact created/adopted IDs are cleaned or intentionally preserved; no production object touched. | `TEST_INVALID or FAIL only if certified app cleanup contract violated` |
| **Functional assertion gate** | All previous gates passed. Only now may an acceptance mismatch be labelled FAIL. | `FAIL` |

## Test-generation rules

1. Generate functional Robot keywords from the JSON action IDs rather than copying selectors from old test packages.
2. A package must list the action IDs it uses in `TestManifest.json`.
3. The package validator must confirm every listed action ID exists and every source hash matches.
4. The package must run the matrix-defined runtime preflight before creating a Draft, session, artifact or import.
5. Do not use JSON import, Reset ABSA, or any other unrelated setup shortcut unless that action itself is part of the acceptance scope.
6. Use the smallest already-unverified tail; do not rerun completed scopes.
7. Static checks must be described as static. They are not live DOM or handler proof.


## Additional certified Statement navigation and result actions

| ID | Purpose | Exact selector / resolution | Handler / transport | Runtime requirement / hazard |
|---|---|---|---|---|
| `statement.open-detailed-section` | Open an exact detailed section. | `.statement-config-nav button[data-section-target="<SECTION_ID>"]:visible`; assert `#<SECTION_ID>.statement-section.is-active:visible`. | Client-side `showSection`; no server navigation. | Advanced-only sections require Advanced mode. Do not substitute major/mobile navigation. |
| `statement.open-major-section` | Open Save Profile or another major section. | `.statement-progress:visible button.statement-progress-step[data-major-target="<SECTION_ID>"]:visible`; assert active section. | Client-side `showSection`; no server navigation. | Basic and Advanced progress strips coexist; scope to the visible strip. |
| `statement.read-ajax-outcome` | Classify an AJAX POST before later assertions. | Wait for AJAX busy state to clear; read replacement page, validation summary, feedback data/tone, URL/hash and returned ID/state. | Fetch POST and fragment replacement or documented redirect. | HTTP success can still contain validation errors. Never wait only for a later ID or card. |
| `statement.read-test-outcome` | Read authoritative representative-test state. | `#test-results .statement-test-summary-grid:visible`, direct Test Results badge, success-card value and provider/mode summary. | Read-only result of Test/RerunExtraction. | Use authoritative summary values, not a potentially capped table. |


### Repeated Save Draft & Exit render locations

`statement.save-draft-exit` is one semantic action rendered in four locations:

| Render location | Selector | Desktop expectation | Mobile expectation | Handler |
|---|---|---:|---:|---|
| Header | `button.statement-save-exit-header[data-visible-save-and-exit]:visible` | 1 when header action is visible | 0 | `SaveAndExit` |
| Save card primary | `#save-profile .statement-primary-save-actions button[data-visible-save-and-exit]:visible` | 1 — canonical desktop click target | typically hidden with desktop layout | `SaveAndExit` |
| Save section footer | `#save-profile .statement-section-footer button[data-visible-save-and-exit]:visible` | 1 — equivalent secondary location | layout-dependent | `SaveAndExit` |
| Mobile sticky actions | `.statement-mobile-sticky-actions button[data-visible-save-and-exit]:visible` | 0 | 1 | `SaveAndExit` |

The combined desktop selector:

```text
#save-profile button[data-visible-save-and-exit]:visible
```

has an expected count of **2**, not 1. Tests must click the canonical primary selector rather than asserting global uniqueness.


## Multi-evidence and archive action matrix

| ID | Contract |
|---|---|
| `imports.upload-multiple-images` | One file-input operation may select multiple supported images. The server creates `screenshot-batch-<timestamp>.zip` with `01_`, `02_`, … prefixes in browser selection order. Any non-image in the selection rejects the whole request at Step 2. |
| `imports.upload-image-only-archive` | A safe ZIP containing images only routes to ImageArchive OCR and mandatory Extraction Review. ZIP entries are processed by `FullName` using ordinal-ignore-case order. |
| `imports.upload-pdf-only-archive` | A safe ZIP containing PDFs only routes to PDF archive direct-text/OCR inspection and review. It is not processed by the screenshot normalizer. |
| `imports.reject-mixed-evidence-archive` | A ZIP containing both PDF and image entries is rejected by the file-safety service before session-file persistence. |
| `imports.read-feedback-banner` | Read `.bankimports-banner:visible` immediately after POST redirect because success/error feedback may auto-dismiss. |
| `review.file-summaries` | Read `.pdf-review-file-summary .pdf-review-file-name`; expect one card per distinct row-level source filename. |
| `review.verify-image-order-dedup` | For the certified overlap dataset, read row field properties and verify exact-fingerprint deduplication, date/source ordering and source attribution. |

### Certified screenshot merge contract

```text
direct multi-image selection
→ synthetic ZIP with two-digit selection-order prefixes
→ image entries sorted by FullName
→ OCR each source independently
→ exact fingerprint deduplication
→ known dates ascending
→ source order
→ reverse visual row order for same source/day
→ same-day sort key
→ mandatory Extraction Review
```

The exact screenshot duplicate fingerprint contains:

```text
date
normalized description
amount
balance
```

It is not fuzzy duplicate detection.

### Archive separation contract

```text
image-only ZIP  → ImageArchive OCR
PDF-only ZIP    → PdfArchive direct text/OCR
mixed ZIP       → reject before persistence
```


## Synthetic OCR evidence calibration and multi-test classification

### Calibrated overlap dataset

The deployed `Phase 25J OCR IMAGE TEST` profile with `local-tesseract` has now proven these rows reliable:

```text
2026-05-28
2026-05-29
2026-05-30
2026-05-31
```

The row below was omitted in both the earlier single-image baseline and the direct multi-image V1 run:

```text
2026-06-01 — Bank service fee
```

It must not remain a required hard assertion in the corrected package unless it first passes a separate calibration.

The corrected overlap dataset is:

```text
Source A: 28 May, 29 May, 30 May
Source B: 30 May, 31 May

5 extracted source rows
→ 1 exact overlap removed
→ 4 Extraction Review rows
```

### Independent scenario execution

The following must be separate Robot test cases:

```text
direct multiple images
image-only ZIP
PDF-only ZIP
mixed PDF/image ZIP rejection
```

Each test performs exact session cleanup in its own teardown. One `BLOCKED` scenario must not prevent later scenarios from running.

### Classification aggregation

Runner and recorder precedence:

```text
ERROR
→ TEST_INVALID
→ FAIL
→ BLOCKED
→ PASS
```

The runner must inspect all failed tests. The recorder must use a classification explicitly recorded before the custom library raises; `${SUITE MESSAGE}` is not a valid classification source.


## Guided Import session JSON schema

`window.__importSession` is produced by `ImportsModel.SerializeSessionState` and uses these exact camelCase properties:

```text
id
step
status
selectedProfileId
selectedBankAccountId
originalFileName
storedFileName
hasPersistedFile
hasOwnerScopedArtifact
autoDetectResultJson
columnMappingJson
importResultBatchId
updatedAt
hasPreview
hasValidation
```

The workflow step must be read as:

```javascript
window.__importSession.step
```

These are invalid:

```javascript
window.__importSession.currentStep
window.__importSession.CurrentStep
```

`currentStep` remains valid only as the Guided Import URL/query parameter.

### Mixed archive rejection state

After the source-confirmed mixed PDF/image ZIP rejection:

```text
URL path                  /Banking/Imports
activeTab                 guided
currentStep query         2
visible pane              #stepPane2
session id                unchanged exact GUID
window.__importSession.step                 2
window.__importSession.hasPersistedFile     false
window.__importSession.hasOwnerScopedArtifact false
window.__importSession.originalFileName     empty/null
window.__importSession.storedFileName       empty/null
window.__importSession.hasPreview           false
window.__importSession.hasValidation        false
```

The schema must be validated before these values can produce an application assertion.


## Advanced visual-layout action matrix

| ID | Certified interaction |
|---|---|
| `statement.regions-editor` | Configure the generated `.ocr-region-card` controls. Hidden region JSON is verification-only. |
| `statement.add-ignore-region` | Click `#addDefaultRegion` exactly once and configure the second card as Ignore. |
| `statement.add-anchor-rule` | Click `#addAnchorRule` twice and configure start/below and end/above anchors. |
| `statement.table-detection-settings` | Enable table detection, expected count 5, automatic bands and wrapped-row merging. |
| `statement.use-detected-columns` | Click after initial Test; detected geometry or the source-confirmed five starter bands becomes Manual. |
| `statement.manual-column-editor` | Edit generated manual column bands and verify normalized JSON. | `#columnMappingList .statement-column-item`<br>Capture each visible card's stable `data-column-id`; target all later field/boundary edits by that identity; verify hidden `#ColumnMappingsJson` only after changes.<br>Source: `AtxSolutions/wwwroot/js/banking-statement-column-mapping.js:91` | Client column-mapping controller → Remap | Client state followed by AJAX Remap POST | Manual mode selected. **Hazard:** Every field or boundary change can re-render and sort cards by `leftPercent`; `nth-child` is not stable across edits. Direct JSON writes remain prohibited. |
| `statement.amount-rules` | Configure SignedAmount and explicit separators/negative style. |
| `statement.row-reconstruction-settings` | Persist wrapped-description joining and a continuation rule. |
| `statement.ordering-duplicates-settings` | Persist StrictRowMatch and summary-row cleanup. |
| `statement.balance-validation-settings` | Persist running-balance reconciliation and minimum confidence. |

### Scope boundary

```text
dedicated disposable Draft
→ prepare synthetic image
→ configure visible dynamic controls
→ initial Test for positioned geometry
→ choose/manualise columns
→ Remap & Validate cached geometry
→ Save Draft & Exit
→ exact-GUID reload and persistence proof
→ delete exact never-published Draft
```

The test must not publish, start Guided Import or modify any protected profile.



## Statement interpretation result matrix (V12)

| ID | Certified interaction and outcome |
|---|---|
| `statement.read-extracted-rows` | Read six visible result cells in rendered source order after cached Remap. |
| `statement.verify-wrapped-row-reconstruction` | With wrapped-row and continuation settings enabled, an undated amountless detail line is appended to the previous manually mapped transaction description. |
| `statement.verify-amount-field-precedence` | Signed Amount wins when populated; blank Signed Amount falls back to Credit minus Debit. |
| `statement.verify-running-balance-order` | Same-date rows keep source order and the four displayed balances form one continuous chain without variance warnings. |

### V12 scope boundary

```text
one disposable never-published Draft
→ packaged synthetic image
→ visible seven-column mapping
→ initial positioned OCR
→ cached Remap
→ exact displayed row/value assertions
→ exact Draft deletion
```

A raw OCR identity mismatch is `BLOCKED` calibration evidence, not an ATX functional failure. Once calibrated row identity is present, contradictory amount, ordering or balance output is `FAIL`.


## Low-confidence and bounded-recovery action matrix (V20)

| ID | Certified interaction and outcome |
|---|---|
| `statement.validation-minimum-ocr-confidence` | Use the visible `MinimumOcrConfidence` validation-rule card, keep it enabled, set `RequiresReview`, and set the exact threshold. Hidden validation JSON is verification-only. |
| `statement.recovery-enable-limits` | Enable recovery and configure `MaximumAttempts`, overall/per-attempt budgets, retry-on-review and stop conditions through the visible controls. |
| `statement.recovery-attempt-editor` | Add and edit generated `.statement-recovery-attempt-card` controls. Each attempt must have a materially different execution fingerprint. Hidden retry JSON is verification-only. |
| `statement.run-bounded-recovery` | Run one Test/Rerun Extraction request and allow the service to execute no more than the configured total attempt count. |
| `statement.read-recovery-history` | Read the accepted summary and every rendered recovery-history item. Candidate count and confidence are provider-stage scoring metrics; they are not the final post-mapping row count. |
| `statement.verify-best-recovery-result` | Calculate the source score from each rendered attempt's provider-stage metrics and verify the Accepted item is the strict highest-scoring result; verify the final mapped row count separately from the Test Results summary. |

### V20 scope boundary

```text
one disposable never-published Draft
→ one packaged synthetic low-confidence image
→ visible validation rule setup
→ visible bounded recovery setup
→ one extraction request
→ complete recovery-history and provider-stage score assertions
→ separate final mapped-row assertion from the Test Results summary
→ final Requires-review outcome
→ exact Draft deletion
```

The package must not publish, start Guided Import, accept Extraction Review, create a batch or create transactions.

## Profiles catalogue create-menu scoping

The Profiles page contains three rendered links whose href begins with:

```text
/Banking/Profiles/Statement
```

in the current certified state:

```text
1 create-menu Statement profile link
2 existing profile-card Configure links
```

This global selector is prohibited:

```text
a[href^="/Banking/Profiles/Statement"]:visible
```

The canonical create selector is:

```text
ul[aria-labelledby="newProfileDropdown"]
  a.dropdown-item[href="/Banking/Profiles/Statement"]:visible
```

It must be resolved only after clicking `#newProfileDropdown`.

## Cleanup evidence truthfulness

A teardown that had nothing to delete is not proof of deletion.

Required reporting:

```text
No Draft created:
  cleanupSucceeded = true
  draftCreated = false
  exactDraftDeleted = false

Exact Draft created/resumed and deleted:
  cleanupSucceeded = true
  draftCreated = true
  exactDraftDeleted = true
  deletedProfileId = <exact GUID>
```

Recorder and runner output must agree.


## Statement Profile JavaScript readiness

The Statement Profile markup can become visible before `DOMContentLoaded` has completed the page-controller initialization.

The source-confirmed end-of-initialization marker is:

```javascript
typeof window.__atxStatementProfileCleanup === 'function'
```

This marker is assigned only after:

```text
mode-button listeners
section navigation
dynamic region/anchor editors
column mapping
contextual help
AJAX form handlers
```

have been initialized.

Required interaction sequence:

```text
wait for .statement-profile-page visible
→ wait for __atxStatementProfileCleanup function
→ resolve exactly one visible Advanced button
→ click once
→ verify data-profile-mode=advanced
```

A Browser click marked PASS before the listener exists is not proof that the application action ran.

## Current OCR-image provisioning implications

- Create a new incomplete Draft with **Save Draft & Exit**, not Save Draft & Continue.
- Reopen the exact Draft by ID before advanced configuration.
- Configure source type through the Image source card so the page JavaScript sets `SampleSourceType`, `FormImageType` and the recommended OCR mode.
- Select DPI/language/provider using live `<select>` options.
- Run the representative test and inspect its immediate AJAX response.
- Publish only through Save Draft & Publish after the exact cached result is current and non-blocking.
- Use the exact Published profile ID in Guided Import.
- Stop at Extraction Review unless acceptance/import is explicitly in scope.


## Final-import status and cleanup-tail matrix (V26)

| ID | Certified interaction and outcome |
|---|---|
| `imports.batch-detail-json` | `importedRows` and `transactionCount` must equal accepted review rows. Derive `Failed` / `Partial` / `Completed` from `errorCount`, `warningCount` and `importedRows`; do not require `Completed` for warning-bearing imports. |
| `imports.undo-exact-runtime-batch` | Undo redirects to the default Guided tab. Navigate explicitly back to Import History, re-resolve the exact batch trigger, and prove `Reversed` with zero transactions. |
| `final-import-tail-reuse` | When a prior run already proved one exact batch and row-count idempotency, reuse its exact batch ID and runtime filename for a tail-only status/cleanup package instead of creating another import. |

The V1.2.2 result is `TEST_INVALID`: one exact batch imported both accepted rows, but the package incorrectly rejected the source-valid `Partial` status and did not certify the post-Undo redirect before marking cleanup complete.


## Maintenance

Place this file and its JSON companion under `AtxSolutions.UiTests/docs/`. Whenever any source hash changes, regenerate the matrix from the newest project ZIP before creating another test package.

---

# Part III — Machine-Readable ATX Source–Action Contracts


## V30 Banking-only scope correction and Payment Evidence profile/preview contract

The V29 general UI package is withdrawn from Phase 25J. Active Phase 25J work is restricted to `/Banking/*`, with this package covering only `/Banking/PaymentEvidence`.

| Action ID | Runtime contract |
|---|---|
| `payment-evidence.open-profiles-tab` | Open the Payment Evidence Profiles pane directly. |
| `payment-evidence.new-profile-modal` | Open and reset one dedicated new-profile modal. |
| `payment-evidence.profile-preview-map` | Preview the synthetic CSV and map through generated visible selectors. |
| `payment-evidence.save-profile` | Create one tenant-owned active disposable profile. |
| `payment-evidence.find-exact-profile` | Resolve exactly one saved profile and capture its GUID. |
| `payment-evidence.open-exact-profile` | Reopen by exact ID and verify persisted configuration. |
| `payment-evidence.import-preview` | Preview five rows without executing an import. |
| `payment-evidence.delete-exact-profile` | Delete and prove absence of the exact disposable profile. |
| `payment-evidence.read-import-preview-results` | Read the exact direct-child Preview Results card without matching ancestors. |
| `payment-evidence.execute-import` | Execute the exact preview once and capture the redirected batch GUID. |
| `payment-evidence.read-exact-batch-review` | Verify exact batch totals, status and row kinds. |
| `payment-evidence.delete-exact-batch` | Delete only the captured disposable batch and prove absence. |

Important boundary:

```text
PaymentEvidenceImportProfile is not a Statement lifecycle Draft.
The test creates one disposable active profile, previews representative CSV evidence,
reopens the exact profile, verifies persistence, previews the import, and deletes the exact profile.
No Payment Evidence batch or row is imported.
```



## V37 Payment Evidence ownership and cross-tenant security contract

Phase 25J remains restricted to `/Banking/*`. This focused contract creates one disposable Payment Evidence profile and batch, proves owner access, proves the exact profile and batch are denied in `Basic Beside CIPC`, restores owner access, and deletes only the captured IDs.

Runtime and source proof remain separate: tenant-boundary behavior is browser-proven; manager/operation/artifact/profile ownership assignment is source-certified from the current project hash.

## V43 Phase 25J final protected baseline, cleanup and acceptance closeout

This is the final Banking-only Phase 25J runtime package. It is read-only.

It verifies:

```text
Phase 25J OCR IMAGE TEST remains v1 Published.
Phase 25J TEST A1 remains v1 Published.
The preserved production batch 99bc4964-0bcb-4061-ad09-88574cd17ec6 remains Completed with 77/77/77 and zero duplicate/skip/error/warning counts.
No disposable Statement profile prefix remains.
No disposable Payment Evidence profile or test file remains.
No active Guided Import session remains.
The packaged acceptance matrix contains the accepted PASS evidence supplied during this session.
```

It must not create, edit, publish, archive, delete, undo, abandon, upload, accept extraction, execute an import, or mutate any profile, session, artifact, batch, row or transaction.



## Phase 25H-D2-A concurrent Payment Evidence import recovery (V51)

The V1.5 website-only result proved that preview, artifact storage and usage persistence now succeed. Its concurrent double-submit reached final import persistence and exposed a true owner-operation race: both requests passed the pre-check, the unique index correctly allowed one batch, and the losing request surfaced a generic `DbUpdateException` instead of returning the batch committed by the winning request.

The V51 application contract preserves the unique database index as the final concurrency guard and adds narrowly scoped recovery:

```text
same tenant + manager + operation + source artifact
→ both requests pass the pre-check
→ one transaction commits the batch and rows
→ the losing transaction receives SQL Server 2601 or 2627
→ losing transaction rolls back
→ losing batch and rows are detached
→ transaction scope unwinds
→ exact committed winner is reloaded by tenant, manager, operation and source artifact
→ both website responses redirect to the same batch ID
```

Recovery is prohibited for any other SQL error. If the unique-key error does not resolve to an exact owner-scoped winning batch, ATX returns the safe support reference `PE-IMPORT-IDEMPOTENCY` and does not adopt a batch from another operation, artifact, manager or tenant.

Remaining database failures now return an actionable, non-sensitive website message with `PE-IMPORT-SQL<number>`, `PE-IMPORT-DATABASE` or `PE-IMPORT-UNEXPECTED`. Connection information, SQL parameters and uploaded evidence content remain excluded.

| Action ID | Action type | Runtime contract |
|---|---|---|
| `payment-evidence.execute-import-double-submit` | Test | Submit the exact Execute Import form twice concurrently from the same preview. Both responses must resolve to the same exact batch GUID with no application error. |
| `payment-evidence.same-operation-idempotency-source` | Code + source contract | Only SQL Server 2601/2627 enters recovery; the losing attempt rolls back and detaches, then reloads the exact winner after its transaction has unwound. |
| `payment-evidence.verify-single-active-batch` | Test | The website shows one active batch for the runtime-unique filename and one exact Resume link to the shared batch GUID. |

### V51 browser boundary

Robot remains website-only. It proves both same-operation responses, one visible batch, the exact review and website cleanup. It does not query the database or claim direct row-count proof outside the website.

## Phase 25H-D2-A Banking usage text-constraint correction (V50)

The V1.4 website-only result is a valid application `FAIL`. Application Logs identify SQL Server error 547 and the exact failing constraint:

```text
CK_BankingUsageEvents_Text
```

The recorded event key is lowercase and contains only the intended machine-token characters. The corresponding usage type is `ArtifactStored` and unit is `Bytes`. Source audit therefore confirms that the application-generated values satisfy the C# machine-token contract, while the deployed range-based SQL wildcard predicate rejects them.

The corrected database contract replaces collation-sensitive character ranges with explicit ASCII allow-lists:

```text
EventKey:
  lowercase letters, digits, colon, period, underscore and hyphen

UsageType / UnitType / AdjustmentReasonCode:
  uppercase and lowercase letters, digits, colon, period, underscore and hyphen
```

The deployment hotfix is idempotent, replaces only `CK_BankingUsageEvents_Text`, rechecks existing rows with `WITH CHECK`, and fails transactionally if certified `ArtifactStored`/`Bytes` tokens are rejected or invalid space/uppercase EventKey samples are accepted. The read-only verification script performs no inserts, updates or deletes.

The Payment Evidence page now maps this exact failure to:

```text
PE-PREVIEW-SAVEEVIDENCE-SQL547-CKTEXT
```

and explains that an internal Banking data-format rule rejected the usage reference. It does not expose SQL text, connection information, evidence content or other sensitive details.

| Action ID | Action type | Runtime contract |
|---|---|---|
| `phase25h-d2a.website-preview-outcome-classification` | Test | A visible `PE-PREVIEW-SAVEEVIDENCE-SQL547-CKTEXT` message is an application `FAIL`; Robot captures it immediately and does not wait for the Preview Results card. |
| `phase25h-d2a.website-preview-friendly-error` | Test | The website explains the failed Banking usage-reference stage, confirms no preview rows were imported and supplies the exact support reference. |

### V50 browser boundary

Robot remains website-only. The schema hotfix and its read-only verification are deployment artifacts, not Robot dependencies. The Robot package must not open a database connection, read application configuration, run SQL or claim direct proof of the immutable usage row.

## Phase 25H-D2-A trigger-compatible usage persistence and actionable preview errors (V49)

The V1.3 website-only result correctly exposed a deployed `DbUpdateException` while saving the immutable Banking usage event. The application now preserves the existing EF mapping that disables SQL Server `OUTPUT` for the trigger-backed ledger and adds a narrowly guarded SQL Server error 334 fallback that inserts through the current `AppDbContext` connection and transaction without an `OUTPUT` clause. The fallback remains parameterized and all existing table constraints, ownership triggers and append-only protections still execute. It does not create a new connection or read a connection string.

When a Banking usage write fails for any other reason, Application Logs must include the safe SQL error number, state, class and message together with tenant, manager, operation and event-key lineage. Connection strings, SQL parameter values, filenames and evidence content remain excluded.

The Payment Evidence preview page now tracks the failed stage and renders an actionable website error. For secure evidence persistence failures, the user is told that ATX could not save the secure evidence and usage record, that preview stopped before any rows were imported, and which support reference to use when an administrator checks Application Logs.

| Action ID | Action type | Runtime contract |
|---|---|---|
| `phase25h-d2a.website-preview-outcome-classification` | Test | Classify the immediate Upload Preview result using the exact preview card, `[data-payment-evidence-error]`, validation summary, authentication response or access-denied response. |
| `phase25h-d2a.website-preview-friendly-error` | Test | When preview fails, read `[data-payment-evidence-error-message]` and require a stage-specific explanation, an explicit statement that no rows were imported, and a `PE-PREVIEW-*` Application Logs support reference. |

### V49 browser boundary

The Robot package remains website-only. It must not query the database, read application configuration, inspect local source at runtime or claim direct proof of an internal usage row. The friendly error contract is asserted only if the website returns an error; a successful preview continues through the existing visible preview, retry, batch-review and cleanup assertions.

## Phase 25H-D2-A execution-strategy hotfix and browser outcome classification (V48)

The production Payment Evidence preview failure was traced to `BankingEvidenceArtifactService.SaveAsync`: an explicit relational transaction was opened outside the configured EF Core retrying execution strategy. The hotfix moves the complete owned transaction inside `CreateExecutionStrategy().ExecuteAsync(...)`, keeps one stable artifact ID and event key across retries, and reuses an already committed artifact/usage pair after an ambiguous commit.

The Robot boundary remains website-only. The package must not connect to SQL Server, read database configuration, query `BankingUsageEvents`, or inspect local application source at runtime.

| Action ID | Action type | Runtime contract |
|---|---|---|
| `phase25h-d2a.website-preview-outcome-classification` | Test | After the visible Upload Preview action, classify the immediate website result as exactly one of: Preview Results success, visible application-error alert, visible validation error, authentication/authorization response, or timeout. A visible application-error alert is an application `FAIL`, not `TEST_INVALID`. |
| `phase25h-d2a.website-preview-visible` | Test | Only after the immediate outcome classifier confirms success may the package assert the exact filename, five detected rows, five classified rows, zero unknown rows and one duplicate warning. |

### Application Logs diagnostic boundary

`/Admin/SystemSettings/ApplicationLogs` may be added later as an optional website-only diagnostic tail only after a dedicated read-only diagnostic user is granted the minimum required access. Until then, the package records the visible failing route, message, timestamp, disposable profile and runtime filename, and captures a screenshot. Lack of Application Logs access must not hide or downgrade a visible application failure.

## Phase 25H-D2-A website-only Robot action matrix (V47)

**Authority:** `Project Context File(15).zip` plus the approved D1-A and D2-A overlays.  
**Combined authority SHA-256:** `b3f2307ca4dc77e94d97df4656607e108f50e12d2da637d58de303ded88da177`

| Action ID | Action type | Runtime contract |
|---|---|---|
| `phase25h-d2a.website-preview-visible` | Test | Through `/Banking/PaymentEvidence`, one exact runtime-unique CSV produces one visible Preview Results card with the expected filename, five rows, five classified rows, zero unknown rows and one duplicate warning. |
| `phase25h-d2a.website-retry-single-batch` | Test | Two bounded submissions of the exact visible Execute Import form resolve to one unique batch GUID and the website lists one active batch for the exact runtime filename. |
| `phase25h-d2a.website-cleanup-visible` | Test | The exact batch and profile are deleted through website controls; the deleted batch returns the website's not-found state and the exact profile row is absent. |

### V47 focused package boundary

```text
Creates through the website:
  one disposable active Payment Evidence profile
  one runtime-unique synthetic CSV upload
  one Payment Evidence InReview batch
  five disposable Payment Evidence rows

Deletes through the website:
  the exact disposable batch and rows
  the exact disposable profile

Browser-proves:
  preview result and classification output
  same-form retry produces one visible batch
  exact batch review values
  exact website cleanup

Does not access or read:
  SQL Server or any database
  appsettings database configuration
  BankingUsageEvents
  BankingEvidenceArtifacts tables
  local project source as runtime evidence

Does not claim browser proof of:
  the internal artifact ID
  the usage event key
  stored byte quantity
  append-only usage-row persistence
```

<!-- BEGIN ATX_ACTION_CONTRACTS_JSON -->
```json
{
  "schemaVersion": 2,
  "title": "ATX Robot Testing Source of Truth V53 — Phase 25H-D2-B Processing Usage",
  "generatedAtUtc": "2026-07-31T10:45:00Z",
  "authoritativeCodePack": {
    "name": "ATX_Banking_Phase25H_D2B_Processing_Usage_20260731.zip",
    "sha256": "492f1926d1fee3781b2c6917631c5ba1343ee1513dbee24bac4395857a3e4b1a",
    "authority": "Project Context File(15).zip plus approved D1-A, D2-A and D2-B overlays"
  },
  "scope": [
    "Banking Profiles catalogue",
    "Statement Profile workspace",
    "Guided Banking Import",
    "Extraction Review",
    "Robot package certification rules",
    "Phase 25J Banking-only Payment Evidence retry and duplicate-prevention acceptance",
    "OCR problem-state correction persistence and Banking-only UI closeout",
    "Phase 25J final protected baseline, cleanup and acceptance closeout",
    "Phase 25H-D1-A append-only Banking usage foundation",
    "ATX Robot website-only runtime boundary",
    "Phase 25H-D2-A Payment Evidence browser-visible preview, retry and cleanup acceptance",
    "Phase 25H-D2-A execution-strategy hotfix",
    "Phase 25H-D2-A immediate website preview-outcome classification",
    "Phase 25H-D2-A trigger-compatible usage persistence and actionable Payment Evidence preview errors",
    "Phase 25H-D2-A Banking usage text-constraint correction and exact user-facing SQL547/CKTEXT diagnostics",
    "Phase 25H-D2-A concurrent same-operation Payment Evidence import recovery",
    "Phase 25H-D2-B owner-scoped processing usage for direct text, OCR, image preparation, cached Remap and bounded recovery",
    "Phase 25H-D2-B website-only processing acceptance and exact disposable cleanup"
  ],
  "mandatoryRule": "A functional FAIL is permitted only after package certification, source hashes, runtime preflight, exact handler identity, immediate response classification, prerequisites and cleanup contract pass.",
  "sourceInventory": {
    "profiles_index_razor": {
      "path": "AtxSolutions/Pages/Banking/Profiles/Index.cshtml",
      "sha256": "22a4192c31e281e20504172cff4f57238bb8ef7d204b30cfc41062406b9e52b2",
      "lineCount": 523
    },
    "profiles_index_model": {
      "path": "AtxSolutions/Pages/Banking/Profiles/Index.cshtml.cs",
      "sha256": "3c261f3f7d1e3aafb48a9dac54c2b10263810cfc836f510b7b1dec7e1acce7ea",
      "lineCount": 328
    },
    "statement_razor": {
      "path": "AtxSolutions/Pages/Banking/Profiles/Statement.cshtml",
      "sha256": "2eedf0f8401a20a16b8490e648aee49c5e51c8e71b30d7c583392ee74183e56f",
      "lineCount": 4981
    },
    "statement_model": {
      "path": "AtxSolutions/Pages/Banking/Profiles/Statement.cshtml.cs",
      "sha256": "9bf33caddee62a723117072108610973abc23f7663947b39b63a676d244ad2fd",
      "lineCount": 2773
    },
    "imports_razor": {
      "path": "AtxSolutions/Pages/Banking/Imports.cshtml",
      "sha256": "85d9435c7ffa43c916328ebb766533a07fd9882f7898177aa7c1a6419b805a44",
      "lineCount": 3124
    },
    "imports_model": {
      "path": "AtxSolutions/Pages/Banking/Imports.cshtml.cs",
      "sha256": "831973308fbce32c76b9f3b070926d886750c8817a4dfdc505dd99b5690e7777",
      "lineCount": 4619
    },
    "review_razor": {
      "path": "AtxSolutions/Pages/Banking/Imports/ExtractionReview.cshtml",
      "sha256": "725c594585ad274e7829df15dcf073095e7d65d6b8ba05a8416679f8f46895b7",
      "lineCount": 1257
    },
    "review_model": {
      "path": "AtxSolutions/Pages/Banking/Imports/ExtractionReview.cshtml.cs",
      "sha256": "8bad735700c4aaf21f0c4257b149646393e1dba63eeb6da89744b858c6e21757",
      "lineCount": 1054
    },
    "source_service": {
      "path": "AtxSolutions/Features/Banking/Services/SourceIngestion/BankImportSourceService.cs",
      "sha256": "f18d8c4fdbe83cd7b416398acd90aa6d713689813ad35dcf95ee3912ecf4782a",
      "lineCount": 987
    },
    "image_ocr_normalizer": {
      "path": "AtxSolutions/Features/Banking/Services/SourceIngestion/BankImportImageOcrNormalizer.cs",
      "sha256": "7da1bc2609d90360f53b8778c18c2d9e69640d3da272a46b2c442173b4162035",
      "lineCount": 814
    },
    "pdf_text_normalizer": {
      "path": "AtxSolutions/Features/Banking/Services/SourceIngestion/BankImportPdfTextNormalizer.cs",
      "sha256": "1dfed89f9163eb86a5da1f8a5abca83bc4301077618e8996b1f7eadfd963117d",
      "lineCount": 1073
    },
    "pdf_ocr_normalizer": {
      "path": "AtxSolutions/Features/Banking/Services/SourceIngestion/BankImportPdfOcrNormalizer.cs",
      "sha256": "df0ddbd69b9a53ae7d616b80798a4d1d03dc1b27c6abe893e318b00ab50612e7",
      "lineCount": 1050
    },
    "evidence_file_safety": {
      "path": "AtxSolutions/Features/Banking/Services/SourceIngestion/Safety/BankingEvidenceFileSafetyService.cs",
      "sha256": "03d8af4d4b70913d7c98d784366cb3ea27ee56330c7a7f56440c2e537fe59229",
      "lineCount": 653
    },
    "statement_column_mapping_js": {
      "path": "AtxSolutions/wwwroot/js/banking-statement-column-mapping.js",
      "sha256": "fbb4149da9edefb1c22f7fb0c7f9c13097d2a6706614b898c2c6755b6992b18a",
      "lineCount": 681
    },
    "statement_column_mapping_engine": {
      "path": "AtxSolutions/Features/Banking/Services/SourceIngestion/BankStatementColumnMappingEngine.cs",
      "sha256": "a65eef89f7d6147a79ef7913e49d0fecb14b98ae8557a0f3de8de88540691fae",
      "lineCount": 1046
    },
    "statement_column_mapping_tests": {
      "path": "AtxSolutions.Tests/Features/Banking/SourceIngestion/BankingContentExtractionFoundationTests.cs",
      "sha256": "86dd032ebdf53d3db86d1603d5628656d0ff94e0359cef44537ac4876997a557",
      "lineCount": 1964
    },
    "statement_cached_extraction_interpreter": {
      "path": "AtxSolutions/Features/Banking/Services/SourceIngestion/BankStatementCachedExtractionInterpreter.cs",
      "sha256": "4888413cfef3d83c2347004d739bc5e98a304abf60dd2d21447eb4e8e712a2be",
      "lineCount": 86
    },
    "statement_profile_flow_regression_tests": {
      "path": "AtxSolutions.Tests/Features/Banking/SourceIngestion/StatementProfileFlowRegressionTests.cs",
      "sha256": "66aef6eb6904d0502a0144fe6e67409e6f803ba3e8609567d982e06ed463d73a",
      "lineCount": 324
    },
    "statement_validation_recovery_js": {
      "path": "AtxSolutions/wwwroot/js/banking-statement-validation-recovery.js",
      "sha256": "a01320749cda7523d1df83472ca4e4c968f75a7a8a8e4c13e935b18af592857f",
      "lineCount": 394
    },
    "banking_content_extraction_service": {
      "path": "AtxSolutions/Features/Banking/Services/SourceIngestion/BankingContentExtractionService.cs",
      "sha256": "7fa33cd8c3bdb1781a4bca945c964b308cb56d5fc543c2201e845644055f2f04",
      "lineCount": 961
    },
    "bank_statement_validation_engine": {
      "path": "AtxSolutions/Features/Banking/Services/SourceIngestion/BankStatementValidationEngine.cs",
      "sha256": "4b5a922e0f7de273905e4f1303fa7b190085866a6b9986f03cc5ed878be9257b",
      "lineCount": 636
    },
    "bank_import_service": {
      "path": "AtxSolutions/Features/Banking/Services/BankImportService.cs",
      "sha256": "f5dac85ea058476cc50210d49f5a35ac795901093c6818e888297c09841c0653",
      "lineCount": 2237
    },
    "import_session_service": {
      "path": "AtxSolutions/Features/Banking/Services/ImportSessionService.cs",
      "sha256": "a88aab76335b1198f6249021b4afbff68f002fe60bbd141d967e307e0b0f42f3",
      "lineCount": 954
    },
    "login_razor": {
      "path": "AtxSolutions/Pages/Login.cshtml",
      "sha256": "ffe69a2c43dcfbfcc64c18ee0dd5705644fac7b9ffcd9e22382b6516e76f0380",
      "lineCount": 458
    },
    "layout_razor": {
      "path": "AtxSolutions/Pages/Shared/_Layout.cshtml",
      "sha256": "77f395745897f3b83d3974009fce717b72fee4ea146f476905d52740c243ce61",
      "lineCount": 4969
    },
    "workspace_menu_js": {
      "path": "AtxSolutions/wwwroot/js/workspace-menu-bar.js",
      "sha256": "3aaf91e465059cd52fecc8df5e5965bb74efa69f62b95172baa2c744de2659f0",
      "lineCount": 128
    },
    "product_inventory_index_razor": {
      "path": "AtxSolutions/Pages/Products/Inventory/Index.cshtml",
      "sha256": "ba639a282fb81494b1f49da0e7f2b06de3e9c1998bbdecfaef87274688153669",
      "lineCount": 203
    },
    "product_inventory_detail_razor": {
      "path": "AtxSolutions/Pages/Products/Inventory/ProductInventory.cshtml",
      "sha256": "650cd56a9e45ba062c4699517bee46516acc4ee4c4c9bdd24906a39047959669",
      "lineCount": 350
    },
    "product_inventory_detail_model": {
      "path": "AtxSolutions/Pages/Products/Inventory/ProductInventory.cshtml.cs",
      "sha256": "77a4d37523a85e28d12e3154cb7f79f1cd326ae97dafcf7c5daa87980bea9b4c",
      "lineCount": 182
    },
    "product_categories_razor": {
      "path": "AtxSolutions/Pages/Products/Categories/Index.cshtml",
      "sha256": "1eae24ae3839db4f53937718772773226c291642058be15a51000fecb1ff2d74",
      "lineCount": 595
    },
    "stock_count_create_razor": {
      "path": "AtxSolutions/Pages/Products/Inventory/Counts/Create.cshtml",
      "sha256": "0042d92c6bb74d1950bc80cd69eca1c902b08ba52ab65deccfefbd310afe2b24",
      "lineCount": 370
    },
    "payroll_reminders_razor": {
      "path": "AtxSolutions/Pages/Payroll/Settings/Reminders.cshtml",
      "sha256": "3387e7e787de01875fc060e446b41c8f65a03110a2001ce606965710a80b38ce",
      "lineCount": 657
    },
    "payroll_reminder_activity_service": {
      "path": "AtxSolutions/Features/Payroll/Services/PayrollReminderActivityQueryService.cs",
      "sha256": "3075cfeae4a35b6dcf6d595d98fc9c1114957d864f96fa804314faf4601b135b",
      "lineCount": 268
    },
    "support_email_polling_service": {
      "path": "AtxSolutions/Services/Support/SupportEmailPollingService.cs",
      "sha256": "b340a0374ec1dda12a7f6f2359b7033b20b299894939569d649f6f6b5f4b90c3",
      "lineCount": 536
    },
    "support_email_resilience_tests": {
      "path": "AtxSolutions.Tests/Services/Support/SupportEmailPollingResilienceSourceContractTests.cs",
      "sha256": "2355d959afcfd74771e1ae5774d9b7f0fd54fed19efb7d8a680976aafe96118e",
      "lineCount": 47
    },
    "ui_closeout_source_tests": {
      "path": "AtxSolutions.Tests/Features/Ui/UiTestingCloseoutSourceContractTests.cs",
      "sha256": "ae7d8901b4ba8ff6e993badd9e49e45e021bf123a19d44a4401e936596bd3515",
      "lineCount": 102
    },
    "unified_email_service": {
      "path": "AtxSolutions/Services/Support/EmailClient/UnifiedEmailService.cs",
      "sha256": "fecb7157bd71f1bec234092d820118ef07439a2100a5a5ca23e13e3378a1c95b",
      "lineCount": 310
    },
    "payment_evidence_index_razor": {
      "path": "AtxSolutions/Pages/Banking/PaymentEvidence/Index.cshtml",
      "sha256": "a23d2c06b3035104c7f00d64cddb6a1dc7b00b34b1c7f4657b15c5184dd73502",
      "lineCount": 1691
    },
    "payment_evidence_index_model": {
      "path": "AtxSolutions/Pages/Banking/PaymentEvidence/Index.cshtml.cs",
      "sha256": "8d18863372d65e21d4dea501663b2d179fabdb1dfeef242562fe16abb40d852a",
      "lineCount": 1141
    },
    "payment_evidence_import_service": {
      "path": "AtxSolutions/Features/Banking/Services/PaymentEvidenceImportService.cs",
      "sha256": "c477d1dc39f12b6703356936c03c6d762f6431ed830005cc09f7e4d73989e4db",
      "lineCount": 2226
    },
    "payment_evidence_profile_model": {
      "path": "AtxSolutions/Features/Banking/Models/PaymentEvidenceImportProfile.cs",
      "sha256": "640a5956c21eefd53ab8cd22b7d365c414dab9ff595304dc034c2cced03f5793",
      "lineCount": 58
    },
    "payment_evidence_mapping_definition": {
      "path": "AtxSolutions/Data/Entities/Dto/Banking/PaymentEvidenceMappingDefinition.cs",
      "sha256": "d653b30f2969664f9ec4dd190ea76c0119ddc4cbd047af62cc2d4050f045bd17",
      "lineCount": 25
    },
    "payment_evidence_batch_razor": {
      "path": "AtxSolutions/Pages/Banking/PaymentEvidence/Batch.cshtml",
      "sha256": "17041c493616d81a44f94cb76e1027e107b96c75e039decb8bff07696ca8c89e",
      "lineCount": 1663
    },
    "payment_evidence_batch_model": {
      "path": "AtxSolutions/Pages/Accounting/Customers/Receipts/Batch.cshtml.cs",
      "sha256": "6b7939dd9ce8703e3466854f75c997750191cfa92c378ad6090a4fa3a57b95c3",
      "lineCount": 1239
    },
    "payment_evidence_batch_configuration": {
      "path": "AtxSolutions/Data/Configurations/Banking/PaymentEvidenceImportBatchConfiguration.cs",
      "sha256": "3161d29e7cb93546e2de04a6549f9b01d3bc1d87809b2ef15fe648295db0abaa",
      "lineCount": 74
    },
    "shared_layout_razor": {
      "path": "AtxSolutions/Pages/Shared/_Layout.cshtml",
      "sha256": "77f395745897f3b83d3974009fce717b72fee4ea146f476905d52740c243ce61",
      "lineCount": 4969
    },
    "workspace_switcher_js": {
      "path": "AtxSolutions/wwwroot/js/workspace-switcher.js",
      "sha256": "65e283c109375844f983dda38fb84f5753cf884c7dbf1f34d0c27bbe52e98dd1",
      "lineCount": 178
    },
    "banking_usage_event_model": {
      "path": "AtxSolutions/Features/Banking/Models/BankingUsageEvent.cs",
      "sha256": "a46f24e7c4129938928bd62493c5372f419d4c13582cfca0eb029b8824c7b851",
      "lineCount": 92
    },
    "banking_usage_contracts": {
      "path": "AtxSolutions/Features/Banking/Services/Usage/BankingUsageContracts.cs",
      "sha256": "e73455432aceef895b70f9e05e6dcb728f54a4c35cd57ffc97d2be5b32185152",
      "lineCount": 56
    },
    "banking_usage_event_service": {
      "path": "AtxSolutions/Features/Banking/Services/Usage/BankingUsageEventService.cs",
      "sha256": "90e333407e330a617ac0255210fa41a7e21e8398a2a5bdf49007dc02ba529eb1",
      "lineCount": 521
    },
    "banking_usage_event_configuration": {
      "path": "AtxSolutions/Data/Configurations/Banking/BankingUsageEventConfiguration.cs",
      "sha256": "75f1360b6b87a5ce323fe663751a457bbc06accf178821565af54e55c695630d",
      "lineCount": 63
    },
    "banking_evidence_artifact_service_d2a": {
      "path": "AtxSolutions/Features/Banking/Services/Artifacts/BankingEvidenceArtifactService.cs",
      "sha256": "9974a576f79466a77e2731bb0c082c375cc004f3787b989b1036d7268193d58a",
      "lineCount": 574
    },
    "payment_evidence_preview_artifact_service": {
      "path": "AtxSolutions/Features/Banking/Services/Artifacts/PaymentEvidencePreviewArtifactService.cs",
      "sha256": "c0144f1382c180e7d837b08ed8a3b9ccd79d4ddedc728c8ff53552dfd7e34cf1",
      "lineCount": 92
    },
    "banking_usage_foundation_schema": {
      "path": "AtxSolutions/Migrations/Manual/20260730_Phase25H_D1A_BankingUsageFoundation_SCHEMA.sql",
      "sha256": "f28408ec1142362fb2b0ac4053a5950f93d660d364d1495f9bd51aa1ffaa07c7",
      "lineCount": 238
    },
    "banking_usage_text_constraint_hotfix": {
      "path": "AtxSolutions/Migrations/Manual/20260731_Phase25H_D2A_BankingUsageTextConstraint_HOTFIX.sql",
      "sha256": "282807a31dd7ad059e7efd799d5b98a53b6c8d3f3a0fac5698577409261cfc75",
      "lineCount": 89
    },
    "banking_usage_text_constraint_verification": {
      "path": "AtxSolutions/Migrations/Manual/20260731_Phase25H_D2A_BankingUsageTextConstraint_VERIFICATION_READ_ONLY.sql",
      "sha256": "f9ab325ee18502314bf943ee848f1e89d70b991ad9e8d104e6a3b822b7201120",
      "lineCount": 38
    },
    "phase25h_d2a_source_contract_tests": {
      "path": "AtxSolutions.Tests/Features/Banking/Phase25HD2AArtifactStorageUsageSourceContractTests.cs",
      "sha256": "9bdf641fab0672fb3b9920e49a254898273bce86bb2b2fa6015f8802439d0a79",
      "lineCount": 179
    },
    "banking_usage_model": {
      "path": "AtxSolutions/Features/Banking/Models/BankingUsageEvent.cs",
      "sha256": "51375d1041aac06536eda8fc7df91394cda114d5266b40824ccd0374870e34cd",
      "lineCount": 158
    },
    "profile_test_artifact_store": {
      "path": "AtxSolutions/Features/Banking/Services/SourceIngestion/BankStatementProfileTestArtifactStore.cs",
      "sha256": "e78e2f5966b7d383e5f2773096c4f2485bd0783e7f2ae6c8e315ea2c0109fd5d",
      "lineCount": 536
    },
    "single_transaction_model": {
      "path": "AtxSolutions/Pages/Banking/Profiles/SingleTransaction.cshtml.cs",
      "sha256": "d4bed8495c82f476a466c39a143d7180b76f8fdbdb4f380c74db7bf2d3de3f24",
      "lineCount": 1154
    },
    "bank_import_source_service": {
      "path": "AtxSolutions/Features/Banking/Services/SourceIngestion/BankImportSourceService.cs",
      "sha256": "0408c09ff29a54418e7fe11d98d91cb0b7b559c69fb2f910e77d263f4ec958ba",
      "lineCount": 1006
    },
    "d2b_source_contract_tests": {
      "path": "AtxSolutions.Tests/Features/Banking/Phase25HD2BProcessingUsageSourceContractTests.cs",
      "sha256": "9ba12feaa2cb1e035b571e93cf65eeda93c851e9b595741562799d9cc62d157e",
      "lineCount": 136
    },
    "extraction_foundation_tests": {
      "path": "AtxSolutions.Tests/Features/Banking/SourceIngestion/BankingContentExtractionFoundationTests.cs",
      "sha256": "17da93917f018cff57faa9e049f88c537ced2235e3649d3f5f0346f4c3d08328",
      "lineCount": 2191
    }
  },
  "statusTaxonomy": {
    "PASS": "Certified acceptance assertions completed successfully.",
    "FAIL": "Certified package and prerequisites passed; ATX violated the source-confirmed acceptance contract.",
    "TEST_INVALID": "Selector, handler, action expectation, test data, runtime-variable wiring, cleanup or package contract is wrong.",
    "BLOCKED": "A required safe prerequisite is absent or intentionally unavailable.",
    "ERROR": "Runner, parser, Robot, Browser, authentication, environment, dependency or reporting failure."
  },
  "actions": [
    {
      "id": "profiles.open-new-statement",
      "area": "Profiles catalogue",
      "route": "/Banking/Profiles?tab=user",
      "purpose": "Open a new tenant Statement Profile workspace.",
      "sourceFile": "AtxSolutions/Pages/Banking/Profiles/Index.cshtml",
      "sourceAnchor": "id=\"newProfileDropdown\"",
      "selector": "#newProfileDropdown then ul[aria-labelledby=\"newProfileDropdown\"] a.dropdown-item[href=\"/Banking/Profiles/Statement\"]:visible",
      "interaction": "Click `#newProfileDropdown`, then resolve exactly one scoped create-menu anchor using `ul[aria-labelledby=\"newProfileDropdown\"] a.dropdown-item[href=\"/Banking/Profiles/Statement\"]:visible`, then click it.",
      "visibleCount": "1 dropdown; exactly 1 scoped Statement create-menu item after opening",
      "handler": "GET /Banking/Profiles/Statement",
      "pageModelMethod": "StatementModel.OnGetAsync",
      "transport": "Full navigation",
      "preconditions": "User tab loaded; manager has profile-management permission.",
      "expectedOutcome": "`.statement-profile-page` visible; `#Form_Id` empty for a new profile.",
      "hazards": "Global `a[href^=\"/Banking/Profiles/Statement\"]` also matches existing profile-card Configure links such as `/Banking/Profiles/Statement?id=<GUID>` and is prohibited.",
      "failureBeforeCertification": "TEST_INVALID",
      "sourceLine": 98,
      "pageModelFile": "AtxSolutions/Pages/Banking/Profiles/Statement.cshtml.cs",
      "pageModelLine": 124
    },
    {
      "id": "profiles.find-exact-user-card",
      "area": "Profiles catalogue",
      "route": "/Banking/Profiles?tab=user",
      "purpose": "Locate exactly one tenant profile by exact displayed name.",
      "sourceFile": "AtxSolutions/Pages/Banking/Profiles/Index.cshtml",
      "sourceAnchor": "<div class=\"bp-profile-card p-3 d-flex flex-column\">",
      "selector": "xpath=//div[contains(@class,'bp-profile-card')][.//h2[normalize-space()='<EXACT_PROFILE_NAME>']]",
      "interaction": "Get count before any action.",
      "visibleCount": "Exactly 1",
      "handler": "None",
      "pageModelMethod": "IndexModel.OnGetAsync",
      "transport": "Read-only",
      "preconditions": "User tab selected.",
      "expectedOutcome": "One exact card. Zero means missing prerequisite; more than one means unsafe duplicate test data.",
      "hazards": "Never use `:has-text()` alone for destructive actions because it permits substring matches.",
      "failureBeforeCertification": "BLOCKED or TEST_INVALID",
      "sourceLine": 226,
      "pageModelFile": "AtxSolutions/Pages/Banking/Profiles/Index.cshtml.cs",
      "pageModelLine": 61
    },
    {
      "id": "profiles.read-card-lifecycle",
      "area": "Profiles catalogue",
      "route": "/Banking/Profiles?tab=user",
      "purpose": "Read the exact profile lifecycle badge without positional guessing.",
      "sourceFile": "AtxSolutions/Pages/Banking/Profiles/Index.cshtml",
      "sourceAnchor": "v@(profile.CurrentVersionNumber) · @profile.LifecycleState",
      "selector": "Structural JS on exact card: direct top row `:scope > .d-flex > span.badge`.",
      "interaction": "Read direct-child lifecycle badge text.",
      "visibleCount": "Exactly 1 lifecycle badge per card",
      "handler": "None",
      "pageModelMethod": "IndexModel.OnGetAsync",
      "transport": "Read-only",
      "preconditions": "Exact card already resolved.",
      "expectedOutcome": "`vN · Draft|Tested|Published|Archived`.",
      "hazards": "The card also contains a `User` scope badge. Never use `span.badge >> nth=1`.",
      "failureBeforeCertification": "TEST_INVALID",
      "sourceLine": 233,
      "pageModelFile": "AtxSolutions/Pages/Banking/Profiles/Index.cshtml.cs",
      "pageModelLine": 61
    },
    {
      "id": "profiles.configure-exact-statement",
      "area": "Profiles catalogue",
      "route": "/Banking/Profiles?tab=user",
      "purpose": "Open the exact Statement Profile by ID.",
      "sourceFile": "AtxSolutions/Pages/Banking/Profiles/Index.cshtml",
      "sourceAnchor": "asp-page=\"/Banking/Profiles/Statement\" asp-route-id=\"@profile.Id\"",
      "selector": "<exact card> >> css=a[href*=\"/Banking/Profiles/Statement\"][href*=\"id=\"]",
      "interaction": "Read the exact scoped anchor href and verify the GUID. Prefer clicking that exact anchor. If direct navigation is necessary, resolve `new URL(href, document.baseURI).href`, verify the resolved origin equals the configured ATX origin, then navigate.",
      "visibleCount": "Exactly 1",
      "handler": "GET /Banking/Profiles/Statement?id=<GUID>",
      "pageModelMethod": "StatementModel.OnGetAsync",
      "transport": "Full navigation",
      "preconditions": "Exact card is a Statement builder profile.",
      "expectedOutcome": "`#Form_Id` equals the card GUID after the exact scoped anchor navigation.",
      "hazards": "The rendered href is normally root-relative, for example `/Banking/Profiles/Statement?id=<GUID>`. Browser `Go To` requires an absolute URL. Never pass a raw href directly to `Go To`, and never open the first Configure link.",
      "failureBeforeCertification": "TEST_INVALID",
      "sourceLine": 242,
      "pageModelFile": "AtxSolutions/Pages/Banking/Profiles/Statement.cshtml.cs",
      "pageModelLine": 124
    },
    {
      "id": "profiles.publish-tested-version",
      "area": "Profiles catalogue",
      "route": "/Banking/Profiles?tab=user",
      "purpose": "Publish a profile already in Tested lifecycle.",
      "sourceFile": "AtxSolutions/Pages/Banking/Profiles/Index.cshtml",
      "sourceAnchor": "asp-page-handler=\"Publish\"",
      "selector": "<exact card> >> css=form[action*=\"handler=Publish\"]:has(input[name=\"profileId\"][value=\"<GUID>\"])",
      "interaction": "Open exact card Actions dropdown; submit exact form.",
      "visibleCount": "Exactly 1 only when lifecycle is Tested",
      "handler": "Publish",
      "pageModelMethod": "IndexModel.OnPostPublishAsync(Guid profileId, bool systemProfile = false)",
      "transport": "Full POST then catalogue redirect",
      "preconditions": "Exact lifecycle is Tested; profile ID and tenant ownership confirmed.",
      "expectedOutcome": "Exact card lifecycle becomes Published.",
      "hazards": "Action is absent outside Tested lifecycle. Missing action is BLOCKED, not application FAIL.",
      "failureBeforeCertification": "BLOCKED or TEST_INVALID",
      "sourceLine": 266,
      "pageModelFile": "AtxSolutions/Pages/Banking/Profiles/Index.cshtml.cs",
      "pageModelLine": 102
    },
    {
      "id": "profiles.delete-never-published-draft",
      "area": "Profiles catalogue",
      "route": "/Banking/Profiles?tab=user",
      "purpose": "Delete an exact disposable never-published, unreferenced Draft.",
      "sourceFile": "AtxSolutions/Pages/Banking/Profiles/Index.cshtml",
      "sourceAnchor": "asp-page-handler=\"Delete\"",
      "selector": "<exact card> >> css=form[action*=\"handler=Delete\"]:has(input[name=\"profileId\"][value=\"<GUID>\"])",
      "interaction": "Open exact card Actions dropdown; remove `onsubmit` only after exact-ID and Draft checks; submit.",
      "visibleCount": "Exactly 1 only when `profile.CanRemove`",
      "handler": "Delete",
      "pageModelMethod": "IndexModel.OnPostDeleteAsync(Guid profileId)",
      "transport": "Full POST then catalogue redirect",
      "preconditions": "Exact name, exact GUID, non-Published state, `CanRemove` action visible.",
      "expectedOutcome": "Exact card absent.",
      "hazards": "Never delete by name alone. Published/protected profiles intentionally have no delete form.",
      "failureBeforeCertification": "BLOCKED or TEST_INVALID",
      "sourceLine": 278,
      "pageModelFile": "AtxSolutions/Pages/Banking/Profiles/Index.cshtml.cs",
      "pageModelLine": 87
    },
    {
      "id": "statement.switch-advanced",
      "area": "Statement Profile",
      "route": "/Banking/Profiles/Statement",
      "purpose": "Switch the workspace into Advanced mode.",
      "sourceFile": "AtxSolutions/Pages/Banking/Profiles/Statement.cshtml",
      "sourceAnchor": "data-profile-mode-button=\"advanced\"",
      "selector": "button[data-profile-mode-button=\"advanced\"]:visible",
      "interaction": "After readiness, resolve exactly one visible `button[data-profile-mode-button=\"advanced\"]`, click once, and verify `.statement-profile-page[data-profile-mode=\"advanced\"]`.",
      "visibleCount": "Exactly 1",
      "handler": "Client-side only",
      "pageModelMethod": "None",
      "transport": "No navigation; localStorage + DOM state",
      "preconditions": "Statement page readiness gate passed: `typeof window.__atxStatementProfileCleanup === 'function'`.",
      "expectedOutcome": "`data-profile-mode=\"advanced\"`.",
      "hazards": "The button is visible before its click listener is necessarily bound. A physical click before the source-confirmed readiness marker can be ignored while Browser still reports PASS.",
      "failureBeforeCertification": "TEST_INVALID until readiness is proven",
      "sourceLine": 1889,
      "pageModelFile": null,
      "pageModelLine": null
    },
    {
      "id": "statement.profile-id",
      "area": "Statement Profile",
      "route": "/Banking/Profiles/Statement",
      "purpose": "Read the exact persisted profile ID.",
      "sourceFile": "AtxSolutions/Pages/Banking/Profiles/Statement.cshtml",
      "sourceAnchor": "<input asp-for=\"Form.Id\" type=\"hidden\" />",
      "selector": "#Form_Id",
      "interaction": "Get Property `value`.",
      "visibleCount": "Exactly 1 attached element",
      "handler": "None",
      "pageModelMethod": "Form.Id binding",
      "transport": "Read-only",
      "preconditions": "Workspace loaded.",
      "expectedOutcome": "Empty before first durable save; GUID after save.",
      "hazards": "The header Cancel/Reset forms also contain hidden `name=\"Form.Id\"`. Never use `input[name=\"Form.Id\"]`.",
      "failureBeforeCertification": "TEST_INVALID",
      "sourceLine": 2006,
      "pageModelFile": null,
      "pageModelLine": null
    },
    {
      "id": "statement.profile-name",
      "area": "Statement Profile",
      "route": "/Banking/Profiles/Statement#profile-details",
      "purpose": "Set/read the visible profile name.",
      "sourceFile": "AtxSolutions/Pages/Banking/Profiles/Statement.cshtml",
      "sourceAnchor": "<input asp-for=\"Form.ProfileName\"",
      "selector": "#Form_ProfileName",
      "interaction": "Fill Text; verify with Get Property `value`.",
      "visibleCount": "Exactly 1",
      "handler": "Form binding",
      "pageModelMethod": "PdfProfileFormInput.ProfileName",
      "transport": "Client state until submit",
      "preconditions": "`#profile-details` active.",
      "expectedOutcome": "Live value equals exact name.",
      "hazards": "Reset ABSA has a separate hidden `name=\"Form.ProfileName\"`. Never use a broad name selector.",
      "failureBeforeCertification": "TEST_INVALID",
      "sourceLine": 2230,
      "pageModelFile": null,
      "pageModelLine": null
    },
    {
      "id": "statement.bank-name",
      "area": "Statement Profile",
      "route": "/Banking/Profiles/Statement#profile-details",
      "purpose": "Set/read source or issuer name.",
      "sourceFile": "AtxSolutions/Pages/Banking/Profiles/Statement.cshtml",
      "sourceAnchor": "<input asp-for=\"Form.BankName\"",
      "selector": "#Form_BankName",
      "interaction": "Fill Text; Get Property `value`.",
      "visibleCount": "Exactly 1 in Advanced mode",
      "handler": "Form binding",
      "pageModelMethod": "PdfProfileFormInput.BankName",
      "transport": "Client state until submit",
      "preconditions": "Advanced mode; Profile Info active.",
      "expectedOutcome": "Value retained.",
      "hazards": "Advanced-only control; hidden in Basic mode.",
      "failureBeforeCertification": "TEST_INVALID",
      "sourceLine": 2236,
      "pageModelFile": null,
      "pageModelLine": null
    },
    {
      "id": "statement.statement-type",
      "area": "Statement Profile",
      "route": "/Banking/Profiles/Statement#profile-details",
      "purpose": "Set/read document type.",
      "sourceFile": "AtxSolutions/Pages/Banking/Profiles/Statement.cshtml",
      "sourceAnchor": "<input asp-for=\"Form.StatementType\"",
      "selector": "#Form_StatementType",
      "interaction": "Fill Text; Get Property `value`.",
      "visibleCount": "Exactly 1 in Advanced mode",
      "handler": "Form binding",
      "pageModelMethod": "PdfProfileFormInput.StatementType",
      "transport": "Client state until submit",
      "preconditions": "Advanced mode.",
      "expectedOutcome": "Value retained.",
      "hazards": "Advanced-only control.",
      "failureBeforeCertification": "TEST_INVALID",
      "sourceLine": 2240,
      "pageModelFile": null,
      "pageModelLine": null
    },
    {
      "id": "statement.currency",
      "area": "Statement Profile",
      "route": "/Banking/Profiles/Statement#profile-details",
      "purpose": "Select profile currency.",
      "sourceFile": "AtxSolutions/Pages/Banking/Profiles/Statement.cshtml",
      "sourceAnchor": "<select asp-for=\"Form.CurrencyCode\"",
      "selector": "#Form_CurrencyCode",
      "interaction": "Select Options By `value` (for example `ZAR`); never Fill Text.",
      "visibleCount": "Exactly 1",
      "handler": "Form binding",
      "pageModelMethod": "PdfProfileFormInput.CurrencyCode",
      "transport": "Client state until submit",
      "preconditions": "Profile Info active.",
      "expectedOutcome": "Selected value equals requested code.",
      "hazards": "This is a `<select>`, not a text input.",
      "failureBeforeCertification": "TEST_INVALID",
      "sourceLine": 2244,
      "pageModelFile": null,
      "pageModelLine": null
    },
    {
      "id": "statement.choose-image-source",
      "area": "Statement Profile",
      "route": "/Banking/Profiles/Statement#source-sample",
      "purpose": "Select screenshot/image evidence.",
      "sourceFile": "AtxSolutions/Pages/Banking/Profiles/Statement.cshtml",
      "sourceAnchor": "data-source-type=\"Image\"",
      "selector": "button.statement-source-card[data-source-type=\"Image\"]:visible",
      "interaction": "Click; verify `#SampleSourceType` and `#FormImageType` properties.",
      "visibleCount": "Exactly 1",
      "handler": "Client-side `selectSourceType(type, applyRecommendation)`",
      "pageModelMethod": "ResolveSampleSourceType / form binding",
      "transport": "No navigation",
      "preconditions": "Source & Sample section active.",
      "expectedOutcome": "`#SampleSourceType=Image`, `#FormImageType=Screenshot`, recommended OCR mode Force.",
      "hazards": "Clicking the card triggers JS side effects; setting only the hidden field does not exercise the UI contract.",
      "failureBeforeCertification": "TEST_INVALID",
      "sourceLine": 2316,
      "pageModelFile": null,
      "pageModelLine": null
    },
    {
      "id": "statement.sample-file",
      "area": "Statement Profile",
      "route": "/Banking/Profiles/Statement#source-sample",
      "purpose": "Stage representative sample evidence.",
      "sourceFile": "AtxSolutions/Pages/Banking/Profiles/Statement.cshtml",
      "sourceAnchor": "id=\"SampleEvidence\"",
      "selector": "#SampleEvidence",
      "interaction": "Upload File By Selector; verify `files.length` and filename.",
      "visibleCount": "Exactly 1",
      "handler": "Multipart form binding",
      "pageModelMethod": "SampleEvidence binding",
      "transport": "Client-side until Prepare/Test/Rerun submit",
      "preconditions": "Selected source card permits file extension.",
      "expectedOutcome": "One selected file; cache not yet durable until a consuming handler runs.",
      "hazards": "The selected File object is lost after an AJAX page replacement unless the JS restore contract succeeds.",
      "failureBeforeCertification": "TEST_INVALID",
      "sourceLine": 2345,
      "pageModelFile": null,
      "pageModelLine": null
    },
    {
      "id": "statement.force-ocr",
      "area": "Statement Profile",
      "route": "/Banking/Profiles/Statement#extraction-method",
      "purpose": "Select OCR-only extraction mode.",
      "sourceFile": "AtxSolutions/Pages/Banking/Profiles/Statement.cshtml",
      "sourceAnchor": "id=\"OcrModeForce\"",
      "selector": "#OcrModeForce",
      "interaction": "Click associated mode card or Check; verify `checked=true`.",
      "visibleCount": "Exactly 1 attached radio",
      "handler": "Client-side radio change",
      "pageModelMethod": "PdfProfileFormInput.OcrMode",
      "transport": "Client state until submit",
      "preconditions": "Advanced mode for direct section navigation.",
      "expectedOutcome": "OcrMode value `Force`.",
      "hazards": "The radio is visually hidden; clicking the label card is the user-equivalent action.",
      "failureBeforeCertification": "TEST_INVALID",
      "sourceLine": 2484,
      "pageModelFile": null,
      "pageModelLine": null
    },
    {
      "id": "statement.image-type",
      "area": "Statement Profile",
      "route": "/Banking/Profiles/Statement#image-source",
      "purpose": "Set expected image type.",
      "sourceFile": "AtxSolutions/Pages/Banking/Profiles/Statement.cshtml",
      "sourceAnchor": "id=\"FormImageType\"",
      "selector": "#FormImageType",
      "interaction": "Select Options By `value=Screenshot`.",
      "visibleCount": "Exactly 1",
      "handler": "Form binding",
      "pageModelMethod": "PdfProfileFormInput.ImageType",
      "transport": "Client state until submit",
      "preconditions": "Advanced mode; Image Source active.",
      "expectedOutcome": "Selected value `Screenshot`.",
      "hazards": "This is a `<select>`.",
      "failureBeforeCertification": "TEST_INVALID",
      "sourceLine": 2518,
      "pageModelFile": null,
      "pageModelLine": null
    },
    {
      "id": "statement.ocr-dpi",
      "area": "Statement Profile",
      "route": "/Banking/Profiles/Statement#image-source",
      "purpose": "Set OCR/render DPI.",
      "sourceFile": "AtxSolutions/Pages/Banking/Profiles/Statement.cshtml",
      "sourceAnchor": "<select asp-for=\"Form.OcrRenderDpi\"",
      "selector": "#Form_OcrRenderDpi",
      "interaction": "Select Options By `value=300`.",
      "visibleCount": "Exactly 1",
      "handler": "Form binding",
      "pageModelMethod": "PdfProfileFormInput.OcrRenderDpi",
      "transport": "Client state until submit",
      "preconditions": "Image Source active.",
      "expectedOutcome": "Selected value `300`.",
      "hazards": "This is a `<select>`. `Fill Text` is invalid.",
      "failureBeforeCertification": "TEST_INVALID",
      "sourceLine": 2529,
      "pageModelFile": null,
      "pageModelLine": null
    },
    {
      "id": "statement.ocr-language",
      "area": "Statement Profile",
      "route": "/Banking/Profiles/Statement#image-source",
      "purpose": "Select installed OCR language.",
      "sourceFile": "AtxSolutions/Pages/Banking/Profiles/Statement.cshtml",
      "sourceAnchor": "<select asp-for=\"Form.OcrLanguage\"",
      "selector": "#Form_OcrLanguage",
      "interaction": "Read available options; select exact installed value, preferably `eng` only when present.",
      "visibleCount": "Exactly 1",
      "handler": "Form binding",
      "pageModelMethod": "DiscoverInstalledOcrLanguages / PdfProfileFormInput.OcrLanguage",
      "transport": "Client state until submit",
      "preconditions": "At least one installed language option.",
      "expectedOutcome": "Selected value is one of live options.",
      "hazards": "Do not assume `eng` exists without runtime option preflight.",
      "failureBeforeCertification": "BLOCKED or TEST_INVALID",
      "sourceLine": 2556,
      "pageModelFile": null,
      "pageModelLine": null
    },
    {
      "id": "statement.ocr-provider",
      "area": "Statement Profile",
      "route": "/Banking/Profiles/Statement#ocr-engine",
      "purpose": "Select an installed OCR provider.",
      "sourceFile": "AtxSolutions/Pages/Banking/Profiles/Statement.cshtml",
      "sourceAnchor": "<select asp-for=\"Form.OcrProviderKey\"",
      "selector": "#Form_OcrProviderKey",
      "interaction": "Verify enabled; read options; select exact preferred provider only if present.",
      "visibleCount": "Exactly 1",
      "handler": "Form binding",
      "pageModelMethod": "LoadPermissionsAsync builds `OcrProviders`",
      "transport": "Client state until submit",
      "preconditions": "Provider control enabled and at least one non-empty option.",
      "expectedOutcome": "Selected value exists in the live options.",
      "hazards": "No provider is a BLOCKED environment prerequisite, not application FAIL.",
      "failureBeforeCertification": "BLOCKED",
      "sourceLine": 2713,
      "pageModelFile": null,
      "pageModelLine": null
    },
    {
      "id": "statement.prepare-image",
      "area": "Statement Profile",
      "route": "/Banking/Profiles/Statement#image-preparation",
      "purpose": "Prepare or refresh the pre-OCR preview without running extraction.",
      "sourceFile": "AtxSolutions/Pages/Banking/Profiles/Statement.cshtml",
      "sourceAnchor": "asp-page-handler=\"PrepareImage\"",
      "selector": "#image-preparation button[formaction*=\"handler=PrepareImage\"]:visible",
      "interaction": "Submit AJAX; validate the replacement page and client-controller readiness; verify the scoped SampleCacheToken; open Regions & Anchors; then wait for #ocrPreparedImage to be visible and fully loaded (complete=true, naturalWidth>0, naturalHeight>0).",
      "visibleCount": "Exactly 1 in active Image Preparation section",
      "handler": "PrepareImage",
      "pageModelMethod": "StatementModel.OnPostPrepareImageAsync",
      "transport": "AJAX POST with `X-ATX-Profile-Action:true`; page fragment replacement",
      "preconditions": "Image sample selected or cached; form values valid for preparation.",
      "expectedOutcome": "Prepared preview token exists and the processed image resource becomes visible and fully loaded; OCR/test counters remain unchanged.",
      "hazards": "Fragment replacement can complete before the prepared image resource loads. An immediate :visible count is TEST_INVALID. There is another PrepareImage button in OCR Input Preview; scope to the active section.",
      "failureBeforeCertification": "TEST_INVALID until response, token, section visibility and bounded image-load readiness checks pass",
      "sourceLine": 2685,
      "pageModelFile": "AtxSolutions/Pages/Banking/Profiles/Statement.cshtml.cs",
      "pageModelLine": 213
    },
    {
      "id": "statement.clear-sample",
      "area": "Statement Profile",
      "route": "/Banking/Profiles/Statement#image-preparation",
      "purpose": "Detach the temporary profile sample.",
      "sourceFile": "AtxSolutions/Pages/Banking/Profiles/Statement.cshtml",
      "sourceAnchor": "asp-page-handler=\"ClearSample\"",
      "selector": "#image-preparation button[formaction*=\"handler=ClearSample\"]:visible",
      "interaction": "Submit AJAX; verify token empty, file input empty, clear action absent/disabled and workspace no longer shows sample.",
      "visibleCount": "Exactly 1 only when a temporary sample exists",
      "handler": "ClearSample",
      "pageModelMethod": "StatementModel.OnPostClearSampleAsync",
      "transport": "AJAX POST and fragment replacement",
      "preconditions": "Temporary sample exists.",
      "expectedOutcome": "Logical sample detachment; no claim of immediate physical artifact deletion.",
      "hazards": "Button absence when no sample is correct.",
      "failureBeforeCertification": "BLOCKED or TEST_INVALID",
      "sourceLine": 2683,
      "pageModelFile": "AtxSolutions/Pages/Banking/Profiles/Statement.cshtml.cs",
      "pageModelLine": 250
    },
    {
      "id": "statement.run-test",
      "area": "Statement Profile",
      "route": "/Banking/Profiles/Statement#test-results",
      "purpose": "Run the representative extraction test.",
      "sourceFile": "AtxSolutions/Pages/Banking/Profiles/Statement.cshtml",
      "sourceAnchor": "asp-page-handler=\"Test\"",
      "selector": "#test-results button[formaction*=\"handler=Test\"]:visible",
      "interaction": "Submit AJAX; parse response before waiting for result cards.",
      "visibleCount": "Exactly 1 when no cached extraction exists",
      "handler": "Test",
      "pageModelMethod": "StatementModel.OnPostTestAsync -> RunTestExtractionAsync",
      "transport": "AJAX POST and fragment replacement",
      "preconditions": "CanSave; required profile fields; sample selected/cached; provider available when OCR enabled.",
      "expectedOutcome": "TestResult and cache token rendered; result state, rows, warnings and acceptance decision recorded.",
      "hazards": "When cached extraction exists, the visible primary action may be RerunExtraction instead.",
      "failureBeforeCertification": "BLOCKED or TEST_INVALID until preconditions/action identity verified",
      "sourceLine": 3429,
      "pageModelFile": "AtxSolutions/Pages/Banking/Profiles/Statement.cshtml.cs",
      "pageModelLine": 362
    },
    {
      "id": "statement.rerun-extraction",
      "area": "Statement Profile",
      "route": "/Banking/Profiles/Statement#test-results",
      "purpose": "Rerun provider extraction after extraction-affecting changes.",
      "sourceFile": "AtxSolutions/Pages/Banking/Profiles/Statement.cshtml",
      "sourceAnchor": "asp-page-handler=\"RerunExtraction\"",
      "selector": "#test-results button[formaction*=\"handler=RerunExtraction\"]:visible",
      "interaction": "Count visible matches in active branch; click the intended primary or menu action.",
      "visibleCount": "At least 1 in cached/tested state; scope to specific action group if more than 1",
      "handler": "RerunExtraction",
      "pageModelMethod": "StatementModel.OnPostRerunExtractionAsync",
      "transport": "AJAX POST and fragment replacement",
      "preconditions": "Cached sample exists; CanSave.",
      "expectedOutcome": "Extraction reruns and cache fingerprints/counters update.",
      "hazards": "The handler appears in multiple Razor branches and dropdowns. Never assume global uniqueness.",
      "failureBeforeCertification": "TEST_INVALID",
      "sourceLine": 3423,
      "pageModelFile": "AtxSolutions/Pages/Banking/Profiles/Statement.cshtml.cs",
      "pageModelLine": 365
    },
    {
      "id": "statement.remap-validate",
      "area": "Statement Profile",
      "route": "/Banking/Profiles/Statement#test-results",
      "purpose": "Remap cached geometry without rerunning OCR.",
      "sourceFile": "AtxSolutions/Pages/Banking/Profiles/Statement.cshtml",
      "sourceAnchor": "asp-page-handler=\"Remap\"",
      "selector": "#test-results button[formaction*=\"handler=Remap\"]:visible",
      "interaction": "Verify enabled and `testLab.CanRemap`; submit AJAX.",
      "visibleCount": "1 or more depending active result branch; scope to desired action group",
      "handler": "Remap",
      "pageModelMethod": "StatementModel.OnPostRemapAsync",
      "transport": "AJAX POST and fragment replacement",
      "preconditions": "Cached extraction current; interpretation/mapping changed; remap allowed.",
      "expectedOutcome": "Remap counter increments; extraction counter does not.",
      "hazards": "Disabled Remap is a prerequisite state, not application failure.",
      "failureBeforeCertification": "BLOCKED or TEST_INVALID",
      "sourceLine": 3449,
      "pageModelFile": "AtxSolutions/Pages/Banking/Profiles/Statement.cshtml.cs",
      "pageModelLine": 386
    },
    {
      "id": "statement.save-draft-continue",
      "area": "Statement Profile",
      "route": "/Banking/Profiles/Statement#save-profile",
      "purpose": "Save a fully valid Draft and remain in the workspace.",
      "sourceFile": "AtxSolutions/Pages/Banking/Profiles/Statement.cshtml",
      "sourceAnchor": "data-save-draft",
      "selector": "#save-profile button[data-save-draft]:visible",
      "interaction": "Open `#save-profile .statement-save-more-actions` dropdown; submit AJAX; inspect validation summary and returned `#Form_Id`.",
      "visibleCount": "Exactly 1 after opening the scoped dropdown",
      "handler": "Save",
      "pageModelMethod": "StatementModel.OnPostSaveAsync",
      "transport": "AJAX POST when `data-profile-ajax`; returns Page for workspace requests",
      "preconditions": "`ValidateProfileForm()` must pass.",
      "expectedOutcome": "Draft saved; exact `#Form_Id` populated; workspace remains.",
      "hazards": "This is NOT the permissive incomplete-Draft action. Never expect SaveAndExit semantics.",
      "failureBeforeCertification": "TEST_INVALID if incomplete form was intentionally used",
      "sourceLine": 3839,
      "pageModelFile": "AtxSolutions/Pages/Banking/Profiles/Statement.cshtml.cs",
      "pageModelLine": 436
    },
    {
      "id": "statement.save-draft-exit",
      "area": "Statement Profile",
      "route": "/Banking/Profiles/Statement",
      "purpose": "Permissively save an incomplete Draft and return to catalogue.",
      "sourceFile": "AtxSolutions/Pages/Banking/Profiles/Statement.cshtml",
      "sourceAnchor": "data-visible-save-and-exit",
      "selector": "Canonical desktop interaction: #save-profile .statement-primary-save-actions button[data-visible-save-and-exit]:visible",
      "interaction": "Desktop: assert one canonical primary action and one footer equivalent inside `#save-profile`; click only the canonical primary action. Header and mobile sticky variants are mapped separately. Verify every variant posts `SaveAndExit`.",
      "visibleCount": "Desktop Save section: 2 visible inside `#save-profile` (primary save card + section footer). Header may add one further visible page-level action. Mobile: sticky action replaces desktop/header visibility according to CSS.",
      "handler": "SaveAndExit",
      "pageModelMethod": "StatementModel.OnPostSaveAndExitAsync",
      "transport": "Full POST and redirect to `/Banking/Profiles?tab=user|system`",
      "preconditions": "CanSave. Full profile validation is intentionally not required.",
      "expectedOutcome": "The canonical primary action posts `SaveAndExit`, invokes `OnPostSaveAndExitAsync`, and returns to the exact profile catalogue state.",
      "hazards": "The action is intentionally repeated: page header, primary Save card, Save-section footer and mobile sticky actions. `#save-profile button[data-visible-save-and-exit]:visible` returns 2 on the certified desktop viewport and must not be asserted as unique.",
      "failureBeforeCertification": "TEST_INVALID",
      "sourceLine": 1895,
      "pageModelFile": "AtxSolutions/Pages/Banking/Profiles/Statement.cshtml.cs",
      "pageModelLine": 481,
      "renderLocations": [
        {
          "id": "header",
          "selector": "button.statement-save-exit-header[data-visible-save-and-exit]:visible",
          "viewport": "desktop/tablet above mobile breakpoint",
          "handler": "SaveAndExit"
        },
        {
          "id": "save-primary",
          "selector": "#save-profile .statement-primary-save-actions button[data-visible-save-and-exit]:visible",
          "viewport": "desktop canonical interaction",
          "handler": "SaveAndExit"
        },
        {
          "id": "save-footer",
          "selector": "#save-profile .statement-section-footer button[data-visible-save-and-exit]:visible",
          "viewport": "desktop equivalent",
          "handler": "SaveAndExit"
        },
        {
          "id": "mobile-sticky",
          "selector": ".statement-mobile-sticky-actions button[data-visible-save-and-exit]:visible",
          "viewport": "mobile only",
          "handler": "SaveAndExit"
        }
      ]
    },
    {
      "id": "statement.save-draft-publish",
      "area": "Statement Profile",
      "route": "/Banking/Profiles/Statement#test-results",
      "purpose": "Save and publish the exact reviewed cached test result.",
      "sourceFile": "AtxSolutions/Pages/Banking/Profiles/Statement.cshtml",
      "sourceAnchor": "asp-page-handler=\"SaveDraftAndPublish\"",
      "selector": "#test-results button[formaction*=\"handler=SaveDraftAndPublish\"]:visible",
      "interaction": "Verify exact cached test current/non-blocking; submit AJAX action; follow redirect/catalogue outcome.",
      "visibleCount": "Exactly 1 in the active Test Results branch",
      "handler": "SaveDraftAndPublish",
      "pageModelMethod": "StatementModel.OnPostSaveDraftAndPublishAsync",
      "transport": "AJAX fetch can receive redirect; server publishes exact tested version and redirects",
      "preconditions": "ValidateProfileForm passes; current cached test exists; extraction and interpretation fingerprints current; no blocking/rejected outcome.",
      "expectedOutcome": "Exact version Published and selectable for imports.",
      "hazards": "Handler never reruns extraction. Publishing without a current cache must remain blocked.",
      "failureBeforeCertification": "BLOCKED or application FAIL only after all cache prerequisites certified",
      "sourceLine": 3798,
      "pageModelFile": "AtxSolutions/Pages/Banking/Profiles/Statement.cshtml.cs",
      "pageModelLine": 538
    },
    {
      "id": "statement.cancel",
      "area": "Statement Profile",
      "route": "/Banking/Profiles/Statement",
      "purpose": "Leave the workspace without deleting a persisted profile.",
      "sourceFile": "AtxSolutions/Pages/Banking/Profiles/Statement.cshtml",
      "sourceAnchor": "asp-page-handler=\"Cancel\"",
      "selector": ".statement-header-meta form[action*=\"handler=Cancel\"] [data-cancel-profile]:visible",
      "interaction": "Handle unsaved-change confirmation; submit.",
      "visibleCount": "Exactly 1 header Cancel on desktop",
      "handler": "Cancel",
      "pageModelMethod": "StatementModel.OnPostCancelAsync",
      "transport": "Full POST and catalogue redirect",
      "preconditions": "Workspace loaded.",
      "expectedOutcome": "Returns to catalogue; temporary test-store token removed; persisted Draft is not deleted.",
      "hazards": "Cancel is intentionally non-destructive. Do not assert Draft deletion.",
      "failureBeforeCertification": "TEST_INVALID",
      "sourceLine": 1899,
      "pageModelFile": "AtxSolutions/Pages/Banking/Profiles/Statement.cshtml.cs",
      "pageModelLine": 678
    },
    {
      "id": "statement.reset-absa",
      "area": "Statement Profile",
      "route": "/Banking/Profiles/Statement",
      "purpose": "Load default ABSA rules into the current form.",
      "sourceFile": "AtxSolutions/Pages/Banking/Profiles/Statement.cshtml",
      "sourceAnchor": "asp-page-handler=\"ResetAbsa\"",
      "selector": ".statement-header-meta form[action*=\"handler=ResetAbsa\"]",
      "interaction": "Open overflow dropdown and submit exact form, or submit exact form after confirming ID/name transport.",
      "visibleCount": "Exactly 1 form",
      "handler": "ResetAbsa",
      "pageModelMethod": "StatementModel.OnPostResetAbsaAsync",
      "transport": "AJAX POST and fragment replacement",
      "preconditions": "Correct profile ID/name preserved.",
      "expectedOutcome": "Default rules loaded; profile ID/name retained.",
      "hazards": "This separate form contains hidden `Form.Id` and `Form.ProfileName`, causing broad selector duplicates.",
      "failureBeforeCertification": "TEST_INVALID",
      "sourceLine": 1906,
      "pageModelFile": "AtxSolutions/Pages/Banking/Profiles/Statement.cshtml.cs",
      "pageModelLine": 860
    },
    {
      "id": "statement.import-json",
      "area": "Statement Profile",
      "route": "/Banking/Profiles/Statement#save-profile",
      "purpose": "Load exported settings JSON into the form for review.",
      "sourceFile": "AtxSolutions/Pages/Banking/Profiles/Statement.cshtml",
      "sourceAnchor": "asp-page-handler=\"ImportJson\"",
      "selector": "#profileJsonTools button[formaction*=\"handler=ImportJson\"]:visible",
      "interaction": "Open accordion; fill exact `#ImportProfileJson`; submit AJAX; verify exact visible form properties, not page text.",
      "visibleCount": "Exactly 1 after accordion opened",
      "handler": "ImportJson",
      "pageModelMethod": "StatementModel.OnPostImportJsonAsync",
      "transport": "AJAX POST and fragment replacement",
      "preconditions": "Advanced mode; valid exported JSON.",
      "expectedOutcome": "Server Form is rebuilt from JSON and returned for review; not saved automatically.",
      "hazards": "ModelState can preserve posted visible values over server Form values. JSON import needs its own focused contract and must not be used as hidden setup for unrelated tests.",
      "failureBeforeCertification": "TEST_INVALID",
      "sourceLine": 3878,
      "pageModelFile": "AtxSolutions/Pages/Banking/Profiles/Statement.cshtml.cs",
      "pageModelLine": 799
    },
    {
      "id": "imports.current-session",
      "area": "Guided Import",
      "route": "/Banking/Imports?activeTab=guided",
      "purpose": "Classify any active session before navigating or mutating.",
      "sourceFile": "AtxSolutions/Pages/Banking/Imports.cshtml",
      "sourceAnchor": "window.__importSession",
      "selector": "Evaluate `window.__importSession`.",
      "interaction": "Read and schema-validate `window.__importSession` using the exact camelCase properties from `SerializeSessionState`: id, step, status, selectedProfileId, selectedBankAccountId, originalFileName, storedFileName, hasPersistedFile, hasOwnerScopedArtifact, autoDetectResultJson, columnMappingJson, importResultBatchId, updatedAt, hasPreview and hasValidation.",
      "visibleCount": "N/A",
      "handler": "OnGet data",
      "pageModelMethod": "ImportsModel.OnGetAsync",
      "transport": "Read-only",
      "preconditions": "Page loaded.",
      "expectedOutcome": "No session, or one schema-valid owned session whose exact ID, step, selections, file/artifact flags and preview/validation flags are fully classified before mutation.",
      "hazards": "An active session overrides a requested `currentStep` query parameter. The serialized workflow property is `step`, not `currentStep` or `CurrentStep`. Never use a null-coalescing default that turns a missing property into a false application failure.",
      "failureBeforeCertification": "TEST_INVALID or BLOCKED",
      "sourceLine": 1855,
      "pageModelFile": "AtxSolutions/Pages/Banking/Imports.cshtml.cs",
      "pageModelLine": 244
    },
    {
      "id": "imports.select-bank-account",
      "area": "Guided Import",
      "route": "/Banking/Imports?activeTab=guided&currentStep=1",
      "purpose": "Select the exact protected test bank account.",
      "sourceFile": "AtxSolutions/Pages/Banking/Imports.cshtml",
      "sourceAnchor": "id=\"guidedBankAccount\"",
      "selector": "#guidedBankAccount",
      "interaction": "Resolve option by exact bank-name prefix and capture option value; select by value.",
      "visibleCount": "Exactly 1 select; exactly 1 matching option",
      "handler": "StartSession form binding",
      "pageModelMethod": "OnPostStartSessionAsync(Guid profileId, Guid bankAccountId)",
      "transport": "Client state until POST",
      "preconditions": "Step 1 visible; account active and tenant-owned.",
      "expectedOutcome": "Selected option value is exact account GUID.",
      "hazards": "Option text is `Bank name — account number`, not exactly the bank name.",
      "failureBeforeCertification": "BLOCKED or TEST_INVALID",
      "sourceLine": 578,
      "pageModelFile": "AtxSolutions/Pages/Banking/Imports.cshtml.cs",
      "pageModelLine": 490,
      "robotBindings": [
        {
          "keyword": "Create Exact Guided Import Session",
          "requiredPatterns": [
            "xpath=//select[@id='guidedBankAccount']/option[starts-with(normalize-space(.),'${TARGET_ACCOUNT}')]",
            "Select Options By    css=#guidedBankAccount    value    ${account_id}"
          ]
        }
      ]
    },
    {
      "id": "imports.select-profile",
      "area": "Guided Import",
      "route": "/Banking/Imports?activeTab=guided&currentStep=1",
      "purpose": "Select the exact active Published profile from the Guided Import control.",
      "sourceFile": "AtxSolutions/Pages/Banking/Imports.cshtml",
      "sourceAnchor": "id=\"guidedProfile\"",
      "selector": "#guidedProfile",
      "interaction": "Use the native select control as the authority: verify the target label is present in the select text, select by exact label, then read the selected option's own value and data-profile-scope. Do not locate hidden option elements with XPath and do not derive a GUID from another page.",
      "visibleCount": "Exactly 1 #guidedProfile control; native selection resolves exactly one exact label.",
      "handler": "StartSession form binding",
      "pageModelMethod": "OnPostStartSessionAsync",
      "transport": "Client state until POST",
      "preconditions": "Step 1 visible; exact active Published user-profile option exists in the current workspace.",
      "expectedOutcome": "The exact Guided Import option is selected using its own submitted value; text, scope and value remain consistent.",
      "hazards": "Option elements are non-visual transport nodes and XPath cardinality against them has produced false negatives. Use Select Options By label on #guidedProfile, then verify value, selected text and user scope. Never infer a value from another page.",
      "failureBeforeCertification": "BLOCKED only when the exact label is genuinely absent from the server-rendered select text; TEST_INVALID for XPath/hidden-option cardinality or cross-page ID assumptions; FAIL only after native selection contradicts StartSession.",
      "sourceLine": 593,
      "pageModelFile": "AtxSolutions/Pages/Banking/Imports.cshtml.cs",
      "pageModelLine": 490,
      "robotBindings": [
        {
          "keyword": "Create Exact Guided Import Session",
          "requiredPatterns": [
            "Get Text    css=#guidedProfile",
            "Select Options By    css=#guidedProfile    label    ${TARGET_PROFILE}",
            "Get Property    css=#guidedProfile    value",
            "Get Attribute    css=#guidedProfile option:checked    data-profile-scope"
          ],
          "forbiddenPatterns": [
            "xpath=//select[@id='guidedProfile']/option",
            "Evaluate JavaScript    css=#guidedProfile"
          ]
        }
      ]
    },
    {
      "id": "imports.start-session",
      "area": "Guided Import",
      "route": "/Banking/Imports?activeTab=guided&currentStep=1",
      "purpose": "Create an exact ImportSession and advance to Evidence.",
      "sourceFile": "AtxSolutions/Pages/Banking/Imports.cshtml",
      "sourceAnchor": "asp-page-handler=\"StartSession\"",
      "selector": "#stepPane1 form[action*=\"handler=StartSession\"] #btnStep1Next",
      "interaction": "Verify button enabled; submit exact Step 1 form.",
      "visibleCount": "Exactly 1 when Step 1 visible",
      "handler": "StartSession",
      "pageModelMethod": "ImportsModel.OnPostStartSessionAsync",
      "transport": "Full POST and redirect to Step 2",
      "preconditions": "Exact account/profile GUIDs selected; no conflicting active session.",
      "expectedOutcome": "Owned session created, selected exact published version pinned, Step 2 visible.",
      "hazards": "Do not infer session ID from URL; read hidden Step 2 session input / session JSON.",
      "failureBeforeCertification": "Application FAIL only after selection and ownership preflight",
      "sourceLine": 572,
      "pageModelFile": null,
      "pageModelLine": null,
      "robotBindings": [
        {
          "keyword": "Create Exact Guided Import Session",
          "requiredPatterns": [
            "Safe Click    css=#btnStep1Next",
            "Wait For Elements State    css=#stepPane2    visible"
          ]
        }
      ]
    },
    {
      "id": "imports.evidence-file",
      "area": "Guided Import",
      "route": "/Banking/Imports?activeTab=guided&currentStep=2",
      "purpose": "Select one or more evidence files.",
      "sourceFile": "AtxSolutions/Pages/Banking/Imports.cshtml",
      "sourceAnchor": "id=\"guidedFile\"",
      "selector": "#guidedFile",
      "interaction": "Upload file(s); verify FileList, summary and Next enabled.",
      "visibleCount": "Exactly 1",
      "handler": "UploadSessionFile form binding",
      "pageModelMethod": "OnPostUploadSessionFileAsync(Guid sessionId, List<IFormFile>? sessionFiles)",
      "transport": "Client state until POST",
      "preconditions": "Exact owned Step 2 session.",
      "expectedOutcome": "Selected files displayed; `#btnStep2Next` enabled.",
      "hazards": "Multiple non-image files are intentionally rejected. Multiple images are bundled into a synthetic ZIP.",
      "failureBeforeCertification": "TEST_INVALID or BLOCKED",
      "sourceLine": 643,
      "pageModelFile": "AtxSolutions/Pages/Banking/Imports.cshtml.cs",
      "pageModelLine": 701,
      "robotBindings": [
        {
          "keyword": "Upload Synthetic OCR Evidence To Review",
          "requiredPatterns": [
            "Upload File By Selector    css=#guidedFile    ${OCR_UI_SAMPLE}",
            "Get Property    css=#guidedFile    files"
          ]
        }
      ]
    },
    {
      "id": "imports.next-preview-upload",
      "area": "Guided Import",
      "route": "/Banking/Imports?activeTab=guided&currentStep=2",
      "purpose": "Upload and inspect evidence, then route to Preview or Extraction Review.",
      "sourceFile": "AtxSolutions/Pages/Banking/Imports.cshtml",
      "sourceAnchor": "id=\"btnStep2Next\"",
      "selector": "#btnStep2Next",
      "interaction": "Submit Step 2 form; inspect final URL and visible TempData/validation message before later assertions.",
      "visibleCount": "Exactly 1 when Step 2 visible",
      "handler": "UploadSessionFile",
      "pageModelMethod": "ImportsModel.OnPostUploadSessionFileAsync",
      "transport": "Full multipart POST and redirect",
      "preconditions": "Exact session ID; selected file(s); selected profile source format compatible.",
      "expectedOutcome": "Image/PDF requiring review redirects to `/Banking/Imports/ExtractionReview?sessionId=<GUID>`; otherwise Step 3.",
      "hazards": "A profile/source mismatch redirects to Step 1. OCR-disabled image produces a clear Step 2 error. Always classify response before waiting.",
      "failureBeforeCertification": "Application FAIL only after profile capability and file compatibility certified",
      "sourceLine": 687,
      "pageModelFile": null,
      "pageModelLine": null,
      "robotBindings": [
        {
          "keyword": "Upload Synthetic OCR Evidence To Review",
          "requiredPatterns": [
            "Safe Click    css=#btnStep2Next",
            "Wait Until Keyword Succeeds    60s    500ms    Evidence Upload Outcome Should Exist"
          ]
        }
      ]
    },
    {
      "id": "imports.cancel-visible-action",
      "area": "Guided Import",
      "route": "/Banking/Imports?activeTab=guided",
      "purpose": "Open the cancellation path for the exact active session.",
      "sourceFile": "AtxSolutions/Pages/Banking/Imports.cshtml",
      "sourceAnchor": "data-guided-cancel-import",
      "selector": "button[data-guided-cancel-import][data-bs-target=\"#cancelSessionModal\"]:visible",
      "interaction": "Use direct visible abandon form if uniquely visible; otherwise click exact modal trigger.",
      "visibleCount": "Exactly 1 visible cancel trigger when modal path is used",
      "handler": "Client Bootstrap modal",
      "pageModelMethod": "None",
      "transport": "No navigation until form submit",
      "preconditions": "Exact owned session ID known.",
      "expectedOutcome": "`#cancelSessionModal.show` visible.",
      "hazards": "The DOM can contain both visible direct and hidden modal abandon forms.",
      "failureBeforeCertification": "TEST_INVALID",
      "sourceLine": 554,
      "pageModelFile": null,
      "pageModelLine": null,
      "robotBindings": [
        {
          "keyword": "Verify Active Session Cancel And Abandon",
          "requiredPatterns": [
            "css=button[data-guided-cancel-import][data-bs-target=\"#cancelSessionModal\"]:visible",
            "css=form[action*=\"handler=AbandonSession\"]:has(input[name=\"sessionId\"][value=\"${SESSION_ID}\"]):visible"
          ]
        }
      ]
    },
    {
      "id": "imports.abandon-session",
      "area": "Guided Import",
      "route": "/Banking/Imports?activeTab=guided",
      "purpose": "Abandon exactly one owned session.",
      "sourceFile": "AtxSolutions/Pages/Banking/Imports.cshtml",
      "sourceAnchor": "asp-page-handler=\"AbandonSession\"",
      "selector": "form[action*=\"handler=AbandonSession\"]:has(input[name=\"sessionId\"][value=\"<GUID>\"]):visible",
      "interaction": "Prefer exactly one visible form; otherwise open modal and submit exact visible modal form.",
      "visibleCount": "Exactly 1 active form path",
      "handler": "AbandonSession",
      "pageModelMethod": "ImportsModel.OnPostAbandonSessionAsync",
      "transport": "Full POST and redirect to Guided Step 1",
      "preconditions": "Exact session ID, ownership and test-data classification confirmed.",
      "expectedOutcome": "Session discarded; Step 1 visible; exact abandon form absent.",
      "hazards": "Never assert global form count 1. Hidden duplicates are intentional.",
      "failureBeforeCertification": "TEST_INVALID",
      "sourceLine": 486,
      "pageModelFile": "AtxSolutions/Pages/Banking/Imports.cshtml.cs",
      "pageModelLine": 614,
      "robotBindings": [
        {
          "keyword": "Verify Active Session Cancel And Abandon",
          "requiredPatterns": [
            "css=form[action*=\"handler=AbandonSession\"]:has(input[name=\"sessionId\"][value=\"${SESSION_ID}\"]):visible",
            "Wait For Elements State    css=#stepPane1    visible"
          ]
        }
      ]
    },
    {
      "id": "review.form",
      "area": "Extraction Review",
      "route": "/Banking/Imports/ExtractionReview?sessionId=<GUID>",
      "purpose": "Confirm the mandatory review page and exact session.",
      "sourceFile": "AtxSolutions/Pages/Banking/Imports/ExtractionReview.cshtml",
      "sourceAnchor": "id=\"pdfExtractionReviewForm\"",
      "selector": "#pdfExtractionReviewForm:visible",
      "interaction": "Verify form and `#SessionId` property.",
      "visibleCount": "Exactly 1",
      "handler": "OnGet",
      "pageModelMethod": "ExtractionReviewModel.OnGetAsync",
      "transport": "GET",
      "preconditions": "Owned session has an extraction snapshot requiring review.",
      "expectedOutcome": "Heading `Confirm extracted transactions`; exact SessionId.",
      "hazards": "Do not use form-relative `input[name=SessionId]` when exact generated ID exists.",
      "failureBeforeCertification": "Application FAIL only after upload redirect contract certified",
      "sourceLine": 124,
      "pageModelFile": "AtxSolutions/Pages/Banking/Imports/ExtractionReview.cshtml.cs",
      "pageModelLine": 74,
      "robotBindings": [
        {
          "keyword": "Upload Synthetic OCR Evidence To Review",
          "requiredPatterns": [
            "css=#pdfExtractionReviewForm:visible",
            "Get Property    css=#SessionId    value"
          ]
        }
      ]
    },
    {
      "id": "review.rows",
      "area": "Extraction Review",
      "route": "/Banking/Imports/ExtractionReview",
      "purpose": "Read extracted transaction rows.",
      "sourceFile": "AtxSolutions/Pages/Banking/Imports/ExtractionReview.cshtml",
      "sourceAnchor": "id=\"pdfExtractionReviewTable\"",
      "selector": "#pdfExtractionReviewTable tr[data-review-row]",
      "interaction": "Count rows; read values through `data-field` input properties.",
      "visibleCount": "One or more for a successful representative extraction",
      "handler": "OnGet/posted state",
      "pageModelMethod": "LoadFromSessionAsync / BuildRowsFromSnapshotOrSessionFileAsync",
      "transport": "Read-only",
      "preconditions": "Review form loaded.",
      "expectedOutcome": "Rows attributed to source file/page; active rows > 0.",
      "hazards": "Use authoritative page counters where UI row rendering may be capped elsewhere.",
      "failureBeforeCertification": "Application FAIL only after sample/parser contract certified",
      "sourceLine": 231,
      "pageModelFile": null,
      "pageModelLine": null,
      "robotBindings": [
        {
          "keyword": "Upload Synthetic OCR Evidence To Review",
          "requiredPatterns": [
            "css=#pdfExtractionReviewTable tr[data-review-row]"
          ]
        }
      ]
    },
    {
      "id": "review.source-file-field",
      "area": "Extraction Review",
      "route": "/Banking/Imports/ExtractionReview",
      "purpose": "Verify per-row source attribution.",
      "sourceFile": "AtxSolutions/Pages/Banking/Imports/ExtractionReview.cshtml",
      "sourceAnchor": "data-field=\"SourceFileName\"",
      "selector": "<row> >> css=[data-field=\"SourceFileName\"]",
      "interaction": "Get Property `value`.",
      "visibleCount": "Exactly 1 per row",
      "handler": "Row form binding",
      "pageModelMethod": "ExtractionReviewRowInput.SourceFileName",
      "transport": "Read-only until submit",
      "preconditions": "Exact row selected.",
      "expectedOutcome": "Source filename matches staged evidence or bundled image entry.",
      "hazards": "Input values are not included in `Get Text`.",
      "failureBeforeCertification": "TEST_INVALID",
      "sourceLine": 264,
      "pageModelFile": null,
      "pageModelLine": null,
      "robotBindings": [
        {
          "keyword": "Upload Synthetic OCR Evidence To Review",
          "requiredPatterns": [
            "css=[data-field=\"SourceFileName\"]"
          ]
        }
      ]
    },
    {
      "id": "review.save-corrections",
      "area": "Extraction Review",
      "route": "/Banking/Imports/ExtractionReview",
      "purpose": "Save non-blocking review corrections without accepting.",
      "sourceFile": "AtxSolutions/Pages/Banking/Imports/ExtractionReview.cshtml",
      "sourceAnchor": "asp-page-handler=\"Save\"",
      "selector": "#pdfReviewActionBar button[formaction*=\"handler=Save\"]:visible",
      "interaction": "Submit and inspect ModelState/redirect.",
      "visibleCount": "Exactly 1",
      "handler": "Save",
      "pageModelMethod": "ExtractionReviewModel.OnPostSaveAsync",
      "transport": "Full POST; Page on blocking issues, redirect back on success",
      "preconditions": "Exact session; posted rows normalized.",
      "expectedOutcome": "Corrections saved with `accepted:false`; review remains.",
      "hazards": "Blocking issues correctly return the page and preserve posted corrections.",
      "failureBeforeCertification": "Application FAIL only after row-policy contract certified",
      "sourceLine": 367,
      "pageModelFile": "AtxSolutions/Pages/Banking/Imports/ExtractionReview.cshtml.cs",
      "pageModelLine": 86,
      "robotBindings": [
        {
          "keyword": "Verify OCR Problem State Correction And Persistence",
          "requiredPatterns": [
            "css=#pdfReviewActionBar button[formaction*=\"handler=Save\"]:visible",
            "Correct the required transaction fields before saving."
          ]
        }
      ]
    },
    {
      "id": "review.accept-warnings",
      "area": "Extraction Review",
      "route": "/Banking/Imports/ExtractionReview",
      "purpose": "Acknowledge advisory warnings before acceptance.",
      "sourceFile": "AtxSolutions/Pages/Banking/Imports/ExtractionReview.cshtml",
      "sourceAnchor": "asp-for=\"AcceptWarnings\"",
      "selector": "#AcceptWarnings",
      "interaction": "Check only after comparing advisory rows with source.",
      "visibleCount": "Exactly 1 when advisory warnings exist; container hidden otherwise",
      "handler": "Accept form binding",
      "pageModelMethod": "ExtractionReviewModel.AcceptWarnings",
      "transport": "Client state until Accept POST",
      "preconditions": "Warnings present and no blocking issues.",
      "expectedOutcome": "Checkbox checked.",
      "hazards": "ASP.NET may render a hidden checkbox fallback. Always use exact ID/type.",
      "failureBeforeCertification": "TEST_INVALID",
      "sourceLine": 362,
      "pageModelFile": null,
      "pageModelLine": null
    },
    {
      "id": "review.accept-continue",
      "area": "Extraction Review",
      "route": "/Banking/Imports/ExtractionReview",
      "purpose": "Accept reviewed extraction and continue to Guided Preview.",
      "sourceFile": "AtxSolutions/Pages/Banking/Imports/ExtractionReview.cshtml",
      "sourceAnchor": "id=\"pdfReviewAcceptButton\"",
      "selector": "#pdfReviewAcceptButton:visible",
      "interaction": "Verify enabled and warning acknowledgement as required; submit.",
      "visibleCount": "Exactly 1 at runtime (Razor branches share the same ID)",
      "handler": "Accept",
      "pageModelMethod": "ExtractionReviewModel.OnPostAcceptAsync",
      "transport": "Full POST; Page on rejection/blocking/warnings, redirect to Guided Step 3 on success",
      "preconditions": "No rejection/blocking; warnings acknowledged if present.",
      "expectedOutcome": "Rows saved with `accepted:true`; Step 3 redirect.",
      "hazards": "Focused tests that must not import should not click this button.",
      "failureBeforeCertification": "Application FAIL only after all policy preconditions certified",
      "sourceLine": 372,
      "pageModelFile": "AtxSolutions/Pages/Banking/Imports/ExtractionReview.cshtml.cs",
      "pageModelLine": 139
    },
    {
      "id": "statement.open-detailed-section",
      "area": "Statement Profile",
      "route": "/Banking/Profiles/Statement",
      "purpose": "Open one exact detailed configuration section through the desktop Statement navigation.",
      "sourceFile": "AtxSolutions/Pages/Banking/Profiles/Statement.cshtml",
      "sourceAnchor": "class=\"statement-nav-link\" data-section-target=\"profile-details\"",
      "selector": ".statement-config-nav button[data-section-target=\"<SECTION_ID>\"]:visible",
      "interaction": "Assert exactly one visible navigation button, click it, then assert `#<SECTION_ID>.statement-section.is-active:visible`.",
      "visibleCount": "Exactly 1 for a valid desktop detailed section in the current mode",
      "handler": "Client-side showSection(sectionId)",
      "pageModelMethod": "None",
      "transport": "No navigation; DOM section state and URL hash update",
      "preconditions": "Desktop viewport; Advanced mode when the target is advanced-only.",
      "expectedOutcome": "The requested section alone is active and the URL hash identifies it.",
      "hazards": "Detailed navigation, major progress navigation and mobile overview navigation are separate systems. Never substitute `data-major-target` or `data-mobile-section-target`.",
      "failureBeforeCertification": "TEST_INVALID",
      "sourceLine": 2032,
      "pageModelFile": null,
      "pageModelLine": null
    },
    {
      "id": "statement.open-major-section",
      "area": "Statement Profile",
      "route": "/Banking/Profiles/Statement",
      "purpose": "Open an exact major progress section such as Save Profile.",
      "sourceFile": "AtxSolutions/Pages/Banking/Profiles/Statement.cshtml",
      "sourceAnchor": "data-major-target=\"save-profile\"",
      "selector": ".statement-progress:visible button.statement-progress-step[data-major-target=\"<SECTION_ID>\"]:visible",
      "interaction": "Resolve the single visible Basic or Advanced progress strip, click its exact major target, then assert `#<SECTION_ID>.statement-section.is-active:visible`.",
      "visibleCount": "Exactly 1 after scoping to `.statement-progress:visible`",
      "handler": "Client-side showSection(sectionId)",
      "pageModelMethod": "None",
      "transport": "No navigation; DOM section state and URL hash update",
      "preconditions": "Statement workspace loaded in a desktop viewport.",
      "expectedOutcome": "The requested major section is active.",
      "hazards": "Basic and Advanced progress strips both exist in the DOM. Never use an unscoped global `button[data-major-target]` uniqueness assertion.",
      "failureBeforeCertification": "TEST_INVALID",
      "sourceLine": 1953,
      "pageModelFile": null,
      "pageModelLine": null
    },
    {
      "id": "statement.read-ajax-outcome",
      "area": "Statement Profile",
      "route": "/Banking/Profiles/Statement",
      "purpose": "Classify the immediate result of a Statement AJAX action before waiting for a later state.",
      "sourceFile": "AtxSolutions/Pages/Banking/Profiles/Statement.cshtml",
      "sourceAnchor": "async function submitProfileActionWithoutNavigation(event)",
      "selector": ".statement-profile-page, #statementProfileValidationSummary, .statement-ajax-feedback:visible",
      "interaction": "Wait for `.statement-profile-page.is-ajax-busy` to clear; read the replacement page URL/hash, visible validation summary, `data-ajax-feedback-message`, `data-ajax-feedback-tone`, transient feedback and the exact returned ID/state.",
      "visibleCount": "Exactly 1 replacement Statement page; validation/feedback may be zero or one",
      "handler": "Client-side AJAX lifecycle around the submitter's Razor handler",
      "pageModelMethod": "Handler-specific",
      "transport": "Fetch POST with X-ATX-Profile-Action and fragment replacement, or redirect navigation",
      "preconditions": "The exact mapped AJAX submitter was used.",
      "expectedOutcome": "HTTP success produced either a replacement Statement page or the documented redirect; validation and feedback are classified before later assertions.",
      "hazards": "A successful HTTP response can still contain validation errors. Waiting only for a later ID, card or result grid hides the actual handler outcome.",
      "failureBeforeCertification": "TEST_INVALID until the immediate response has been classified",
      "sourceLine": 4817,
      "pageModelFile": null,
      "pageModelLine": null
    },
    {
      "id": "statement.read-test-outcome",
      "area": "Statement Profile",
      "route": "/Banking/Profiles/Statement#test-results",
      "purpose": "Read the authoritative representative-test state, row count, provider and publish readiness.",
      "sourceFile": "AtxSolutions/Pages/Banking/Profiles/Statement.cshtml",
      "sourceAnchor": "class=\"statement-test-summary-grid\"",
      "selector": "#test-results .statement-test-summary-grid:visible",
      "interaction": "Read the direct Test Results header badge, the success-card transaction value, blocking alert/validation state and the provider/mode summary through visible text nodes.",
      "visibleCount": "Exactly 1 summary grid after a completed test",
      "handler": "Read-only result of Test or RerunExtraction",
      "pageModelMethod": "StatementModel.OnPostTestAsync / OnPostRerunExtractionAsync",
      "transport": "Read-only after AJAX replacement",
      "preconditions": "The immediate AJAX outcome was classified and a TestResult is present.",
      "expectedOutcome": "Badge is Ready, authoritative transaction count is greater than zero, no blocking alert/validation exists, and provider/mode are populated.",
      "hazards": "Do not infer total rows from a potentially capped preview table. Read input properties for form values and visible text only for rendered result labels.",
      "failureBeforeCertification": "Application FAIL only after source, provider, sample and handler prerequisites are certified",
      "sourceLine": 3479,
      "pageModelFile": "AtxSolutions/Pages/Banking/Profiles/Statement.cshtml.cs",
      "pageModelLine": 362
    },
    {
      "id": "imports.upload-multiple-images",
      "area": "Guided Import",
      "route": "/Banking/Imports?activeTab=guided&currentStep=2",
      "purpose": "Select multiple screenshot/image files in one Guided Import upload.",
      "sourceFile": "AtxSolutions/Pages/Banking/Imports.cshtml.cs",
      "sourceAnchor": "uploadFile = await BuildSyntheticScreenshotZipAsync(uploadFiles, HttpContext.RequestAborted);",
      "selector": "#guidedFile",
      "interaction": "Upload two or more paths in one Browser file-input operation; verify FileList count and exact selection order before submitting `#btnStep2Next`.",
      "visibleCount": "Exactly 1 file input; FileList count equals supplied image path count",
      "handler": "UploadSessionFile",
      "pageModelMethod": "ImportsModel.OnPostUploadSessionFileAsync",
      "transport": "Full multipart POST and redirect",
      "preconditions": "Exact owned Step-2 session; every selected file has a supported image OCR extension; each file is within NormalImportMaxBytes.",
      "expectedOutcome": "Server builds one synthetic ZIP named `screenshot-batch-<UTC timestamp>.zip`; entries are `01_<original>`, `02_<original>`, and so on; success feedback states that screenshots were bundled; inspection routes to mandatory Extraction Review.",
      "hazards": "If any selected file is not an image, the handler rejects the whole multi-file request and stays at Step 2. Do not confuse direct multi-file selection with uploading one prebuilt ZIP.",
      "failureBeforeCertification": "TEST_INVALID or BLOCKED",
      "sourceLine": 755,
      "pageModelFile": "AtxSolutions/Pages/Banking/Imports.cshtml.cs",
      "pageModelLine": 701
    },
    {
      "id": "imports.upload-image-only-archive",
      "area": "Guided Import",
      "route": "/Banking/Imports?activeTab=guided&currentStep=2",
      "purpose": "Upload one ZIP containing supported image evidence only.",
      "sourceFile": "AtxSolutions/Features/Banking/Services/SourceIngestion/BankImportSourceService.cs",
      "sourceAnchor": "if (imageCount > 0)",
      "selector": "#guidedFile",
      "interaction": "Upload one certified image-only ZIP, verify one selected file and submit `#btnStep2Next`; classify the immediate redirect and review state.",
      "visibleCount": "Exactly 1 file input; FileList count 1",
      "handler": "UploadSessionFile -> InspectZipBankingSourceUploadAsync -> InspectImageOcrUploadAsync",
      "pageModelMethod": "ImportsModel.OnPostUploadSessionFileAsync",
      "transport": "Full multipart POST and redirect",
      "preconditions": "Archive safety passes; at least one supported image entry; no PDF entries; entry limits and size limits pass; published OCR profile accepts ImageArchive.",
      "expectedOutcome": "Source format resolves to PdfText/ImageArchive, OCR runs per image entry, and the exact session reaches mandatory Extraction Review with per-entry source attribution.",
      "hazards": "ZIP entry order is normalized by FullName, not ZIP insertion order. Unsupported/nested/unsafe entries are safety failures, not application parsing failures.",
      "failureBeforeCertification": "BLOCKED or TEST_INVALID",
      "sourceLine": 160,
      "pageModelFile": null,
      "pageModelLine": null
    },
    {
      "id": "imports.upload-pdf-only-archive",
      "area": "Guided Import",
      "route": "/Banking/Imports?activeTab=guided&currentStep=2",
      "purpose": "Upload one ZIP containing PDF evidence only.",
      "sourceFile": "AtxSolutions/Features/Banking/Services/SourceIngestion/BankImportSourceService.cs",
      "sourceAnchor": "return await InspectPdfDirectTextUploadAsync(file, fileName, extension, pdfPassword, sourceSettingsJson, cancellationToken);",
      "selector": "#guidedFile",
      "interaction": "Upload one certified PDF-only ZIP, verify one selected file and submit `#btnStep2Next`; classify direct-text/OCR outcome and mandatory review routing.",
      "visibleCount": "Exactly 1 file input; FileList count 1",
      "handler": "UploadSessionFile -> InspectZipBankingSourceUploadAsync -> InspectPdfDirectTextUploadAsync",
      "pageModelMethod": "ImportsModel.OnPostUploadSessionFileAsync",
      "transport": "Full multipart POST and redirect",
      "preconditions": "Archive safety passes; at least one PDF entry; no image entries; shared PDF-password requirement satisfied; published profile accepts PdfArchive.",
      "expectedOutcome": "PDF archive is inspected by direct text or OCR according to the profile and provider contract; review-required output reaches Extraction Review with per-PDF attribution.",
      "hazards": "A PDF-only ZIP is not processed by the screenshot normalizer. Password-protected PDFs in one archive currently share one supplied password.",
      "failureBeforeCertification": "BLOCKED or TEST_INVALID",
      "sourceLine": 164,
      "pageModelFile": null,
      "pageModelLine": null
    },
    {
      "id": "imports.reject-mixed-evidence-archive",
      "area": "Guided Import",
      "route": "/Banking/Imports?activeTab=guided&currentStep=2",
      "purpose": "Reject a ZIP containing both PDF and image evidence.",
      "sourceFile": "AtxSolutions/Features/Banking/Services/SourceIngestion/Safety/BankingEvidenceFileSafetyService.cs",
      "sourceAnchor": "The ZIP contains both PDF and image files. Split them into separate imports.",
      "selector": "#guidedFile then .bankimports-banner.alert-danger:visible",
      "interaction": "Upload one certified mixed ZIP and submit `#btnStep2Next`; immediately verify the exact error banner, URL query, visible Step-2 pane and the schema-valid `window.__importSession` object.",
      "visibleCount": "Exactly 1 file input; exactly 1 visible error banner after redirect",
      "handler": "UploadSessionFile -> BankingEvidenceFileSafetyService.InspectArchiveAsync",
      "pageModelMethod": "ImportsModel.OnPostUploadSessionFileAsync",
      "transport": "Full multipart POST and redirect back to Step 2",
      "preconditions": "Exact empty owned Step-2 session; archive contains at least one PDF and one supported image.",
      "expectedOutcome": "Safety decision `banking-archive-mixed-content`; exact rejection text; URL remains Guided Step 2; the exact session ID is preserved; `step` is 2; no file, owner-scoped artifact, preview or validation state is persisted.",
      "hazards": "The safety service rejects mixed content before the later source-service branch. Read `step` from the source-confirmed serialized schema. A missing-property fallback is TEST_INVALID, not an ATX defect.",
      "failureBeforeCertification": "Application FAIL only after archive contents and safety gate are certified",
      "sourceLine": 160,
      "pageModelFile": null,
      "pageModelLine": null
    },
    {
      "id": "imports.read-feedback-banner",
      "area": "Guided Import",
      "route": "/Banking/Imports",
      "purpose": "Read the immediate TempData feedback produced by a Guided Import POST.",
      "sourceFile": "AtxSolutions/Pages/Banking/Imports.cshtml",
      "sourceAnchor": "class=\"alert alert-danger alert-dismissible fade show bankimports-banner\"",
      "selector": ".bankimports-banner:visible",
      "interaction": "Read visible banner class and text immediately after redirect, before auto-dismiss.",
      "visibleCount": "Zero or one per feedback category; exact focused test expects one matching banner",
      "handler": "Razor rendering of TempData ErrorMessage/WarningMessage/SuccessMessage",
      "pageModelMethod": "ImportsModel.OnGetAsync",
      "transport": "Read-only after full redirect",
      "preconditions": "A POST set TempData feedback.",
      "expectedOutcome": "Banner tone and text match the source-confirmed handler outcome.",
      "hazards": "Success and error banners can auto-dismiss. Read them immediately; do not wait only for a later pane.",
      "failureBeforeCertification": "TEST_INVALID until immediate feedback is read",
      "sourceLine": 121,
      "pageModelFile": null,
      "pageModelLine": null
    },
    {
      "id": "review.file-summaries",
      "area": "Extraction Review",
      "route": "/Banking/Imports/ExtractionReview",
      "purpose": "Read the per-source-file summary cards above the review table.",
      "sourceFile": "AtxSolutions/Pages/Banking/Imports/ExtractionReview.cshtml",
      "sourceAnchor": "class=\"fw-semibold pdf-review-file-name\"",
      "selector": ".pdf-review-file-summary .pdf-review-file-name",
      "interaction": "Read every visible summary filename and its row/page/status text in DOM order.",
      "visibleCount": "Exactly one summary card per distinct SourceFileName represented by review rows",
      "handler": "OnGet read-only rendering",
      "pageModelMethod": "ExtractionReviewModel.OnGetAsync",
      "transport": "Read-only",
      "preconditions": "Extraction Review loaded with rows from one or more sources.",
      "expectedOutcome": "Distinct source filenames and counts match the row-level SourceFileName values.",
      "hazards": "Summary order follows server grouping/order and may differ from original ZIP insertion order.",
      "failureBeforeCertification": "TEST_INVALID",
      "sourceLine": 166,
      "pageModelFile": "AtxSolutions/Pages/Banking/Imports/ExtractionReview.cshtml.cs",
      "pageModelLine": 404
    },
    {
      "id": "review.verify-image-order-dedup",
      "area": "Extraction Review",
      "route": "/Banking/Imports/ExtractionReview",
      "purpose": "Verify screenshot archive exact-row deduplication, stable date/source ordering and source attribution.",
      "sourceFile": "AtxSolutions/Features/Banking/Services/SourceIngestion/BankImportImageOcrNormalizer.cs",
      "sourceAnchor": "Removed {duplicateCount} duplicate screenshot row(s) where date, normalized description, amount and balance matched exactly.",
      "selector": "#pdfExtractionReviewTable tr[data-review-row] with child fields `[data-field=SourceFileName]`, `[data-field=Date]`, `[data-field=Description]`, `[data-field=Amount]`, `[data-field=Balance]`",
      "interaction": "Read all row field properties in table order; compare against the certified synthetic overlap dataset and distinct per-file summary names.",
      "visibleCount": "Expected certified dataset count after one exact overlap is removed",
      "handler": "BankImportImageOcrNormalizer.PostProcessScreenshotRows",
      "pageModelMethod": "None",
      "transport": "Read-only verification of persisted extraction snapshot",
      "preconditions": "The synthetic pair uses only rows already proven reliable with the same Published profile/provider; both copies of the overlap are runtime-visible before exact-dedup failure can be asserted.",
      "expectedOutcome": "For the calibrated dataset, one exact overlap is removed; the remaining known dates are ascending; the earlier source retains the duplicate; row SourceFileName values retain exact archive entry names.",
      "hazards": "OCR calibration is part of the test contract. A row already known to be omitted may not remain a required datum in a corrected package. Incomplete calibration is BLOCKED once; repeating it is TEST_INVALID.",
      "failureBeforeCertification": "Application FAIL only after the synthetic OCR fingerprint is runtime-certified",
      "sourceLine": 277,
      "pageModelFile": null,
      "pageModelLine": null
    },
    {
      "id": "imports.session-json-schema",
      "area": "Guided Import",
      "route": "/Banking/Imports?activeTab=guided",
      "purpose": "Validate the exact browser-visible ImportSession serialization before reading session state.",
      "sourceFile": "AtxSolutions/Pages/Banking/Imports.cshtml.cs",
      "sourceAnchor": "step = session.CurrentStep,",
      "selector": "Evaluate `window.__importSession` and compare `Object.keys(...)` with the exact schema contract.",
      "interaction": "Require the exact camelCase property set emitted by `SerializeSessionState`; validate types; only then read `id`, `step`, selection IDs and persistence/review flags.",
      "visibleCount": "N/A",
      "handler": "OnGet -> SerializeSessionState -> window.__importSession",
      "pageModelMethod": "ImportsModel.OnGetAsync",
      "serializationMethod": "ImportsModel.SerializeSessionState",
      "transport": "Read-only JavaScript object embedded by Razor",
      "preconditions": "Imports page loaded with an active session.",
      "expectedOutcome": "Exactly 15 source-confirmed camelCase properties are present. `step` is an integer and the state object belongs to the exact session being tested.",
      "hazards": "`currentStep` is a URL/page concept and is not a serialized session property. `CurrentStep` is the C# entity property and is converted to `step` by the anonymous object plus camelCase serializer.",
      "failureBeforeCertification": "TEST_INVALID",
      "sourceLine": 3791,
      "pageModelFile": "AtxSolutions/Pages/Banking/Imports.cshtml.cs",
      "pageModelLine": 3791
    },
    {
      "id": "statement.regions-editor",
      "area": "Statement Profile",
      "route": "/Banking/Profiles/Statement",
      "purpose": "Configure and verify percentage-based OCR regions through the generated region cards.",
      "sourceFile": "AtxSolutions/Pages/Banking/Profiles/Statement.cshtml",
      "sourceAnchor": "id=\"ocrRegionList\"",
      "selector": "#ocrRegionList .ocr-region-card",
      "interaction": "Use the generated visible inputs/selects/checkboxes inside each `.ocr-region-card`. Read `#OcrRegionsJson` only after UI events to verify the resulting normalized model.",
      "visibleCount": "One default Transactions card; two cards after adding one Ignore region",
      "handler": "Client editor sync -> Statement form binding",
      "pageModelMethod": "StatementModel.OnPostSaveAndExitAsync",
      "transport": "Client state followed by full SaveAndExit POST",
      "preconditions": "Advanced mode; dedicated Draft; synthetic sample prepared for visual canvas assertions.",
      "expectedOutcome": "Exactly one enabled Transactions region and one enabled Ignore region persist with normalized percentages.",
      "hazards": "Direct writes to `#OcrRegionsJson` bypass the UI contract and are prohibited.",
      "failureBeforeCertification": "TEST_INVALID",
      "sourceLine": 2812,
      "pageModelFile": "AtxSolutions/Pages/Banking/Profiles/Statement.cshtml.cs",
      "pageModelLine": 1021
    },
    {
      "id": "statement.add-ignore-region",
      "area": "Statement Profile",
      "route": "/Banking/Profiles/Statement#anchors-noise",
      "purpose": "Add one visible Ignore region through the editor toolbar.",
      "sourceFile": "AtxSolutions/Pages/Banking/Profiles/Statement.cshtml",
      "sourceAnchor": "id=\"addDefaultRegion\"",
      "selector": "#addDefaultRegion",
      "interaction": "Click once, then configure the second `.ocr-region-card`.",
      "visibleCount": "Exactly 1",
      "handler": "Client `addDefaultRegion` click listener",
      "pageModelMethod": "None",
      "transport": "Client only until save",
      "preconditions": "Advanced Regions & Anchors section open.",
      "expectedOutcome": "One normalized Ignore region is appended and synced.",
      "hazards": "Repeated clicks create extra regions; exact count must be verified before saving.",
      "failureBeforeCertification": "TEST_INVALID",
      "sourceLine": 2810,
      "pageModelFile": null,
      "pageModelLine": null
    },
    {
      "id": "statement.add-anchor-rule",
      "area": "Statement Profile",
      "route": "/Banking/Profiles/Statement#anchors-noise",
      "purpose": "Add start/end anchor cards through the visible editor.",
      "sourceFile": "AtxSolutions/Pages/Banking/Profiles/Statement.cshtml",
      "sourceAnchor": "id=\"addAnchorRule\"",
      "selector": "#addAnchorRule then #ocrAnchorList .ocr-anchor-card",
      "interaction": "Click twice; configure the generated Name, Anchor text, Match type, boundary direction, distance, offset, page scope and Required switches through visible controls.",
      "visibleCount": "Exactly 2 anchor cards for the certified Draft",
      "handler": "Client `addAnchorRule` click listener",
      "pageModelMethod": "StatementModel.OnPostSaveAndExitAsync",
      "transport": "Client state followed by full SaveAndExit POST",
      "preconditions": "Advanced Regions & Anchors section open.",
      "expectedOutcome": "Start/below and end/above anchors persist in exact order.",
      "hazards": "Direct writes to `#AnchorRulesJson` are prohibited.",
      "failureBeforeCertification": "TEST_INVALID",
      "sourceLine": 2826,
      "pageModelFile": "AtxSolutions/Pages/Banking/Profiles/Statement.cshtml.cs",
      "pageModelLine": 1017
    },
    {
      "id": "statement.table-detection-settings",
      "area": "Statement Profile",
      "route": "/Banking/Profiles/Statement#table-detection",
      "purpose": "Configure table detection and wrapped-row geometry settings.",
      "sourceFile": "AtxSolutions/Pages/Banking/Profiles/Statement.cshtml",
      "sourceAnchor": "asp-for=\"Form.TableDetectionEnabled\"",
      "selector": "#Form_TableDetectionEnabled, #Form_TableExpectedColumnCount, #Form_TableAutoDetectColumns, #Form_TableMergeWrappedRows, #Form_TableAllowContinuationRows",
      "interaction": "Use the visible checkbox/number controls and verify their DOM properties.",
      "visibleCount": "Exactly 1 each",
      "handler": "Statement form binding",
      "pageModelMethod": "StatementModel.OnPostTestAsync",
      "transport": "AJAX Test POST",
      "preconditions": "Advanced mode; one enabled transaction region.",
      "expectedOutcome": "Table detection runs with the expected column count, automatic bands, wrapped-row merging and continuation-row handling.",
      "hazards": "Detected geometry is provider-dependent; persistence is hard-required, exact detected count is not. Continuation behavior must be asserted with calibrated evidence.",
      "failureBeforeCertification": "BLOCKED until provider returns positioned geometry",
      "sourceLine": 2865,
      "pageModelFile": "AtxSolutions/Pages/Banking/Profiles/Statement.cshtml.cs",
      "pageModelLine": 1041
    },
    {
      "id": "statement.use-detected-columns",
      "area": "Statement Profile",
      "route": "/Banking/Profiles/Statement#column-mapping",
      "purpose": "Convert detected or starter bands into manual editable columns.",
      "sourceFile": "AtxSolutions/wwwroot/js/banking-statement-column-mapping.js",
      "sourceAnchor": "document.getElementById('useDetectedColumns')?.addEventListener('click'",
      "selector": "#useDetectedColumns",
      "interaction": "Click once after a successful initial Test; verify Manual mode and generated column items.",
      "visibleCount": "Exactly 1",
      "handler": "Client column-mapping controller",
      "pageModelMethod": "StatementModel.OnPostRemapAsync",
      "transport": "Client state followed by AJAX Remap POST",
      "preconditions": "Initial extraction has completed; Column Mapping section open.",
      "expectedOutcome": "Manual mode contains detected columns or the five source-confirmed starter columns.",
      "hazards": "Do not assume detected-column count; the client intentionally falls back to starter columns.",
      "failureBeforeCertification": "TEST_INVALID",
      "sourceLine": 654,
      "pageModelFile": "AtxSolutions/Pages/Banking/Profiles/Statement.cshtml.cs",
      "pageModelLine": 383
    },
    {
      "id": "statement.manual-column-editor",
      "area": "Statement Profile",
      "route": "/Banking/Profiles/Statement#column-mapping",
      "purpose": "Edit generated manual column bands and verify normalized JSON.",
      "sourceFile": "AtxSolutions/wwwroot/js/banking-statement-column-mapping.js",
      "sourceAnchor": "function buildStarterColumns()",
      "selector": "#columnMappingList .statement-column-item",
      "interaction": "Use the visible Banking-field selects and generated boundary inputs. Capture each card data-column-id before edits and target every subsequent change by that stable identity. Read #ColumnMappingMode and #ColumnMappingsJson only for verification.",
      "visibleCount": "At least 5; the focused V12 interpretation scenario reaches exactly 7 through the visible Add Column action.",
      "handler": "Client column-mapping controller -> Remap",
      "pageModelMethod": "StatementModel.OnPostRemapAsync",
      "transport": "AJAX Remap POST",
      "preconditions": "Manual mode selected.",
      "expectedOutcome": "The seven configured cards retain their certified identity-to-boundary-to-field mapping and normalize contiguously as TransactionDate, Description, Reference, SignedAmount, Debit, Credit and RunningBalance.",
      "hazards": "The controller calls sortColumns during render and every field/boundary update can replace and reorder DOM cards by leftPercent. nth-child/index selectors become stale after the first re-render. Direct JSON writes remain prohibited.",
      "failureBeforeCertification": "TEST_INVALID until stable data-column-id targeting, final DOM order and normalized JSON order are certified",
      "sourceLine": 91,
      "pageModelFile": "AtxSolutions/Pages/Banking/Profiles/Statement.cshtml.cs",
      "pageModelLine": 1102
    },
    {
      "id": "statement.amount-rules",
      "area": "Statement Profile",
      "route": "/Banking/Profiles/Statement#amount-rules",
      "purpose": "Configure signed amount and number-format interpretation.",
      "sourceFile": "AtxSolutions/Pages/Banking/Profiles/Statement.cshtml",
      "sourceAnchor": "asp-for=\"Form.AmountStrategy\"",
      "selector": "#Form_DateFormat, #Form_AmountFormat, #Form_AmountStrategy, #Form_DecimalSeparator, #Form_ThousandsSeparator, #Form_NegativeNumberStyle",
      "interaction": "Select explicit values, verify live DOM properties and apply them through Remap.",
      "visibleCount": "Exactly 1 each",
      "handler": "Statement form binding -> Remap",
      "pageModelMethod": "StatementModel.OnPostRemapAsync",
      "transport": "AJAX Remap POST",
      "preconditions": "Manual SignedAmount column exists.",
      "expectedOutcome": "The configured date/number rules are bound and applied during Remap. V12 separately verifies SignedAmount precedence and Debit/Credit fallback values.",
      "hazards": "Persistence was already certified by Advanced Visual V1.2; this action does not by itself prove every bank number format.",
      "failureBeforeCertification": "TEST_INVALID",
      "sourceLine": 3080,
      "pageModelFile": "AtxSolutions/Pages/Banking/Profiles/Statement.cshtml.cs",
      "pageModelLine": 383
    },
    {
      "id": "statement.row-reconstruction-settings",
      "area": "Statement Profile",
      "route": "/Banking/Profiles/Statement#row-reconstruction",
      "purpose": "Configure wrapped-description reconstruction.",
      "sourceFile": "AtxSolutions/Pages/Banking/Profiles/Statement.cshtml",
      "sourceAnchor": "asp-for=\"Form.JoinWrappedDescriptionLines\"",
      "selector": "#Form_JoinWrappedDescriptionLines, #Form_ContinuationLineRules",
      "interaction": "Enable wrapped-description joining, enter the continuation rule, verify live state and apply through Remap.",
      "visibleCount": "Exactly 1 each",
      "handler": "Statement form binding -> Remap",
      "pageModelMethod": "StatementModel.OnPostRemapAsync",
      "transport": "AJAX Remap POST",
      "preconditions": "Advanced mode.",
      "expectedOutcome": "Wrapped-row settings are bound and applied. The calibrated continuation-row output is verified by statement.verify-wrapped-row-reconstruction.",
      "hazards": "A setting alone is not output proof; use calibrated evidence for the focused wrapped-row contract.",
      "failureBeforeCertification": "TEST_INVALID",
      "sourceLine": 3144,
      "pageModelFile": "AtxSolutions/Pages/Banking/Profiles/Statement.cshtml.cs",
      "pageModelLine": 383
    },
    {
      "id": "statement.ordering-duplicates-settings",
      "area": "Statement Profile",
      "route": "/Banking/Profiles/Statement#ordering-duplicates",
      "purpose": "Configure strict duplicate cleanup and summary-row removal.",
      "sourceFile": "AtxSolutions/Pages/Banking/Profiles/Statement.cshtml",
      "sourceAnchor": "asp-for=\"Form.DuplicateDetectionMode\"",
      "selector": "#Form_DuplicateDetectionMode, #Form_SkipSummaryRows",
      "interaction": "Select StrictRowMatch, enable SkipSummaryRows, verify live state and apply through Remap.",
      "visibleCount": "Exactly 1 each",
      "handler": "Statement form binding -> Remap",
      "pageModelMethod": "StatementModel.OnPostRemapAsync",
      "transport": "AJAX Remap POST",
      "preconditions": "Advanced mode.",
      "expectedOutcome": "Strict duplicate and summary-row settings are applied without blocking. Same-date source ordering is verified separately by V12.",
      "hazards": "Cross-file exact deduplication was certified separately. This action is configuration, not row-order proof.",
      "failureBeforeCertification": "TEST_INVALID",
      "sourceLine": 3177,
      "pageModelFile": "AtxSolutions/Pages/Banking/Profiles/Statement.cshtml.cs",
      "pageModelLine": 383
    },
    {
      "id": "statement.balance-validation-settings",
      "area": "Statement Profile",
      "route": "/Banking/Profiles/Statement#balance-validation",
      "purpose": "Configure running-balance and confidence validation.",
      "sourceFile": "AtxSolutions/Pages/Banking/Profiles/Statement.cshtml",
      "sourceAnchor": "asp-for=\"Form.BalanceReconciliationEnabled\"",
      "selector": "#Form_RunningBalancePresent, #Form_BalanceReconciliationEnabled, #Form_OpeningBalanceRule, #Form_ClosingBalanceRule, #Form_MinimumConfidenceThreshold",
      "interaction": "Set running-balance and confidence controls, verify live state and apply through Remap.",
      "visibleCount": "Exactly 1 each",
      "handler": "Statement form binding -> Remap",
      "pageModelMethod": "StatementModel.OnPostRemapAsync",
      "transport": "AJAX Remap POST",
      "preconditions": "RunningBalance column exists.",
      "expectedOutcome": "Balance reconciliation and 60% minimum confidence are applied without a blocking Remap result. V12 separately verifies the calibrated balance chain.",
      "hazards": "The focused V12 test verifies one calibrated continuous chain; balance-repair edge cases remain later work.",
      "failureBeforeCertification": "TEST_INVALID",
      "sourceLine": 3229,
      "pageModelFile": "AtxSolutions/Pages/Banking/Profiles/Statement.cshtml.cs",
      "pageModelLine": 383
    },
    {
      "id": "statement.page-initialization-readiness",
      "area": "Statement Profile",
      "route": "/Banking/Profiles/Statement",
      "purpose": "Wait until all Statement Profile client controllers and mode/section handlers are bound.",
      "sourceFile": "AtxSolutions/Pages/Banking/Profiles/Statement.cshtml",
      "sourceAnchor": "window.__atxStatementProfileCleanup = () => {",
      "selector": ".statement-profile-page plus window.__atxStatementProfileCleanup",
      "interaction": "Wait for `.statement-profile-page` to be visible, then poll JavaScript until `typeof window.__atxStatementProfileCleanup === 'function'`.",
      "visibleCount": "Exactly 1 Statement page; ready marker returns true",
      "handler": "window.initializeStatementProfilePage",
      "pageModelMethod": "None",
      "transport": "Read-only browser readiness check",
      "preconditions": "Full navigation or AJAX replacement has rendered Statement Profile markup.",
      "expectedOutcome": "Mode buttons, section navigation, dynamic editors and AJAX handlers are bound.",
      "hazards": "DOM visibility can occur before DOMContentLoaded initialization. Browser Click can report PASS while the application handler is not attached and the mode remains unchanged.",
      "failureBeforeCertification": "TEST_INVALID",
      "sourceLine": 4963,
      "pageModelFile": null,
      "pageModelLine": null
    },
    {
      "id": "statement.read-extracted-rows",
      "area": "Statement Profile",
      "route": "/Banking/Profiles/Statement#test-results",
      "purpose": "Read exact displayed extracted-row values after Test or Remap.",
      "sourceFile": "AtxSolutions/Pages/Banking/Profiles/Statement.cshtml",
      "sourceAnchor": "id=\"resultRows\"",
      "selector": "#resultRows table.statement-result-table tbody tr",
      "interaction": "Read the six visible cells in source order: Date, Description, Reference, Amount, Balance and Source. Serialize only displayed text for comparison.",
      "visibleCount": "Exactly 4 for the calibrated interpretation sample",
      "handler": "Read-only result of Test/Remap",
      "pageModelMethod": "PdfProfileExtractedRow.From",
      "transport": "Read-only DOM after AJAX fragment replacement",
      "preconditions": "Statement client controllers ready; Test Results active; Remap completed; result table present.",
      "expectedOutcome": "Four displayed rows retain calibrated order and exact mapped values.",
      "hazards": "The result table is capped at 200 rows. Use the summary count for totals and table cells only for exact calibrated rows.",
      "failureBeforeCertification": "TEST_INVALID for selector/schema mismatch; value outcomes are classified by the focused V12 actions.",
      "sourceLine": 3570,
      "pageModelFile": "AtxSolutions/Pages/Banking/Profiles/Statement.cshtml.cs",
      "pageModelLine": 2715
    },
    {
      "id": "statement.verify-wrapped-row-reconstruction",
      "area": "Statement Profile",
      "route": "/Banking/Profiles/Statement#test-results",
      "purpose": "Verify an undated, amountless continuation line is appended to the previous transaction description during manual visual Remap when wrapped-row and continuation settings are enabled.",
      "sourceFile": "AtxSolutions/Features/Banking/Services/SourceIngestion/BankStatementColumnMappingEngine.cs",
      "sourceAnchor": "CanMergeContinuationRow",
      "selector": "#resultRows table.statement-result-table tbody tr:first-child",
      "interaction": "Use the visible first result row after the calibrated complete-row plus undated-continuation sample is extracted and remapped.",
      "visibleCount": "Exactly 1 first row",
      "handler": "BankStatementColumnMappingEngine.Map -> CanMergeContinuationRow -> MergeContinuationRow -> BuildCandidate",
      "pageModelMethod": "StatementModel.OnPostRemapAsync",
      "transport": "AJAX Remap POST followed by result-table read",
      "preconditions": "TableAllowContinuationRows and wrapped-row settings enabled; calibrated synthetic image selected.",
      "expectedOutcome": "The first output row remains dated 2026-06-01 and its description is Supplier payment Additional wrapped invoice detail.",
      "hazards": "Calibration verifies row count, date, reference and source attribution. The wrapped description is behavior under test and must not be treated as sample calibration.",
      "failureBeforeCertification": "BLOCKED only when row count/date/reference/source attribution do not reproduce. After those identities pass, a missing continuation description is FAIL."
    },
    {
      "id": "statement.verify-amount-field-precedence",
      "area": "Statement Profile",
      "route": "/Banking/Profiles/Statement#test-results",
      "purpose": "Verify Signed Amount is used when present and Debit/Credit fallback produces credit minus debit when Signed Amount is blank.",
      "sourceFile": "AtxSolutions/Features/Banking/Services/SourceIngestion/BankStatementColumnMappingEngine.cs",
      "sourceAnchor": "decimal? amount = signedAmount;",
      "selector": "#resultRows table.statement-result-table tbody tr td:nth-child(4)",
      "interaction": "Read displayed Amount values from the calibrated seven-column mapping after Remap.",
      "visibleCount": "Exactly 4 amount cells",
      "handler": "BankStatementColumnMappingEngine.BuildCandidate",
      "pageModelMethod": "StatementModel.OnPostRemapAsync",
      "transport": "AJAX Remap POST followed by result-table read",
      "preconditions": "Manual fields include SignedAmount, Debit and Credit with calibrated boundaries.",
      "expectedOutcome": "Amounts are -125.50, 500.00, -74.50 and 250.00 in source order.",
      "hazards": "A blank Signed Amount intentionally falls back to absolute Credit minus absolute Debit. Service Fee is never substituted.",
      "failureBeforeCertification": "FAIL after calibrated row identity is established; TEST_INVALID for field/selector contract errors."
    },
    {
      "id": "statement.verify-running-balance-order",
      "area": "Statement Profile",
      "route": "/Banking/Profiles/Statement#test-results",
      "purpose": "Verify same-date source order and a continuous running-balance chain.",
      "sourceFile": "AtxSolutions/Features/Banking/Services/SourceIngestion/BankImportPdfTextNormalizer.cs",
      "sourceAnchor": "var expectedBalance = previous.Balance!.Value + current.Amount;",
      "selector": "#resultRows table.statement-result-table tbody tr, #resultWarnings",
      "interaction": "Read rows in rendered order and verify no running-balance variance message is present.",
      "visibleCount": "4 rows; warnings container present",
      "handler": "Balance reconciliation validation",
      "pageModelMethod": "StatementModel.OnPostRemapAsync",
      "transport": "AJAX Remap POST followed by result/warning read",
      "preconditions": "Running balance present and reconciliation enabled.",
      "expectedOutcome": "Same-date rows remain in source order and balances are 9874.50, 10374.50, 10300.00 and 10550.00 with no variance warning.",
      "hazards": "The first displayed balance is the chain baseline; reconciliation comparisons begin with the next row.",
      "failureBeforeCertification": "FAIL after calibrated row identity is established; TEST_INVALID for row/schema contract errors."
    },
    {
      "id": "statement.validation-minimum-ocr-confidence",
      "area": "Statement Profile",
      "route": "/Banking/Profiles/Statement#validation-rules",
      "purpose": "Configure the source-confirmed OCR confidence rule through its generated visible rule card.",
      "sourceFile": "AtxSolutions/wwwroot/js/banking-statement-validation-recovery.js",
      "sourceAnchor": "MinimumOcrConfidence",
      "selector": "#validationRulesList .statement-validation-rule-card:has(input[data-rule-field=\"ruleKey\"][value=\"MinimumOcrConfidence\"])",
      "interaction": "Keep enabled; select RequiresReview; fill the exact threshold through data-rule-field controls.",
      "visibleCount": "Exactly 1 matching rule card",
      "handler": "Client validation editor",
      "pageModelMethod": "StatementModel.Form.ToSettings",
      "transport": "Client state included in later AJAX Test POST",
      "preconditions": "Statement validation/recovery controller initialized.",
      "expectedOutcome": "ValidationRulesJson contains one enabled MinimumOcrConfidence RequiresReview rule with the configured threshold.",
      "hazards": "Direct writes to ValidationRulesJson bypass the visible editor and are prohibited.",
      "failureBeforeCertification": "TEST_INVALID until the generated card and normalized JSON are certified."
    },
    {
      "id": "statement.recovery-enable-limits",
      "area": "Statement Profile",
      "route": "/Banking/Profiles/Statement#recovery-strategy",
      "purpose": "Enable bounded OCR recovery and set total-attempt and time limits.",
      "sourceFile": "AtxSolutions/Pages/Banking/Profiles/Statement.cshtml",
      "sourceAnchor": "RecoveryMaximumAttempts",
      "selector": "#RecoveryEnabled, #RecoveryMaximumAttempts, #RecoveryMaximumElapsedSeconds, #RecoveryPerAttemptTimeoutSeconds, #RecoveryMinimumAcceptedRowCount, #RecoveryRetryOnRequiresReview, #RecoveryStopConfidence, #RecoveryStopRows",
      "interaction": "Edit each visible control and verify normalized RetryStrategyJson.",
      "visibleCount": "Exactly one of each control",
      "handler": "Client recovery editor",
      "pageModelMethod": "StatementModel.Form.ToSettings",
      "transport": "Client state included in later AJAX Test POST",
      "preconditions": "Advanced mode and recovery section active.",
      "expectedOutcome": "Recovery is enabled with the exact maximum attempts, budgets and stop conditions.",
      "hazards": "MaximumAttempts includes the primary extraction.",
      "failureBeforeCertification": "TEST_INVALID for missing, duplicated or stale recovery controls."
    },
    {
      "id": "statement.recovery-attempt-editor",
      "area": "Statement Profile",
      "route": "/Banking/Profiles/Statement#recovery-strategy",
      "purpose": "Configure materially different retry attempts through generated visible cards.",
      "sourceFile": "AtxSolutions/wwwroot/js/banking-statement-validation-recovery.js",
      "sourceAnchor": "statement-recovery-attempt-card",
      "selector": "#addRecoveryAttempt, #recoveryAttemptList .statement-recovery-attempt-card",
      "interaction": "Click Add Retry Attempt and edit generated data-attempt-field controls.",
      "visibleCount": "Configured attempts equal MaximumAttempts minus one",
      "handler": "Client recovery editor",
      "pageModelMethod": "StatementModel.ValidateProfileForm",
      "transport": "Client state included in later AJAX Test POST",
      "preconditions": "Recovery enabled and MaximumAttempts allows another card.",
      "expectedOutcome": "Every enabled attempt has a unique GetExecutionFingerprint.",
      "hazards": "Duplicate attempts are invalid; direct RetryStrategyJson writes are prohibited.",
      "failureBeforeCertification": "TEST_INVALID for duplicate fingerprints, hidden JSON setup or wrong cardinality."
    },
    {
      "id": "statement.run-bounded-recovery",
      "area": "Statement Profile",
      "route": "/Banking/Profiles/Statement#test-results",
      "purpose": "Execute the primary extraction and no more than the configured total recovery attempts.",
      "sourceFile": "AtxSolutions/Features/Banking/Services/SourceIngestion/BankingContentExtractionService.cs",
      "sourceAnchor": "Take(Math.Max(0, strategy.MaximumAttempts - 1))",
      "selector": "#test-results button[formaction*=\"handler=Test\"]:visible, #test-results button[formaction*=\"handler=RerunExtraction\"]:visible",
      "interaction": "Click the unique Test or Rerun Extraction action once and await the AJAX response.",
      "visibleCount": "Exactly one applicable extraction action",
      "handler": "Test / RerunExtraction",
      "pageModelMethod": "StatementModel.OnPostTestAsync / OnPostRerunExtractionAsync",
      "transport": "AJAX POST with full visible form state",
      "preconditions": "Package certified; sample, provider, rules and retry attempts configured.",
      "expectedOutcome": "Recovery history contains at most MaximumAttempts total entries and no undeclared attempt executes.",
      "hazards": "Do not click Test separately for each retry; the service owns the bounded sequence.",
      "failureBeforeCertification": "FAIL only after exact settings, response and history schema are certified."
    },
    {
      "id": "statement.read-recovery-history",
      "area": "Statement Profile",
      "route": "/Banking/Profiles/Statement#test-results",
      "purpose": "Read the complete rendered recovery history and accepted-result summary.",
      "sourceFile": "AtxSolutions/Pages/Banking/Profiles/Statement.cshtml",
      "sourceAnchor": "Accepted result:",
      "selector": "#resultRecovery .statement-recovery-history-item, #resultRecovery .alert",
      "interaction": "Open Recovery result tab and read every attempt card, badge, outcome, provider-stage candidate count and provider confidence.",
      "visibleCount": "One summary and one item per configured total attempt",
      "handler": "Server-rendered Test result",
      "pageModelMethod": "StatementModel.BuildTestResult",
      "transport": "AJAX response replacement followed by DOM read",
      "preconditions": "Extraction completed and Statement client controllers are ready after AJAX replacement.",
      "expectedOutcome": "Exactly one item is Accepted; execution state is truthful; candidate count and confidence remain the provider-stage metrics used by source scoring.",
      "hazards": "The accepted badge replaces Completed. Recovery CandidateCount is not the final post-mapping transaction count; read final mapped rows from the Test Results summary.",
      "failureBeforeCertification": "TEST_INVALID until the history schema and cardinality are certified."
    },
    {
      "id": "statement.verify-best-recovery-result",
      "area": "Statement Profile",
      "route": "/Banking/Profiles/Statement#test-results",
      "purpose": "Verify the accepted recovery attempt is the strict highest-scoring source result.",
      "sourceFile": "AtxSolutions/Features/Banking/Services/SourceIngestion/BankingContentExtractionService.cs",
      "sourceAnchor": "Score(candidate, candidateValidation) > Score(current, currentValidation)",
      "selector": "#resultRecovery .statement-recovery-history-item",
      "interaction": "Calculate the source score from rendered provider-stage attempt metrics, compare with the Accepted item, then verify the final mapped row count separately from the Test Results summary.",
      "visibleCount": "Exactly one Accepted item",
      "handler": "BankingContentExtractionService.IsBetterResult",
      "pageModelMethod": "StatementModel.BuildTestResult",
      "transport": "Read-only DOM assertion after AJAX extraction",
      "preconditions": "Calibrated rule set is ProviderSuccess, MinimumOcrConfidence and MinimumRowCount only.",
      "expectedOutcome": "Accepted attempt has the highest source score; equal scores retain the earlier attempt; final mapped rows satisfy their separate calibrated summary contract.",
      "hazards": "Do not substitute final mapped rows into the source score and do not require an attempt CandidateCount to equal the final mapped-row count.",
      "failureBeforeCertification": "FAIL after rule set, history metrics and source score formula are certified."
    },
    {
      "id": "imports.advance-preview-to-review",
      "area": "Guided Import",
      "route": "/Banking/Imports?activeTab=guided&currentStep=3",
      "purpose": "Advance the exact session from Preview to Review and generate the authoritative validation snapshot.",
      "sourceFile": "AtxSolutions/Pages/Banking/Imports.cshtml",
      "sourceAnchor": "id=\"step3AdvanceForm\"",
      "selector": "#step3AdvanceForm button[name=\"targetStep\"][value=\"4\"]:visible",
      "interaction": "Verify Step 3 visible, exact session hidden input matches, button enabled, then click the visible Continue action.",
      "visibleCount": "Exactly 1 when Step 3 is active",
      "handler": "AdvanceStep",
      "pageModelMethod": "ImportsModel.OnPostAdvanceStepAsync",
      "transport": "Full POST, GenerateAndPersistValidationAsync, redirect to Step 4",
      "preconditions": "Accepted extraction or structured preview exists; exact owned active session; preview snapshot present.",
      "expectedOutcome": "Step 4 visible with a non-null validation summary for the same session.",
      "hazards": "Do not write preview/validation hidden JSON directly. Disabled Continue is a prerequisite failure, not application FAIL.",
      "failureBeforeCertification": "TEST_INVALID or BLOCKED until session identity, button state and preview snapshot are certified.",
      "sourceLine": 820,
      "pageModelFile": "AtxSolutions/Pages/Banking/Imports.cshtml.cs",
      "pageModelLine": 639
    },
    {
      "id": "imports.advance-review-to-final",
      "area": "Guided Import",
      "route": "/Banking/Imports?activeTab=guided&currentStep=4",
      "purpose": "Advance a validation-clean exact session from Review to the final import confirmation step.",
      "sourceFile": "AtxSolutions/Pages/Banking/Imports.cshtml",
      "sourceAnchor": "id=\"btnStep4Next\"",
      "selector": "#btnStep4Next:visible",
      "interaction": "Verify validation summary can proceed, exact session hidden input matches, button enabled, then click Continue.",
      "visibleCount": "Exactly 1 when Step 4 is active",
      "handler": "AdvanceStep",
      "pageModelMethod": "ImportsModel.OnPostAdvanceStepAsync",
      "transport": "Full POST and redirect to Step 5",
      "preconditions": "ValidationSnapshotJson exists and CanProceed is true.",
      "expectedOutcome": "Step 5 visible; final summary and #guidedImportForm refer to the same exact session.",
      "hazards": "Warnings may be allowed by policy. A disabled button is not an application failure until validation state is certified.",
      "failureBeforeCertification": "TEST_INVALID or BLOCKED before validation authority is established.",
      "sourceLine": 1033,
      "pageModelFile": "AtxSolutions/Pages/Banking/Imports.cshtml.cs",
      "pageModelLine": 639
    },
    {
      "id": "imports.final-import-form",
      "area": "Guided Import",
      "route": "/Banking/Imports?activeTab=guided&currentStep=5",
      "purpose": "Resolve the exact final-import form, session transport and antiforgery token.",
      "sourceFile": "AtxSolutions/Pages/Banking/Imports.cshtml",
      "sourceAnchor": "id=\"guidedImportForm\"",
      "selector": "#guidedImportForm:visible #btnConfirmImport:visible",
      "interaction": "Verify form action targets SessionImport, exact hidden sessionId matches, validation snapshot is non-empty and button is enabled. Read form data without mutating it.",
      "visibleCount": "Exactly 1 active form and 1 visible confirm button",
      "handler": "SessionImport",
      "pageModelMethod": "ImportsModel.OnPostSessionImportAsync",
      "transport": "Full POST into ExecuteSessionImportCoreAsync",
      "preconditions": "Exact active session at Step 5; owner/artifact/account/profile/version lineage present; validation can proceed.",
      "expectedOutcome": "A final-import request uses the exact session operation ID and exact published profile version.",
      "hazards": "Do not use hiddenImportFile as the source; the persisted owner-scoped session artifact is authoritative.",
      "failureBeforeCertification": "TEST_INVALID until exact session/form/lineage prerequisites are verified.",
      "sourceLine": 1038,
      "pageModelFile": "AtxSolutions/Pages/Banking/Imports.cshtml.cs",
      "pageModelLine": 937
    },
    {
      "id": "imports.concurrent-final-import-retry",
      "area": "Guided Import",
      "route": "/Banking/Imports?activeTab=guided&currentStep=5",
      "purpose": "Submit the exact final-import form twice as a bounded same-session retry and prove operation-id idempotency.",
      "sourceFile": "AtxSolutions/Features/Banking/Services/BankImportService.cs",
      "sourceAnchor": "existingBatch = await _db.BankImportBatches.AsNoTracking()",
      "selector": "#guidedImportForm:visible",
      "interaction": "Create two independent FormData instances from the certified final form and issue two same-origin credentialed POSTs for the same session within one bounded browser-side operation. Record both final URLs/statuses.",
      "visibleCount": "One exact final form",
      "handler": "OnPostSessionImportAsync -> ExecuteSessionImportCoreAsync -> BankImportService.ExecuteOwnedImportAsync",
      "pageModelMethod": "ImportsModel.ExecuteSessionImportCoreAsync",
      "transport": "Two same-session POSTs; one operation ID; execution-strategy transaction and existing-operation lookup",
      "preconditions": "Package certified; one exact active session; one synthetic test file; final button enabled; no previous batch for the current unique operation.",
      "expectedOutcome": "At least one response resolves to one completedBatchId; any successful responses reference the same batch. Exactly one batch exists for the unique runtime filename and its transaction count equals the accepted review-row count.",
      "hazards": "This is a deliberate transport retry, not two user sessions. Never use two different session IDs or operation IDs. Response order is nondeterministic.",
      "failureBeforeCertification": "FAIL only after exact form/session and unique runtime filename are certified.",
      "sourceLine": 349,
      "pageModelFile": "AtxSolutions/Pages/Banking/Imports.cshtml.cs",
      "pageModelLine": 3260
    },
    {
      "id": "imports.history-exact-runtime-batch",
      "area": "Import History",
      "route": "/Banking/Imports?activeTab=history",
      "purpose": "Resolve the one exact batch created by the current runtime-unique synthetic filename.",
      "sourceFile": "AtxSolutions/Pages/Banking/Imports.cshtml",
      "sourceAnchor": "data-batch-id=\"@b.Id\"",
      "selector": "#historyListView .d-md-block tbody tr containing exact runtime filename",
      "interaction": "Scope to the desktop history table, require exactly one row with the runtime-unique filename, then read data-batch-id and detail URL from that row.",
      "visibleCount": "Exactly 1 desktop history row for the runtime-unique filename",
      "handler": "OnGet history model",
      "pageModelMethod": "ImportsModel.BuildImportHistoryRowsAsync",
      "transport": "Read-only DOM",
      "preconditions": "At least one final-import response completed and history loaded.",
      "expectedOutcome": "One exact batch ID; no duplicate history batch for the unique filename.",
      "hazards": "Desktop table and mobile cards are responsive duplicates. Scope to desktop table before asserting uniqueness.",
      "failureBeforeCertification": "TEST_INVALID if responsive duplicates are counted globally.",
      "sourceLine": 1155,
      "pageModelFile": "AtxSolutions/Pages/Banking/Imports.cshtml.cs",
      "pageModelLine": 2827
    },
    {
      "id": "imports.batch-detail-json",
      "area": "Import History",
      "route": "/Banking/Imports?handler=BatchDetail&batchId=<GUID>",
      "purpose": "Read authoritative batch and transaction counts for the exact tenant-owned batch and prove the same batch identifier is denied after switching to another tenant workspace.",
      "sourceFile": "AtxSolutions/Pages/Banking/Imports.cshtml.cs",
      "sourceAnchor": "OnGetBatchDetailAsync",
      "selector": "Exact history-row `button.js-batch-detail-trigger[data-batch-id='<GUID>']`; read `data-batch-detail-url` from that same element inside the browser callback.",
      "interaction": "Evaluate JavaScript against the exact detail-trigger element and call fetch(button.dataset.batchDetailUrl, { credentials: 'same-origin' }). Re-resolve the exact trigger after undo before reading the reversed detail.",
      "visibleCount": "One JSON response",
      "handler": "BatchDetail",
      "pageModelMethod": "ImportsModel.OnGetBatchDetailAsync",
      "transport": "Authenticated GET JSON",
      "preconditions": "Exact tenant-owned batch ID resolved from the owner workspace history. Cross-tenant denial uses the same authenticated manager after switching to a different tenant workspace.",
      "expectedOutcome": "Owner workspace: success=true, exact batch ID returned, current lifecycle/status returned and transaction count is tenant-scoped. Foreign workspace: success=false with message Import batch not found.; the exact owner batch must not appear in foreign Import History. Returning to the owner workspace must restore success=true for the same batch.",
      "hazards": "Do not infer denial from a missing row alone; call the source-confirmed BatchDetail handler under the foreign workspace. Do not treat 404-style tenant filtering as BLOCKED. Do not expose batch details across tenants. Use the same exact batch ID before, during and after workspace switching.",
      "failureBeforeCertification": "TEST_INVALID if workspace switching, exact batch identity, handler URL or response schema is not certified. FAIL only if the foreign tenant receives success=true or owner batch data, or the owner tenant cannot re-read its exact batch after returning.",
      "sourceLine": 2449,
      "pageModelFile": "AtxSolutions/Pages/Banking/Imports.cshtml.cs",
      "pageModelLine": 2449
    },
    {
      "id": "imports.undo-exact-runtime-batch",
      "area": "Import History",
      "route": "/Banking/Imports",
      "purpose": "Reverse the exact disposable test batch and remove its unlocked transactions.",
      "sourceFile": "AtxSolutions/Pages/Banking/Imports.cshtml",
      "sourceAnchor": "asp-page-handler=\"Undo\"",
      "selector": "Exact history-row form[action*=\"handler=Undo\"] containing input[name=\"batchId\"][value=\"<GUID>\"]",
      "interaction": "Scope to the exact runtime batch row, confirm canUndo, neutralize only the browser confirm callback, and click the visible Undo button. OnPostUndoAsync returns parameterless RedirectToPage(), so wait only for the authenticated page redirect, then navigate explicitly to /Banking/Imports?activeTab=history, re-resolve the exact batch trigger and verify Reversed status and zero transactions.",
      "visibleCount": "Exactly 1 desktop undo form for the exact batch while undo is available",
      "handler": "Undo",
      "pageModelMethod": "ImportsModel.OnPostUndoAsync -> BankImportService.UndoImportBatchAsync",
      "transport": "Full POST followed by parameterless RedirectToPage() to the default Guided tab; explicit GET back to history is required for verification.",
      "preconditions": "Exact test batch; no row posted/reconciled/locked; current batch detail says canUndo=true.",
      "expectedOutcome": "Batch status Reversed; transactionCount 0; exact test transactions deleted.",
      "hazards": "A successful click or default Guided redirect is not deletion proof. Do not wait for #historyListView immediately after Undo; it is rendered hidden on the default Guided tab. Navigate explicitly back to history and read BatchDetail. A reversed batch, operation/profile usage and audit evidence remain intentionally for traceability. Never undo the production 77-row baseline.",
      "failureBeforeCertification": "TEST_INVALID if cleanup assumes the Undo redirect remains on history or marks reversal before BatchDetail proves Reversed and zero transactions. FAIL only after exact test ownership, canUndo and the post-redirect BatchDetail response are certified.",
      "sourceLine": 1194,
      "pageModelFile": "AtxSolutions/Pages/Banking/Imports.cshtml.cs",
      "pageModelLine": 1663
    },
    {
      "id": "login.password-autocomplete",
      "area": "Login",
      "route": "/Login",
      "purpose": "Verify the active login password control advertises the browser current-password contract.",
      "sourceFile": "AtxSolutions/Pages/Login.cshtml",
      "sourceAnchor": "autocomplete=\"current-password\"",
      "selector": "#Password",
      "interaction": "Read the autocomplete attribute before entering credentials.",
      "visibleCount": "Exactly 1 visible password input.",
      "handler": "POST /Login after the read-only metadata check.",
      "pageModelMethod": "LoginModel.OnPostAsync",
      "transport": "Initial GET followed by the established authenticated login flow.",
      "preconditions": "Unauthenticated login page is available.",
      "expectedOutcome": "`#Password` has type=password and autocomplete=current-password.",
      "hazards": "Do not expand the login secret or confuse metadata proof with credential proof.",
      "failureBeforeCertification": "TEST_INVALID",
      "sourceLine": 100,
      "pageModelFile": "AtxSolutions/Pages/Login.cshtml.cs",
      "pageModelLine": 1
    },
    {
      "id": "profiles.breadcrumb-runtime",
      "area": "Banking Profiles",
      "route": "/Banking/Profiles?tab=user&status=all",
      "purpose": "Verify the catalogue breadcrumb reflects Banking / Profiles rather than a generic page label.",
      "sourceFile": "AtxSolutions/Pages/Banking/Profiles/Index.cshtml",
      "sourceAnchor": "ViewData[\"Breadcrumb\"] = \"Banking / Profiles\";",
      "selector": "nav[aria-label=\"breadcrumb\"] .breadcrumb-item",
      "interaction": "Read the rendered breadcrumb items without mutating profile state.",
      "visibleCount": "Home plus Banking plus Profiles.",
      "handler": "GET /Banking/Profiles",
      "pageModelMethod": "IndexModel.OnGetAsync",
      "transport": "Full navigation.",
      "preconditions": "Authenticated manager workspace.",
      "expectedOutcome": "Rendered breadcrumb contains Banking followed by Profiles.",
      "hazards": "Do not use page title alone as breadcrumb proof.",
      "failureBeforeCertification": "TEST_INVALID",
      "sourceLine": 7,
      "pageModelFile": "AtxSolutions/Pages/Banking/Profiles/Index.cshtml.cs",
      "pageModelLine": 1,
      "robotBindings": [
        {
          "keyword": "Verify Banking UI Closeout",
          "requiredPatterns": [
            "Go To    ${BASE_URL}/Banking/Profiles?tab=user&status=all",
            "css=nav[aria-label=\"breadcrumb\"] .breadcrumb-item >> nth=1",
            "css=nav[aria-label=\"breadcrumb\"] .breadcrumb-item >> nth=2"
          ]
        }
      ]
    },
    {
      "id": "imports.draft-profile-guidance",
      "area": "Guided Import",
      "route": "/Banking/Imports",
      "purpose": "Distinguish a workspace with retained Draft profiles but no Published import-ready profile from a genuinely empty profile workspace.",
      "sourceFile": "AtxSolutions/Pages/Banking/Imports.cshtml",
      "sourceAnchor": "Publish an Import-Ready Banking Evidence Profile",
      "selector": "h4:has-text(\"Publish an Import-Ready Banking Evidence Profile\"), a:has-text(\"Review Profile Drafts\")",
      "interaction": "Run only after a runtime prerequisite proves the workspace has managed profiles but no active profile with a Published version. Otherwise source-certify this branch and do not assert it in Chromium.",
      "visibleCount": "Exactly one heading and one Review Profile Drafts action.",
      "handler": "GET /Banking/Imports",
      "pageModelMethod": "ImportsModel.OnGetAsync",
      "transport": "Full navigation.",
      "preconditions": "No active import-ready profile exists and at least one tenant-managed profile exists. A catalogue card showing the current version as Draft is not proof because an earlier Published version may still be import-ready.",
      "expectedOutcome": "When the exact prerequisite is true, Draft-aware publication guidance is shown and Create Your First is not shown.",
      "hazards": "Never hard-code a workspace as draft-only from its card badge or name. If the lifecycle prerequisite is not proven, classify the runtime branch N/A/BLOCKED rather than FAIL.",
      "failureBeforeCertification": "TEST_INVALID",
      "sourceLine": 442,
      "pageModelFile": "AtxSolutions/Pages/Banking/Imports.cshtml.cs",
      "pageModelLine": 1,
      "robotBindings": [
        {
          "keyword": "Verify Draft-Only Guidance When Runtime Prerequisite Exists",
          "requiredPatterns": [
            "css=#pane-guided h4:has-text(\"Publish an Import-Ready Banking Evidence Profile\"):visible",
            "css=#pane-guided a:has-text(\"Review Profile Drafts\"):visible"
          ],
          "forbiddenPatterns": [
            "Basic Beside CIPC remains draft-only",
            "${DRAFT_ONLY_WORKSPACE}"
          ]
        }
      ]
    },
    {
      "id": "imports.published-version-with-current-draft",
      "area": "Guided Import",
      "route": "/Banking/Imports?activeTab=guided",
      "purpose": "Verify that a profile with an earlier Published version remains available to Guided Import even when its current working version is Draft.",
      "sourceFile": "AtxSolutions/Pages/Banking/Imports.cshtml",
      "sourceAnchor": "@if (!Model.HasProfiles)",
      "selector": "#stepPane1, #guidedProfile",
      "interaction": "Switch to the certified coexistence workspace, open Guided Import, verify Step 1 and the expected profile option, and verify empty/draft-only guidance is absent.",
      "visibleCount": "One visible Step 1 pane and one exact import-ready profile label; zero empty-profile or draft-only guidance headings.",
      "handler": "GET /Banking/Imports",
      "pageModelMethod": "ImportsModel.OnGetAsync",
      "transport": "Full navigation and read-only select inspection.",
      "preconditions": "The workspace has a profile whose earlier Published version is active while a newer Draft exists. Current Draft card state does not remove the Published import-ready version.",
      "expectedOutcome": "Guided Import renders Step 1 and includes the Published profile; it does not render Create Your First or Publish an Import-Ready guidance.",
      "hazards": "Do not infer import readiness from the current catalogue badge. Do not use a workspace name as a lifecycle assertion.",
      "failureBeforeCertification": "TEST_INVALID",
      "sourceLine": 432,
      "pageModelFile": "AtxSolutions/Pages/Banking/Imports.cshtml.cs",
      "pageModelLine": 1,
      "robotBindings": [
        {
          "keyword": "Verify Banking UI Closeout",
          "requiredPatterns": [
            "Ensure Workspace    ${COEXISTING_DRAFT_WORKSPACE}",
            "Wait For Elements State    css=#stepPane1    visible    timeout=30s",
            "Should Contain    ${available_profiles}    ${COEXISTING_PROFILE}",
            "css=#pane-guided h4:has-text(\"Publish an Import-Ready Banking Evidence Profile\"):visible",
            "css=#pane-guided h4:has-text(\"Create Your First Banking Evidence Profile\"):visible"
          ],
          "forbiddenPatterns": [
            "${DRAFT_ONLY_WORKSPACE}",
            "Application Fail    Draft-only Guided Import guidance did not distinguish unpublished profiles correctly."
          ]
        }
      ]
    },
    {
      "id": "products.stock-overview-menu-route",
      "area": "Product navigation",
      "route": "/Products/Inventory/Index?tab=overview",
      "purpose": "Verify the Product stock levels menu points to the valid inventory overview route.",
      "sourceFile": "AtxSolutions/Pages/Shared/_Layout.cshtml",
      "sourceAnchor": "href=\"/Products/Inventory/Index?tab=overview\"",
      "selector": ".workspace-menu-bar a[href=\"/Products/Inventory/Index?tab=overview\"]:has-text(\"Product stock levels\")",
      "interaction": "Resolve the scoped desktop menu anchor and read its href.",
      "visibleCount": "Exactly one scoped desktop route anchor in the DOM.",
      "handler": "GET /Products/Inventory/Index?tab=overview",
      "pageModelMethod": "Inventory.IndexModel.OnGetAsync",
      "transport": "Normal navigation.",
      "preconditions": "Authenticated Manager layout.",
      "expectedOutcome": "Menu route targets the overview and does not target the legacy no-ID detail route.",
      "hazards": "Mobile navigation may contain an equivalent duplicate; scope to workspace-menu-bar.",
      "failureBeforeCertification": "TEST_INVALID",
      "sourceLine": 2268,
      "pageModelFile": "AtxSolutions/Pages/Products/Inventory/Index.cshtml.cs",
      "pageModelLine": 1
    },
    {
      "id": "products.legacy-stock-overview-redirect",
      "area": "Product inventory",
      "route": "/Products/Inventory/ProductInventory",
      "purpose": "Verify the legacy no-ID product inventory route remains backward compatible.",
      "sourceFile": "AtxSolutions/Pages/Products/Inventory/ProductInventory.cshtml.cs",
      "sourceAnchor": "RedirectToPage(\"/Products/Inventory/Index\", new { tab = \"overview\" })",
      "selector": "Direct GET followed by URL and Inventory Management heading checks.",
      "interaction": "Navigate to the legacy route without an ID.",
      "visibleCount": "One destination inventory page.",
      "handler": "GET /Products/Inventory/ProductInventory",
      "pageModelMethod": "ProductInventoryModel.OnGetAsync(Guid? id)",
      "transport": "Server redirect.",
      "preconditions": "Authenticated manager with product access.",
      "expectedOutcome": "Final URL is /Products/Inventory/Index?tab=overview and Inventory Management loads.",
      "hazards": "A valid /ProductInventory/<guid> remains a detail route and must not be treated as legacy redirect.",
      "failureBeforeCertification": "TEST_INVALID",
      "sourceLine": 71,
      "pageModelFile": "AtxSolutions/Pages/Products/Inventory/ProductInventory.cshtml.cs",
      "pageModelLine": 59
    },
    {
      "id": "workspace.desktop-wrap-collapse",
      "area": "Desktop navigation",
      "route": "Authenticated layout",
      "purpose": "Verify the workspace menu collapses instead of rendering visible navigation on more than one row.",
      "sourceFile": "AtxSolutions/wwwroot/js/workspace-menu-bar.js",
      "sourceAnchor": "const shouldCollapse = rows > 1;",
      "selector": ".workspace-menu-bar, #workspaceMenuBarNav, .workspace-menu-nav",
      "interaction": "Measure visible direct nav-item row tops and the force-collapsed class.",
      "visibleCount": "One menu bar; zero or one visible row unless force-collapsed.",
      "handler": "Client-side layout evaluation.",
      "pageModelMethod": "N/A",
      "transport": "JavaScript readiness and resize evaluation.",
      "preconditions": "Authenticated desktop viewport.",
      "expectedOutcome": "No uncollapsed multi-row menu is visible.",
      "hazards": "A collapsed menu may have zero visible direct items; that is valid.",
      "failureBeforeCertification": "TEST_INVALID",
      "sourceLine": 78,
      "pageModelFile": "AtxSolutions/wwwroot/js/workspace-menu-bar.js",
      "pageModelLine": 1
    },
    {
      "id": "products.optional-category-colour",
      "area": "Product Categories",
      "route": "/Products/Categories",
      "purpose": "Verify optional category colour values use hidden nullable transport inputs plus separate colour pickers.",
      "sourceFile": "AtxSolutions/Pages/Products/Categories/Index.cshtml",
      "sourceAnchor": "asp-for=\"NewCategory.ColorCode\" type=\"hidden\"",
      "selector": "#new-color-code[type=hidden], #new-color-picker[type=color], #edit-color-code[type=hidden], #edit-color-picker[type=color]",
      "interaction": "Inspect DOM types only; do not submit or mutate a category.",
      "visibleCount": "Four source-confirmed controls, with modal pickers allowed to be hidden.",
      "handler": "GET /Products/Categories",
      "pageModelMethod": "IndexModel.OnGetAsync",
      "transport": "Full navigation.",
      "preconditions": "Authenticated manager with product category access.",
      "expectedOutcome": "Optional model values are hidden inputs and browser colour controls are separate.",
      "hazards": "Do not require hidden modal controls to be visible.",
      "failureBeforeCertification": "TEST_INVALID",
      "sourceLine": 323,
      "pageModelFile": "AtxSolutions/Pages/Products/Categories/Index.cshtml.cs",
      "pageModelLine": 1
    },
    {
      "id": "inventory.count-page-no-debug",
      "area": "Inventory Count",
      "route": "/Products/Inventory/Counts/Create",
      "purpose": "Verify the Count creation page loads and the removed temporary debug messages are absent from source/runtime evidence.",
      "sourceFile": "AtxSolutions/Pages/Products/Inventory/Counts/Create.cshtml",
      "sourceAnchor": "ViewData[\"Title\"] = isEdit ? $\"Stock Count {Model.Count!.CountNumber}\" : \"New Stock Count\";",
      "selector": "h2:has-text(\"New Stock Count\")",
      "interaction": "Open the page read-only and inspect the rendered heading.",
      "visibleCount": "Exactly one New Stock Count heading.",
      "handler": "GET /Products/Inventory/Counts/Create",
      "pageModelMethod": "CreateModel.OnGetAsync",
      "transport": "Full navigation.",
      "preconditions": "Authenticated manager with inventory access.",
      "expectedOutcome": "Page loads without an error view; source certification proves removed console strings remain absent.",
      "hazards": "Do not create or submit a count.",
      "failureBeforeCertification": "TEST_INVALID",
      "sourceLine": 9,
      "pageModelFile": "AtxSolutions/Pages/Products/Inventory/Counts/Create.cshtml.cs",
      "pageModelLine": 1
    },
    {
      "id": "payroll.reminders-runtime",
      "area": "Payroll Reminders",
      "route": "/Payroll/Settings/Reminders",
      "purpose": "Verify the reminder settings route loads without the historical nullable MaxAsync runtime exception.",
      "sourceFile": "AtxSolutions/Pages/Payroll/Settings/Reminders.cshtml",
      "sourceAnchor": "ViewData[\"Title\"] = \"Reminder Settings\";",
      "selector": "h1:has-text(\"Reminder Settings\")",
      "interaction": "Open the route and inspect the heading and body for historical exception text.",
      "visibleCount": "One Reminder Settings heading, or a source-confirmed locked panel without an exception.",
      "handler": "GET /Payroll/Settings/Reminders",
      "pageModelMethod": "RemindersModel.OnGetAsync",
      "transport": "Full navigation.",
      "preconditions": "Authenticated manager workspace with Payroll route access.",
      "expectedOutcome": "No ValidateLambdaArgs, nullable MaxAsync, or unhandled error content.",
      "hazards": "Entitlement lock is not an application failure if the route renders safely.",
      "failureBeforeCertification": "TEST_INVALID",
      "sourceLine": 4,
      "pageModelFile": "AtxSolutions/Pages/Payroll/Settings/Reminders.cshtml.cs",
      "pageModelLine": 1
    },
    {
      "id": "support.imap-circuit-source",
      "area": "Support email polling",
      "route": "Background support-email poll",
      "purpose": "Certify circuit-breaker failure updates and duplicate-log removal from current source.",
      "sourceFile": "AtxSolutions/Services/Support/SupportEmailPollingService.cs",
      "sourceAnchor": "UpdateCircuitBreakerFailureAsync(config.Id)",
      "selector": "Source-only contract; no live credential or provider failure is induced.",
      "interaction": "Package certification checks service and focused xUnit source anchors.",
      "visibleCount": "N/A",
      "handler": "SupportEmailPollingService.PollEmailsAsync",
      "pageModelMethod": "N/A",
      "transport": "Background IMAP service.",
      "preconditions": "Current project source matches authoritative hashes.",
      "expectedOutcome": "Circuit-breaker source proof passes; no runtime provider outage is claimed.",
      "hazards": "Do not simulate invalid credentials or external network failure in the production session.",
      "failureBeforeCertification": "TEST_INVALID",
      "sourceLine": 483,
      "pageModelFile": "AtxSolutions.Tests/Services/Support/SupportEmailPollingResilienceSourceContractTests.cs",
      "pageModelLine": 1
    },
    {
      "id": "support.imap-transient-retry-source",
      "area": "Support email polling",
      "route": "Unified IMAP fetch",
      "purpose": "Certify one bounded retry for transient transport failures while invalid credentials remain non-retryable.",
      "sourceFile": "AtxSolutions/Services/Support/EmailClient/UnifiedEmailService.cs",
      "sourceAnchor": "MaxTransientFetchAttempts = 2",
      "selector": "Source-only contract; no live credential or provider failure is induced.",
      "interaction": "Package certification checks the current source and focused xUnit source anchors.",
      "visibleCount": "N/A",
      "handler": "UnifiedEmailService.FetchUnreadEmailsAsync",
      "pageModelMethod": "N/A",
      "transport": "IMAP connection/authentication.",
      "preconditions": "Current project source matches authoritative hashes.",
      "expectedOutcome": "Exactly two total transient attempts are allowed and AuthenticationException is excluded.",
      "hazards": "Do not simulate invalid credentials or external network failure in the production session.",
      "failureBeforeCertification": "TEST_INVALID",
      "sourceLine": 22,
      "pageModelFile": "AtxSolutions.Tests/Services/Support/SupportEmailPollingResilienceSourceContractTests.cs",
      "pageModelLine": 1
    },
    {
      "id": "payment-evidence.open-profiles-tab",
      "area": "Banking Payment Evidence",
      "route": "/Banking/PaymentEvidence?activeEvidenceTab=profiles",
      "purpose": "Open the Payment Evidence Profiles workspace directly without unrelated route discovery.",
      "sourceFile": "AtxSolutions/Pages/Banking/PaymentEvidence/Index.cshtml",
      "sourceAnchor": "id=\"sub-profiles\"",
      "selector": "#pane-sub-profiles, button[data-profile-mode=\"new\"]",
      "interaction": "Navigate directly with activeEvidenceTab=profiles and wait for the Profiles pane and New Profile action.",
      "visibleCount": "Exactly one active Profiles pane and one visible New Profile button for a manager with manage permission.",
      "handler": "GET /Banking/PaymentEvidence?activeEvidenceTab=profiles",
      "pageModelMethod": "IndexModel.OnGetAsync",
      "transport": "Full navigation with server-selected active evidence tab.",
      "preconditions": "Authenticated manager in CIPC Example Holdings with PaymentEvidenceView and PaymentEvidenceManage.",
      "expectedOutcome": "The Payment Evidence Profiles pane is active and the new-profile action is available.",
      "hazards": "Do not use unrelated /Banking/Profiles catalogue controls; Payment Evidence profiles are managed on this page.",
      "failureBeforeCertification": "TEST_INVALID",
      "sourceLine": 122,
      "pageModelFile": "AtxSolutions/Pages/Banking/PaymentEvidence/Index.cshtml.cs",
      "pageModelLine": 118,
      "robotBindings": [
        {
          "keyword": "Certify Runtime Before Mutation",
          "requiredPatterns": [
            "Go To    ${BASE_URL}/Banking/PaymentEvidence?activeEvidenceTab=profiles",
            "Wait For Elements State    css=#pane-sub-profiles"
          ]
        }
      ]
    },
    {
      "id": "payment-evidence.new-profile-modal",
      "area": "Banking Payment Evidence Profiles",
      "route": "/Banking/PaymentEvidence?activeEvidenceTab=profiles",
      "purpose": "Open and reset the dedicated new Payment Evidence profile modal through its visible action.",
      "sourceFile": "AtxSolutions/Pages/Banking/PaymentEvidence/Index.cshtml",
      "sourceAnchor": "data-profile-mode=\"new\"",
      "selector": "#pane-sub-profiles button[data-bs-target=\"#paymentEvidenceProfileModal\"][data-profile-mode=\"new\"]:visible",
      "interaction": "Click the scoped New Profile button, wait for #paymentEvidenceProfileModal:visible, and verify the hidden profile ID is empty/zero before mutation.",
      "visibleCount": "Exactly one visible scoped New Profile action and one visible modal.",
      "handler": "Bootstrap modal show; resetPaymentEvidenceProfileModal() runs for data-profile-mode=new.",
      "pageModelMethod": "IndexModel.OnGetAsync",
      "transport": "Client-side modal activation; no server mutation.",
      "preconditions": "Profiles pane is active and package preflight passed.",
      "expectedOutcome": "New Payment Evidence Profile modal opens with default comma/header/date/active settings and no existing profile identity.",
      "hazards": "Do not use a global button:has-text(New Profile) selector outside #pane-sub-profiles.",
      "failureBeforeCertification": "TEST_INVALID",
      "sourceLine": 381,
      "pageModelFile": "AtxSolutions/Pages/Banking/PaymentEvidence/Index.cshtml.cs",
      "pageModelLine": 118,
      "robotBindings": [
        {
          "keyword": "Create Mapped Disposable Profile",
          "requiredPatterns": [
            "Safe Click    css=#pane-sub-profiles button[data-bs-target=\"#paymentEvidenceProfileModal\"][data-profile-mode=\"new\"]:visible",
            "Wait For Elements State    css=#paymentEvidenceProfileModal:visible"
          ]
        }
      ]
    },
    {
      "id": "payment-evidence.profile-preview-map",
      "area": "Banking Payment Evidence Profile Modal",
      "route": "/Banking/PaymentEvidence?activeEvidenceTab=profiles",
      "purpose": "Preview a synthetic CSV and configure the generated mapping grid through visible controls before saving.",
      "sourceFile": "AtxSolutions/Pages/Banking/PaymentEvidence/Index.cshtml",
      "sourceAnchor": "id=\"paymentEvidenceProfilePreviewButton\"",
      "selector": "#paymentEvidenceProfilePreviewFile, #paymentEvidenceProfilePreviewButton, #paymentEvidenceProfileMapperTable .payment-evidence-profile-mapper-select",
      "interaction": "Set the synthetic CSV, click Preview & Map CSV, wait for #paymentEvidenceProfilePreviewArea, verify row/column summary and visible mapper selections, and change mapper selects only through their generated controls.",
      "visibleCount": "One file input, one preview button, one mapper table, and one generated select per source column after preview.",
      "handler": "PreviewPaymentEvidenceProfile",
      "pageModelMethod": "IndexModel.OnPostPreviewPaymentEvidenceProfileAsync",
      "transport": "AJAX multipart POST via fetch('?handler=PreviewPaymentEvidenceProfile'); JSON response renders the mapping grid.",
      "preconditions": "Modal is open; sample is CSV; profile name/default CSV settings are present.",
      "expectedOutcome": "Preview JSON succeeds, representative rows render, aliases map expected columns, and MappingDefinitionJson is synchronized.",
      "hazards": "Do not write MappingDefinitionJson directly. Wait for AJAX completion and generated mapper controls.",
      "failureBeforeCertification": "TEST_INVALID",
      "sourceLine": 640,
      "pageModelFile": "AtxSolutions/Pages/Banking/PaymentEvidence/Index.cshtml.cs",
      "pageModelLine": 235,
      "robotBindings": [
        {
          "keyword": "Create Mapped Disposable Profile",
          "requiredPatterns": [
            "Upload File By Selector    css=#paymentEvidenceProfilePreviewFile",
            "Safe Click    css=#paymentEvidenceProfilePreviewButton",
            "Mapper Count Should Be Twelve"
          ]
        }
      ]
    },
    {
      "id": "payment-evidence.save-profile",
      "area": "Banking Payment Evidence Profile Modal",
      "route": "/Banking/PaymentEvidence?activeEvidenceTab=profiles",
      "purpose": "Create the exact disposable Payment Evidence profile after visible preview/mapping.",
      "sourceFile": "AtxSolutions/Pages/Banking/PaymentEvidence/Index.cshtml",
      "sourceAnchor": "asp-page-handler=\"SavePaymentEvidenceProfile\"",
      "selector": "#paymentEvidenceProfileFormElement button[type=\"submit\"]:visible",
      "interaction": "Submit the modal only after profile name, visible mappings, duplicate behavior and classification hints are synchronized.",
      "visibleCount": "Exactly one visible Create Profile/Update Profile submit button.",
      "handler": "SavePaymentEvidenceProfile",
      "pageModelMethod": "IndexModel.OnPostSavePaymentEvidenceProfileAsync",
      "transport": "Full POST followed by redirect to the Profiles tab on success.",
      "preconditions": "Unique disposable profile name; successful profile preview; required mappings present.",
      "expectedOutcome": "One tenant-owned active PaymentEvidenceImportProfile is created and the success message is shown.",
      "hazards": "Payment Evidence profiles do not use Statement Draft/Published lifecycle. Record the actual active profile contract.",
      "failureBeforeCertification": "TEST_INVALID",
      "sourceLine": 586,
      "pageModelFile": "AtxSolutions/Pages/Banking/PaymentEvidence/Index.cshtml.cs",
      "pageModelLine": 170,
      "robotBindings": [
        {
          "keyword": "Create Mapped Disposable Profile",
          "requiredPatterns": [
            "Safe Click    css=#paymentEvidenceProfileFormElement button[type=\"submit\"]:visible",
            "Capture Exact Profile Identity"
          ]
        }
      ]
    },
    {
      "id": "payment-evidence.find-exact-profile",
      "area": "Banking Payment Evidence Profiles",
      "route": "/Banking/PaymentEvidence?activeEvidenceTab=profiles",
      "purpose": "Resolve the exact disposable Payment Evidence profile card and its own ID after save.",
      "sourceFile": "AtxSolutions/Pages/Banking/PaymentEvidence/Index.cshtml",
      "sourceAnchor": "href=\"/Banking/PaymentEvidence?activeEvidenceTab=profiles&paymentEvidenceProfileId=@profile.Id\"",
      "selector": "Exact #pane-sub-profiles .list-group-item containing a direct .fw-semibold profile-name match.",
      "interaction": "Scope to the exact generated profile name, require one row, and parse the GUID from that row's Edit href or delete input.",
      "visibleCount": "Exactly one exact disposable profile row.",
      "handler": "GET Profiles tab",
      "pageModelMethod": "IndexModel.OnGetAsync",
      "transport": "Rendered profile list.",
      "preconditions": "Save succeeded and redirect completed.",
      "expectedOutcome": "The exact active profile is present once and its GUID is captured.",
      "hazards": "Do not use partial :has-text matching that can cross profile names.",
      "failureBeforeCertification": "TEST_INVALID",
      "sourceLine": 407,
      "pageModelFile": "AtxSolutions/Pages/Banking/PaymentEvidence/Index.cshtml.cs",
      "pageModelLine": 118,
      "robotBindings": [
        {
          "keyword": "Capture Exact Profile Identity",
          "requiredPatterns": [
            "paymentEvidenceProfileId=([0-9a-f-]{36})",
            "Record Profile Created    ${PROFILE_ID}"
          ]
        }
      ]
    },
    {
      "id": "payment-evidence.open-exact-profile",
      "area": "Banking Payment Evidence Profiles",
      "route": "/Banking/PaymentEvidence?activeEvidenceTab=profiles&paymentEvidenceProfileId=<GUID>",
      "purpose": "Reopen the exact saved profile and verify persisted mapping/settings.",
      "sourceFile": "AtxSolutions/Pages/Banking/PaymentEvidence/Index.cshtml",
      "sourceAnchor": "paymentEvidenceProfileId=@profile.Id",
      "selector": "Exact profile row >> a[href*=\"activeEvidenceTab=profiles\"][href*=\"paymentEvidenceProfileId=<GUID>\"]",
      "interaction": "Click the exact row's Edit action, wait for the modal, and read live form properties plus MappingDefinitionJson.",
      "visibleCount": "Exactly one scoped Edit action.",
      "handler": "GET with paymentEvidenceProfileId",
      "pageModelMethod": "IndexModel.OnGetAsync -> InitializePaymentEvidenceProfileFormAsync",
      "transport": "Full navigation; server hydrates the exact profile and client opens the edit modal.",
      "preconditions": "Exact profile GUID was captured.",
      "expectedOutcome": "Name, active state, duplicate action, classification hints and all required mapping columns persist.",
      "hazards": "The sample file itself is not persisted by this profile editor; do not require file-input restoration.",
      "failureBeforeCertification": "TEST_INVALID",
      "sourceLine": 428,
      "pageModelFile": "AtxSolutions/Pages/Banking/PaymentEvidence/Index.cshtml.cs",
      "pageModelLine": 763,
      "robotBindings": [
        {
          "keyword": "Reopen And Verify Exact Profile",
          "requiredPatterns": [
            "paymentEvidenceProfileId=${PROFILE_ID}",
            "Validate And Record Saved Mapping"
          ]
        }
      ]
    },
    {
      "id": "payment-evidence.import-preview",
      "area": "Banking Payment Evidence Guided Import",
      "route": "/Banking/PaymentEvidence?activeEvidenceTab=import",
      "purpose": "Use the exact disposable profile to preview representative payment evidence without executing the import.",
      "sourceFile": "AtxSolutions/Pages/Banking/PaymentEvidence/Index.cshtml",
      "sourceAnchor": "asp-page-handler=\"UploadPreview\"",
      "selector": "#PreviewProfileId, #PreviewFile, form[action*=\"handler=UploadPreview\"] button[type=\"submit\"]:visible",
      "interaction": "Select the exact profile GUID, upload the synthetic CSV and submit Preview Import. Result reading is a separate action contract.",
      "visibleCount": "After the exact profile exists: one profile select, one CSV input and one Preview Import button.",
      "handler": "UploadPreview",
      "pageModelMethod": "IndexModel.OnPostUploadPreviewAsync",
      "transport": "Multipart full POST; server creates an owner-scoped temporary preview artifact and renders preview state.",
      "preconditions": "At least one active Payment Evidence profile exists; the exact disposable profile GUID was captured; sample remains available. The Guided Import controls render only when HasPaymentEvidenceProfiles is true.",
      "expectedOutcome": "UploadPreview completes and the exact Preview Results render location becomes available.",
      "hazards": "Do not require controls during initial zero-profile preflight. Do not read preview results through an ancestor :has() card selector. Do not execute import.",
      "failureBeforeCertification": "TEST_INVALID",
      "sourceLine": 238,
      "pageModelFile": "AtxSolutions/Pages/Banking/PaymentEvidence/Index.cshtml.cs",
      "pageModelLine": 425,
      "robotBindings": [
        {
          "keyword": "Preview And Execute Exact Import",
          "requiredPatterns": [
            "Select Options By    css=#PreviewProfileId    value    ${PROFILE_ID}",
            "Upload File By Selector    css=#PreviewFile",
            "Safe Click    css=form[action*=\"handler=UploadPreview\"] button[type=\"submit\"]:visible"
          ]
        }
      ]
    },
    {
      "id": "payment-evidence.delete-exact-profile",
      "area": "Banking Payment Evidence Profiles",
      "route": "/Banking/PaymentEvidence?activeEvidenceTab=profiles",
      "purpose": "Delete only the exact disposable profile created by the test.",
      "sourceFile": "AtxSolutions/Pages/Banking/PaymentEvidence/Index.cshtml",
      "sourceAnchor": "asp-page-handler=\"DeletePaymentEvidenceProfile\"",
      "selector": "Exact disposable profile row >> form[action*=\"handler=DeletePaymentEvidenceProfile\"] input[name=\"profileId\"][value=\"<GUID>\"] plus its visible Delete button",
      "interaction": "Return to Profiles, scope by exact name and GUID, accept the confirmation, submit Delete, and verify the exact row is absent.",
      "visibleCount": "Exactly one delete form for the exact disposable profile.",
      "handler": "DeletePaymentEvidenceProfile",
      "pageModelMethod": "IndexModel.OnPostDeletePaymentEvidenceProfileAsync -> PaymentEvidenceImportService.DeleteProfileAsync",
      "transport": "Full POST followed by redirect to Profiles.",
      "preconditions": "Profile was created by this test, remains unreferenced by any batch, and exact GUID is known.",
      "expectedOutcome": "Exact disposable profile is deleted; protected profiles and historical batches remain untouched.",
      "hazards": "A successful no-op is not deletion proof. Record actual pre-delete existence and post-delete absence.",
      "failureBeforeCertification": "TEST_INVALID",
      "sourceLine": 433,
      "pageModelFile": "AtxSolutions/Pages/Banking/PaymentEvidence/Index.cshtml.cs",
      "pageModelLine": 335,
      "robotBindings": [
        {
          "keyword": "Delete Exact Disposable Profile",
          "requiredPatterns": [
            "input[name=\"profileId\"][value=\"${PROFILE_ID}\"]",
            "Record Profile Deleted    ${PROFILE_ID}"
          ]
        }
      ]
    },
    {
      "id": "payment-evidence.read-import-preview-results",
      "area": "Banking Payment Evidence Guided Import",
      "route": "/Banking/PaymentEvidence?activeEvidenceTab=import",
      "purpose": "Read the exact direct-child Preview Results card after UploadPreview without matching its ancestor cards.",
      "sourceFile": "AtxSolutions/Pages/Banking/PaymentEvidence/Index.cshtml",
      "sourceAnchor": "<h6 class=\"mb-1\"><i class=\"bi bi-table me-2 text-primary\"></i>Preview Results</h6>",
      "selector": "#pane-sub-import > div.card.border-0.shadow-sm:not(.mb-4)",
      "interaction": "Require exactly one direct-child preview results card, then read its header, badges, warning and Execute Import enabled state without clicking Execute Import.",
      "visibleCount": "Exactly one after a successful UploadPreview; zero before preview.",
      "handler": "Rendered result of UploadPreview",
      "pageModelMethod": "IndexModel.OnPostUploadPreviewAsync",
      "transport": "Server-rendered full POST response.",
      "preconditions": "UploadPreview completed with the exact active profile and synthetic sample.",
      "expectedOutcome": "Five rows detected, five classified, zero unknown, one duplicate, warning visible and Execute Import enabled.",
      "hazards": "The broad selector .card:has(h6:has-text(\"Preview Results\")) matches nested ancestor cards and is prohibited.",
      "failureBeforeCertification": "TEST_INVALID",
      "sourceLine": 286,
      "pageModelFile": "AtxSolutions/Pages/Banking/PaymentEvidence/Index.cshtml.cs",
      "pageModelLine": 425,
      "robotBindings": [
        {
          "keyword": "Preview And Execute Exact Import",
          "requiredPatterns": [
            "css=#pane-sub-import > div.card.border-0.shadow-sm:not(.mb-4)",
            "Preview Results Card Should Be Unique",
            "Record Import Preview    5    5    0    1"
          ]
        }
      ]
    },
    {
      "id": "payment-evidence.execute-import",
      "area": "Banking Payment Evidence Guided Import",
      "route": "/Banking/PaymentEvidence?activeEvidenceTab=import",
      "purpose": "Execute the exact previewed Payment Evidence import and follow the server redirect to the exact batch review workspace.",
      "sourceFile": "AtxSolutions/Pages/Banking/PaymentEvidence/Index.cshtml",
      "sourceAnchor": "<form method=\"post\" asp-page-handler=\"ExecuteImport\"",
      "selector": "#pane-sub-import > div.card.border-0.shadow-sm:not(.mb-4) form[action*=\"handler=ExecuteImport\"] button[type=\"submit\"]:visible",
      "interaction": "Click Execute Import once inside the exact Preview Results card after confirming the hidden exact profile ID and enabled state.",
      "visibleCount": "Exactly one after a valid preview.",
      "handler": "ExecuteImport",
      "pageModelMethod": "IndexModel.OnPostExecuteImportAsync",
      "pageModelFile": "AtxSolutions/Pages/Banking/PaymentEvidence/Index.cshtml.cs",
      "transport": "Full POST; owner-scoped preview artifact is validated, imported and promoted; response redirects to /Banking/PaymentEvidence/Batch?id={batchId}.",
      "preconditions": "Exact active disposable profile, valid preview state, owner-scoped artifact and warning-only CanProceed=true result.",
      "expectedOutcome": "One InReview batch is created and the browser reaches its exact review workspace.",
      "hazards": "Do not click twice. Retry/idempotency is a separate scope. Do not use a broad form selector outside the exact Preview Results card.",
      "failureBeforeCertification": "TEST_INVALID",
      "sourceLine": 341,
      "robotBindings": [
        {
          "keyword": "Preview And Execute Exact Import",
          "requiredPatterns": [
            "Safe Click    ${preview_card} >> css=form[action*=\"handler=ExecuteImport\"] button[type=\"submit\"]:visible",
            "Wait For Elements State    css=#paymentEvidenceBatchWorkspace    visible",
            "Capture Exact Batch Identity"
          ]
        }
      ]
    },
    {
      "id": "payment-evidence.read-exact-batch-review",
      "area": "Banking Payment Evidence Review",
      "route": "/Banking/PaymentEvidence/Batch?id={batchId}",
      "purpose": "Verify the exact imported batch review workspace, batch status, totals and imported row classifications.",
      "sourceFile": "AtxSolutions/Pages/Banking/PaymentEvidence/Batch.cshtml",
      "sourceAnchor": "<div id=\"paymentEvidenceBatchWorkspace\">",
      "selector": "#paymentEvidenceBatchWorkspace, .pe-review-command-strip, .pe-review-table-card",
      "interaction": "Read the exact batch page reached from ExecuteImport; validate file name, InReview status, 5 rows, 5 unresolved, 0 exceptions and expected row-kind distribution.",
      "visibleCount": "One exact batch workspace, one command strip and one desktop row table at the certified viewport.",
      "handler": "GET",
      "pageModelMethod": "BatchModel.OnGetAsync",
      "pageModelFile": "AtxSolutions/Pages/Accounting/Customers/Receipts/Batch.cshtml.cs",
      "transport": "Owner-scoped server-rendered GET using the exact batch GUID.",
      "preconditions": "ExecuteImport redirect completed and exact batch GUID was captured from the absolute URL.",
      "expectedOutcome": "Five imported rows render in source order: two CustomerPayment, one FeeOrCharge, one Refund and one PayoutOrSettlement; batch remains InReview.",
      "hazards": "Do not interpret suggestions as row-kind badges. Scope counts to .pe-review-table-card tbody rows.",
      "failureBeforeCertification": "TEST_INVALID",
      "sourceLine": 463,
      "robotBindings": [
        {
          "keyword": "Verify Exact Imported Batch Review",
          "requiredPatterns": [
            "App Should Equal    ${file_name}    ${SAMPLE_FILE_NAME}",
            "Record Batch Review    5    5    0    ${customer}    ${fee}    ${refund}    ${payout}",
            "css=.pe-review-table-card tbody tr"
          ]
        }
      ]
    },
    {
      "id": "payment-evidence.delete-exact-batch",
      "area": "Banking Payment Evidence Review",
      "route": "/Banking/PaymentEvidence/Batch?id={batchId}",
      "purpose": "Delete the exact disposable InReview Payment Evidence batch and prove the exact GUID no longer opens.",
      "sourceFile": "AtxSolutions/Pages/Banking/PaymentEvidence/Batch.cshtml",
      "sourceAnchor": "asp-page-handler=\"Delete\" asp-route-id=\"@Model.Id\"",
      "selector": "#paymentEvidenceBatchWorkspace form[action*=\"handler=Delete\"] button[type=\"submit\"]:visible",
      "interaction": "Confirm and submit the one Delete action on the exact captured batch, then navigate to the exact batch URL and require the owner-scoped not-found redirect.",
      "visibleCount": "Exactly one while the exact batch is InReview.",
      "handler": "Delete",
      "pageModelMethod": "BatchModel.OnPostDeleteAsync",
      "pageModelFile": "AtxSolutions/Pages/Accounting/Customers/Receipts/Batch.cshtml.cs",
      "transport": "Full POST calls UndoBatchAsync and redirects to Payment Evidence landing.",
      "preconditions": "Captured exact batch GUID, InReview status and no receipt-linked rows.",
      "expectedOutcome": "All five disposable rows and the exact batch are deleted; direct exact-GUID access redirects with Payment evidence batch not found.",
      "hazards": "Do not delete historical batches. Bind cleanup to the exact captured GUID and current URL.",
      "failureBeforeCertification": "TEST_INVALID",
      "sourceLine": 524,
      "robotBindings": [
        {
          "keyword": "Delete Exact Disposable Batch",
          "requiredPatterns": [
            "css=#paymentEvidenceBatchWorkspace form[action*=\"handler=Delete\"] button[type=\"submit\"]:visible",
            "${BASE_URL}/Banking/PaymentEvidence/Batch?id=${BATCH_ID}",
            "Record Batch Deleted    ${BATCH_ID}"
          ]
        }
      ]
    },
    {
      "id": "payment-evidence.execute-import-double-submit",
      "area": "Banking Payment Evidence Guided Import",
      "route": "/Banking/PaymentEvidence?activeEvidenceTab=import",
      "purpose": "Submit the exact ExecuteImport form twice from one preview operation to verify retry safety.",
      "sourceFile": "AtxSolutions/Pages/Banking/PaymentEvidence/Index.cshtml",
      "sourceAnchor": "<form method=\"post\" asp-page-handler=\"ExecuteImport\"",
      "selector": "#pane-sub-import > div.card.border-0.shadow-sm:not(.mb-4) form[action*=\"handler=ExecuteImport\"]",
      "interaction": "Use one static source-certified browser script against the exact form element to issue two concurrent same-origin POST requests with separate FormData instances.",
      "visibleCount": "Exactly one exact ExecuteImport form after valid preview.",
      "handler": "ExecuteImport",
      "pageModelMethod": "IndexModel.OnPostExecuteImportAsync",
      "pageModelFile": "AtxSolutions/Pages/Banking/PaymentEvidence/Index.cshtml.cs",
      "transport": "Two concurrent same-session POSTs using the same owner-scoped preview operation and artifact.",
      "preconditions": "Exact disposable profile, valid preview, CanProceed=true and one exact ExecuteImport form.",
      "expectedOutcome": "Both bounded responses resolve to the same exact Payment Evidence batch GUID with no application error and no second persisted batch.",
      "hazards": "No dynamic JavaScript arguments, no URL regex construction and no unrelated form. A missing batch response, generic application error or two different batch GUIDs is an application failure.",
      "failureBeforeCertification": "TEST_INVALID",
      "sourceLine": 341,
      "robotBindings": [
        {
          "keyword": "Preview And Submit Exact Import Twice",
          "requiredPatterns": [
            "${responses}=    Evaluate JavaScript    ${execute_form}",
            "Analyze Retry Responses    ${responses}",
            "Assert Retry Analysis    ${analysis}"
          ]
        }
      ]
    },
    {
      "id": "payment-evidence.same-operation-idempotency-source",
      "area": "Banking Payment Evidence service and database",
      "route": "PaymentEvidenceImportService.ExecuteImportAsync",
      "purpose": "Certify the pre-check, unique owner-operation fence and exact winning-batch recovery used by concurrent retry execution.",
      "sourceFile": "AtxSolutions/Features/Banking/Services/PaymentEvidenceImportService.cs",
      "sourceAnchor": "catch (DbUpdateException ex) when (IsConcurrentOperationUniqueViolation(ex))",
      "selector": "Source-certified contract plus runtime double-submit.",
      "interaction": "Certify the existing-batch pre-check, SQL Server 2601/2627 filter, rollback and detach of the losing attempt, then exact tenant/manager/operation/source-artifact reload of the committed winning batch after the owned transaction has unwound.",
      "visibleCount": "N/A",
      "handler": "ExecuteImportAsync",
      "pageModelMethod": "PaymentEvidenceImportBatchConfiguration.Configure",
      "pageModelFile": "AtxSolutions/Data/Configurations/Banking/PaymentEvidenceImportBatchConfiguration.cs",
      "transport": "EF pre-check plus database unique index UX_PaymentEvidenceImportBatches_Owner_OperationId; the losing request returns the exact committed winner rather than a generic error.",
      "preconditions": "Current project hashes match V51; two requests submit the same owner-scoped preview operation and artifact.",
      "expectedOutcome": "Both same-operation requests complete successfully with the same exact batch ID; one batch and one row set persist, and the losing attempt is detached without promoting or duplicating data.",
      "hazards": "Only SQL Server unique-key errors 2601/2627 may enter recovery. The winning batch must match tenant, manager, operation and source artifact. If no exact winner exists, recovery fails safely with PE-IMPORT-IDEMPOTENCY.",
      "failureBeforeCertification": "TEST_INVALID until the V51 source hash and exact recovery predicates are certified",
      "sourceLine": 625,
      "robotBindings": [
        {
          "keyword": "Preview And Submit Exact Import Twice",
          "requiredPatterns": [
            "# ATX-ACTION: payment-evidence.same-operation-idempotency-source",
            "Analyze Retry Responses    ${responses}"
          ]
        }
      ]
    },
    {
      "id": "payment-evidence.verify-single-active-batch",
      "area": "Banking Payment Evidence landing",
      "route": "/Banking/PaymentEvidence?activeEvidenceTab=import",
      "purpose": "Verify retry produced exactly one active batch entry for the exact synthetic evidence filename and captured batch GUID.",
      "sourceFile": "AtxSolutions/Pages/Banking/PaymentEvidence/Index.cshtml",
      "sourceAnchor": "<h6 class=\"mb-1\"><i class=\"bi bi-clock-history me-2 text-warning\"></i>Active Batches</h6>",
      "selector": "#pane-sub-import .list-group-item:has-text(\"${SAMPLE_FILE_NAME}\")",
      "interaction": "Reload the import pane and count exact matching active-batch entries and the exact Resume href.",
      "visibleCount": "Exactly one.",
      "handler": "GET",
      "pageModelMethod": "IndexModel.OnGetAsync",
      "pageModelFile": "AtxSolutions/Pages/Banking/PaymentEvidence/Index.cshtml.cs",
      "transport": "Owner-scoped server-rendered active batch list.",
      "preconditions": "Concurrent retry analysis captured two successful responses resolving to one exact batch GUID.",
      "expectedOutcome": "One matching active batch and one exact Resume link.",
      "hazards": "Do not count preview cards or historical completed batches. Scope to active .list-group-item entries.",
      "failureBeforeCertification": "TEST_INVALID",
      "sourceLine": 160,
      "robotBindings": [
        {
          "keyword": "Verify Single Active Batch For Retry",
          "requiredPatterns": [
            "css=#pane-sub-import .list-group-item:has-text(\"${SAMPLE_FILE_NAME}\")",
            "a[href*=\"/Banking/PaymentEvidence/Batch\"][href*=\"${BATCH_ID}\"]",
            "Record Single Active Batch    ${BATCH_ID}"
          ]
        }
      ]
    },
    {
      "id": "payment-evidence.owner-batch-access",
      "area": "Banking Payment Evidence Review",
      "route": "/Banking/PaymentEvidence/Batch?id=<GUID>",
      "purpose": "Prove the exact disposable Payment Evidence batch is accessible in its owner workspace before the tenant switch.",
      "sourceFile": "AtxSolutions/Pages/Banking/PaymentEvidence/Batch.cshtml",
      "sourceAnchor": "id=\"paymentEvidenceBatchWorkspace\"",
      "selector": "#paymentEvidenceBatchWorkspace, .pe-review-command-strip h5.pe-file-name",
      "interaction": "Remain on the exact redirected batch page, verify its GUID, filename, InReview state and five rows.",
      "visibleCount": "Exactly one owner batch workspace.",
      "handler": "GET /Banking/PaymentEvidence/Batch?id=<GUID>",
      "pageModelMethod": "BatchModel.OnGetAsync",
      "transport": "Full GET with tenant-scoped service lookup.",
      "preconditions": "Exact disposable batch was created in CIPC Example Holdings.",
      "expectedOutcome": "Owner batch review renders exactly once.",
      "hazards": "Do not reuse a historical batch or infer ownership from filename alone; retain exact GUID.",
      "failureBeforeCertification": "TEST_INVALID",
      "sourceLine": 460,
      "pageModelFile": "AtxSolutions/Pages/Accounting/Customers/Receipts/Batch.cshtml.cs",
      "pageModelLine": 110,
      "robotBindings": [
        {
          "keyword": "Verify Payment Evidence Ownership And Cross Tenant Security",
          "requiredPatterns": [
            "App Should Contain    ${owner_url}    id=${BATCH_ID}",
            "Record Owner Security Access    ${PROFILE_ID}    ${BATCH_ID}    ${owner_file}"
          ]
        }
      ]
    },
    {
      "id": "payment-evidence.owner-lineage-source",
      "area": "Banking Payment Evidence Import Service",
      "route": "source contract",
      "purpose": "Certify tenant, manager, user, operation, source artifact and exact profile ownership for the disposable Payment Evidence batch.",
      "sourceFile": "AtxSolutions/Features/Banking/Services/PaymentEvidenceImportService.cs",
      "sourceAnchor": "ManagerId = context.ManagerId,",
      "selector": "Source-only contract; no browser selector.",
      "interaction": "Package certification verifies the current service hashes and ownership assignments before Chromium.",
      "visibleCount": "N/A source contract.",
      "handler": "PaymentEvidenceImportService.ExecuteImportAsync",
      "pageModelMethod": "IndexModel.OnPostExecuteImportAsync",
      "transport": "Owner-scoped service execution and EF persistence.",
      "preconditions": "Current project hashes match V37.",
      "expectedOutcome": "CreateImportBatch persists TenantId, ManagerId, OperationId, SourceArtifactId and ProfileId from the certified context.",
      "hazards": "Browser UI does not prove database-at-rest lineage; report this as source-certified.",
      "failureBeforeCertification": "TEST_INVALID",
      "sourceLine": 1842,
      "pageModelFile": "AtxSolutions/Pages/Banking/PaymentEvidence/Index.cshtml.cs",
      "pageModelLine": 528,
      "robotBindings": [
        {
          "keyword": "Verify Payment Evidence Ownership And Cross Tenant Security",
          "requiredPatterns": [
            "Record Source Lineage Certified    ${PROFILE_ID}    ${BATCH_ID}"
          ]
        }
      ]
    },
    {
      "id": "payment-evidence.foreign-profile-denial",
      "area": "Banking Payment Evidence Profiles",
      "route": "/Banking/PaymentEvidence?activeEvidenceTab=profiles",
      "purpose": "Prove the exact disposable owner profile is not listed in a different tenant workspace.",
      "sourceFile": "AtxSolutions/Pages/Banking/PaymentEvidence/Index.cshtml.cs",
      "sourceAnchor": "GetProfilesAsync(ActiveTenantId)",
      "selector": "Exact generated profile-name row in #pane-sub-profiles.",
      "interaction": "Switch to Basic Beside CIPC, open Payment Evidence profiles, and require exact profile row count zero.",
      "visibleCount": "Zero foreign profile rows.",
      "handler": "IndexModel.OnGetAsync",
      "pageModelMethod": "IndexModel.LoadPaymentEvidenceWorkspaceAsync",
      "transport": "Full GET scoped by ActiveTenantId.",
      "preconditions": "Owner profile GUID/name captured; foreign workspace exists.",
      "expectedOutcome": "Exact profile is absent in the foreign workspace.",
      "hazards": "Do not treat a missing foreign workspace as PASS; classify BLOCKED.",
      "failureBeforeCertification": "TEST_INVALID",
      "sourceLine": 647,
      "pageModelFile": "AtxSolutions/Pages/Banking/PaymentEvidence/Index.cshtml.cs",
      "pageModelLine": 641,
      "robotBindings": [
        {
          "keyword": "Verify Payment Evidence Ownership And Cross Tenant Security",
          "requiredPatterns": [
            "Switch To Workspace    ${FOREIGN_WORKSPACE}",
            "${foreign_profile_count}=    Exact Profile Row Count",
            "Record Foreign Profile Denial    ${PROFILE_ID}    ${foreign_profile_count}"
          ]
        }
      ]
    },
    {
      "id": "payment-evidence.foreign-batch-denial",
      "area": "Banking Payment Evidence Review",
      "route": "/Banking/PaymentEvidence/Batch?id=<GUID>",
      "purpose": "Prove direct access to the exact owner batch is denied in a different tenant workspace.",
      "sourceFile": "AtxSolutions/Features/Banking/Services/PaymentEvidenceImportService.cs",
      "sourceAnchor": "Payment evidence batch not found.",
      "selector": "#pane-sub-import .alert-danger:visible after tenant-scoped redirect.",
      "interaction": "Navigate directly to the exact batch GUID while the foreign workspace is active and verify no batch workspace plus the not-found message.",
      "visibleCount": "Zero #paymentEvidenceBatchWorkspace and one not-found alert.",
      "handler": "BatchModel.OnGetAsync",
      "pageModelMethod": "PaymentEvidenceImportService.GetBatchAsync",
      "transport": "Full GET; BatchModel redirects to Payment Evidence index when tenant-owned batch lookup fails.",
      "preconditions": "Foreign workspace active and exact owner batch GUID captured.",
      "expectedOutcome": "No owner batch data is rendered; Payment evidence batch not found is shown.",
      "hazards": "A generic navigation/selector failure is TEST_INVALID, not a security PASS.",
      "failureBeforeCertification": "TEST_INVALID",
      "sourceLine": 644,
      "pageModelFile": "AtxSolutions/Pages/Accounting/Customers/Receipts/Batch.cshtml.cs",
      "pageModelLine": 431,
      "robotBindings": [
        {
          "keyword": "Verify Payment Evidence Ownership And Cross Tenant Security",
          "requiredPatterns": [
            "Go To    ${BASE_URL}/Banking/PaymentEvidence/Batch?id=${BATCH_ID}",
            "Record Foreign Batch Denial    ${BATCH_ID}    ${foreign_message}"
          ]
        }
      ]
    },
    {
      "id": "payment-evidence.owner-access-restored",
      "area": "Banking Payment Evidence Review",
      "route": "/Banking/PaymentEvidence/Batch?id=<GUID>",
      "purpose": "Prove owner access to the exact batch is restored after returning from the foreign workspace.",
      "sourceFile": "AtxSolutions/Pages/Banking/PaymentEvidence/Batch.cshtml",
      "sourceAnchor": "class=\"mb-0 text-truncate pe-file-name\"",
      "selector": "#paymentEvidenceBatchWorkspace .pe-file-name",
      "interaction": "Switch back to CIPC Example Holdings, reopen the exact batch GUID and verify the exact filename.",
      "visibleCount": "Exactly one owner batch workspace and filename.",
      "handler": "GET /Banking/PaymentEvidence/Batch?id=<GUID>",
      "pageModelMethod": "BatchModel.OnGetAsync",
      "transport": "Full GET under restored ActiveTenantId.",
      "preconditions": "Foreign denial passed and owner workspace can be restored.",
      "expectedOutcome": "Owner batch renders again with the exact filename.",
      "hazards": "Cleanup may run only after owner access is restored.",
      "failureBeforeCertification": "TEST_INVALID",
      "sourceLine": 468,
      "pageModelFile": "AtxSolutions/Pages/Accounting/Customers/Receipts/Batch.cshtml.cs",
      "pageModelLine": 110,
      "robotBindings": [
        {
          "keyword": "Verify Payment Evidence Ownership And Cross Tenant Security",
          "requiredPatterns": [
            "Switch To Workspace    ${TARGET_WORKSPACE}",
            "Record Owner Security Return    ${BATCH_ID}    ${owner_after_file}"
          ]
        }
      ]
    },
    {
      "id": "imports.step1-cancel-overview",
      "area": "Guided Banking Import",
      "route": "/Banking/Imports?activeTab=guided&currentStep=1",
      "purpose": "Verify the no-session Step 1 Cancel action returns to Banking Overview without creating an ImportSession.",
      "sourceFile": "AtxSolutions/Pages/Banking/Imports.cshtml",
      "sourceAnchor": "asp-page=\"/Banking/Overview\"",
      "selector": "a[data-guided-cancel-import][href=\"/Banking/Overview\"]:visible",
      "interaction": "Resolve exactly one no-session Cancel link, click it, verify Banking Overview, then return to Guided Step 1.",
      "visibleCount": "Exactly 1 while no active session exists.",
      "handler": "GET /Banking/Overview",
      "pageModelMethod": "None",
      "transport": "Normal anchor navigation.",
      "preconditions": "Authenticated manager; no active Guided Import session.",
      "expectedOutcome": "Banking Overview loads and no ImportSession is created.",
      "hazards": "Do not require the modal cancel button before a session exists; Step 1 intentionally renders an Overview link instead.",
      "failureBeforeCertification": "TEST_INVALID",
      "sourceLine": 562,
      "robotBindings": [
        {
          "keyword": "Verify Banking UI Closeout",
          "requiredPatterns": [
            "css=a[data-guided-cancel-import][href=\"/Banking/Overview\"]:visible",
            "Safe Click    css=a[data-guided-cancel-import][href=\"/Banking/Overview\"]:visible",
            "Should Contain    ${overview_url}    /Banking/Overview"
          ]
        }
      ]
    },
    {
      "id": "review.problem-state-correction-persistence",
      "area": "Banking Extraction Review",
      "route": "/Banking/Imports/ExtractionReview?sessionId=<GUID>",
      "purpose": "Prove an invalid posted OCR row remains visible as a blocking problem, then a valid correction is saved and persists after a fresh exact-session reload.",
      "sourceFile": "AtxSolutions/Pages/Banking/Imports/ExtractionReview.cshtml",
      "sourceAnchor": "Correct the red required-field errors first.",
      "selector": "#pdfExtractionReviewTable tr[data-review-row] >> nth=0; child [data-field=\"Date\"], [data-field=\"Amount\"]; #pdfReviewActionBar button[formaction*=\"handler=Save\"]:visible",
      "interaction": "Capture original first-row values, post an invalid date and amount, verify blocking state and posted-value preservation, restore the originals, save, reload the exact session and verify persisted values and no blocking class.",
      "visibleCount": "Exactly one review form, at least one row and one visible Save Corrections button.",
      "handler": "Save",
      "pageModelMethod": "ExtractionReviewModel.OnPostSaveAsync",
      "transport": "Full POST; Page on blocking issues, same-session redirect after valid save.",
      "preconditions": "Owned active OCR/image ImportSession at Extraction Review with at least one calibrated row.",
      "expectedOutcome": "Invalid values remain visible and cannot be accepted; restored valid values persist after exact-session reload.",
      "hazards": "A blocking save does not persist to the session; it preserves posted values only on the returned page. Persistence may be asserted only after the valid save redirects.",
      "failureBeforeCertification": "FAIL only after exact session, source fields, save handler and response branch are certified.",
      "sourceLine": 130,
      "pageModelFile": "AtxSolutions/Pages/Banking/Imports/ExtractionReview.cshtml.cs",
      "pageModelLine": 86,
      "robotBindings": [
        {
          "keyword": "Verify OCR Problem State Correction And Persistence",
          "requiredPatterns": [
            "Fill Text    ${date_field}    invalid-date",
            "Fill Text    ${amount_field}    invalid-amount",
            "Correct the required transaction fields before saving.",
            "Go To    ${BASE_URL}/Banking/Imports/ExtractionReview?sessionId=${SESSION_ID}"
          ],
          "forbiddenPatterns": [
            "Safe Click    css=#pdfReviewAcceptButton"
          ]
        }
      ]
    },
    {
      "id": "shell.workspace-switcher-open",
      "area": "Authenticated shell",
      "route": "Any authenticated /Banking/* page",
      "purpose": "Open the workspace switcher through the visible desktop workspace chip after its client listener is ready.",
      "sourceFile": "AtxSolutions/wwwroot/js/workspace-switcher.js",
      "sourceAnchor": "document.querySelectorAll('[data-atx-workspace-switcher-open]')",
      "selector": "button.atx-topbar-chip-workspace[data-atx-workspace-switcher-open=\"true\"]:visible:not([disabled])",
      "interaction": "Retry the visible user click until #workspaceSwitcherModal.show is visible. DOM presence alone is not controller readiness.",
      "visibleCount": "Exactly 1 visible enabled desktop trigger; exactly 1 visible modal after click.",
      "handler": "workspace-switcher.js click listener invokes Bootstrap Modal.show()",
      "pageModelMethod": "N/A",
      "transport": "Client-side Bootstrap modal",
      "preconditions": "Authenticated shell rendered; Bootstrap and workspace-switcher listener initialized.",
      "expectedOutcome": "#workspaceSwitcherModal has .show and is visible.",
      "hazards": "A visible trigger can exist before workspace-switcher.js has attached its click listener. A single immediate click followed by a long wait is TEST_INVALID.",
      "failureBeforeCertification": "TEST_INVALID",
      "sourceLine": 1,
      "pageModelFile": "AtxSolutions/Pages/Shared/_Layout.cshtml",
      "pageModelLine": 1,
      "robotBindings": [
        {
          "keyword": "Workspace Switcher Should Be Open",
          "requiredPatterns": [
            "# ATX-ACTION: shell.workspace-switcher-open",
            "button.atx-topbar-chip-workspace[data-atx-workspace-switcher-open=\"true\"]:visible:not([disabled])",
            "css=#workspaceSwitcherModal.show:visible"
          ],
          "forbiddenPatterns": [
            "Safe Click    css=button[data-atx-workspace-switcher-open] >> nth=0"
          ]
        }
      ]
    },
    {
      "id": "shell.workspace-switcher-select",
      "area": "Authenticated shell",
      "route": "Any authenticated /Banking/* page",
      "purpose": "Select one exact workspace from the open switcher.",
      "sourceFile": "AtxSolutions/Pages/Shared/_Layout.cshtml",
      "sourceAnchor": "data-workspace-switch-link",
      "selector": "#workspaceSwitcherModal.show .workspace-switcher-card[data-workspace-row]:has(.workspace-switcher-name:has-text(\"<workspace>\")) a[data-workspace-switch-link]:visible",
      "interaction": "Within the visible modal, resolve one exact workspace card and click its data-workspace-switch-link action.",
      "visibleCount": "Exactly 1 target switch link.",
      "handler": "GET /Workspace/SetTenant?tenantId=...&returnUrl=...",
      "pageModelMethod": "SetTenantModel.OnGetAsync",
      "transport": "Full navigation",
      "preconditions": "Workspace switcher open; target workspace accessible.",
      "expectedOutcome": "Authenticated page reloads and workspace chip label contains the target workspace.",
      "hazards": "Do not use an unscoped global :has-text('Switch') selector.",
      "failureBeforeCertification": "TEST_INVALID or BLOCKED for missing prerequisite",
      "sourceLine": 1,
      "pageModelFile": null,
      "pageModelLine": null,
      "robotBindings": [
        {
          "keyword": "Switch To Workspace",
          "requiredPatterns": [
            "# ATX-ACTION: shell.workspace-switcher-select",
            "Wait Until Keyword Succeeds    15s    250ms    Workspace Switcher Should Be Open",
            "a[data-workspace-switch-link]:visible"
          ]
        }
      ]
    },
    {
      "id": "phase25j.closeout.protected-profile-state",
      "area": "Phase 25J final closeout",
      "route": "/Banking/Profiles?tab=user&status=all",
      "purpose": "Verify both protected Phase 25J tenant profiles remain exactly Published v1 and no disposable Statement test profile remains.",
      "sourceFile": "AtxSolutions/Pages/Banking/Profiles/Index.cshtml",
      "sourceAnchor": "<div class=\"bp-profile-card p-3 d-flex flex-column\">",
      "selector": "Exact profile-card XPath by exact h2 text; exact direct top-row lifecycle badge; catalogue text for prohibited prefixes.",
      "interaction": "Read-only card count, lifecycle text and catalogue text.",
      "visibleCount": "Exactly one card per protected profile; zero disposable-prefix cards.",
      "handler": "GET",
      "pageModelMethod": "IndexModel.OnGetAsync",
      "transport": "Full navigation and DOM reads.",
      "preconditions": "Authenticated manager in CIPC Example Holdings.",
      "expectedOutcome": "Phase 25J OCR IMAGE TEST and Phase 25J TEST A1 each show v1 · Published; disposable Statement prefixes are absent.",
      "hazards": "Do not use substring-only destructive selectors; no mutation is permitted.",
      "failureBeforeCertification": "TEST_INVALID for ambiguous selectors; FAIL only for source-certified protected-state contradiction.",
      "sourceLine": 226,
      "pageModelFile": "AtxSolutions/Pages/Banking/Profiles/Index.cshtml.cs",
      "pageModelLine": 61,
      "robotBindings": [
        {
          "keyword": "Verify Protected Profiles And Disposable Profile Cleanup",
          "requiredPatterns": [
            "# ATX-ACTION: phase25j.closeout.protected-profile-state",
            "Go To    ${BASE_URL}/Banking/Profiles?tab=user&status=all",
            "Verify Protected Profile    ${PROTECTED_OCR_PROFILE}    ${PROTECTED_LIFECYCLE}",
            "Verify Protected Profile    ${PROTECTED_LIFECYCLE_PROFILE}    ${PROTECTED_LIFECYCLE}",
            "Validate Disposable Statement Profile Absence    ${catalogue_text}"
          ]
        }
      ]
    },
    {
      "id": "phase25j.closeout.production-baseline",
      "area": "Phase 25J final closeout",
      "route": "/Banking/Imports?handler=BatchDetail&batchId=<PRODUCTION_BATCH_GUID>",
      "purpose": "Read the exact preserved 77-row production batch directly through the tenant-scoped BatchDetail handler.",
      "sourceFile": "AtxSolutions/Pages/Banking/Imports.cshtml.cs",
      "sourceAnchor": "public async Task<IActionResult> OnGetBatchDetailAsync(Guid batchId)",
      "selector": "Absolute same-origin BatchDetail URL with frozen production batch GUID; read JSON body text.",
      "interaction": "Navigate directly to the read-only JSON handler and validate exact identifiers, status and counts.",
      "visibleCount": "One JSON body.",
      "handler": "BatchDetail",
      "pageModelMethod": "ImportsModel.OnGetBatchDetailAsync",
      "transport": "Authenticated GET JSON.",
      "preconditions": "Basic Beside CIPC production workspace and preserved batch 99bc4964-0bcb-4061-ad09-88574cd17ec6.",
      "expectedOutcome": "success=true, exact batch ID, Completed, processed/imported/transactions 77, duplicates/skips/errors/warnings zero, Demo Bank account.",
      "hazards": "The production baseline belongs to Basic Beside CIPC, while protected Phase 25J TEST profiles belong to CIPC Example Holdings. Never call Undo/Delete or mutate the production baseline.",
      "failureBeforeCertification": "BLOCKED only if the protected baseline prerequisite is unavailable; FAIL for a certified changed baseline.",
      "sourceLine": 2449,
      "pageModelFile": "AtxSolutions/Pages/Banking/Imports.cshtml.cs",
      "pageModelLine": 2449,
      "robotBindings": [
        {
          "keyword": "Verify Production Baseline",
          "requiredPatterns": [
            "# ATX-ACTION: phase25j.closeout.production-baseline",
            "Go To    ${BASE_URL}/Banking/Imports?handler=BatchDetail&batchId=${PRODUCTION_BATCH_ID}",
            "Validate Production Baseline Detail    ${detail_text}"
          ]
        }
      ]
    },
    {
      "id": "phase25j.closeout.payment-evidence-cleanup",
      "area": "Phase 25J final closeout",
      "route": "/Banking/PaymentEvidence",
      "purpose": "Verify no disposable Payment Evidence profile or test batch/file remains after the accepted Payment Evidence scopes.",
      "sourceFile": "AtxSolutions/Pages/Banking/PaymentEvidence/Index.cshtml",
      "sourceAnchor": "id=\"pane-sub-profiles\"",
      "selector": "Server-selected Profiles, Import and History panes; read each pane body text.",
      "interaction": "Read-only full navigation across Payment Evidence tabs.",
      "visibleCount": "One active pane per route.",
      "handler": "GET /Banking/PaymentEvidence",
      "pageModelMethod": "IndexModel.OnGetAsync",
      "transport": "Full navigation and DOM reads.",
      "preconditions": "Authenticated manager in CIPC Example Holdings.",
      "expectedOutcome": "All disposable profile prefixes and synthetic test file names are absent.",
      "hazards": "Two intentional legacy Payment Evidence batches may remain; validate only known disposable test identifiers.",
      "failureBeforeCertification": "TEST_INVALID for missing panes; FAIL for leaked disposable test objects.",
      "sourceLine": 122,
      "pageModelFile": "AtxSolutions/Pages/Banking/PaymentEvidence/Index.cshtml.cs",
      "pageModelLine": 118,
      "robotBindings": [
        {
          "keyword": "Verify Payment Evidence Cleanup",
          "requiredPatterns": [
            "# ATX-ACTION: phase25j.closeout.payment-evidence-cleanup",
            "Go To    ${BASE_URL}/Banking/PaymentEvidence?activeEvidenceTab=profiles",
            "Go To    ${BASE_URL}/Banking/PaymentEvidence?activeEvidenceTab=import",
            "Go To    ${BASE_URL}/Banking/PaymentEvidence?activeEvidenceTab=history",
            "Validate Payment Evidence Cleanup    ${profiles_text}    ${import_text}    ${history_text}"
          ]
        }
      ]
    },
    {
      "id": "phase25j.closeout.no-active-guided-session",
      "area": "Phase 25J final closeout",
      "route": "/Banking/Imports?activeTab=guided&currentStep=1",
      "purpose": "Verify final closeout starts with no active Guided Import session.",
      "sourceFile": "AtxSolutions/Pages/Banking/Imports.cshtml",
      "sourceAnchor": "window.__importSession = @Html.Raw(Model.SessionJson ?? \"null\");",
      "selector": "window.__importSession",
      "interaction": "Read browser session object without mutation.",
      "visibleCount": "One object or null.",
      "handler": "GET",
      "pageModelMethod": "ImportsModel.OnGetAsync",
      "transport": "Full navigation plus read-only browser state.",
      "preconditions": "Owner workspace selected.",
      "expectedOutcome": "null. Any unrelated active session blocks closeout; an ATX test session proves cleanup failure.",
      "hazards": "Do not abandon an unrelated manager session during final read-only closeout.",
      "failureBeforeCertification": "BLOCKED for unrelated active session; FAIL for leaked Phase 25J test session.",
      "sourceLine": 1855,
      "pageModelFile": "AtxSolutions/Pages/Banking/Imports.cshtml.cs",
      "pageModelLine": 461,
      "robotBindings": [
        {
          "keyword": "Verify No Active Guided Session",
          "requiredPatterns": [
            "# ATX-ACTION: phase25j.closeout.no-active-guided-session",
            "Go To    ${BASE_URL}/Banking/Imports?activeTab=guided&currentStep=1",
            "Evaluate JavaScript    css=html    (element) => window.__importSession || null",
            "Validate No Active Guided Session    ${session}"
          ]
        }
      ]
    },
    {
      "id": "phase25h-d2a.website-preview-visible",
      "area": "Payment Evidence website preview",
      "route": "/Banking/PaymentEvidence?activeEvidenceTab=import",
      "purpose": "Prove the deployed website visibly accepts and previews one exact runtime-unique Payment Evidence CSV after D2-A.",
      "sourceFile": "AtxSolutions/Pages/Banking/PaymentEvidence/Index.cshtml",
      "sourceAnchor": "Preview Results",
      "selector": "#pane-sub-import > div.card.border-0.shadow-sm:not(.mb-4)",
      "interaction": "Select the exact disposable profile, upload the synthetic CSV through #PreviewFile, click the visible UploadPreview submitter, first classify the immediate website result, and read the direct Preview Results card only when the classifier reports success.",
      "visibleCount": "Exactly 1 Preview Results card.",
      "handler": "UploadPreview",
      "pageModelMethod": "PaymentEvidence IndexModel.OnPostUploadPreviewAsync",
      "transport": "Browser multipart POST and rendered website response only",
      "preconditions": "Exact disposable active Payment Evidence profile and non-empty runtime-unique synthetic CSV.",
      "expectedOutcome": "Exact filename, 5 detected rows, 5 classified, 0 unknown, 1 duplicate, duplicate warning visible, and Execute Import enabled.",
      "hazards": "A visible application-error alert or validation error must be captured immediately. Do not wait only for the success card, and do not supplement the browser result with SQL, appsettings, local database configuration or table queries.",
      "failureBeforeCertification": "FAIL for a certified visible application-error response; TEST_INVALID only for package, selector or response-classifier defects.",
      "sourceLine": 275,
      "pageModelFile": "AtxSolutions/Pages/Banking/PaymentEvidence/Index.cshtml.cs",
      "pageModelLine": 430
    },
    {
      "id": "phase25h-d2a.website-retry-single-batch",
      "area": "Payment Evidence website retry",
      "route": "/Banking/PaymentEvidence and /Banking/PaymentEvidence/Batch",
      "purpose": "Prove through the website that two bounded submissions of the exact Execute Import form resolve to one visible batch.",
      "sourceFile": "AtxSolutions/Pages/Banking/PaymentEvidence/Index.cshtml",
      "sourceAnchor": "asp-page-handler=\"ExecuteImport\"",
      "selector": "Exact Preview Results form[action*=\"handler=ExecuteImport\"] and the exact active-batch row for the runtime filename.",
      "interaction": "Submit the exact form twice through same-origin browser fetch, collect final website URLs, require one unique batch GUID, then verify one active website batch row links to that GUID.",
      "visibleCount": "One unique batch GUID and one active batch row for the exact runtime filename.",
      "handler": "ExecuteImport",
      "pageModelMethod": "PaymentEvidence IndexModel.OnPostExecuteImportAsync",
      "transport": "Two bounded same-origin browser POSTs and browser-rendered pages only",
      "preconditions": "Current visible preview and exact disposable profile.",
      "expectedOutcome": "One active InReview batch with five rows and the expected website classification totals.",
      "hazards": "This proves website-visible idempotency only. It does not expose or prove the internal usage-ledger row.",
      "failureBeforeCertification": "FAIL only after exact form, response and batch identity certification",
      "sourceLine": 354,
      "pageModelFile": "AtxSolutions/Pages/Banking/PaymentEvidence/Index.cshtml.cs",
      "pageModelLine": 533
    },
    {
      "id": "phase25h-d2a.website-cleanup-visible",
      "area": "Payment Evidence exact website cleanup",
      "route": "/Banking/PaymentEvidence/Batch and /Banking/PaymentEvidence?activeEvidenceTab=profiles",
      "purpose": "Delete only the exact disposable website objects and prove their absence through the website.",
      "sourceFile": "AtxSolutions/Pages/Banking/PaymentEvidence/Batch.cshtml",
      "sourceAnchor": "handler=Delete",
      "selector": "Exact batch Delete form and exact disposable profile DeletePaymentEvidenceProfile form.",
      "interaction": "Delete the captured batch GUID through its visible page, verify the website not-found state, delete the captured profile GUID, and verify its exact row is absent.",
      "visibleCount": "One exact delete action at each stage; zero exact rows after cleanup.",
      "handler": "Delete / DeletePaymentEvidenceProfile",
      "pageModelMethod": "Payment Evidence Batch delete and IndexModel.OnPostDeletePaymentEvidenceProfileAsync",
      "transport": "Browser POST, redirects and rendered website responses only",
      "preconditions": "Exact captured batch and profile IDs from the website flow.",
      "expectedOutcome": "Batch not found through the website and exact profile row absent.",
      "hazards": "Do not claim deletion of internal append-only usage history; it is not website-visible.",
      "failureBeforeCertification": "FAIL only after exact-ID cleanup certification",
      "sourceLine": 1,
      "pageModelFile": "AtxSolutions/Pages/Banking/PaymentEvidence/Index.cshtml.cs",
      "pageModelLine": 1
    },
    {
      "id": "phase25h-d2a.website-preview-outcome-classification",
      "area": "Payment Evidence immediate website response",
      "route": "/Banking/PaymentEvidence?activeEvidenceTab=import",
      "purpose": "Classify the immediate rendered result of UploadPreview before waiting for the Preview Results success card.",
      "sourceFile": "AtxSolutions/Pages/Banking/PaymentEvidence/Index.cshtml",
      "sourceAnchor": "data-payment-evidence-error",
      "selector": "#pane-sub-import > div.card.border-0.shadow-sm:not(.mb-4), #pane-sub-import [data-payment-evidence-error]:visible, #pane-sub-import .validation-summary-errors:visible, #loginForm:visible, .access-denied:visible",
      "interaction": "After clicking the exact UploadPreview submitter, wait until exactly one recognised outcome exists. Capture route, timestamp, visible text and screenshot before classification.",
      "visibleCount": "Exactly one recognised terminal outcome.",
      "handler": "UploadPreview",
      "pageModelMethod": "PaymentEvidence IndexModel.OnPostUploadPreviewAsync",
      "transport": "Browser multipart POST and rendered website response only",
      "preconditions": "Exact disposable profile, exact runtime filename and certified upload form.",
      "expectedOutcome": "Exactly one certified website outcome is classified. A visible `PE-PREVIEW-SAVEEVIDENCE-SQL547-CKTEXT` error is application FAIL and must be captured without waiting for the success card.",
      "hazards": "Do not downgrade a visible application error to TEST_INVALID. Do not add SQL or configuration access to the Robot package.",
      "failureBeforeCertification": "FAIL for visible application error after certified request; BLOCKED for missing permission; TEST_INVALID for an unrecognised or ambiguous package response.",
      "sourceLine": 146
    },
    {
      "id": "phase25h-d2a.website-preview-friendly-error",
      "area": "Payment Evidence",
      "route": "/Banking/PaymentEvidence?handler=UploadPreview",
      "purpose": "Expose a specific, safe and actionable Payment Evidence preview failure through the website.",
      "sourceFile": "AtxSolutions/Pages/Banking/PaymentEvidence/Index.cshtml.cs",
      "sourceAnchor": "BuildPreviewFailureMessage",
      "selector": "[data-payment-evidence-error]:visible [data-payment-evidence-error-message]",
      "interaction": "When `[data-payment-evidence-error]` is visible, read `[data-payment-evidence-error-message]` and record the exact stage-specific message and `PE-PREVIEW-*` support reference.",
      "visibleCount": "Exactly 1 when preview returns an application error",
      "handler": "UploadPreview",
      "pageModelMethod": "IndexModel.OnPostUploadPreviewAsync -> BuildPreviewFailureMessage",
      "transport": "Full multipart POST returning Page",
      "preconditions": "The immediate preview outcome classifier identified the rendered application-error branch.",
      "expectedOutcome": "For SQL error 547 caused by `CK_BankingUsageEvents_Text`, the website explains that an internal Banking data-format rule rejected the usage reference, states that preview stopped before rows were imported, and supplies support reference `PE-PREVIEW-SAVEEVIDENCE-SQL547-CKTEXT`.",
      "hazards": "Do not expose SQL text, constraint definitions, connection data, filenames or evidence content to the user. A visible error remains application FAIL; Robot must not query the database.",
      "failureBeforeCertification": "TEST_INVALID until the exact message selector and current source hash are certified",
      "sourceLine": 768,
      "pageModelFile": "AtxSolutions/Pages/Banking/PaymentEvidence/Index.cshtml.cs",
      "pageModelLine": 768
    },
    {
      "id": "statement.choose-selectable-pdf-source",
      "area": "Statement Profile",
      "route": "/Banking/Profiles/Statement#source-sample",
      "purpose": "Select a PDF containing embedded selectable text.",
      "sourceFile": "AtxSolutions/Pages/Banking/Profiles/Statement.cshtml",
      "sourceAnchor": "data-source-type=\"SelectablePdf\"",
      "selector": "button.statement-source-card[data-source-type=\"SelectablePdf\"]:visible",
      "interaction": "Click the source card and verify #SampleSourceType=SelectablePdf.",
      "visibleCount": "Exactly 1",
      "handler": "Client-side selectSourceType",
      "pageModelMethod": "StatementModel.ResolveSampleSourceType",
      "transport": "Client-side form state",
      "preconditions": "Statement profile workspace initialised.",
      "expectedOutcome": "File accept becomes .pdf and recommended OCR mode is Off.",
      "hazards": "Do not set only the hidden SampleSourceType value; the card click drives dependent state.",
      "failureBeforeCertification": "TEST_INVALID",
      "sourceLine": 2300,
      "pageModelFile": "AtxSolutions/Pages/Banking/Profiles/Statement.cshtml.cs",
      "pageModelLine": 1180
    },
    {
      "id": "statement.disable-ocr-for-direct-text",
      "area": "Statement Profile",
      "route": "/Banking/Profiles/Statement#extraction-method",
      "purpose": "Use direct embedded PDF text without OCR.",
      "sourceFile": "AtxSolutions/Pages/Banking/Profiles/Statement.cshtml",
      "sourceAnchor": "id=\"OcrModeOff\"",
      "selector": "label:has(#OcrModeOff)",
      "interaction": "Click the visible mode card and verify #OcrModeOff checked.",
      "visibleCount": "Exactly 1 visible label card",
      "handler": "Client-side radio change",
      "pageModelMethod": "PdfProfileFormInput.OcrMode",
      "transport": "Client-side form state",
      "preconditions": "Selectable PDF source selected.",
      "expectedOutcome": "OcrMode=Off and provider is not invoked.",
      "hazards": "The radio itself is visually hidden; click the associated visible label.",
      "failureBeforeCertification": "TEST_INVALID",
      "sourceLine": 2478,
      "pageModelFile": "AtxSolutions/Pages/Banking/Profiles/Statement.cshtml.cs",
      "pageModelLine": 2320
    },
    {
      "id": "phase25h-d2b.direct-text-processing",
      "area": "Phase 25H-D2-B",
      "route": "/Banking/Profiles/Statement#test-results",
      "purpose": "Exercise a successful direct-text extraction through the website.",
      "sourceFile": "AtxSolutions/Features/Banking/Services/SourceIngestion/BankingContentExtractionService.cs",
      "sourceAnchor": "BankingUsageTypes.DirectTextExtraction",
      "selector": "#test-results .statement-test-lab-actions button[formaction*=\"handler=RerunExtraction\"]:visible and result footer",
      "interaction": "In Advanced mode, resolve the canonical Test Lab RerunExtraction action, submit SelectablePdf with OcrMode Off, then inspect the immediate AJAX outcome and rendered provider/mode/page summary.",
      "visibleCount": "Exactly 1 visible Advanced Test Lab extraction action; zero visible Basic Test actions",
      "handler": "RerunExtraction",
      "pageModelMethod": "StatementModel.OnPostRerunExtractionAsync -> BankingContentExtractionService.ExtractAsync",
      "transport": "AJAX POST and replacement",
      "preconditions": "Synthetic selectable-text PDF staged; valid disposable Draft.",
      "expectedOutcome": "DirectText result, one page processed, extraction run count increments, no OCR browser action is selected.",
      "hazards": "The Basic handler=Test control is hidden in Advanced mode. Selecting it is TEST_INVALID. Browser proves processing behavior, not raw BankingUsageEvents rows.",
      "failureBeforeCertification": "TEST_INVALID until selectors, sample and action identity pass; then FAIL",
      "sourceLine": 1,
      "pageModelFile": "AtxSolutions/Pages/Banking/Profiles/Statement.cshtml.cs",
      "pageModelLine": 717
    },
    {
      "id": "phase25h-d2b.image-preparation",
      "area": "Phase 25H-D2-B",
      "route": "/Banking/Profiles/Statement#image-preparation",
      "purpose": "Exercise preview-only image preparation without extraction.",
      "sourceFile": "AtxSolutions/Features/Banking/Services/SourceIngestion/BankStatementProfileTestArtifactStore.cs",
      "sourceAnchor": "BankingUsageTypes.ImagePreparation",
      "selector": "#image-preparation button[formaction*=\"handler=PrepareImage\"]:visible",
      "interaction": "Prepare the packaged image sample and verify the processed image is fully loaded while extraction/remap counters remain zero.",
      "visibleCount": "One active action",
      "handler": "PrepareImage",
      "pageModelMethod": "StatementModel.OnPostPrepareImageAsync",
      "transport": "AJAX POST and image load",
      "preconditions": "Image source, OCR Force, provider and preprocessing configured.",
      "expectedOutcome": "Original/prepared preview exists and no extraction/remap run occurs.",
      "hazards": "AJAX completion precedes image readiness; require complete and non-zero natural dimensions.",
      "failureBeforeCertification": "TEST_INVALID until readiness checks pass; then FAIL",
      "sourceLine": 1,
      "pageModelFile": "AtxSolutions/Pages/Banking/Profiles/Statement.cshtml.cs",
      "pageModelLine": 217
    },
    {
      "id": "phase25h-d2b.ocr-processing",
      "area": "Phase 25H-D2-B",
      "route": "/Banking/Profiles/Statement#test-results",
      "purpose": "Exercise a successful image OCR extraction through the website.",
      "sourceFile": "AtxSolutions/Features/Banking/Services/SourceIngestion/BankingContentExtractionService.cs",
      "sourceAnchor": "BankingUsageTypes.OcrExtraction",
      "selector": "#test-results .statement-test-lab-actions button[formaction*=\"handler=RerunExtraction\"]:visible and result footer",
      "interaction": "In Advanced mode, resolve the canonical Test Lab RerunExtraction action, run image evidence with OcrMode Force, then verify Ocr mode and the extraction counter.",
      "visibleCount": "Exactly 1 visible Advanced Test Lab extraction action; zero visible Basic Test actions",
      "handler": "RerunExtraction",
      "pageModelMethod": "StatementModel.OnPostRerunExtractionAsync -> BankingContentExtractionService.ExtractAsync",
      "transport": "AJAX POST and replacement",
      "preconditions": "OCR provider available and synthetic image prepared.",
      "expectedOutcome": "OCR result is rendered and extraction count becomes one.",
      "hazards": "No provider is BLOCKED. The hidden Basic handler=Test control is not the Advanced action. Browser does not inspect the internal image-unit event.",
      "failureBeforeCertification": "BLOCKED or TEST_INVALID until prerequisites pass; then FAIL",
      "sourceLine": 1,
      "pageModelFile": "AtxSolutions/Pages/Banking/Profiles/Statement.cshtml.cs",
      "pageModelLine": 717
    },
    {
      "id": "phase25h-d2b.cached-remap",
      "area": "Phase 25H-D2-B",
      "route": "/Banking/Profiles/Statement#test-results",
      "purpose": "Exercise cached remapping without rerunning OCR.",
      "sourceFile": "AtxSolutions/Pages/Banking/Profiles/Statement.cshtml.cs",
      "sourceAnchor": "RecordCachedRemapUsageAsync",
      "selector": "#test-results .statement-test-lab-actions button[formaction*=\"handler=Remap\"]:visible",
      "interaction": "Change interpretation-only SkipSummaryRows, submit Remap, verify OCR-not-rerun feedback, unchanged extraction count and incremented remap count.",
      "visibleCount": "Exactly 1 canonical Test Lab action",
      "handler": "Remap",
      "pageModelMethod": "StatementModel.OnPostRemapAsync",
      "transport": "AJAX POST and replacement",
      "preconditions": "Current cached extraction and changed interpretation fingerprint.",
      "expectedOutcome": "Extraction count unchanged; remap count +1; feedback states OCR was not rerun.",
      "hazards": "Changing extraction/recovery/provider settings requires RerunExtraction and makes Remap disabled.",
      "failureBeforeCertification": "TEST_INVALID until CanRemap state is proven; then FAIL",
      "sourceLine": 418,
      "pageModelFile": "AtxSolutions/Pages/Banking/Profiles/Statement.cshtml.cs",
      "pageModelLine": 390
    },
    {
      "id": "phase25h-d2b.bounded-recovery",
      "area": "Phase 25H-D2-B",
      "route": "/Banking/Profiles/Statement#recovery-strategy",
      "purpose": "Exercise exactly three real bounded OCR attempts.",
      "sourceFile": "AtxSolutions/Features/Banking/Services/SourceIngestion/BankingContentExtractionService.cs",
      "sourceAnchor": "RecordRecoveryAttemptAsync",
      "selector": "#RecoveryEnabled, #RecoveryMaximumAttempts, #recoveryAttemptList, #resultRecovery .statement-recovery-history-item",
      "interaction": "Configure rules and two distinct visible retry cards, rerun extraction, then inspect rendered recovery history.",
      "visibleCount": "Three history entries after execution",
      "handler": "RerunExtraction",
      "pageModelMethod": "BankingContentExtractionService bounded recovery loop",
      "transport": "AJAX POST and replacement",
      "preconditions": "OCR sample, provider and visible recovery controls available.",
      "expectedOutcome": "Three executed attempts, one accepted best result, one bounded extraction run.",
      "hazards": "Skipped or duplicate retry configurations must not be counted as executed work. Hidden JSON writes are prohibited.",
      "failureBeforeCertification": "TEST_INVALID until editor model and history schema pass; then FAIL",
      "sourceLine": 1,
      "pageModelFile": "AtxSolutions/Pages/Banking/Profiles/Statement.cshtml.cs",
      "pageModelLine": 369
    },
    {
      "id": "phase25h-d2b.website-cleanup",
      "area": "Phase 25H-D2-B",
      "route": "/Banking/Profiles?tab=user",
      "purpose": "Remove the exact temporary sample and disposable never-published Draft.",
      "sourceFile": "AtxSolutions/Pages/Banking/Profiles/Index.cshtml",
      "sourceAnchor": "handler=Delete",
      "selector": "Exact profile card and exact delete form/button",
      "interaction": "Clear the temporary sample first, then delete the exact Draft and prove the exact card is absent.",
      "visibleCount": "One exact card before deletion, zero after",
      "handler": "ClearSample then Delete",
      "pageModelMethod": "StatementModel.OnPostClearSampleAsync; IndexModel.OnPostDeleteAsync",
      "transport": "AJAX then full POST",
      "preconditions": "Exact generated name/GUID, Draft, never published.",
      "expectedOutcome": "No test sample and no exact profile card remain.",
      "hazards": "Never delete by substring or touch ABSA/Phase25J protected profiles.",
      "failureBeforeCertification": "TEST_INVALID before exact identity; cleanup failure is FAIL/ERROR according to cause",
      "sourceLine": 278,
      "pageModelFile": "AtxSolutions/Pages/Banking/Profiles/Index.cshtml.cs",
      "pageModelLine": 210
    }
  ],
  "packageLayoutContract": {
    "schemaVersion": 1,
    "purpose": "Keep extracted-package, payload and installed-test paths as separate namespaces and prove that every required installed file has exactly one valid source mapping.",
    "manifestShape": {
      "packageRootRequiredFiles": "Paths resolved from the extracted ZIP root, for example Install-And-Run.bat, Install-And-Run.ps1, PACKAGE_CONTENT_SHA256SUMS.txt and payload/TestManifest.json.",
      "payloadRequiredFiles": "Paths resolved below the extracted payload directory and copied to the installed test root.",
      "installedRequiredFiles": "Paths required below the installed test root after all copy mappings complete.",
      "rootToInstallCopies": "Explicit mappings from extracted ZIP-root files to installed-test-root destinations."
    },
    "mandatoryRules": [
      "The ambiguous manifest property requiredFiles is prohibited.",
      "The installer must validate packageRootRequiredFiles against PackageRoot.",
      "The installer must validate payloadRequiredFiles against PayloadRoot.",
      "The installer must apply rootToInstallCopies explicitly.",
      "The installer must validate installedRequiredFiles against InstallRoot after copying.",
      "Every installedRequiredFiles entry must be produced by exactly one source: payload copy or rootToInstallCopies.",
      "No root file may be silently treated as payload-relative.",
      "No build validation may manually seed the simulated install directory outside the declared copy mappings.",
      "The build must simulate the installer copy graph from an extracted package tree before ZIP delivery.",
      "The checksum manifest must be validated at package root and copied through an explicit rootToInstallCopies entry."
    ],
    "requiredBuildGates": [
      "Extracted package-root existence validation",
      "Payload existence validation",
      "Package checksum verification",
      "Install copy-graph simulation",
      "Installed-file existence validation",
      "Exactly-one-producer validation for every installed required file",
      "Final ZIP extraction and repeat of the same layout simulation"
    ],
    "failureClassification": "TEST_INVALID"
  },
  "navigationContract": {
    "schemaVersion": 1,
    "rule": "An HTML href may be absolute, protocol-relative, root-relative or document-relative. Robot Browser Go To must never receive a raw href unless it has first been proven absolute.",
    "approvedPatterns": [
      "Click the exact source-mapped anchor after verifying its href and object identity.",
      "When direct navigation is required, resolve with new URL(href, document.baseURI).href and verify the resolved origin equals the ATX base origin before Go To."
    ],
    "prohibitedPatterns": [
      "Go To    ${href}",
      "Go To using any href value read directly from Get Attribute without absolute-URL resolution",
      "String concatenation that assumes every href begins with exactly one slash"
    ],
    "requiredPackageGates": [
      "Scan Robot suites for Go To calls whose URL argument is a variable originating from an href attribute.",
      "Reject raw relative-href navigation before ZIP creation.",
      "Runtime-check the exact anchor href and exact object GUID before clicking.",
      "Reject any resolved URL whose origin differs from the configured ATX base origin."
    ],
    "failureClassification": "TEST_INVALID"
  },
  "repeatedActionContract": {
    "schemaVersion": 1,
    "rule": "A semantically identical action may be rendered in multiple desktop, footer, header or mobile locations. Tests must map each render location and choose one canonical interaction target.",
    "requiredFields": [
      "action identity",
      "render-location selector",
      "responsive visibility rule",
      "expected visible count by viewport/mode",
      "canonical interaction selector",
      "equivalent-handler verification"
    ],
    "mandatoryRules": [
      "Do not assert global uniqueness for an action intentionally rendered more than once.",
      "A preflight must verify the documented render-location counts, not assume one visible control.",
      "A modifying click must use the canonical selector for one exact render location.",
      "All equivalent rendered controls must invoke the same handler before they are treated as interchangeable.",
      "Mobile-only controls must be excluded from desktop counts and desktop-only controls from mobile counts.",
      "When a result exposes an undocumented duplicate, update the source of truth before another package."
    ],
    "failureClassification": "TEST_INVALID"
  },
  "multiEvidenceArchiveContract": {
    "schemaVersion": 1,
    "scope": [
      "direct multiple screenshot/image selection",
      "server-generated synthetic screenshot ZIP",
      "user-supplied image-only ZIP",
      "user-supplied PDF-only ZIP",
      "mixed PDF/image ZIP rejection",
      "per-file Extraction Review attribution",
      "screenshot exact-row deduplication and stable ordering"
    ],
    "mandatoryRules": [
      "Direct multiple-file selection is accepted only when every selected file is a supported screenshot/image extension.",
      "The server-generated screenshot ZIP prefixes entries with a two-digit selection-order index.",
      "Image ZIP entries are processed in ordinal-ignore-case FullName order.",
      "Screenshot rows are deduplicated only when date, normalized description, amount and balance match the exact duplicate fingerprint.",
      "After deduplication, screenshot rows are ordered by known date, date ascending, source order, reverse visual row order and same-day sort key.",
      "A user-supplied image-only ZIP routes to image OCR and mandatory Extraction Review.",
      "A user-supplied PDF-only ZIP routes to PDF direct-text/OCR inspection and mandatory Extraction Review when review is required.",
      "A ZIP containing both PDF and image entries is rejected by the archive safety gate before session-file persistence.",
      "Focused archive tests must not accept extraction or perform final import.",
      "Synthetic OCR rows used for exact assertions must satisfy the synthetic-evidence calibration contract.",
      "Independent direct-image, image-ZIP, PDF-ZIP and mixed-ZIP scenarios must run as separate Robot test cases.",
      "A BLOCKED scenario must not prevent later independent scenarios from executing.",
      "Final classification must aggregate all scenario results using the result-classification contract."
    ],
    "failureClassification": {
      "missing_or_ambiguous_browser_control": "TEST_INVALID",
      "unsupported_environment_or_provider": "BLOCKED",
      "certified_server_contract_violation": "FAIL"
    }
  },
  "syntheticEvidenceCalibrationContract": {
    "schemaVersion": 1,
    "rule": "Synthetic OCR acceptance evidence must be calibrated against the deployed OCR/profile behavior before it is used as a hard application assertion.",
    "mandatoryRules": [
      "Do not reuse a row that a prior certified run already proved the deployed OCR profile omits.",
      "Build overlap/order datasets only from rows previously extracted reliably by the same Published profile and provider, or calibrate each source independently before the combined assertion.",
      "A package may classify incomplete OCR evidence as BLOCKED only once; the next package must remove or calibrate the unstable row before rerunning the same scope.",
      "Exact deduplication may become FAIL only when the runtime rows prove both copies of the complete duplicate fingerprint were extracted.",
      "Independent archive scenarios must be separate Robot test cases so one BLOCKED scenario does not prevent later scenarios from executing.",
      "Every scenario must have exact per-test session cleanup so subsequent scenarios can continue safely."
    ],
    "knownCalibrationEvidence": {
      "profile": "Phase 25J OCR IMAGE TEST",
      "provider": "local-tesseract",
      "reliablyExtractedDates": [
        "2026-05-28",
        "2026-05-29",
        "2026-05-30",
        "2026-05-31"
      ],
      "unreliableRow": {
        "date": "2026-06-01",
        "description": "Bank service fee",
        "observedIn": [
          "single-image representative baseline",
          "multi-image direct-selection V1"
        ],
        "rule": "Do not use this row as a required acceptance datum without a separate successful calibration."
      }
    },
    "failureClassification": "TEST_INVALID when the package repeats an already known unstable datum"
  },
  "resultClassificationAggregationContract": {
    "schemaVersion": 1,
    "rule": "The runner and recorder must aggregate all executed test failures and produce the same final classification.",
    "precedence": [
      "ERROR",
      "TEST_INVALID",
      "FAIL",
      "BLOCKED",
      "PASS"
    ],
    "mandatoryRules": [
      "Do not classify a multi-test suite from only the first failure.",
      "Do not infer classification from Robot's suite-summary text such as '1 test, 0 passed, 1 failed'.",
      "Custom libraries must record the classification before raising ATX_APP_FAIL, ATX_TEST_INVALID, ATX_BLOCKED or ATX_INFRA_ERROR.",
      "The recorder must use the stored classification when suite status is FAIL; an unclassified suite failure becomes TEST_INVALID.",
      "The runner must inspect every failed test status and relevant FAIL/ERROR message and apply the documented precedence.",
      "Runner final status, recorder status and result ZIP suffix must agree."
    ]
  },
  "sessionStateSerializationContract": {
    "schemaVersion": 1,
    "sourceMethod": "ImportsModel.SerializeSessionState",
    "sourceFile": "AtxSolutions/Pages/Banking/Imports.cshtml.cs",
    "javascriptObject": "window.__importSession",
    "propertyNamingPolicy": "camelCase",
    "exactProperties": [
      "id",
      "step",
      "status",
      "selectedProfileId",
      "selectedBankAccountId",
      "originalFileName",
      "storedFileName",
      "hasPersistedFile",
      "hasOwnerScopedArtifact",
      "autoDetectResultJson",
      "columnMappingJson",
      "importResultBatchId",
      "updatedAt",
      "hasPreview",
      "hasValidation"
    ],
    "typedProperties": {
      "id": "GUID string",
      "step": "integer 1-5",
      "status": "non-empty string",
      "selectedProfileId": "GUID string or null",
      "selectedBankAccountId": "GUID string or null",
      "originalFileName": "string or null",
      "storedFileName": "string or null",
      "hasPersistedFile": "boolean",
      "hasOwnerScopedArtifact": "boolean",
      "autoDetectResultJson": "string or null",
      "columnMappingJson": "string or null",
      "importResultBatchId": "GUID string or null",
      "updatedAt": "ISO date-time string",
      "hasPreview": "boolean",
      "hasValidation": "boolean"
    },
    "mandatoryRules": [
      "Read the browser object using the exact serialized camelCase property names.",
      "The workflow step property is `step`; `currentStep` and `CurrentStep` are not serialized properties.",
      "Validate the expected schema before using any property in a modifying acceptance assertion.",
      "A missing, renamed or unexpected schema property is TEST_INVALID until the source-action reference is updated.",
      "Never fall back from a missing property to zero, false or an empty string in a way that can manufacture an application failure.",
      "After source hashes pass, a schema-valid object whose values violate the certified handler contract may produce application FAIL.",
      "The session ID used for cleanup must equal the exact `id` value from the schema-valid object."
    ],
    "mixedArchiveRejectionState": {
      "urlPath": "/Banking/Imports",
      "query": {
        "activeTab": "guided",
        "currentStep": "2"
      },
      "visiblePane": "#stepPane2:visible",
      "session": {
        "step": 2,
        "hasPersistedFile": false,
        "hasOwnerScopedArtifact": false,
        "originalFileName": "",
        "storedFileName": "",
        "hasPreview": false,
        "hasValidation": false
      },
      "banner": "The ZIP contains both PDF and image files. Split them into separate imports."
    },
    "failureClassification": {
      "schema_mapping_or_property_error": "TEST_INVALID",
      "schema_valid_certified_value_violation": "FAIL",
      "unsafe_existing_session": "BLOCKED"
    }
  },
  "advancedVisualLayoutContract": {
    "schemaVersion": 1,
    "scope": [
      "prepared-image preview",
      "one transaction region",
      "one ignore region",
      "start and end anchors",
      "table detection settings",
      "manual visual column bands",
      "signed-amount rules",
      "wrapped-row reconstruction settings",
      "ordering and exact-duplicate settings",
      "running-balance validation settings",
      "Draft persistence and exact-GUID reload"
    ],
    "mandatoryRules": [
      "Use a dedicated disposable Draft named `Phase 25J INTERPRETATION TEST`.",
      "Never edit, test, republish or delete `Phase 25J OCR IMAGE TEST`, `Phase 25J TEST A1` or `ABSA bank statement`.",
      "Create an incomplete Draft with Save Draft & Exit, capture its exact GUID, then reopen it.",
      "Interact with generated region, anchor and column controls through their actual visible UI controls.",
      "The hidden OcrRegionsJson, AnchorRulesJson and ColumnMappingsJson values are read-only verification surfaces; tests must not write them directly.",
      "Prepare the synthetic sample before requiring the prepared-image canvas.",
      "Run initial extraction before choosing detected/manual columns.",
      "Use Remap & Validate after manual column and interpretation changes rather than rerunning OCR.",
      "Save Draft & Exit, reopen the exact GUID, verify persistence, then delete only the exact never-published Draft.",
      "Do not publish, start Guided Import, accept Extraction Review, create a batch or create transactions."
    ],
    "resultClassification": {
      "missing_or_ambiguous_dynamic_control": "TEST_INVALID",
      "missing_OCR_provider_or_language": "BLOCKED",
      "certified_handler_or_persistence_violation": "FAIL"
    }
  },
  "catalogueCreateActionContract": {
    "schemaVersion": 1,
    "rule": "Create-menu actions must be scoped to the opened create dropdown and matched by the exact rendered destination, not by a route prefix that also matches existing profile-card Configure links.",
    "canonicalStatementSelector": "ul[aria-labelledby=\"newProfileDropdown\"] a.dropdown-item[href=\"/Banking/Profiles/Statement\"]:visible",
    "mandatoryRules": [
      "Open `#newProfileDropdown` before resolving the create-menu item.",
      "Scope the Statement create action to `ul[aria-labelledby=\"newProfileDropdown\"]`.",
      "Match the exact rendered href `/Banking/Profiles/Statement`.",
      "Do not use `a[href^=\"/Banking/Profiles/Statement\"]` globally because it also matches existing profile Configure links containing `?id=`.",
      "Verify exactly one scoped create-menu item before clicking.",
      "Existing card Configure actions remain separate exact-card-scoped actions."
    ],
    "failureClassification": "TEST_INVALID"
  },
  "cleanupEvidenceTruthContract": {
    "schemaVersion": 1,
    "rule": "Cleanup reports must distinguish no-op cleanup from deletion of a test-owned object.",
    "states": [
      "not-created",
      "created-and-deleted",
      "created-and-cleanup-failed",
      "pre-existing-draft-resumed-and-deleted",
      "pre-existing-unsafe-object-not-touched"
    ],
    "mandatoryRules": [
      "Do not set `exactDraftDeleted=true` when no Draft was created or resumed.",
      "Record whether a test-owned exact GUID ever existed.",
      "Record the exact GUID that was deleted.",
      "Recorder summary and runner TestResult must agree on Draft creation and deletion.",
      "A successful no-op teardown is `cleanupSucceeded=true`, `draftCreated=false`, `exactDraftDeleted=false`."
    ],
    "failureClassification": "TEST_INVALID",
    "requiredEvidence": [
      "After an exact test-owned Draft deletion succeeds, the recorder must always be updated with exactDraftDeleted=true and deletedProfileId=<exact GUID>; do not skip recording because the in-memory deletion flag is already true."
    ]
  },
  "statementPageInitializationContract": {
    "schemaVersion": 1,
    "rule": "Visible Statement DOM is not proof that the page's client controllers and event handlers have completed initialization.",
    "sourceConfirmedReadyMarker": "typeof window.__atxStatementProfileCleanup === 'function'",
    "mandatoryRules": [
      "After every full navigation or AJAX page replacement to Statement Profile, wait for the source-confirmed ready marker before interacting with client-controlled actions.",
      "Do not click Basic/Advanced, section navigation, dynamic editors, Test, Remap or Prepare Image merely because `.statement-profile-page` is visible.",
      "The Advanced-mode action must verify exactly one visible Advanced button after readiness, click it once, then verify `data-profile-mode=advanced`.",
      "A click performed before the event listener is attached is TEST_INVALID even when Browser reports the physical click as successful.",
      "Do not write `data-profile-mode` or localStorage directly as a substitute for the visible mode action.",
      "The same readiness gate must be reused after AJAX replacement because `initializeStatementProfilePage()` rebinds controllers."
    ],
    "failureClassification": "TEST_INVALID before readiness; FAIL only after readiness and exact visible interaction are proven"
  },
  "statementInterpretationContract": {
    "schemaVersion": 1,
    "rule": "Interpretation acceptance uses one calibrated synthetic image and reads exact visible result rows after cached Remap.",
    "sample": "ATX_Phase25J_Statement_Interpretation_Test.png",
    "expectedRows": [
      {
        "date": "2026-06-01",
        "description": "Supplier payment Additional wrapped invoice detail",
        "reference": "WRAPA1",
        "amount": "-125.50",
        "balance": "9874.50"
      },
      {
        "date": "2026-06-01",
        "description": "Same day client receipt",
        "reference": "SAMEB2",
        "amount": "500.00",
        "balance": "10374.50"
      },
      {
        "date": "2026-06-02",
        "description": "Signed monthly service fee",
        "reference": "SIGNC3",
        "amount": "-74.50",
        "balance": "10300.00"
      },
      {
        "date": "2026-06-02",
        "description": "Signed refund received",
        "reference": "SIGND4",
        "amount": "250.00",
        "balance": "10550.00"
      }
    ],
    "mandatoryRules": [
      "Use a dedicated never-published Draft named `Phase 25J INTERPRETATION TEST`.",
      "Use visible controls to configure seven manual columns: TransactionDate, Description, Reference, SignedAmount, Debit, Credit and RunningBalance.",
      "Enable continuation rows, wrapped-row merging and running-balance reconciliation.",
      "Run one initial OCR extraction, then use cached Remap after interpretation changes.",
      "Read rows from `#resultRows table.statement-result-table tbody tr` in rendered order.",
      "Do not publish, start Guided Import, accept Extraction Review, create a batch or create transactions.",
      "Delete only the exact test-owned Draft GUID.",
      "Each intended transaction must start on a complete dated row; the wrapped detail is the only undated continuation line.",
      "Manual visual mapping must merge an undated, amountless continuation line into the previous transaction description when JoinWrappedDescriptionLines, MergeWrappedRows and AllowContinuationRows are enabled.",
      "Continuation merging must not run when wrapped-row merging is disabled.",
      "The merged candidate must preserve transaction date, reference, amount, balance, source order and source text.",
      "Cached Remap must discard provider balance diagnostics calculated before manual column interpretation.",
      "The current BankStatementValidationEngine running-balance result is authoritative after Remap.",
      "A passing remapped balance chain must not retain a stale Running balance variance warning.",
      "A failing remapped balance chain must expose a fresh VALIDATION-RUNNINGBALANCE warning derived from the current candidates."
    ],
    "resultClassification": {
      "missing_or_ambiguous_control_or_result_schema": "TEST_INVALID",
      "missing_ocr_provider_or_language": "BLOCKED",
      "calibrated_value_or_order_contradiction_after_certification": "FAIL"
    },
    "sampleSha256": "ad340c4d0f4b2ed46fd3ecb92ce0231801dd085aa051982181b0ea4cffaf211e",
    "calibrationBoundary": {
      "calibrationFields": [
        "rowCount",
        "transactionDate",
        "reference",
        "sourceDocumentName"
      ],
      "functionalFields": [
        "description",
        "amount",
        "runningBalance",
        "sourceOrder",
        "balanceWarnings"
      ],
      "rule": "Never classify a wrapped-description mismatch as sample calibration after row count, date, reference and source attribution passed."
    },
    "balanceWarningAuthority": {
      "beforeRemap": "Provider balance warnings may describe the pre-mapping OCR candidates and are not authoritative after interpretation changes.",
      "duringRemap": "Remove stale Running balance variance/check diagnostics before mapping and validation.",
      "afterRemap": "BankStatementValidationEngine evaluates the current remapped candidates and is the sole running-balance authority.",
      "passingOutcome": "No running-balance variance warning remains.",
      "failingOutcome": "A fresh VALIDATION-RUNNINGBALANCE warning describes the current mismatch."
    }
  },
  "preparedImageReadinessContract": {
    "rule": "AJAX fragment replacement is not equivalent to prepared-image resource readiness.",
    "requiredSequence": [
      "Wait until the Statement replacement page is no longer AJAX-busy.",
      "Validate the immediate response and controller readiness.",
      "Verify the main Statement form contains a non-empty SampleCacheToken.",
      "Open the source-confirmed section containing #ocrPreparedImage.",
      "Wait until the image is visible, complete and has non-zero natural dimensions."
    ],
    "classification": "An immediate missing/hidden image assertion before the bounded load gate is TEST_INVALID. A bounded readiness failure after a certified successful response may be FAIL."
  },
  "manualColumnIdentityContract": {
    "rule": "Dynamic manual-column cards are identity-addressed, not index-addressed.",
    "sourceBehavior": "render() and sync() sort columns by leftPercent and replace the list DOM; updateColumn() can therefore move a card after each visible edit.",
    "requiredSequence": [
      "Reach the required cardinality through visible add/remove controls.",
      "Capture every visible card data-column-id before changing boundaries.",
      "Target each later boundary and Banking-field control by data-column-id.",
      "Use a non-crossing boundary sequence, then verify final visible order.",
      "Verify normalized ColumnMappingsJson order before Remap."
    ],
    "classification": "An nth-child/index-based edit after a re-render is TEST_INVALID. A contradiction after stable-identity certification may be FAIL."
  },
  "packageHygieneContract": {
    "rule": "Generated Python bytecode is mutable runtime output and must never be present in an ATX test package, payload, installed test root or checksum manifest.",
    "forbiddenArtifacts": [
      "any __pycache__ directory",
      "*.pyc",
      "*.pyo"
    ],
    "builderRequirements": [
      "Delete generated bytecode before checksum generation.",
      "Compile or parse Python sources outside the package tree.",
      "Reject the package when generated bytecode exists before ZIP creation.",
      "Extract the final ZIP and repeat the generated-artifact rejection before delivery."
    ],
    "runtimeRequirements": [
      "Set PYTHONDONTWRITEBYTECODE=1 for every Python child process.",
      "Invoke Python with -B for package certification, Robot dry-run and Robot execution.",
      "Reject generated bytecode at package-root and installed-root certification gates."
    ],
    "classification": "Any packaged or generated __pycache__, .pyc or .pyo artifact is TEST_INVALID and must stop before credentials and Chromium."
  },
  "interpretationSampleCalibrationContract": {
    "schemaVersion": 1,
    "rule": "Wrapped-row and same-date ordering acceptance must use a sample where every intended transaction starts on a complete dated row. Only the intended continuation line may omit the date.",
    "sample": "ATX_Phase25J_Statement_Interpretation_Test.png",
    "sampleSha256": "ad340c4d0f4b2ed46fd3ecb92ce0231801dd085aa051982181b0ea4cffaf211e",
    "expectedTransactionCount": 4,
    "mandatoryRules": [
      "Do not use a date-only starter line for a wrapped-row acceptance sample.",
      "Place the first transaction date, identity, amount source and running balance on the same visual row.",
      "Place exactly one continuation description line immediately below the first transaction with no date, reference, amount or balance.",
      "Place the second same-date transaction on a clearly separate visual baseline with its full identity and values.",
      "Use OCR-stable reference values that avoid zero-versus-letter-O ambiguity.",
      "Treat the first failed calibration as BLOCKED; do not repeat the same unstable sample unchanged."
    ],
    "classification": "BLOCKED only when row count, dates, references or source attribution fail calibration. Description, amount, balance, ordering and warning mismatches are functional outcomes."
  },
  "appliedHotfix": {
    "name": "ATX_Phase25J_Cached_Remap_Balance_Warning_Hotfix_20260730.zip",
    "purpose": "Remove stale provider running-balance diagnostics before cached Remap validation and preserve only the current remapped validation outcome.",
    "changedSourceFiles": [
      {
        "path": "AtxSolutions/Features/Banking/Services/SourceIngestion/BankStatementCachedExtractionInterpreter.cs",
        "sha256": "4888413cfef3d83c2347004d739bc5e98a304abf60dd2d21447eb4e8e712a2be",
        "lineCount": 86
      },
      {
        "path": "AtxSolutions.Tests/Features/Banking/SourceIngestion/StatementProfileFlowRegressionTests.cs",
        "sha256": "66aef6eb6904d0502a0144fe6e67409e6f803ba3e8609567d982e06ed463d73a",
        "lineCount": 324
      }
    ]
  },
  "appliedHotfixes": [
    {
      "name": "ATX_Phase25J_Manual_Visual_Wrapped_Row_Hotfix_20260730.zip",
      "purpose": "Apply wrapped/continuation-row reconstruction to manual visual column mapping and add regression tests.",
      "changedSourceFiles": [
        {
          "path": "AtxSolutions/Features/Banking/Services/SourceIngestion/BankStatementColumnMappingEngine.cs",
          "sha256": "a65eef89f7d6147a79ef7913e49d0fecb14b98ae8557a0f3de8de88540691fae",
          "lineCount": 1046
        },
        {
          "path": "AtxSolutions.Tests/Features/Banking/SourceIngestion/BankingContentExtractionFoundationTests.cs",
          "sha256": "86dd032ebdf53d3db86d1603d5628656d0ff94e0359cef44537ac4876997a557",
          "lineCount": 1964
        }
      ]
    },
    {
      "name": "ATX_Phase25J_Cached_Remap_Balance_Warning_Hotfix_20260730.zip",
      "purpose": "Remove stale provider running-balance diagnostics before cached Remap validation and preserve only the current remapped validation outcome.",
      "changedSourceFiles": [
        {
          "path": "AtxSolutions/Features/Banking/Services/SourceIngestion/BankStatementCachedExtractionInterpreter.cs",
          "sha256": "4888413cfef3d83c2347004d739bc5e98a304abf60dd2d21447eb4e8e712a2be",
          "lineCount": 86
        },
        {
          "path": "AtxSolutions.Tests/Features/Banking/SourceIngestion/StatementProfileFlowRegressionTests.cs",
          "sha256": "66aef6eb6904d0502a0144fe6e67409e6f803ba3e8609567d982e06ed463d73a",
          "lineCount": 324
        }
      ]
    }
  ],
  "staleBalanceWarningContract": {
    "schemaVersion": 1,
    "source": "BankStatementCachedExtractionInterpreter.RemapAndValidate",
    "filterAnchor": "IsStaleBalanceDiagnostic",
    "staleMessages": [
      "Running balance variance on",
      "Running balance check found",
      "Running balance check could not run"
    ],
    "currentValidator": "BankStatementValidationEngine.EvaluateAndApply",
    "classification": {
      "stale warning retained after correct remapped chain": "FAIL",
      "missing source mapping or warning reader": "TEST_INVALID"
    }
  },
  "recoveryStrategyContract": {
    "schemaVersion": 1,
    "maximumAttemptsIncludesPrimary": true,
    "visibleEditorRequired": true,
    "directValidationJsonWritesProhibited": true,
    "directRetryJsonWritesProhibited": true,
    "calibratedRules": [
      {
        "ruleKey": "ProviderSuccess",
        "severity": "BlockPublication"
      },
      {
        "ruleKey": "MinimumOcrConfidence",
        "severity": "RequiresReview",
        "value": "99"
      },
      {
        "ruleKey": "MinimumRowCount",
        "severity": "RequiresReview",
        "value": "4"
      }
    ],
    "scoreFormula": {
      "success": 100000,
      "blocking": -10000,
      "requiresReview": -1000,
      "warning": -100,
      "candidate": 10,
      "confidence": 1
    },
    "tieRule": "Strict greater-than retains the earlier result.",
    "expectedPackageBoundary": {
      "maximumAttempts": 3,
      "expectedHistoryItems": 3,
      "acceptedItems": 1,
      "finalOutcome": "RequiresReview",
      "published": false,
      "guidedImportStarted": false,
      "batchCreated": false,
      "transactionsCreated": false
    }
  },
  "finalImportRetryIdempotencyContract": {
    "version": 44,
    "testProfile": "Phase 25J OCR IMAGE TEST",
    "testAccount": "ATX UI TEST BANK",
    "sample": "Runtime-unique copy of packaged synthetic PNG",
    "requiredFlow": [
      "create one exact active session",
      "upload one synthetic image",
      "review and accept extracted rows",
      "advance through preview and validation",
      "submit the same final form twice with the same session and operation",
      "resolve one exact batch by runtime-unique filename",
      "compare authoritative transaction count with accepted review-row count",
      "undo the exact batch and verify zero remaining transactions"
    ],
    "idempotencyAuthorities": {
      "operationLookup": "BankImportService existingBatch/ alreadyCommitted lookup by TenantId + ManagerId + OperationId",
      "batchUniqueness": "one desktop history row for runtime-unique filename",
      "transactionCount": "OnGetBatchDetailAsync batch.transactionCount",
      "sessionLineage": "ImportSessionService.CompleteSessionAsync exact owner/operation/artifact/account/profile-version match"
    },
    "acceptedPersistentEffects": [
      "one Reversed BankImportBatch",
      "one Completed ImportSession linked to that batch",
      "owner-scoped artifact lifecycle/audit/profile usage evidence retained by policy"
    ],
    "forbiddenEffects": [
      "second BankImportBatch for the same operation",
      "transactionCount greater than accepted review rows",
      "unreversed test transactions",
      "modification of Phase 25J OCR IMAGE TEST",
      "modification of ABSA bank statement or the preserved 77-row baseline"
    ],
    "batchStatusAuthority": {
      "source": "BankImportService.ExecuteImportAsync final status assignment",
      "failed": "errorCount > 0 and importedRows = 0",
      "partial": "warningCount > 0 or errorCount > 0",
      "completed": "warningCount = 0 and errorCount = 0",
      "rule": "Successful row creation does not require Completed; warning-bearing successful imports are Partial."
    },
    "undoRedirectAuthority": {
      "source": "ImportsModel.OnPostUndoAsync",
      "redirect": "parameterless RedirectToPage() to default Guided tab",
      "verification": "Explicitly GET activeTab=history, re-resolve exact BatchDetail trigger, then prove Reversed and zero transactions."
    },
    "tailOnlyReuse": {
      "allowedWhen": "A prior certified run already proved one exact batch, accepted-row equality and same-session retry uniqueness before a test-contract assertion stopped cleanup verification.",
      "requiredIdentifiers": [
        "exact batch ID",
        "runtime-unique filename",
        "accepted review-row count"
      ],
      "scope": "Verify source-derived pre-undo status, perform undo only if still available, and prove Reversed with zero transactions without creating another session or batch."
    },
    "historicalV122Result": "TEST_INVALID: expected Completed although the exact batch had warnings and was correctly Partial; teardown also assumed Undo redirected back to visible history."
  },
  "crossTenantBatchDenialContract": {
    "ownerWorkspace": "CIPC Example Holdings",
    "foreignWorkspace": "Basic Beside CIPC",
    "batchId": "5dfddb23-81d7-4400-85d0-806034cdc882",
    "ownerExpected": "BatchDetail success=true and exact Reversed batch with zero transactions.",
    "foreignExpected": "BatchDetail success=false, message Import batch not found., and no exact history row.",
    "returnExpected": "Owner BatchDetail success=true again for the same exact batch.",
    "mutationBoundary": "Read-only. No session, upload, import, undo, profile mutation, batch mutation or transaction mutation."
  },
  "ownerLineageCertificationContract": {
    "schemaVersion": 1,
    "scope": "Combined read-only runtime and source-contract certification for the exact Phase 25J idempotency batch.",
    "exactEvidence": {
      "ownerWorkspace": "CIPC Example Holdings",
      "sessionId": "e5e868d5-1572-4f10-ad29-8edca1129815",
      "batchId": "5dfddb23-81d7-4400-85d0-806034cdc882",
      "runtimeFileName": "ATX-P25J-IDEMPOTENCY-20260730091746-9AE50635.png",
      "accountId": "9ae8b4b7-ffd8-4a31-8159-fcdcb8fa7dca",
      "accountName": "ATX UI TEST BANK",
      "profileId": "9ca8ca44-2b98-48e5-89f6-fa933022928c",
      "profileName": "Phase 25J OCR IMAGE TEST",
      "profileLifecycle": "v1 · Published"
    },
    "runtimeProof": [
      "The exact Published user-profile card resolves by exact name and exact Statement Configure GUID.",
      "The exact card lifecycle badge is v1 · Published.",
      "The exact Reversed batch resolves by batch ID and runtime-unique filename.",
      "BatchDetail returns the exact selected account and its review URL contains the exact bank-account GUID.",
      "The batch has two imported rows, zero remaining transactions and Reversed lifecycle after cleanup."
    ],
    "sourceConfirmedProof": [
      "ExecuteSessionImportCoreAsync fails closed unless SelectedBankAccountId, SelectedProfileId, SelectedProfileVersionId, ManagerId, OperationId and SourceArtifactId are present.",
      "ExecuteSessionImportCoreAsync constructs BankImportExecutionContext from the exact session tenant, manager, user, operation and source artifact, then passes the exact account, profile and profile-version IDs to ExecuteImportAsync.",
      "BankImportService fails closed unless tenant, manager, user, operation and source-artifact ownership are complete and the exact published profile version is present.",
      "BankImportService validates source-artifact tenant, manager, user and operation identity before import.",
      "BankImportService persists TenantId, ManagerId, OperationId, SourceArtifactId, BankAccountId, ImportProfileId and ImportProfileVersionId on the batch.",
      "Same-operation retries must match source artifact, user, account, profile and exact profile version or fail."
    ],
    "proofBoundary": {
      "runtimeProven": "Owner-visible batch/account/profile identity and exact Published v1 catalogue state.",
      "sourceConfirmed": "Hidden manager, operation, source-artifact and exact-version propagation and fail-closed persistence contract.",
      "notClaimed": "The browser does not directly expose raw manager, operation or artifact GUIDs."
    },
    "mutationBoundary": "Read-only. No session, upload, import, undo, profile, batch or transaction mutation.",
    "classification": {
      "PASS": "All runtime identity checks and source-contract certification pass.",
      "FAIL": "A certified owner-visible identity contradicts the exact prior batch/profile/account evidence.",
      "TEST_INVALID": "Source hashes, exact identifiers, selectors, handler schema or proof boundary are invalid.",
      "BLOCKED": "The exact retained Reversed test batch or protected Published test profile is unavailable.",
      "ERROR": "Runner, parser, browser, authentication, environment or reporting failure."
    }
  },
  "scopeCorrectionContract": {
    "version": 44,
    "activeScope": [
      "/Banking/PaymentEvidence*",
      "/Banking/Profiles*",
      "/Banking/Imports*",
      "Banking OCR documents and images",
      "Banking Extraction Review, Import History, ownership, lineage and cleanup"
    ],
    "withdrawnFromPhase25J": [
      "Product Inventory",
      "Product Categories",
      "Payroll Reminders",
      "Support email polling"
    ],
    "rule": "The V29 Focused UI Runtime Regression package is withdrawn and must not be run as Phase 25J evidence."
  },
  "paymentEvidenceProfilePreviewContract": {
    "version": 44,
    "profileLifecycle": "PaymentEvidenceImportProfile is an active/inactive tenant profile and does not use Statement Draft/Published lifecycle.",
    "sampleRows": 5,
    "expectedClassifiedRows": 5,
    "expectedUnknownRows": 0,
    "expectedDuplicateRows": 1,
    "expectedWarning": "Duplicate payment evidence detected and will be flagged for review.",
    "mappingRule": "Use generated visible mapper selects; direct MappingDefinitionJson writes are prohibited.",
    "reopenRule": "Verify saved profile fields and mapping JSON after exact-ID reopen; sample file restoration is not required.",
    "cleanupRule": "Delete the exact unreferenced disposable profile. The preview artifact is owner-scoped temporary evidence and remains retention-governed because this scope does not execute import."
  },
  "paymentEvidenceConditionalImportControlsContract": {
    "version": 44,
    "sourceCondition": "The Guided Import form containing #PreviewProfileId and #PreviewFile is rendered only when IndexModel.HasPaymentEvidenceProfiles is true.",
    "emptyState": "When no Payment Evidence profiles exist, the Import pane renders the no-profile guidance card and does not render #PreviewProfileId or #PreviewFile.",
    "preMutationRule": "Before creating the disposable profile, certify profile-editor controls and certify that import-control presence matches the current total profile count. Do not globally require import controls when the workspace has zero profiles.",
    "postCreationRule": "After saving the exact disposable active profile, navigate to activeEvidenceTab=import and require #PreviewProfileId, #PreviewFile and the UploadPreview submit button before previewing.",
    "classification": "A preflight that requires conditionally absent import controls before profile creation is TEST_INVALID, not an ATX failure."
  },
  "paymentEvidenceDropdownOptionSelectorContract": {
    "version": 44,
    "route": "/Banking/PaymentEvidence?activeEvidenceTab=import",
    "select": "#PreviewProfileId",
    "authority": "The exact option element whose value equals the captured Payment Evidence profile GUID.",
    "requiredPattern": "Get Element Count    css=#PreviewProfileId option[value=\"${PROFILE_ID}\"]",
    "prohibitedPattern": "Evaluate JavaScript with a raw Robot scalar appended as an unquoted callback argument for simple select-option lookup.",
    "classification": "A JavaScript parser failure or argument-marshalling defect in this lookup is TEST_INVALID.",
    "reason": "Native scoped option selectors are sufficient and avoid second-parser argument ambiguity."
  },
  "executableActionTraceContract": {
    "version": 44,
    "markerSyntax": "# ATX-ACTION: <action-id>",
    "allManifestActionIdsMustExist": true,
    "allManifestActionIdsMustBeMarkedInRobot": true,
    "allRobotActionMarkersMustBeManifestDeclared": true,
    "allActionBindingsMustResolveToCustomKeywords": true,
    "allRequiredPatternsMustExistInBoundKeyword": true,
    "allForbiddenPatternsMustBeAbsentFromBoundKeyword": true,
    "prohibitedGlobalPatterns": [
      ".card:has(h6:has-text(\"Preview Results\"))"
    ],
    "classification": "Any missing action marker, unknown action ID, unresolved binding, missing required pattern or prohibited pattern is TEST_INVALID before credentials and Chromium.",
    "deliveryRule": "No package may be delivered unless the final extracted ZIP passes action IDs, markers, keyword bindings, required/forbidden patterns, exact keyword resolution, package layout, checksum and generated-bytecode checks."
  },
  "paymentEvidencePreviewResultsLocatorContract": {
    "version": 44,
    "sourceRenderLocation": "Direct child of #pane-sub-import after the Guided Import card.",
    "requiredSelector": "#pane-sub-import > div.card.border-0.shadow-sm:not(.mb-4)",
    "expectedCountAfterPreview": 1,
    "prohibitedSelector": ".card:has(h6:has-text(\"Preview Results\"))",
    "reason": "The prohibited nested :has() selector also matches ancestor cards containing the preview card."
  },
  "paymentEvidenceEndToEndImportContract": {
    "version": 44,
    "scope": "One disposable profile, one preview, one Execute Import, exact batch review verification, exact batch deletion and exact profile deletion.",
    "expectedRows": 5,
    "expectedClassifiedRows": 5,
    "expectedUnresolvedRows": 5,
    "expectedExceptionRows": 0,
    "expectedRowKinds": {
      "CustomerPayment": 2,
      "FeeOrCharge": 1,
      "Refund": 1,
      "PayoutOrSettlement": 1
    },
    "expectedBatchStatus": "InReview",
    "executeImportClickCount": 1,
    "retryOrDuplicateSubmissionOutOfScope": true,
    "cleanupOrder": [
      "exact batch",
      "exact profile"
    ],
    "historicalBatchesProtected": true
  },
  "paymentEvidenceRetryDuplicatePreventionContract": {
    "version": 44,
    "scope": "Payment Evidence same-preview-operation retry and duplicate batch/row prevention.",
    "runtimeSubmission": "Submit the exact source-confirmed ExecuteImport form twice concurrently from the same preview state and session operation.",
    "acceptedSecondResponse": [
      "redirect to the same exact batch GUID",
      "safe return to import with Preview the payment evidence CSV again before executing the import."
    ],
    "requiredOutcome": "Exactly one unique batch GUID, exactly one active batch entry for the synthetic filename, and exactly five rows in that batch.",
    "sourceProof": {
      "serviceReuse": "Owned batch lookup by TenantId/ManagerId/OperationId/SourceArtifactId returns an existing batch.",
      "databaseFence": "Unique index UX_PaymentEvidenceImportBatches_Owner_OperationId on TenantId, ManagerId and OperationId."
    },
    "prohibited": [
      "two different batch GUIDs",
      "HTTP 500",
      "generic Payment Evidence import failure",
      "more than one active batch entry for the sample"
    ],
    "cleanup": "Delete every captured disposable batch GUID before deleting the exact disposable profile."
  },
  "paymentEvidenceOwnershipSecurityContract": {
    "version": 44,
    "scope": "One disposable Payment Evidence profile and batch are created in CIPC Example Holdings, denied from Basic Beside CIPC, restored in the owner workspace, then deleted exactly.",
    "runtimeProof": [
      "Owner workspace can open the exact batch and exact disposable profile.",
      "Foreign workspace cannot see the exact profile.",
      "Direct foreign access to the exact batch redirects with Payment evidence batch not found.",
      "Returning to the owner workspace restores exact batch access."
    ],
    "sourceProof": [
      "ExecuteImportAsync requires tenant, manager, user, operation and source-artifact ownership.",
      "CreateImportBatch copies TenantId, ManagerId, OperationId and SourceArtifactId.",
      "GetBatchAsync filters through OwnedBatches(tenantId)."
    ],
    "cleanup": "Delete only the captured batch GUID and profile GUID after owner access is restored.",
    "classification": "A foreign-tenant visibility/access leak after package certification is FAIL. Missing workspaces/permissions are BLOCKED. Selector/action/cleanup defects are TEST_INVALID."
  },
  "robotPythonLibraryContract": {
    "version": 44,
    "requiredClassName": "AtxCertifiedPhase25JCloseoutLibrary",
    "modulePath": "resources/AtxCertifiedPhase25JCloseoutLibrary.py",
    "requiredMethods": [
      "verify_package_certificate",
      "initialize_phase25j_closeout_recorder",
      "validate_acceptance_matrix",
      "validate_protected_profile",
      "validate_disposable_statement_profile_absence",
      "validate_production_baseline_detail",
      "validate_payment_evidence_cleanup",
      "validate_no_active_guided_session",
      "test_invalid",
      "blocked",
      "application_fail",
      "infrastructure_error",
      "finalize_phase25j_closeout_recorder"
    ]
  },
  "ocrProblemStateBankingUiCloseoutContract": {
    "version": 44,
    "scope": "Banking-only OCR problem-state correction persistence, Banking Profiles breadcrumb, Published-plus-current-Draft Guided Import coexistence, source-certified draft-only wording, and shared cancel/abandon behavior.",
    "mutationBoundary": "One exact owner-scoped Guided Import session and temporary OCR artifact; no acceptance, final import, batch, transaction or profile mutation.",
    "problemState": "Post invalid date and amount through visible first-row controls; blocking response must preserve posted values and disable acceptance.",
    "correctionPersistence": "Restore captured original values, Save Corrections, then perform a fresh exact-session GET and verify those values remain.",
    "cancelContract": "No-session Step 1 uses the Banking Overview link. Active session uses the shared modal/direct exact-session AbandonSession form.",
    "cleanup": "Abandon the exact session and verify Step 1 with no active session.",
    "outOfScope": [
      "Products",
      "Payroll",
      "Support email",
      "Payment Evidence import",
      "final Banking import",
      "mobile/responsive"
    ],
    "guidanceContract": "Runtime-prove the Published-plus-current-Draft branch in Basic Beside CIPC. Source-certify the true draft-only branch unless a safe runtime workspace is first proven to have managed profiles and zero Published import-ready versions."
  },
  "manifestVersionBindingContract": {
    "version": 44,
    "singleAuthority": "TestManifest.json contractVersion",
    "requiredEqualValues": [
      "TestManifest.schemaVersion",
      "TestManifest.requiredExecutableActionTraceVersion",
      "TestManifest.pythonRobotLibraryContract.version",
      "Source-of-Truth robotPythonLibraryContract.version",
      "Source-of-Truth ocrProblemStateBankingUiCloseoutContract.version",
      "Source-of-Truth manifestVersionBindingContract.version",
      "Source-of-Truth runtimePrerequisiteAndRobotExpressionContract.version"
    ],
    "installerRule": "The installer must derive the expected contract version from manifest.contractVersion and must not contain a previous package version literal.",
    "certifierRule": "The installed Python certifier must derive the expected version from manifest.contractVersion and verify every manifest and Source-of-Truth version binding before credentials or Chromium.",
    "deliveryRule": "A package containing a stale hard-coded contract version or unequal contract versions is TEST_INVALID and cannot be delivered."
  },
  "workspaceClientReadinessContract": {
    "version": 44,
    "rule": "Visible authenticated shell markup is not proof that workspace-switcher.js listeners are attached.",
    "requiredPattern": "Retry the visible workspace-chip click and modal-open postcondition as one atomic readiness action.",
    "prohibitedPattern": "One immediate click followed only by a 15-second modal wait.",
    "classification": "TEST_INVALID when the readiness action is incomplete."
  },
  "guidedNativeLabelSelectionContract": {
    "version": 44,
    "control": "#guidedProfile",
    "requiredPattern": "Use Run Keyword And Return Status with Select Options By exact label, then verify selected value and data-profile-scope. Read multiline select text only for diagnostics after selection fails.",
    "prohibitedPatterns": [
      "XPath cardinality against hidden option elements",
      "cross-page profile GUID lookup",
      "JavaScript option selection",
      "Robot IF expression containing pre-resolved multiline select text"
    ],
    "classification": "TEST_INVALID for selector/transport defects; BLOCKED only if the exact label is genuinely absent."
  },
  "robotExitCodeClassificationContract": {
    "version": 44,
    "robotSemantics": "Native exit codes 1 through 249 represent the number of failed tests, not infrastructure errors. Exit code 250 represents execution/framework failure.",
    "classificationOrder": [
      "ERROR",
      "TEST_INVALID",
      "FAIL",
      "BLOCKED",
      "PASS"
    ],
    "requiredRule": "Parse complete output.xml and aggregate all test failure messages. Any unprefixed Robot failure is TEST_INVALID and takes precedence over ATX_APP_FAIL; only fully prefixed certified application violations may produce FAIL.",
    "prohibitedRule": "Allowing one ATX_APP_FAIL marker to hide a separate unclassified Robot/package failure."
  },
  "runtimePrerequisiteAndRobotExpressionContract": {
    "version": 44,
    "runtimePrerequisiteRule": "Workspace names and current Draft badges are not lifecycle proof. A runtime branch may be asserted only after its complete prerequisite is proven.",
    "publishedPlusDraftRule": "A newer Draft may coexist with an earlier active Published version; Guided Import remains available.",
    "robotExpressionRule": "Robot IF/ELSE IF expressions must use $variable object syntax. Quoted pre-resolved '${variable}' expressions are prohibited because multiline or quoted values can create invalid Python expressions.",
    "classificationRule": "Missing prerequisite or unsafe expression is TEST_INVALID/BLOCKED, never ATX application FAIL.",
    "deliveryRule": "The final extracted package certifier must reject quoted pre-resolved Robot variables inside IF/ELSE IF and reject the old fixed draft-only workspace assumption."
  },
  "phase25JFinalCloseoutContract": {
    "version": 44,
    "scope": "Read-only final protected baseline, cleanup and acceptance closeout.",
    "ownerWorkspace": "CIPC Example Holdings",
    "protectedProfiles": [
      {
        "name": "Phase 25J OCR IMAGE TEST",
        "lifecycle": "v1 · Published"
      },
      {
        "name": "Phase 25J TEST A1",
        "lifecycle": "v1 · Published"
      }
    ],
    "productionBaseline": {
      "importSessionId": "c26a6a17-1425-45c7-b279-111d2d27549f",
      "operationId": "7031fccc-1393-4a20-b570-e7778a4074c9",
      "sourceArtifactId": "cb5bc07d-7292-4988-9ca5-6f4e6095b1f8",
      "batchId": "99bc4964-0bcb-4061-ad09-88574cd17ec6",
      "profileId": "8e16e3b3-0caa-4fe4-9824-e3dc292ca135",
      "profileVersionId": "749340bf-9a22-4103-b2a1-2a43d9650d42",
      "profileName": "ABSA bank statement",
      "accountId": "ec307879-4de7-4f14-9a4b-cfc9a3fade71",
      "accountName": "Demo Bank",
      "processedRows": 77,
      "importedRows": 77,
      "transactionCount": 77,
      "duplicateRows": 0,
      "skippedRows": 0,
      "errorCount": 0,
      "warningCount": 0,
      "status": "Completed"
    },
    "cleanupBoundary": {
      "noDisposableStatementProfilePrefixes": [
        "Phase 25J ADVANCED VISUAL TEST",
        "Phase 25J INTERPRETATION TEST",
        "Phase 25J RECOVERY TEST"
      ],
      "noDisposablePaymentEvidenceProfilePrefixes": [
        "Phase 25J PAYMENT EVIDENCE PREVIEW TEST",
        "Phase 25J PAYMENT EVIDENCE IMPORT TEST",
        "Phase 25J PAYMENT EVIDENCE RETRY TEST"
      ],
      "noPaymentEvidenceTestFileNames": [
        "ATX_Phase25J_Payment_Evidence_Profile_Preview_Test.csv",
        "ATX_Phase25J_Payment_Evidence_End_To_End_Import_Test.csv",
        "ATX_Phase25J_Payment_Evidence_Retry_Duplicate_Prevention_Test.csv",
        "ATX_Phase25J_Payment_Evidence_Ownership_Security_Test.csv"
      ],
      "activeGuidedSessionMustBeNull": true,
      "readOnly": true
    },
    "productionWorkspace": "Basic Beside CIPC"
  },
  "phase25JProductionBaselineWorkspaceContract": {
    "version": 44,
    "protectedTestWorkspace": "CIPC Example Holdings",
    "productionBaselineWorkspace": "Basic Beside CIPC",
    "rule": "Protected Phase 25J TEST profiles and Payment Evidence cleanup are verified in CIPC Example Holdings. The preserved ABSA 77-row production baseline is verified in Basic Beside CIPC.",
    "classification": "Using the wrong tenant workspace for an exact tenant-scoped batch lookup is TEST_INVALID, not BLOCKED and not an ATX application failure.",
    "runtimeRequirement": "Switch explicitly to the contract workspace immediately before each tenant-scoped read and return to the owner TEST workspace before subsequent TEST-state checks."
  },
  "phase25HD2BProcessingUsageContract": {
    "status": "Implemented; website acceptance pending",
    "browserBoundary": "Deployed website only; no SQL, database client, appsettings lookup or direct table access.",
    "directText": "DirectTextExtraction / Pages; no OCR event.",
    "pdfOcr": "OcrExtraction / Pages.",
    "imageOcr": "OcrExtraction / Images.",
    "fallback": "Direct text attempt and OCR work are separate actual-operation facts.",
    "imagePreparation": "ImagePreparation / Images / 1 only when preparation executes.",
    "cachedRemap": "CachedRemap / Operations / 1; OCR is not rerun.",
    "recovery": "RecoveryAttempt / Attempts / 1 per real executed retry, plus provider work.",
    "websiteAcceptance": "Browser proves processing actions, visible counters, bounded history, no-rerun behavior and cleanup. Source/unit contracts certify internal event type, units, deterministic keys, ownership and fail-closed behavior.",
    "sqlRequirement": "None."
  }
}
```
<!-- END ATX_ACTION_CONTRACTS_JSON -->

---

## V13 prepared-image readiness validation addendum

- Statement Interpretation V1 result audited: **TEST_INVALID**, not application FAIL.
- PrepareImage response completed and the screenshot showed the prepared image after the premature assertion.
- `statement.prepare-image` now includes token, section, controller and fully-loaded image postconditions.
- Exact Draft `48adcabc-8171-4611-aa96-845e243650fd` was deleted; V13 requires the recorder to persist that successful cleanup evidence.
- No ATX application or database change is justified by this result.


## V14 stable manual-column identity validation addendum

- Statement Interpretation V1.1 result audited: **TEST_INVALID**, not ATX application FAIL.
- Prepared-image readiness passed; initial OCR produced three rows.
- Failure occurred before interpretation configuration, Remap and value assertions.
- The package used positional card selectors while the source re-sorted cards by `leftPercent`.
- Exact Draft `3e1f18ac-7806-440d-a904-bd40131e8dbe` was deleted successfully.
- No ATX application or database change is justified.


## V15 generated-bytecode package-hygiene validation addendum

- Statement Interpretation V1.2 installer result audited: **TEST_INVALID**, before Robot and Chromium.
- The package contained mutable `__pycache__` bytecode and its checksum changed after compilation.
- No login, Draft creation, OCR, Remap, persistence or cleanup action ran.
- Package V1.2.1 removes all generated bytecode and adds package-root, installed-root and runtime prevention gates.
- No ATX application, database or SQL change is justified.


## V16 interpretation-sample calibration validation addendum

- Statement Interpretation V1.2.1 runtime result: **BLOCKED** after cached Remap produced three rows.
- The first date-only transaction row absorbed the following same-date transaction in the synthetic sample.
- The exact disposable Draft `b9d58796-5e10-490f-8304-448878d47898` was deleted successfully.
- No profile was published and no Guided Import, batch or transaction was created.
- V1.2.2 replaces only the synthetic sample and its exact expected-row contract.
- No ATX application, database or SQL change is justified.


## V17 manual visual wrapped-row hotfix validation addendum

- Statement Interpretation V1.2.2 recorded result: **BLOCKED**.
- Runtime evidence reproduced four calibrated rows with the expected dates, references, source file, amounts and balances.
- The first description omitted `Additional wrapped invoice detail`.
- Source audit confirmed that manual visual mapping did not apply wrapped/continuation settings.
- The hotfix merges only undated, amountless continuation rows into the previous description when all three controls are enabled.
- The hotfix adds enabled and disabled regression tests.
- Changed engine SHA-256: `a65eef89f7d6147a79ef7913e49d0fecb14b98ae8557a0f3de8de88540691fae`.
- Changed test SHA-256: `86dd032ebdf53d3db86d1603d5628656d0ff94e0359cef44537ac4876997a557`.
- `dotnet build` and `dotnet test` remain unexecuted in this environment because the .NET SDK is unavailable.


## V18 cached-remap balance-warning hotfix validation addendum

- Statement Interpretation V1.3 runtime result: **FAIL**.
- All four certified rows, wrapped description, signs, ordering and balances matched.
- A stale provider `Running balance variance` warning remained after cached Remap.
- Source audit confirmed `BankStatementCachedExtractionInterpreter` removed profile-derived warnings but not pre-mapping balance diagnostics.
- The hotfix removes only known balance-reconciliation diagnostics before current mapping and validation.
- Current validation failures are still emitted as fresh `VALIDATION-RUNNINGBALANCE` warnings.
- Exact Draft `faf8eef7-c3e0-49b4-91de-5fa0035a9a64` was deleted successfully.
- Changed interpreter SHA-256: `4888413cfef3d83c2347004d739bc5e98a304abf60dd2d21447eb4e8e712a2be`.
- Changed regression-test SHA-256: `66aef6eb6904d0502a0144fe6e67409e6f803ba3e8609567d982e06ed463d73a`.
- `dotnet build` and `dotnet test` remain unexecuted because the .NET SDK is unavailable in this environment.




## V19 low-confidence bounded-recovery validation addendum

- Statement Interpretation V1.4 runtime result: **PASS**.
- Four calibrated rows, wrapped description, amount precedence, same-date order and running-balance chain passed.
- No stale provider balance warning remained after cached Remap.
- Exact disposable Draft `4b39ec36-2ea7-4a45-9355-b6d2034d347e` was deleted.
- No profile was published and no Guided Import, batch or transaction was created.
- The next focused scope is low-confidence outcome, bounded recovery and source-scored best-result selection.
- V19 adds the visible validation/recovery editor and recovery-history contracts.


# Part IV — ATX Source–Action Validation Record

# ATX Robot Source–Action Matrix Validation

- **Authoritative ZIP:** `Project Context File(13).zip`
- **ZIP SHA-256:** `b39e7ba45d6c1ec1abb99cf8f0d23a86095e32beae0a76593453166041fc38ff`
- **Mapped actions:** 67
- **Unique action IDs:** 67
- **Source files hashed:** 14
- **All source anchors found:** PASS
- **All mapped source files present:** PASS
- **All mapped PageModel method anchors present where specified:** PASS
- **JSON parse validation:** PASS
- **No executable test package included:** TRUE

## Validation boundary

This validates the documentation and source mapping against Project Context File(13).zip. It does not prove the deployed production DOM matches the code; each test must still run the matrix-defined read-only runtime preflight.


## V2 validation addendum

- **Mapped actions after update:** 48
- **Unique action IDs:** 67
- **New action IDs:** `statement.open-detailed-section`, `statement.open-major-section`, `statement.read-ajax-outcome`, `statement.read-test-outcome`
- **All new source anchors found in Project Context File(13).zip:** PASS
- **Embedded JSON parse:** PASS
- **Duplicate action IDs:** 0


## V3 package-layout validation addendum

- **Action contracts retained:** 48
- **Unique action IDs:** 67
- **Package-layout contract schema:** 1
- **Separate package-root, payload and installed namespaces:** REQUIRED
- **Ambiguous `requiredFiles` property:** PROHIBITED
- **Installer-equivalent copy simulation before delivery:** REQUIRED
- **Final ZIP re-extraction and repeat simulation:** REQUIRED
- **Embedded JSON parse:** PASS


## V4 navigation-contract validation addendum

- **Action contracts retained:** 48
- **Unique action IDs:** 67
- **Navigation contract schema:** 1
- **Raw `Go To    ${href}`:** PROHIBITED
- **Exact scoped anchor click after GUID verification:** APPROVED
- **Absolute URL resolution with ATX-origin verification:** APPROVED
- **Whole-suite href-to-navigation scan before delivery:** REQUIRED
- **Embedded JSON parse:** PASS


## V5 repeated-action validation addendum

- **Action contracts retained:** 48
- **Unique action IDs:** 67
- **Repeated-action contract schema:** 1
- **Save Draft & Exit render locations mapped:** 4
- **Desktop canonical primary selector expected count:** 1
- **Desktop Save-section combined expected count:** 2
- **Global uniqueness assertion for repeated actions:** PROHIBITED
- **Canonical render-location click required:** YES
- **Embedded JSON parse:** PASS


## V6 multi-evidence/archive validation addendum

- **Mapped actions:** 67
- **Unique action IDs:** 67
- **Source files hashed:** 14
- **New archive/action IDs:** 7
- **Direct multiple-image synthetic ZIP contract:** MAPPED
- **Image-only ZIP contract:** MAPPED
- **PDF-only ZIP contract:** MAPPED
- **Mixed PDF/image ZIP rejection:** MAPPED
- **Per-file review summaries:** MAPPED
- **Exact screenshot dedup/order contract:** MAPPED
- **Embedded JSON parse:** PASS


## V7 calibration/classification validation addendum

- **Mapped actions retained:** 55
- **Unique action IDs:** 67
- **Source files hashed:** 14
- **Synthetic evidence calibration contract:** ADDED
- **Known reliable OCR dates:** 4
- **Known unstable OCR row excluded from corrected hard assertions:** REQUIRED
- **Independent archive scenarios as separate Robot tests:** REQUIRED
- **Per-test exact-session cleanup:** REQUIRED
- **All-failure runner aggregation:** REQUIRED
- **Runner/recorder classification agreement:** REQUIRED
- **Embedded JSON parse:** PASS


## V8 session-schema validation addendum

- **Mapped actions:** 67
- **Unique action IDs:** 67
- **Source files hashed:** 14
- **Exact session properties mapped:** 15
- **`step` property source-confirmed:** YES
- **`currentStep`/`CurrentStep` browser fallback:** PROHIBITED
- **Schema validation before value assertions:** REQUIRED
- **Mixed archive rejection tail-only rerun:** REQUIRED
- **Previously passing direct/image-ZIP/PDF-ZIP scenarios:** DO NOT RERUN
- **Embedded JSON parse:** PASS


## V9 advanced-visual validation addendum

- **Mapped actions:** 67
- **Unique action IDs:** 67
- **Source files hashed:** 14
- **New advanced-visual actions:** 10
- **Visible dynamic editor interaction:** REQUIRED
- **Direct hidden JSON writes:** PROHIBITED
- **Dedicated never-published Draft:** REQUIRED
- **Initial OCR followed by cached Remap:** REQUIRED
- **Exact reload and Draft deletion:** REQUIRED
- **Embedded JSON parse:** PASS


## V10 catalogue-create/cleanup validation addendum

- **Mapped actions retained:** 66
- **Unique action IDs:** 67
- **Source files hashed:** 14
- **Exact scoped Statement create selector:** REQUIRED
- **Global Statement route-prefix selector:** PROHIBITED
- **No-op cleanup reported as deletion:** PROHIBITED
- **Recorder/runner cleanup agreement:** REQUIRED
- **Embedded JSON parse:** PASS


## V11 Statement readiness validation addendum

- **Mapped actions:** 67
- **Unique action IDs:** 67
- **Source files hashed:** 14
- **Statement client-controller readiness marker:** MAPPED
- **DOM visibility alone accepted as readiness:** NO
- **Direct mode dataset/localStorage writes:** PROHIBITED
- **Advanced click after ready marker:** REQUIRED
- **Readiness reused after AJAX replacement:** REQUIRED
- **Embedded JSON parse:** PASS


## V12 statement-interpretation validation addendum

- **Mapped actions:** 71
- **Unique action IDs:** 71
- **Source files hashed:** 15
- **Calibrated wrapped-row result contract:** MAPPED
- **Signed Amount and Debit/Credit fallback:** MAPPED
- **Same-date source ordering:** MAPPED
- **Running-balance chain:** MAPPED
- **Initial OCR followed by cached Remap:** REQUIRED
- **Exact Draft deletion:** REQUIRED
- **Embedded JSON parse:** PASS

## V17 wrapped-row implementation validation addendum

- **Mapped actions:** 71
- **Unique action IDs:** 71
- **Source files hashed:** 16
- **Manual visual continuation merge source anchor:** `CanMergeContinuationRow`
- **Enabled-path regression test:** ADDED
- **Disabled-path regression test:** ADDED
- **Calibration/functional boundary corrected:** YES
- **Embedded JSON parse:** PASS

## V18 cached-remap balance-warning validation addendum

- **Mapped actions:** 71
- **Unique action IDs:** 71
- **Source files hashed:** 18
- **Stale-balance filter source anchor:** `IsStaleBalanceDiagnostic`
- **Passing-chain regression test:** ADDED
- **Failing-chain replacement-warning regression test:** ADDED
- **Current remapped validation authority:** REQUIRED
- **Embedded JSON parse:** PASS

## V19 low-confidence recovery validation addendum

- **Mapped actions:** 77
- **Unique action IDs:** 77
- **Source files hashed:** 21
- **Visible validation-rule editor:** MAPPED
- **Visible recovery limits and attempts:** MAPPED
- **MaximumAttempts includes primary:** YES
- **Rendered recovery-history schema:** MAPPED
- **Source score and strict tie rule:** MAPPED
- **Direct validation/retry JSON writes:** PROHIBITED
- **Embedded JSON parse:** PASS

## V20 recovery metric-authority validation addendum

- **Mapped actions:** 77
- **Unique action IDs:** 77
- **Source files hashed:** 21
- **Provider-stage recovery CandidateCount:** SCORE AUTHORITY
- **Final Test Results transaction summary:** MAPPED-ROW AUTHORITY
- **Attempt CandidateCount equals final rows:** PROHIBITED ASSUMPTION
- **Cleanup recording after assertion abort:** REQUIRED
- **Historical V1 classification:** TEST_INVALID
- **Embedded JSON parse:** PASS

## V21 final-import retry/idempotency validation addendum

- **Mapped actions:** 84
- **Unique action IDs:** 84
- **Source files hashed:** 23
- **BankImportService SHA-256:** `f5dac85ea058476cc50210d49f5a35ac795901093c6818e888297c09841c0653`
- **ImportSessionService SHA-256:** `cb659e0f76f53cb98fdb9382963b398fc69dda928fca7fa85b283add9f0da7bd`
- **Runtime-unique filename contract:** ADDED
- **Same-session concurrent retry contract:** ADDED
- **BatchDetail transaction authority:** ADDED
- **Exact undo cleanup contract:** ADDED
- **Embedded JSON parse:** PASS

## V22 exact profile identity validation addendum

- **Mapped actions:** 84
- **Unique action IDs:** 84
- **Source files hashed:** 23
- **Exact Published catalogue card proof:** REQUIRED
- **Profile GUID parsed from scoped Statement Configure anchor:** REQUIRED
- **Guided Import option matched by exact GUID value:** REQUIRED
- **Name-only dropdown miss treated as missing prerequisite:** PROHIBITED
- **Published-card/import-option contradiction after fresh workspace GET:** APPLICATION FAIL
- **Historical V1 result classification:** TEST_INVALID
- **Embedded JSON parse:** PASS

## V23 Guided Import option-authority validation addendum

- **Mapped actions:** 84
- **Unique action IDs:** 84
- **Source files hashed:** 23
- **Cross-page Configure GUID as select-option authority:** PROHIBITED
- **Exact Guided Import option text and user scope:** REQUIRED
- **Option own submitted value captured and selected:** REQUIRED
- **Account selected before profile-resolution wait:** REQUIRED
- **Historical V22 package correction classification:** TEST_INVALID
- **Embedded JSON parse:** PASS



## V24 Guided Import no-catalogue-detour validation addendum

- **Mapped actions:** 84
- **Unique action IDs:** 84
- **Source files hashed:** 23
- **Direct Guided Import navigation:** REQUIRED
- **Global `.bp-profile-card` strict wait:** PROHIBITED
- **Catalogue detour for select-option prerequisite:** PROHIBITED
- **Exact `#guidedProfile` option as submitted-value authority:** REQUIRED
- **Historical V1.1/V1.2 correction classification:** TEST_INVALID
- **Embedded JSON parse:** PASS

## V25 BatchDetail JavaScript-argument validation addendum

- **Mapped actions:** 84
- **Unique action IDs:** 84
- **Source files hashed:** 23
- **Raw root-relative URL passed to `Evaluate JavaScript`:** PROHIBITED
- **Exact BatchDetail trigger dataset as fetch authority:** REQUIRED
- **Detail trigger re-resolved after undo:** REQUIRED
- **Historical V1.2.1 result classification:** TEST_INVALID
- **Embedded JSON SHA-256:** `12912dcdd2fc4d80585a0f10853da53fe6fb18ad26f52512e486ef33a9ccb697`
- **Embedded JSON parse:** PASS

## V26 warning-aware final-import status and cleanup-tail validation addendum

- **Mapped actions:** 84
- **Unique action IDs:** 84
- **Source files hashed:** 23
- **Successful import always requires Completed:** PROHIBITED
- **Batch status derived from imported/warning/error counts:** REQUIRED
- **Undo redirect assumed to remain on visible history:** PROHIBITED
- **Explicit history GET and post-Undo BatchDetail proof:** REQUIRED
- **Tail-only reuse of exact V1.2.2 batch:** REQUIRED
- **Historical V1.2.2 result classification:** TEST_INVALID
- **Embedded JSON SHA-256:** `aa29a3d9a26b36a40d71b358f107c9ebe82c2372be1fae60fa48522aadba3347`
- **Embedded JSON parse:** PASS



## V27 cross-tenant BatchDetail denial validation addendum

- **Mapped actions:** 84
- **Unique action IDs:** 84
- **Updated action:** `imports.batch-detail-json`
- **Owner workspace:** `CIPC Example Holdings`
- **Foreign workspace:** `Basic Beside CIPC`
- **Exact batch:** `5dfddb23-81d7-4400-85d0-806034cdc882`
- **Contract:** owner read succeeds, foreign read returns `Import batch not found.`, and owner read succeeds again after returning.
- **Mutation boundary:** read-only; no session, upload, import, undo, profile, batch or transaction mutation.
- **Embedded JSON SHA-256:** `5f837e515d347deb7ed3404eb252dff8f5ca787ed2cb789407f26744dc5c0424`

## V28 owner, account and exact-version lineage certification addendum

- **Mapped actions:** 84
- **Unique action IDs:** 84
- **Runtime actions:** `profiles.find-exact-user-card`, `profiles.read-card-lifecycle`, `profiles.configure-exact-statement`, `imports.batch-detail-json`
- **Exact retained session:** `e5e868d5-1572-4f10-ad29-8edca1129815`
- **Exact retained batch:** `5dfddb23-81d7-4400-85d0-806034cdc882`
- **Exact account:** `9ae8b4b7-ffd8-4a31-8159-fcdcb8fa7dca` — `ATX UI TEST BANK`
- **Exact profile:** `9ca8ca44-2b98-48e5-89f6-fa933022928c` — `Phase 25J OCR IMAGE TEST` — `v1 · Published`
- **Runtime proof:** owner-visible exact batch, account, profile and lifecycle identity.
- **Source-confirmed proof:** manager, operation, source-artifact, account, profile and exact-version fail-closed propagation and batch persistence.
- **Proof boundary:** raw manager/operation/artifact GUIDs are not claimed as browser-visible evidence.
- **Mutation boundary:** read-only; no session, upload, import, undo, profile, batch or transaction mutation.
- **Embedded JSON SHA-256:** `8c38e3c9e7adb38af4efa031559d3c6259892e9c01b2b98af7460f8ad7400286`
- **Embedded JSON parse:** PASS

## V29 focused July 27 UI/runtime regression validation addendum

- **Mapped actions:** 95
- **Unique action IDs:** 95
- **Source files hashed:** 37
- **Login current-password metadata:** MAPPED
- **Banking Profiles breadcrumb:** MAPPED
- **Draft-only Guided Import publication guidance:** MAPPED
- **Product stock overview route and legacy redirect:** MAPPED
- **Desktop multi-row collapse contract:** MAPPED
- **Optional Product Category colour transport:** MAPPED
- **Inventory Count removed debug evidence:** MAPPED
- **Payroll Reminders nullable-query runtime route:** MAPPED
- **Support-email bounded transient retry:** SOURCE-CERTIFIED ONLY
- **Support-email circuit-breaker update and duplicate-log removal:** SOURCE-CERTIFIED ONLY
- **Statement editor breadcrumb:** NOT INCLUDED; remains a separately identified source gap
- **Mutation boundary:** read-only; no profile, category, count, payroll, email, import, batch or transaction mutation
- **Embedded JSON SHA-256:** `dba29020c88105bf7e0ddbdc96e41a7bea4ebfdfed9d9ddc2b305277933fa351`
- **Embedded JSON parse:** PASS

## V30 Payment Evidence profile and preview validation addendum

- **Active route family:** `/Banking/PaymentEvidence*`
- **Mapped actions:** 103
- **Unique action IDs:** 103
- **V29 non-Banking UI package:** WITHDRAWN
- **Payment Evidence profile lifecycle:** active/inactive tenant profile; not Statement Draft/Published
- **Profile preview transport:** AJAX `PreviewPaymentEvidenceProfile`
- **Import preview transport:** full POST `UploadPreview`
- **Expected preview:** 5 total, 5 classified, 0 unknown, 1 duplicate
- **Import execution:** PROHIBITED in this scope
- **Exact profile cleanup:** REQUIRED
- **Embedded JSON SHA-256:** `a1e9d85d8a967c4290c10d7f1cea531eb5b45911ccc36be223add076f623d531`
- **Embedded JSON parse:** PASS

## V31 Robot keyword-resolution certification addendum

- **Historical Payment Evidence Profile Preview V1 classification:** ERROR caused by a test-package keyword defect.
- **Unsupported keyword `Set Input Files`:** PROHIBITED.
- **Browser file upload keyword:** `Upload File By Selector` REQUIRED for the two mapped file-input actions in this scope.
- **External Robot keyword allowlist:** REQUIRED in the package manifest.
- **Every executable Robot keyword call:** MUST resolve to a package-defined custom keyword or an explicitly allowlisted library keyword before delivery.
- **Non-allowlisted external keyword:** TEST_INVALID during package certification.
- **Target-machine Robot dry-run:** remains mandatory and must pass before Chromium starts.
- **Runtime side effects from the failed package:** none; Robot stopped before browser execution.
- **ATX application/source/database change:** none required.

## V32 conditional Payment Evidence import-control rendering addendum

- **Historical V1.0.1 result:** `TEST_INVALID`.
- **Observed runtime state:** the workspace had zero Payment Evidence profiles, so the source-valid no-profile guidance rendered and `#PreviewProfileId` / `#PreviewFile` were intentionally absent.
- **Source condition:** the Guided Import form renders only inside `else` for `Model.HasPaymentEvidenceProfiles`.
- **Initial preflight:** certify profile-editor controls and certify conditional import-control presence against the current profile count.
- **After exact profile creation:** require the import profile select, CSV input and `UploadPreview` button before import preview.
- **Prohibited regression:** globally requiring conditionally rendered Guided Import controls before creating the first profile.
- **Classification:** package/test-contract defect; no ATX application or database change required.



## V33 native Payment Evidence profile-option selector addendum

- **Historical V1.0.2 result:** `TEST_INVALID`.
- **Completed before failure:** profile preview mapping, exact save, exact reopen and exact profile cleanup.
- **Failure:** Browser `Evaluate JavaScript` received a second parser/argument form that produced `SyntaxError: Invalid or unexpected token`.
- **Required exact option authority:** `#PreviewProfileId option[value="${PROFILE_ID}"]`.
- **Simple select-option existence checks:** MUST use a native scoped selector and `Get Element Count`.
- **Raw Robot scalar appended to `Evaluate JavaScript` for option lookup:** PROHIBITED.
- **Import execution:** remains prohibited in this scope.
- **ATX application/source/database change:** none required.

## V34 executable action trace and scoped Payment Evidence preview-result contract

- **Historical V1.0.3 result:** `TEST_INVALID`.
- **Completed before failure:** disposable profile creation, visible mapping, save, exact-ID reopen and exact cleanup.
- **Failure:** `.card:has(h6:has-text("Preview Results"))` matched the preview card and two ancestor cards.
- **Required preview selector:** `#pane-sub-import > div.card.border-0.shadow-sm:not(.mb-4)`.
- **Executable contract:** every manifest action ID must be marked in Robot with `# ATX-ACTION: <id>` and mechanically validated against its Source-of-Truth `robotBindings`.
- **Delivery gate:** the final extracted ZIP must pass action-ID existence, marker coverage, keyword binding, required-pattern and prohibited-pattern validation.
- **ATX application/source/database change:** none required.

## V35 Payment Evidence end-to-end import contract

- Reuses the accepted V34 profile-creation and preview controls only as setup.
- Executes **one** exact import; retry/duplicate resubmission remains the next separate scope.
- Requires the exact redirected batch GUID, `InReview` status, five rows, five unresolved, zero exceptions and the calibrated row-kind distribution.
- Cleanup order is exact batch deletion followed by exact disposable profile deletion.
- Historical Payment Evidence batches and protected Banking profiles remain untouched.
- Every executable action remains mechanically bound to an `ATX-ACTION` contract.



## V36 Payment Evidence retry and duplicate-prevention addendum

- **Runtime retry:** the exact ExecuteImport form is submitted twice from one preview operation.
- **Accepted result:** one unique batch GUID; the second response may reuse that batch or safely require a new preview.
- **Duplicate prevention:** exactly one active batch entry and five rows; two batch GUIDs are an application failure.
- **Source fence:** existing-batch lookup plus `UX_PaymentEvidenceImportBatches_Owner_OperationId`.
- **Cleanup:** every captured disposable batch is deleted before the exact profile.
- **Scope:** `/Banking/PaymentEvidence*` only.

## V38 Python Robot library exposure validation addendum

- **Historical Payment Evidence Ownership V1 result:** `ERROR` before Chromium.
- **Root cause:** `AtxCertifiedPaymentEvidenceSecurityLibrary.py` contained class `AtxCertifiedPaymentEvidenceProfileLibrary`.
- **Required module-stem class:** `AtxCertifiedPaymentEvidenceSecurityLibrary`.
- **Python AST parse:** REQUIRED.
- **Required Robot keyword method exposure:** REQUIRED.
- **Installer class/module check:** REQUIRED.
- **Installed certifier class/module and method check:** REQUIRED.
- **Final package dry-run:** still mandatory before Chromium.
- **Runtime side effects from failed package:** none.
- **ATX application/source/database change:** none required.

## V39 OCR problem-state and Banking UI closeout validation addendum

- **Previous Payment Evidence ownership result:** PASS.
- **Mapped actions:** 117
- **Unique action IDs:** 117
- **Active scope:** `/Banking/Profiles*` and `/Banking/Imports*` only.
- **No-session Cancel:** exact Banking Overview link; no ImportSession created.
- **Active-session Cancel:** shared exact-session `AbandonSession` path.
- **OCR problem state:** invalid date and amount must render as blocking and preserve the posted values on the returned page.
- **Persistence authority:** only the subsequent valid Save Corrections redirect may be used as persisted-session proof.
- **Fresh reload:** exact session values must remain after a new GET.
- **Import boundary:** extraction is not accepted; no final import, batch or transaction is created.
- **Executable action trace:** every manifest action is mechanically bound to a Source-of-Truth action ID.
- **Python library contract:** `AtxCertifiedOcrUiCloseoutLibrary`.
- **Embedded JSON SHA-256:** `41368e235d1fed353508fada65f56ebc5e3b579868b458d65b954e30680da821`
- **Embedded JSON parse:** PASS



## V40 manifest-derived package contract version validation addendum

- **Historical OCR UI Closeout V1 installer result:** `TEST_INVALID` before Robot and Chromium.
- **Root cause:** the V39 manifest and Source of Truth were correct, but `Install-And-Run.ps1` still hard-coded Python Robot library contract version `38`.
- **Permanent rule:** `TestManifest.json contractVersion` is the single package-version authority.
- **Installer:** derives the expected version from the manifest and verifies all manifest and embedded Source-of-Truth version fields match it.
- **Installed certifier:** performs the same dynamic equality checks before credentials or Chromium.
- **Prohibited:** previous-version numeric literals inside package contract validation logic.
- **Classification:** any stale or unequal version binding is `TEST_INVALID`.
- **Runtime side effects:** none; the failed installer stopped before installation completed or Chromium started.
- **ATX application/source/database change:** none required.


## V41 runtime-readiness, native-selection and Robot-exit classification addendum

- **Historical V1.0.1 result:** `TEST_INVALID`, although the runner incorrectly labelled two normal failed tests as `ERROR`.
- **Workspace-switch cause:** the visible workspace chip was clicked before `workspace-switcher.js` had attached its listener; the modal stayed hidden.
- **Guided-profile cause:** the package used XPath cardinality against hidden `<option>` transport elements instead of the native select-label contract.
- **Permanent workspace rule:** retry the visible user click and `#workspaceSwitcherModal.show` postcondition as one atomic readiness action.
- **Permanent select rule:** use `Select Options By` with the exact label, then verify the selected value, text and `data-profile-scope`.
- **Permanent runner rule:** Robot exit codes 1-249 are failed-test counts. Classification comes from complete `output.xml` and aggregated markers; only 250 or execution errors are infrastructure `ERROR`.
- **Runtime side effects:** none. No ImportSession, batch or transaction was created.
- **ATX application/source/database change:** none required.

## V42 runtime-prerequisite, Robot-expression and aggregate-classification addendum

- **Historical V1.0.2 result:** `TEST_INVALID`, not application `FAIL`.
- **Guidance prerequisite defect:** `Basic Beside CIPC` was incorrectly assumed to be Draft-only from its current Draft card. The profile still has an earlier Published import-ready version, so Guided Import correctly rendered Step 1.
- **Permanent lifecycle rule:** a current Draft badge does not prove that no Published version exists.
- **Runtime guidance proof:** verify the Published-plus-current-Draft coexistence branch. The true Draft-only wording remains source-certified until a safe workspace is proven to have managed profiles and zero Published versions.
- **Robot expression defect:** quoted pre-resolved `${variable}` values inside `IF` can become invalid expressions when values contain newlines or quotes.
- **Permanent Robot rule:** `IF` and `ELSE IF` use `$variable` object syntax; quoted pre-resolved variables are rejected during package certification.
- **Aggregate classification:** any unprefixed Robot failure makes the run `TEST_INVALID` and takes precedence over an `ATX_APP_FAIL` from another test.
- **Runtime side effects:** no ImportSession, batch or transaction was created.
- **ATX application/source/database change:** none required.
- **Embedded JSON SHA-256:** `122b2040b8bb373327e9e52042b6896404aa8442ccb87dd9dcd6e7c4ddcf17b4`

## Historical V46 Phase 25H-D2-A SQL-assisted package addendum — withdrawn

- **Previous phase:** Phase 25J is closed at 100%.
- **D1-A:** schema and inert usage foundation accepted and deployed.
- **D2-A code:** approved implementation package created.
- **D2-A runtime acceptance:** focused Robot/Playwright plus SELECT-only SQL verification package prepared.
- **Mapped actions:** 128
- **Unique action IDs:** 128
- **New D2-A actions:** 4
- **Authoritative base ZIP:** `Project Context File(15).zip`
- **D1-A package SHA-256:** `f44a89caea6a881efefcbd1c02489e808f67e090fba17cde371a348b23a607a4`
- **D2-A package SHA-256:** `511c6fcbb167b3d6a8597e15ed8088caef072a31d8c77a86dc96b1ad9d81becf`
- **Combined authority SHA-256:** `b3f2307ca4dc77e94d97df4656607e108f50e12d2da637d58de303ded88da177`
- **Embedded JSON SHA-256:** `8be6b77e24d290a58670c63997c606e946c88f4976fc45c3096b068c094a80e2`
- **Embedded JSON parse:** PASS
- **Runtime SQL boundary:** parameterized SELECT only; credentials never logged or packaged.
- **Expected persistent test residue:** one append-only usage event only; disposable profile, batch and rows are deleted.

## Historical V46 Phase 25H-D2-A SQL-verifier correction addendum — withdrawn

- **Historical package:** `ATX_Phase25H_D2A_Artifact_Storage_Usage_Robot_V1.zip`
- **Historical result:** `ERROR`
- **Audited cause:** the package's SELECT-only PowerShell helper raised `System.ArgumentException` while constructing its SQL connection, before the Baseline query.
- **Application evidence:** none; no disposable profile, batch, artifact or usage assertion was reached.
- **Corrected package:** V1.1.
- **Verifier change:** parameterless `SqlConnection` construction followed by separate `ConnectionString` assignment.
- **New preflight:** executable `SelfTest` validates local configuration, SqlClient loading, connection-string construction and helper output before Robot opens Chromium.
- **New evidence:** sanitized per-stage verifier logs.
- **Reporting correction:** mutation and verification flags come only from the recorder and usage-stage evidence; they are not hard-coded.
- **ATX application/source/database change:** none required.



## V47 website-only Robot boundary correction addendum

- **Correction:** all direct SQL/database integration was removed from the Phase 25H-D2-A Robot package.
- **Permanent boundary:** ATX Robot packages may test only what the deployed website exposes through browser actions, DOM, same-origin page responses, downloads and visual evidence.
- **Prohibited:** SQL clients, appsettings database lookup, connection strings, table queries and database helper scripts.
- **Withdrawn packages:** D2-A V1 and V1.1.
- **Replacement:** D2-A Website-Only V1.2.
- **Browser scope:** exact Payment Evidence profile creation, CSV preview, double-submit retry, one visible batch, exact batch review and exact cleanup.
- **Not browser-proven:** BankingUsageEvents row identity, quantity, event key or persistence.
- **Mapped actions:** 127
- **Unique action IDs:** 127
- **Embedded JSON SHA-256:** `411e160bddca3c914955b147c738cd478cf05c82248576eddf9bd8f9000f7761`
- **ATX application/database change:** none.

## V53 Phase 25H-D2-B processing-usage acceptance addendum

- **Authoritative implementation:** `ATX_Banking_Phase25H_D2B_Processing_Usage_20260731.zip`.
- **Website scope:** one exact disposable Statement Draft copied from the ABSA starter.
- **Processing paths:** direct selectable-PDF text, preview-only image preparation, image OCR, cached Remap without OCR, and exactly three bounded recovery attempts.
- **Runtime boundary:** deployed website only; no SQL, configuration lookup, project-source inspection or direct usage-ledger access.
- **Browser proof:** visible processing mode, page/count metrics, OCR-not-rerun feedback, recovery history and exact cleanup.
- **Internal accounting proof:** D2-B source/unit contracts certify usage type, units, owner lineage, deterministic event keys and fail-closed persistence.
- **Cleanup:** clear the temporary sample before deleting the exact never-published Draft; never publish or start Guided Import.
- **SQL requirement:** none.
- **Mapped actions:** 137.
- **Unique action IDs:** 137.
- **Embedded JSON SHA-256:** `0e5d301fbfb4129cc2746b3d49624e96a7df00a08b6ebfdcee6d5694af388baf`.



## V53 Dynomax foundation migration addendum

- **Previous D2-B V1 result:** `TEST_INVALID`; no processing assertion ran.
- **Corrected source contract:** visible desktop lifecycle badge is scoped to `.statement-page-header .statement-header-meta`.
- **Cleanup recorder correction:** fallback deletion must persist the exact deleted GUID and true deletion state.
- **Migration decision:** do not rebuild the legacy standalone Robot V1.1 package.
- **Next execution:** create a Dynomax authenticated/workspace/Draft foundation workflow first, then port the complete D2-B scenario.
- **Runtime boundary:** website only; no SQL, appsettings, connection strings, source inspection or internal usage-table query.
- **SQL requirement:** none.
- **ATX application/database change:** none.


## V60 D2-B responsive Test Lab and JavaScript-argument correction addendum

- **Historical V1.0.3 result:** `TEST_INVALID`; the direct-text extraction request reached the result surface but the Robot evaluator emitted the dynamic label `Pages processed` as unquoted JavaScript and failed with `SyntaxError: Unexpected identifier 'processed'`.
- **Permanent evaluator rule:** every dynamic value passed to Browser `Evaluate JavaScript` is serialized with `json.dumps` first; raw Robot strings are never emitted as JavaScript source expressions.
- **Application UI finding:** the Advanced Test Lab status grid used a viewport media query while its usable width was reduced by two ATX sidebars. The first grid track could collapse to a few pixels and wrap `Cached Visual Extraction Test Lab` one character per line.
- **Application correction:** `banking-statement-test-lab.css` uses a named inline-size container on `#test-results .statement-section-body`, a readable `minmax(16rem, 1fr)` primary track, and a `52rem` component-width stacking query.
- **Live browser acceptance:** the status main region must be at least 220 CSS pixels wide, the heading must occupy no more than three rendered lines, and the status card must not horizontally overflow.
- **Classification:** the evaluator failure is `TEST_INVALID`; the collapsed status card is a confirmed ATX UI defect corrected by the approved CSS change.
- **Cleanup:** the failed run still cleared the sample, deleted the exact disposable Draft and logged out.
- **SQL requirement:** none.
- **Dynomax Core change:** none.


## V61 D2-B rendered-metric locator correction addendum

### Returned evidence

- Dynomax run `9ffdbc5c-cb2e-434f-a48c-f876bb9f56c5` reached the direct-text result successfully.
- The browser showed 5 transactions, 1 page processed, 1 extraction run and 0 Remaps.
- The package then reported `Summary metric Pages processed resolved to 0 cards`.
- Exact sample/Draft cleanup passed.
- Causal classification: `TEST_INVALID`; the ATX processing result was visible and the test locator was invalid.

### Root cause

The V60 metric helper passed a dynamic label through Browser `Evaluate JavaScript`. Although the JavaScript executed, the helper did not resolve the rendered summary card that was visibly present. This made a successful direct-text result look absent.

### Permanent corrected contract

1. Do not use dynamic JavaScript evaluation to locate the fixed Test Lab metrics.
2. Read fixed labels through exact, source-certified DOM hierarchy selectors.
3. Test Lab counters are located only under `.statement-test-lab-metrics`, matching `small` text exactly, and reading the sibling `strong`.
4. `Pages processed` is located only under `.statement-test-summary-card`, matching the direct `.statement-muted` label exactly, and reading the direct `.value`.
5. Provider mode is read from the unique Test Results footer containing both `Provider:` and `Mode:`, using its second `strong`.
6. Supported labels are allow-listed. Unknown labels are `TEST_INVALID`.
7. Missing, duplicate or non-integer metric values are `TEST_INVALID`; they must never silently become zero.
8. The same corrected readers are shared by direct text, image preparation, OCR, cached Remap and bounded recovery.
9. The correction reuses SQL-backed session `000003`; it does not allocate session `000004`.
10. No ATX application, database or Dynomax Core change is required.

### Source-certified rendered hierarchy

- `Statement.cshtml`: `.statement-test-lab-metrics > span > strong + small` with labels `Extraction runs` and `Remaps`.
- `Statement.cshtml`: `.statement-test-summary-card > .value` plus `.statement-muted` label `Pages processed`.
- `Statement.cshtml`: Test Results footer text `Provider:` and `Mode:` with the extraction mode in the second `strong`.

## V62 D2-B Robot/JavaScript interpolation correction addendum

### Plain-English returned result

- The direct PDF processing stage passed.
- The sample-clear stage passed.
- The workflow moved forward to image preparation.
- ATX prepared and displayed the image, but the test failed while trying to read the image dimensions.
- The failure text was `Variable '${img}' not found`.
- OCR, cached Remap and bounded recovery were skipped because Dynomax stops dependent actions after the first invalid action.
- Cleanup cleared the sample, deleted the exact disposable Draft and logged out.
- Causal classification: `TEST_INVALID`; this was a Robot test-script construction defect, not an ATX image-preparation failure.

### Root cause

The image-preparation action embedded JavaScript template interpolation directly in a Robot argument:

```text
(img) => `${img.naturalWidth}x${img.naturalHeight}`
```

Robot parsed `${img.naturalWidth}` as a Robot variable before the browser could execute the JavaScript. This exact defect class was already documented in the source contract and should not have reached live execution.

### Permanent corrected contract

1. JavaScript passed through Robot must not contain template-literal `${...}` interpolation.
2. Construct dynamic browser strings with ordinary JavaScript concatenation or return structured values.
3. The prepared-image dimensions reader uses:
   `String(img.naturalWidth) + "x" + String(img.naturalHeight)`.
4. Package and installed-tree validation scan every `.resource` and `.robot` line containing `Evaluate JavaScript`.
5. A JavaScript template literal containing `${...}` in such a line is rejected before installation or workflow execution.
6. The complete remaining OCR, cached Remap and recovery resources are scanned by the same gate.
7. The correction reuses SQL-backed session `000003`; it does not allocate session `000004`.
8. No ATX application, ATX database or Dynomax Core change is required.

