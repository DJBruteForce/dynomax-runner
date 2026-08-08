import json
import re
from pathlib import Path
from urllib.parse import parse_qsl, quote, urlsplit, urlunsplit

_SECRET_KEY = re.compile(r"(?i)(password|passwd|pwd|secret|token|authorization|cookie|set-cookie|api[-_]?key|client[-_]?secret|credential|providerreference)")
_BEARER = re.compile(r"(?i)\b(bearer|basic)\s+[A-Za-z0-9._~+/=-]{8,}")
_ASSIGNMENT = re.compile(r"(?i)\b(password|passwd|pwd|secret|token|authorization|cookie|api[-_]?key|client[-_]?secret)\s*[:=]\s*([^\s,;]+)")
_JWT = re.compile(r"\beyJ[A-Za-z0-9_-]{8,}\.[A-Za-z0-9_-]{8,}\.[A-Za-z0-9_-]{8,}\b")
_LONG_TOKEN = re.compile(r"\b[A-Za-z0-9_-]{48,}\b")
_EMAIL = re.compile(r"[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}", re.I)
_URL = re.compile(r"https?://[^\s<>\"']+", re.I)

_SAFE_REQUEST_HEADERS = {
    "accept", "accept-language", "content-type", "origin", "referer", "user-agent",
    "sec-fetch-dest", "sec-fetch-mode", "sec-fetch-site"
}
_SAFE_RESPONSE_HEADERS = {"content-type", "content-length", "cache-control", "location"}
_SAFE_BODY_MIME_HINTS = (
    "application/json", "application/problem+json", "application/graphql-response+json", "text/"
)
_MAX_BODY_EXCERPT = 20000

