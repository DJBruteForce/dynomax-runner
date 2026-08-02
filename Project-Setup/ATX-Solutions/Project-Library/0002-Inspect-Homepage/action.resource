*** Keywords ***
ATX Inspect Homepage
    ${website_title}=    Get Dynomax Context Value    websiteTitle
    ${website_url}=    Get Dynomax Context Value    websiteUrl
    Should Not Be Empty    ${website_title}
    Should Not Be Empty    ${website_url}
    ${active_title}=    Get Title
    ${active_url}=    Get Url
    Should Be Equal    ${active_title}    ${website_title}
    Should Be Equal    ${active_url}    ${website_url}
    ${visible_h1_count}=    Get Element Count    css=h1:visible
    ${first_h1}=    Set Variable    ${EMPTY}
    IF    ${visible_h1_count} > 0
        ${first_h1}=    Get Text    css=h1:visible >> nth=0
    END
    ${heading_count}=    Get Element Count    css=h1,h2,h3,h4,h5,h6
    ${link_count}=    Get Element Count    css=a[href]
    ${button_count}=    Get Element Count    css=button
    ${form_count}=    Get Element Count    css=form
    ${image_count}=    Get Element Count    css=img
    ${input_count}=    Get Element Count    css=input,select,textarea
    ${language_status}    ${page_language}=    Run Keyword And Ignore Error    Get Attribute    css=html    lang
    IF    '${language_status}' == 'FAIL'
        ${page_language}=    Set Variable    ${EMPTY}
    END
    ${console_status}    ${console_value}=    Run Keyword And Ignore Error    Get Console Log
    ${console_text}=    Convert To String    ${console_value}
    ${resource_status}    ${resource_json}=    Run Keyword And Ignore Error    Evaluate JavaScript    css=html    (element)=>{const entries=performance.getEntriesByType('resource').map((entry)=>({name:entry.name,initiatorType:entry.initiatorType,duration:entry.duration,transferSize:entry.transferSize,responseStatus:(typeof entry.responseStatus==='number'?entry.responseStatus:null)}));const failed=entries.filter((entry)=>(entry.responseStatus!==null&&entry.responseStatus>=400)||(entry.duration===0&&entry.transferSize===0));return JSON.stringify({available:true,mode:'performance-resource-timing',entriesObserved:entries.length,failedCandidateCount:failed.length,failedCandidates:failed,note:'HTTP response status is included where the browser exposes it; zero-duration and zero-transfer entries are candidates only.'});}
    IF    '${resource_status}' == 'FAIL'
        ${resource_json}=    Set Variable    {"available":false,"mode":"unavailable","entriesObserved":0,"failedCandidateCount":0,"failedCandidates":[],"note":"Browser resource timing could not be read safely."}
    END
    ${resource_entries}=    Evaluate    int(json.loads($resource_json).get('entriesObserved',0))    modules=json
    ${failed_resource_count}=    Evaluate    int(json.loads($resource_json).get('failedCandidateCount',0))    modules=json
    Set Dynomax Context Value    firstVisibleH1    ${first_h1}
    Set Dynomax Context Value    visibleH1Count    ${visible_h1_count}
    Set Dynomax Context Value    headingCount    ${heading_count}
    Set Dynomax Context Value    linkCount    ${link_count}
    Set Dynomax Context Value    buttonCount    ${button_count}
    Set Dynomax Context Value    formCount    ${form_count}
    Set Dynomax Context Value    imageCount    ${image_count}
    Set Dynomax Context Value    inputCount    ${input_count}
    Set Dynomax Context Value    pageLanguage    ${page_language}
    Set Dynomax Context Value    consoleLogStatus    ${console_status}
    Set Dynomax Context Value    consoleLogText    ${console_text}
    Set Dynomax Context Value    resourceEntriesObserved    ${resource_entries}
    Set Dynomax Context Value    failedResourceCandidateCount    ${failed_resource_count}
    Set Dynomax Context Value    resourceObservationJson    ${resource_json}
