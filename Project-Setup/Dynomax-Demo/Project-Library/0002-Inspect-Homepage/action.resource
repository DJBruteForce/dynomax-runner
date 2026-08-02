*** Keywords ***
Demo Inspect Homepage Structure
    ${website_title}=    Get Dynomax Context Value    websiteTitle
    ${website_url}=    Get Dynomax Context Value    websiteUrl
    Should Not Be Empty    ${website_title}
    Should Not Be Empty    ${website_url}
    ${body_text}=    Get Text    css=body
    ${body_length}=    Get Length    ${body_text}
    ${body_preview}=    Evaluate    $body_text[:1500]
    ${h1_count}=    Get Element Count    css=h1
    ${h2_count}=    Get Element Count    css=h2
    ${h3_count}=    Get Element Count    css=h3
    ${heading_count}=    Evaluate    int($h1_count) + int($h2_count) + int($h3_count)
    ${link_count}=    Get Element Count    css=a[href]
    ${button_count}=    Get Element Count    css=button
    ${form_count}=    Get Element Count    css=form
    ${image_count}=    Get Element Count    css=img
    ${input_count}=    Get Element Count    css=input
    ${language_status}    ${language}=    Run Keyword And Ignore Error    Get Attribute    css=html    lang
    IF    '${language_status}' == 'FAIL'
        ${language}=    Set Variable    ${EMPTY}
    END
    ${description_count}=    Get Element Count    css=meta[name="description"]
    ${description}=    Set Variable    ${EMPTY}
    IF    ${description_count} > 0
        ${description}=    Get Attribute    css=meta[name="description"]    content
    END
    ${first_h1}=    Set Variable    ${EMPTY}
    IF    ${h1_count} > 0
        ${first_h1}=    Get Text    css=h1 >> nth=0
    END
    Set Dynomax Context Value    bodyTextLength    ${body_length}
    Set Dynomax Context Value    bodyTextPreview    ${body_preview}
    Set Dynomax Context Value    h1Count    ${h1_count}
    Set Dynomax Context Value    h2Count    ${h2_count}
    Set Dynomax Context Value    h3Count    ${h3_count}
    Set Dynomax Context Value    headingCount    ${heading_count}
    Set Dynomax Context Value    linkCount    ${link_count}
    Set Dynomax Context Value    buttonCount    ${button_count}
    Set Dynomax Context Value    formCount    ${form_count}
    Set Dynomax Context Value    imageCount    ${image_count}
    Set Dynomax Context Value    inputCount    ${input_count}
    Set Dynomax Context Value    pageLanguage    ${language}
    Set Dynomax Context Value    metaDescription    ${description}
    Set Dynomax Context Value    firstH1    ${first_h1}