STRUCTURE_SCRIPT = r'''(root)=>{const clean=(v,n=500)=>{if(v==null)return null;let s=String(v).replace(/[\s]+/g,' ').trim().slice(0,n);s=s.replace(/[A-Z0-9._%+-]+@[A-Z0-9.-]+[.][A-Z]{2,}/ig,'[redacted-email]').replace(/\beyJ[A-Za-z0-9_-]{8,}\.[A-Za-z0-9_-]{8,}\.[A-Za-z0-9_-]{8,}\b/g,'[redacted-token]').replace(/\b[A-Za-z0-9_-]{48,}\b/g,'[redacted-token]');return s||null};const safeUrl=(v)=>{try{const u=new URL(v,location.href);if(!['http:','https:','about:'].includes(u.protocol))return u.protocol+'[redacted]';u.search=[...u.searchParams.keys()].map(k=>encodeURIComponent(k)+'=%5Bredacted%5D').join('&');u.hash='';return clean(u.toString(),1200)}catch{return clean(v,1200)}};const visible=(e)=>{const r=e.getBoundingClientRect(),s=getComputedStyle(e);return s.display!=='none'&&s.visibility!=='hidden'&&r.width>0&&r.height>0};const selector=(e)=>{if(e.id)return '#'+CSS.escape(e.id);const name=e.getAttribute('name');if(name)return e.tagName.toLowerCase()+'[name="'+String(name).replace(/"/g,'\\"')+'"]';const role=e.getAttribute('role');const aria=e.getAttribute('aria-label');if(role&&aria)return '[role="'+role+'"][aria-label="'+String(aria).replace(/"/g,'\\"')+'"]';return e.tagName.toLowerCase()};const labelFor=(e)=>{const id=e.id;if(id){const l=root.querySelector('label[for="'+CSS.escape(id)+'"]');if(l)return clean(l.innerText||l.textContent)}const parent=e.closest('label');return parent?clean(parent.innerText||parent.textContent):null};const nearestHeading=(e)=>{let p=e.parentElement;while(p&&p!==root){const h=p.querySelector(':scope > h1,:scope > h2,:scope > h3,:scope > h4');if(h)return clean(h.innerText||h.textContent);p=p.parentElement}return null};const els=Array.from(root.querySelectorAll('a,button,input,select,textarea,label,h1,h2,h3,h4,[role],[contenteditable="true"],iframe,table')).slice(0,1200).map((e,index)=>{const r=e.getBoundingClientRect();return{index,tag:e.tagName.toLowerCase(),role:clean(e.getAttribute('role')),id:clean(e.id),name:clean(e.getAttribute('name')),type:clean(e.getAttribute('type')),ariaLabel:clean(e.getAttribute('aria-label')),ariaDescribedBy:clean(e.getAttribute('aria-describedby')),ariaControls:clean(e.getAttribute('aria-controls')),placeholder:clean(e.getAttribute('placeholder')),title:clean(e.getAttribute('title')),autocomplete:clean(e.getAttribute('autocomplete')),dataTestId:clean(e.getAttribute('data-testid')),className:clean(e.className),label:labelFor(e),nearestHeading:nearestHeading(e),formId:clean(e.form?.id),accept:e.tagName==='INPUT'?clean(e.getAttribute('accept')):null,multiple:Boolean(e.multiple),href:e.tagName==='A'&&e.href?safeUrl(e.href):null,src:e.tagName==='IFRAME'?safeUrl(e.src):null,text:['A','BUTTON','LABEL','H1','H2','H3','H4'].includes(e.tagName)?clean(e.innerText||e.textContent):null,selector:selector(e),visible:visible(e),disabled:Boolean(e.disabled),required:Boolean(e.required),checked:e.tagName==='INPUT'&&['checkbox','radio'].includes(String(e.type||'').toLowerCase())?Boolean(e.checked):null,bounds:{x:Math.round(r.x),y:Math.round(r.y),width:Math.round(r.width),height:Math.round(r.height)}}});const forms=Array.from(root.forms||[]).slice(0,100).map((f,i)=>({index:i,id:clean(f.id),name:clean(f.getAttribute('name')),method:clean(f.method),action:safeUrl(f.action),enctype:clean(f.enctype),controls:Array.from(f.elements||[]).slice(0,200).map(e=>({tag:e.tagName.toLowerCase(),id:clean(e.id),name:clean(e.getAttribute('name')),type:clean(e.getAttribute('type')),label:labelFor(e),selector:selector(e),required:Boolean(e.required),disabled:Boolean(e.disabled)}))}));const tables=Array.from(root.querySelectorAll('table')).slice(0,50).map((t,i)=>({index:i,id:clean(t.id),caption:clean(t.caption?.innerText||t.caption?.textContent),headers:Array.from(t.querySelectorAll('th')).slice(0,100).map(h=>clean(h.innerText||h.textContent)),rowCount:t.rows?.length||0}));return{schemaVersion:3,capture:'sanitized-rich-page-structure',url:safeUrl(location.href),title:clean(document.title),language:clean(document.documentElement.lang),readyState:document.readyState,historyLength:history.length,viewport:{width:innerWidth,height:innerHeight,devicePixelRatio},forms,tables,elements:els};}'''

DOM_SCRIPT = r'''(root)=>{const red=(s)=>String(s??'').replace(/[A-Z0-9._%+-]+@[A-Z0-9.-]+[.][A-Z]{2,}/ig,'[redacted-email]').replace(/\beyJ[A-Za-z0-9_-]{8,}\.[A-Za-z0-9_-]{8,}\.[A-Za-z0-9_-]{8,}\b/g,'[redacted-token]').replace(/\b[A-Za-z0-9_-]{48,}\b/g,'[redacted-token]');const safeUrl=(v)=>{try{const u=new URL(v,location.href);u.search=[...u.searchParams.keys()].map(k=>encodeURIComponent(k)+'=%5Bredacted%5D').join('&');u.hash='';return u.toString()}catch{return red(v)}};const clone=root.cloneNode(true);clone.querySelectorAll('script').forEach(e=>{e.textContent='/* script body omitted by Dynomax Discovery */';if(e.src)e.setAttribute('src',safeUrl(e.src))});clone.querySelectorAll('input,textarea,select,option,[contenteditable="true"]').forEach(e=>{e.removeAttribute('value');e.removeAttribute('checked');e.removeAttribute('selected');if(e.tagName==='TEXTAREA')e.textContent='';if(e.hasAttribute('contenteditable'))e.textContent='[redacted-editable-content]'});clone.querySelectorAll('*').forEach(e=>{for(const a of Array.from(e.attributes)){const n=a.name.toLowerCase();if(/password|passwd|secret|token|authorization|cookie|nonce|api[-_]?key|client[-_]?secret|providerreference/.test(n)||n.startsWith('on')){e.removeAttribute(a.name);continue}if(['href','src','action','formaction'].includes(n))e.setAttribute(a.name,safeUrl(a.value));else e.setAttribute(a.name,red(a.value).slice(0,4000))}});return '<!doctype html>\n'+red(clone.outerHTML).slice(0,1500000);}'''

TEXT_SCRIPT = r'''(root)=>{let s=String(root.innerText||'').replace(/[\s]+/g,' ').trim();s=s.replace(/[A-Z0-9._%+-]+@[A-Z0-9.-]+[.][A-Z]{2,}/ig,'[redacted-email]').replace(/\beyJ[A-Za-z0-9_-]{8,}\.[A-Za-z0-9_-]{8,}\.[A-Za-z0-9_-]{8,}\b/g,'[redacted-token]').replace(/\b[A-Za-z0-9_-]{48,}\b/g,'[redacted-token]');return s.slice(0,100000);}'''

TIMING_SCRIPT = r'''(root)=>{const safe=(v)=>{try{const u=new URL(v,location.href);u.search=[...u.searchParams.keys()].map(k=>encodeURIComponent(k)+'=%5Bredacted%5D').join('&');u.hash='';return u.toString()}catch{return String(v||'').slice(0,1200)}};return{schemaVersion:2,navigation:performance.getEntriesByType('navigation').slice(0,5).map(e=>({name:safe(e.name),entryType:e.entryType,startTime:e.startTime,duration:e.duration,domInteractive:e.domInteractive,domContentLoadedEventEnd:e.domContentLoadedEventEnd,loadEventEnd:e.loadEventEnd,transferSize:e.transferSize,encodedBodySize:e.encodedBodySize,decodedBodySize:e.decodedBodySize})),resources:performance.getEntriesByType('resource').slice(-1500).map(e=>({name:safe(e.name),initiatorType:e.initiatorType,startTime:e.startTime,duration:e.duration,transferSize:e.transferSize,encodedBodySize:e.encodedBodySize,decodedBodySize:e.decodedBodySize}))};}'''

UNMASK_SCRIPT = r'''(root)=>{document.getElementById('dynomax-discovery-mask')?.remove();const saved=window.__dynomaxDiscoveryTextMask||[];for(const item of saved){try{item[0].nodeValue=item[1]}catch{}}window.__dynomaxDiscoveryTextMask=[];return true;}'''


def _load_secret_values(context_path):
    try:
        context = json.loads(Path(str(context_path)).read_text(encoding="utf-8"))
        keys = {str(k) for k in (context.get("secretKeys") or [])}
        values = context.get("values") or {}
        result = []
        for key in keys:
            value = values.get(key)
            if value is None:
                continue
            text = str(value)
            if text and text not in result:
                result.append(text)
        return sorted(result, key=len, reverse=True)
    except Exception:
        return []


def _redact_exact_secrets(text, context_path=None):
    value = str(text)
    for secret in _load_secret_values(context_path) if context_path else []:
        variants = {secret, quote(secret, safe=""), quote(secret, safe="@._-~")}
        for variant in sorted((v for v in variants if v), key=len, reverse=True):
            value = value.replace(variant, "[redacted-secret]")
    return value


def _safe_url(value, context_path=None):
    if not value:
        return value
    raw = _redact_exact_secrets(value, context_path)
    try:
        parts = urlsplit(str(raw))
        if parts.scheme and parts.scheme.lower() not in ("http", "https", "about", "data"):
            return f"{parts.scheme}:[redacted]"
        if parts.scheme.lower() == "data":
            return "data:[redacted]"
        query = parse_qsl(parts.query, keep_blank_values=True)
        safe_query = "&".join(f"{quote(str(key))}=%5Bredacted%5D" for key, _ in query) if query else ""
        return urlunsplit((parts.scheme, parts.netloc, parts.path, safe_query, ""))
    except Exception:
        return "[redacted-url]"


def sanitize_discovery_text(value, context_path=None, max_length=200000):
    if value is None:
        return None
    text = _redact_exact_secrets(value, context_path)
    text = _BEARER.sub(lambda m: f"{m.group(1)} [redacted]", text)
    text = _ASSIGNMENT.sub(lambda m: f"{m.group(1)}=[redacted]", text)
    text = _JWT.sub("[redacted-token]", text)
    text = _LONG_TOKEN.sub("[redacted-token]", text)
    text = _EMAIL.sub("[redacted-email]", text)
    text = _URL.sub(lambda m: _safe_url(m.group(0), context_path), text)
    if len(text) > int(max_length):
        text = text[: int(max_length)] + "\n[truncated]"
    return text


def _sanitize_value(value, key=None, context_path=None):
    if key and _SECRET_KEY.search(str(key)):
        return "[redacted]"
    if isinstance(value, dict):
        return {str(k): _sanitize_value(v, str(k), context_path) for k, v in value.items()}
    if isinstance(value, list):
        return [_sanitize_value(item, None, context_path) for item in value[:5000]]
    if isinstance(value, str):
        if key and str(key).lower() in {"url", "href", "src", "action", "location", "documenturl"}:
            return _safe_url(value, context_path)
        return sanitize_discovery_text(value, context_path, 20000)
    return value


def sanitize_discovery_json(json_text, context_path=None):
    try:
        value = json.loads(str(json_text))
    except Exception:
        return json.dumps({"captureWarning": "JSON evidence could not be parsed safely."}, indent=2)
    return json.dumps(_sanitize_value(value, context_path=context_path), ensure_ascii=False, indent=2)


def _safe_headers(headers, allowed, context_path=None):
    result = []
    for item in headers or []:
        name = str(item.get("name", ""))
        lower = name.lower()
        if lower not in allowed or _SECRET_KEY.search(name):
            continue
        value = str(item.get("value", ""))
        if lower in {"referer", "origin", "location"}:
            value = _safe_url(value, context_path)
        else:
            value = sanitize_discovery_text(value, context_path, 2000)
        result.append({"name": name, "value": value})
    return result


def _safe_body_excerpt(text, mime_type, encoding, context_path=None):
    if not text or encoding:
        return None
    mime = str(mime_type or "").lower()
    if not any(hint in mime for hint in _SAFE_BODY_MIME_HINTS):
        return None
    raw = str(text)
    if len(raw) > _MAX_BODY_EXCERPT * 4:
        raw = raw[: _MAX_BODY_EXCERPT * 4]
    if "json" in mime:
        try:
            value = json.loads(raw)
            safe = json.dumps(_sanitize_value(value, context_path=context_path), ensure_ascii=False, indent=2)
            return safe[:_MAX_BODY_EXCERPT]
        except Exception:
            pass
    return sanitize_discovery_text(raw, context_path, _MAX_BODY_EXCERPT)


def sanitize_discovery_har(raw_path, output_path, context_path=None):
    raw = Path(str(raw_path))
    output = Path(str(output_path))
    output.parent.mkdir(parents=True, exist_ok=True)
    try:
        data = json.loads(raw.read_text(encoding="utf-8"))
        log = data.get("log") or {}
        safe_entries = []
        for entry in (log.get("entries") or [])[:5000]:
            request = entry.get("request") or {}
            response = entry.get("response") or {}
            content = response.get("content") or {}
            post_data = request.get("postData") or {}
            request_excerpt = _safe_body_excerpt(post_data.get("text"), post_data.get("mimeType"), None, context_path)
            response_excerpt = _safe_body_excerpt(content.get("text"), content.get("mimeType"), content.get("encoding"), context_path)
            safe_entries.append({
                "startedDateTime": entry.get("startedDateTime"),
                "time": entry.get("time"),
                "request": {
                    "method": request.get("method"),
                    "url": _safe_url(request.get("url"), context_path),
                    "httpVersion": request.get("httpVersion"),
                    "headers": _safe_headers(request.get("headers"), _SAFE_REQUEST_HEADERS, context_path),
                    "queryString": [{"name": sanitize_discovery_text(q.get("name"), context_path, 200), "value": "[redacted]"} for q in (request.get("queryString") or [])[:200]],
                    "bodyIncluded": request_excerpt is not None,
                    "bodyExcerpt": request_excerpt,
                },
                "response": {
                    "status": response.get("status"),
                    "statusText": sanitize_discovery_text(response.get("statusText"), context_path, 500),
                    "httpVersion": response.get("httpVersion"),
                    "headers": _safe_headers(response.get("headers"), _SAFE_RESPONSE_HEADERS, context_path),
                    "content": {
                        "size": content.get("size"),
                        "mimeType": sanitize_discovery_text(content.get("mimeType"), context_path, 500),
                        "bodyIncluded": response_excerpt is not None,
                        "bodyExcerpt": response_excerpt,
                    },
                    "redirectURL": _safe_url(response.get("redirectURL"), context_path),
                },
                "cache": {},
                "timings": _sanitize_value(entry.get("timings") or {}, context_path=context_path),
                "serverIPAddress": sanitize_discovery_text(entry.get("serverIPAddress"), context_path, 200),
                "connection": sanitize_discovery_text(entry.get("connection"), context_path, 200),
            })
        safe = {
            "log": {
                "version": log.get("version", "1.2"),
                "creator": {"name": "Dynomax sanitized Discovery HAR", "version": "2"},
                "entries": safe_entries,
            },
            "security": {
                "rawRequestBodiesIncluded": False,
                "rawResponseBodiesIncluded": False,
                "boundedSanitizedTextOrJsonBodyExcerptsMayBeIncluded": True,
                "maximumBodyExcerptCharacters": _MAX_BODY_EXCERPT,
                "cookiesIncluded": False,
                "authorizationHeadersIncluded": False,
                "queryValuesIncluded": False,
            },
        }
        output.write_text(json.dumps(safe, ensure_ascii=False, indent=2), encoding="utf-8")
        return True
    except Exception as exc:
        output.write_text(json.dumps({"captureWarning": sanitize_discovery_text(exc, context_path, 1000)}, indent=2), encoding="utf-8")
        return False
    finally:
        try:
            if raw.exists():
                raw.unlink()
        except Exception:
            pass


def get_discovery_script(name, context_path=None):
    key = str(name or "").strip().lower()
    if key == "structure":
        return STRUCTURE_SCRIPT
    if key == "dom":
        return DOM_SCRIPT
    if key == "text":
        return TEXT_SCRIPT
    if key == "timing":
        return TIMING_SCRIPT
    if key == "unmask":
        return UNMASK_SCRIPT
    if key == "mask":
        secrets = _load_secret_values(context_path)
        encoded = json.dumps(secrets, ensure_ascii=False)
        return r'''(root)=>{const secrets=''' + encoded + r''';document.getElementById('dynomax-discovery-mask')?.remove();const style=document.createElement('style');style.id='dynomax-discovery-mask';style.textContent='input,textarea,select,[contenteditable="true"],[data-secret],[data-sensitive]{color:transparent!important;text-shadow:none!important;caret-color:transparent!important} input::placeholder,textarea::placeholder{color:transparent!important}';document.head.appendChild(style);const saved=[];const email=/[A-Z0-9._%+-]+@[A-Z0-9.-]+[.][A-Z]{2,}/ig;const walker=document.createTreeWalker(document.body||root,NodeFilter.SHOW_TEXT);let node;while(node=walker.nextNode()){const original=String(node.nodeValue||'');let masked=original;for(const secret of secrets){if(secret)masked=masked.split(secret).join('[redacted-secret]')}masked=masked.replace(email,'[redacted-email]');if(masked!==original){saved.push([node,original]);node.nodeValue=masked}}window.__dynomaxDiscoveryTextMask=saved;return {applied:true,textNodesMasked:saved.length,formControlsMasked:true,exactRuntimeSecretsConsidered:secrets.length};}'''
    raise ValueError(f"Unknown Discovery script '{name}'.")


def validate_discovery_evidence(discovery_dir, context_path=None):
    root = Path(str(discovery_dir))
    required = [
        "page-structure.json", "page-dom.html", "page-text.txt",
        "screenshot-viewport.png", "screenshot-full-page.png", "screenshot-mask.json",
        "console.json", "page-errors.json", "network.har.json", "resource-timing.json",
        "capture-metadata.json"
    ]
    missing = [name for name in required if not (root / name).is_file() or (root / name).stat().st_size == 0]
    problems = []
    if missing:
        problems.append("Missing required sanitized evidence: " + ", ".join(missing))

    secrets = _load_secret_values(context_path)
    textual = [
        "page-structure.json", "page-dom.html", "page-text.txt", "screenshot-mask.json",
        "console.json", "page-errors.json", "network.har.json", "resource-timing.json", "capture-metadata.json"
    ]
    leaked_files = []
    for name in textual:
        path = root / name
        if not path.exists():
            continue
        try:
            text = path.read_text(encoding="utf-8", errors="replace")
        except Exception:
            continue
        for secret in secrets:
            if secret and secret in text:
                leaked_files.append(name)
                break
    if leaked_files:
        problems.append("Exact runtime secret value found in sanitized textual evidence: " + ", ".join(sorted(set(leaked_files))))

    raw_har = root.parent / "discovery-network.raw.har"
    if raw_har.exists():
        problems.append("Transient raw HAR still exists after sanitization.")

    try:
        mask = json.loads((root / "screenshot-mask.json").read_text(encoding="utf-8"))
        if mask.get("applied") is not True or mask.get("formControlsMasked") is not True:
            problems.append("Screenshot masking did not confirm successful application.")
    except Exception:
        problems.append("Screenshot masking report is missing or invalid.")

    try:
        structure = json.loads((root / "page-structure.json").read_text(encoding="utf-8"))
        if structure.get("captureWarning"):
            problems.append("Rich page-structure capture failed.")
    except Exception:
        problems.append("Rich page-structure evidence is invalid JSON.")

    safe = not problems
    report = {
        "schemaVersion": 1,
        "safeForAgentHandoff": safe,
        "requiredEvidenceCount": len(required),
        "missingEvidence": missing,
        "runtimeSecretValuesLoadedForValidation": len(secrets),
        "exactSecretLeakDetected": bool(leaked_files),
        "rawHarDeleted": not raw_har.exists(),
        "screenshotsMasked": not any("Screenshot masking" in p for p in problems),
        "problems": problems,
        "note": "No runtime secret value is written to this report. Discovery export must fail closed unless safeForAgentHandoff is true."
    }
    (root / "security-report.json").write_text(json.dumps(report, ensure_ascii=False, indent=2), encoding="utf-8")
    return safe


def remove_discovery_file(path):
    try:
        p = Path(str(path))
        if p.exists():
            p.unlink()
        return True
    except Exception:
        return False
