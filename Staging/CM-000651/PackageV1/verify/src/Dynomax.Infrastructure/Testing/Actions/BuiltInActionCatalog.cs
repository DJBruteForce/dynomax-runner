using System.IO.Compression;
using System.Security.Cryptography;
using System.Text;
using System.Text.Json;
using System.Text.Json.Nodes;
using Dynomax.Application.Testing.Actions;
using Dynomax.Application.Testing.ExecutionPolicies;
using Dynomax.Domain.Testing.Actions;

namespace Dynomax.Infrastructure.Testing.Actions;

internal sealed class BuiltInActionCatalog : IBuiltInActionCatalog
{
    private const string FirstBatchRequiredCoreVersion = "1.0.15";
    private const string RemainderRequiredCoreVersion = "1.0.16";
    private static readonly DateTimeOffset ZipTimestamp = new(1980, 1, 1, 0, 0, 0, TimeSpan.Zero);
    private static readonly string[] NormalBindings =
    [
        ActionBindingKinds.Literal,
        ActionBindingKinds.WorkflowInput,
        ActionBindingKinds.WorkflowDefault,
        ActionBindingKinds.ProjectVariable,
        ActionBindingKinds.NodeOutput,
        ActionBindingKinds.RuntimeValue
    ];
    private static readonly string[] SecretBindings = [ActionBindingKinds.SecretReference];
    private static readonly string[] NormalOrSecretBindings = [.. NormalBindings, ActionBindingKinds.SecretReference];
    private static readonly string[] SensitiveBindings =
    [
        ActionBindingKinds.SecretReference,
        ActionBindingKinds.NodeOutput
    ];
    private static readonly JsonSerializerOptions JsonOptions = new()
    {
        PropertyNamingPolicy = JsonNamingPolicy.CamelCase,
        WriteIndented = true
    };

    private static readonly IReadOnlySet<string> SharedRuntimeActionKeys = new HashSet<string>(StringComparer.Ordinal)
    {
        "web.file.upload",
        "web.file.download",
        "validation.http.status",
        "validation.json.value",
        "http.request",
        "http.get",
        "http.post",
        "http.put",
        "http.patch",
        "http.delete",
        "http.download-url",
        "http.upload-file",
        "http.webhook.call",
        "http.oauth2.token",
        "http.bearer.request",
        "http.basic.request",
        "file.text.read",
        "file.text.write",
        "file.text.append",
        "file.copy",
        "file.move",
        "file.delete",
        "file.exists",
        "directory.create",
        "directory.delete",
        "directory.list",
        "file.find",
        "file.info",
        "file.hash.sha256",
        "file.zip.compress",
        "file.zip.extract",
        "file.csv.read",
        "file.json.read",
        "file.xml.read",
        "file.csv.write",
        "file.json.write",
        "file.xml.write",
        "data.json.serialize",
        "data.json.set-value",
        "data.json.merge",
        "data.json.filter-array",
        "data.xml.parse",
        "data.xml.xpath",
        "data.xml.to-json",
        "data.csv.to-json",
        "data.json.to-csv",
        "data.regex.extract",
        "data.regex.replace",
        "data.string.replace",
        "data.string.split",
        "data.string.join",
        "data.base64.encode",
        "data.base64.decode",
        "data.url.encode",
        "data.url.decode",
        "database.sql.query",
        "database.sql.execute",
        "database.sql.scalar",
        "database.sql.stored-procedure",
        "email.smtp.send",
        "email.smtp.send-attachment",
        "email.imap.read",
        "email.imap.find",
        "email.imap.latest",
        "email.imap.download-attachments",
        "email.imap.mark-read",
        "email.imap.move",
        "email.imap.delete",
        "process.run",
        "command.run",
        "powershell.run",
        "python.run",
        "dotnet.run",
        "datetime.current",
        "datetime.format",
        "datetime.parse",
        "datetime.add",
        "datetime.difference",
        "datetime.convert-time-zone",
        "utility.guid.generate",
        "utility.random.string",
        "utility.random.number",
        "utility.sha256",
        "utility.hmac",
        "utility.timestamp",
        "utility.environment-variable",
        "utility.machine-information",
    };


    private static readonly IReadOnlyList<BuiltInActionDescriptor> ActionVersions = BuildActions();
    private static readonly IReadOnlyList<BuiltInActionDescriptor> Actions = ActionVersions
        .GroupBy(item => item.Key, StringComparer.Ordinal)
        .Select(group => group.OrderByDescending(item => item.ContractVersion).First())
        .ToArray();
    private static readonly IReadOnlyDictionary<string, BuiltInActionDescriptor> ShippedByKey = Actions
        .ToDictionary(item => item.Key, StringComparer.Ordinal);
    private static readonly IReadOnlyDictionary<(string Key, int Version), BuiltInActionDescriptor> ExactByKey = ActionVersions
        .ToDictionary(item => (item.Key, item.ContractVersion));

    public IReadOnlyList<BuiltInActionDescriptor> GetAll() => Actions;
    public IReadOnlyList<BuiltInActionDescriptor> GetAllVersions() => ActionVersions;

    public BuiltInActionDescriptor? FindShipped(string key) =>
        string.IsNullOrWhiteSpace(key) ? null : ShippedByKey.GetValueOrDefault(key.Trim().ToLowerInvariant());

    public BuiltInActionDescriptor? FindExact(string key, int contractVersion) =>
        string.IsNullOrWhiteSpace(key) ? null : ExactByKey.GetValueOrDefault((key.Trim().ToLowerInvariant(), contractVersion));

    private static IReadOnlyList<BuiltInActionDescriptor> BuildActions()
    {
        var result = new List<BuiltInActionDescriptor>();

        Add(result,
            "web.page.open", "Open Page", "Open a URL in the shared browser session.", "Browser",
            "Dynomax BuiltIn Open Page", ActionSessionBehaviors.RequiresNewOrExistingBrowser, 60, ActionSideEffectKinds.ReadOnly, false,
            [Input("url", "String", false, "Normal", "null", "Absolute URL; when omitted the Environment Base URL is used.")],
            [Output("url", "String", "Current page URL.")]);
        Add(result,
            "web.page.navigate", "Navigate", "Navigate the current browser to another URL.", "Browser",
            "Dynomax BuiltIn Navigate", ActionSessionBehaviors.RequiresExistingBrowser, 60, ActionSideEffectKinds.ReadOnly, false,
            [Input("url", "String", true, "Normal", null, "Absolute target URL.")],
            [Output("url", "String", "Current page URL.")]);
        Add(result,
            "web.element.click", "Click Element", "Click a matching page element.", "Browser",
            "Dynomax BuiltIn Click Element", ActionSessionBehaviors.RequiresExistingBrowser, 30, ActionSideEffectKinds.ExternalEffect, false,
            [Input("selector", "String", true, "Normal", null, "Browser selector.")],
            []);
        Add(result,
            "web.element.double-click", "Double Click", "Double-click a matching page element.", "Browser",
            "Dynomax BuiltIn Double Click", ActionSessionBehaviors.RequiresExistingBrowser, 30, ActionSideEffectKinds.ExternalEffect, false,
            [Input("selector", "String", true, "Normal", null, "Browser selector.")],
            []);
        Add(result,
            "web.element.enter-text", "Enter Text", "Enter text into an input field.", "Browser",
            "Dynomax BuiltIn Enter Text", ActionSessionBehaviors.RequiresExistingBrowser, 30, ActionSideEffectKinds.UpdatesData, false,
            [Input("selector", "String", true, "Normal", null, "Browser selector."), Input("text", "String", true, "Normal", null, "Text to enter.")],
            []);
        Add(result,
            "web.element.enter-text", "Enter Text", "Enter text into an input field. The action treats the supplied value only as text; Dynomax runtime metadata controls protected handling and redaction.", "Browser",
            "Dynomax BuiltIn Enter Text V2", ActionSessionBehaviors.RequiresExistingBrowser, 30, ActionSideEffectKinds.UpdatesData, false,
            [
                Input("selector", "String", true, "Normal", null, "Browser selector."),
                Input("text", "String", true, "Normal", null, "Text to enter. Normal, SecretReference, Sensitive WorkflowInput and sensitive runtime NodeOutput sources are accepted; semantic content is never interpreted by this Action.", NormalOrSecretBindings, acceptSensitiveNodeOutput: true)
            ],
            [],
            contractVersion: 2,
            requiredCoreVersionOverride: "1.0.20");
        Add(result,
            "web.element.enter-secret-text", "Enter Secret Text", "Enter secret text into an input field using a Secret Reference.", "Browser",
            "Dynomax BuiltIn Enter Secret Text", ActionSessionBehaviors.RequiresExistingBrowser, 30, ActionSideEffectKinds.UpdatesData, false,
            [Input("selector", "String", true, "Normal", null, "Browser selector."), Input("text", "String", true, "Secret", null, "Secret Reference whose resolved value is entered without exposing the secret.")],
            []);
        Add(result,
            "web.element.enter-secret-text", "Enter Secret Text", "Enter sensitive runtime text or a Secret Reference without exposing the value.", "Browser",
            "Dynomax BuiltIn Enter Sensitive Text V2", ActionSessionBehaviors.RequiresExistingBrowser, 30, ActionSideEffectKinds.UpdatesData, false,
            [Input("selector", "String", true, "Normal", null, "Browser selector."), Input("text", "String", true, "Sensitive", null, "Sensitive runtime NodeOutput or Secret Reference entered without exposing the value.")],
            [],
            contractVersion: 2,
            requiredCoreVersionOverride: "1.0.20");
        Add(result,
            "web.element.clear", "Clear Field", "Clear an input field.", "Browser",
            "Dynomax BuiltIn Clear Field", ActionSessionBehaviors.RequiresExistingBrowser, 30, ActionSideEffectKinds.UpdatesData, false,
            [Input("selector", "String", true, "Normal", null, "Browser selector.")],
            []);
        Add(result,
            "web.element.select-option", "Select Dropdown Option", "Select a dropdown option by label/value.", "Browser",
            "Dynomax BuiltIn Select Dropdown Option", ActionSessionBehaviors.RequiresExistingBrowser, 30, ActionSideEffectKinds.UpdatesData, false,
            [Input("selector", "String", true, "Normal", null, "Browser selector."), Input("by", "String", false, "Normal", "\"value\"", "Selection attribute: value, label/text, or index."), Input("value", "String", true, "Normal", null, "Option value for the selected attribute.")],
            []);
        Add(result,
            "web.element.check", "Check Checkbox", "Check a checkbox.", "Browser",
            "Dynomax BuiltIn Check Checkbox", ActionSessionBehaviors.RequiresExistingBrowser, 30, ActionSideEffectKinds.UpdatesData, false,
            [Input("selector", "String", true, "Normal", null, "Browser selector.")],
            []);
        Add(result,
            "web.element.uncheck", "Uncheck Checkbox", "Uncheck a checkbox.", "Browser",
            "Dynomax BuiltIn Uncheck Checkbox", ActionSessionBehaviors.RequiresExistingBrowser, 30, ActionSideEffectKinds.UpdatesData, false,
            [Input("selector", "String", true, "Normal", null, "Browser selector.")],
            []);
        Add(result,
            "web.keyboard.press-key", "Press Key", "Send a keyboard key or shortcut to an element/page.", "Browser",
            "Dynomax BuiltIn Press Key", ActionSessionBehaviors.RequiresExistingBrowser, 30, ActionSideEffectKinds.ExternalEffect, false,
            [Input("selector", "String", false, "Normal", "null", "Optional target selector."), Input("key", "String", true, "Normal", null, "Browser key or shortcut.")],
            []);
        Add(result,
            "web.form.submit", "Submit Form", "Submit the form containing a matching element.", "Browser",
            "Dynomax BuiltIn Submit Form", ActionSessionBehaviors.RequiresExistingBrowser, 30, ActionSideEffectKinds.ExternalEffect, false,
            [Input("selector", "String", true, "Normal", null, "Selector for the form or an element inside it.")],
            []);
        Add(result,
            "web.auth.login", "Login", "Perform a configurable target-agnostic login sequence.", "Browser",
            "Dynomax BuiltIn Login", ActionSessionBehaviors.RequiresExistingBrowser, 60, ActionSideEffectKinds.ExternalEffect, false,
            [Input("usernameSelector", "String", true, "Normal", null, "Username input selector."), Input("passwordSelector", "String", true, "Normal", null, "Password input selector."), Input("submitSelector", "String", true, "Normal", null, "Submit control selector."), Input("username", "String", true, "Secret", null, "Username secret reference."), Input("password", "String", true, "Secret", null, "Password secret reference."), Input("successSelector", "String", false, "Normal", "null", "Optional selector that must become visible after login.")],
            []);
        Add(result,
            "web.auth.login", "Login", "Perform a configurable target-agnostic login sequence with an ordinary or secret username and a secret password.", "Browser",
            "Dynomax BuiltIn Login V2", ActionSessionBehaviors.RequiresExistingBrowser, 60, ActionSideEffectKinds.ExternalEffect, false,
            [
                Input("usernameSelector", "String", true, "Normal", null, "Username input selector."),
                Input("passwordSelector", "String", true, "Normal", null, "Password input selector."),
                Input("submitSelector", "String", true, "Normal", null, "Submit control selector."),
                Input("username", "String", true, "Normal", null, "Username value. Ordinary Dynomax Values/variables and Secret References are supported.", NormalOrSecretBindings),
                Input("password", "String", true, "Secret", null, "Password Secret Reference. Plain values are never accepted."),
                Input("successSelector", "String", false, "Normal", "null", "Optional selector that must become visible after login.")
            ],
            [],
            contractVersion: 2);
        Add(result,
            "web.auth.logout", "Logout", "Perform a configurable target-agnostic logout click.", "Browser",
            "Dynomax BuiltIn Logout", ActionSessionBehaviors.RequiresExistingBrowser, 60, ActionSideEffectKinds.ExternalEffect, false,
            [Input("selector", "String", true, "Normal", null, "Logout control selector."), Input("successSelector", "String", false, "Normal", "null", "Optional selector that must become visible after logout.")],
            []);
        Add(result,
            "web.wait.element", "Wait for Element", "Wait until an element reaches the requested state.", "Browser",
            "Dynomax BuiltIn Wait Element", ActionSessionBehaviors.RequiresExistingBrowser, 120, ActionSideEffectKinds.ReadOnly, true,
            [Input("selector", "String", true, "Normal", null, "Browser selector."), Input("state", "String", false, "Normal", "\"visible\"", "Browser element state."), Input("timeoutSeconds", "Integer", false, "Normal", "30", "Wait timeout in seconds.")],
            []);
        Add(result,
            "web.wait.text", "Wait for Text", "Wait until specified visible text appears.", "Browser",
            "Dynomax BuiltIn Wait Text", ActionSessionBehaviors.RequiresExistingBrowser, 120, ActionSideEffectKinds.ReadOnly, true,
            [Input("text", "String", true, "Normal", null, "Visible text to wait for."), Input("timeoutSeconds", "Integer", false, "Normal", "30", "Wait timeout in seconds.")],
            []);
        Add(result,
            "web.wait.url", "Wait for URL", "Wait until the current URL equals the expected URL.", "Browser",
            "Dynomax BuiltIn Wait URL", ActionSessionBehaviors.RequiresExistingBrowser, 120, ActionSideEffectKinds.ReadOnly, true,
            [Input("url", "String", true, "Normal", null, "Expected URL."), Input("timeoutSeconds", "Integer", false, "Normal", "30", "Wait timeout in seconds.")],
            []);
        Add(result,
            "web.wait.page-load", "Wait for Page Load", "Wait for the requested page load state.", "Browser",
            "Dynomax BuiltIn Wait Page Load", ActionSessionBehaviors.RequiresExistingBrowser, 120, ActionSideEffectKinds.ReadOnly, true,
            [Input("state", "String", false, "Normal", "\"domcontentloaded\"", "Browser load state.")],
            []);
        Add(result,
            "web.element.get-text", "Get Element Text", "Return text from an element.", "Browser",
            "Dynomax BuiltIn Get Element Text", ActionSessionBehaviors.RequiresExistingBrowser, 30, ActionSideEffectKinds.ReadOnly, true,
            [Input("selector", "String", true, "Normal", null, "Browser selector.")],
            [Output("text", "String", "Element text.")]);
        Add(result,
            "web.element.get-attribute", "Get Element Attribute", "Return an element attribute.", "Browser",
            "Dynomax BuiltIn Get Element Attribute", ActionSessionBehaviors.RequiresExistingBrowser, 30, ActionSideEffectKinds.ReadOnly, true,
            [Input("selector", "String", true, "Normal", null, "Browser selector."), Input("attribute", "String", true, "Normal", null, "Attribute name.")],
            [Output("value", "String", "Attribute value.")]);
        Add(result,
            "web.element.get-input-value", "Get Input Value", "Return the current value of an input.", "Browser",
            "Dynomax BuiltIn Get Input Value", ActionSessionBehaviors.RequiresExistingBrowser, 30, ActionSideEffectKinds.ReadOnly, true,
            [Input("selector", "String", true, "Normal", null, "Browser selector.")],
            [Output("value", "String", "Input value.")]);
        Add(result,
            "web.element.exists", "Element Exists", "Determine whether an element exists.", "Browser",
            "Dynomax BuiltIn Element Exists", ActionSessionBehaviors.RequiresExistingBrowser, 30, ActionSideEffectKinds.ReadOnly, true,
            [Input("selector", "String", true, "Normal", null, "Browser selector.")],
            [Output("exists", "Boolean", "Whether an element exists.")]);
        Add(result,
            "web.element.visible", "Element Visible", "Determine whether an element is visible.", "Browser",
            "Dynomax BuiltIn Element Visible", ActionSessionBehaviors.RequiresExistingBrowser, 30, ActionSideEffectKinds.ReadOnly, true,
            [Input("selector", "String", true, "Normal", null, "Browser selector.")],
            [Output("visible", "Boolean", "Whether an element is visible.")]);
        Add(result,
            "web.element.visible", "Element Visible", "Probe whether an element becomes visible without treating expected absence as an Action failure.", "Browser",
            "Dynomax BuiltIn Element Visible V2", ActionSessionBehaviors.RequiresExistingBrowser, 30, ActionSideEffectKinds.ReadOnly, true,
            [Input("selector", "String", true, "Normal", null, "Browser selector."), Input("timeoutSeconds", "Integer", false, "Normal", "1", "Maximum non-asserting probe duration in seconds; zero performs one immediate probe.")],
            [Output("visible", "Boolean", "Whether an element became visible before the probe timeout.")],
            contractVersion: 2,
            requiredCoreVersionOverride: "1.0.18");
        Add(result,
            "web.element.visible", "Element Visible", "Probe whether an element becomes visible within an explicitly bounded non-asserting timeout.", "Browser",
            "Dynomax BuiltIn Element Visible V3", ActionSessionBehaviors.RequiresExistingBrowser, 30, ActionSideEffectKinds.ReadOnly, true,
            [Input("selector", "String", true, "Normal", null, "Browser selector."), Input("timeoutSeconds", "Integer", false, "Normal", "1", "Maximum non-asserting probe duration in seconds; zero performs one immediate probe without inheriting the Browser selector timeout.")],
            [Output("visible", "Boolean", "Whether an element became visible before the probe timeout.")],
            contractVersion: 3,
            requiredCoreVersionOverride: "1.0.18");
        Add(result,
            "web.page.get-url", "Get Current URL", "Return the browser current URL.", "Browser",
            "Dynomax BuiltIn Get Current URL", ActionSessionBehaviors.RequiresExistingBrowser, 30, ActionSideEffectKinds.ReadOnly, true,
            [],
            [Output("url", "String", "Current URL.")]);
        Add(result,
            "web.page.get-title", "Get Page Title", "Return the current page title.", "Browser",
            "Dynomax BuiltIn Get Page Title", ActionSessionBehaviors.RequiresExistingBrowser, 30, ActionSideEffectKinds.ReadOnly, true,
            [],
            [Output("title", "String", "Page title.")]);
        Add(result,
            "web.viewport.set", "Set Browser Viewport", "Set and verify the active Playwright page viewport without recreating the browser context or page.", "Browser",
            "Dynomax BuiltIn Set Browser Viewport", ActionSessionBehaviors.RequiresExistingBrowser, 30, ActionSideEffectKinds.ReadOnly, true,
            [
                Input("width", "Integer", true, "Normal", null, "Requested active-page viewport width in CSS pixels (1..10000)."),
                Input("height", "Integer", true, "Normal", null, "Requested active-page viewport height in CSS pixels (1..10000).")
            ],
            [
                Output("requestedWidth", "Integer", "Requested viewport width in CSS pixels."),
                Output("requestedHeight", "Integer", "Requested viewport height in CSS pixels."),
                Output("actualWidth", "Integer", "Verified active-page viewport width after application."),
                Output("actualHeight", "Integer", "Verified active-page viewport height after application."),
                Output("applied", "Boolean", "True only when runtime and page-observed viewport dimensions match the request.")
            ],
            requiredCoreVersionOverride: "1.0.20");
        Add(result,
            "web.device.emulate", "Emulate Mobile Device", "Recreate the active Playwright browser context from a real Playwright mobile device descriptor while preserving authenticated cookie/local-storage state, bounded sessionStorage and the current URL.", "Browser",
            "Dynomax BuiltIn Emulate Mobile Device", ActionSessionBehaviors.RequiresExistingBrowser, 60, ActionSideEffectKinds.ReadOnly, true,
            [
                Input("deviceProfile", "String", true, "Normal", null, "Exact base Playwright mobile device name, for example iPhone X, iPhone 13 or Pixel 5. Only existing Playwright descriptors with isMobile=true and hasTouch=true are accepted."),
                Input("orientation", "String", false, "Normal", "\"portrait\"", "Requested orientation: portrait or landscape. Landscape resolves the matching Playwright '<device> landscape' descriptor.")
            ],
            [
                Output("deviceProfile", "String", "Canonical base Playwright device profile."),
                Output("orientation", "String", "Applied portrait or landscape orientation."),
                Output("contextId", "String", "New active Playwright browser-context identifier."),
                Output("url", "String", "Restored current URL."),
                Output("viewportWidth", "Integer", "Verified CSS viewport width."),
                Output("viewportHeight", "Integer", "Verified CSS viewport height."),
                Output("screenWidth", "Integer", "Verified emulated screen width."),
                Output("screenHeight", "Integer", "Verified emulated screen height."),
                Output("deviceScaleFactor", "Decimal", "Verified device pixel ratio."),
                Output("isMobile", "Boolean", "Playwright device descriptor isMobile flag."),
                Output("hasTouch", "Boolean", "Playwright device descriptor hasTouch flag."),
                Output("coarsePointer", "Boolean", "Whether the rendered page matches the coarse-pointer media query."),
                Output("userAgent", "String", "Verified mobile user agent."),
                Output("sessionRestored", "Boolean", "True after authenticated state restoration completes."),
                Output("applied", "Boolean", "True only after page-observed mobile semantics pass verification.")
            ],
            requiredCoreVersionOverride: "1.0.20");
        Add(result,
            "web.mobile.inspect", "Inspect Mobile Layout", "Inspect the active mobile-rendered page for viewport overflow, geometry, modal scrolling, sticky/fixed elements and unreachable interactive controls without returning field values or page text.", "Browser",
            "Dynomax BuiltIn Inspect Mobile Layout", ActionSessionBehaviors.RequiresExistingBrowser, 60, ActionSideEffectKinds.ReadOnly, true,
            [Input("maxFindings", "Integer", false, "Normal", "100", "Maximum findings returned per category (1..200); the DOM scan is capped at 5000 elements.")],
            [Output("result", "Json", "Bounded secret-safe mobile layout inspection result containing device metrics, geometry and reachability findings only.")],
            requiredCoreVersionOverride: "1.0.20");        Add(result,
            "web.media.emulate", "Emulate Browser Media", "Set and verify the active Playwright page prefers-reduced-motion media feature without recreating the browser context or page.", "Browser",
            "Dynomax BuiltIn Emulate Browser Media", ActionSessionBehaviors.RequiresExistingBrowser, 30, ActionSideEffectKinds.ReadOnly, true,
            [
                Input("reducedMotion", "String", true, "Normal", null, "Requested prefers-reduced-motion state: reduce or no-preference.")
            ],
            [
                Output("requestedReducedMotion", "String", "Canonical requested prefers-reduced-motion state."),
                Output("actualReducedMotion", "String", "Verified page-observed prefers-reduced-motion state after emulation."),
                Output("reducedMotionMatches", "Boolean", "True only when the requested media query matches after genuine Browser/Playwright emulation."),
                Output("applied", "Boolean", "True only when the requested and page-observed reduced-motion states agree.")
            ],
            requiredCoreVersionOverride: "1.0.20");
        Add(result,
            "web.page.screenshot", "Take Screenshot", "Capture a screenshot into the Dynomax run evidence directory.", "Browser",
            "Dynomax BuiltIn Take Screenshot", ActionSessionBehaviors.RequiresExistingBrowser, 60, ActionSideEffectKinds.ReadOnly, true,
            [Input("fullPage", "Boolean", false, "Normal", "false", "Capture the full page when true.")],
            [Output("fileReference", "FileReference", "Run-scoped screenshot file reference.")]);
        Add(result,
            "web.page.screenshot", "Take Screenshot", "Capture an explicitly requested screenshot using Dynomax's secret-safe DOM masking before portable evidence finalization.", "Browser",
            "Dynomax BuiltIn Take Screenshot V2", ActionSessionBehaviors.RequiresExistingBrowser, 60, ActionSideEffectKinds.ReadOnly, true,
            [Input("fullPage", "Boolean", false, "Normal", "false", "Capture the full page when true."), Input("sensitiveSelectors", "Json", false, "Normal", "[]", "Optional additional Browser selectors to mask temporarily while the screenshot is captured.")],
            [Output("fileReference", "FileReference", "Run-scoped screenshot file reference retained only when capture masking succeeds.")],
            contractVersion: 2,
            requiredCoreVersionOverride: "1.0.18");
        Add(result,
            "web.page.screenshot", "Take Screenshot", "Capture an explicitly requested screenshot using Dynomax's secret-safe DOM masking before portable evidence finalization.", "Browser",
            "Dynomax BuiltIn Take Screenshot V3", ActionSessionBehaviors.RequiresExistingBrowser, 60, ActionSideEffectKinds.ReadOnly, true,
            [Input("fullPage", "Boolean", false, "Normal", "false", "Capture the full page when true."), Input("sensitiveSelectors", "Json", false, "Normal", "[]", "Optional additional Browser selectors to mask temporarily while the screenshot is captured. Selectors are handled strictly as Browser selector data and are never evaluated as JavaScript source.")],
            [Output("fileReference", "FileReference", "Run-scoped screenshot file reference retained only when capture masking succeeds.")],
            contractVersion: 3,
            requiredCoreVersionOverride: "1.0.18");
        Add(result,
            "web.page.screenshot", "Take Screenshot", "Capture an explicitly requested screenshot using Dynomax's secret-safe authored and runtime-sensitive DOM masking before portable evidence finalization.", "Browser",
            "Dynomax BuiltIn Take Screenshot V4", ActionSessionBehaviors.RequiresExistingBrowser, 60, ActionSideEffectKinds.ReadOnly, true,
            [Input("fullPage", "Boolean", false, "Normal", "false", "Capture the full page when true."), Input("sensitiveSelectors", "Json", false, "Normal", "[]", "Optional additional Browser selectors to mask temporarily while the screenshot is captured. Runtime-sensitive browser fields registered by Dynomax are also masked automatically.")],
            [Output("fileReference", "FileReference", "Run-scoped screenshot file reference retained only when capture masking succeeds.")],
            contractVersion: 4,
            requiredCoreVersionOverride: "1.0.20");
        Add(result,
            "web.dialog.accept", "Accept Dialog", "Configure the next browser dialog to be accepted.", "Browser",
            "Dynomax BuiltIn Accept Dialog", ActionSessionBehaviors.RequiresExistingBrowser, 30, ActionSideEffectKinds.ExternalEffect, false,
            [],
            []);
        Add(result,
            "web.dialog.accept", "Accept Dialog", "Configure exactly the next browser dialog to be accepted with a reusable one-shot handler.", "Browser",
            "Dynomax BuiltIn Accept Dialog V2", ActionSessionBehaviors.RequiresExistingBrowser, 30, ActionSideEffectKinds.ExternalEffect, false,
            [],
            [],
            contractVersion: 2);
        Add(result,
            "web.dialog.dismiss", "Dismiss Dialog", "Configure the next browser dialog to be dismissed.", "Browser",
            "Dynomax BuiltIn Dismiss Dialog", ActionSessionBehaviors.RequiresExistingBrowser, 30, ActionSideEffectKinds.ExternalEffect, false,
            [],
            []);
        Add(result,
            "web.dialog.dismiss", "Dismiss Dialog", "Configure exactly the next browser dialog to be dismissed with a reusable one-shot handler.", "Browser",
            "Dynomax BuiltIn Dismiss Dialog V2", ActionSessionBehaviors.RequiresExistingBrowser, 30, ActionSideEffectKinds.ExternalEffect, false,
            [],
            [],
            contractVersion: 2);
        Add(result,
            "web.window.switch", "Switch Tab / Window", "Switch to a browser page by page id or PREVIOUS/NEW selector.", "Browser",
            "Dynomax BuiltIn Switch Window", ActionSessionBehaviors.RequiresExistingBrowser, 30, ActionSideEffectKinds.ReadOnly, true,
            [Input("page", "String", true, "Normal", null, "Browser page identifier or supported selector.")],
            [Output("page", "String", "Selected page identifier.")]);
        Add(result,
            "web.window.close", "Close Tab", "Close the active browser page/tab.", "Browser",
            "Dynomax BuiltIn Close Window", ActionSessionBehaviors.RequiresExistingBrowser, 30, ActionSideEffectKinds.ExternalEffect, false,
            [],
            []);
        Add(result,
            "web.javascript.execute", "Execute JavaScript", "Execute JavaScript in the current page context.", "Browser",
            "Dynomax BuiltIn Execute JavaScript", ActionSessionBehaviors.RequiresExistingBrowser, 60, ActionSideEffectKinds.ExternalEffect, false,
            [Input("script", "String", true, "Normal", null, "JavaScript function/body executed against css=html.")],
            [Output("result", "Json", "JSON-compatible result.")]);
        Add(result,
            "web.form.snapshot", "Snapshot Form Fields", "Capture multiple form/control values from the current page in one structured read-only Action.", "Browser",
            "Dynomax BuiltIn Snapshot Form Fields", ActionSessionBehaviors.RequiresExistingBrowser, 30, ActionSideEffectKinds.ReadOnly, true,
            [
                Input("fields", "Json", true, "Normal", null, "Object mapping output names to selectors or descriptors with selector, kind and optional attribute."),
                Input("rootSelector", "String", false, "Normal", "\"\"", "Optional CSS selector that scopes every field lookup.")
            ],
            [Output("snapshot", "Json", "Captured field values keyed by the supplied names.")],
            requiredCoreVersionOverride: "1.0.20");
        Add(result,
            "web.form.snapshot", "Snapshot Form Fields", "Capture multiple form/control values from the current page in one structured read-only Action.", "Browser",
            "Dynomax BuiltIn Snapshot Form Fields", ActionSessionBehaviors.RequiresExistingBrowser, 30, ActionSideEffectKinds.ReadOnly, true,
            [
                Input("fields", "Json", true, "Normal", null, "Object mapping output names to selectors or descriptors with selector, kind and optional attribute."),
                Input("rootSelector", "String", false, "Normal", "\"\"", "Optional CSS selector that scopes every field lookup.")
            ],
            [Output("snapshot", "Json", "Captured field values keyed by the supplied names.")],
            contractVersion: 2,
            requiredCoreVersionOverride: "1.0.20");
        Add(result,
            "web.form.snapshot", "Snapshot Form Fields", "Capture multiple form/control values from the current page in one structured read-only Action.", "Browser",
            "Dynomax BuiltIn Snapshot Form Fields", ActionSessionBehaviors.RequiresExistingBrowser, 30, ActionSideEffectKinds.ReadOnly, true,
            [
                Input("fields", "Json", true, "Normal", null, "Object mapping output names to selectors or descriptors with selector, kind and optional attribute."),
                Input("rootSelector", "String", false, "Normal", "\"\"", "Optional CSS selector that scopes every field lookup.")
            ],
            [Output("snapshot", "Json", "Captured field values keyed by the supplied names.")],
            contractVersion: 3,
            requiredCoreVersionOverride: "1.0.20");
        Add(result,
            "web.form.apply-values", "Apply Form Values", "Apply multiple form/control values in one generic browser Action and dispatch input/change events.", "Browser",
            "Dynomax BuiltIn Apply Form Values", ActionSessionBehaviors.RequiresExistingBrowser, 30, ActionSideEffectKinds.UpdatesData, true,
            [
                Input("fields", "Json", true, "Normal", null, "Object mapping names/selectors to scalar values or descriptors with selector, value, kind and optional attribute."),
                Input("rootSelector", "String", false, "Normal", "\"\"", "Optional CSS selector that scopes every field lookup.")
            ],
            [
                Output("applied", "Integer", "Number of controls updated."),
                Output("results", "Json", "Safe per-field selector and update-kind evidence.")
            ],
            requiredCoreVersionOverride: "1.0.20");
        Add(result,
            "web.form.apply-values", "Apply Form Values", "Apply multiple form/control values in one generic browser Action and dispatch input/change events.", "Browser",
            "Dynomax BuiltIn Apply Form Values", ActionSessionBehaviors.RequiresExistingBrowser, 30, ActionSideEffectKinds.UpdatesData, true,
            [
                Input("fields", "Json", true, "Normal", null, "Object mapping names/selectors to scalar values or descriptors with selector, value, kind and optional attribute."),
                Input("rootSelector", "String", false, "Normal", "\"\"", "Optional CSS selector that scopes every field lookup.")
            ],
            [
                Output("applied", "Integer", "Number of controls updated."),
                Output("results", "Json", "Safe per-field selector and update-kind evidence.")
            ],
            contractVersion: 2,
            requiredCoreVersionOverride: "1.0.20");
        Add(result,
            "web.form.apply-values", "Apply Form Values", "Apply multiple form/control values in one generic browser Action and dispatch input/change events.", "Browser",
            "Dynomax BuiltIn Apply Form Values", ActionSessionBehaviors.RequiresExistingBrowser, 30, ActionSideEffectKinds.UpdatesData, true,
            [
                Input("fields", "Json", true, "Normal", null, "Object mapping names/selectors to scalar values or descriptors with selector, value, kind and optional attribute."),
                Input("rootSelector", "String", false, "Normal", "\"\"", "Optional CSS selector that scopes every field lookup.")
            ],
            [
                Output("applied", "Integer", "Number of controls updated."),
                Output("results", "Json", "Safe per-field selector and update-kind evidence.")
            ],
            contractVersion: 3,
            requiredCoreVersionOverride: "1.0.20");
        Add(result,
            "validation.text.exists", "Verify Text Exists", "Require expected visible text to exist.", "Validation",
            "Dynomax BuiltIn Verify Text Exists", ActionSessionBehaviors.RequiresExistingBrowser, 30, ActionSideEffectKinds.ReadOnly, true,
            [Input("text", "String", true, "Normal", null, "Expected visible text.")],
            [Output("verified", "Boolean", "True when verification passes.")]);
        Add(result,
            "validation.text.exists", "Verify Text Exists", "Require expected visible text to exist even when the same text is rendered by multiple elements.", "Validation",
            "Dynomax BuiltIn Verify Text Exists V2", ActionSessionBehaviors.RequiresExistingBrowser, 30, ActionSideEffectKinds.ReadOnly, true,
            [Input("text", "String", true, "Normal", null, "Expected visible text.")],
            [Output("verified", "Boolean", "True when at least one matching element is visible.")],
            contractVersion: 2);
        Add(result,
            "validation.element.exists", "Verify Element Exists", "Require an element to exist.", "Validation",
            "Dynomax BuiltIn Verify Element Exists", ActionSessionBehaviors.RequiresExistingBrowser, 30, ActionSideEffectKinds.ReadOnly, true,
            [Input("selector", "String", true, "Normal", null, "Browser selector.")],
            [Output("verified", "Boolean", "True when verification passes.")]);
        Add(result,
            "validation.element.visible", "Verify Element Visible", "Require an element to be visible.", "Validation",
            "Dynomax BuiltIn Verify Element Visible", ActionSessionBehaviors.RequiresExistingBrowser, 30, ActionSideEffectKinds.ReadOnly, true,
            [Input("selector", "String", true, "Normal", null, "Browser selector.")],
            [Output("verified", "Boolean", "True when verification passes.")]);
        Add(result,
            "validation.element.enabled", "Verify Element Enabled", "Require an element to be enabled.", "Validation",
            "Dynomax BuiltIn Verify Element Enabled", ActionSessionBehaviors.RequiresExistingBrowser, 30, ActionSideEffectKinds.ReadOnly, true,
            [Input("selector", "String", true, "Normal", null, "Browser selector.")],
            [Output("verified", "Boolean", "True when verification passes.")]);
        Add(result,
            "validation.url.verify", "Verify URL", "Require the current URL to equal an expected value.", "Validation",
            "Dynomax BuiltIn Verify URL", ActionSessionBehaviors.RequiresExistingBrowser, 30, ActionSideEffectKinds.ReadOnly, true,
            [Input("expectedUrl", "String", true, "Normal", null, "Expected URL.")],
            [Output("verified", "Boolean", "True when verification passes.")]);
        Add(result,
            "web.page.verify", "Verify Page Title", "Require the current page title to equal an expected title.", "Validation",
            "Dynomax BuiltIn Verify Page Title", ActionSessionBehaviors.RequiresExistingBrowser, 30, ActionSideEffectKinds.ReadOnly, true,
            [Input("expectedTitle", "String", true, "Normal", null, "Expected page title.")],
            [Output("title", "String", "Observed page title."), Output("verified", "Boolean", "True when verification passes.")]);
        Add(result,
            "validation.value.verify", "Verify Value", "Require actual and expected values to be equal.", "Validation",
            "Dynomax BuiltIn Verify Value", ActionSessionBehaviors.DoesNotUseBrowser, 30, ActionSideEffectKinds.None, true,
            [Input("actual", "String", true, "Normal", null, "Actual value."), Input("expected", "String", true, "Normal", null, "Expected value.")],
            [Output("verified", "Boolean", "True when verification passes.")]);
        Add(result,
            "validation.object.verify", "Verify Structured Object", "Require two JSON-compatible values to be deeply equal after deterministic canonicalization.", "Validation",
            "Dynomax BuiltIn Verify Structured Object", ActionSessionBehaviors.DoesNotUseBrowser, 30, ActionSideEffectKinds.None, true,
            [
                Input("actual", "Json", true, "Normal", null, "Actual JSON-compatible value."),
                Input("expected", "Json", true, "Normal", null, "Expected JSON-compatible value.")
            ],
            [Output("verified", "Boolean", "True when the structured values are deeply equal.")],
            requiredCoreVersionOverride: "1.0.20");
        Add(result,
            "validation.value.compare", "Compare Values", "Compare two values for equality and fail when they differ.", "Validation",
            "Dynomax BuiltIn Compare Values", ActionSessionBehaviors.DoesNotUseBrowser, 30, ActionSideEffectKinds.None, true,
            [Input("left", "String", true, "Normal", null, "Left value."), Input("right", "String", true, "Normal", null, "Right value.")],
            [Output("equal", "Boolean", "True when values are equal.")]);
        Add(result,
            "validation.regex.match", "Regex Match", "Require a value to match a regular expression.", "Validation",
            "Dynomax BuiltIn Regex Match", ActionSessionBehaviors.DoesNotUseBrowser, 30, ActionSideEffectKinds.None, true,
            [Input("value", "String", true, "Normal", null, "Value to test."), Input("pattern", "String", true, "Normal", null, "Regular expression.")],
            [Output("matched", "Boolean", "True when the regex matches.")]);
        Add(result,
            "validation.contains", "Contains", "Require text to contain an expected value.", "Validation",
            "Dynomax BuiltIn Contains", ActionSessionBehaviors.DoesNotUseBrowser, 30, ActionSideEffectKinds.None, true,
            [Input("value", "String", true, "Normal", null, "Text to inspect."), Input("expected", "String", true, "Normal", null, "Expected substring.")],
            [Output("matched", "Boolean", "True when contained.")]);
        Add(result,
            "validation.starts-with", "Starts With", "Require text to start with an expected value.", "Validation",
            "Dynomax BuiltIn Starts With", ActionSessionBehaviors.DoesNotUseBrowser, 30, ActionSideEffectKinds.None, true,
            [Input("value", "String", true, "Normal", null, "Text to inspect."), Input("expected", "String", true, "Normal", null, "Expected prefix.")],
            [Output("matched", "Boolean", "True when prefix matches.")]);
        Add(result,
            "validation.ends-with", "Ends With", "Require text to end with an expected value.", "Validation",
            "Dynomax BuiltIn Ends With", ActionSessionBehaviors.DoesNotUseBrowser, 30, ActionSideEffectKinds.None, true,
            [Input("value", "String", true, "Normal", null, "Text to inspect."), Input("expected", "String", true, "Normal", null, "Expected suffix.")],
            [Output("matched", "Boolean", "True when suffix matches.")]);
        Add(result,
            "data.json.parse", "Parse JSON", "Parse JSON text into structured data.", "Data",
            "Dynomax BuiltIn Parse JSON", ActionSessionBehaviors.DoesNotUseBrowser, 30, ActionSideEffectKinds.None, true,
            [Input("text", "String", true, "Normal", null, "JSON text.")],
            [Output("json", "Json", "Parsed JSON value.")]);
        Add(result,
            "data.json.get-value", "Get JSON Value", "Retrieve a value from JSON using a bounded dot/bracket path.", "Data",
            "Dynomax BuiltIn Get JSON Value", ActionSessionBehaviors.DoesNotUseBrowser, 30, ActionSideEffectKinds.None, true,
            [Input("json", "Json", true, "Normal", null, "JSON value or JSON text."), Input("path", "String", true, "Normal", null, "Dot/bracket path, for example customer.addresses[0].city.")],
            [Output("value", "Json", "Selected JSON-compatible value.")]);
        Add(result,
            "data.json.get-value", "Get JSON Value", "Retrieve a value from JSON while preserving runtime sensitivity from the source value.", "Data",
            "Dynomax BuiltIn Get JSON Value", ActionSessionBehaviors.DoesNotUseBrowser, 30, ActionSideEffectKinds.None, true,
            [Input("json", "Json", true, "Normal", null, "JSON value or JSON text. Sensitive runtime NodeOutput is accepted and remains runtime-only.", NormalBindings, acceptSensitiveNodeOutput: true), Input("path", "String", true, "Normal", null, "Dot/bracket path, for example customer.addresses[0].city.")],
            [Output("value", "Json", "Selected JSON-compatible value.", ActionOutputClassifications.Normal, true, ["json"])],
            contractVersion: 2,
            requiredCoreVersionOverride: "1.0.20");
        Add(result,
            "data.json.get-string", "Get JSON String", "Retrieve a string from JSON using a bounded dot/bracket path while preserving runtime sensitivity from the source value.", "Data",
            "Dynomax BuiltIn Get JSON String", ActionSessionBehaviors.DoesNotUseBrowser, 30, ActionSideEffectKinds.None, true,
            [Input("json", "Json", true, "Normal", null, "JSON value or JSON text. Sensitive runtime NodeOutput is accepted and remains runtime-only.", NormalBindings, acceptSensitiveNodeOutput: true), Input("path", "String", true, "Normal", null, "Dot/bracket path whose selected value must be a JSON string.")],
            [Output("value", "String", "Selected string value.", ActionOutputClassifications.Normal, true, ["json"])],
            requiredCoreVersionOverride: "1.0.20");
        Add(result,
            "data.json.get-string", "Get JSON String", "Retrieve a string from JSON using a bounded dot/bracket path through the direct sensitivity-preserving runtime.", "Data",
            "Dynomax BuiltIn Get JSON String", ActionSessionBehaviors.DoesNotUseBrowser, 30, ActionSideEffectKinds.None, true,
            [Input("json", "Json", true, "Normal", null, "JSON value or JSON text. Sensitive runtime NodeOutput is accepted and remains runtime-only.", NormalBindings, acceptSensitiveNodeOutput: true), Input("path", "String", true, "Normal", null, "Dot/bracket path whose selected value must be a JSON string.")],
            [Output("value", "String", "Selected string value.", ActionOutputClassifications.Normal, true, ["json"])],
            contractVersion: 2,
            requiredCoreVersionOverride: "1.0.20");
        Add(result,
            "web.file.upload", "Upload File", "Upload a run-workspace file through a browser file-input control.", "Browser",
            "Dynomax BuiltIn Upload File", ActionSessionBehaviors.RequiresExistingBrowser, 60, ActionSideEffectKinds.UpdatesData, false,
            [Input("selector", "String", true, "Normal", null, "Browser file-input selector."), Input("fileReference", "FileReference", true, "Normal", null, "Run-workspace relative file reference.")],
            [Output("uploaded", "Boolean", "True when the file is staged into the browser control.")]);
        Add(result,
            "web.file.download", "Download File", "Trigger and capture a browser download into the disposable run workspace.", "Browser",
            "Dynomax BuiltIn Download File", ActionSessionBehaviors.RequiresExistingBrowser, 120, ActionSideEffectKinds.ReadOnly, true,
            [Input("selector", "String", true, "Normal", null, "Browser selector that triggers the download."), Input("destinationDirectory", "String", false, "Normal", "\"downloads\"", "Run-workspace relative destination directory."), Input("timeoutSeconds", "Integer", false, "Normal", "60", "Download timeout in seconds.")],
            [Output("fileReference", "FileReference", "Run-workspace relative downloaded file reference.")]);
        Add(result,
            "web.file.download", "Download File", "Trigger and capture a browser download into a safe run-workspace-relative destination directory.", "Browser",
            "Dynomax BuiltIn Download File V2", ActionSessionBehaviors.RequiresExistingBrowser, 120, ActionSideEffectKinds.ReadOnly, true,
            [Input("selector", "String", true, "Normal", null, "Browser selector that triggers the download."), Input("destinationDirectory", "String", false, "Normal", "\"downloads\"", "Run-workspace relative destination directory."), Input("timeoutSeconds", "Integer", false, "Normal", "60", "Maximum time in seconds for the browser download to finish.")],
            [Output("fileReference", "FileReference", "Run-workspace relative downloaded file reference.")],
            contractVersion: 2,
            requiredCoreVersionOverride: "1.0.16");
        Add(result,
            "validation.http.status", "Verify HTTP Status", "Require an HTTP response status to equal the expected status.", "Validation",
            "Dynomax BuiltIn Verify HTTP Status", ActionSessionBehaviors.DoesNotUseBrowser, 30, ActionSideEffectKinds.None, true,
            [Input("status", "Integer", true, "Normal", null, "Actual HTTP status."), Input("expectedStatus", "Integer", true, "Normal", null, "Expected HTTP status.")],
            [Output("verified", "Boolean", "True when verification passes.")]);
        Add(result,
            "validation.json.value", "Verify JSON Value", "Require a bounded JSON path value to equal the expected value.", "Validation",
            "Dynomax BuiltIn Verify JSON Value", ActionSessionBehaviors.DoesNotUseBrowser, 30, ActionSideEffectKinds.None, true,
            [Input("json", "Json", true, "Normal", null, "JSON value or JSON text."), Input("path", "String", true, "Normal", null, "Bounded dot/bracket JSON path."), Input("expected", "Json", true, "Normal", null, "Expected JSON-compatible value.")],
            [Output("verified", "Boolean", "True when verification passes.")]);
        Add(result,
            "http.request", "HTTP Request", "Send a configurable HTTP request through the shared bounded HTTP engine.", "HTTP / API",
            "Dynomax BuiltIn HTTP Request", ActionSessionBehaviors.DoesNotUseBrowser, 300, ActionSideEffectKinds.ExternalEffect, false,
            [Input("method", "String", false, "Normal", "\"GET\"", "HTTP method."), Input("url", "String", true, "Normal", null, "Absolute HTTP/HTTPS URL whose origin must be allowed by the Environment."), Input("headers", "Json", false, "Normal", "{}", "Non-secret request headers."), Input("secretHeadersJson", "String", false, "Secret", null, "Optional secret-reference JSON object containing sensitive request headers."), Input("body", "String", false, "Normal", "null", "Optional request body, bounded to 4 MiB."), Input("contentType", "String", false, "Normal", "null", "Optional request Content-Type."), Input("timeoutSeconds", "Integer", false, "Normal", "30", "Request timeout in seconds.")],
            [Output("status", "Integer", "HTTP status code."), Output("headers", "Json", "Response headers with credential/cookie headers removed."), Output("body", "String", "Bounded response body."), Output("contentType", "String", "Response content type."), Output("durationMs", "Integer", "Request duration in milliseconds."), Output("finalUrl", "String", "Final URL after allowed redirects.")]);
        Add(result,
            "http.request", "HTTP Request", "Send a configurable HTTP request through the shared bounded HTTP engine.", "HTTP / API",
            "Dynomax BuiltIn HTTP Request", ActionSessionBehaviors.DoesNotUseBrowser, 300, ActionSideEffectKinds.ExternalEffect, false,
            [Input("method", "String", false, "Normal", "\"GET\"", "HTTP method."), Input("url", "String", true, "Normal", null, "Absolute HTTP/HTTPS URL whose origin must be allowed by the Environment."), Input("headers", "Json", false, "Normal", "{}", "Non-secret request headers."), Input("secretHeadersJson", "String", false, "Secret", null, "Optional secret-reference JSON object containing sensitive request headers."), Input("body", "String", false, "Normal", "null", "Optional request body, bounded to 4 MiB. Sensitive runtime NodeOutput is accepted as an explicit outbound sink and remains runtime-only.", NormalBindings, acceptSensitiveNodeOutput: true), Input("contentType", "String", false, "Normal", "null", "Optional request Content-Type."), Input("timeoutSeconds", "Integer", false, "Normal", "30", "Request timeout in seconds.")],
            [Output("status", "Integer", "HTTP status code."), Output("headers", "Json", "Response headers with credential/cookie headers removed."), Output("body", "String", "Bounded response body.", ActionOutputClassifications.Normal, true, ["body"]), Output("contentType", "String", "Response content type."), Output("durationMs", "Integer", "Request duration in milliseconds."), Output("finalUrl", "String", "Final URL after allowed redirects.")],
            contractVersion: 2,
            requiredCoreVersionOverride: "1.0.20");
        Add(result,
            "http.get", "HTTP GET", "Send an HTTP GET request through the shared bounded HTTP engine.", "HTTP / API",
            "Dynomax BuiltIn HTTP GET", ActionSessionBehaviors.DoesNotUseBrowser, 300, ActionSideEffectKinds.ReadOnly, true,
            [Input("url", "String", true, "Normal", null, "Absolute HTTP/HTTPS URL whose origin must be allowed by the Environment."), Input("headers", "Json", false, "Normal", "{}", "Non-secret request headers."), Input("secretHeadersJson", "String", false, "Secret", null, "Optional secret-reference JSON object containing sensitive request headers."), Input("body", "String", false, "Normal", "null", "Optional request body, bounded to 4 MiB."), Input("contentType", "String", false, "Normal", "null", "Optional request Content-Type."), Input("timeoutSeconds", "Integer", false, "Normal", "30", "Request timeout in seconds.")],
            [Output("status", "Integer", "HTTP status code."), Output("headers", "Json", "Response headers with credential/cookie headers removed."), Output("body", "String", "Bounded response body."), Output("contentType", "String", "Response content type."), Output("durationMs", "Integer", "Request duration in milliseconds."), Output("finalUrl", "String", "Final URL after allowed redirects.")]);
        Add(result,
            "http.post", "HTTP POST", "Send an HTTP POST request through the shared bounded HTTP engine.", "HTTP / API",
            "Dynomax BuiltIn HTTP POST", ActionSessionBehaviors.DoesNotUseBrowser, 300, ActionSideEffectKinds.ExternalEffect, false,
            [Input("url", "String", true, "Normal", null, "Absolute HTTP/HTTPS URL whose origin must be allowed by the Environment."), Input("headers", "Json", false, "Normal", "{}", "Non-secret request headers."), Input("secretHeadersJson", "String", false, "Secret", null, "Optional secret-reference JSON object containing sensitive request headers."), Input("body", "String", false, "Normal", "null", "Optional request body, bounded to 4 MiB."), Input("contentType", "String", false, "Normal", "null", "Optional request Content-Type."), Input("timeoutSeconds", "Integer", false, "Normal", "30", "Request timeout in seconds.")],
            [Output("status", "Integer", "HTTP status code."), Output("headers", "Json", "Response headers with credential/cookie headers removed."), Output("body", "String", "Bounded response body."), Output("contentType", "String", "Response content type."), Output("durationMs", "Integer", "Request duration in milliseconds."), Output("finalUrl", "String", "Final URL after allowed redirects.")]);
        Add(result,
            "http.post", "HTTP POST", "Send an HTTP POST request through the shared bounded HTTP engine.", "HTTP / API",
            "Dynomax BuiltIn HTTP POST", ActionSessionBehaviors.DoesNotUseBrowser, 300, ActionSideEffectKinds.ExternalEffect, false,
            [Input("url", "String", true, "Normal", null, "Absolute HTTP/HTTPS URL whose origin must be allowed by the Environment."), Input("headers", "Json", false, "Normal", "{}", "Non-secret request headers."), Input("secretHeadersJson", "String", false, "Secret", null, "Optional secret-reference JSON object containing sensitive request headers."), Input("body", "String", false, "Normal", "null", "Optional request body, bounded to 4 MiB. Sensitive runtime NodeOutput is accepted as an explicit outbound sink and remains runtime-only.", NormalBindings, acceptSensitiveNodeOutput: true), Input("contentType", "String", false, "Normal", "null", "Optional request Content-Type."), Input("timeoutSeconds", "Integer", false, "Normal", "30", "Request timeout in seconds.")],
            [Output("status", "Integer", "HTTP status code."), Output("headers", "Json", "Response headers with credential/cookie headers removed."), Output("body", "String", "Bounded response body.", ActionOutputClassifications.Normal, true, ["body"]), Output("contentType", "String", "Response content type."), Output("durationMs", "Integer", "Request duration in milliseconds."), Output("finalUrl", "String", "Final URL after allowed redirects.")],
            contractVersion: 2,
            requiredCoreVersionOverride: "1.0.20");
        Add(result,
            "http.put", "HTTP PUT", "Send an HTTP PUT request through the shared bounded HTTP engine.", "HTTP / API",
            "Dynomax BuiltIn HTTP PUT", ActionSessionBehaviors.DoesNotUseBrowser, 300, ActionSideEffectKinds.ExternalEffect, false,
            [Input("url", "String", true, "Normal", null, "Absolute HTTP/HTTPS URL whose origin must be allowed by the Environment."), Input("headers", "Json", false, "Normal", "{}", "Non-secret request headers."), Input("secretHeadersJson", "String", false, "Secret", null, "Optional secret-reference JSON object containing sensitive request headers."), Input("body", "String", false, "Normal", "null", "Optional request body, bounded to 4 MiB."), Input("contentType", "String", false, "Normal", "null", "Optional request Content-Type."), Input("timeoutSeconds", "Integer", false, "Normal", "30", "Request timeout in seconds.")],
            [Output("status", "Integer", "HTTP status code."), Output("headers", "Json", "Response headers with credential/cookie headers removed."), Output("body", "String", "Bounded response body."), Output("contentType", "String", "Response content type."), Output("durationMs", "Integer", "Request duration in milliseconds."), Output("finalUrl", "String", "Final URL after allowed redirects.")]);
        Add(result,
            "http.put", "HTTP PUT", "Send an HTTP PUT request through the shared bounded HTTP engine.", "HTTP / API",
            "Dynomax BuiltIn HTTP PUT", ActionSessionBehaviors.DoesNotUseBrowser, 300, ActionSideEffectKinds.ExternalEffect, false,
            [Input("url", "String", true, "Normal", null, "Absolute HTTP/HTTPS URL whose origin must be allowed by the Environment."), Input("headers", "Json", false, "Normal", "{}", "Non-secret request headers."), Input("secretHeadersJson", "String", false, "Secret", null, "Optional secret-reference JSON object containing sensitive request headers."), Input("body", "String", false, "Normal", "null", "Optional request body, bounded to 4 MiB. Sensitive runtime NodeOutput is accepted as an explicit outbound sink and remains runtime-only.", NormalBindings, acceptSensitiveNodeOutput: true), Input("contentType", "String", false, "Normal", "null", "Optional request Content-Type."), Input("timeoutSeconds", "Integer", false, "Normal", "30", "Request timeout in seconds.")],
            [Output("status", "Integer", "HTTP status code."), Output("headers", "Json", "Response headers with credential/cookie headers removed."), Output("body", "String", "Bounded response body.", ActionOutputClassifications.Normal, true, ["body"]), Output("contentType", "String", "Response content type."), Output("durationMs", "Integer", "Request duration in milliseconds."), Output("finalUrl", "String", "Final URL after allowed redirects.")],
            contractVersion: 2,
            requiredCoreVersionOverride: "1.0.20");
        Add(result,
            "http.patch", "HTTP PATCH", "Send an HTTP PATCH request through the shared bounded HTTP engine.", "HTTP / API",
            "Dynomax BuiltIn HTTP PATCH", ActionSessionBehaviors.DoesNotUseBrowser, 300, ActionSideEffectKinds.ExternalEffect, false,
            [Input("url", "String", true, "Normal", null, "Absolute HTTP/HTTPS URL whose origin must be allowed by the Environment."), Input("headers", "Json", false, "Normal", "{}", "Non-secret request headers."), Input("secretHeadersJson", "String", false, "Secret", null, "Optional secret-reference JSON object containing sensitive request headers."), Input("body", "String", false, "Normal", "null", "Optional request body, bounded to 4 MiB."), Input("contentType", "String", false, "Normal", "null", "Optional request Content-Type."), Input("timeoutSeconds", "Integer", false, "Normal", "30", "Request timeout in seconds.")],
            [Output("status", "Integer", "HTTP status code."), Output("headers", "Json", "Response headers with credential/cookie headers removed."), Output("body", "String", "Bounded response body."), Output("contentType", "String", "Response content type."), Output("durationMs", "Integer", "Request duration in milliseconds."), Output("finalUrl", "String", "Final URL after allowed redirects.")]);
        Add(result,
            "http.patch", "HTTP PATCH", "Send an HTTP PATCH request through the shared bounded HTTP engine.", "HTTP / API",
            "Dynomax BuiltIn HTTP PATCH", ActionSessionBehaviors.DoesNotUseBrowser, 300, ActionSideEffectKinds.ExternalEffect, false,
            [Input("url", "String", true, "Normal", null, "Absolute HTTP/HTTPS URL whose origin must be allowed by the Environment."), Input("headers", "Json", false, "Normal", "{}", "Non-secret request headers."), Input("secretHeadersJson", "String", false, "Secret", null, "Optional secret-reference JSON object containing sensitive request headers."), Input("body", "String", false, "Normal", "null", "Optional request body, bounded to 4 MiB. Sensitive runtime NodeOutput is accepted as an explicit outbound sink and remains runtime-only.", NormalBindings, acceptSensitiveNodeOutput: true), Input("contentType", "String", false, "Normal", "null", "Optional request Content-Type."), Input("timeoutSeconds", "Integer", false, "Normal", "30", "Request timeout in seconds.")],
            [Output("status", "Integer", "HTTP status code."), Output("headers", "Json", "Response headers with credential/cookie headers removed."), Output("body", "String", "Bounded response body.", ActionOutputClassifications.Normal, true, ["body"]), Output("contentType", "String", "Response content type."), Output("durationMs", "Integer", "Request duration in milliseconds."), Output("finalUrl", "String", "Final URL after allowed redirects.")],
            contractVersion: 2,
            requiredCoreVersionOverride: "1.0.20");
        Add(result,
            "http.delete", "HTTP DELETE", "Send an HTTP DELETE request through the shared bounded HTTP engine.", "HTTP / API",
            "Dynomax BuiltIn HTTP DELETE", ActionSessionBehaviors.DoesNotUseBrowser, 300, ActionSideEffectKinds.DeletesData, false,
            [Input("url", "String", true, "Normal", null, "Absolute HTTP/HTTPS URL whose origin must be allowed by the Environment."), Input("headers", "Json", false, "Normal", "{}", "Non-secret request headers."), Input("secretHeadersJson", "String", false, "Secret", null, "Optional secret-reference JSON object containing sensitive request headers."), Input("body", "String", false, "Normal", "null", "Optional request body, bounded to 4 MiB."), Input("contentType", "String", false, "Normal", "null", "Optional request Content-Type."), Input("timeoutSeconds", "Integer", false, "Normal", "30", "Request timeout in seconds.")],
            [Output("status", "Integer", "HTTP status code."), Output("headers", "Json", "Response headers with credential/cookie headers removed."), Output("body", "String", "Bounded response body."), Output("contentType", "String", "Response content type."), Output("durationMs", "Integer", "Request duration in milliseconds."), Output("finalUrl", "String", "Final URL after allowed redirects.")]);
        Add(result,
            "http.delete", "HTTP DELETE", "Send an HTTP DELETE request through the shared bounded HTTP engine.", "HTTP / API",
            "Dynomax BuiltIn HTTP DELETE", ActionSessionBehaviors.DoesNotUseBrowser, 300, ActionSideEffectKinds.DeletesData, false,
            [Input("url", "String", true, "Normal", null, "Absolute HTTP/HTTPS URL whose origin must be allowed by the Environment."), Input("headers", "Json", false, "Normal", "{}", "Non-secret request headers."), Input("secretHeadersJson", "String", false, "Secret", null, "Optional secret-reference JSON object containing sensitive request headers."), Input("body", "String", false, "Normal", "null", "Optional request body, bounded to 4 MiB. Sensitive runtime NodeOutput is accepted as an explicit outbound sink and remains runtime-only.", NormalBindings, acceptSensitiveNodeOutput: true), Input("contentType", "String", false, "Normal", "null", "Optional request Content-Type."), Input("timeoutSeconds", "Integer", false, "Normal", "30", "Request timeout in seconds.")],
            [Output("status", "Integer", "HTTP status code."), Output("headers", "Json", "Response headers with credential/cookie headers removed."), Output("body", "String", "Bounded response body.", ActionOutputClassifications.Normal, true, ["body"]), Output("contentType", "String", "Response content type."), Output("durationMs", "Integer", "Request duration in milliseconds."), Output("finalUrl", "String", "Final URL after allowed redirects.")],
            contractVersion: 2,
            requiredCoreVersionOverride: "1.0.20");
        Add(result,
            "http.download-url", "Download URL", "Download bounded content from an allowed HTTP URL into the disposable run workspace.", "HTTP / API",
            "Dynomax BuiltIn Download URL", ActionSessionBehaviors.DoesNotUseBrowser, 300, ActionSideEffectKinds.ReadOnly, true,
            [Input("url", "String", true, "Normal", null, "Allowed absolute URL."), Input("headers", "Json", false, "Normal", "{}", "Non-secret request headers."), Input("secretHeadersJson", "String", false, "Secret", null, "Optional secret-reference JSON headers."), Input("destinationPath", "String", true, "Normal", null, "Run-workspace relative destination file path."), Input("timeoutSeconds", "Integer", false, "Normal", "60", "Request timeout in seconds.")],
            [Output("status", "Integer", "HTTP status code."), Output("headers", "Json", "Sanitized response headers."), Output("contentType", "String", "Response content type."), Output("durationMs", "Integer", "Request duration."), Output("finalUrl", "String", "Final allowed URL."), Output("fileReference", "FileReference", "Downloaded run-workspace file reference.")]);
        Add(result,
            "http.upload-file", "Upload File", "Upload a run-workspace file to an allowed HTTP endpoint using multipart/form-data.", "HTTP / API",
            "Dynomax BuiltIn Upload File", ActionSessionBehaviors.DoesNotUseBrowser, 300, ActionSideEffectKinds.ExternalEffect, false,
            [Input("url", "String", true, "Normal", null, "Allowed absolute URL."), Input("method", "String", false, "Normal", "\"POST\"", "POST, PUT or PATCH method."), Input("headers", "Json", false, "Normal", "{}", "Non-secret request headers."), Input("secretHeadersJson", "String", false, "Secret", null, "Optional secret-reference JSON headers."), Input("fileReference", "FileReference", true, "Normal", null, "Run-workspace relative file reference."), Input("fieldName", "String", false, "Normal", "\"file\"", "Multipart file field name."), Input("fields", "Json", false, "Normal", "{}", "Additional non-secret multipart fields."), Input("timeoutSeconds", "Integer", false, "Normal", "60", "Request timeout in seconds.")],
            [Output("status", "Integer", "HTTP status code."), Output("headers", "Json", "Response headers with credential/cookie headers removed."), Output("body", "String", "Bounded response body."), Output("contentType", "String", "Response content type."), Output("durationMs", "Integer", "Request duration in milliseconds."), Output("finalUrl", "String", "Final URL after allowed redirects.")]);
        Add(result,
            "http.webhook.call", "Webhook Call", "POST bounded data to an allowed webhook endpoint using the shared HTTP engine.", "HTTP / API",
            "Dynomax BuiltIn Webhook Call", ActionSessionBehaviors.DoesNotUseBrowser, 300, ActionSideEffectKinds.ExternalEffect, false,
            [Input("url", "String", true, "Normal", null, "Absolute HTTP/HTTPS URL whose origin must be allowed by the Environment."), Input("headers", "Json", false, "Normal", "{}", "Non-secret request headers."), Input("secretHeadersJson", "String", false, "Secret", null, "Optional secret-reference JSON object containing sensitive request headers."), Input("body", "String", false, "Normal", "null", "Optional request body, bounded to 4 MiB."), Input("contentType", "String", false, "Normal", "null", "Optional request Content-Type."), Input("timeoutSeconds", "Integer", false, "Normal", "30", "Request timeout in seconds.")],
            [Output("status", "Integer", "HTTP status code."), Output("headers", "Json", "Response headers with credential/cookie headers removed."), Output("body", "String", "Bounded response body."), Output("contentType", "String", "Response content type."), Output("durationMs", "Integer", "Request duration in milliseconds."), Output("finalUrl", "String", "Final URL after allowed redirects.")]);
        Add(result,
            "http.webhook.call", "Webhook Call", "POST bounded data to an allowed webhook endpoint using the shared HTTP engine.", "HTTP / API",
            "Dynomax BuiltIn Webhook Call", ActionSessionBehaviors.DoesNotUseBrowser, 300, ActionSideEffectKinds.ExternalEffect, false,
            [Input("url", "String", true, "Normal", null, "Absolute HTTP/HTTPS URL whose origin must be allowed by the Environment."), Input("headers", "Json", false, "Normal", "{}", "Non-secret request headers."), Input("secretHeadersJson", "String", false, "Secret", null, "Optional secret-reference JSON object containing sensitive request headers."), Input("body", "String", false, "Normal", "null", "Optional request body, bounded to 4 MiB. Sensitive runtime NodeOutput is accepted as an explicit outbound sink and remains runtime-only.", NormalBindings, acceptSensitiveNodeOutput: true), Input("contentType", "String", false, "Normal", "null", "Optional request Content-Type."), Input("timeoutSeconds", "Integer", false, "Normal", "30", "Request timeout in seconds.")],
            [Output("status", "Integer", "HTTP status code."), Output("headers", "Json", "Response headers with credential/cookie headers removed."), Output("body", "String", "Bounded response body.", ActionOutputClassifications.Normal, true, ["body"]), Output("contentType", "String", "Response content type."), Output("durationMs", "Integer", "Request duration in milliseconds."), Output("finalUrl", "String", "Final URL after allowed redirects.")],
            contractVersion: 2,
            requiredCoreVersionOverride: "1.0.20");
        Add(result,
            "http.oauth2.token", "OAuth 2.0 Token Request", "Obtain an OAuth 2.0 token from an allowed token endpoint without persisting the access token.", "HTTP / API",
            "Dynomax BuiltIn OAuth 2.0 Token Request", ActionSessionBehaviors.DoesNotUseBrowser, 300, ActionSideEffectKinds.ReadOnly, true,
            [Input("url", "String", true, "Normal", null, "Allowed OAuth token endpoint."), Input("clientId", "String", true, "Normal", null, "OAuth client id."), Input("clientSecret", "String", true, "Secret", null, "OAuth client secret reference."), Input("scope", "String", false, "Normal", "null", "Optional OAuth scope string."), Input("grantType", "String", false, "Normal", "\"client_credentials\"", "OAuth grant type."), Input("timeoutSeconds", "Integer", false, "Normal", "30", "Request timeout in seconds.")],
            [Output("accessToken", "String", "Runtime-only access token.", "SensitiveRedacted", false), Output("tokenType", "String", "OAuth token type."), Output("expiresIn", "Integer", "Token lifetime in seconds where supplied.")]);
        Add(result,
            "http.bearer.request", "Bearer Token Request", "Send an allowed HTTP request using a runtime or secret-reference bearer token.", "HTTP / API",
            "Dynomax BuiltIn Bearer Token Request", ActionSessionBehaviors.DoesNotUseBrowser, 300, ActionSideEffectKinds.ExternalEffect, false,
            [Input("method", "String", false, "Normal", "\"GET\"", "HTTP method."), Input("url", "String", true, "Normal", null, "Allowed absolute URL."), Input("accessToken", "String", true, "Sensitive", null, "Sensitive bearer token; may come from OAuth output or a secret reference."), Input("headers", "Json", false, "Normal", "{}", "Additional non-secret headers."), Input("body", "String", false, "Normal", "null", "Optional body."), Input("contentType", "String", false, "Normal", "null", "Optional content type."), Input("timeoutSeconds", "Integer", false, "Normal", "30", "Request timeout.")],
            [Output("status", "Integer", "HTTP status code."), Output("headers", "Json", "Response headers with credential/cookie headers removed."), Output("body", "String", "Bounded response body."), Output("contentType", "String", "Response content type."), Output("durationMs", "Integer", "Request duration in milliseconds."), Output("finalUrl", "String", "Final URL after allowed redirects.")]);
        Add(result,
            "http.bearer.request", "Bearer Token Request", "Send an allowed HTTP request using a runtime or secret-reference bearer token.", "HTTP / API",
            "Dynomax BuiltIn Bearer Token Request", ActionSessionBehaviors.DoesNotUseBrowser, 300, ActionSideEffectKinds.ExternalEffect, false,
            [Input("method", "String", false, "Normal", "\"GET\"", "HTTP method."), Input("url", "String", true, "Normal", null, "Allowed absolute URL."), Input("accessToken", "String", true, "Sensitive", null, "Sensitive bearer token; may come from OAuth output or a secret reference."), Input("headers", "Json", false, "Normal", "{}", "Additional non-secret headers."), Input("body", "String", false, "Normal", "null", "Optional body. Sensitive runtime NodeOutput is accepted as an explicit outbound sink and remains runtime-only.", NormalBindings, acceptSensitiveNodeOutput: true), Input("contentType", "String", false, "Normal", "null", "Optional content type."), Input("timeoutSeconds", "Integer", false, "Normal", "30", "Request timeout.")],
            [Output("status", "Integer", "HTTP status code."), Output("headers", "Json", "Response headers with credential/cookie headers removed."), Output("body", "String", "Bounded response body.", ActionOutputClassifications.Normal, true, ["body"]), Output("contentType", "String", "Response content type."), Output("durationMs", "Integer", "Request duration in milliseconds."), Output("finalUrl", "String", "Final URL after allowed redirects.")],
            contractVersion: 2,
            requiredCoreVersionOverride: "1.0.20");
        Add(result,
            "http.basic.request", "Basic Authentication Request", "Send an allowed HTTP request using Basic authentication credentials supplied only through secret references.", "HTTP / API",
            "Dynomax BuiltIn Basic Authentication Request", ActionSessionBehaviors.DoesNotUseBrowser, 300, ActionSideEffectKinds.ExternalEffect, false,
            [Input("method", "String", false, "Normal", "\"GET\"", "HTTP method."), Input("url", "String", true, "Normal", null, "Allowed absolute URL."), Input("username", "String", true, "Secret", null, "Basic-auth username secret reference."), Input("password", "String", true, "Secret", null, "Basic-auth password secret reference."), Input("headers", "Json", false, "Normal", "{}", "Additional non-secret headers."), Input("body", "String", false, "Normal", "null", "Optional body."), Input("contentType", "String", false, "Normal", "null", "Optional content type."), Input("timeoutSeconds", "Integer", false, "Normal", "30", "Request timeout.")],
            [Output("status", "Integer", "HTTP status code."), Output("headers", "Json", "Response headers with credential/cookie headers removed."), Output("body", "String", "Bounded response body."), Output("contentType", "String", "Response content type."), Output("durationMs", "Integer", "Request duration in milliseconds."), Output("finalUrl", "String", "Final URL after allowed redirects.")]);
        Add(result,
            "http.basic.request", "Basic Authentication Request", "Send an allowed HTTP request using Basic authentication credentials supplied only through secret references.", "HTTP / API",
            "Dynomax BuiltIn Basic Authentication Request", ActionSessionBehaviors.DoesNotUseBrowser, 300, ActionSideEffectKinds.ExternalEffect, false,
            [Input("method", "String", false, "Normal", "\"GET\"", "HTTP method."), Input("url", "String", true, "Normal", null, "Allowed absolute URL."), Input("username", "String", true, "Secret", null, "Basic-auth username secret reference."), Input("password", "String", true, "Secret", null, "Basic-auth password secret reference."), Input("headers", "Json", false, "Normal", "{}", "Additional non-secret headers."), Input("body", "String", false, "Normal", "null", "Optional body. Sensitive runtime NodeOutput is accepted as an explicit outbound sink and remains runtime-only.", NormalBindings, acceptSensitiveNodeOutput: true), Input("contentType", "String", false, "Normal", "null", "Optional content type."), Input("timeoutSeconds", "Integer", false, "Normal", "30", "Request timeout.")],
            [Output("status", "Integer", "HTTP status code."), Output("headers", "Json", "Response headers with credential/cookie headers removed."), Output("body", "String", "Bounded response body.", ActionOutputClassifications.Normal, true, ["body"]), Output("contentType", "String", "Response content type."), Output("durationMs", "Integer", "Request duration in milliseconds."), Output("finalUrl", "String", "Final URL after allowed redirects.")],
            contractVersion: 2,
            requiredCoreVersionOverride: "1.0.20");
        Add(result,
            "file.text.read", "Read Text File", "Read UTF-8 text from a run-workspace file.", "Files",
            "Dynomax BuiltIn Read Text File", ActionSessionBehaviors.DoesNotUseBrowser, 30, ActionSideEffectKinds.ReadOnly, true,
            [Input("path", "String", true, "Normal", null, "Run-workspace relative file path."), Input("maxCharacters", "Integer", false, "Normal", "4194304", "Maximum characters to read.")],
            [Output("text", "String", "File text.")]);
        Add(result,
            "file.text.write", "Write Text File", "Write UTF-8 text to a run-workspace file.", "Files",
            "Dynomax BuiltIn Write Text File", ActionSessionBehaviors.DoesNotUseBrowser, 30, ActionSideEffectKinds.UpdatesData, false,
            [Input("path", "String", true, "Normal", null, "Run-workspace relative file path."), Input("text", "String", true, "Normal", null, "Text to write."), Input("overwrite", "Boolean", false, "Normal", "true", "Allow replacement of an existing file.")],
            [Output("fileReference", "FileReference", "Written file reference.")]);
        Add(result,
            "file.text.append", "Append Text File", "Append UTF-8 text to a run-workspace file.", "Files",
            "Dynomax BuiltIn Append Text File", ActionSessionBehaviors.DoesNotUseBrowser, 30, ActionSideEffectKinds.UpdatesData, false,
            [Input("path", "String", true, "Normal", null, "Run-workspace relative file path."), Input("text", "String", true, "Normal", null, "Text to append.")],
            [Output("fileReference", "FileReference", "Updated file reference.")]);
        Add(result,
            "file.copy", "Copy File", "Copy File within the disposable run workspace.", "Files",
            "Dynomax BuiltIn Copy File", ActionSessionBehaviors.DoesNotUseBrowser, 30, ActionSideEffectKinds.CreatesData, false,
            [Input("sourcePath", "String", true, "Normal", null, "Source run-workspace relative file path."), Input("destinationPath", "String", true, "Normal", null, "Destination run-workspace relative file path."), Input("overwrite", "Boolean", false, "Normal", "false", "Allow replacement of an existing destination.")],
            [Output("fileReference", "FileReference", "Destination file reference.")]);
        Add(result,
            "file.copy", "Copy File", "Copy File within the disposable run workspace.", "Files",
            "Dynomax BuiltIn Copy File V2", ActionSessionBehaviors.DoesNotUseBrowser, 30, ActionSideEffectKinds.None, false,
            [Input("sourcePath", "String", true, "Normal", null, "Source run-workspace relative file path."), Input("destinationPath", "String", true, "Normal", null, "Destination run-workspace relative file path."), Input("overwrite", "Boolean", false, "Normal", "false", "Allow replacement of an existing destination.")],
            [Output("fileReference", "FileReference", "Destination file reference.")],
            contractVersion: 2);
        Add(result,
            "file.move", "Move File", "Move File within the disposable run workspace.", "Files",
            "Dynomax BuiltIn Move File", ActionSessionBehaviors.DoesNotUseBrowser, 30, ActionSideEffectKinds.UpdatesData, false,
            [Input("sourcePath", "String", true, "Normal", null, "Source run-workspace relative file path."), Input("destinationPath", "String", true, "Normal", null, "Destination run-workspace relative file path."), Input("overwrite", "Boolean", false, "Normal", "false", "Allow replacement of an existing destination.")],
            [Output("fileReference", "FileReference", "Destination file reference.")]);
        Add(result,
            "file.delete", "Delete File", "Delete a file within the disposable run workspace.", "Files",
            "Dynomax BuiltIn Delete File", ActionSessionBehaviors.DoesNotUseBrowser, 30, ActionSideEffectKinds.DeletesData, false,
            [Input("path", "String", true, "Normal", null, "Run-workspace relative file path."), Input("missingOk", "Boolean", false, "Normal", "true", "Treat an already-missing file as success.")],
            [Output("deleted", "Boolean", "True when deletion is complete.")]);
        Add(result,
            "file.exists", "File Exists", "Determine whether a run-workspace file exists.", "Files",
            "Dynomax BuiltIn File Exists", ActionSessionBehaviors.DoesNotUseBrowser, 30, ActionSideEffectKinds.ReadOnly, true,
            [Input("path", "String", true, "Normal", null, "Run-workspace relative file path.")],
            [Output("exists", "Boolean", "True when the file exists.")]);
        Add(result,
            "directory.create", "Create Directory", "Create a directory within the disposable run workspace.", "Files",
            "Dynomax BuiltIn Create Directory", ActionSessionBehaviors.DoesNotUseBrowser, 30, ActionSideEffectKinds.CreatesData, true,
            [Input("path", "String", true, "Normal", null, "Run-workspace relative directory path.")],
            [Output("directoryReference", "String", "Created directory reference.")]);
        Add(result,
            "directory.delete", "Delete Directory", "Delete a directory within the disposable run workspace.", "Files",
            "Dynomax BuiltIn Delete Directory", ActionSessionBehaviors.DoesNotUseBrowser, 30, ActionSideEffectKinds.DeletesData, false,
            [Input("path", "String", true, "Normal", null, "Run-workspace relative directory path."), Input("recursive", "Boolean", false, "Normal", "false", "Delete contained items recursively."), Input("missingOk", "Boolean", false, "Normal", "true", "Treat an already-missing directory as success.")],
            [Output("deleted", "Boolean", "True when deletion is complete.")]);
        Add(result,
            "directory.list", "List Directory", "List bounded entries from a run-workspace directory.", "Files",
            "Dynomax BuiltIn List Directory", ActionSessionBehaviors.DoesNotUseBrowser, 30, ActionSideEffectKinds.ReadOnly, true,
            [Input("path", "String", false, "Normal", "\".\"", "Run-workspace relative directory path."), Input("recursive", "Boolean", false, "Normal", "false", "Include nested entries.")],
            [Output("entries", "Json", "Bounded entry metadata."), Output("count", "Integer", "Entry count.")]);
        Add(result,
            "file.find", "Find Files", "Find bounded matching files within the disposable run workspace.", "Files",
            "Dynomax BuiltIn Find Files", ActionSessionBehaviors.DoesNotUseBrowser, 30, ActionSideEffectKinds.ReadOnly, true,
            [Input("path", "String", false, "Normal", "\".\"", "Search root."), Input("pattern", "String", false, "Normal", "\"*\"", "File-name glob pattern."), Input("recursive", "Boolean", false, "Normal", "true", "Search recursively.")],
            [Output("files", "Json", "Matching file metadata."), Output("count", "Integer", "Match count.")]);
        Add(result,
            "file.info", "Get File Information", "Return safe metadata for a run-workspace file or directory.", "Files",
            "Dynomax BuiltIn Get File Information", ActionSessionBehaviors.DoesNotUseBrowser, 30, ActionSideEffectKinds.ReadOnly, true,
            [Input("path", "String", true, "Normal", null, "Run-workspace relative path.")],
            [Output("info", "Json", "Safe file metadata.")]);
        Add(result,
            "file.hash.sha256", "Calculate File Hash", "Calculate SHA-256 for a run-workspace file.", "Files",
            "Dynomax BuiltIn Calculate File Hash", ActionSessionBehaviors.DoesNotUseBrowser, 30, ActionSideEffectKinds.ReadOnly, true,
            [Input("path", "String", true, "Normal", null, "Run-workspace relative file path.")],
            [Output("sha256", "String", "Lower-case SHA-256 digest.")]);
        Add(result,
            "file.zip.compress", "Compress ZIP", "Create a bounded ZIP from run-workspace files/directories.", "Files",
            "Dynomax BuiltIn Compress ZIP", ActionSessionBehaviors.DoesNotUseBrowser, 300, ActionSideEffectKinds.CreatesData, false,
            [Input("paths", "Json", true, "Normal", null, "JSON array of run-workspace source paths."), Input("destinationPath", "String", true, "Normal", null, "Run-workspace relative ZIP path.")],
            [Output("fileReference", "FileReference", "Created ZIP reference.")]);
        Add(result,
            "file.zip.extract", "Extract ZIP", "Extract a bounded ZIP into the disposable run workspace with zip-slip protection.", "Files",
            "Dynomax BuiltIn Extract ZIP", ActionSessionBehaviors.DoesNotUseBrowser, 300, ActionSideEffectKinds.CreatesData, false,
            [Input("zipPath", "String", true, "Normal", null, "Run-workspace relative ZIP path."), Input("destinationDirectory", "String", true, "Normal", null, "Run-workspace relative destination directory.")],
            [Output("directoryReference", "String", "Destination directory reference."), Output("entryCount", "Integer", "Extracted entry count.")]);
        Add(result,
            "file.csv.read", "Read CSV", "Read CSV from the disposable run workspace.", "Files",
            "Dynomax BuiltIn Read CSV", ActionSessionBehaviors.DoesNotUseBrowser, 30, ActionSideEffectKinds.ReadOnly, true,
            [Input("path", "String", true, "Normal", null, "Run-workspace relative file path."), Input("delimiter", "String", false, "Normal", "\",\"", "CSV delimiter.")],
            [Output("rows", "Json", "Read rows value.")]);
        Add(result,
            "file.json.read", "Read JSON File", "Read JSON File from the disposable run workspace.", "Files",
            "Dynomax BuiltIn Read JSON File", ActionSessionBehaviors.DoesNotUseBrowser, 30, ActionSideEffectKinds.ReadOnly, true,
            [Input("path", "String", true, "Normal", null, "Run-workspace relative file path.")],
            [Output("json", "Json", "Read json value.")]);
        Add(result,
            "file.xml.read", "Read XML File", "Read XML File from the disposable run workspace.", "Files",
            "Dynomax BuiltIn Read XML File", ActionSessionBehaviors.DoesNotUseBrowser, 30, ActionSideEffectKinds.ReadOnly, true,
            [Input("path", "String", true, "Normal", null, "Run-workspace relative file path.")],
            [Output("xml", "String", "Read xml value.")]);
        Add(result,
            "file.csv.write", "Write CSV", "Write CSV into the disposable run workspace.", "Files",
            "Dynomax BuiltIn Write CSV", ActionSessionBehaviors.DoesNotUseBrowser, 30, ActionSideEffectKinds.UpdatesData, false,
            [Input("path", "String", true, "Normal", null, "Run-workspace relative file path."), Input("rows", "Json", true, "Normal", null, "rows content."), Input("overwrite", "Boolean", false, "Normal", "true", "Allow replacement."), Input("delimiter", "String", false, "Normal", "\",\"", "CSV delimiter.")],
            [Output("fileReference", "FileReference", "Written file reference.")]);
        Add(result,
            "file.json.write", "Write JSON File", "Write JSON File into the disposable run workspace.", "Files",
            "Dynomax BuiltIn Write JSON File", ActionSessionBehaviors.DoesNotUseBrowser, 30, ActionSideEffectKinds.UpdatesData, false,
            [Input("path", "String", true, "Normal", null, "Run-workspace relative file path."), Input("json", "Json", true, "Normal", null, "json content."), Input("overwrite", "Boolean", false, "Normal", "true", "Allow replacement.")],
            [Output("fileReference", "FileReference", "Written file reference.")]);
        Add(result,
            "file.xml.write", "Write XML File", "Write XML File into the disposable run workspace.", "Files",
            "Dynomax BuiltIn Write XML File", ActionSessionBehaviors.DoesNotUseBrowser, 30, ActionSideEffectKinds.UpdatesData, false,
            [Input("path", "String", true, "Normal", null, "Run-workspace relative file path."), Input("xml", "String", true, "Normal", null, "xml content."), Input("overwrite", "Boolean", false, "Normal", "true", "Allow replacement.")],
            [Output("fileReference", "FileReference", "Written file reference.")]);
        Add(result,
            "data.json.serialize", "Serialize JSON", "Serialize structured data as bounded JSON text.", "Data",
            "Dynomax BuiltIn Serialize JSON", ActionSessionBehaviors.DoesNotUseBrowser, 30, ActionSideEffectKinds.None, true,
            [Input("value", "Json", true, "Normal", null, "JSON-compatible value.")],
            [Output("text", "String", "Serialized JSON text.")]);
        Add(result,
            "data.json.set-value", "Set JSON Value", "Set a value at a bounded JSON path.", "Data",
            "Dynomax BuiltIn Set JSON Value", ActionSessionBehaviors.DoesNotUseBrowser, 30, ActionSideEffectKinds.None, true,
            [Input("json", "Json", true, "Normal", null, "JSON object/array."), Input("path", "String", true, "Normal", null, "Bounded dot/bracket path."), Input("value", "Json", true, "Normal", null, "New JSON-compatible value.")],
            [Output("json", "Json", "Updated JSON.")]);
        Add(result,
            "data.json.merge", "Merge JSON", "Shallow-merge two JSON objects.", "Data",
            "Dynomax BuiltIn Merge JSON", ActionSessionBehaviors.DoesNotUseBrowser, 30, ActionSideEffectKinds.None, true,
            [Input("left", "Json", true, "Normal", null, "Base JSON object."), Input("right", "Json", true, "Normal", null, "Overlay JSON object.")],
            [Output("json", "Json", "Merged JSON object.")]);
        Add(result,
            "data.json.serialize", "Serialize JSON", "Serialize structured data as bounded JSON text while preserving runtime sensitivity.", "Data",
            "Dynomax BuiltIn Serialize JSON", ActionSessionBehaviors.DoesNotUseBrowser, 30, ActionSideEffectKinds.None, true,
            [Input("value", "Json", true, "Normal", null, "JSON-compatible value. Sensitive runtime NodeOutput is accepted and remains runtime-only.", NormalBindings, acceptSensitiveNodeOutput: true)],
            [Output("text", "String", "Serialized JSON text.", ActionOutputClassifications.Normal, true, ["value"])],
            contractVersion: 2,
            requiredCoreVersionOverride: "1.0.20");
        Add(result,
            "data.json.set-value", "Set JSON Value", "Set a value at a bounded JSON path while preserving runtime sensitivity.", "Data",
            "Dynomax BuiltIn Set JSON Value", ActionSessionBehaviors.DoesNotUseBrowser, 30, ActionSideEffectKinds.None, true,
            [Input("json", "Json", true, "Normal", null, "JSON object/array. Sensitive runtime NodeOutput is accepted and remains runtime-only.", NormalBindings, acceptSensitiveNodeOutput: true), Input("path", "String", true, "Normal", null, "Bounded dot/bracket path."), Input("value", "Json", true, "Normal", null, "New JSON-compatible value. Sensitive runtime NodeOutput is accepted and remains runtime-only.", NormalBindings, acceptSensitiveNodeOutput: true)],
            [Output("json", "Json", "Updated JSON.", ActionOutputClassifications.Normal, true, ["json", "value"])],
            contractVersion: 2,
            requiredCoreVersionOverride: "1.0.20");
        Add(result,
            "data.json.merge", "Merge JSON", "Shallow-merge two JSON objects while preserving runtime sensitivity.", "Data",
            "Dynomax BuiltIn Merge JSON", ActionSessionBehaviors.DoesNotUseBrowser, 30, ActionSideEffectKinds.None, true,
            [Input("left", "Json", true, "Normal", null, "Base JSON object. Sensitive runtime NodeOutput is accepted and remains runtime-only.", NormalBindings, acceptSensitiveNodeOutput: true), Input("right", "Json", true, "Normal", null, "Overlay JSON object. Sensitive runtime NodeOutput is accepted and remains runtime-only.", NormalBindings, acceptSensitiveNodeOutput: true)],
            [Output("json", "Json", "Merged JSON object.", ActionOutputClassifications.Normal, true, ["left", "right"])],
            contractVersion: 2,
            requiredCoreVersionOverride: "1.0.20");
        Add(result,
            "data.json.set-string", "Set JSON String", "Set a string value at a bounded JSON path while preserving runtime sensitivity.", "Data",
            "Dynomax BuiltIn Set JSON String", ActionSessionBehaviors.DoesNotUseBrowser, 30, ActionSideEffectKinds.None, true,
            [Input("json", "Json", true, "Normal", null, "JSON object/array. Sensitive runtime NodeOutput is accepted and remains runtime-only.", NormalBindings, acceptSensitiveNodeOutput: true), Input("path", "String", true, "Normal", null, "Bounded dot/bracket path."), Input("value", "String", true, "Normal", null, "String value. Sensitive runtime NodeOutput is accepted and remains runtime-only.", NormalBindings, acceptSensitiveNodeOutput: true)],
            [Output("json", "Json", "Updated JSON.", ActionOutputClassifications.Normal, true, ["json", "value"])],
            requiredCoreVersionOverride: "1.0.20");
        Add(result,
            "data.json.filter-array", "Filter JSON Array", "Filter a JSON array by a bounded path comparison.", "Data",
            "Dynomax BuiltIn Filter JSON Array", ActionSessionBehaviors.DoesNotUseBrowser, 30, ActionSideEffectKinds.None, true,
            [Input("array", "Json", true, "Normal", null, "JSON array."), Input("path", "String", true, "Normal", null, "Item path."), Input("operator", "String", false, "Normal", "\"Equals\"", "Equals, NotEquals or Contains."), Input("expected", "Json", true, "Normal", null, "Expected value.")],
            [Output("array", "Json", "Filtered array."), Output("count", "Integer", "Filtered item count.")]);
        Add(result,
            "data.xml.parse", "Parse XML", "Parse bounded XML into a structured JSON representation.", "Data",
            "Dynomax BuiltIn Parse XML", ActionSessionBehaviors.DoesNotUseBrowser, 30, ActionSideEffectKinds.None, true,
            [Input("xml", "String", true, "Normal", null, "XML text.")],
            [Output("json", "Json", "Structured XML representation.")]);
        Add(result,
            "data.xml.xpath", "XPath Query", "Run a bounded ElementTree XPath query and return text values.", "Data",
            "Dynomax BuiltIn XPath Query", ActionSessionBehaviors.DoesNotUseBrowser, 30, ActionSideEffectKinds.None, true,
            [Input("xml", "String", true, "Normal", null, "XML text."), Input("xpath", "String", true, "Normal", null, "ElementTree XPath expression.")],
            [Output("values", "Json", "Matching text values.")]);
        Add(result,
            "data.xml.to-json", "XML to JSON", "Convert bounded XML into a structured JSON representation.", "Data",
            "Dynomax BuiltIn XML to JSON", ActionSessionBehaviors.DoesNotUseBrowser, 30, ActionSideEffectKinds.None, true,
            [Input("xml", "String", true, "Normal", null, "XML text.")],
            [Output("json", "Json", "Structured JSON representation.")]);
        Add(result,
            "data.csv.to-json", "CSV to JSON", "Convert bounded CSV text into a JSON array of objects.", "Data",
            "Dynomax BuiltIn CSV to JSON", ActionSessionBehaviors.DoesNotUseBrowser, 30, ActionSideEffectKinds.None, true,
            [Input("csv", "String", true, "Normal", null, "CSV text."), Input("delimiter", "String", false, "Normal", "\",\"", "CSV delimiter.")],
            [Output("json", "Json", "JSON rows.")]);
        Add(result,
            "data.json.to-csv", "JSON to CSV", "Convert a bounded JSON array of objects into CSV text.", "Data",
            "Dynomax BuiltIn JSON to CSV", ActionSessionBehaviors.DoesNotUseBrowser, 30, ActionSideEffectKinds.None, true,
            [Input("json", "Json", true, "Normal", null, "JSON array of objects."), Input("delimiter", "String", false, "Normal", "\",\"", "CSV delimiter.")],
            [Output("csv", "String", "CSV text.")]);
        Add(result,
            "data.regex.extract", "Regex Extract", "Extract a bounded regex match/group from text.", "Data",
            "Dynomax BuiltIn Regex Extract", ActionSessionBehaviors.DoesNotUseBrowser, 30, ActionSideEffectKinds.None, true,
            [Input("value", "String", true, "Normal", null, "Input text."), Input("pattern", "String", true, "Normal", null, "Regular expression."), Input("group", "Integer", false, "Normal", "0", "Capture group index.")],
            [Output("value", "String", "Matched value or null."), Output("matched", "Boolean", "True when a match exists.")]);
        Add(result,
            "data.regex.extract", "Regex Extract", "Extract a bounded regex match/group while preserving runtime sensitivity from the source text.", "Data",
            "Dynomax BuiltIn Regex Extract", ActionSessionBehaviors.DoesNotUseBrowser, 30, ActionSideEffectKinds.None, true,
            [Input("value", "String", true, "Normal", null, "Input text. Sensitive runtime NodeOutput is accepted and remains runtime-only.", NormalBindings, acceptSensitiveNodeOutput: true), Input("pattern", "String", true, "Normal", null, "Regular expression."), Input("group", "Integer", false, "Normal", "0", "Capture group index.")],
            [Output("value", "String", "Matched value or null.", ActionOutputClassifications.Normal, true, ["value"]), Output("matched", "Boolean", "True when a match exists.")],
            contractVersion: 2,
            requiredCoreVersionOverride: "1.0.20");
        Add(result,
            "data.regex.replace", "Regex Replace", "Replace regex matches in text.", "Data",
            "Dynomax BuiltIn Regex Replace", ActionSessionBehaviors.DoesNotUseBrowser, 30, ActionSideEffectKinds.None, true,
            [Input("value", "String", true, "Normal", null, "Input text."), Input("pattern", "String", true, "Normal", null, "Regular expression."), Input("replacement", "String", false, "Normal", "\"\"", "Replacement text."), Input("count", "Integer", false, "Normal", "0", "Maximum replacements; 0 means all.")],
            [Output("value", "String", "Updated text.")]);
        Add(result,
            "data.string.replace", "String Replace", "Replace literal text occurrences.", "Data",
            "Dynomax BuiltIn String Replace", ActionSessionBehaviors.DoesNotUseBrowser, 30, ActionSideEffectKinds.None, true,
            [Input("value", "String", true, "Normal", null, "Input text."), Input("old", "String", true, "Normal", null, "Text to replace."), Input("new", "String", false, "Normal", "\"\"", "Replacement text."), Input("count", "Integer", false, "Normal", "-1", "Maximum replacements; -1 means all.")],
            [Output("value", "String", "Updated text.")]);
        Add(result,
            "data.string.split", "String Split", "Split text into a bounded JSON array.", "Data",
            "Dynomax BuiltIn String Split", ActionSessionBehaviors.DoesNotUseBrowser, 30, ActionSideEffectKinds.None, true,
            [Input("value", "String", true, "Normal", null, "Input text."), Input("separator", "String", true, "Normal", null, "Separator text."), Input("maxSplit", "Integer", false, "Normal", "-1", "Maximum split count.")],
            [Output("values", "Json", "Split values.")]);
        Add(result,
            "data.string.join", "String Join", "Join a JSON array using a separator.", "Data",
            "Dynomax BuiltIn String Join", ActionSessionBehaviors.DoesNotUseBrowser, 30, ActionSideEffectKinds.None, true,
            [Input("values", "Json", true, "Normal", null, "Values to join."), Input("separator", "String", false, "Normal", "\"\"", "Separator text.")],
            [Output("value", "String", "Joined text.")]);
        Add(result,
            "data.base64.encode", "Base64 Encode", "Base64-encode UTF-8 text.", "Data",
            "Dynomax BuiltIn Base64 Encode", ActionSessionBehaviors.DoesNotUseBrowser, 30, ActionSideEffectKinds.None, true,
            [Input("value", "String", true, "Normal", null, "Text to encode.")],
            [Output("value", "String", "Base64 value.")]);
        Add(result,
            "data.base64.decode", "Base64 Decode", "Decode Base64 into UTF-8 text.", "Data",
            "Dynomax BuiltIn Base64 Decode", ActionSessionBehaviors.DoesNotUseBrowser, 30, ActionSideEffectKinds.None, true,
            [Input("value", "String", true, "Normal", null, "Base64 value.")],
            [Output("value", "String", "Decoded text.")]);
        Add(result,
            "data.url.encode", "URL Encode", "Percent-encode text for a URL component.", "Data",
            "Dynomax BuiltIn URL Encode", ActionSessionBehaviors.DoesNotUseBrowser, 30, ActionSideEffectKinds.None, true,
            [Input("value", "String", true, "Normal", null, "Text to encode.")],
            [Output("value", "String", "Encoded text.")]);
        Add(result,
            "data.url.decode", "URL Decode", "Decode percent-encoded text.", "Data",
            "Dynomax BuiltIn URL Decode", ActionSessionBehaviors.DoesNotUseBrowser, 30, ActionSideEffectKinds.None, true,
            [Input("value", "String", true, "Normal", null, "Encoded text.")],
            [Output("value", "String", "Decoded text.")]);
        Add(result,
            "database.sql.query", "SQL Query", "Execute a provider-abstracted parameterized query and return bounded rows.", "Database",
            "Dynomax BuiltIn SQL Query", ActionSessionBehaviors.DoesNotUseBrowser, 3600, ActionSideEffectKinds.ReadOnly, true,
            [Input("connectionProfileJson", "String", true, "Secret", null, "Secret-reference JSON profile with providerInvariantName and connectionString."), Input("sql", "String", true, "Normal", null, "Query text."), Input("parameters", "Json", false, "Normal", "{}", "Named command parameters."), Input("maxRows", "Integer", false, "Normal", "1000", "Maximum rows."), Input("timeoutSeconds", "Integer", false, "Normal", "30", "Command timeout.")],
            [Output("rows", "Json", "Runtime-only query rows.", "SensitiveRedacted", false), Output("rowCount", "Integer", "Returned row count.")]);
        Add(result,
            "database.sql.execute", "SQL Execute", "Execute a provider-abstracted parameterized mutation command.", "Database",
            "Dynomax BuiltIn SQL Execute", ActionSessionBehaviors.DoesNotUseBrowser, 3600, ActionSideEffectKinds.UpdatesData, false,
            [Input("connectionProfileJson", "String", true, "Secret", null, "Secret-reference JSON profile with providerInvariantName and connectionString."), Input("sql", "String", true, "Normal", null, "Mutation/DDL command text."), Input("parameters", "Json", false, "Normal", "{}", "Named command parameters."), Input("timeoutSeconds", "Integer", false, "Normal", "30", "Command timeout.")],
            [Output("rowsAffected", "Integer", "Affected row count.")]);
        Add(result,
            "database.sql.scalar", "SQL Scalar", "Execute a provider-abstracted parameterized scalar query.", "Database",
            "Dynomax BuiltIn SQL Scalar", ActionSessionBehaviors.DoesNotUseBrowser, 3600, ActionSideEffectKinds.ReadOnly, true,
            [Input("connectionProfileJson", "String", true, "Secret", null, "Secret-reference JSON profile with providerInvariantName and connectionString."), Input("sql", "String", true, "Normal", null, "Scalar query text."), Input("parameters", "Json", false, "Normal", "{}", "Named command parameters."), Input("timeoutSeconds", "Integer", false, "Normal", "30", "Command timeout.")],
            [Output("value", "Json", "Runtime-only scalar value.", "SensitiveRedacted", false)]);
        Add(result,
            "database.sql.stored-procedure", "SQL Stored Procedure", "Execute a provider-abstracted stored procedure/function and return bounded rows.", "Database",
            "Dynomax BuiltIn SQL Stored Procedure", ActionSessionBehaviors.DoesNotUseBrowser, 3600, ActionSideEffectKinds.ExternalEffect, false,
            [Input("connectionProfileJson", "String", true, "Secret", null, "Secret-reference JSON profile with providerInvariantName and connectionString."), Input("procedure", "String", true, "Normal", null, "Stored procedure/function name."), Input("parameters", "Json", false, "Normal", "{}", "Named command parameters."), Input("maxRows", "Integer", false, "Normal", "1000", "Maximum returned rows."), Input("timeoutSeconds", "Integer", false, "Normal", "30", "Command timeout.")],
            [Output("rows", "Json", "Runtime-only returned rows.", "SensitiveRedacted", false), Output("rowCount", "Integer", "Returned row count.")]);
        Add(result,
            "workspace.records.query", "Workspace Records Query", "Query a bounded set of normal-classification durable records in the current Workspace or Environment.", "Workspace Data",
            "Dynomax BuiltIn Workspace Records Query", ActionSessionBehaviors.DoesNotUseBrowser, 120, ActionSideEffectKinds.ReadOnly, true,
            [Input("collection", "String", true, "Normal", null, "Durable collection name."), Input("scope", "String", false, "Normal", "\"Environment\"", "Environment or Workspace."), Input("key", "Json", false, "Normal", "null", "Optional exact structured-key JSON object filter."), Input("observedAfterUtc", "String", false, "Normal", "null", "Optional inclusive observation-time lower bound."), Input("observedBeforeUtc", "String", false, "Normal", "null", "Optional exclusive observation-time upper bound."), Input("maxAgeMinutes", "Integer", false, "Normal", "0", "Optional freshness window from current UTC time; 0 disables."), Input("maxRows", "Integer", false, "Normal", "100", "Maximum records, 1-500."), Input("includeExpired", "Boolean", false, "Normal", "false", "Include records whose expiry has passed.")],
            [Output("records", "Json", "Matching durable records."), Output("recordCount", "Integer", "Returned record count.")],
            requiredCoreVersionOverride: "1.0.20");
        Add(result,
            "workspace.records.query", "Workspace Records Query", "Query a bounded set of normal-classification durable records in the current Workspace or Environment.", "Workspace Data",
            "Dynomax BuiltIn Workspace Records Query", ActionSessionBehaviors.DoesNotUseBrowser, 120, ActionSideEffectKinds.ReadOnly, true,
            [Input("collection", "String", true, "Normal", null, "Durable collection name."), Input("scope", "String", false, "Normal", "\"Environment\"", "Environment or Workspace."), Input("key", "Json", false, "Normal", "null", "Optional exact structured-key JSON object filter."), Input("observedAfterUtc", "String", false, "Normal", "null", "Optional inclusive observation-time lower bound."), Input("observedBeforeUtc", "String", false, "Normal", "null", "Optional exclusive observation-time upper bound."), Input("maxAgeMinutes", "Integer", false, "Normal", "0", "Optional freshness window from current UTC time; 0 disables."), Input("maxRows", "Integer", false, "Normal", "100", "Maximum records, 1-500."), Input("includeExpired", "Boolean", false, "Normal", "false", "Include records whose expiry has passed.")],
            [Output("records", "Json", "Matching durable records."), Output("recordCount", "Integer", "Returned record count.")],
            contractVersion: 2,
            requiredCoreVersionOverride: "1.0.20");
        Add(result,
            "workspace.records.get", "Workspace Records Get", "Get one normal-classification durable record by stable key in the current Workspace or Environment.", "Workspace Data",
            "Dynomax BuiltIn Workspace Records Get", ActionSessionBehaviors.DoesNotUseBrowser, 120, ActionSideEffectKinds.ReadOnly, true,
            [Input("collection", "String", true, "Normal", null, "Durable collection name."), Input("scope", "String", false, "Normal", "\"Environment\"", "Environment or Workspace."), Input("recordKey", "String", true, "Normal", null, "Stable record key.")],
            [Output("found", "Boolean", "True when the keyed record exists and is not expired."), Output("record", "Json", "Durable record envelope or null.")],
            requiredCoreVersionOverride: "1.0.20");
        Add(result,
            "workspace.records.get", "Workspace Records Get", "Get one normal-classification durable record by stable key in the current Workspace or Environment.", "Workspace Data",
            "Dynomax BuiltIn Workspace Records Get", ActionSessionBehaviors.DoesNotUseBrowser, 120, ActionSideEffectKinds.ReadOnly, true,
            [Input("collection", "String", true, "Normal", null, "Durable collection name."), Input("scope", "String", false, "Normal", "\"Environment\"", "Environment or Workspace."), Input("recordKey", "String", true, "Normal", null, "Stable record key.")],
            [Output("found", "Boolean", "True when the keyed record exists and is not expired."), Output("record", "Json", "Durable record envelope or null.")],
            contractVersion: 2,
            requiredCoreVersionOverride: "1.0.20");
        Add(result,
            "workspace.records.append", "Workspace Records Append", "Append one immutable normal-classification durable observation to the current Workspace or Environment.", "Workspace Data",
            "Dynomax BuiltIn Workspace Records Append", ActionSessionBehaviors.DoesNotUseBrowser, 120, ActionSideEffectKinds.CreatesData, false,
            [Input("collection", "String", true, "Normal", null, "Durable collection name."), Input("scope", "String", false, "Normal", "\"Environment\"", "Environment or Workspace."), Input("key", "Json", false, "Normal", "null", "Optional structured lookup-key JSON object."), Input("record", "Json", true, "Normal", null, "Normal-classification JSON object to persist."), Input("appendIdempotencyKey", "String", false, "Normal", "null", "Optional idempotency key for retry-safe append."), Input("observedAtUtc", "String", false, "Normal", "null", "Observation timestamp; defaults to current UTC time."), Input("expiresAtUtc", "String", false, "Normal", "null", "Optional expiry timestamp.")],
            [Output("record", "Json", "Persisted durable record envelope."), Output("wasDuplicate", "Boolean", "True when an identical append idempotency key already existed.")],
            requiredCoreVersionOverride: "1.0.20");
        Add(result,
            "workspace.records.append", "Workspace Records Append", "Append one immutable normal-classification durable observation to the current Workspace or Environment.", "Workspace Data",
            "Dynomax BuiltIn Workspace Records Append", ActionSessionBehaviors.DoesNotUseBrowser, 120, ActionSideEffectKinds.CreatesData, false,
            [Input("collection", "String", true, "Normal", null, "Durable collection name."), Input("scope", "String", false, "Normal", "\"Environment\"", "Environment or Workspace."), Input("key", "Json", false, "Normal", "null", "Optional structured lookup-key JSON object."), Input("record", "Json", true, "Normal", null, "Normal-classification JSON object to persist."), Input("appendIdempotencyKey", "String", false, "Normal", "null", "Optional idempotency key for retry-safe append."), Input("observedAtUtc", "String", false, "Normal", "null", "Observation timestamp; defaults to current UTC time."), Input("expiresAtUtc", "String", false, "Normal", "null", "Optional expiry timestamp.")],
            [Output("record", "Json", "Persisted durable record envelope."), Output("wasDuplicate", "Boolean", "True when an identical append idempotency key already existed.")],
            contractVersion: 2,
            requiredCoreVersionOverride: "1.0.20");
        Add(result,
            "workspace.records.upsert", "Workspace Records Upsert", "Create or update one stable normal-classification durable record by key in the current Workspace or Environment.", "Workspace Data",
            "Dynomax BuiltIn Workspace Records Upsert", ActionSessionBehaviors.DoesNotUseBrowser, 120, ActionSideEffectKinds.UpdatesData, true,
            [Input("collection", "String", true, "Normal", null, "Durable collection name."), Input("scope", "String", false, "Normal", "\"Environment\"", "Environment or Workspace."), Input("recordKey", "String", true, "Normal", null, "Stable record key."), Input("key", "Json", false, "Normal", "null", "Optional structured lookup-key JSON object."), Input("record", "Json", true, "Normal", null, "Normal-classification JSON object to persist."), Input("expectedVersion", "Integer", false, "Normal", "-1", "Optimistic version: -1 ignores, 0 requires absence, positive requires exact version."), Input("expiresAtUtc", "String", false, "Normal", "null", "Optional expiry timestamp.")],
            [Output("record", "Json", "Persisted durable record envelope."), Output("created", "Boolean", "True when a new stable record was created."), Output("changed", "Boolean", "True when persisted content changed.")],
            requiredCoreVersionOverride: "1.0.20");
        Add(result,
            "workspace.records.upsert", "Workspace Records Upsert", "Create or update one stable normal-classification durable record by key in the current Workspace or Environment.", "Workspace Data",
            "Dynomax BuiltIn Workspace Records Upsert", ActionSessionBehaviors.DoesNotUseBrowser, 120, ActionSideEffectKinds.UpdatesData, true,
            [Input("collection", "String", true, "Normal", null, "Durable collection name."), Input("scope", "String", false, "Normal", "\"Environment\"", "Environment or Workspace."), Input("recordKey", "String", true, "Normal", null, "Stable record key."), Input("key", "Json", false, "Normal", "null", "Optional structured lookup-key JSON object."), Input("record", "Json", true, "Normal", null, "Normal-classification JSON object to persist."), Input("expectedVersion", "Integer", false, "Normal", "-1", "Optimistic version: -1 ignores, 0 requires absence, positive requires exact version."), Input("expiresAtUtc", "String", false, "Normal", "null", "Optional expiry timestamp.")],
            [Output("record", "Json", "Persisted durable record envelope."), Output("created", "Boolean", "True when a new stable record was created."), Output("changed", "Boolean", "True when persisted content changed.")],
            contractVersion: 2,
            requiredCoreVersionOverride: "1.0.20");
        Add(result,
            "workspace.records.get-many", "Workspace Records Get Many", "Get a bounded ordered set of normal-classification durable records by stable keys in the current Workspace or Environment.", "Workspace Data",
            "Dynomax BuiltIn Workspace Records Get Many", ActionSessionBehaviors.DoesNotUseBrowser, 300, ActionSideEffectKinds.ReadOnly, true,
            [Input("collection", "String", true, "Normal", null, "Durable collection name."), Input("scope", "String", false, "Normal", "\"Environment\"", "Environment or Workspace."), Input("recordKeys", "Json", true, "Normal", null, "JSON array of 0-500 unique stable record keys."), Input("includeExpired", "Boolean", false, "Normal", "false", "Include keyed records whose expiry has passed.")],
            [Output("results", "Json", "Ordered entries containing recordKey, found and record."), Output("recordCount", "Integer", "Requested/result entry count."), Output("foundCount", "Integer", "Number of keys with a returned durable record.")],
            requiredCoreVersionOverride: "1.0.20");
        Add(result,
            "workspace.records.get-many", "Workspace Records Get Many", "Get a bounded ordered set of normal-classification durable records by stable keys in the current Workspace or Environment.", "Workspace Data",
            "Dynomax BuiltIn Workspace Records Get Many", ActionSessionBehaviors.DoesNotUseBrowser, 300, ActionSideEffectKinds.ReadOnly, true,
            [Input("collection", "String", true, "Normal", null, "Durable collection name."), Input("scope", "String", false, "Normal", "\"Environment\"", "Environment or Workspace."), Input("recordKeys", "Json", true, "Normal", null, "JSON array of 0-500 unique stable record keys."), Input("includeExpired", "Boolean", false, "Normal", "false", "Include keyed records whose expiry has passed.")],
            [Output("results", "Json", "Ordered entries containing recordKey, found and record."), Output("recordCount", "Integer", "Requested/result entry count."), Output("foundCount", "Integer", "Number of keys with a returned durable record.")],
            contractVersion: 2,
            requiredCoreVersionOverride: "1.0.20");
        Add(result,
            "workspace.records.append-many", "Workspace Records Append Many", "Atomically append a bounded batch of immutable normal-classification durable observations to the current Workspace or Environment.", "Workspace Data",
            "Dynomax BuiltIn Workspace Records Append Many", ActionSessionBehaviors.DoesNotUseBrowser, 300, ActionSideEffectKinds.CreatesData, false,
            [Input("collection", "String", true, "Normal", null, "Durable collection name."), Input("scope", "String", false, "Normal", "\"Environment\"", "Environment or Workspace."), Input("records", "Json", true, "Normal", null, "JSON array of 0-500 append items. Each item contains record and may contain key, appendIdempotencyKey, observedAtUtc and expiresAtUtc. Total payload is bounded to 1 MiB.")],
            [Output("results", "Json", "Ordered persisted record envelopes with per-item wasDuplicate state."), Output("recordCount", "Integer", "Persisted/result entry count."), Output("duplicateCount", "Integer", "Number of idempotent duplicate items returned without creating a new row.")],
            requiredCoreVersionOverride: "1.0.20");
        Add(result,
            "workspace.records.append-many", "Workspace Records Append Many", "Atomically append a bounded batch of immutable normal-classification durable observations to the current Workspace or Environment.", "Workspace Data",
            "Dynomax BuiltIn Workspace Records Append Many", ActionSessionBehaviors.DoesNotUseBrowser, 300, ActionSideEffectKinds.CreatesData, false,
            [Input("collection", "String", true, "Normal", null, "Durable collection name."), Input("scope", "String", false, "Normal", "\"Environment\"", "Environment or Workspace."), Input("records", "Json", true, "Normal", null, "JSON array of 0-500 append items. Each item contains record and may contain key, appendIdempotencyKey, observedAtUtc and expiresAtUtc. Total payload is bounded to 1 MiB.")],
            [Output("results", "Json", "Ordered persisted record envelopes with per-item wasDuplicate state."), Output("recordCount", "Integer", "Persisted/result entry count."), Output("duplicateCount", "Integer", "Number of idempotent duplicate items returned without creating a new row.")],
            contractVersion: 2,
            requiredCoreVersionOverride: "1.0.20");
        Add(result,
            "workspace.records.upsert-many", "Workspace Records Upsert Many", "Atomically create or update a bounded batch of stable normal-classification durable records by key in the current Workspace or Environment.", "Workspace Data",
            "Dynomax BuiltIn Workspace Records Upsert Many", ActionSessionBehaviors.DoesNotUseBrowser, 300, ActionSideEffectKinds.UpdatesData, true,
            [Input("collection", "String", true, "Normal", null, "Durable collection name."), Input("scope", "String", false, "Normal", "\"Environment\"", "Environment or Workspace."), Input("records", "Json", true, "Normal", null, "JSON array of 0-500 unique stable-key upsert items. Each item contains recordKey and record and may contain key, expectedVersion and expiresAtUtc. Total payload is bounded to 1 MiB.")],
            [Output("results", "Json", "Ordered persisted record envelopes with per-item created and changed state."), Output("recordCount", "Integer", "Persisted/result entry count."), Output("createdCount", "Integer", "Number of newly created stable records."), Output("changedCount", "Integer", "Number of created or updated stable records whose persisted content changed.")],
            requiredCoreVersionOverride: "1.0.20");
        Add(result,
            "workspace.records.upsert-many", "Workspace Records Upsert Many", "Atomically create or update a bounded batch of stable normal-classification durable records by key in the current Workspace or Environment.", "Workspace Data",
            "Dynomax BuiltIn Workspace Records Upsert Many", ActionSessionBehaviors.DoesNotUseBrowser, 300, ActionSideEffectKinds.UpdatesData, true,
            [Input("collection", "String", true, "Normal", null, "Durable collection name."), Input("scope", "String", false, "Normal", "\"Environment\"", "Environment or Workspace."), Input("records", "Json", true, "Normal", null, "JSON array of 0-500 unique stable-key upsert items. Each item contains recordKey and record and may contain key, expectedVersion and expiresAtUtc. Total payload is bounded to 1 MiB.")],
            [Output("results", "Json", "Ordered persisted record envelopes with per-item created and changed state."), Output("recordCount", "Integer", "Persisted/result entry count."), Output("createdCount", "Integer", "Number of newly created stable records."), Output("changedCount", "Integer", "Number of created or updated stable records whose persisted content changed.")],
            contractVersion: 2,
            requiredCoreVersionOverride: "1.0.20");
        Add(result,
            "email.smtp.send", "SMTP Send Email", "Send an email using a secret-reference SMTP profile.", "Email",
            "Dynomax BuiltIn SMTP Send Email", ActionSessionBehaviors.DoesNotUseBrowser, 300, ActionSideEffectKinds.ExternalEffect, false,
            [Input("connectionProfileJson", "String", true, "Secret", null, "Secret-reference SMTP/IMAP connection profile JSON."), Input("from", "String", false, "Normal", "null", "Sender address; defaults to profile sender/username."), Input("to", "String", true, "Normal", null, "Comma-separated or JSON-array recipients."), Input("subject", "String", false, "Normal", "\"\"", "Subject."), Input("body", "String", false, "Normal", "\"\"", "Plain-text body.")],
            [Output("messageId", "String", "Message identifier where supplied.")]);
        Add(result,
            "email.smtp.send-attachment", "SMTP Send Email with Attachment", "Send an email with run-workspace attachments using a secret-reference SMTP profile.", "Email",
            "Dynomax BuiltIn SMTP Send Email with Attachment", ActionSessionBehaviors.DoesNotUseBrowser, 300, ActionSideEffectKinds.ExternalEffect, false,
            [Input("connectionProfileJson", "String", true, "Secret", null, "Secret-reference SMTP/IMAP connection profile JSON."), Input("from", "String", false, "Normal", "null", "Sender address."), Input("to", "String", true, "Normal", null, "Recipients."), Input("subject", "String", false, "Normal", "\"\"", "Subject."), Input("body", "String", false, "Normal", "\"\"", "Plain-text body."), Input("attachments", "Json", true, "Normal", null, "JSON array of run-workspace file references.")],
            [Output("messageId", "String", "Message identifier where supplied.")]);
        Add(result,
            "email.imap.read", "IMAP Read Emails", "Read bounded messages using a secret-reference IMAP profile.", "Email",
            "Dynomax BuiltIn IMAP Read Emails", ActionSessionBehaviors.DoesNotUseBrowser, 300, ActionSideEffectKinds.ReadOnly, true,
            [Input("connectionProfileJson", "String", true, "Secret", null, "Secret-reference SMTP/IMAP connection profile JSON."), Input("folder", "String", false, "Normal", "\"INBOX\"", "Mailbox folder."), Input("criteria", "String", false, "Normal", "\"ALL\"", "IMAP search criteria."), Input("limit", "Integer", false, "Normal", "20", "Maximum messages."), Input("includeBody", "Boolean", false, "Normal", "true", "Include bounded plain-text body.")],
            [Output("messages", "Json", "Runtime-only message data.", "SensitiveRedacted", false), Output("count", "Integer", "Message count.")]);
        Add(result,
            "email.imap.read", "IMAP Read Emails", "Read bounded messages using split non-secret connection fields plus a secret-reference password.", "Email",
            "Dynomax BuiltIn IMAP Read Emails", ActionSessionBehaviors.DoesNotUseBrowser, 300, ActionSideEffectKinds.ReadOnly, true,
            [Input("host", "String", true, "Normal", null, "IMAP server host."), Input("port", "Integer", false, "Normal", "993", "IMAP server port."), Input("security", "String", false, "Normal", "\"ssl\"", "Connection security: ssl or starttls."), Input("username", "String", true, "Normal", null, "Mailbox username; this value is not treated as a secret."), Input("password", "String", true, "Secret", null, "Mailbox password supplied only by SecretReference."), Input("timeoutSeconds", "Integer", false, "Normal", "30", "Connection timeout in seconds."), Input("folder", "String", false, "Normal", "\"INBOX\"", "Mailbox folder."), Input("criteria", "String", false, "Normal", "\"ALL\"", "IMAP search criteria such as UNSEEN."), Input("limit", "Integer", false, "Normal", "20", "Maximum messages."), Input("includeBody", "Boolean", false, "Normal", "true", "Include bounded plain-text body.")],
            [Output("messages", "Json", "Runtime-only message data.", "SensitiveRedacted", false), Output("count", "Integer", "Message count.")],
            contractVersion: 2,
            requiredCoreVersionOverride: "1.0.20");
        Add(result,
            "email.imap.find", "IMAP Find Email", "Search bounded messages using IMAP criteria.", "Email",
            "Dynomax BuiltIn IMAP Find Email", ActionSessionBehaviors.DoesNotUseBrowser, 300, ActionSideEffectKinds.ReadOnly, true,
            [Input("connectionProfileJson", "String", true, "Secret", null, "Secret-reference SMTP/IMAP connection profile JSON."), Input("folder", "String", false, "Normal", "\"INBOX\"", "Mailbox folder."), Input("criteria", "String", true, "Normal", null, "IMAP search criteria."), Input("limit", "Integer", false, "Normal", "20", "Maximum messages."), Input("includeBody", "Boolean", false, "Normal", "true", "Include body.")],
            [Output("messages", "Json", "Runtime-only message data.", "SensitiveRedacted", false), Output("count", "Integer", "Message count.")]);
        Add(result,
            "email.imap.find", "IMAP Find Email", "Search bounded messages using split non-secret connection fields plus a secret-reference password.", "Email",
            "Dynomax BuiltIn IMAP Find Email", ActionSessionBehaviors.DoesNotUseBrowser, 300, ActionSideEffectKinds.ReadOnly, true,
            [Input("host", "String", true, "Normal", null, "IMAP server host."), Input("port", "Integer", false, "Normal", "993", "IMAP server port."), Input("security", "String", false, "Normal", "\"ssl\"", "Connection security: ssl or starttls."), Input("username", "String", true, "Normal", null, "Mailbox username; this value is not treated as a secret."), Input("password", "String", true, "Secret", null, "Mailbox password supplied only by SecretReference."), Input("timeoutSeconds", "Integer", false, "Normal", "30", "Connection timeout in seconds."), Input("folder", "String", false, "Normal", "\"INBOX\"", "Mailbox folder."), Input("criteria", "String", true, "Normal", null, "IMAP search criteria."), Input("limit", "Integer", false, "Normal", "20", "Maximum messages."), Input("includeBody", "Boolean", false, "Normal", "true", "Include body.")],
            [Output("messages", "Json", "Runtime-only message data.", "SensitiveRedacted", false), Output("count", "Integer", "Message count.")],
            contractVersion: 2,
            requiredCoreVersionOverride: "1.0.20");
        Add(result,
            "email.imap.latest", "IMAP Read Latest Email", "Return the newest matching email.", "Email",
            "Dynomax BuiltIn IMAP Read Latest Email", ActionSessionBehaviors.DoesNotUseBrowser, 300, ActionSideEffectKinds.ReadOnly, true,
            [Input("connectionProfileJson", "String", true, "Secret", null, "Secret-reference SMTP/IMAP connection profile JSON."), Input("folder", "String", false, "Normal", "\"INBOX\"", "Mailbox folder."), Input("criteria", "String", false, "Normal", "\"ALL\"", "IMAP search criteria."), Input("includeBody", "Boolean", false, "Normal", "true", "Include body.")],
            [Output("message", "Json", "Runtime-only newest message.", "SensitiveRedacted", false)]);
        Add(result,
            "email.imap.latest", "IMAP Read Latest Email", "Return the newest matching email using split non-secret connection fields plus a secret-reference password.", "Email",
            "Dynomax BuiltIn IMAP Read Latest Email", ActionSessionBehaviors.DoesNotUseBrowser, 300, ActionSideEffectKinds.ReadOnly, true,
            [Input("host", "String", true, "Normal", null, "IMAP server host."), Input("port", "Integer", false, "Normal", "993", "IMAP server port."), Input("security", "String", false, "Normal", "\"ssl\"", "Connection security: ssl or starttls."), Input("username", "String", true, "Normal", null, "Mailbox username; this value is not treated as a secret."), Input("password", "String", true, "Secret", null, "Mailbox password supplied only by SecretReference."), Input("timeoutSeconds", "Integer", false, "Normal", "30", "Connection timeout in seconds."), Input("folder", "String", false, "Normal", "\"INBOX\"", "Mailbox folder."), Input("criteria", "String", false, "Normal", "\"ALL\"", "IMAP search criteria."), Input("includeBody", "Boolean", false, "Normal", "true", "Include body.")],
            [Output("message", "Json", "Runtime-only newest message.", "SensitiveRedacted", false)],
            contractVersion: 2,
            requiredCoreVersionOverride: "1.0.20");
        Add(result,
            "email.imap.latest", "IMAP Read Latest Email", "Return the newest matching email; fail deterministically when no message matches.", "Email",
            "Dynomax BuiltIn IMAP Read Latest Email", ActionSessionBehaviors.DoesNotUseBrowser, 300, ActionSideEffectKinds.ReadOnly, true,
            [Input("host", "String", true, "Normal", null, "IMAP server host."), Input("port", "Integer", false, "Normal", "993", "IMAP server port."), Input("security", "String", false, "Normal", "\"ssl\"", "Connection security: ssl or starttls."), Input("username", "String", true, "Normal", null, "Mailbox username; this value is not treated as a secret."), Input("password", "String", true, "Secret", null, "Mailbox password supplied only by SecretReference."), Input("timeoutSeconds", "Integer", false, "Normal", "30", "Connection timeout in seconds."), Input("folder", "String", false, "Normal", "\"INBOX\"", "Mailbox folder."), Input("criteria", "String", false, "Normal", "\"ALL\"", "IMAP search criteria."), Input("includeBody", "Boolean", false, "Normal", "true", "Include body.")],
            [Output("message", "Json", "Runtime-only newest message.", "SensitiveRedacted", false)],
            contractVersion: 3,
            requiredCoreVersionOverride: "1.0.20");
        Add(result,
            "email.imap.download-attachments", "IMAP Download Attachments", "Download bounded attachments into the disposable run workspace.", "Email",
            "Dynomax BuiltIn IMAP Download Attachments", ActionSessionBehaviors.DoesNotUseBrowser, 300, ActionSideEffectKinds.ReadOnly, true,
            [Input("connectionProfileJson", "String", true, "Secret", null, "Secret-reference SMTP/IMAP connection profile JSON."), Input("folder", "String", false, "Normal", "\"INBOX\"", "Mailbox folder."), Input("messageId", "String", true, "Normal", null, "IMAP UID/message id."), Input("destinationDirectory", "String", false, "Normal", "null", "Run-workspace destination directory.")],
            [Output("attachments", "Json", "Downloaded run-workspace file references.")]);
        Add(result,
            "email.imap.download-attachments", "IMAP Download Attachments", "Download bounded attachments using split non-secret connection fields plus a secret-reference password.", "Email",
            "Dynomax BuiltIn IMAP Download Attachments", ActionSessionBehaviors.DoesNotUseBrowser, 300, ActionSideEffectKinds.ReadOnly, true,
            [Input("host", "String", true, "Normal", null, "IMAP server host."), Input("port", "Integer", false, "Normal", "993", "IMAP server port."), Input("security", "String", false, "Normal", "\"ssl\"", "Connection security: ssl or starttls."), Input("username", "String", true, "Normal", null, "Mailbox username; this value is not treated as a secret."), Input("password", "String", true, "Secret", null, "Mailbox password supplied only by SecretReference."), Input("timeoutSeconds", "Integer", false, "Normal", "30", "Connection timeout in seconds."), Input("folder", "String", false, "Normal", "\"INBOX\"", "Mailbox folder."), Input("messageId", "String", true, "Normal", null, "IMAP UID/message id. Sensitive runtime NodeOutput is accepted as an explicit mailbox-operation identifier sink.", NormalBindings, acceptSensitiveNodeOutput: true), Input("destinationDirectory", "String", false, "Normal", "null", "Run-workspace destination directory.")],
            [Output("attachments", "Json", "Run-workspace file references.")],
            contractVersion: 2,
            requiredCoreVersionOverride: "1.0.20");
        Add(result,
            "email.imap.mark-read", "IMAP Mark Read / Unread", "Change an email read state.", "Email",
            "Dynomax BuiltIn IMAP Mark Read / Unread", ActionSessionBehaviors.DoesNotUseBrowser, 300, ActionSideEffectKinds.UpdatesData, false,
            [Input("connectionProfileJson", "String", true, "Secret", null, "Secret-reference SMTP/IMAP connection profile JSON."), Input("folder", "String", false, "Normal", "\"INBOX\"", "Mailbox folder."), Input("messageId", "String", true, "Normal", null, "IMAP UID/message id."), Input("read", "Boolean", false, "Normal", "true", "True to mark read; false unread.")],
            [Output("updated", "Boolean", "True when update succeeds.")]);
        Add(result,
            "email.imap.mark-read", "IMAP Mark Read / Unread", "Change an email read state using split non-secret connection fields plus a secret-reference password.", "Email",
            "Dynomax BuiltIn IMAP Mark Read / Unread", ActionSessionBehaviors.DoesNotUseBrowser, 300, ActionSideEffectKinds.UpdatesData, false,
            [Input("host", "String", true, "Normal", null, "IMAP server host."), Input("port", "Integer", false, "Normal", "993", "IMAP server port."), Input("security", "String", false, "Normal", "\"ssl\"", "Connection security: ssl or starttls."), Input("username", "String", true, "Normal", null, "Mailbox username; this value is not treated as a secret."), Input("password", "String", true, "Secret", null, "Mailbox password supplied only by SecretReference."), Input("timeoutSeconds", "Integer", false, "Normal", "30", "Connection timeout in seconds."), Input("folder", "String", false, "Normal", "\"INBOX\"", "Mailbox folder."), Input("messageId", "String", true, "Normal", null, "IMAP UID/message id. Sensitive runtime NodeOutput is accepted as an explicit mailbox-operation identifier sink.", NormalBindings, acceptSensitiveNodeOutput: true), Input("read", "Boolean", false, "Normal", "true", "True to mark read; false unread.")],
            [Output("updated", "Boolean", "True when the flag update succeeds.")],
            contractVersion: 2,
            requiredCoreVersionOverride: "1.0.20");
        Add(result,
            "email.imap.move", "IMAP Move Email", "Move an email to another mailbox/folder.", "Email",
            "Dynomax BuiltIn IMAP Move Email", ActionSessionBehaviors.DoesNotUseBrowser, 300, ActionSideEffectKinds.UpdatesData, false,
            [Input("connectionProfileJson", "String", true, "Secret", null, "Secret-reference SMTP/IMAP connection profile JSON."), Input("folder", "String", false, "Normal", "\"INBOX\"", "Source mailbox folder."), Input("messageId", "String", true, "Normal", null, "IMAP UID/message id."), Input("destinationFolder", "String", true, "Normal", null, "Destination mailbox folder.")],
            [Output("moved", "Boolean", "True when move succeeds.")]);
        Add(result,
            "email.imap.move", "IMAP Move Email", "Move an email using split non-secret connection fields plus a secret-reference password.", "Email",
            "Dynomax BuiltIn IMAP Move Email", ActionSessionBehaviors.DoesNotUseBrowser, 300, ActionSideEffectKinds.UpdatesData, false,
            [Input("host", "String", true, "Normal", null, "IMAP server host."), Input("port", "Integer", false, "Normal", "993", "IMAP server port."), Input("security", "String", false, "Normal", "\"ssl\"", "Connection security: ssl or starttls."), Input("username", "String", true, "Normal", null, "Mailbox username; this value is not treated as a secret."), Input("password", "String", true, "Secret", null, "Mailbox password supplied only by SecretReference."), Input("timeoutSeconds", "Integer", false, "Normal", "30", "Connection timeout in seconds."), Input("folder", "String", false, "Normal", "\"INBOX\"", "Source mailbox folder."), Input("messageId", "String", true, "Normal", null, "IMAP UID/message id. Sensitive runtime NodeOutput is accepted as an explicit mailbox-operation identifier sink.", NormalBindings, acceptSensitiveNodeOutput: true), Input("destinationFolder", "String", true, "Normal", null, "Destination mailbox folder.")],
            [Output("moved", "Boolean", "True when the move succeeds.")],
            contractVersion: 2,
            requiredCoreVersionOverride: "1.0.20");
        Add(result,
            "email.imap.delete", "IMAP Delete Email", "Delete/expunge an email.", "Email",
            "Dynomax BuiltIn IMAP Delete Email", ActionSessionBehaviors.DoesNotUseBrowser, 300, ActionSideEffectKinds.DeletesData, false,
            [Input("connectionProfileJson", "String", true, "Secret", null, "Secret-reference SMTP/IMAP connection profile JSON."), Input("folder", "String", false, "Normal", "\"INBOX\"", "Mailbox folder."), Input("messageId", "String", true, "Normal", null, "IMAP UID/message id.")],
            [Output("deleted", "Boolean", "True when deletion succeeds.")]);
        Add(result,
            "email.imap.delete", "IMAP Delete Email", "Delete/expunge an email using split non-secret connection fields plus a secret-reference password.", "Email",
            "Dynomax BuiltIn IMAP Delete Email", ActionSessionBehaviors.DoesNotUseBrowser, 300, ActionSideEffectKinds.DeletesData, false,
            [Input("host", "String", true, "Normal", null, "IMAP server host."), Input("port", "Integer", false, "Normal", "993", "IMAP server port."), Input("security", "String", false, "Normal", "\"ssl\"", "Connection security: ssl or starttls."), Input("username", "String", true, "Normal", null, "Mailbox username; this value is not treated as a secret."), Input("password", "String", true, "Secret", null, "Mailbox password supplied only by SecretReference."), Input("timeoutSeconds", "Integer", false, "Normal", "30", "Connection timeout in seconds."), Input("folder", "String", false, "Normal", "\"INBOX\"", "Mailbox folder."), Input("messageId", "String", true, "Normal", null, "IMAP UID/message id. Sensitive runtime NodeOutput is accepted as an explicit mailbox-operation identifier sink.", NormalBindings, acceptSensitiveNodeOutput: true)],
            [Output("deleted", "Boolean", "True when deletion succeeds.")],
            contractVersion: 2,
            requiredCoreVersionOverride: "1.0.20");
        Add(result,
            "process.run", "Run Process", "Execute an explicitly allow-listed executable without a shell.", "Scripting",
            "Dynomax BuiltIn Run Process", ActionSessionBehaviors.DoesNotUseBrowser, 3600, ActionSideEffectKinds.ExternalEffect, false,
            [Input("executable", "String", true, "Normal", null, "Exact allow-listed executable path/name."), Input("stdin", "String", false, "Normal", "null", "Optional standard input."), Input("arguments", "Json", false, "Normal", "[]", "Argument array."), Input("workingDirectory", "String", false, "Normal", "\".\"", "Run-workspace relative working directory."), Input("environment", "Json", false, "Normal", "{}", "Allow-listed normal environment values."), Input("secretEnvironmentJson", "String", false, "Secret", null, "Optional secret-reference JSON environment values."), Input("timeoutSeconds", "Integer", false, "Normal", "60", "Process timeout."), Input("allowNonZeroExit", "Boolean", false, "Normal", "false", "Allow a nonzero exit code without failing the Action.")],
            [Output("exitCode", "Integer", "Process exit code."), Output("stdout", "String", "Runtime-only bounded stdout.", "SensitiveRedacted", false), Output("stderr", "String", "Runtime-only bounded stderr.", "SensitiveRedacted", false)]);
        Add(result,
            "command.run", "Run Command", "Execute an explicitly allow-listed command executable and argument array without shell interpretation.", "Scripting",
            "Dynomax BuiltIn Run Command", ActionSessionBehaviors.DoesNotUseBrowser, 3600, ActionSideEffectKinds.ExternalEffect, false,
            [Input("executable", "String", true, "Normal", null, "Exact allow-listed executable path/name."), Input("stdin", "String", false, "Normal", "null", "Optional standard input."), Input("arguments", "Json", false, "Normal", "[]", "Argument array."), Input("workingDirectory", "String", false, "Normal", "\".\"", "Run-workspace relative working directory."), Input("environment", "Json", false, "Normal", "{}", "Allow-listed normal environment values."), Input("secretEnvironmentJson", "String", false, "Secret", null, "Optional secret-reference JSON environment values."), Input("timeoutSeconds", "Integer", false, "Normal", "60", "Process timeout."), Input("allowNonZeroExit", "Boolean", false, "Normal", "false", "Allow a nonzero exit code without failing the Action.")],
            [Output("exitCode", "Integer", "Process exit code."), Output("stdout", "String", "Runtime-only bounded stdout.", "SensitiveRedacted", false), Output("stderr", "String", "Runtime-only bounded stderr.", "SensitiveRedacted", false)]);
        Add(result,
            "powershell.run", "Run PowerShell", "Execute PowerShell code only when Built-in process execution is explicitly enabled by Worker policy.", "Scripting",
            "Dynomax BuiltIn Run PowerShell", ActionSessionBehaviors.DoesNotUseBrowser, 3600, ActionSideEffectKinds.ExternalEffect, false,
            [Input("script", "String", true, "Normal", null, "PowerShell script text."), Input("arguments", "Json", false, "Normal", "[]", "Argument array."), Input("workingDirectory", "String", false, "Normal", "\".\"", "Run-workspace relative working directory."), Input("environment", "Json", false, "Normal", "{}", "Allow-listed normal environment values."), Input("secretEnvironmentJson", "String", false, "Secret", null, "Optional secret-reference JSON environment values."), Input("timeoutSeconds", "Integer", false, "Normal", "60", "Process timeout."), Input("allowNonZeroExit", "Boolean", false, "Normal", "false", "Allow a nonzero exit code without failing the Action.")],
            [Output("exitCode", "Integer", "Process exit code."), Output("stdout", "String", "Runtime-only bounded stdout.", "SensitiveRedacted", false), Output("stderr", "String", "Runtime-only bounded stderr.", "SensitiveRedacted", false)]);
        Add(result,
            "python.run", "Run Python", "Execute Python code only when Built-in process execution is explicitly enabled by Worker policy.", "Scripting",
            "Dynomax BuiltIn Run Python", ActionSessionBehaviors.DoesNotUseBrowser, 3600, ActionSideEffectKinds.ExternalEffect, false,
            [Input("script", "String", true, "Normal", null, "Python script text."), Input("arguments", "Json", false, "Normal", "[]", "Argument array."), Input("workingDirectory", "String", false, "Normal", "\".\"", "Run-workspace relative working directory."), Input("environment", "Json", false, "Normal", "{}", "Allow-listed normal environment values."), Input("secretEnvironmentJson", "String", false, "Secret", null, "Optional secret-reference JSON environment values."), Input("timeoutSeconds", "Integer", false, "Normal", "60", "Process timeout."), Input("allowNonZeroExit", "Boolean", false, "Normal", "false", "Allow a nonzero exit code without failing the Action.")],
            [Output("exitCode", "Integer", "Process exit code."), Output("stdout", "String", "Runtime-only bounded stdout.", "SensitiveRedacted", false), Output("stderr", "String", "Runtime-only bounded stderr.", "SensitiveRedacted", false)]);
        Add(result,
            "dotnet.run", "Run .NET Application", "Execute a .NET application from the disposable run workspace only when process execution is enabled.", "Scripting",
            "Dynomax BuiltIn Run .NET Application", ActionSessionBehaviors.DoesNotUseBrowser, 3600, ActionSideEffectKinds.ExternalEffect, false,
            [Input("applicationPath", "FileReference", true, "Normal", null, "Run-workspace relative .NET application path."), Input("arguments", "Json", false, "Normal", "[]", "Argument array."), Input("workingDirectory", "String", false, "Normal", "\".\"", "Run-workspace relative working directory."), Input("environment", "Json", false, "Normal", "{}", "Allow-listed normal environment values."), Input("secretEnvironmentJson", "String", false, "Secret", null, "Optional secret-reference JSON environment values."), Input("timeoutSeconds", "Integer", false, "Normal", "60", "Process timeout."), Input("allowNonZeroExit", "Boolean", false, "Normal", "false", "Allow a nonzero exit code without failing the Action.")],
            [Output("exitCode", "Integer", "Process exit code."), Output("stdout", "String", "Runtime-only bounded stdout.", "SensitiveRedacted", false), Output("stderr", "String", "Runtime-only bounded stderr.", "SensitiveRedacted", false)]);
        Add(result,
            "datetime.current", "Current Date/Time", "Return current date/time in an explicit timezone.", "Date & Time",
            "Dynomax BuiltIn Current Date/Time", ActionSessionBehaviors.DoesNotUseBrowser, 30, ActionSideEffectKinds.None, false,
            [Input("timeZone", "String", false, "Normal", "\"UTC\"", "IANA timezone name.")],
            [Output("dateTime", "String", "ISO-8601 date/time.")]);
        Add(result,
            "datetime.format", "Format Date/Time", "Format an ISO date/time with an explicit format.", "Date & Time",
            "Dynomax BuiltIn Format Date/Time", ActionSessionBehaviors.DoesNotUseBrowser, 30, ActionSideEffectKinds.None, true,
            [Input("dateTime", "String", true, "Normal", null, "ISO-8601 date/time."), Input("sourceTimeZone", "String", false, "Normal", "\"UTC\"", "Timezone applied when input has no offset."), Input("format", "String", false, "Normal", "\"%Y-%m-%dT%H:%M:%S%z\"", "strftime format string.")],
            [Output("text", "String", "Formatted value.")]);
        Add(result,
            "datetime.parse", "Parse Date/Time", "Parse ISO-compatible text into an explicit ISO date/time.", "Date & Time",
            "Dynomax BuiltIn Parse Date/Time", ActionSessionBehaviors.DoesNotUseBrowser, 30, ActionSideEffectKinds.None, true,
            [Input("text", "String", true, "Normal", null, "Date/time text."), Input("timeZone", "String", false, "Normal", "\"UTC\"", "Timezone applied when input has no offset.")],
            [Output("dateTime", "String", "ISO-8601 date/time.")]);
        Add(result,
            "datetime.add", "Add Time", "Add/subtract an explicit duration.", "Date & Time",
            "Dynomax BuiltIn Add Time", ActionSessionBehaviors.DoesNotUseBrowser, 30, ActionSideEffectKinds.None, true,
            [Input("dateTime", "String", true, "Normal", null, "ISO-8601 date/time."), Input("days", "Integer", false, "Normal", "0", "Days."), Input("hours", "Integer", false, "Normal", "0", "Hours."), Input("minutes", "Integer", false, "Normal", "0", "Minutes."), Input("seconds", "Integer", false, "Normal", "0", "Seconds.")],
            [Output("dateTime", "String", "Adjusted date/time.")]);
        Add(result,
            "datetime.difference", "Date Difference", "Calculate the difference between two date/time values.", "Date & Time",
            "Dynomax BuiltIn Date Difference", ActionSessionBehaviors.DoesNotUseBrowser, 30, ActionSideEffectKinds.None, true,
            [Input("start", "String", true, "Normal", null, "Start ISO date/time."), Input("end", "String", true, "Normal", null, "End ISO date/time.")],
            [Output("totalSeconds", "Json", "Difference in seconds."), Output("totalMinutes", "Json", "Difference in minutes."), Output("totalHours", "Json", "Difference in hours."), Output("totalDays", "Json", "Difference in days.")]);
        Add(result,
            "datetime.convert-time-zone", "Convert Time Zone", "Convert a date/time into another explicit timezone.", "Date & Time",
            "Dynomax BuiltIn Convert Time Zone", ActionSessionBehaviors.DoesNotUseBrowser, 30, ActionSideEffectKinds.None, true,
            [Input("dateTime", "String", true, "Normal", null, "ISO-8601 date/time."), Input("sourceTimeZone", "String", false, "Normal", "\"UTC\"", "Timezone applied when no offset exists."), Input("targetTimeZone", "String", true, "Normal", null, "Target IANA timezone name.")],
            [Output("dateTime", "String", "Converted ISO-8601 date/time.")]);
        Add(result,
            "utility.guid.generate", "Generate GUID", "Generate a new GUID/UUID.", "Utilities",
            "Dynomax BuiltIn Generate GUID", ActionSessionBehaviors.DoesNotUseBrowser, 30, ActionSideEffectKinds.None, false,
            [],
            [Output("guid", "String", "Generated GUID.")]);
        Add(result,
            "utility.random.string", "Generate Random String", "Generate a cryptographically strong bounded random string.", "Utilities",
            "Dynomax BuiltIn Generate Random String", ActionSessionBehaviors.DoesNotUseBrowser, 30, ActionSideEffectKinds.None, false,
            [Input("length", "Integer", false, "Normal", "32", "Length from 1 to 1024."), Input("alphabet", "String", false, "Normal", "\"Alphanumeric\"", "Alphanumeric, Letters or Digits.")],
            [Output("value", "String", "Generated string.")]);
        Add(result,
            "utility.random.number", "Generate Random Number", "Generate a cryptographically strong random integer in an inclusive range.", "Utilities",
            "Dynomax BuiltIn Generate Random Number", ActionSessionBehaviors.DoesNotUseBrowser, 30, ActionSideEffectKinds.None, false,
            [Input("minimum", "Integer", false, "Normal", "0", "Inclusive minimum."), Input("maximum", "Integer", false, "Normal", "2147483647", "Inclusive maximum.")],
            [Output("value", "Integer", "Generated integer.")]);
        Add(result,
            "utility.sha256", "SHA-256 Hash", "Calculate SHA-256 for UTF-8 text.", "Utilities",
            "Dynomax BuiltIn SHA-256 Hash", ActionSessionBehaviors.DoesNotUseBrowser, 30, ActionSideEffectKinds.None, true,
            [Input("value", "String", true, "Normal", null, "Text to hash.")],
            [Output("sha256", "String", "Lower-case SHA-256 digest.")]);
        Add(result,
            "utility.hmac", "HMAC", "Calculate HMAC-SHA256 using a secret-reference key.", "Utilities",
            "Dynomax BuiltIn HMAC", ActionSessionBehaviors.DoesNotUseBrowser, 30, ActionSideEffectKinds.None, true,
            [Input("value", "String", true, "Normal", null, "Message text."), Input("key", "String", true, "Secret", null, "HMAC key secret reference.")],
            [Output("hmac", "String", "Lower-case HMAC-SHA256 digest.")]);
        Add(result,
            "utility.timestamp", "Generate Timestamp", "Generate a current UTC ISO timestamp and Unix milliseconds.", "Utilities",
            "Dynomax BuiltIn Generate Timestamp", ActionSessionBehaviors.DoesNotUseBrowser, 30, ActionSideEffectKinds.None, false,
            [],
            [Output("timestamp", "String", "UTC ISO-8601 timestamp."), Output("unixMilliseconds", "Integer", "Unix epoch milliseconds.")]);
        Add(result,
            "utility.environment-variable", "Environment Variable", "Read only a non-secret Dynomax runtime/configured value by key; never reads arbitrary host environment variables.", "Utilities",
            "Dynomax BuiltIn Environment Variable", ActionSessionBehaviors.DoesNotUseBrowser, 30, ActionSideEffectKinds.None, true,
            [Input("name", "String", true, "Normal", null, "Dynomax runtime/configured value key."), Input("required", "Boolean", false, "Normal", "false", "Fail if the key is missing.")],
            [Output("value", "Json", "Configured non-secret runtime value.")]);
        Add(result,
            "utility.machine-information", "Machine Information", "Return a safe curated runtime-machine contract without environment dumps, credentials, user name or host name.", "Utilities",
            "Dynomax BuiltIn Machine Information", ActionSessionBehaviors.DoesNotUseBrowser, 30, ActionSideEffectKinds.None, true,
            [],
            [Output("machine", "Json", "Safe OS/architecture/Python metadata.")]);
        return result.OrderBy(item => item.Category, StringComparer.Ordinal).ThenBy(item => item.DisplayName, StringComparer.Ordinal).ToArray();
    }

    private static BuiltInActionInput Input(
        string name,
        string dataType,
        bool required,
        string classification,
        string? defaultValueJson,
        string description) => Input(
            name,
            dataType,
            required,
            classification,
            defaultValueJson,
            description,
            classification switch
            {
                ActionInputClassifications.Secret => SecretBindings,
                ActionInputClassifications.Sensitive => SensitiveBindings,
                _ => NormalBindings
            });

    private static BuiltInActionInput Input(
        string name,
        string dataType,
        bool required,
        string classification,
        string? defaultValueJson,
        string description,
        IReadOnlyList<string> allowedBindingKinds,
        bool acceptSensitiveNodeOutput = false) => new(
            name,
            SplitDisplayName(name),
            dataType,
            null,
            required,
            classification,
            defaultValueJson,
            allowedBindingKinds,
            description,
            acceptSensitiveNodeOutput);

    private static BuiltInActionOutput Output(string name, string dataType, string description) =>
        Output(name, dataType, description, ActionOutputClassifications.Normal, true);

    private static BuiltInActionOutput Output(
        string name,
        string dataType,
        string description,
        string classification,
        bool persistInResult,
        IReadOnlyList<string>? sensitiveWhenInputsSensitive = null) => new(
        name,
        SplitDisplayName(name),
        dataType,
        null,
        true,
        classification,
        persistInResult,
        description,
        sensitiveWhenInputsSensitive);

    private static void Add(
        ICollection<BuiltInActionDescriptor> result,
        string key,
        string displayName,
        string description,
        string category,
        string keyword,
        string sessionBehavior,
        int timeoutSeconds,
        string sideEffectKind,
        bool isReplaySafe,
        IReadOnlyList<BuiltInActionInput> inputs,
        IReadOnlyList<BuiltInActionOutput> outputs,
        int contractVersion = 1,
        string? requiredCoreVersionOverride = null)
    {
        string engine = ActionEngines.RobotBrowser;
        string entryPoint = "action.resource";
        string runtimeKeyword = keyword;
        string runtimeKey = $"dynomax.builtin.{key}";
        string requiredCoreVersion = requiredCoreVersionOverride ?? (SharedRuntimeActionKeys.Contains(key)
            ? RemainderRequiredCoreVersion
            : FirstBatchRequiredCoreVersion);
        ActionExecutionPolicyContract policy = new(
            ActionExecutionPolicyDefaults.SingleAttempt(timeoutSeconds),
            ActionExecutionPolicyLimits.Standard);

        var definition = new SortedDictionary<string, object?>(StringComparer.Ordinal)
        {
            ["schemaVersion"] = 1,
            ["actionOrigin"] = ActionCapabilityOrigins.BuiltIn,
            ["actionId"] = key,
            ["runtimeActionId"] = runtimeKey,
            ["displayName"] = displayName,
            ["description"] = description,
            ["category"] = category,
            ["builtInContractVersion"] = contractVersion,
            ["engine"] = engine,
            ["entryPoint"] = entryPoint,
            ["keyword"] = runtimeKeyword,
            ["sessionBehavior"] = sessionBehavior,
            ["timeoutSeconds"] = timeoutSeconds,
            ["evidenceOnPass"] = key == "web.page.screenshot" ? ActionEvidenceModes.ScreenshotAndDiagnostics : ActionEvidenceModes.StructuredOnly,
            ["evidenceOnFailure"] = ActionEvidenceModes.Diagnostics,
            ["sideEffectKind"] = sideEffectKind,
            ["cleanupPolicy"] = ActionCleanupPolicies.NoneRequired,
            ["isReplaySafe"] = isReplaySafe,
            ["requiredCoreVersion"] = requiredCoreVersion,
            ["inputs"] = inputs.Select(item =>
            {
                var contract = new SortedDictionary<string, object?>(StringComparer.Ordinal)
                {
                    ["name"] = item.Name,
                    ["displayName"] = item.DisplayName,
                    ["dataType"] = item.DataType,
                    ["format"] = item.Format,
                    ["required"] = item.IsRequired,
                    ["classification"] = item.Classification,
                    ["defaultValue"] = ParseDefault(item.DefaultValueJson),
                    ["allowedBindingKinds"] = item.AllowedBindingKinds,
                    ["description"] = item.Description
                };
                if (item.AcceptSensitiveNodeOutput) contract["acceptSensitiveNodeOutput"] = true;
                return contract;
            }).ToArray(),
            ["outputs"] = outputs.Select(item =>
            {
                var contract = new SortedDictionary<string, object?>(StringComparer.Ordinal)
                {
                    ["name"] = item.Name,
                    ["displayName"] = item.DisplayName,
                    ["dataType"] = item.DataType,
                    ["format"] = item.Format,
                    ["required"] = item.IsRequired,
                    ["classification"] = item.Classification,
                    ["persistInResult"] = item.PersistInResult,
                    ["description"] = item.Description
                };
                if (item.SensitiveWhenInputsSensitive is { Count: > 0 })
                    contract["sensitiveWhenInputsSensitive"] = item.SensitiveWhenInputsSensitive;
                return contract;
            }).ToArray(),
            ["executionPolicy"] = new SortedDictionary<string, object?>(StringComparer.Ordinal)
            {
                ["defaults"] = policy.Defaults,
                ["limits"] = policy.Limits
            }
        };

        string canonicalDefinition = Canonicalize(JsonSerializer.Serialize(definition, JsonOptions));
        string definitionSha256 = Hash(Encoding.UTF8.GetBytes(canonicalDefinition));
        var runtimeDefinition = new SortedDictionary<string, object?>(definition, StringComparer.Ordinal)
        {
            ["actionId"] = runtimeKey,
            ["canonicalActionId"] = key,
            ["canonicalDefinitionSha256"] = definitionSha256
        };
        string runtimeDefinitionJson = Canonicalize(JsonSerializer.Serialize(runtimeDefinition, JsonOptions));
        string runtimeDefinitionSha256 = Hash(Encoding.UTF8.GetBytes(runtimeDefinitionJson));
        byte[] entryPointContent = Encoding.UTF8.GetBytes(BuildActionResource(key, runtimeKeyword, contractVersion));
        string entryPointSha256 = Hash(entryPointContent);

        var packageFiles = new List<BuiltInActionPackageFile>
        {
            new(entryPoint, entryPointContent, entryPointSha256)
        };
        packageFiles.AddRange(BuildSupportFiles(key, contractVersion));
        byte[] packageWithoutManifest = CreateDeterministicZip(packageFiles);
        string preliminaryPackageHash = Hash(packageWithoutManifest);
        byte[] manifest = Encoding.UTF8.GetBytes(Canonicalize(JsonSerializer.Serialize(new SortedDictionary<string, object?>(StringComparer.Ordinal)
        {
            ["schemaVersion"] = 1,
            ["packageType"] = "DynomaxBuiltInActionPackage",
            ["storageAuthority"] = "Dynomax.BuiltInActionCatalog",
            ["actionOrigin"] = ActionCapabilityOrigins.BuiltIn,
            ["actionKey"] = key,
            ["runtimeActionKey"] = runtimeKey,
            ["contractVersion"] = contractVersion,
            ["definitionSha256"] = definitionSha256,
            ["runtimeDefinitionSha256"] = runtimeDefinitionSha256,
            ["entryPoint"] = entryPoint,
            ["entryPointSha256"] = entryPointSha256,
            ["requiredCoreVersion"] = requiredCoreVersion,
            ["contentSetSha256"] = preliminaryPackageHash,
            ["secretValuesIncluded"] = false,
            ["files"] = packageFiles.Select(file => new { path = file.RelativePath, length = file.Content.LongLength, sha256 = file.Sha256 }).ToArray()
        }, JsonOptions)));
        packageFiles.Add(new("BUILTIN_PACKAGE_MANIFEST.json", manifest, Hash(manifest)));
        string packageSha256 = Hash(CreateDeterministicZip(packageFiles));

        result.Add(new BuiltInActionDescriptor(
            key,
            runtimeKey,
            displayName,
            description,
            category,
            contractVersion,
            engine,
            entryPoint,
            runtimeKeyword,
            sessionBehavior,
            timeoutSeconds,
            key == "web.page.screenshot" ? ActionEvidenceModes.ScreenshotAndDiagnostics : ActionEvidenceModes.StructuredOnly,
            ActionEvidenceModes.Diagnostics,
            sideEffectKind,
            ActionCleanupPolicies.NoneRequired,
            isReplaySafe,
            requiredCoreVersion,
            canonicalDefinition,
            definitionSha256,
            runtimeDefinitionJson,
            runtimeDefinitionSha256,
            packageSha256,
            entryPointSha256,
            packageFiles.ToArray(),
            inputs,
            outputs,
            policy));
    }


    private static string BuildActionResource(string key, string keyword, int contractVersion)
    {
        if (IsWorkspaceRecordsBatchAction(key) && contractVersion >= 2)
            return BuildWorkspaceRecordBatchActionResource(key, keyword);

        if (key.StartsWith("workspace.records.", StringComparison.Ordinal))
            return BuildWorkspaceRecordsActionResource(key, keyword);

        if (UsesSensitiveJsonRuntime(key, contractVersion))
            return BuildSensitiveJsonV2ActionResource(key, keyword);

        if (IsImapV3(key, contractVersion))
            return BuildImapV3ActionResource(key, keyword);

        if (IsImapV2(key, contractVersion))
            return BuildImapV2ActionResource(key, keyword);

        if (string.Equals(key, "web.file.download", StringComparison.Ordinal) && contractVersion >= 2)
            return BuildDownloadV2ActionResource(keyword);

        if (string.Equals(key, "web.form.snapshot", StringComparison.Ordinal) ||
            string.Equals(key, "web.form.apply-values", StringComparison.Ordinal))
        {
            // Immutable compatibility: v2 was already published before the Robot section-header
            // packaging defect was found, so preserve its exact historical entry-point bytes.
            if (contractVersion == 2)
                return ExtractRobotKeyword(StructuredFormV2RobotResource, keyword);

            if (contractVersion >= 3)
                return BuildStructuredFormV3ActionResource(keyword);
        }

        if (SharedRuntimeActionKeys.Contains(key))
            return BuildSharedRuntimeActionResource(key, keyword);

        var builder = new StringBuilder();
        string? library = key switch
        {
            "data.json.parse" => "DynomaxBuiltInParseJson.py",
            "data.json.get-value" => "DynomaxBuiltInGetJsonValue.py",
            "data.json.get-string" => "DynomaxBuiltInGetJsonValue.py",
            _ => null
        };
        if (library is not null)
        {
            builder.AppendLine("*** Settings ***");
            builder.Append("Library    ${CURDIR}/").AppendLine(library);
            builder.AppendLine();
        }

        builder.AppendLine("*** Keywords ***");
        builder.Append(ExtractRobotKeyword(keyword));
        if (string.Equals(key, "web.wait.url", StringComparison.Ordinal))
            builder.Append(ExtractRobotKeyword("Dynomax BuiltIn URL Should Equal"));
        return builder.ToString().Replace("\r\n", "\n", StringComparison.Ordinal);
    }

    private static string BuildWorkspaceRecordsActionResource(string key, string keyword)
    {
        var builder = new StringBuilder();
        builder.AppendLine("*** Settings ***");
        builder.AppendLine("Library    ${CURDIR}/DynomaxBuiltInWorkspaceRecords.py");
        builder.AppendLine();
        builder.AppendLine("*** Keywords ***");
        builder.AppendLine(keyword);
        builder.Append("    Execute Dynomax Workspace Records Operation    ").Append(key)
            .AppendLine("    ${DYNOMAX_CONTEXT_PATH}    ${DYNOMAX_POWERSHELL}    ${DYNOMAX_ROOT}");
        return builder.ToString().Replace("\r\n", "\n", StringComparison.Ordinal);
    }

    private static string BuildWorkspaceRecordBatchActionResource(string key, string keyword)
    {
        var builder = new StringBuilder();
        builder.AppendLine("*** Settings ***");
        builder.AppendLine("Library    ${CURDIR}/DynomaxBuiltInWorkspaceRecordBatches.py");
        builder.AppendLine();
        builder.AppendLine("*** Keywords ***");
        builder.AppendLine(keyword);
        builder.Append("    Execute Dynomax Workspace Record Batch Operation    ").Append(key)
            .AppendLine("    ${DYNOMAX_CONTEXT_PATH}    ${DYNOMAX_POWERSHELL}    ${DYNOMAX_ROOT}");
        return builder.ToString().Replace("\r\n", "\n", StringComparison.Ordinal);
    }

    private static bool IsWorkspaceRecordsBatchAction(string key) =>
        string.Equals(key, "workspace.records.get-many", StringComparison.Ordinal) ||
        string.Equals(key, "workspace.records.append-many", StringComparison.Ordinal) ||
        string.Equals(key, "workspace.records.upsert-many", StringComparison.Ordinal);

    private static bool UsesSensitiveJsonRuntime(string key, int contractVersion) =>
        (contractVersion >= 2 &&
         (string.Equals(key, "data.json.serialize", StringComparison.Ordinal) ||
          string.Equals(key, "data.json.set-value", StringComparison.Ordinal) ||
          string.Equals(key, "data.json.merge", StringComparison.Ordinal) ||
          string.Equals(key, "data.json.get-string", StringComparison.Ordinal))) ||
        string.Equals(key, "data.json.set-string", StringComparison.Ordinal);

    private static bool IsImapV3(string key, int contractVersion) =>
        contractVersion >= 3 && string.Equals(key, "email.imap.latest", StringComparison.Ordinal);

    private static bool IsImapV2(string key, int contractVersion) =>
        contractVersion >= 2 && key.StartsWith("email.imap.", StringComparison.Ordinal);

    private static string BuildSensitiveJsonV2ActionResource(string key, string keyword)
    {
        var builder = new StringBuilder();
        builder.AppendLine("*** Settings ***");
        builder.AppendLine("Library    ${CURDIR}/DynomaxBuiltInSensitiveJson.py");
        builder.AppendLine();
        builder.AppendLine("*** Keywords ***");
        builder.AppendLine(keyword);
        builder.Append("    Execute Dynomax Sensitive JSON Operation    ").Append(key)
            .AppendLine("    ${DYNOMAX_CONTEXT_PATH}");
        return builder.ToString().Replace("\r\n", "\n", StringComparison.Ordinal);
    }

    private static string BuildImapV3ActionResource(string key, string keyword)
    {
        var builder = new StringBuilder();
        builder.AppendLine("*** Settings ***");
        builder.AppendLine("Library    ${CURDIR}/DynomaxBuiltInImapV3.py");
        builder.AppendLine();
        builder.AppendLine("*** Keywords ***");
        builder.AppendLine(keyword);
        builder.Append("    Execute Dynomax IMAP V3 Operation    ").Append(key)
            .AppendLine("    ${DYNOMAX_CONTEXT_PATH}    ${DYNOMAX_RUN_DIR}");
        return builder.ToString().Replace("\r\n", "\n", StringComparison.Ordinal);
    }

    private static string BuildImapV2ActionResource(string key, string keyword)
    {
        var builder = new StringBuilder();
        builder.AppendLine("*** Settings ***");
        builder.AppendLine("Library    ${CURDIR}/DynomaxBuiltInImapV2.py");
        builder.AppendLine();
        builder.AppendLine("*** Keywords ***");
        builder.AppendLine(keyword);
        builder.Append("    Execute Dynomax IMAP V2 Operation    ").Append(key)
            .AppendLine("    ${DYNOMAX_CONTEXT_PATH}    ${DYNOMAX_RUN_DIR}");
        return builder.ToString().Replace("\r\n", "\n", StringComparison.Ordinal);
    }

    private static string BuildDownloadV2ActionResource(string keyword)
    {
        var builder = new StringBuilder();
        builder.AppendLine("*** Settings ***");
        builder.AppendLine("Library    ${CURDIR}/DynomaxBuiltInRuntime.py");
        builder.AppendLine("Library    ${CURDIR}/DynomaxBuiltInDownload.py");
        builder.AppendLine();
        builder.AppendLine("*** Keywords ***");
        builder.AppendLine(keyword);
        builder.AppendLine("    ${selector}=    Get Dynomax Context Value    selector");
        builder.AppendLine("    ${destination}=    Get Dynomax Context Value    destinationDirectory    downloads");
        builder.AppendLine("    ${timeout}=    Get Dynomax Context Value    timeoutSeconds    60");
        builder.AppendLine("    ${save_as}=    Prepare Dynomax BuiltIn Download Target    ${DYNOMAX_RUN_DIR}    ${destination}");
        builder.AppendLine("    ${download_promise}=    Promise To Wait For Download    ${save_as}    wait_for_finished=${True}    download_timeout=${timeout}s");
        builder.AppendLine("    Click    ${selector}");
        builder.AppendLine("    ${download}=    Wait For    ${download_promise}");
        builder.AppendLine("    Finalize Dynomax BuiltIn Download    ${DYNOMAX_CONTEXT_PATH}    ${DYNOMAX_RUN_DIR}    ${destination}    ${download}[saveAs]    ${download}[suggestedFilename]");
        return builder.ToString().Replace("\r\n", "\n", StringComparison.Ordinal);
    }


    private static string BuildStructuredFormV3ActionResource(string keyword)
    {
        var builder = new StringBuilder();
        builder.AppendLine("*** Keywords ***");
        builder.Append(ExtractRobotKeyword(StructuredFormV2RobotResource, keyword));
        return builder.ToString().Replace("\r\n", "\n", StringComparison.Ordinal);
    }

    private static string BuildSharedRuntimeActionResource(string key, string keyword)
    {
        var builder = new StringBuilder();
        builder.AppendLine("*** Settings ***");
        builder.AppendLine("Library    ${CURDIR}/DynomaxBuiltInRuntime.py");
        builder.AppendLine();
        builder.AppendLine("*** Keywords ***");
        builder.AppendLine(keyword);

        if (string.Equals(key, "web.file.upload", StringComparison.Ordinal))
        {
            builder.AppendLine("    ${selector}=    Get Dynomax Context Value    selector");
            builder.AppendLine("    ${reference}=    Get Dynomax Context Value    fileReference");
            builder.AppendLine("    ${path}=    Resolve Dynomax BuiltIn Run Path    ${DYNOMAX_RUN_DIR}    ${reference}    ${True}");
            builder.AppendLine("    Upload File By Selector    ${selector}    ${path}");
            builder.AppendLine("    Set Dynomax Context Value    uploaded    ${True}");
        }
        else if (string.Equals(key, "web.file.download", StringComparison.Ordinal))
        {
            builder.AppendLine("    ${selector}=    Get Dynomax Context Value    selector");
            builder.AppendLine("    ${destination}=    Get Dynomax Context Value    destinationDirectory    downloads");
            builder.AppendLine("    ${timeout}=    Get Dynomax Context Value    timeoutSeconds    60");
            builder.AppendLine("    ${directory}=    Prepare Dynomax BuiltIn Run Directory    ${DYNOMAX_RUN_DIR}    ${destination}");
            builder.AppendLine("    ${download_promise}=    Promise To Wait For Download    ${directory}    timeout=${timeout}s");
            builder.AppendLine("    Click    ${selector}");
            builder.AppendLine("    ${download}=    Wait For    ${download_promise}");
            builder.AppendLine("    Record Dynomax BuiltIn Download    ${DYNOMAX_CONTEXT_PATH}    ${DYNOMAX_RUN_DIR}    ${download}[saveAs]");
        }
        else
        {
            builder.Append("    Execute Dynomax BuiltIn Operation    ").Append(key)
                .AppendLine("    ${DYNOMAX_CONTEXT_PATH}    ${DYNOMAX_RUN_DIR}    ${DYNOMAX_WORKFLOW_PATH}    ${DYNOMAX_POWERSHELL}    ${DYNOMAX_ROOT}");
        }

        return builder.ToString().Replace("\r\n", "\n", StringComparison.Ordinal);
    }

    private static IReadOnlyList<BuiltInActionPackageFile> BuildSupportFiles(string key, int contractVersion)
    {
        if (IsWorkspaceRecordsBatchAction(key))
        {
            if (contractVersion >= 2)
            {
                string runtimeLibrary = WorkspaceRecordsBatchRuntimeLibraryV1.Replace(
                    "@keyword(\"Execute Dynomax Workspace Records Operation\")",
                    "@keyword(\"Execute Dynomax Workspace Record Batch Operation\")",
                    StringComparison.Ordinal);
                byte[] v2Content = Encoding.UTF8.GetBytes(runtimeLibrary.Replace("\r\n", "\n", StringComparison.Ordinal));
                return [new BuiltInActionPackageFile("DynomaxBuiltInWorkspaceRecordBatches.py", v2Content, Hash(v2Content))];
            }

            byte[] content = Encoding.UTF8.GetBytes(WorkspaceRecordsBatchRuntimeLibraryV1.Replace("\r\n", "\n", StringComparison.Ordinal));
            return [new BuiltInActionPackageFile("DynomaxBuiltInWorkspaceRecords.py", content, Hash(content))];
        }

        if (key.StartsWith("workspace.records.", StringComparison.Ordinal))
        {
            string runtimeLibrary = contractVersion >= 2 ? WorkspaceRecordsRuntimeLibraryV2 : WorkspaceRecordsRuntimeLibraryV1;
            byte[] content = Encoding.UTF8.GetBytes(runtimeLibrary.Replace("\r\n", "\n", StringComparison.Ordinal));
            return [new BuiltInActionPackageFile("DynomaxBuiltInWorkspaceRecords.py", content, Hash(content))];
        }

        if (UsesSensitiveJsonRuntime(key, contractVersion))
        {
            string runtimeLibrary = string.Equals(key, "data.json.get-string", StringComparison.Ordinal) && contractVersion >= 2
                ? SensitiveJsonGetStringRuntimeLibrary
                : SensitiveJsonV2RuntimeLibrary;
            byte[] content = Encoding.UTF8.GetBytes(runtimeLibrary.Replace("\r\n", "\n", StringComparison.Ordinal));
            return [new BuiltInActionPackageFile("DynomaxBuiltInSensitiveJson.py", content, Hash(content))];
        }

        if (IsImapV3(key, contractVersion))
        {
            byte[] content = Encoding.UTF8.GetBytes(ImapV3RuntimeLibrary.Replace("\r\n", "\n", StringComparison.Ordinal));
            return [new BuiltInActionPackageFile("DynomaxBuiltInImapV3.py", content, Hash(content))];
        }

        if (IsImapV2(key, contractVersion))
        {
            byte[] content = Encoding.UTF8.GetBytes(ImapV2RuntimeLibrary.Replace("\r\n", "\n", StringComparison.Ordinal));
            return [new BuiltInActionPackageFile("DynomaxBuiltInImapV2.py", content, Hash(content))];
        }

        if (SharedRuntimeActionKeys.Contains(key))
        {
            byte[] content = Encoding.UTF8.GetBytes(SharedBuiltInRuntimeLibrary.Replace("\r\n", "\n", StringComparison.Ordinal));
            var files = new List<BuiltInActionPackageFile>
            {
                new("DynomaxBuiltInRuntime.py", content, Hash(content))
            };
            if (string.Equals(key, "web.file.download", StringComparison.Ordinal) && contractVersion >= 2)
            {
                byte[] download = Encoding.UTF8.GetBytes(DownloadBuiltInRuntimeLibrary.Replace("\r\n", "\n", StringComparison.Ordinal));
                files.Add(new BuiltInActionPackageFile("DynomaxBuiltInDownload.py", download, Hash(download)));
            }
            return files;
        }

        (string Name, string Content)? source = key switch
        {
            "data.json.parse" => ("DynomaxBuiltInParseJson.py", ParseJsonLibrary),
            "data.json.get-value" => ("DynomaxBuiltInGetJsonValue.py", GetJsonValueLibrary),
            "data.json.get-string" => ("DynomaxBuiltInGetJsonValue.py", GetJsonValueLibrary),
            _ => null
        };
        if (source is null) return [];
        byte[] support = Encoding.UTF8.GetBytes(source.Value.Content.Replace("\r\n", "\n", StringComparison.Ordinal));
        return [new BuiltInActionPackageFile(source.Value.Name, support, Hash(support))];
    }

    private static string ExtractRobotKeyword(string keyword) =>
        ExtractRobotKeyword(SharedRobotResource, keyword);

    private static string ExtractRobotKeyword(string resource, string keyword)
    {
        string[] lines = resource.Replace("\r\n", "\n", StringComparison.Ordinal).Split('\n');
        int start = Array.FindIndex(lines, line => string.Equals(line, keyword, StringComparison.Ordinal));
        if (start < 0) throw new InvalidOperationException($"Built-in Robot keyword '{keyword}' was not found.");
        var builder = new StringBuilder();
        for (int index = start; index < lines.Length; index++)
        {
            string line = lines[index];
            if (index > start && line.Length > 0 && !char.IsWhiteSpace(line[0])) break;
            builder.AppendLine(line);
        }
        return builder.ToString();
    }

    private static object? ParseDefault(string? json)
    {
        if (json is null) return null;
        return JsonNode.Parse(json);
    }

    private static string SplitDisplayName(string name)
    {
        if (string.IsNullOrEmpty(name)) return name;
        var builder = new StringBuilder(name.Length + 8);
        for (int index = 0; index < name.Length; index++)
        {
            char character = name[index];
            if (index > 0 && char.IsUpper(character) && char.IsLower(name[index - 1])) builder.Append(' ');
            builder.Append(index == 0 ? char.ToUpperInvariant(character) : character);
        }
        return builder.ToString();
    }

    private static byte[] CreateDeterministicZip(IReadOnlyList<BuiltInActionPackageFile> files)
    {
        using var stream = new MemoryStream();
        using (var archive = new ZipArchive(stream, ZipArchiveMode.Create, leaveOpen: true))
        {
            foreach (BuiltInActionPackageFile file in files.OrderBy(item => item.RelativePath, StringComparer.Ordinal))
            {
                ZipArchiveEntry entry = archive.CreateEntry(file.RelativePath, CompressionLevel.NoCompression);
                entry.LastWriteTime = ZipTimestamp;
                using Stream target = entry.Open();
                target.Write(file.Content, 0, file.Content.Length);
            }
        }
        return stream.ToArray();
    }

    private static string Canonicalize(string json)
    {
        using JsonDocument document = JsonDocument.Parse(json);
        using var stream = new MemoryStream();
        using (var writer = new Utf8JsonWriter(stream, new JsonWriterOptions { Indented = true }))
            WriteCanonical(writer, document.RootElement);
        return Encoding.UTF8.GetString(stream.ToArray());
    }

    private static void WriteCanonical(Utf8JsonWriter writer, JsonElement element)
    {
        switch (element.ValueKind)
        {
            case JsonValueKind.Object:
                writer.WriteStartObject();
                foreach (JsonProperty property in element.EnumerateObject().OrderBy(property => property.Name, StringComparer.Ordinal))
                {
                    writer.WritePropertyName(property.Name);
                    WriteCanonical(writer, property.Value);
                }
                writer.WriteEndObject();
                break;
            case JsonValueKind.Array:
                writer.WriteStartArray();
                foreach (JsonElement item in element.EnumerateArray()) WriteCanonical(writer, item);
                writer.WriteEndArray();
                break;
            default:
                element.WriteTo(writer);
                break;
        }
    }

    private static string Hash(byte[] content) =>
        Convert.ToHexString(SHA256.HashData(content)).ToLowerInvariant();

    private const string WorkspaceRecordsRuntimeLibraryV1 = """
from __future__ import annotations

import base64
import datetime as dt
import hashlib
import json
import os
import re
import subprocess
import tempfile
from typing import Any, Dict

from robot.api.deco import keyword, library

_MAX_JSON_CHARS = 1_048_576
_COLLECTION_RE = re.compile(r"^[A-Za-z0-9][A-Za-z0-9._-]{0,99}$")
_KEY_RE = re.compile(r"^[A-Za-z0-9][A-Za-z0-9._:/-]{0,199}$")


def _load(path: str) -> Dict[str, Any]:
    with open(path, "r", encoding="utf-8") as stream:
        value = json.load(stream)
    if not isinstance(value, dict):
        raise RuntimeError("Dynomax runtime context is invalid.")
    return value


def _save(path: str, context: Dict[str, Any]) -> None:
    target = os.path.abspath(path)
    fd, temp_name = tempfile.mkstemp(prefix=".dynomax-workspace-records-", suffix=".tmp", dir=os.path.dirname(target))
    try:
        with os.fdopen(fd, "w", encoding="utf-8", newline="\n") as stream:
            json.dump(context, stream, ensure_ascii=False, indent=2, default=str)
            stream.write("\n")
        os.replace(temp_name, target)
    except Exception:
        try:
            os.unlink(temp_name)
        except OSError:
            pass
        raise


def _values(ctx: Dict[str, Any]) -> Dict[str, Any]:
    values = ctx.setdefault("values", {})
    if not isinstance(values, dict):
        raise RuntimeError("Dynomax runtime context values are invalid.")
    return values


def _get(ctx: Dict[str, Any], name: str, default: Any = None, *, required: bool = False) -> Any:
    value = _values(ctx).get(name, default)
    if required and (value is None or (isinstance(value, str) and value.strip() == "")):
        raise ValueError(f"Required Built-in Action input '{name}' is missing.")
    return value


def _set(ctx: Dict[str, Any], name: str, value: Any) -> None:
    _values(ctx)[name] = value
    secret_keys = {str(item) for item in (ctx.get("secretKeys") or []) if str(item).strip()}
    secret_keys.discard(name)
    ctx["secretKeys"] = sorted(secret_keys)


def _reject_sensitive_inputs(ctx: Dict[str, Any]) -> None:
    secret_keys = {str(item) for item in (ctx.get("secretKeys") or []) if str(item).strip()}
    guarded = {
        "collection", "scope", "key", "recordKey", "record", "appendIdempotencyKey",
        "observedAtUtc", "observedAfterUtc", "observedBeforeUtc", "maxAgeMinutes",
        "maxRows", "includeExpired", "expectedVersion", "expiresAtUtc"
    }
    if secret_keys.intersection(guarded):
        raise ValueError("Workspace durable records accept Normal-classification inputs only.")


def _canonical_json(value: Any) -> str:
    if isinstance(value, str):
        if len(value) > _MAX_JSON_CHARS:
            raise ValueError("JSON input exceeds the 1 MiB Built-in Action limit.")
        try:
            value = json.loads(value)
        except json.JSONDecodeError:
            pass
    rendered = json.dumps(value, ensure_ascii=False, sort_keys=True, separators=(",", ":"), default=str)
    if len(rendered.encode("utf-8")) > _MAX_JSON_CHARS:
        raise ValueError("JSON input exceeds the 1 MiB Built-in Action limit.")
    return rendered


def _canonical_object(value: Any, label: str) -> str:
    if isinstance(value, str):
        if len(value) > _MAX_JSON_CHARS:
            raise ValueError("JSON input exceeds the 1 MiB Built-in Action limit.")
        value = json.loads(value)
    if not isinstance(value, dict):
        raise ValueError(f"{label} must be a JSON object.")
    return _canonical_json(value)


def _sha256(text: str) -> str:
    return hashlib.sha256(text.encode("utf-8")).hexdigest()


def _normalized_collection(value: Any) -> str:
    text = str(value or "").strip().lower()
    if not _COLLECTION_RE.fullmatch(text):
        raise ValueError("Collection must be 1-100 characters using letters, digits, '.', '_' or '-'.")
    return text


def _normalized_key(value: Any, label: str) -> str:
    text = str(value or "").strip().lower()
    if not _KEY_RE.fullmatch(text):
        raise ValueError(f"{label} must be 1-200 characters using a bounded stable-key character set.")
    return text


def _scope(value: Any) -> str:
    text = str(value or "Environment").strip().lower()
    if text == "environment":
        return "Environment"
    if text == "workspace":
        return "Workspace"
    raise ValueError("Scope must be Environment or Workspace.")


def _utc_text(value: Any, label: str, *, default_now: bool = False) -> str | None:
    if value is None or str(value).strip() == "":
        if not default_now:
            return None
        parsed = dt.datetime.now(dt.timezone.utc)
    else:
        text = str(value).strip()
        if text.endswith("Z"):
            text = text[:-1] + "+00:00"
        try:
            parsed = dt.datetime.fromisoformat(text)
        except ValueError as exc:
            raise ValueError(f"{label} must be an ISO-8601 timestamp.") from exc
        if parsed.tzinfo is None:
            parsed = parsed.replace(tzinfo=dt.timezone.utc)
        parsed = parsed.astimezone(dt.timezone.utc)
    return parsed.isoformat(timespec="microseconds").replace("+00:00", "Z")


def _bounded_int(value: Any, default: int, minimum: int, maximum: int, label: str) -> int:
    if value is None or str(value).strip() == "":
        parsed = default
    else:
        parsed = int(value)
    if parsed < minimum or parsed > maximum:
        raise ValueError(f"{label} must be between {minimum} and {maximum}.")
    return parsed


def _runtime_identity(ctx: Dict[str, Any]) -> tuple[str, str]:
    runtime = ctx.get("runtimeValues") or {}
    if not isinstance(runtime, dict):
        raise RuntimeError("Dynomax runtime identity is unavailable.")
    project_id = str(runtime.get("ProjectId") or "").strip()
    environment_key = str(runtime.get("EnvironmentKey") or "").strip()
    if not project_id or not environment_key:
        raise RuntimeError("Dynomax runtime ProjectId/EnvironmentKey identity is unavailable.")
    return project_id, environment_key


def _powershell_script() -> str:
    return r'''$ErrorActionPreference='Stop'
Set-StrictMode -Version Latest
$payload=[Console]::In.ReadToEnd() | ConvertFrom-Json
$root=[System.IO.Path]::GetFullPath([string]$payload.dynomaxRoot)
$configPath=Join-Path $root 'dynomax.json'
if(-not(Test-Path -LiteralPath $configPath -PathType Leaf)){throw 'Dynomax runtime configuration was not found.'}
. (Join-Path $root 'Core\Common\Dynomax.Common.ps1')
. (Join-Path $root 'Core\Database\Dynomax.Database.ps1')
$config=Read-DynomaxJson -Path $configPath
$sqlConfigPath=Resolve-DynomaxPath -Root $root -ConfiguredPath $config.paths.databaseConfig
$databaseConfig=Read-DynomaxJson -Path $sqlConfigPath
$conn=Open-DynomaxConnection -SqlConfig $databaseConfig.sql

function Convert-RecordRow($row){
  if($null -eq $row){return $null}
  function V($name){$v=$row.$name;if($null -eq $v -or $v -is [DBNull]){return $null};return $v}
  function T($name){$v=V $name;if($null -eq $v){return $null};if($v -is [DateTime]){return $v.ToString('yyyy-MM-ddTHH:mm:ss.fffffffZ')};return [string]$v}
  return [ordered]@{
    id=[string](V 'Id'); collection=[string](V 'CollectionName'); scope=[string](V 'Scope'); recordKey=V 'RecordKey';
    keyJson=V 'KeyJson'; dataJson=[string](V 'DataJson'); observedAtUtc=T 'ObservedAtUtc'; createdAtUtc=T 'CreatedAtUtc';
    updatedAtUtc=T 'UpdatedAtUtc'; version=[int](V 'Version'); expiresAtUtc=T 'ExpiresAtUtc'
  }
}
function Rows($sql,[hashtable]$params,$tx=$null){return Invoke-DynomaxSqlRows -Connection $conn -CommandText $sql -Parameters $params -Transaction $tx -CommandTimeoutSeconds 120}
function Scalar($sql,[hashtable]$params,$tx=$null){return Invoke-DynomaxSqlScalar -Connection $conn -CommandText $sql -Parameters $params -Transaction $tx -CommandTimeoutSeconds 120}
function Exec($sql,[hashtable]$params,$tx=$null){return Invoke-DynomaxSqlNonQuery -Connection $conn -CommandText $sql -Parameters $params -Transaction $tx -CommandTimeoutSeconds 120}
function FirstRow($table){if($null -eq $table -or $table.Rows.Count -eq 0){return $null};return $table.Rows[0]}

try {
  $projectId=[Guid]::Parse([string]$payload.projectId)
  $projectExists=Scalar 'SELECT COUNT_BIG(1) FROM [DynomaxV2].[Projects] WHERE [Id]=@ProjectId' @{ '@ProjectId'=$projectId }
  if([int64]$projectExists -ne 1){throw 'Runtime Workspace project identity was not found.'}
  $environmentId=$null
  if([string]$payload.scope -eq 'Environment'){
    $environmentId=Scalar 'SELECT TOP(1) [Id] FROM [DynomaxV2].[ProjectEnvironments] WHERE [ProjectId]=@ProjectId AND [Key]=@EnvironmentKey AND [IsActive]=1' @{ '@ProjectId'=$projectId; '@EnvironmentKey'=[string]$payload.environmentKey }
    if($null -eq $environmentId -or $environmentId -is [DBNull]){throw 'Runtime Workspace environment identity was not found.'}
    $environmentId=[Guid]$environmentId
  }
  $baseParams=@{ '@ProjectId'=$projectId; '@Collection'=[string]$payload.collection; '@Scope'=[string]$payload.scope }
  $scopePredicate=if([string]$payload.scope -eq 'Environment'){'[ProjectEnvironmentId]=@EnvironmentId'}else{'[ProjectEnvironmentId] IS NULL'}
  if($environmentId){$baseParams['@EnvironmentId']=$environmentId}
  $select='SELECT [Id],[CollectionName],[Scope],[RecordKey],[KeyJson],[DataJson],[ObservedAtUtc],[CreatedAtUtc],[UpdatedAtUtc],[Version],[ExpiresAtUtc] FROM [DynomaxV2].[WorkspaceDataRecords]'

  switch([string]$payload.operation){
    'workspace.records.query' {
      $p=@{};$baseParams.Keys|ForEach-Object{$p[$_]=$baseParams[$_]}
      $where="[ProjectId]=@ProjectId AND [CollectionName]=@Collection AND [Scope]=@Scope AND $scopePredicate"
      if($payload.keyJson){$where+=' AND [KeySha256]=@KeySha256 AND [KeyJson]=@KeyJson';$p['@KeySha256']=[string]$payload.keySha256;$p['@KeyJson']=[string]$payload.keyJson}
      if($payload.observedAfterUtc){$where+=' AND [ObservedAtUtc]>=@ObservedAfterUtc';$p['@ObservedAfterUtc']=[DateTime]::Parse([string]$payload.observedAfterUtc).ToUniversalTime()}
      if($payload.observedBeforeUtc){$where+=' AND [ObservedAtUtc]<@ObservedBeforeUtc';$p['@ObservedBeforeUtc']=[DateTime]::Parse([string]$payload.observedBeforeUtc).ToUniversalTime()}
      if(-not [bool]$payload.includeExpired){$where+=' AND ([ExpiresAtUtc] IS NULL OR [ExpiresAtUtc]>SYSUTCDATETIME())'}
      $limit=[Math]::Max(1,[Math]::Min(500,[int]$payload.maxRows));$p['@MaxRows']=$limit
      $table=Rows ("SELECT TOP (@MaxRows) [Id],[CollectionName],[Scope],[RecordKey],[KeyJson],[DataJson],[ObservedAtUtc],[CreatedAtUtc],[UpdatedAtUtc],[Version],[ExpiresAtUtc] FROM [DynomaxV2].[WorkspaceDataRecords] WHERE $where ORDER BY [ObservedAtUtc] DESC,[CreatedAtUtc] DESC,[Id] DESC") $p
      $records=@();foreach($row in $table.Rows){$records+=,(Convert-RecordRow $row)}
      [ordered]@{records=$records}|ConvertTo-Json -Depth 20 -Compress
    }
    'workspace.records.get' {
      $p=@{};$baseParams.Keys|ForEach-Object{$p[$_]=$baseParams[$_]};$p['@RecordKey']=[string]$payload.recordKey
      $table=Rows ("$select WHERE [ProjectId]=@ProjectId AND [CollectionName]=@Collection AND [Scope]=@Scope AND $scopePredicate AND [RecordKey]=@RecordKey AND ([ExpiresAtUtc] IS NULL OR [ExpiresAtUtc]>SYSUTCDATETIME())") $p
      [ordered]@{record=Convert-RecordRow (FirstRow $table)}|ConvertTo-Json -Depth 20 -Compress
    }
    'workspace.records.append' {
      $tx=$conn.BeginTransaction([System.Data.IsolationLevel]::Serializable)
      try {
        $p=@{};$baseParams.Keys|ForEach-Object{$p[$_]=$baseParams[$_]}
        if($payload.appendIdempotencyKey){
          $p['@AppendKey']=[string]$payload.appendIdempotencyKey
          $existing=Rows ("SELECT [Id],[CollectionName],[Scope],[RecordKey],[KeyJson],[DataJson],[ObservedAtUtc],[CreatedAtUtc],[UpdatedAtUtc],[Version],[ExpiresAtUtc],[KeySha256],[DataSha256] FROM [DynomaxV2].[WorkspaceDataRecords] WITH (UPDLOCK,HOLDLOCK) WHERE [ProjectId]=@ProjectId AND [CollectionName]=@Collection AND [Scope]=@Scope AND $scopePredicate AND [AppendIdempotencyKey]=@AppendKey") $p $tx
          $existingRow=FirstRow $existing
          if($existingRow){
            $same=([string]$existingRow.KeySha256 -eq [string]$payload.keySha256) -and ([string]$existingRow.DataSha256 -eq [string]$payload.dataSha256) -and ([string]$existingRow.KeyJson -eq [string]$payload.keyJson) -and ([string]$existingRow.DataJson -eq [string]$payload.dataJson)
            $same=$same -and ([DateTime]$existingRow.ObservedAtUtc -eq [DateTime]::Parse([string]$payload.observedAtUtc).ToUniversalTime())
            $existingExpiry=if($existingRow.ExpiresAtUtc -is [DBNull]){$null}else{$existingRow.ExpiresAtUtc}
            $requestedExpiry=if($payload.expiresAtUtc){[DateTime]::Parse([string]$payload.expiresAtUtc).ToUniversalTime()}else{$null}
            if(($null -eq $existingExpiry) -xor ($null -eq $requestedExpiry)){$same=$false}elseif($null -ne $existingExpiry -and [DateTime]$existingExpiry -ne $requestedExpiry){$same=$false}
            if(-not $same){throw 'Append idempotency key already exists with different durable record content.'}
            $tx.Commit();[ordered]@{record=Convert-RecordRow $existingRow;wasDuplicate=$true}|ConvertTo-Json -Depth 20 -Compress;break
          }
        }
        $id=[Guid]::NewGuid();$now=[DateTime]::UtcNow
        $p['@EnvironmentId']=if($environmentId){$environmentId}else{[DBNull]::Value};$p['@Id']=$id;$p['@RecordKey']=[DBNull]::Value;$p['@AppendKey']=if($payload.appendIdempotencyKey){[string]$payload.appendIdempotencyKey}else{[DBNull]::Value};$p['@KeyJson']=if($payload.keyJson){[string]$payload.keyJson}else{[DBNull]::Value};$p['@KeySha256']=[string]$payload.keySha256;$p['@DataJson']=[string]$payload.dataJson;$p['@DataSha256']=[string]$payload.dataSha256;$p['@ObservedAtUtc']=[DateTime]::Parse([string]$payload.observedAtUtc).ToUniversalTime();$p['@Now']=$now;$p['@ExpiresAtUtc']=if($payload.expiresAtUtc){[DateTime]::Parse([string]$payload.expiresAtUtc).ToUniversalTime()}else{[DBNull]::Value}
        [void](Exec 'INSERT INTO [DynomaxV2].[WorkspaceDataRecords] ([Id],[ProjectId],[ProjectEnvironmentId],[CollectionName],[Scope],[RecordKey],[AppendIdempotencyKey],[KeyJson],[KeySha256],[DataJson],[DataSha256],[ObservedAtUtc],[CreatedAtUtc],[UpdatedAtUtc],[Version],[ExpiresAtUtc]) VALUES (@Id,@ProjectId,@EnvironmentId,@Collection,@Scope,@RecordKey,@AppendKey,@KeyJson,@KeySha256,@DataJson,@DataSha256,@ObservedAtUtc,@Now,@Now,1,@ExpiresAtUtc)' $p $tx)
        $read=Rows ("$select WHERE [Id]=@Id") @{ '@Id'=$id } $tx;$row=FirstRow $read;$tx.Commit();[ordered]@{record=Convert-RecordRow $row;wasDuplicate=$false}|ConvertTo-Json -Depth 20 -Compress
      } catch {try{$tx.Rollback()}catch{};throw} finally {$tx.Dispose()}
    }
    'workspace.records.upsert' {
      $tx=$conn.BeginTransaction([System.Data.IsolationLevel]::Serializable)
      try {
        $p=@{};$baseParams.Keys|ForEach-Object{$p[$_]=$baseParams[$_]};$p['@RecordKey']=[string]$payload.recordKey
        $existing=Rows ("SELECT [Id],[CollectionName],[Scope],[RecordKey],[KeyJson],[DataJson],[ObservedAtUtc],[CreatedAtUtc],[UpdatedAtUtc],[Version],[ExpiresAtUtc],[KeySha256],[DataSha256] FROM [DynomaxV2].[WorkspaceDataRecords] WITH (UPDLOCK,HOLDLOCK) WHERE [ProjectId]=@ProjectId AND [CollectionName]=@Collection AND [Scope]=@Scope AND $scopePredicate AND [RecordKey]=@RecordKey") $p $tx
        $row=FirstRow $existing;$expected=[int]$payload.expectedVersion
        if($row){
          if($expected -eq 0){throw 'Stable durable record already exists but expectedVersion requires absence.'}
          if($expected -gt 0 -and [int]$row.Version -ne $expected){throw "Stable durable record version conflict. Expected $expected but found $($row.Version)."}
          $same=([string]$row.KeySha256 -eq [string]$payload.keySha256) -and ([string]$row.DataSha256 -eq [string]$payload.dataSha256) -and ([string]$row.KeyJson -eq [string]$payload.keyJson) -and ([string]$row.DataJson -eq [string]$payload.dataJson)
          $existingExpiry=if($row.ExpiresAtUtc -is [DBNull]){$null}else{$row.ExpiresAtUtc};$requestedExpiry=if($payload.expiresAtUtc){[DateTime]::Parse([string]$payload.expiresAtUtc).ToUniversalTime()}else{$null}
          if(($null -eq $existingExpiry) -xor ($null -eq $requestedExpiry)){$same=$false}elseif($null -ne $existingExpiry -and [DateTime]$existingExpiry -ne $requestedExpiry){$same=$false}
          if($same){$tx.Commit();[ordered]@{record=Convert-RecordRow $row;created=$false;changed=$false}|ConvertTo-Json -Depth 20 -Compress;break}
          $u=@{ '@Id'=[Guid]$row.Id; '@KeyJson'=if($payload.keyJson){[string]$payload.keyJson}else{[DBNull]::Value}; '@KeySha256'=[string]$payload.keySha256; '@DataJson'=[string]$payload.dataJson; '@DataSha256'=[string]$payload.dataSha256; '@ExpiresAtUtc'=if($payload.expiresAtUtc){[DateTime]::Parse([string]$payload.expiresAtUtc).ToUniversalTime()}else{[DBNull]::Value}; '@Now'=[DateTime]::UtcNow }
          [void](Exec 'UPDATE [DynomaxV2].[WorkspaceDataRecords] SET [KeyJson]=@KeyJson,[KeySha256]=@KeySha256,[DataJson]=@DataJson,[DataSha256]=@DataSha256,[ObservedAtUtc]=@Now,[UpdatedAtUtc]=@Now,[Version]=[Version]+1,[ExpiresAtUtc]=@ExpiresAtUtc WHERE [Id]=@Id' $u $tx)
          $read=Rows ("$select WHERE [Id]=@Id") @{ '@Id'=[Guid]$row.Id } $tx;$updated=FirstRow $read;$tx.Commit();[ordered]@{record=Convert-RecordRow $updated;created=$false;changed=$true}|ConvertTo-Json -Depth 20 -Compress
        } else {
          if($expected -gt 0){throw "Stable durable record does not exist but expectedVersion requires version $expected."}
          $id=[Guid]::NewGuid();$now=[DateTime]::UtcNow;$i=@{};$baseParams.Keys|ForEach-Object{$i[$_]=$baseParams[$_]};$i['@EnvironmentId']=if($environmentId){$environmentId}else{[DBNull]::Value};$i['@Id']=$id;$i['@RecordKey']=[string]$payload.recordKey;$i['@AppendKey']=[DBNull]::Value;$i['@KeyJson']=if($payload.keyJson){[string]$payload.keyJson}else{[DBNull]::Value};$i['@KeySha256']=[string]$payload.keySha256;$i['@DataJson']=[string]$payload.dataJson;$i['@DataSha256']=[string]$payload.dataSha256;$i['@ObservedAtUtc']=$now;$i['@Now']=$now;$i['@ExpiresAtUtc']=if($payload.expiresAtUtc){[DateTime]::Parse([string]$payload.expiresAtUtc).ToUniversalTime()}else{[DBNull]::Value}
          [void](Exec 'INSERT INTO [DynomaxV2].[WorkspaceDataRecords] ([Id],[ProjectId],[ProjectEnvironmentId],[CollectionName],[Scope],[RecordKey],[AppendIdempotencyKey],[KeyJson],[KeySha256],[DataJson],[DataSha256],[ObservedAtUtc],[CreatedAtUtc],[UpdatedAtUtc],[Version],[ExpiresAtUtc]) VALUES (@Id,@ProjectId,@EnvironmentId,@Collection,@Scope,@RecordKey,@AppendKey,@KeyJson,@KeySha256,@DataJson,@DataSha256,@ObservedAtUtc,@Now,@Now,1,@ExpiresAtUtc)' $i $tx)
          $read=Rows ("$select WHERE [Id]=@Id") @{ '@Id'=$id } $tx;$createdRow=FirstRow $read;$tx.Commit();[ordered]@{record=Convert-RecordRow $createdRow;created=$true;changed=$true}|ConvertTo-Json -Depth 20 -Compress
        }
      } catch {try{$tx.Rollback()}catch{};throw} finally {$tx.Dispose()}
    }
    default {throw 'Unsupported Workspace durable-record operation.'}
  }
} finally {if($conn){$conn.Dispose()}}'''


def _decode_record(item: Any) -> Any:
    if item is None:
        return None
    result = dict(item)
    key_json = result.pop("keyJson", None)
    result["key"] = json.loads(key_json) if key_json is not None else None
    result["record"] = json.loads(result.pop("dataJson"))
    return result


def _execute(ctx: Dict[str, Any], operation: str, powershell_path: str, dynomax_root: str) -> Dict[str, Any]:
    _reject_sensitive_inputs(ctx)
    project_id, environment_key = _runtime_identity(ctx)
    collection = _normalized_collection(_get(ctx, "collection", required=True))
    scope = _scope(_get(ctx, "scope", "Environment"))
    key_input = _get(ctx, "key")
    key_json = None if key_input is None else _canonical_object(key_input, "key")
    payload: Dict[str, Any] = {
        "operation": operation,
        "dynomaxRoot": os.path.abspath(str(dynomax_root)),
        "projectId": project_id,
        "environmentKey": environment_key,
        "collection": collection,
        "scope": scope,
        "keyJson": key_json,
        "keySha256": _sha256(key_json if key_json is not None else "null"),
    }
    if operation == "workspace.records.query":
        after = _utc_text(_get(ctx, "observedAfterUtc"), "observedAfterUtc")
        before = _utc_text(_get(ctx, "observedBeforeUtc"), "observedBeforeUtc")
        max_age = _bounded_int(_get(ctx, "maxAgeMinutes", 0), 0, 0, 525600, "maxAgeMinutes")
        if max_age:
            cutoff = dt.datetime.now(dt.timezone.utc) - dt.timedelta(minutes=max_age)
            age_after = cutoff.isoformat(timespec="microseconds").replace("+00:00", "Z")
            if after is None or after < age_after:
                after = age_after
        include_expired_raw = _get(ctx, "includeExpired", False)
        include_expired = include_expired_raw if isinstance(include_expired_raw, bool) else str(include_expired_raw).strip().lower() in {"1", "true", "yes", "on"}
        payload.update({"observedAfterUtc": after, "observedBeforeUtc": before, "maxRows": _bounded_int(_get(ctx, "maxRows", 100), 100, 1, 500, "maxRows"), "includeExpired": include_expired})
    elif operation == "workspace.records.get":
        payload["recordKey"] = _normalized_key(_get(ctx, "recordKey", required=True), "recordKey")
    elif operation == "workspace.records.append":
        data_json = _canonical_object(_get(ctx, "record", required=True), "record")
        payload.update({
            "dataJson": data_json,
            "dataSha256": _sha256(data_json),
            "appendIdempotencyKey": None if _get(ctx, "appendIdempotencyKey") in (None, "") else _normalized_key(_get(ctx, "appendIdempotencyKey"), "appendIdempotencyKey"),
            "observedAtUtc": _utc_text(_get(ctx, "observedAtUtc"), "observedAtUtc", default_now=True),
            "expiresAtUtc": _utc_text(_get(ctx, "expiresAtUtc"), "expiresAtUtc"),
        })
    elif operation == "workspace.records.upsert":
        data_json = _canonical_object(_get(ctx, "record", required=True), "record")
        payload.update({
            "recordKey": _normalized_key(_get(ctx, "recordKey", required=True), "recordKey"),
            "dataJson": data_json,
            "dataSha256": _sha256(data_json),
            "expectedVersion": _bounded_int(_get(ctx, "expectedVersion", -1), -1, -1, 2_147_483_647, "expectedVersion"),
            "expiresAtUtc": _utc_text(_get(ctx, "expiresAtUtc"), "expiresAtUtc"),
        })
    else:
        raise ValueError("Unsupported Workspace durable-record operation.")

    encoded = base64.b64encode(_powershell_script().encode("utf-16le")).decode("ascii")
    completed = subprocess.run(
        [str(powershell_path), "-NoLogo", "-NoProfile", "-NonInteractive", "-EncodedCommand", encoded],
        input=json.dumps(payload, ensure_ascii=False, separators=(",", ":")),
        capture_output=True,
        text=True,
        timeout=130,
        encoding="utf-8",
        errors="replace",
    )
    if completed.returncode != 0:
        raise RuntimeError((completed.stderr or "Workspace durable-record operation failed.")[:4096])
    raw = completed.stdout.strip()
    if len(raw) > _MAX_JSON_CHARS * 4:
        raise ValueError("Workspace durable-record result exceeds the Built-in Action size limit.")
    result = json.loads(raw or "{}")
    if operation == "workspace.records.query":
        records = [_decode_record(item) for item in (result.get("records") or [])]
        _set(ctx, "records", records)
        _set(ctx, "recordCount", len(records))
    elif operation == "workspace.records.get":
        record = _decode_record(result.get("record"))
        _set(ctx, "found", record is not None)
        _set(ctx, "record", record)
    elif operation == "workspace.records.append":
        _set(ctx, "record", _decode_record(result.get("record")))
        _set(ctx, "wasDuplicate", bool(result.get("wasDuplicate", False)))
    else:
        _set(ctx, "record", _decode_record(result.get("record")))
        _set(ctx, "created", bool(result.get("created", False)))
        _set(ctx, "changed", bool(result.get("changed", False)))
    return ctx


@library(scope="GLOBAL", auto_keywords=False)
class DynomaxBuiltInWorkspaceRecords:
    @keyword("Execute Dynomax Workspace Records Operation")
    def execute(self, operation: str, context_path: str, powershell_path: str, dynomax_root: str) -> None:
        context = _load(str(context_path))
        _execute(context, str(operation), str(powershell_path), str(dynomax_root))
        _save(str(context_path), context)
""";

    private const string WorkspaceRecordsRuntimeLibraryV2 = """
from __future__ import annotations

import datetime as dt
import hashlib
import json
import os
import re
import subprocess
import tempfile
from typing import Any, Dict

from robot.api.deco import keyword, library

_MAX_JSON_CHARS = 1_048_576
_COLLECTION_RE = re.compile(r"^[A-Za-z0-9][A-Za-z0-9._-]{0,99}$")
_KEY_RE = re.compile(r"^[A-Za-z0-9][A-Za-z0-9._:/-]{0,199}$")


def _load(path: str) -> Dict[str, Any]:
    with open(path, "r", encoding="utf-8") as stream:
        value = json.load(stream)
    if not isinstance(value, dict):
        raise RuntimeError("Dynomax runtime context is invalid.")
    return value


def _save(path: str, context: Dict[str, Any]) -> None:
    target = os.path.abspath(path)
    fd, temp_name = tempfile.mkstemp(prefix=".dynomax-workspace-records-", suffix=".tmp", dir=os.path.dirname(target))
    try:
        with os.fdopen(fd, "w", encoding="utf-8", newline="\n") as stream:
            json.dump(context, stream, ensure_ascii=False, indent=2, default=str)
            stream.write("\n")
        os.replace(temp_name, target)
    except Exception:
        try:
            os.unlink(temp_name)
        except OSError:
            pass
        raise


def _values(ctx: Dict[str, Any]) -> Dict[str, Any]:
    values = ctx.setdefault("values", {})
    if not isinstance(values, dict):
        raise RuntimeError("Dynomax runtime context values are invalid.")
    return values


def _get(ctx: Dict[str, Any], name: str, default: Any = None, *, required: bool = False) -> Any:
    value = _values(ctx).get(name, default)
    if required and (value is None or (isinstance(value, str) and value.strip() == "")):
        raise ValueError(f"Required Built-in Action input '{name}' is missing.")
    return value


def _set(ctx: Dict[str, Any], name: str, value: Any) -> None:
    _values(ctx)[name] = value
    secret_keys = {str(item) for item in (ctx.get("secretKeys") or []) if str(item).strip()}
    secret_keys.discard(name)
    ctx["secretKeys"] = sorted(secret_keys)


def _reject_sensitive_inputs(ctx: Dict[str, Any]) -> None:
    secret_keys = {str(item) for item in (ctx.get("secretKeys") or []) if str(item).strip()}
    guarded = {
        "collection", "scope", "key", "recordKey", "record", "appendIdempotencyKey",
        "observedAtUtc", "observedAfterUtc", "observedBeforeUtc", "maxAgeMinutes",
        "maxRows", "includeExpired", "expectedVersion", "expiresAtUtc"
    }
    if secret_keys.intersection(guarded):
        raise ValueError("Workspace durable records accept Normal-classification inputs only.")


def _canonical_json(value: Any) -> str:
    if isinstance(value, str):
        if len(value) > _MAX_JSON_CHARS:
            raise ValueError("JSON input exceeds the 1 MiB Built-in Action limit.")
        try:
            value = json.loads(value)
        except json.JSONDecodeError:
            pass
    rendered = json.dumps(value, ensure_ascii=False, sort_keys=True, separators=(",", ":"), default=str)
    if len(rendered.encode("utf-8")) > _MAX_JSON_CHARS:
        raise ValueError("JSON input exceeds the 1 MiB Built-in Action limit.")
    return rendered


def _canonical_object(value: Any, label: str) -> str:
    if isinstance(value, str):
        if len(value) > _MAX_JSON_CHARS:
            raise ValueError("JSON input exceeds the 1 MiB Built-in Action limit.")
        value = json.loads(value)
    if not isinstance(value, dict):
        raise ValueError(f"{label} must be a JSON object.")
    return _canonical_json(value)


def _sha256(text: str) -> str:
    return hashlib.sha256(text.encode("utf-8")).hexdigest()


def _normalized_collection(value: Any) -> str:
    text = str(value or "").strip().lower()
    if not _COLLECTION_RE.fullmatch(text):
        raise ValueError("Collection must be 1-100 characters using letters, digits, '.', '_' or '-'.")
    return text


def _normalized_key(value: Any, label: str) -> str:
    text = str(value or "").strip().lower()
    if not _KEY_RE.fullmatch(text):
        raise ValueError(f"{label} must be 1-200 characters using a bounded stable-key character set.")
    return text


def _scope(value: Any) -> str:
    text = str(value or "Environment").strip().lower()
    if text == "environment":
        return "Environment"
    if text == "workspace":
        return "Workspace"
    raise ValueError("Scope must be Environment or Workspace.")


def _utc_text(value: Any, label: str, *, default_now: bool = False) -> str | None:
    if value is None or str(value).strip() == "":
        if not default_now:
            return None
        parsed = dt.datetime.now(dt.timezone.utc)
    else:
        text = str(value).strip()
        if text.endswith("Z"):
            text = text[:-1] + "+00:00"
        try:
            parsed = dt.datetime.fromisoformat(text)
        except ValueError as exc:
            raise ValueError(f"{label} must be an ISO-8601 timestamp.") from exc
        if parsed.tzinfo is None:
            parsed = parsed.replace(tzinfo=dt.timezone.utc)
        parsed = parsed.astimezone(dt.timezone.utc)
    return parsed.isoformat(timespec="microseconds").replace("+00:00", "Z")


def _bounded_int(value: Any, default: int, minimum: int, maximum: int, label: str) -> int:
    if value is None or str(value).strip() == "":
        parsed = default
    else:
        parsed = int(value)
    if parsed < minimum or parsed > maximum:
        raise ValueError(f"{label} must be between {minimum} and {maximum}.")
    return parsed


def _runtime_identity(ctx: Dict[str, Any]) -> tuple[str, str]:
    runtime = ctx.get("runtimeValues") or {}
    if not isinstance(runtime, dict):
        raise RuntimeError("Dynomax runtime identity is unavailable.")
    project_id = str(runtime.get("ProjectId") or "").strip()
    environment_key = str(runtime.get("EnvironmentKey") or "").strip()
    if not project_id or not environment_key:
        raise RuntimeError("Dynomax runtime ProjectId/EnvironmentKey identity is unavailable.")
    return project_id, environment_key


def _powershell_script() -> str:
    return r'''$ErrorActionPreference='Stop'
Set-StrictMode -Version Latest
$payload=[Console]::In.ReadToEnd() | ConvertFrom-Json
$root=[System.IO.Path]::GetFullPath([string]$payload.dynomaxRoot)
$configPath=Join-Path $root 'dynomax.json'
if(-not(Test-Path -LiteralPath $configPath -PathType Leaf)){throw 'Dynomax runtime configuration was not found.'}
. (Join-Path $root 'Core\Common\Dynomax.Common.ps1')
. (Join-Path $root 'Core\Database\Dynomax.Database.ps1')
$config=Read-DynomaxJson -Path $configPath
$sqlConfigPath=Resolve-DynomaxPath -Root $root -ConfiguredPath $config.paths.databaseConfig
$databaseConfig=Read-DynomaxJson -Path $sqlConfigPath
$conn=Open-DynomaxConnection -SqlConfig $databaseConfig.sql

function Convert-RecordRow($row){
  if($null -eq $row){return $null}
  function V($name){$v=$row.$name;if($null -eq $v -or $v -is [DBNull]){return $null};return $v}
  function T($name){$v=V $name;if($null -eq $v){return $null};if($v -is [DateTime]){return $v.ToString('yyyy-MM-ddTHH:mm:ss.fffffffZ')};return [string]$v}
  return [ordered]@{
    id=[string](V 'Id'); collection=[string](V 'CollectionName'); scope=[string](V 'Scope'); recordKey=V 'RecordKey';
    keyJson=V 'KeyJson'; dataJson=[string](V 'DataJson'); observedAtUtc=T 'ObservedAtUtc'; createdAtUtc=T 'CreatedAtUtc';
    updatedAtUtc=T 'UpdatedAtUtc'; version=[int](V 'Version'); expiresAtUtc=T 'ExpiresAtUtc'
  }
}
function Rows($sql,[hashtable]$params,$tx=$null){return Invoke-DynomaxSqlRows -Connection $conn -CommandText $sql -Parameters $params -Transaction $tx -CommandTimeoutSeconds 120}
function Scalar($sql,[hashtable]$params,$tx=$null){return Invoke-DynomaxSqlScalar -Connection $conn -CommandText $sql -Parameters $params -Transaction $tx -CommandTimeoutSeconds 120}
function Exec($sql,[hashtable]$params,$tx=$null){return Invoke-DynomaxSqlNonQuery -Connection $conn -CommandText $sql -Parameters $params -Transaction $tx -CommandTimeoutSeconds 120}
function FirstRow($table){if($null -eq $table -or $table.Rows.Count -eq 0){return $null};return $table.Rows[0]}

try {
  $projectId=[Guid]::Parse([string]$payload.projectId)
  $projectExists=Scalar 'SELECT COUNT_BIG(1) FROM [DynomaxV2].[Projects] WHERE [Id]=@ProjectId' @{ '@ProjectId'=$projectId }
  if([int64]$projectExists -ne 1){throw 'Runtime Workspace project identity was not found.'}
  $environmentId=$null
  if([string]$payload.scope -eq 'Environment'){
    $environmentId=Scalar 'SELECT TOP(1) [Id] FROM [DynomaxV2].[ProjectEnvironments] WHERE [ProjectId]=@ProjectId AND [Key]=@EnvironmentKey AND [IsActive]=1' @{ '@ProjectId'=$projectId; '@EnvironmentKey'=[string]$payload.environmentKey }
    if($null -eq $environmentId -or $environmentId -is [DBNull]){throw 'Runtime Workspace environment identity was not found.'}
    $environmentId=[Guid]$environmentId
  }
  $baseParams=@{ '@ProjectId'=$projectId; '@Collection'=[string]$payload.collection; '@Scope'=[string]$payload.scope }
  $scopePredicate=if([string]$payload.scope -eq 'Environment'){'[ProjectEnvironmentId]=@EnvironmentId'}else{'[ProjectEnvironmentId] IS NULL'}
  if($environmentId){$baseParams['@EnvironmentId']=$environmentId}
  $select='SELECT [Id],[CollectionName],[Scope],[RecordKey],[KeyJson],[DataJson],[ObservedAtUtc],[CreatedAtUtc],[UpdatedAtUtc],[Version],[ExpiresAtUtc] FROM [DynomaxV2].[WorkspaceDataRecords]'

  switch([string]$payload.operation){
    'workspace.records.query' {
      $p=@{};$baseParams.Keys|ForEach-Object{$p[$_]=$baseParams[$_]}
      $where="[ProjectId]=@ProjectId AND [CollectionName]=@Collection AND [Scope]=@Scope AND $scopePredicate"
      if($payload.keyJson){$where+=' AND [KeySha256]=@KeySha256 AND [KeyJson]=@KeyJson';$p['@KeySha256']=[string]$payload.keySha256;$p['@KeyJson']=[string]$payload.keyJson}
      if($payload.observedAfterUtc){$where+=' AND [ObservedAtUtc]>=@ObservedAfterUtc';$p['@ObservedAfterUtc']=[DateTime]::Parse([string]$payload.observedAfterUtc).ToUniversalTime()}
      if($payload.observedBeforeUtc){$where+=' AND [ObservedAtUtc]<@ObservedBeforeUtc';$p['@ObservedBeforeUtc']=[DateTime]::Parse([string]$payload.observedBeforeUtc).ToUniversalTime()}
      if(-not [bool]$payload.includeExpired){$where+=' AND ([ExpiresAtUtc] IS NULL OR [ExpiresAtUtc]>SYSUTCDATETIME())'}
      $limit=[Math]::Max(1,[Math]::Min(500,[int]$payload.maxRows));$p['@MaxRows']=$limit
      $table=Rows ("SELECT TOP (@MaxRows) [Id],[CollectionName],[Scope],[RecordKey],[KeyJson],[DataJson],[ObservedAtUtc],[CreatedAtUtc],[UpdatedAtUtc],[Version],[ExpiresAtUtc] FROM [DynomaxV2].[WorkspaceDataRecords] WHERE $where ORDER BY [ObservedAtUtc] DESC,[CreatedAtUtc] DESC,[Id] DESC") $p
      $records=@();foreach($row in $table.Rows){$records+=,(Convert-RecordRow $row)}
      [ordered]@{records=$records}|ConvertTo-Json -Depth 20 -Compress
    }
    'workspace.records.get' {
      $p=@{};$baseParams.Keys|ForEach-Object{$p[$_]=$baseParams[$_]};$p['@RecordKey']=[string]$payload.recordKey
      $table=Rows ("$select WHERE [ProjectId]=@ProjectId AND [CollectionName]=@Collection AND [Scope]=@Scope AND $scopePredicate AND [RecordKey]=@RecordKey AND ([ExpiresAtUtc] IS NULL OR [ExpiresAtUtc]>SYSUTCDATETIME())") $p
      [ordered]@{record=Convert-RecordRow (FirstRow $table)}|ConvertTo-Json -Depth 20 -Compress
    }
    'workspace.records.append' {
      $tx=$conn.BeginTransaction([System.Data.IsolationLevel]::Serializable)
      try {
        $p=@{};$baseParams.Keys|ForEach-Object{$p[$_]=$baseParams[$_]}
        if($payload.appendIdempotencyKey){
          $p['@AppendKey']=[string]$payload.appendIdempotencyKey
          $existing=Rows ("SELECT [Id],[CollectionName],[Scope],[RecordKey],[KeyJson],[DataJson],[ObservedAtUtc],[CreatedAtUtc],[UpdatedAtUtc],[Version],[ExpiresAtUtc],[KeySha256],[DataSha256] FROM [DynomaxV2].[WorkspaceDataRecords] WITH (UPDLOCK,HOLDLOCK) WHERE [ProjectId]=@ProjectId AND [CollectionName]=@Collection AND [Scope]=@Scope AND $scopePredicate AND [AppendIdempotencyKey]=@AppendKey") $p $tx
          $existingRow=FirstRow $existing
          if($existingRow){
            $same=([string]$existingRow.KeySha256 -eq [string]$payload.keySha256) -and ([string]$existingRow.DataSha256 -eq [string]$payload.dataSha256) -and ([string]$existingRow.KeyJson -eq [string]$payload.keyJson) -and ([string]$existingRow.DataJson -eq [string]$payload.dataJson)
            $same=$same -and ([DateTime]$existingRow.ObservedAtUtc -eq [DateTime]::Parse([string]$payload.observedAtUtc).ToUniversalTime())
            $existingExpiry=if($existingRow.ExpiresAtUtc -is [DBNull]){$null}else{$existingRow.ExpiresAtUtc}
            $requestedExpiry=if($payload.expiresAtUtc){[DateTime]::Parse([string]$payload.expiresAtUtc).ToUniversalTime()}else{$null}
            if(($null -eq $existingExpiry) -xor ($null -eq $requestedExpiry)){$same=$false}elseif($null -ne $existingExpiry -and [DateTime]$existingExpiry -ne $requestedExpiry){$same=$false}
            if(-not $same){throw 'Append idempotency key already exists with different durable record content.'}
            $tx.Commit();[ordered]@{record=Convert-RecordRow $existingRow;wasDuplicate=$true}|ConvertTo-Json -Depth 20 -Compress;break
          }
        }
        $id=[Guid]::NewGuid();$now=[DateTime]::UtcNow
        $p['@EnvironmentId']=if($environmentId){$environmentId}else{[DBNull]::Value};$p['@Id']=$id;$p['@RecordKey']=[DBNull]::Value;$p['@AppendKey']=if($payload.appendIdempotencyKey){[string]$payload.appendIdempotencyKey}else{[DBNull]::Value};$p['@KeyJson']=if($payload.keyJson){[string]$payload.keyJson}else{[DBNull]::Value};$p['@KeySha256']=[string]$payload.keySha256;$p['@DataJson']=[string]$payload.dataJson;$p['@DataSha256']=[string]$payload.dataSha256;$p['@ObservedAtUtc']=[DateTime]::Parse([string]$payload.observedAtUtc).ToUniversalTime();$p['@Now']=$now;$p['@ExpiresAtUtc']=if($payload.expiresAtUtc){[DateTime]::Parse([string]$payload.expiresAtUtc).ToUniversalTime()}else{[DBNull]::Value}
        [void](Exec 'INSERT INTO [DynomaxV2].[WorkspaceDataRecords] ([Id],[ProjectId],[ProjectEnvironmentId],[CollectionName],[Scope],[RecordKey],[AppendIdempotencyKey],[KeyJson],[KeySha256],[DataJson],[DataSha256],[ObservedAtUtc],[CreatedAtUtc],[UpdatedAtUtc],[Version],[ExpiresAtUtc]) VALUES (@Id,@ProjectId,@EnvironmentId,@Collection,@Scope,@RecordKey,@AppendKey,@KeyJson,@KeySha256,@DataJson,@DataSha256,@ObservedAtUtc,@Now,@Now,1,@ExpiresAtUtc)' $p $tx)
        $read=Rows ("$select WHERE [Id]=@Id") @{ '@Id'=$id } $tx;$row=FirstRow $read;$tx.Commit();[ordered]@{record=Convert-RecordRow $row;wasDuplicate=$false}|ConvertTo-Json -Depth 20 -Compress
      } catch {try{$tx.Rollback()}catch{};throw} finally {$tx.Dispose()}
    }
    'workspace.records.upsert' {
      $tx=$conn.BeginTransaction([System.Data.IsolationLevel]::Serializable)
      try {
        $p=@{};$baseParams.Keys|ForEach-Object{$p[$_]=$baseParams[$_]};$p['@RecordKey']=[string]$payload.recordKey
        $existing=Rows ("SELECT [Id],[CollectionName],[Scope],[RecordKey],[KeyJson],[DataJson],[ObservedAtUtc],[CreatedAtUtc],[UpdatedAtUtc],[Version],[ExpiresAtUtc],[KeySha256],[DataSha256] FROM [DynomaxV2].[WorkspaceDataRecords] WITH (UPDLOCK,HOLDLOCK) WHERE [ProjectId]=@ProjectId AND [CollectionName]=@Collection AND [Scope]=@Scope AND $scopePredicate AND [RecordKey]=@RecordKey") $p $tx
        $row=FirstRow $existing;$expected=[int]$payload.expectedVersion
        if($row){
          if($expected -eq 0){throw 'Stable durable record already exists but expectedVersion requires absence.'}
          if($expected -gt 0 -and [int]$row.Version -ne $expected){throw "Stable durable record version conflict. Expected $expected but found $($row.Version)."}
          $same=([string]$row.KeySha256 -eq [string]$payload.keySha256) -and ([string]$row.DataSha256 -eq [string]$payload.dataSha256) -and ([string]$row.KeyJson -eq [string]$payload.keyJson) -and ([string]$row.DataJson -eq [string]$payload.dataJson)
          $existingExpiry=if($row.ExpiresAtUtc -is [DBNull]){$null}else{$row.ExpiresAtUtc};$requestedExpiry=if($payload.expiresAtUtc){[DateTime]::Parse([string]$payload.expiresAtUtc).ToUniversalTime()}else{$null}
          if(($null -eq $existingExpiry) -xor ($null -eq $requestedExpiry)){$same=$false}elseif($null -ne $existingExpiry -and [DateTime]$existingExpiry -ne $requestedExpiry){$same=$false}
          if($same){$tx.Commit();[ordered]@{record=Convert-RecordRow $row;created=$false;changed=$false}|ConvertTo-Json -Depth 20 -Compress;break}
          $u=@{ '@Id'=[Guid]$row.Id; '@KeyJson'=if($payload.keyJson){[string]$payload.keyJson}else{[DBNull]::Value}; '@KeySha256'=[string]$payload.keySha256; '@DataJson'=[string]$payload.dataJson; '@DataSha256'=[string]$payload.dataSha256; '@ExpiresAtUtc'=if($payload.expiresAtUtc){[DateTime]::Parse([string]$payload.expiresAtUtc).ToUniversalTime()}else{[DBNull]::Value}; '@Now'=[DateTime]::UtcNow }
          [void](Exec 'UPDATE [DynomaxV2].[WorkspaceDataRecords] SET [KeyJson]=@KeyJson,[KeySha256]=@KeySha256,[DataJson]=@DataJson,[DataSha256]=@DataSha256,[ObservedAtUtc]=@Now,[UpdatedAtUtc]=@Now,[Version]=[Version]+1,[ExpiresAtUtc]=@ExpiresAtUtc WHERE [Id]=@Id' $u $tx)
          $read=Rows ("$select WHERE [Id]=@Id") @{ '@Id'=[Guid]$row.Id } $tx;$updated=FirstRow $read;$tx.Commit();[ordered]@{record=Convert-RecordRow $updated;created=$false;changed=$true}|ConvertTo-Json -Depth 20 -Compress
        } else {
          if($expected -gt 0){throw "Stable durable record does not exist but expectedVersion requires version $expected."}
          $id=[Guid]::NewGuid();$now=[DateTime]::UtcNow;$i=@{};$baseParams.Keys|ForEach-Object{$i[$_]=$baseParams[$_]};$i['@EnvironmentId']=if($environmentId){$environmentId}else{[DBNull]::Value};$i['@Id']=$id;$i['@RecordKey']=[string]$payload.recordKey;$i['@AppendKey']=[DBNull]::Value;$i['@KeyJson']=if($payload.keyJson){[string]$payload.keyJson}else{[DBNull]::Value};$i['@KeySha256']=[string]$payload.keySha256;$i['@DataJson']=[string]$payload.dataJson;$i['@DataSha256']=[string]$payload.dataSha256;$i['@ObservedAtUtc']=$now;$i['@Now']=$now;$i['@ExpiresAtUtc']=if($payload.expiresAtUtc){[DateTime]::Parse([string]$payload.expiresAtUtc).ToUniversalTime()}else{[DBNull]::Value}
          [void](Exec 'INSERT INTO [DynomaxV2].[WorkspaceDataRecords] ([Id],[ProjectId],[ProjectEnvironmentId],[CollectionName],[Scope],[RecordKey],[AppendIdempotencyKey],[KeyJson],[KeySha256],[DataJson],[DataSha256],[ObservedAtUtc],[CreatedAtUtc],[UpdatedAtUtc],[Version],[ExpiresAtUtc]) VALUES (@Id,@ProjectId,@EnvironmentId,@Collection,@Scope,@RecordKey,@AppendKey,@KeyJson,@KeySha256,@DataJson,@DataSha256,@ObservedAtUtc,@Now,@Now,1,@ExpiresAtUtc)' $i $tx)
          $read=Rows ("$select WHERE [Id]=@Id") @{ '@Id'=$id } $tx;$createdRow=FirstRow $read;$tx.Commit();[ordered]@{record=Convert-RecordRow $createdRow;created=$true;changed=$true}|ConvertTo-Json -Depth 20 -Compress
        }
      } catch {try{$tx.Rollback()}catch{};throw} finally {$tx.Dispose()}
    }
    default {throw 'Unsupported Workspace durable-record operation.'}
  }
} finally {if($conn){$conn.Dispose()}}'''


def _decode_record(item: Any) -> Any:
    if item is None:
        return None
    result = dict(item)
    key_json = result.pop("keyJson", None)
    result["key"] = json.loads(key_json) if key_json is not None else None
    result["record"] = json.loads(result.pop("dataJson"))
    return result


def _execute(ctx: Dict[str, Any], operation: str, powershell_path: str, dynomax_root: str) -> Dict[str, Any]:
    _reject_sensitive_inputs(ctx)
    project_id, environment_key = _runtime_identity(ctx)
    collection = _normalized_collection(_get(ctx, "collection", required=True))
    scope = _scope(_get(ctx, "scope", "Environment"))
    key_input = _get(ctx, "key")
    key_json = None if key_input is None else _canonical_object(key_input, "key")
    payload: Dict[str, Any] = {
        "operation": operation,
        "dynomaxRoot": os.path.abspath(str(dynomax_root)),
        "projectId": project_id,
        "environmentKey": environment_key,
        "collection": collection,
        "scope": scope,
        "keyJson": key_json,
        "keySha256": _sha256(key_json if key_json is not None else "null"),
    }
    if operation == "workspace.records.query":
        after = _utc_text(_get(ctx, "observedAfterUtc"), "observedAfterUtc")
        before = _utc_text(_get(ctx, "observedBeforeUtc"), "observedBeforeUtc")
        max_age = _bounded_int(_get(ctx, "maxAgeMinutes", 0), 0, 0, 525600, "maxAgeMinutes")
        if max_age:
            cutoff = dt.datetime.now(dt.timezone.utc) - dt.timedelta(minutes=max_age)
            age_after = cutoff.isoformat(timespec="microseconds").replace("+00:00", "Z")
            if after is None or after < age_after:
                after = age_after
        include_expired_raw = _get(ctx, "includeExpired", False)
        include_expired = include_expired_raw if isinstance(include_expired_raw, bool) else str(include_expired_raw).strip().lower() in {"1", "true", "yes", "on"}
        payload.update({"observedAfterUtc": after, "observedBeforeUtc": before, "maxRows": _bounded_int(_get(ctx, "maxRows", 100), 100, 1, 500, "maxRows"), "includeExpired": include_expired})
    elif operation == "workspace.records.get":
        payload["recordKey"] = _normalized_key(_get(ctx, "recordKey", required=True), "recordKey")
    elif operation == "workspace.records.append":
        data_json = _canonical_object(_get(ctx, "record", required=True), "record")
        payload.update({
            "dataJson": data_json,
            "dataSha256": _sha256(data_json),
            "appendIdempotencyKey": None if _get(ctx, "appendIdempotencyKey") in (None, "") else _normalized_key(_get(ctx, "appendIdempotencyKey"), "appendIdempotencyKey"),
            "observedAtUtc": _utc_text(_get(ctx, "observedAtUtc"), "observedAtUtc", default_now=True),
            "expiresAtUtc": _utc_text(_get(ctx, "expiresAtUtc"), "expiresAtUtc"),
        })
    elif operation == "workspace.records.upsert":
        data_json = _canonical_object(_get(ctx, "record", required=True), "record")
        payload.update({
            "recordKey": _normalized_key(_get(ctx, "recordKey", required=True), "recordKey"),
            "dataJson": data_json,
            "dataSha256": _sha256(data_json),
            "expectedVersion": _bounded_int(_get(ctx, "expectedVersion", -1), -1, -1, 2_147_483_647, "expectedVersion"),
            "expiresAtUtc": _utc_text(_get(ctx, "expiresAtUtc"), "expiresAtUtc"),
        })
    else:
        raise ValueError("Unsupported Workspace durable-record operation.")

    script_fd, script_path = tempfile.mkstemp(prefix=".dynomax-workspace-records-", suffix=".ps1")
    try:
        with os.fdopen(script_fd, "w", encoding="utf-8", newline="\n") as stream:
            stream.write(_powershell_script())
        completed = subprocess.run(
            [str(powershell_path), "-NoLogo", "-NoProfile", "-NonInteractive", "-ExecutionPolicy", "Bypass", "-File", script_path],
            input=json.dumps(payload, ensure_ascii=False, separators=(",", ":")),
            capture_output=True,
            text=True,
            timeout=130,
            encoding="utf-8",
            errors="replace",
        )
    finally:
        try:
            os.unlink(script_path)
        except OSError:
            pass
    if completed.returncode != 0:
        raise RuntimeError((completed.stderr or "Workspace durable-record operation failed.")[:4096])
    raw = completed.stdout.strip()
    if len(raw) > _MAX_JSON_CHARS * 4:
        raise ValueError("Workspace durable-record result exceeds the Built-in Action size limit.")
    result = json.loads(raw or "{}")
    if operation == "workspace.records.query":
        records = [_decode_record(item) for item in (result.get("records") or [])]
        _set(ctx, "records", records)
        _set(ctx, "recordCount", len(records))
    elif operation == "workspace.records.get":
        record = _decode_record(result.get("record"))
        _set(ctx, "found", record is not None)
        _set(ctx, "record", record)
    elif operation == "workspace.records.append":
        _set(ctx, "record", _decode_record(result.get("record")))
        _set(ctx, "wasDuplicate", bool(result.get("wasDuplicate", False)))
    else:
        _set(ctx, "record", _decode_record(result.get("record")))
        _set(ctx, "created", bool(result.get("created", False)))
        _set(ctx, "changed", bool(result.get("changed", False)))
    return ctx


@library(scope="GLOBAL", auto_keywords=False)
class DynomaxBuiltInWorkspaceRecords:
    @keyword("Execute Dynomax Workspace Records Operation")
    def execute(self, operation: str, context_path: str, powershell_path: str, dynomax_root: str) -> None:
        context = _load(str(context_path))
        _execute(context, str(operation), str(powershell_path), str(dynomax_root))
        _save(str(context_path), context)
""";

    private const string WorkspaceRecordsBatchRuntimeLibraryV1 = """
from __future__ import annotations

import datetime as dt
import hashlib
import json
import os
import re
import subprocess
import tempfile
from typing import Any, Dict, List

from robot.api.deco import keyword, library

_MAX_JSON_CHARS = 1_048_576
_MAX_BATCH_ITEMS = 500
_COLLECTION_RE = re.compile(r"^[A-Za-z0-9][A-Za-z0-9._-]{0,99}$")
_KEY_RE = re.compile(r"^[A-Za-z0-9][A-Za-z0-9._:/-]{0,199}$")


def _load(path: str) -> Dict[str, Any]:
    with open(path, "r", encoding="utf-8") as stream:
        value = json.load(stream)
    if not isinstance(value, dict):
        raise RuntimeError("Dynomax runtime context is invalid.")
    return value


def _save(path: str, context: Dict[str, Any]) -> None:
    target = os.path.abspath(path)
    fd, temp_name = tempfile.mkstemp(prefix=".dynomax-workspace-record-batches-", suffix=".tmp", dir=os.path.dirname(target))
    try:
        with os.fdopen(fd, "w", encoding="utf-8", newline="\n") as stream:
            json.dump(context, stream, ensure_ascii=False, indent=2, default=str)
            stream.write("\n")
        os.replace(temp_name, target)
    except Exception:
        try:
            os.unlink(temp_name)
        except OSError:
            pass
        raise


def _values(ctx: Dict[str, Any]) -> Dict[str, Any]:
    values = ctx.setdefault("values", {})
    if not isinstance(values, dict):
        raise RuntimeError("Dynomax runtime context values are invalid.")
    return values


def _get(ctx: Dict[str, Any], name: str, default: Any = None, *, required: bool = False) -> Any:
    value = _values(ctx).get(name, default)
    if required and (value is None or (isinstance(value, str) and value.strip() == "")):
        raise ValueError(f"Required Built-in Action input '{name}' is missing.")
    return value


def _set(ctx: Dict[str, Any], name: str, value: Any) -> None:
    _values(ctx)[name] = value
    secret_keys = {str(item) for item in (ctx.get("secretKeys") or []) if str(item).strip()}
    secret_keys.discard(name)
    ctx["secretKeys"] = sorted(secret_keys)


def _reject_sensitive_inputs(ctx: Dict[str, Any]) -> None:
    secret_keys = {str(item) for item in (ctx.get("secretKeys") or []) if str(item).strip()}
    guarded = {"collection", "scope", "recordKeys", "records", "includeExpired"}
    if secret_keys.intersection(guarded):
        raise ValueError("Workspace durable record batches accept Normal-classification inputs only.")


def _canonical_json(value: Any) -> str:
    if isinstance(value, str):
        if len(value) > _MAX_JSON_CHARS:
            raise ValueError("JSON input exceeds the 1 MiB Built-in Action limit.")
        value = json.loads(value)
    rendered = json.dumps(value, ensure_ascii=False, sort_keys=True, separators=(",", ":"), default=str)
    if len(rendered.encode("utf-8")) > _MAX_JSON_CHARS:
        raise ValueError("JSON input exceeds the 1 MiB Built-in Action limit.")
    return rendered


def _json_array(value: Any, label: str) -> List[Any]:
    if isinstance(value, str):
        if len(value) > _MAX_JSON_CHARS:
            raise ValueError("JSON input exceeds the 1 MiB Built-in Action limit.")
        value = json.loads(value)
    if not isinstance(value, list):
        raise ValueError(f"{label} must be a JSON array.")
    if len(value) > _MAX_BATCH_ITEMS:
        raise ValueError(f"{label} may contain at most {_MAX_BATCH_ITEMS} items.")
    _canonical_json(value)
    return value


def _canonical_object(value: Any, label: str) -> str:
    if isinstance(value, str):
        if len(value) > _MAX_JSON_CHARS:
            raise ValueError("JSON input exceeds the 1 MiB Built-in Action limit.")
        value = json.loads(value)
    if not isinstance(value, dict):
        raise ValueError(f"{label} must be a JSON object.")
    return _canonical_json(value)


def _sha256(text: str) -> str:
    return hashlib.sha256(text.encode("utf-8")).hexdigest()


def _normalized_collection(value: Any) -> str:
    text = str(value or "").strip().lower()
    if not _COLLECTION_RE.fullmatch(text):
        raise ValueError("Collection must be 1-100 characters using letters, digits, '.', '_' or '-'.")
    return text


def _normalized_key(value: Any, label: str) -> str:
    text = str(value or "").strip().lower()
    if not _KEY_RE.fullmatch(text):
        raise ValueError(f"{label} must be 1-200 characters using a bounded stable-key character set.")
    return text


def _scope(value: Any) -> str:
    text = str(value or "Environment").strip().lower()
    if text == "environment":
        return "Environment"
    if text == "workspace":
        return "Workspace"
    raise ValueError("Scope must be Environment or Workspace.")


def _utc_text(value: Any, label: str, *, default_now: bool = False) -> str | None:
    if value is None or str(value).strip() == "":
        if not default_now:
            return None
        parsed = dt.datetime.now(dt.timezone.utc)
    else:
        text = str(value).strip()
        if text.endswith("Z"):
            text = text[:-1] + "+00:00"
        try:
            parsed = dt.datetime.fromisoformat(text)
        except ValueError as exc:
            raise ValueError(f"{label} must be an ISO-8601 timestamp.") from exc
        if parsed.tzinfo is None:
            parsed = parsed.replace(tzinfo=dt.timezone.utc)
        parsed = parsed.astimezone(dt.timezone.utc)
    return parsed.isoformat(timespec="microseconds").replace("+00:00", "Z")


def _bounded_int(value: Any, default: int, minimum: int, maximum: int, label: str) -> int:
    if value is None or str(value).strip() == "":
        parsed = default
    else:
        parsed = int(value)
    if parsed < minimum or parsed > maximum:
        raise ValueError(f"{label} must be between {minimum} and {maximum}.")
    return parsed


def _runtime_identity(ctx: Dict[str, Any]) -> tuple[str, str]:
    runtime = ctx.get("runtimeValues") or {}
    if not isinstance(runtime, dict):
        raise RuntimeError("Dynomax runtime identity is unavailable.")
    project_id = str(runtime.get("ProjectId") or "").strip()
    environment_key = str(runtime.get("EnvironmentKey") or "").strip()
    if not project_id or not environment_key:
        raise RuntimeError("Dynomax runtime ProjectId/EnvironmentKey identity is unavailable.")
    return project_id, environment_key


def _prepare_get_many(ctx: Dict[str, Any], payload: Dict[str, Any]) -> None:
    raw = _json_array(_get(ctx, "recordKeys", required=True), "recordKeys")
    record_keys = [_normalized_key(item, f"recordKeys[{index}]") for index, item in enumerate(raw)]
    if len(set(record_keys)) != len(record_keys):
        raise ValueError("recordKeys must not contain duplicates within one batch.")
    include_expired_raw = _get(ctx, "includeExpired", False)
    include_expired = include_expired_raw if isinstance(include_expired_raw, bool) else str(include_expired_raw).strip().lower() in {"1", "true", "yes", "on"}
    payload.update({"recordKeys": record_keys, "includeExpired": include_expired})


def _prepare_append_many(ctx: Dict[str, Any], payload: Dict[str, Any]) -> None:
    raw = _json_array(_get(ctx, "records", required=True), "records")
    items: List[Dict[str, Any]] = []
    seen_append_keys: set[str] = set()
    for index, item in enumerate(raw):
        if not isinstance(item, dict):
            raise ValueError(f"records[{index}] must be a JSON object.")
        key_input = item.get("key")
        key_json = None if key_input is None else _canonical_object(key_input, f"records[{index}].key")
        data_json = _canonical_object(item.get("record"), f"records[{index}].record")
        append_key_raw = item.get("appendIdempotencyKey")
        append_key = None if append_key_raw in (None, "") else _normalized_key(append_key_raw, f"records[{index}].appendIdempotencyKey")
        if append_key is not None:
            if append_key in seen_append_keys:
                raise ValueError("appendIdempotencyKey values must be unique within one batch.")
            seen_append_keys.add(append_key)
        observed_raw = item.get("observedAtUtc")
        observed_provided = observed_raw is not None and str(observed_raw).strip() != ""
        items.append({
            "keyJson": key_json,
            "keySha256": _sha256(key_json if key_json is not None else "null"),
            "dataJson": data_json,
            "dataSha256": _sha256(data_json),
            "appendIdempotencyKey": append_key,
            "observedAtUtc": _utc_text(observed_raw, f"records[{index}].observedAtUtc", default_now=True),
            "observedAtProvided": observed_provided,
            "expiresAtUtc": _utc_text(item.get("expiresAtUtc"), f"records[{index}].expiresAtUtc"),
        })
    payload["items"] = items


def _prepare_upsert_many(ctx: Dict[str, Any], payload: Dict[str, Any]) -> None:
    raw = _json_array(_get(ctx, "records", required=True), "records")
    items: List[Dict[str, Any]] = []
    seen_record_keys: set[str] = set()
    for index, item in enumerate(raw):
        if not isinstance(item, dict):
            raise ValueError(f"records[{index}] must be a JSON object.")
        record_key = _normalized_key(item.get("recordKey"), f"records[{index}].recordKey")
        if record_key in seen_record_keys:
            raise ValueError("recordKey values must be unique within one batch.")
        seen_record_keys.add(record_key)
        key_input = item.get("key")
        key_json = None if key_input is None else _canonical_object(key_input, f"records[{index}].key")
        data_json = _canonical_object(item.get("record"), f"records[{index}].record")
        items.append({
            "recordKey": record_key,
            "keyJson": key_json,
            "keySha256": _sha256(key_json if key_json is not None else "null"),
            "dataJson": data_json,
            "dataSha256": _sha256(data_json),
            "expectedVersion": _bounded_int(item.get("expectedVersion", -1), -1, -1, 2_147_483_647, f"records[{index}].expectedVersion"),
            "expiresAtUtc": _utc_text(item.get("expiresAtUtc"), f"records[{index}].expiresAtUtc"),
        })
    payload["items"] = items


def _powershell_script() -> str:
    return r'''$ErrorActionPreference='Stop'
Set-StrictMode -Version Latest
$payload=[Console]::In.ReadToEnd() | ConvertFrom-Json
$root=[System.IO.Path]::GetFullPath([string]$payload.dynomaxRoot)
$configPath=Join-Path $root 'dynomax.json'
if(-not(Test-Path -LiteralPath $configPath -PathType Leaf)){throw 'Dynomax runtime configuration was not found.'}
. (Join-Path $root 'Core\Common\Dynomax.Common.ps1')
. (Join-Path $root 'Core\Database\Dynomax.Database.ps1')
$config=Read-DynomaxJson -Path $configPath
$sqlConfigPath=Resolve-DynomaxPath -Root $root -ConfiguredPath $config.paths.databaseConfig
$databaseConfig=Read-DynomaxJson -Path $sqlConfigPath
$conn=Open-DynomaxConnection -SqlConfig $databaseConfig.sql

function Convert-RecordRow($row){
  if($null -eq $row){return $null}
  function V($name){$v=$row.$name;if($null -eq $v -or $v -is [DBNull]){return $null};return $v}
  function T($name){$v=V $name;if($null -eq $v){return $null};if($v -is [DateTime]){return $v.ToString('yyyy-MM-ddTHH:mm:ss.fffffffZ')};return [string]$v}
  return [ordered]@{
    id=[string](V 'Id'); collection=[string](V 'CollectionName'); scope=[string](V 'Scope'); recordKey=V 'RecordKey';
    keyJson=V 'KeyJson'; dataJson=[string](V 'DataJson'); observedAtUtc=T 'ObservedAtUtc'; createdAtUtc=T 'CreatedAtUtc';
    updatedAtUtc=T 'UpdatedAtUtc'; version=[int](V 'Version'); expiresAtUtc=T 'ExpiresAtUtc'
  }
}
function Rows($sql,[hashtable]$params,$tx=$null){return Invoke-DynomaxSqlRows -Connection $conn -CommandText $sql -Parameters $params -Transaction $tx -CommandTimeoutSeconds 300}
function Scalar($sql,[hashtable]$params,$tx=$null){return Invoke-DynomaxSqlScalar -Connection $conn -CommandText $sql -Parameters $params -Transaction $tx -CommandTimeoutSeconds 300}
function Exec($sql,[hashtable]$params,$tx=$null){return Invoke-DynomaxSqlNonQuery -Connection $conn -CommandText $sql -Parameters $params -Transaction $tx -CommandTimeoutSeconds 300}
function FirstRow($table){if($null -eq $table -or $table.Rows.Count -eq 0){return $null};return $table.Rows[0]}
function Copy-Params([hashtable]$source){$target=@{};$source.Keys|ForEach-Object{$target[$_]=$source[$_]};return $target}

try {
  $projectId=[Guid]::Parse([string]$payload.projectId)
  $projectExists=Scalar 'SELECT COUNT_BIG(1) FROM [DynomaxV2].[Projects] WHERE [Id]=@ProjectId' @{ '@ProjectId'=$projectId }
  if([int64]$projectExists -ne 1){throw 'Runtime Workspace project identity was not found.'}
  $environmentId=$null
  if([string]$payload.scope -eq 'Environment'){
    $environmentId=Scalar 'SELECT TOP(1) [Id] FROM [DynomaxV2].[ProjectEnvironments] WHERE [ProjectId]=@ProjectId AND [Key]=@EnvironmentKey AND [IsActive]=1' @{ '@ProjectId'=$projectId; '@EnvironmentKey'=[string]$payload.environmentKey }
    if($null -eq $environmentId -or $environmentId -is [DBNull]){throw 'Runtime Workspace environment identity was not found.'}
    $environmentId=[Guid]$environmentId
  }
  $baseParams=@{ '@ProjectId'=$projectId; '@Collection'=[string]$payload.collection; '@Scope'=[string]$payload.scope }
  $scopePredicate=if([string]$payload.scope -eq 'Environment'){'[ProjectEnvironmentId]=@EnvironmentId'}else{'[ProjectEnvironmentId] IS NULL'}
  if($environmentId){$baseParams['@EnvironmentId']=$environmentId}
  $select='SELECT [Id],[CollectionName],[Scope],[RecordKey],[KeyJson],[DataJson],[ObservedAtUtc],[CreatedAtUtc],[UpdatedAtUtc],[Version],[ExpiresAtUtc] FROM [DynomaxV2].[WorkspaceDataRecords]'
  $selectHashes='SELECT [Id],[CollectionName],[Scope],[RecordKey],[KeyJson],[DataJson],[ObservedAtUtc],[CreatedAtUtc],[UpdatedAtUtc],[Version],[ExpiresAtUtc],[KeySha256],[DataSha256] FROM [DynomaxV2].[WorkspaceDataRecords]'

  switch([string]$payload.operation){
    'workspace.records.get-many' {
      $lookup=@{}
      foreach($recordKey in @($payload.recordKeys)){
        $p=Copy-Params $baseParams;$p['@RecordKey']=[string]$recordKey
        $expiry=if([bool]$payload.includeExpired){''}else{' AND ([ExpiresAtUtc] IS NULL OR [ExpiresAtUtc]>SYSUTCDATETIME())'}
        $row=FirstRow (Rows ("$select WHERE [ProjectId]=@ProjectId AND [CollectionName]=@Collection AND [Scope]=@Scope AND $scopePredicate AND [RecordKey]=@RecordKey$expiry") $p)
        $lookup[[string]$recordKey]=$row
      }
      $results=@();$found=0
      foreach($recordKey in @($payload.recordKeys)){
        $row=$lookup[[string]$recordKey]
        if($row){$found++}
        $results+=,[ordered]@{recordKey=[string]$recordKey;record=Convert-RecordRow $row}
      }
      [ordered]@{results=$results;foundCount=$found}|ConvertTo-Json -Depth 30 -Compress
    }
    'workspace.records.append-many' {
      $tx=$conn.BeginTransaction([System.Data.IsolationLevel]::Serializable)
      try {
        $results=@();$duplicateCount=0
        foreach($item in @($payload.items)){
          $p=Copy-Params $baseParams
          if($item.appendIdempotencyKey){
            $p['@AppendKey']=[string]$item.appendIdempotencyKey
            $existingRow=FirstRow (Rows ("$selectHashes WITH (UPDLOCK,HOLDLOCK) WHERE [ProjectId]=@ProjectId AND [CollectionName]=@Collection AND [Scope]=@Scope AND $scopePredicate AND [AppendIdempotencyKey]=@AppendKey") $p $tx)
            if($existingRow){
              $same=([string]$existingRow.KeySha256 -eq [string]$item.keySha256) -and ([string]$existingRow.DataSha256 -eq [string]$item.dataSha256) -and ([string]$existingRow.KeyJson -eq [string]$item.keyJson) -and ([string]$existingRow.DataJson -eq [string]$item.dataJson)
              if([bool]$item.observedAtProvided){$same=$same -and ([DateTime]$existingRow.ObservedAtUtc -eq [DateTime]::Parse([string]$item.observedAtUtc).ToUniversalTime())}
              $existingExpiry=if($existingRow.ExpiresAtUtc -is [DBNull]){$null}else{$existingRow.ExpiresAtUtc};$requestedExpiry=if($item.expiresAtUtc){[DateTime]::Parse([string]$item.expiresAtUtc).ToUniversalTime()}else{$null}
              if(($null -eq $existingExpiry) -xor ($null -eq $requestedExpiry)){$same=$false}elseif($null -ne $existingExpiry -and [DateTime]$existingExpiry -ne $requestedExpiry){$same=$false}
              if(-not $same){throw 'Append batch idempotency key already exists with different durable record content.'}
              $duplicateCount++;$results+=,[ordered]@{record=Convert-RecordRow $existingRow;wasDuplicate=$true};continue
            }
          }
          $id=[Guid]::NewGuid();$now=[DateTime]::UtcNow
          $p['@EnvironmentId']=if($environmentId){$environmentId}else{[DBNull]::Value};$p['@Id']=$id;$p['@RecordKey']=[DBNull]::Value;$p['@AppendKey']=if($item.appendIdempotencyKey){[string]$item.appendIdempotencyKey}else{[DBNull]::Value};$p['@KeyJson']=if($item.keyJson){[string]$item.keyJson}else{[DBNull]::Value};$p['@KeySha256']=[string]$item.keySha256;$p['@DataJson']=[string]$item.dataJson;$p['@DataSha256']=[string]$item.dataSha256;$p['@ObservedAtUtc']=[DateTime]::Parse([string]$item.observedAtUtc).ToUniversalTime();$p['@Now']=$now;$p['@ExpiresAtUtc']=if($item.expiresAtUtc){[DateTime]::Parse([string]$item.expiresAtUtc).ToUniversalTime()}else{[DBNull]::Value}
          [void](Exec 'INSERT INTO [DynomaxV2].[WorkspaceDataRecords] ([Id],[ProjectId],[ProjectEnvironmentId],[CollectionName],[Scope],[RecordKey],[AppendIdempotencyKey],[KeyJson],[KeySha256],[DataJson],[DataSha256],[ObservedAtUtc],[CreatedAtUtc],[UpdatedAtUtc],[Version],[ExpiresAtUtc]) VALUES (@Id,@ProjectId,@EnvironmentId,@Collection,@Scope,@RecordKey,@AppendKey,@KeyJson,@KeySha256,@DataJson,@DataSha256,@ObservedAtUtc,@Now,@Now,1,@ExpiresAtUtc)' $p $tx)
          $row=FirstRow (Rows ("$select WHERE [Id]=@Id") @{ '@Id'=$id } $tx)
          $results+=,[ordered]@{record=Convert-RecordRow $row;wasDuplicate=$false}
        }
        $tx.Commit();[ordered]@{results=$results;duplicateCount=$duplicateCount}|ConvertTo-Json -Depth 30 -Compress
      } catch {try{$tx.Rollback()}catch{};throw} finally {$tx.Dispose()}
    }
    'workspace.records.upsert-many' {
      $tx=$conn.BeginTransaction([System.Data.IsolationLevel]::Serializable)
      try {
        $results=@();$createdCount=0;$changedCount=0
        foreach($item in @($payload.items)){
          $p=Copy-Params $baseParams;$p['@RecordKey']=[string]$item.recordKey
          $row=FirstRow (Rows ("$selectHashes WITH (UPDLOCK,HOLDLOCK) WHERE [ProjectId]=@ProjectId AND [CollectionName]=@Collection AND [Scope]=@Scope AND $scopePredicate AND [RecordKey]=@RecordKey") $p $tx)
          $expected=[int]$item.expectedVersion
          if($row){
            if($expected -eq 0){throw 'Stable durable record already exists but batch expectedVersion requires absence.'}
            if($expected -gt 0 -and [int]$row.Version -ne $expected){throw "Stable durable record batch version conflict. Expected $expected but found $($row.Version)."}
            $same=([string]$row.KeySha256 -eq [string]$item.keySha256) -and ([string]$row.DataSha256 -eq [string]$item.dataSha256) -and ([string]$row.KeyJson -eq [string]$item.keyJson) -and ([string]$row.DataJson -eq [string]$item.dataJson)
            $existingExpiry=if($row.ExpiresAtUtc -is [DBNull]){$null}else{$row.ExpiresAtUtc};$requestedExpiry=if($item.expiresAtUtc){[DateTime]::Parse([string]$item.expiresAtUtc).ToUniversalTime()}else{$null}
            if(($null -eq $existingExpiry) -xor ($null -eq $requestedExpiry)){$same=$false}elseif($null -ne $existingExpiry -and [DateTime]$existingExpiry -ne $requestedExpiry){$same=$false}
            if($same){$results+=,[ordered]@{record=Convert-RecordRow $row;created=$false;changed=$false};continue}
            $u=@{ '@Id'=[Guid]$row.Id; '@KeyJson'=if($item.keyJson){[string]$item.keyJson}else{[DBNull]::Value}; '@KeySha256'=[string]$item.keySha256; '@DataJson'=[string]$item.dataJson; '@DataSha256'=[string]$item.dataSha256; '@ExpiresAtUtc'=if($item.expiresAtUtc){[DateTime]::Parse([string]$item.expiresAtUtc).ToUniversalTime()}else{[DBNull]::Value}; '@Now'=[DateTime]::UtcNow }
            [void](Exec 'UPDATE [DynomaxV2].[WorkspaceDataRecords] SET [KeyJson]=@KeyJson,[KeySha256]=@KeySha256,[DataJson]=@DataJson,[DataSha256]=@DataSha256,[ObservedAtUtc]=@Now,[UpdatedAtUtc]=@Now,[Version]=[Version]+1,[ExpiresAtUtc]=@ExpiresAtUtc WHERE [Id]=@Id' $u $tx)
            $updated=FirstRow (Rows ("$select WHERE [Id]=@Id") @{ '@Id'=[Guid]$row.Id } $tx);$changedCount++;$results+=,[ordered]@{record=Convert-RecordRow $updated;created=$false;changed=$true}
          } else {
            if($expected -gt 0){throw "Stable durable record does not exist but batch expectedVersion requires version $expected."}
            $id=[Guid]::NewGuid();$now=[DateTime]::UtcNow;$i=Copy-Params $baseParams;$i['@EnvironmentId']=if($environmentId){$environmentId}else{[DBNull]::Value};$i['@Id']=$id;$i['@RecordKey']=[string]$item.recordKey;$i['@AppendKey']=[DBNull]::Value;$i['@KeyJson']=if($item.keyJson){[string]$item.keyJson}else{[DBNull]::Value};$i['@KeySha256']=[string]$item.keySha256;$i['@DataJson']=[string]$item.dataJson;$i['@DataSha256']=[string]$item.dataSha256;$i['@ObservedAtUtc']=$now;$i['@Now']=$now;$i['@ExpiresAtUtc']=if($item.expiresAtUtc){[DateTime]::Parse([string]$item.expiresAtUtc).ToUniversalTime()}else{[DBNull]::Value}
            [void](Exec 'INSERT INTO [DynomaxV2].[WorkspaceDataRecords] ([Id],[ProjectId],[ProjectEnvironmentId],[CollectionName],[Scope],[RecordKey],[AppendIdempotencyKey],[KeyJson],[KeySha256],[DataJson],[DataSha256],[ObservedAtUtc],[CreatedAtUtc],[UpdatedAtUtc],[Version],[ExpiresAtUtc]) VALUES (@Id,@ProjectId,@EnvironmentId,@Collection,@Scope,@RecordKey,@AppendKey,@KeyJson,@KeySha256,@DataJson,@DataSha256,@ObservedAtUtc,@Now,@Now,1,@ExpiresAtUtc)' $i $tx)
            $created=FirstRow (Rows ("$select WHERE [Id]=@Id") @{ '@Id'=$id } $tx);$createdCount++;$changedCount++;$results+=,[ordered]@{record=Convert-RecordRow $created;created=$true;changed=$true}
          }
        }
        $tx.Commit();[ordered]@{results=$results;createdCount=$createdCount;changedCount=$changedCount}|ConvertTo-Json -Depth 30 -Compress
      } catch {try{$tx.Rollback()}catch{};throw} finally {$tx.Dispose()}
    }
    default {throw 'Unsupported Workspace durable-record batch operation.'}
  }
} finally {if($conn){$conn.Dispose()}}'''


def _decode_record(item: Any) -> Any:
    if item is None:
        return None
    result = dict(item)
    key_json = result.pop("keyJson", None)
    result["key"] = json.loads(key_json) if key_json is not None else None
    result["record"] = json.loads(result.pop("dataJson"))
    return result


def _execute(ctx: Dict[str, Any], operation: str, powershell_path: str, dynomax_root: str) -> Dict[str, Any]:
    _reject_sensitive_inputs(ctx)
    project_id, environment_key = _runtime_identity(ctx)
    collection = _normalized_collection(_get(ctx, "collection", required=True))
    scope = _scope(_get(ctx, "scope", "Environment"))
    payload: Dict[str, Any] = {
        "operation": operation,
        "dynomaxRoot": os.path.abspath(str(dynomax_root)),
        "projectId": project_id,
        "environmentKey": environment_key,
        "collection": collection,
        "scope": scope,
    }
    if operation == "workspace.records.get-many":
        _prepare_get_many(ctx, payload)
    elif operation == "workspace.records.append-many":
        _prepare_append_many(ctx, payload)
    elif operation == "workspace.records.upsert-many":
        _prepare_upsert_many(ctx, payload)
    else:
        raise ValueError("Unsupported Workspace durable-record batch operation.")

    encoded_payload = json.dumps(payload, ensure_ascii=False, separators=(",", ":"))
    if len(encoded_payload.encode("utf-8")) > _MAX_JSON_CHARS:
        raise ValueError("Workspace durable-record batch payload exceeds the 1 MiB Built-in Action limit.")

    script_fd, script_path = tempfile.mkstemp(prefix=".dynomax-workspace-record-batches-", suffix=".ps1")
    try:
        with os.fdopen(script_fd, "w", encoding="utf-8", newline="\n") as stream:
            stream.write(_powershell_script())
        completed = subprocess.run(
            [str(powershell_path), "-NoLogo", "-NoProfile", "-NonInteractive", "-ExecutionPolicy", "Bypass", "-File", script_path],
            input=encoded_payload,
            capture_output=True,
            text=True,
            timeout=310,
            encoding="utf-8",
            errors="replace",
        )
    finally:
        try:
            os.unlink(script_path)
        except OSError:
            pass
    if completed.returncode != 0:
        raise RuntimeError((completed.stderr or "Workspace durable-record batch operation failed.")[:4096])
    raw = completed.stdout.strip()
    if len(raw.encode("utf-8")) > _MAX_JSON_CHARS * 4:
        raise ValueError("Workspace durable-record batch result exceeds the Built-in Action size limit.")
    result = json.loads(raw or "{}")

    if operation == "workspace.records.get-many":
        decoded = []
        for item in result.get("results") or []:
            record = _decode_record(item.get("record"))
            decoded.append({"recordKey": item.get("recordKey"), "found": record is not None, "record": record})
        _set(ctx, "results", decoded)
        _set(ctx, "recordCount", len(decoded))
        _set(ctx, "foundCount", sum(1 for item in decoded if item["found"]))
    elif operation == "workspace.records.append-many":
        decoded = []
        for item in result.get("results") or []:
            decoded.append({"record": _decode_record(item.get("record")), "wasDuplicate": bool(item.get("wasDuplicate", False))})
        _set(ctx, "results", decoded)
        _set(ctx, "recordCount", len(decoded))
        _set(ctx, "duplicateCount", sum(1 for item in decoded if item["wasDuplicate"]))
    else:
        decoded = []
        for item in result.get("results") or []:
            decoded.append({
                "record": _decode_record(item.get("record")),
                "created": bool(item.get("created", False)),
                "changed": bool(item.get("changed", False)),
            })
        _set(ctx, "results", decoded)
        _set(ctx, "recordCount", len(decoded))
        _set(ctx, "createdCount", sum(1 for item in decoded if item["created"]))
        _set(ctx, "changedCount", sum(1 for item in decoded if item["changed"]))
    return ctx


@library(scope="GLOBAL", auto_keywords=False)
class DynomaxBuiltInWorkspaceRecordBatches:
    @keyword("Execute Dynomax Workspace Records Operation")
    def execute(self, operation: str, context_path: str, powershell_path: str, dynomax_root: str) -> None:
        context = _load(str(context_path))
        _execute(context, str(operation), str(powershell_path), str(dynomax_root))
        _save(str(context_path), context)
""";

    private const string SharedBuiltInRuntimeLibrary = """
from __future__ import annotations

import base64
import csv
import datetime as dt
import email
import email.message
import email.policy
import fnmatch
import hashlib
import hmac
import imaplib
import io
import json
import mimetypes
import os
import platform
import random
import re
import secrets
import shutil
import smtplib
import ssl
import string
import subprocess
import sys
import tempfile
import time
import urllib.error
import urllib.parse
import urllib.request
import uuid
import xml.etree.ElementTree as ET
import zipfile
from pathlib import Path
from typing import Any, Dict, Iterable, List, Mapping, Sequence

from robot.api.deco import keyword, library

_MAX_JSON_CHARS = 1_048_576
_MAX_TEXT_CHARS = 4_194_304
_MAX_HTTP_BODY_BYTES = 4_194_304
_MAX_FILE_BYTES = 52_428_800
_MAX_ARCHIVE_BYTES = 104_857_600
_MAX_COLLECTION_ITEMS = 5000
_MAX_PATH_CHARS = 1024
_MAX_PATH_TOKENS = 128
_MAX_STDIO_CHARS = 1_048_576
_SENSITIVE_HEADER_NAMES = {
    "authorization", "proxy-authorization", "set-cookie", "cookie",
    "www-authenticate", "proxy-authenticate"
}


def _load(path: str) -> Dict[str, Any]:
    return json.loads(Path(path).read_text(encoding="utf-8"))


def _save(path: str, context: Dict[str, Any]) -> None:
    target = Path(path)
    target.parent.mkdir(parents=True, exist_ok=True)
    fd, temp_name = tempfile.mkstemp(prefix=target.name + ".", suffix=".tmp", dir=str(target.parent))
    try:
        with os.fdopen(fd, "w", encoding="utf-8", newline="\n") as stream:
            json.dump(context, stream, ensure_ascii=False, indent=2, default=str)
            stream.write("\n")
        os.replace(temp_name, target)
    except Exception:
        try:
            os.unlink(temp_name)
        except OSError:
            pass
        raise


def _values(ctx: Dict[str, Any]) -> Dict[str, Any]:
    values = ctx.setdefault("values", {})
    if not isinstance(values, dict):
        raise RuntimeError("Dynomax runtime context values are invalid.")
    return values


def _get(ctx: Dict[str, Any], name: str, default: Any = None, *, required: bool = False) -> Any:
    value = _values(ctx).get(name, default)
    if required and (value is None or (isinstance(value, str) and value.strip() == "")):
        raise ValueError(f"Required Built-in Action input '{name}' is missing.")
    return value


def _secret_keys(ctx: Dict[str, Any]) -> set[str]:
    return {str(value) for value in (ctx.get("secretKeys") or []) if str(value).strip()}


def _get_secret(ctx: Dict[str, Any], name: str, *, required: bool = True) -> Any:
    keys = _secret_keys(ctx)
    if name not in keys:
        if required:
            raise ValueError(f"Built-in Action input '{name}' must be supplied through a secret reference.")
        return None
    value = _values(ctx).get(name)
    if required and (value is None or (isinstance(value, str) and value == "")):
        raise ValueError(f"Required Built-in Action secret input '{name}' is unavailable.")
    return value


def _set(ctx: Dict[str, Any], name: str, value: Any, *, sensitive: bool = False) -> None:
    _values(ctx)[name] = value
    keys = _secret_keys(ctx)
    if sensitive:
        keys.add(name)
    else:
        keys.discard(name)
    ctx["secretKeys"] = sorted(keys)


def _as_bool(value: Any, default: bool = False) -> bool:
    if value is None:
        return default
    if isinstance(value, bool):
        return value
    if isinstance(value, (int, float)):
        return value != 0
    return str(value).strip().lower() in {"1", "true", "yes", "y", "on"}


def _as_int(value: Any, default: int, minimum: int, maximum: int) -> int:
    if value is None or str(value).strip() == "":
        parsed = default
    else:
        parsed = int(value)
    if parsed < minimum or parsed > maximum:
        raise ValueError(f"Numeric input must be between {minimum} and {maximum}.")
    return parsed


def _json_value(value: Any) -> Any:
    if isinstance(value, str):
        if len(value) > _MAX_JSON_CHARS:
            raise ValueError("JSON input exceeds the 1 MiB Built-in Action limit.")
        return json.loads(value)
    return value


def _json_object(value: Any, *, allow_empty: bool = True) -> Dict[str, Any]:
    if value is None or value == "":
        if allow_empty:
            return {}
        raise ValueError("A JSON object is required.")
    parsed = _json_value(value)
    if not isinstance(parsed, dict):
        raise ValueError("Input must be a JSON object.")
    return parsed


def _json_array(value: Any) -> List[Any]:
    parsed = _json_value(value)
    if not isinstance(parsed, list):
        raise ValueError("Input must be a JSON array.")
    if len(parsed) > _MAX_COLLECTION_ITEMS:
        raise ValueError("JSON array exceeds the Built-in Action item limit.")
    return parsed


def _path_tokens(path: str) -> List[Any]:
    text = str(path or "").strip()
    if text == "":
        return []
    if len(text) > _MAX_PATH_CHARS:
        raise ValueError("JSON path exceeds the Built-in Action limit.")
    token_re = re.compile(r"(?:^|\.)([^.\[\]]+)|\[(\d+)\]")
    cursor = 0
    tokens: List[Any] = []
    for match in token_re.finditer(text):
        if match.start() != cursor:
            raise ValueError("Invalid JSON path syntax.")
        key, index = match.groups()
        tokens.append(key if key is not None else int(index))
        if len(tokens) > _MAX_PATH_TOKENS:
            raise ValueError("JSON path contains too many segments.")
        cursor = match.end()
    if cursor != len(text):
        raise ValueError("Invalid JSON path syntax.")
    return tokens


def _json_get(value: Any, path: str) -> Any:
    current = _json_value(value)
    for token in _path_tokens(path):
        if isinstance(token, int):
            if not isinstance(current, list) or token < 0 or token >= len(current):
                raise IndexError(f"JSON array index {token} is unavailable.")
            current = current[token]
        else:
            if not isinstance(current, dict) or token not in current:
                raise KeyError(str(token))
            current = current[token]
    return current


def _json_set(value: Any, path: str, new_value: Any) -> Any:
    root = _json_value(value)
    tokens = _path_tokens(path)
    if not tokens:
        return new_value
    current = root
    for token in tokens[:-1]:
        if isinstance(token, int):
            if not isinstance(current, list) or token < 0 or token >= len(current):
                raise IndexError(f"JSON array index {token} is unavailable.")
            current = current[token]
        else:
            if not isinstance(current, dict):
                raise TypeError("JSON path object segment requires an object.")
            if token not in current:
                current[token] = {}
            current = current[token]
    last = tokens[-1]
    if isinstance(last, int):
        if not isinstance(current, list) or last < 0 or last >= len(current):
            raise IndexError(f"JSON array index {last} is unavailable.")
        current[last] = new_value
    else:
        if not isinstance(current, dict):
            raise TypeError("JSON path object segment requires an object.")
        current[last] = new_value
    return root


def _run_path(run_dir: str, relative: Any, *, must_exist: bool = False, directory: bool | None = None) -> Path:
    text = str(relative or "").strip().replace("\\", "/")
    if not text:
        raise ValueError("A run-workspace relative path is required.")
    if len(text) > 1024 or text.startswith("/") or re.match(r"^[A-Za-z]:", text):
        raise ValueError("Built-in file paths must be relative to the disposable run workspace.")
    root = Path(run_dir).resolve()
    candidate = (root / text).resolve(strict=False)
    try:
        candidate.relative_to(root)
    except ValueError as ex:
        raise ValueError("Built-in file path escaped the disposable run workspace.") from ex
    current = root
    for part in candidate.relative_to(root).parts:
        current = current / part
        if current.exists() and current.is_symlink():
            raise ValueError("Built-in file paths may not traverse symbolic links or junction-like links.")
    if must_exist and not candidate.exists():
        raise FileNotFoundError(f"Run-workspace path does not exist: {text}")
    if directory is True and candidate.exists() and not candidate.is_dir():
        raise ValueError("Expected a directory path.")
    if directory is False and candidate.exists() and not candidate.is_file():
        raise ValueError("Expected a file path.")
    return candidate


def _relative_run_path(run_dir: str, absolute: Any) -> str:
    root = Path(run_dir).resolve()
    candidate = Path(str(absolute)).resolve(strict=False)
    try:
        relative = candidate.relative_to(root)
    except ValueError as ex:
        raise ValueError("Result path escaped the disposable run workspace.") from ex
    return relative.as_posix()


def _read_text(path: Path, max_chars: int = _MAX_TEXT_CHARS) -> str:
    if path.stat().st_size > _MAX_FILE_BYTES:
        raise ValueError("File exceeds the Built-in Action size limit.")
    text = path.read_text(encoding="utf-8")
    if len(text) > max_chars:
        raise ValueError("Text exceeds the Built-in Action character limit.")
    return text


def _write_text(path: Path, text: Any, *, append: bool = False, overwrite: bool = True) -> None:
    value = "" if text is None else str(text)
    if len(value) > _MAX_TEXT_CHARS:
        raise ValueError("Text exceeds the Built-in Action character limit.")
    if path.exists() and not append and not overwrite:
        raise FileExistsError("Destination file already exists and overwrite is disabled.")
    path.parent.mkdir(parents=True, exist_ok=True)
    mode = "a" if append else "w"
    with path.open(mode, encoding="utf-8", newline="\n") as stream:
        stream.write(value)


def _runtime_policy(ctx: Dict[str, Any]) -> Dict[str, Any]:
    policy = ctx.get("runtimePolicy") or {}
    return policy if isinstance(policy, dict) else {}


def _normalize_origin(url: str) -> str:
    parsed = urllib.parse.urlsplit(url)
    if parsed.scheme.lower() not in {"http", "https"} or not parsed.hostname:
        raise ValueError("HTTP Built-in Actions require an absolute http/https URL.")
    if parsed.username or parsed.password:
        raise ValueError("Credentials must not be embedded in HTTP URLs.")
    host = parsed.hostname.lower()
    port = parsed.port
    default = 443 if parsed.scheme.lower() == "https" else 80
    suffix = "" if port in {None, default} else f":{port}"
    return f"{parsed.scheme.lower()}://{host}{suffix}"


def _validate_http_url(ctx: Dict[str, Any], url: str) -> str:
    origin = _normalize_origin(url)
    allowed = {str(item).rstrip("/").lower() for item in (_runtime_policy(ctx).get("allowedOrigins") or [])}
    if not allowed:
        raise ValueError("Runtime Environment origin policy is unavailable.")
    if origin.lower() not in allowed:
        raise ValueError(f"HTTP target origin '{origin}' is not allowed by the selected Environment.")
    return url


class _SafeRedirectHandler(urllib.request.HTTPRedirectHandler):
    def __init__(self, ctx: Dict[str, Any]):
        super().__init__()
        self._ctx = ctx

    def redirect_request(self, req, fp, code, msg, headers, newurl):
        _validate_http_url(self._ctx, newurl)
        return super().redirect_request(req, fp, code, msg, headers, newurl)


def _safe_headers(headers: Mapping[str, Any]) -> Dict[str, str]:
    result: Dict[str, str] = {}
    for name, value in headers.items():
        if str(name).lower() in _SENSITIVE_HEADER_NAMES:
            continue
        result[str(name)] = str(value)
    return result


def _redact_exact_runtime_secrets(ctx: Dict[str, Any], text: str) -> str:
    redacted = text
    values = _values(ctx)
    for key in _secret_keys(ctx):
        value = values.get(key)
        if value is None:
            continue
        secret = str(value)
        if len(secret) >= 4 and secret in redacted:
            redacted = redacted.replace(secret, "[REDACTED]")
    return redacted


def _http_request(ctx: Dict[str, Any], method: str, url: str, headers: Dict[str, str], body: bytes | None, timeout: int) -> Dict[str, Any]:
    _validate_http_url(ctx, url)
    opener = urllib.request.build_opener(_SafeRedirectHandler(ctx))
    request = urllib.request.Request(url=url, data=body, headers=headers, method=method.upper())
    started = time.monotonic()
    try:
        response = opener.open(request, timeout=timeout)
    except urllib.error.HTTPError as ex:
        response = ex
    with response:
        data = response.read(_MAX_HTTP_BODY_BYTES + 1)
        if len(data) > _MAX_HTTP_BODY_BYTES:
            raise ValueError("HTTP response body exceeds the 4 MiB Built-in Action limit.")
        charset = response.headers.get_content_charset() if hasattr(response.headers, "get_content_charset") else None
        content_type = response.headers.get("Content-Type", "")
        try:
            text = data.decode(charset or "utf-8")
            text = _redact_exact_runtime_secrets(ctx, text)
        except UnicodeDecodeError:
            text = base64.b64encode(data).decode("ascii")
            content_type = content_type or "application/octet-stream;base64"
        return {
            "status": int(getattr(response, "status", getattr(response, "code", 0))),
            "headers": _safe_headers(dict(response.headers.items())),
            "body": text,
            "contentType": content_type,
            "durationMs": int((time.monotonic() - started) * 1000),
            "finalUrl": response.geturl(),
        }


def _build_http_inputs(ctx: Dict[str, Any], default_method: str | None = None) -> tuple[str, str, Dict[str, str], bytes | None, int]:
    method = str(_get(ctx, "method", default_method or "GET") or default_method or "GET").upper()
    if method not in {"GET", "POST", "PUT", "PATCH", "DELETE", "HEAD", "OPTIONS"}:
        raise ValueError("Unsupported HTTP method.")
    url = str(_get(ctx, "url", required=True))
    headers = {str(k): str(v) for k, v in _json_object(_get(ctx, "headers", {})).items()}
    secret_headers_raw = _get_secret(ctx, "secretHeadersJson", required=False)
    if secret_headers_raw:
        headers.update({str(k): str(v) for k, v in _json_object(secret_headers_raw).items()})
    body_value = _get(ctx, "body", None)
    body = None if body_value is None else str(body_value).encode("utf-8")
    if body is not None and len(body) > _MAX_HTTP_BODY_BYTES:
        raise ValueError("HTTP request body exceeds the 4 MiB Built-in Action limit.")
    content_type = str(_get(ctx, "contentType", "") or "").strip()
    if content_type and body is not None and not any(name.lower() == "content-type" for name in headers):
        headers["Content-Type"] = content_type
    timeout = _as_int(_get(ctx, "timeoutSeconds", 30), 30, 1, 300)
    return method, url, headers, body, timeout


def _publish_http(ctx: Dict[str, Any], result: Dict[str, Any]) -> None:
    for key in ("status", "headers", "body", "contentType", "durationMs", "finalUrl"):
        _set(ctx, key, result.get(key))


def _multipart_body(fields: Dict[str, Any], field_name: str, file_path: Path, content_type: str | None = None) -> tuple[bytes, str]:
    if file_path.stat().st_size > _MAX_FILE_BYTES:
        raise ValueError("Upload file exceeds the Built-in Action size limit.")
    boundary = "dynomax-" + secrets.token_hex(16)
    buffer = io.BytesIO()
    for key, value in fields.items():
        buffer.write(f"--{boundary}\r\nContent-Disposition: form-data; name=\"{key}\"\r\n\r\n{value}\r\n".encode("utf-8"))
    mime = content_type or mimetypes.guess_type(file_path.name)[0] or "application/octet-stream"
    buffer.write(f"--{boundary}\r\nContent-Disposition: form-data; name=\"{field_name}\"; filename=\"{file_path.name}\"\r\nContent-Type: {mime}\r\n\r\n".encode("utf-8"))
    buffer.write(file_path.read_bytes())
    buffer.write(f"\r\n--{boundary}--\r\n".encode("utf-8"))
    body = buffer.getvalue()
    if len(body) > _MAX_FILE_BYTES + _MAX_HTTP_BODY_BYTES:
        raise ValueError("Multipart HTTP request exceeds the Built-in Action size limit.")
    return body, f"multipart/form-data; boundary={boundary}"


def _xml_to_obj(element: ET.Element, depth: int = 0) -> Dict[str, Any]:
    if depth > 64:
        raise ValueError("XML nesting exceeds the Built-in Action limit.")
    children = list(element)
    return {
        "tag": element.tag,
        "attributes": dict(element.attrib),
        "text": (element.text or "").strip(),
        "children": [_xml_to_obj(child, depth + 1) for child in children],
    }


def _time_zone(name: str):
    normalized = str(name or "UTC").strip()
    if normalized.upper() in {"UTC", "Z", "ETC/UTC"}:
        return dt.timezone.utc
    from zoneinfo import ZoneInfo
    return ZoneInfo(normalized)


def _parse_datetime(value: Any, timezone_name: str | None = None) -> dt.datetime:
    text = str(value or "").strip()
    if not text:
        raise ValueError("Date/time value is required.")
    if text.endswith("Z"):
        text = text[:-1] + "+00:00"
    parsed = dt.datetime.fromisoformat(text)
    if parsed.tzinfo is None:
        if timezone_name:
            parsed = parsed.replace(tzinfo=_time_zone(timezone_name))
        else:
            parsed = parsed.replace(tzinfo=dt.timezone.utc)
    return parsed


def _safe_environment(base: Mapping[str, str], supplied: Dict[str, Any], secret_supplied: Dict[str, Any]) -> Dict[str, str]:
    allowed_base = ["SystemRoot", "WINDIR", "COMSPEC", "TEMP", "TMP", "PATH", "PATHEXT", "HOME", "USERPROFILE"]
    env = {key: base[key] for key in allowed_base if key in base}
    name_re = re.compile(r"^[A-Za-z_][A-Za-z0-9_]{0,127}$")
    for source in (supplied, secret_supplied):
        for name, value in source.items():
            if not name_re.match(str(name)):
                raise ValueError("Process environment variable name is invalid.")
            env[str(name)] = str(value)
    return env


def _process_policy(ctx: Dict[str, Any]) -> Dict[str, Any]:
    policy = (_runtime_policy(ctx).get("processExecution") or {})
    if not isinstance(policy, dict) or not _as_bool(policy.get("enabled"), False):
        raise PermissionError("Built-in process execution is disabled by Worker runtime policy.")
    return policy


def _resolve_executable(ctx: Dict[str, Any], run_dir: str, executable: str) -> str:
    policy = _process_policy(ctx)
    requested = str(executable or "").strip()
    if not requested:
        raise ValueError("Executable is required.")
    allowed_paths = {os.path.normcase(os.path.abspath(str(path))) for path in (policy.get("allowedExecutablePaths") or []) if str(path).strip()}
    allow_run = _as_bool(policy.get("allowRunDirectoryExecutables"), False)
    if os.path.isabs(requested):
        candidate = os.path.normcase(os.path.abspath(requested))
        if candidate in allowed_paths:
            return os.path.abspath(requested)
        if allow_run:
            run_candidate = _run_path(run_dir, os.path.relpath(requested, run_dir), must_exist=True, directory=False)
            return str(run_candidate)
        raise PermissionError("Executable path is not present in the Worker allow-list.")
    found = shutil.which(requested)
    if found and os.path.normcase(os.path.abspath(found)) in allowed_paths:
        return found
    if allow_run:
        candidate = _run_path(run_dir, requested, must_exist=True, directory=False)
        return str(candidate)
    raise PermissionError("Executable is not present in the Worker allow-list.")


def _run_process(ctx: Dict[str, Any], run_dir: str, executable: str, arguments: Sequence[Any], *, cwd_relative: Any = ".", stdin_text: str | None = None, trusted_executable: bool = False) -> Dict[str, Any]:
    if trusted_executable:
        _process_policy(ctx)
        candidate = executable if os.path.isabs(executable) else (shutil.which(executable) or "")
        if not candidate or not Path(candidate).is_file():
            raise PermissionError("The trusted Dynomax interpreter executable is unavailable.")
        resolved = os.path.abspath(candidate)
    else:
        resolved = _resolve_executable(ctx, run_dir, executable)
    cwd = _run_path(run_dir, cwd_relative or ".", must_exist=True, directory=True)
    timeout = _as_int(_get(ctx, "timeoutSeconds", 60), 60, 1, 3600)
    normal_env = _json_object(_get(ctx, "environment", {}))
    secret_env_raw = _get_secret(ctx, "secretEnvironmentJson", required=False)
    secret_env = _json_object(secret_env_raw) if secret_env_raw else {}
    env = _safe_environment(os.environ, normal_env, secret_env)
    completed = subprocess.run(
        [resolved, *[str(item) for item in arguments]],
        input=stdin_text,
        cwd=str(cwd),
        env=env,
        capture_output=True,
        text=True,
        timeout=timeout,
        shell=False,
        encoding="utf-8",
        errors="replace",
    )
    stdout = completed.stdout[:_MAX_STDIO_CHARS]
    stderr = completed.stderr[:_MAX_STDIO_CHARS]
    return {"exitCode": completed.returncode, "stdout": stdout, "stderr": stderr}


def _powershell_database_script() -> str:
    return r'''$ErrorActionPreference='Stop'
$payload=[Console]::In.ReadToEnd()|ConvertFrom-Json
$profile=$payload.profile
$factory=[System.Data.Common.DbProviderFactories]::GetFactory([string]$profile.providerInvariantName)
$conn=$factory.CreateConnection()
$conn.ConnectionString=[string]$profile.connectionString
try {
  $conn.Open()
  $cmd=$conn.CreateCommand()
  $cmd.CommandText=[string]$payload.commandText
  $timeout=30
  if($profile.commandTimeoutSeconds){$timeout=[int]$profile.commandTimeoutSeconds}
  if($payload.timeoutSeconds){$timeout=[int]$payload.timeoutSeconds}
  $cmd.CommandTimeout=[Math]::Max(1,[Math]::Min(3600,$timeout))
  if([string]$payload.mode -eq 'StoredProcedure'){$cmd.CommandType=[System.Data.CommandType]::StoredProcedure}
  if($payload.parameters){
    foreach($prop in $payload.parameters.PSObject.Properties){
      $p=$cmd.CreateParameter();$p.ParameterName=[string]$prop.Name
      $p.Value=if($null -eq $prop.Value){[DBNull]::Value}else{$prop.Value}
      [void]$cmd.Parameters.Add($p)
    }
  }
  function Convert-DbValue($v){
    if($null -eq $v -or $v -is [DBNull]){return $null}
    if($v -is [byte[]]){return [Convert]::ToBase64String($v)}
    if($v -is [DateTime]){return $v.ToUniversalTime().ToString('o')}
    if($v -is [DateTimeOffset]){return $v.ToUniversalTime().ToString('o')}
    if($v -is [Guid]){return $v.ToString('D')}
    return $v
  }
  switch([string]$payload.mode){
    'Query' {
      $reader=$cmd.ExecuteReader();try{$rows=@();$maxRows=[int]$payload.maxRows;while($reader.Read() -and $rows.Count -lt $maxRows){$row=[ordered]@{};for($i=0;$i -lt $reader.FieldCount;$i++){$row[$reader.GetName($i)]=Convert-DbValue $reader.GetValue($i)};$rows+=,[pscustomobject]$row};[ordered]@{rows=$rows;rowCount=$rows.Count}|ConvertTo-Json -Depth 50 -Compress}finally{$reader.Dispose()}
    }
    'Scalar' {[ordered]@{value=Convert-DbValue $cmd.ExecuteScalar()}|ConvertTo-Json -Depth 50 -Compress}
    'Execute' {[ordered]@{rowsAffected=$cmd.ExecuteNonQuery()}|ConvertTo-Json -Depth 10 -Compress}
    'StoredProcedure' {
      $reader=$cmd.ExecuteReader();try{$rows=@();$maxRows=[int]$payload.maxRows;while($reader.Read() -and $rows.Count -lt $maxRows){$row=[ordered]@{};for($i=0;$i -lt $reader.FieldCount;$i++){$row[$reader.GetName($i)]=Convert-DbValue $reader.GetValue($i)};$rows+=,[pscustomobject]$row};[ordered]@{rows=$rows;rowCount=$rows.Count}|ConvertTo-Json -Depth 50 -Compress}finally{$reader.Dispose()}
    }
    default {throw 'Unsupported database operation mode.'}
  }
} finally {if($conn){$conn.Dispose()}}'''


def _database_operation(ctx: Dict[str, Any], mode: str, powershell_path: str) -> None:
    profile_raw = _get_secret(ctx, "connectionProfileJson")
    profile = _json_object(profile_raw, allow_empty=False)
    provider = str(profile.get("providerInvariantName") or "").strip()
    connection_string = str(profile.get("connectionString") or "")
    if not provider or not connection_string:
        raise ValueError("Database connection profile requires providerInvariantName and connectionString.")
    command_name = "procedure" if mode == "StoredProcedure" else "sql"
    command_text = str(_get(ctx, command_name, required=True))
    parameters = _json_object(_get(ctx, "parameters", {}))
    max_rows = _as_int(_get(ctx, "maxRows", 1000), 1000, 1, 5000)
    timeout = _as_int(_get(ctx, "timeoutSeconds", 30), 30, 1, 3600)
    payload = json.dumps({
        "profile": profile,
        "mode": mode,
        "commandText": command_text,
        "parameters": parameters,
        "maxRows": max_rows,
        "timeoutSeconds": timeout,
    }, ensure_ascii=False, default=str)
    encoded = base64.b64encode(_powershell_database_script().encode("utf-16le")).decode("ascii")
    completed = subprocess.run(
        [powershell_path, "-NoLogo", "-NoProfile", "-NonInteractive", "-EncodedCommand", encoded],
        input=payload,
        capture_output=True,
        text=True,
        timeout=timeout + 10,
        encoding="utf-8",
        errors="replace",
    )
    if completed.returncode != 0:
        raise RuntimeError((completed.stderr or "Database provider execution failed.")[:4096])
    raw = completed.stdout.strip()
    if len(raw) > _MAX_JSON_CHARS * 4:
        raise ValueError("Database result exceeds the Built-in Action size limit.")
    result = json.loads(raw or "{}")
    if mode in {"Query", "StoredProcedure"}:
        _set(ctx, "rows", result.get("rows", []), sensitive=True)
        _set(ctx, "rowCount", int(result.get("rowCount", 0)))
    elif mode == "Scalar":
        _set(ctx, "value", result.get("value"), sensitive=True)
    else:
        _set(ctx, "rowsAffected", int(result.get("rowsAffected", -1)))


def _mail_profile(ctx: Dict[str, Any]) -> Dict[str, Any]:
    raw = _get_secret(ctx, "connectionProfileJson")
    profile = _json_object(raw, allow_empty=False)
    host = str(profile.get("host") or "").strip()
    if not host:
        raise ValueError("Email connection profile requires host.")
    return profile


def _smtp_connect(profile: Dict[str, Any]):
    host = str(profile["host"])
    port = int(profile.get("port") or 587)
    security = str(profile.get("security") or "starttls").lower()
    timeout = int(profile.get("timeoutSeconds") or 30)
    if security == "ssl":
        client = smtplib.SMTP_SSL(host, port, timeout=timeout, context=ssl.create_default_context())
    elif security == "starttls":
        client = smtplib.SMTP(host, port, timeout=timeout)
        client.ehlo()
        client.starttls(context=ssl.create_default_context())
        client.ehlo()
    else:
        raise ValueError("SMTP profile security must be 'ssl' or 'starttls'.")
    username = profile.get("username")
    password = profile.get("password")
    if username is not None or password is not None:
        if not username or password is None:
            client.quit()
            raise ValueError("SMTP profile username/password must be supplied together.")
        client.login(str(username), str(password))
    return client


def _imap_connect(profile: Dict[str, Any]):
    host = str(profile["host"])
    port = int(profile.get("port") or 993)
    security = str(profile.get("security") or "ssl").lower()
    timeout = int(profile.get("timeoutSeconds") or 30)
    if security == "ssl":
        client = imaplib.IMAP4_SSL(host, port, ssl_context=ssl.create_default_context(), timeout=timeout)
    elif security == "starttls":
        client = imaplib.IMAP4(host, port, timeout=timeout)
        client.starttls(ssl_context=ssl.create_default_context())
    else:
        raise ValueError("IMAP profile security must be 'ssl' or 'starttls'.")
    username = profile.get("username")
    password = profile.get("password")
    if not username or password is None:
        client.logout()
        raise ValueError("IMAP profile requires username/password.")
    client.login(str(username), str(password))
    return client


def _decode_header(value: str | None) -> str:
    if not value:
        return ""
    parts = email.header.decode_header(value)
    out = []
    for part, charset in parts:
        if isinstance(part, bytes):
            out.append(part.decode(charset or "utf-8", errors="replace"))
        else:
            out.append(part)
    return "".join(out)


def _message_summary(uid: str, raw: bytes, include_body: bool) -> Dict[str, Any]:
    msg = email.message_from_bytes(raw, policy=email.policy.default)
    body = ""
    attachments = []
    for part in msg.walk():
        if part.is_multipart():
            continue
        filename = part.get_filename()
        if filename:
            payload = part.get_payload(decode=True) or b""
            attachments.append({"fileName": _decode_header(filename), "contentType": part.get_content_type(), "size": len(payload)})
            continue
        if include_body and part.get_content_type() == "text/plain" and not body:
            payload = part.get_payload(decode=True) or b""
            charset = part.get_content_charset() or "utf-8"
            body = payload.decode(charset, errors="replace")[:_MAX_TEXT_CHARS]
    return {
        "messageId": uid,
        "from": _decode_header(msg.get("From")),
        "to": _decode_header(msg.get("To")),
        "subject": _decode_header(msg.get("Subject")),
        "date": str(msg.get("Date") or ""),
        "body": body,
        "attachments": attachments,
    }


def _imap_search(client, criteria: str, limit: int, include_body: bool) -> List[Dict[str, Any]]:
    typ, data = client.uid("search", None, criteria or "ALL")
    if typ != "OK":
        raise RuntimeError("IMAP search failed.")
    ids = (data[0] or b"").split()
    ids = ids[-limit:]
    result = []
    for uid in ids:
        typ, message_data = client.uid("fetch", uid, "(RFC822)")
        if typ != "OK" or not message_data:
            continue
        raw = next((item[1] for item in message_data if isinstance(item, tuple) and isinstance(item[1], bytes)), b"")
        if raw:
            result.append(_message_summary(uid.decode("ascii", errors="ignore"), raw, include_body))
    return result


def _email_operation(ctx: Dict[str, Any], run_dir: str, operation: str) -> None:
    profile = _mail_profile(ctx)
    if operation.startswith("email.smtp."):
        from_addr = str(_get(ctx, "from", profile.get("from") or profile.get("username") or "", required=True))
        to_value = _get(ctx, "to", required=True)
        if isinstance(to_value, str) and to_value.lstrip().startswith("["):
            recipient_source = _json_array(to_value)
        else:
            recipient_source = to_value if isinstance(to_value, list) else str(to_value).split(",")
        recipients = [str(item).strip() for item in recipient_source if str(item).strip()]
        if not recipients:
            raise ValueError("At least one email recipient is required.")
        msg = email.message.EmailMessage()
        msg["From"] = from_addr
        msg["To"] = ", ".join(recipients)
        msg["Subject"] = str(_get(ctx, "subject", ""))
        msg.set_content(str(_get(ctx, "body", "")))
        if operation == "email.smtp.send-attachment":
            files = _get(ctx, "attachments", [])
            if isinstance(files, str):
                files = _json_array(files)
            if not isinstance(files, list) or len(files) > 20:
                raise ValueError("Attachments must be a JSON array with at most 20 run-workspace file references.")
            for item in files:
                path = _run_path(run_dir, item, must_exist=True, directory=False)
                if path.stat().st_size > _MAX_FILE_BYTES:
                    raise ValueError("Email attachment exceeds the Built-in Action size limit.")
                mime, _ = mimetypes.guess_type(path.name)
                main, sub = (mime or "application/octet-stream").split("/", 1)
                msg.add_attachment(path.read_bytes(), maintype=main, subtype=sub, filename=path.name)
        client = _smtp_connect(profile)
        try:
            refused = client.send_message(msg, from_addr=from_addr, to_addrs=recipients)
        finally:
            try:
                client.quit()
            except Exception:
                pass
        if refused:
            raise RuntimeError("SMTP server refused one or more recipients.")
        _set(ctx, "messageId", str(msg.get("Message-ID") or ""))
        return

    folder = str(_get(ctx, "folder", "INBOX") or "INBOX")
    client = _imap_connect(profile)
    try:
        typ, _ = client.select(folder)
        if typ != "OK":
            raise RuntimeError("IMAP mailbox selection failed.")
        if operation in {"email.imap.read", "email.imap.find", "email.imap.latest"}:
            limit = 1 if operation == "email.imap.latest" else _as_int(_get(ctx, "limit", 20), 20, 1, 200)
            criteria = str(_get(ctx, "criteria", "ALL") or "ALL")
            include_body = _as_bool(_get(ctx, "includeBody", True), True)
            messages = _imap_search(client, criteria, limit, include_body)
            if operation == "email.imap.latest":
                _set(ctx, "message", messages[-1] if messages else None, sensitive=True)
            else:
                _set(ctx, "messages", messages, sensitive=True)
                _set(ctx, "count", len(messages))
        elif operation == "email.imap.download-attachments":
            uid = str(_get(ctx, "messageId", required=True))
            typ, message_data = client.uid("fetch", uid, "(RFC822)")
            if typ != "OK":
                raise RuntimeError("IMAP message fetch failed.")
            raw = next((item[1] for item in message_data if isinstance(item, tuple) and isinstance(item[1], bytes)), b"")
            msg = email.message_from_bytes(raw, policy=email.policy.default)
            target_dir = _run_path(run_dir, _get(ctx, "destinationDirectory", f"email-attachments/{uid}"), directory=True)
            target_dir.mkdir(parents=True, exist_ok=True)
            saved = []
            for index, part in enumerate(msg.iter_attachments()):
                if len(saved) >= 50:
                    raise ValueError("Email contains too many attachments.")
                filename = _decode_header(part.get_filename()) or f"attachment-{index + 1}"
                filename = re.sub(r"[^A-Za-z0-9._ -]+", "_", filename).strip(" .") or f"attachment-{index + 1}"
                path = (target_dir / filename).resolve(strict=False)
                try:
                    path.relative_to(target_dir.resolve())
                except ValueError as ex:
                    raise ValueError("Attachment filename escaped destination directory.") from ex
                payload = part.get_payload(decode=True) or b""
                if len(payload) > _MAX_FILE_BYTES:
                    raise ValueError("Email attachment exceeds the Built-in Action size limit.")
                path.write_bytes(payload)
                saved.append(_relative_run_path(run_dir, path))
            _set(ctx, "attachments", saved)
        elif operation == "email.imap.mark-read":
            uid = str(_get(ctx, "messageId", required=True))
            read = _as_bool(_get(ctx, "read", True), True)
            command = "+FLAGS" if read else "-FLAGS"
            typ, _ = client.uid("store", uid, command, "(\\Seen)")
            if typ != "OK":
                raise RuntimeError("IMAP read-state update failed.")
            _set(ctx, "updated", True)
        elif operation == "email.imap.move":
            uid = str(_get(ctx, "messageId", required=True))
            destination = str(_get(ctx, "destinationFolder", required=True))
            typ, _ = client.uid("MOVE", uid, destination)
            if typ != "OK":
                typ, _ = client.uid("COPY", uid, destination)
                if typ != "OK":
                    raise RuntimeError("IMAP move/copy failed.")
                client.uid("store", uid, "+FLAGS", "(\\Deleted)")
                client.expunge()
            _set(ctx, "moved", True)
        elif operation == "email.imap.delete":
            uid = str(_get(ctx, "messageId", required=True))
            typ, _ = client.uid("store", uid, "+FLAGS", "(\\Deleted)")
            if typ != "OK":
                raise RuntimeError("IMAP delete failed.")
            client.expunge()
            _set(ctx, "deleted", True)
        else:
            raise ValueError("Unsupported email Built-in operation.")
    finally:
        try:
            client.logout()
        except Exception:
            pass


def _file_operation(ctx: Dict[str, Any], run_dir: str, operation: str) -> None:
    if operation == "file.text.read":
        path = _run_path(run_dir, _get(ctx, "path", required=True), must_exist=True, directory=False)
        max_chars = _as_int(_get(ctx, "maxCharacters", _MAX_TEXT_CHARS), _MAX_TEXT_CHARS, 1, _MAX_TEXT_CHARS)
        _set(ctx, "text", _read_text(path, max_chars))
    elif operation in {"file.text.write", "file.text.append"}:
        path = _run_path(run_dir, _get(ctx, "path", required=True), directory=False)
        _write_text(path, _get(ctx, "text", ""), append=operation.endswith("append"), overwrite=_as_bool(_get(ctx, "overwrite", True), True))
        _set(ctx, "fileReference", _relative_run_path(run_dir, path))
    elif operation in {"file.copy", "file.move"}:
        source = _run_path(run_dir, _get(ctx, "sourcePath", required=True), must_exist=True, directory=False)
        destination = _run_path(run_dir, _get(ctx, "destinationPath", required=True), directory=False)
        overwrite = _as_bool(_get(ctx, "overwrite", False), False)
        if destination.exists() and not overwrite:
            raise FileExistsError("Destination already exists and overwrite is disabled.")
        destination.parent.mkdir(parents=True, exist_ok=True)
        if operation == "file.copy":
            shutil.copy2(source, destination)
        else:
            if destination.exists():
                destination.unlink()
            shutil.move(str(source), str(destination))
        _set(ctx, "fileReference", _relative_run_path(run_dir, destination))
    elif operation == "file.delete":
        path = _run_path(run_dir, _get(ctx, "path", required=True), directory=False)
        if path.exists():
            path.unlink()
        elif not _as_bool(_get(ctx, "missingOk", True), True):
            raise FileNotFoundError("File does not exist.")
        _set(ctx, "deleted", True)
    elif operation == "file.exists":
        path = _run_path(run_dir, _get(ctx, "path", required=True))
        _set(ctx, "exists", path.is_file())
    elif operation == "directory.create":
        path = _run_path(run_dir, _get(ctx, "path", required=True), directory=True)
        path.mkdir(parents=True, exist_ok=True)
        _set(ctx, "directoryReference", _relative_run_path(run_dir, path))
    elif operation == "directory.delete":
        path = _run_path(run_dir, _get(ctx, "path", required=True), directory=True)
        if path.resolve() == Path(run_dir).resolve():
            raise PermissionError("The disposable run-workspace root cannot be deleted by a Built-in Action.")
        if path.exists():
            if _as_bool(_get(ctx, "recursive", False), False):
                shutil.rmtree(path)
            else:
                path.rmdir()
        elif not _as_bool(_get(ctx, "missingOk", True), True):
            raise FileNotFoundError("Directory does not exist.")
        _set(ctx, "deleted", True)
    elif operation in {"directory.list", "file.find"}:
        root = _run_path(run_dir, _get(ctx, "path", "."), must_exist=True, directory=True)
        recursive = _as_bool(_get(ctx, "recursive", False), False)
        pattern = str(_get(ctx, "pattern", "*") or "*") if operation == "file.find" else "*"
        entries = []
        iterator: Iterable[Path] = root.rglob("*") if recursive else root.iterdir()
        for item in iterator:
            if len(entries) >= _MAX_COLLECTION_ITEMS:
                raise ValueError("Directory result exceeds the Built-in Action item limit.")
            if operation == "file.find" and (not item.is_file() or not fnmatch.fnmatch(item.name, pattern)):
                continue
            entries.append({
                "path": _relative_run_path(run_dir, item),
                "name": item.name,
                "isFile": item.is_file(),
                "isDirectory": item.is_dir(),
                "size": item.stat().st_size if item.is_file() else None,
            })
        key = "files" if operation == "file.find" else "entries"
        _set(ctx, key, entries)
        _set(ctx, "count", len(entries))
    elif operation == "file.info":
        path = _run_path(run_dir, _get(ctx, "path", required=True), must_exist=True)
        stat = path.stat()
        _set(ctx, "info", {
            "path": _relative_run_path(run_dir, path), "name": path.name,
            "isFile": path.is_file(), "isDirectory": path.is_dir(),
            "size": stat.st_size if path.is_file() else None,
            "createdUtc": dt.datetime.fromtimestamp(stat.st_ctime, dt.timezone.utc).isoformat(),
            "modifiedUtc": dt.datetime.fromtimestamp(stat.st_mtime, dt.timezone.utc).isoformat(),
        })
    elif operation == "file.hash.sha256":
        path = _run_path(run_dir, _get(ctx, "path", required=True), must_exist=True, directory=False)
        digest = hashlib.sha256()
        with path.open("rb") as stream:
            while True:
                block = stream.read(1024 * 1024)
                if not block:
                    break
                digest.update(block)
        _set(ctx, "sha256", digest.hexdigest())
    elif operation == "file.zip.compress":
        sources = _get(ctx, "paths", required=True)
        if isinstance(sources, str):
            sources = _json_array(sources)
        if not isinstance(sources, list) or not sources or len(sources) > 500:
            raise ValueError("paths must be a non-empty JSON array with at most 500 entries.")
        destination = _run_path(run_dir, _get(ctx, "destinationPath", required=True), directory=False)
        destination.parent.mkdir(parents=True, exist_ok=True)
        with zipfile.ZipFile(destination, "w", zipfile.ZIP_DEFLATED) as archive:
            added = 0
            for source_ref in sources:
                source = _run_path(run_dir, source_ref, must_exist=True)
                if source.resolve() == destination.resolve():
                    continue
                if source.is_file():
                    archive.write(source, arcname=_relative_run_path(run_dir, source))
                    added += 1
                else:
                    for item in source.rglob("*"):
                        if item.is_file():
                            added += 1
                            if added > _MAX_COLLECTION_ITEMS:
                                raise ValueError("ZIP source exceeds the Built-in Action item limit.")
                            archive.write(item, arcname=_relative_run_path(run_dir, item))
        if destination.stat().st_size > _MAX_ARCHIVE_BYTES:
            destination.unlink(missing_ok=True)
            raise ValueError("ZIP archive exceeds the Built-in Action size limit.")
        _set(ctx, "fileReference", _relative_run_path(run_dir, destination))
    elif operation == "file.zip.extract":
        source = _run_path(run_dir, _get(ctx, "zipPath", required=True), must_exist=True, directory=False)
        destination = _run_path(run_dir, _get(ctx, "destinationDirectory", required=True), directory=True)
        destination.mkdir(parents=True, exist_ok=True)
        total = 0
        with zipfile.ZipFile(source, "r") as archive:
            infos = archive.infolist()
            if len(infos) > _MAX_COLLECTION_ITEMS:
                raise ValueError("ZIP contains too many entries.")
            for info in infos:
                total += max(0, int(info.file_size))
                if total > _MAX_ARCHIVE_BYTES:
                    raise ValueError("ZIP extracted size exceeds the Built-in Action limit.")
                target = (destination / info.filename).resolve(strict=False)
                try:
                    target.relative_to(destination.resolve())
                except ValueError as ex:
                    raise ValueError("ZIP entry escaped the destination directory.") from ex
            archive.extractall(destination)
        _set(ctx, "directoryReference", _relative_run_path(run_dir, destination))
        _set(ctx, "entryCount", len(infos))
    elif operation in {"file.csv.read", "file.json.read", "file.xml.read"}:
        path = _run_path(run_dir, _get(ctx, "path", required=True), must_exist=True, directory=False)
        text = _read_text(path)
        if operation == "file.csv.read":
            delimiter = str(_get(ctx, "delimiter", ",") or ",")
            rows = list(csv.DictReader(io.StringIO(text), delimiter=delimiter))
            if len(rows) > _MAX_COLLECTION_ITEMS:
                raise ValueError("CSV row count exceeds the Built-in Action limit.")
            _set(ctx, "rows", rows)
        elif operation == "file.json.read":
            _set(ctx, "json", _json_value(text))
        else:
            ET.fromstring(text)
            _set(ctx, "xml", text)
    elif operation in {"file.csv.write", "file.json.write", "file.xml.write"}:
        path = _run_path(run_dir, _get(ctx, "path", required=True), directory=False)
        if operation == "file.csv.write":
            rows = _json_array(_get(ctx, "rows", required=True))
            if not all(isinstance(row, dict) for row in rows):
                raise ValueError("CSV rows must be JSON objects.")
            fieldnames: List[str] = []
            for row in rows:
                for key in row.keys():
                    if str(key) not in fieldnames:
                        fieldnames.append(str(key))
            out = io.StringIO()
            writer = csv.DictWriter(out, fieldnames=fieldnames, extrasaction="ignore", delimiter=str(_get(ctx, "delimiter", ",") or ","), lineterminator="\n")
            writer.writeheader()
            writer.writerows(rows)
            _write_text(path, out.getvalue(), overwrite=_as_bool(_get(ctx, "overwrite", True), True))
        elif operation == "file.json.write":
            value = _json_value(_get(ctx, "json", required=True))
            _write_text(path, json.dumps(value, ensure_ascii=False, indent=2), overwrite=_as_bool(_get(ctx, "overwrite", True), True))
        else:
            text = str(_get(ctx, "xml", required=True))
            ET.fromstring(text)
            _write_text(path, text, overwrite=_as_bool(_get(ctx, "overwrite", True), True))
        _set(ctx, "fileReference", _relative_run_path(run_dir, path))
    else:
        raise ValueError("Unsupported file Built-in operation.")


def _data_operation(ctx: Dict[str, Any], operation: str) -> None:
    if operation == "data.json.serialize":
        value = _json_value(_get(ctx, "value", required=True))
        text = json.dumps(value, ensure_ascii=False, separators=(",", ":"))
        if len(text) > _MAX_JSON_CHARS:
            raise ValueError("Serialized JSON exceeds the Built-in Action limit.")
        _set(ctx, "text", text)
    elif operation == "data.json.set-value":
        value = _json_value(_get(ctx, "json", required=True))
        result = _json_set(value, str(_get(ctx, "path", required=True)), _json_value(_get(ctx, "value")))
        _set(ctx, "json", result)
    elif operation == "data.json.merge":
        left = _json_object(_get(ctx, "left", required=True), allow_empty=False)
        right = _json_object(_get(ctx, "right", required=True), allow_empty=False)
        merged = dict(left)
        merged.update(right)
        _set(ctx, "json", merged)
    elif operation == "data.json.filter-array":
        items = _json_array(_get(ctx, "array", required=True))
        path = str(_get(ctx, "path", required=True))
        expected = _json_value(_get(ctx, "expected"))
        operator = str(_get(ctx, "operator", "Equals") or "Equals")
        result = []
        for item in items:
            try:
                actual = _json_get(item, path)
            except (KeyError, IndexError, TypeError):
                continue
            matched = actual == expected if operator == "Equals" else actual != expected if operator == "NotEquals" else str(expected) in str(actual) if operator == "Contains" else False
            if matched:
                result.append(item)
        _set(ctx, "array", result)
        _set(ctx, "count", len(result))
    elif operation in {"data.xml.parse", "data.xml.to-json"}:
        text = str(_get(ctx, "xml", required=True))
        if len(text) > _MAX_TEXT_CHARS:
            raise ValueError("XML input exceeds the Built-in Action limit.")
        root = ET.fromstring(text)
        _set(ctx, "json", _xml_to_obj(root))
    elif operation == "data.xml.xpath":
        text = str(_get(ctx, "xml", required=True))
        expression = str(_get(ctx, "xpath", required=True))
        if len(text) > _MAX_TEXT_CHARS or len(expression) > 4096:
            raise ValueError("XML/XPath input exceeds the Built-in Action limit.")
        root = ET.fromstring(text)
        nodes = root.findall(expression)
        if len(nodes) > _MAX_COLLECTION_ITEMS:
            raise ValueError("XPath result exceeds the Built-in Action item limit.")
        _set(ctx, "values", [(node.text or "") for node in nodes])
    elif operation == "data.csv.to-json":
        text = str(_get(ctx, "csv", required=True))
        rows = list(csv.DictReader(io.StringIO(text), delimiter=str(_get(ctx, "delimiter", ",") or ",")))
        if len(rows) > _MAX_COLLECTION_ITEMS:
            raise ValueError("CSV row count exceeds the Built-in Action limit.")
        _set(ctx, "json", rows)
    elif operation == "data.json.to-csv":
        rows = _json_array(_get(ctx, "json", required=True))
        if not all(isinstance(row, dict) for row in rows):
            raise ValueError("JSON to CSV requires an array of objects.")
        fieldnames: List[str] = []
        for row in rows:
            for key in row.keys():
                if str(key) not in fieldnames:
                    fieldnames.append(str(key))
        out = io.StringIO()
        writer = csv.DictWriter(out, fieldnames=fieldnames, extrasaction="ignore", delimiter=str(_get(ctx, "delimiter", ",") or ","), lineterminator="\n")
        writer.writeheader(); writer.writerows(rows)
        _set(ctx, "csv", out.getvalue())
    elif operation == "data.regex.extract":
        value = str(_get(ctx, "value", required=True))
        pattern = str(_get(ctx, "pattern", required=True))
        if len(value) > _MAX_TEXT_CHARS or len(pattern) > 4096:
            raise ValueError("Regex input exceeds the Built-in Action limit.")
        group = _as_int(_get(ctx, "group", 0), 0, 0, 100)
        match = re.search(pattern, value)
        _set(ctx, "value", match.group(group) if match else None)
        _set(ctx, "matched", match is not None)
    elif operation == "data.regex.replace":
        value = str(_get(ctx, "value", required=True))
        pattern = str(_get(ctx, "pattern", required=True))
        replacement = str(_get(ctx, "replacement", ""))
        if len(value) > _MAX_TEXT_CHARS or len(pattern) > 4096 or len(replacement) > _MAX_TEXT_CHARS:
            raise ValueError("Regex input exceeds the Built-in Action limit.")
        result = re.sub(pattern, replacement, value, count=_as_int(_get(ctx, "count", 0), 0, 0, 100000))
        if len(result) > _MAX_TEXT_CHARS:
            raise ValueError("Regex replacement output exceeds the Built-in Action limit.")
        _set(ctx, "value", result)
    elif operation == "data.string.replace":
        _set(ctx, "value", str(_get(ctx, "value", required=True)).replace(str(_get(ctx, "old", required=True)), str(_get(ctx, "new", "")), _as_int(_get(ctx, "count", -1), -1, -1, 100000)))
    elif operation == "data.string.split":
        parts = str(_get(ctx, "value", required=True)).split(str(_get(ctx, "separator", required=True)), _as_int(_get(ctx, "maxSplit", -1), -1, -1, 10000))
        if len(parts) > _MAX_COLLECTION_ITEMS:
            raise ValueError("Split result exceeds the Built-in Action item limit.")
        _set(ctx, "values", parts)
    elif operation == "data.string.join":
        values = _json_array(_get(ctx, "values", required=True))
        _set(ctx, "value", str(_get(ctx, "separator", "")).join(str(item) for item in values))
    elif operation == "data.base64.encode":
        raw = str(_get(ctx, "value", required=True)).encode("utf-8")
        if len(raw) > _MAX_TEXT_CHARS:
            raise ValueError("Base64 input exceeds the Built-in Action limit.")
        _set(ctx, "value", base64.b64encode(raw).decode("ascii"))
    elif operation == "data.base64.decode":
        encoded = str(_get(ctx, "value", required=True))
        if len(encoded) > (_MAX_TEXT_CHARS * 2):
            raise ValueError("Base64 input exceeds the Built-in Action limit.")
        decoded = base64.b64decode(encoded, validate=True)
        if len(decoded) > _MAX_TEXT_CHARS:
            raise ValueError("Base64 decoded output exceeds the Built-in Action limit.")
        _set(ctx, "value", decoded.decode("utf-8"))
    elif operation == "data.url.encode":
        _set(ctx, "value", urllib.parse.quote(str(_get(ctx, "value", required=True)), safe=""))
    elif operation == "data.url.decode":
        _set(ctx, "value", urllib.parse.unquote(str(_get(ctx, "value", required=True))))
    else:
        raise ValueError("Unsupported data Built-in operation.")


def _datetime_operation(ctx: Dict[str, Any], operation: str) -> None:
    if operation == "datetime.current":
        zone = str(_get(ctx, "timeZone", "UTC") or "UTC")
        current = dt.datetime.now(_time_zone(zone))
        _set(ctx, "dateTime", current.isoformat())
    elif operation == "datetime.format":
        parsed = _parse_datetime(_get(ctx, "dateTime", required=True), str(_get(ctx, "sourceTimeZone", "UTC") or "UTC"))
        fmt = str(_get(ctx, "format", "%Y-%m-%dT%H:%M:%S%z") or "%Y-%m-%dT%H:%M:%S%z")
        _set(ctx, "text", parsed.strftime(fmt))
    elif operation == "datetime.parse":
        parsed = _parse_datetime(_get(ctx, "text", required=True), str(_get(ctx, "timeZone", "UTC") or "UTC"))
        _set(ctx, "dateTime", parsed.isoformat())
    elif operation == "datetime.add":
        parsed = _parse_datetime(_get(ctx, "dateTime", required=True))
        delta = dt.timedelta(
            days=float(_get(ctx, "days", 0) or 0),
            hours=float(_get(ctx, "hours", 0) or 0),
            minutes=float(_get(ctx, "minutes", 0) or 0),
            seconds=float(_get(ctx, "seconds", 0) or 0),
        )
        _set(ctx, "dateTime", (parsed + delta).isoformat())
    elif operation == "datetime.difference":
        start = _parse_datetime(_get(ctx, "start", required=True))
        end = _parse_datetime(_get(ctx, "end", required=True))
        seconds = (end - start).total_seconds()
        _set(ctx, "totalSeconds", seconds)
        _set(ctx, "totalMinutes", seconds / 60.0)
        _set(ctx, "totalHours", seconds / 3600.0)
        _set(ctx, "totalDays", seconds / 86400.0)
    elif operation == "datetime.convert-time-zone":
        from zoneinfo import ZoneInfo
        parsed = _parse_datetime(_get(ctx, "dateTime", required=True), str(_get(ctx, "sourceTimeZone", "UTC") or "UTC"))
        target = str(_get(ctx, "targetTimeZone", required=True))
        _set(ctx, "dateTime", parsed.astimezone(ZoneInfo(target)).isoformat())
    else:
        raise ValueError("Unsupported date/time Built-in operation.")


def _utility_operation(ctx: Dict[str, Any], operation: str) -> None:
    if operation == "utility.guid.generate":
        _set(ctx, "guid", str(uuid.uuid4()))
    elif operation == "utility.random.string":
        length = _as_int(_get(ctx, "length", 32), 32, 1, 1024)
        alphabet_name = str(_get(ctx, "alphabet", "Alphanumeric") or "Alphanumeric")
        alphabet = string.ascii_letters + string.digits if alphabet_name == "Alphanumeric" else string.ascii_letters if alphabet_name == "Letters" else string.digits if alphabet_name == "Digits" else None
        if not alphabet:
            raise ValueError("alphabet must be Alphanumeric, Letters, or Digits.")
        _set(ctx, "value", "".join(secrets.choice(alphabet) for _ in range(length)))
    elif operation == "utility.random.number":
        minimum = int(_get(ctx, "minimum", 0) or 0)
        maximum = int(_get(ctx, "maximum", 2_147_483_647) or 2_147_483_647)
        if minimum > maximum:
            raise ValueError("minimum must be less than or equal to maximum.")
        _set(ctx, "value", minimum + secrets.randbelow(maximum - minimum + 1))
    elif operation == "utility.sha256":
        _set(ctx, "sha256", hashlib.sha256(str(_get(ctx, "value", required=True)).encode("utf-8")).hexdigest())
    elif operation == "utility.hmac":
        key = str(_get_secret(ctx, "key"))
        message = str(_get(ctx, "value", required=True))
        _set(ctx, "hmac", hmac.new(key.encode("utf-8"), message.encode("utf-8"), hashlib.sha256).hexdigest())
    elif operation == "utility.timestamp":
        now = dt.datetime.now(dt.timezone.utc)
        _set(ctx, "timestamp", now.isoformat().replace("+00:00", "Z"))
        _set(ctx, "unixMilliseconds", int(now.timestamp() * 1000))
    elif operation == "utility.environment-variable":
        name = str(_get(ctx, "name", required=True))
        if name in _secret_keys(ctx):
            raise PermissionError("Environment Variable Built-in cannot expose secret runtime values.")
        if name not in _values(ctx):
            if _as_bool(_get(ctx, "required", False), False):
                raise KeyError(name)
            _set(ctx, "value", None)
        else:
            _set(ctx, "value", _values(ctx)[name])
    elif operation == "utility.machine-information":
        _set(ctx, "machine", {
            "operatingSystem": platform.system(),
            "osRelease": platform.release(),
            "architecture": platform.machine(),
            "pythonVersion": platform.python_version(),
            "processor": platform.processor()[:200],
        })
    else:
        raise ValueError("Unsupported utility Built-in operation.")


def _process_operation(ctx: Dict[str, Any], run_dir: str, operation: str, powershell_path: str) -> None:
    _process_policy(ctx)
    args_value = _get(ctx, "arguments", [])
    if isinstance(args_value, str):
        args = _json_array(args_value)
    elif isinstance(args_value, list):
        args = args_value
    else:
        raise ValueError("arguments must be a JSON array.")
    if len(args) > 256:
        raise ValueError("Process argument count exceeds the Built-in Action limit.")
    if operation in {"process.run", "command.run"}:
        executable = str(_get(ctx, "executable", required=True))
        result = _run_process(ctx, run_dir, executable, args, cwd_relative=_get(ctx, "workingDirectory", "."), stdin_text=str(_get(ctx, "stdin", "")) if _get(ctx, "stdin", None) is not None else None)
    elif operation == "powershell.run":
        script = str(_get(ctx, "script", required=True))
        script_path = _run_path(run_dir, f"process-scripts/{uuid.uuid4().hex}.ps1", directory=False)
        _write_text(script_path, script)
        try:
            # PowerShell is a fixed Dynomax interpreter for this capability, but is enabled only
            # by the explicit Worker process-execution policy. Arbitrary process Actions still
            # require their own executable allow-list entry.
            result = _run_process(ctx, run_dir, powershell_path, ["-NoLogo", "-NoProfile", "-NonInteractive", "-ExecutionPolicy", "Bypass", "-File", str(script_path), *args], cwd_relative=_get(ctx, "workingDirectory", "."), trusted_executable=True)
        finally:
            script_path.unlink(missing_ok=True)
    elif operation == "python.run":
        script = str(_get(ctx, "script", required=True))
        script_path = _run_path(run_dir, f"process-scripts/{uuid.uuid4().hex}.py", directory=False)
        _write_text(script_path, script)
        try:
            result = _run_process(ctx, run_dir, sys.executable, ["-I", str(script_path), *args], cwd_relative=_get(ctx, "workingDirectory", "."), trusted_executable=True)
        finally:
            script_path.unlink(missing_ok=True)
    elif operation == "dotnet.run":
        assembly = _run_path(run_dir, _get(ctx, "applicationPath", required=True), must_exist=True, directory=False)
        dotnet = shutil.which("dotnet") or shutil.which("dotnet.exe")
        if not dotnet:
            raise RuntimeError("dotnet executable is unavailable on the runtime host.")
        result = _run_process(ctx, run_dir, dotnet, [str(assembly), *args], cwd_relative=_get(ctx, "workingDirectory", "."), trusted_executable=True)
    else:
        raise ValueError("Unsupported process Built-in operation.")
    _set(ctx, "exitCode", int(result["exitCode"]))
    _set(ctx, "stdout", result["stdout"], sensitive=True)
    _set(ctx, "stderr", result["stderr"], sensitive=True)
    if int(result["exitCode"]) != 0 and not _as_bool(_get(ctx, "allowNonZeroExit", False), False):
        raise RuntimeError(f"Process exited with code {result['exitCode']}.")


@library(scope="GLOBAL", auto_keywords=False)
class DynomaxBuiltInRuntime:
    @keyword("Execute Dynomax BuiltIn Operation")
    def execute_operation(self, operation: str, context_path: str, run_dir: str, workflow_path: str = "", powershell_path: str = "powershell.exe", dynomax_root: str = "") -> None:
        ctx = _load(str(context_path))
        op = str(operation)
        if op.startswith("data."):
            _data_operation(ctx, op)
        elif op.startswith("file.") or op.startswith("directory."):
            _file_operation(ctx, str(run_dir), op)
        elif op.startswith("datetime."):
            _datetime_operation(ctx, op)
        elif op.startswith("utility."):
            _utility_operation(ctx, op)
        elif op.startswith("email."):
            _email_operation(ctx, str(run_dir), op)
        elif op.startswith("database.sql."):
            mode = {"database.sql.query": "Query", "database.sql.execute": "Execute", "database.sql.scalar": "Scalar", "database.sql.stored-procedure": "StoredProcedure"}[op]
            _database_operation(ctx, mode, str(powershell_path))
        elif op.startswith("process.") or op in {"command.run", "powershell.run", "python.run", "dotnet.run"}:
            _process_operation(ctx, str(run_dir), op, str(powershell_path))
        elif op.startswith("http."):
            self._execute_http(ctx, str(run_dir), op)
        elif op == "validation.http.status":
            expected = _as_int(_get(ctx, "expectedStatus", required=True), 200, 100, 599)
            actual = _as_int(_get(ctx, "status", required=True), 200, 100, 599)
            if actual != expected:
                raise AssertionError(f"Expected HTTP status {expected}, received {actual}.")
            _set(ctx, "verified", True)
        elif op == "validation.json.value":
            actual = _json_get(_get(ctx, "json", required=True), str(_get(ctx, "path", required=True)))
            expected = _json_value(_get(ctx, "expected"))
            if actual != expected:
                raise AssertionError("JSON value did not match the expected value.")
            _set(ctx, "verified", True)
        else:
            raise ValueError(f"Unsupported Dynomax Built-in operation '{op}'.")
        _save(str(context_path), ctx)

    def _execute_http(self, ctx: Dict[str, Any], run_dir: str, op: str) -> None:
        if op in {"http.request", "http.get", "http.post", "http.put", "http.patch", "http.delete", "http.webhook.call"}:
            default = {"http.get": "GET", "http.post": "POST", "http.put": "PUT", "http.patch": "PATCH", "http.delete": "DELETE", "http.webhook.call": "POST"}.get(op)
            method, url, headers, body, timeout = _build_http_inputs(ctx, default)
            result = _http_request(ctx, method, url, headers, body, timeout)
            _publish_http(ctx, result)
        elif op == "http.download-url":
            method, url, headers, _, timeout = _build_http_inputs(ctx, "GET")
            _validate_http_url(ctx, url)
            destination = _run_path(run_dir, _get(ctx, "destinationPath", required=True), directory=False)
            destination.parent.mkdir(parents=True, exist_ok=True)
            opener = urllib.request.build_opener(_SafeRedirectHandler(ctx))
            request = urllib.request.Request(url=url, headers=headers, method=method)
            started = time.monotonic()
            with opener.open(request, timeout=timeout) as response, destination.open("wb") as output:
                total = 0
                while True:
                    block = response.read(1024 * 1024)
                    if not block:
                        break
                    total += len(block)
                    if total > _MAX_FILE_BYTES:
                        output.close(); destination.unlink(missing_ok=True)
                        raise ValueError("HTTP download exceeds the 50 MiB Built-in Action limit.")
                    output.write(block)
                _set(ctx, "status", int(getattr(response, "status", 0)))
                _set(ctx, "headers", _safe_headers(dict(response.headers.items())))
                _set(ctx, "contentType", response.headers.get("Content-Type", ""))
                _set(ctx, "durationMs", int((time.monotonic() - started) * 1000))
                _set(ctx, "finalUrl", response.geturl())
            _set(ctx, "fileReference", _relative_run_path(run_dir, destination))
        elif op == "http.upload-file":
            method, url, headers, _, timeout = _build_http_inputs(ctx, "POST")
            if method not in {"POST", "PUT", "PATCH"}:
                raise ValueError("HTTP file upload supports POST, PUT or PATCH only.")
            path = _run_path(run_dir, _get(ctx, "fileReference", required=True), must_exist=True, directory=False)
            fields = _json_object(_get(ctx, "fields", {}))
            body, content_type = _multipart_body(fields, str(_get(ctx, "fieldName", "file") or "file"), path)
            headers["Content-Type"] = content_type
            result = _http_request(ctx, method, url, headers, body, timeout)
            _publish_http(ctx, result)
        elif op == "http.oauth2.token":
            url = str(_get(ctx, "url", required=True))
            client_id = str(_get(ctx, "clientId", required=True))
            client_secret = str(_get_secret(ctx, "clientSecret"))
            scopes = str(_get(ctx, "scope", "") or "")
            form = {"grant_type": str(_get(ctx, "grantType", "client_credentials") or "client_credentials"), "client_id": client_id, "client_secret": client_secret}
            if scopes:
                form["scope"] = scopes
            body = urllib.parse.urlencode(form).encode("utf-8")
            timeout = _as_int(_get(ctx, "timeoutSeconds", 30), 30, 1, 300)
            result = _http_request(ctx, "POST", url, {"Content-Type": "application/x-www-form-urlencoded", "Accept": "application/json"}, body, timeout)
            if not 200 <= int(result["status"]) < 300:
                raise RuntimeError(f"OAuth token endpoint returned HTTP {result['status']}.")
            token = _json_object(result["body"], allow_empty=False)
            access_token = token.get("access_token")
            if not access_token:
                raise RuntimeError("OAuth token response did not contain access_token.")
            _set(ctx, "accessToken", str(access_token), sensitive=True)
            _set(ctx, "tokenType", str(token.get("token_type") or "Bearer"))
            _set(ctx, "expiresIn", token.get("expires_in"))
        elif op in {"http.bearer.request", "http.basic.request"}:
            method, url, headers, body, timeout = _build_http_inputs(ctx, "GET")
            if op == "http.bearer.request":
                token = _get(ctx, "accessToken", required=True)
                headers["Authorization"] = f"Bearer {token}"
            else:
                username = str(_get_secret(ctx, "username"))
                password = str(_get_secret(ctx, "password"))
                encoded = base64.b64encode(f"{username}:{password}".encode("utf-8")).decode("ascii")
                headers["Authorization"] = f"Basic {encoded}"
            result = _http_request(ctx, method, url, headers, body, timeout)
            _publish_http(ctx, result)
        else:
            raise ValueError("Unsupported HTTP Built-in operation.")

    @keyword("Resolve Dynomax BuiltIn Run Path")
    def resolve_run_path(self, run_dir: str, relative: str, must_exist: bool = True) -> str:
        return str(_run_path(str(run_dir), relative, must_exist=_as_bool(must_exist, True)))

    @keyword("Prepare Dynomax BuiltIn Run Directory")
    def prepare_run_directory(self, run_dir: str, relative: str) -> str:
        path = _run_path(str(run_dir), relative, directory=True)
        path.mkdir(parents=True, exist_ok=True)
        return str(path)

    @keyword("Record Dynomax BuiltIn Download")
    def record_download(self, context_path: str, run_dir: str, save_as: str) -> None:
        ctx = _load(str(context_path))
        relative = _relative_run_path(str(run_dir), save_as)
        _set(ctx, "fileReference", relative)
        _save(str(context_path), ctx)
""";

    private const string DownloadBuiltInRuntimeLibrary = """
from __future__ import annotations

import re
import shutil
import uuid
from pathlib import Path

from robot.api.deco import keyword, library
from DynomaxBuiltInRuntime import _load, _save, _set

_INVALID_FILENAME = re.compile(r'[<>:"/\\|?*\x00-\x1f]')
_WINDOWS_RESERVED = {
    "CON", "PRN", "AUX", "NUL",
    "COM1", "COM2", "COM3", "COM4", "COM5", "COM6", "COM7", "COM8", "COM9",
    "LPT1", "LPT2", "LPT3", "LPT4", "LPT5", "LPT6", "LPT7", "LPT8", "LPT9",
}


def _run_directory(run_dir: str, relative: object) -> Path:
    text = str(relative or "").strip().replace("\\", "/")
    if not text:
        raise ValueError("A run-workspace relative destination directory is required.")
    if len(text) > 1024 or text.startswith("/") or re.match(r"^[A-Za-z]:", text):
        raise ValueError("Download destinationDirectory must be relative to the disposable run workspace.")
    root = Path(run_dir).resolve()
    candidate = (root / text).resolve(strict=False)
    try:
        candidate.relative_to(root)
    except ValueError as ex:
        raise ValueError("Download destinationDirectory escaped the disposable run workspace.") from ex
    current = root
    for part in candidate.relative_to(root).parts:
        current = current / part
        if current.exists() and current.is_symlink():
            raise ValueError("Download destinationDirectory may not traverse symbolic links or junction-like links.")
    if candidate.exists() and not candidate.is_dir():
        raise ValueError("Download destinationDirectory must resolve to a directory.")
    candidate.mkdir(parents=True, exist_ok=True)
    return candidate


def _contained_file(run_dir: str, value: object, *, must_exist: bool) -> Path:
    root = Path(run_dir).resolve()
    candidate = Path(str(value or "")).resolve(strict=False)
    try:
        candidate.relative_to(root)
    except ValueError as ex:
        raise ValueError("Downloaded file escaped the disposable run workspace.") from ex
    if must_exist and not candidate.is_file():
        raise FileNotFoundError("Browser download did not produce the expected run-workspace file.")
    return candidate


def _safe_name(value: object) -> str:
    raw = Path(str(value or "").replace("\\", "/")).name
    name = _INVALID_FILENAME.sub("_", raw).strip().rstrip(". ")
    if not name or name in {".", ".."}:
        name = "download"
    stem = Path(name).stem.rstrip(". ") or "download"
    suffix = Path(name).suffix
    if stem.upper() in _WINDOWS_RESERVED:
        stem = f"_{stem}"
    # Keep useful spaces and extension while bounding Windows path-component length.
    max_component = 180
    available = max(1, max_component - len(suffix))
    stem = stem[:available].rstrip(". ") or "download"
    return f"{stem}{suffix}"


def _unique_target(directory: Path, filename: str) -> Path:
    candidate = directory / filename
    if not candidate.exists():
        return candidate
    parsed = Path(filename)
    stem = parsed.stem or "download"
    suffix = parsed.suffix
    for index in range(2, 10002):
        candidate = directory / f"{stem} ({index}){suffix}"
        if not candidate.exists():
            return candidate
    raise RuntimeError("Unable to allocate a unique safe download filename.")


@library(scope="GLOBAL", auto_keywords=False)
class DynomaxBuiltInDownload:
    @keyword("Prepare Dynomax BuiltIn Download Target")
    def prepare_target(self, run_dir: str, destination_directory: str) -> str:
        directory = _run_directory(run_dir, destination_directory)
        return str(directory / f".dynomax-download-{uuid.uuid4().hex}.tmp")

    @keyword("Finalize Dynomax BuiltIn Download")
    def finalize_download(
        self,
        context_path: str,
        run_dir: str,
        destination_directory: str,
        save_as: str,
        suggested_filename: str,
    ) -> None:
        source = _contained_file(run_dir, save_as, must_exist=True)
        directory = _run_directory(run_dir, destination_directory)
        try:
            source.relative_to(directory)
        except ValueError as ex:
            raise ValueError("Browser download was written outside destinationDirectory.") from ex
        filename = _safe_name(suggested_filename)
        target = _unique_target(directory, filename)
        if source != target:
            shutil.move(str(source), str(target))
        root = Path(run_dir).resolve()
        relative = target.resolve(strict=True).relative_to(root).as_posix()

        # Reuse the existing Dynomax context helpers so the final public output remains
        # a normal run-workspace-relative FileReference with the existing atomic save semantics.
        context = _load(str(context_path))
        _set(context, "fileReference", relative)
        _save(str(context_path), context)
""";

    private const string ParseJsonLibrary = """
import json

_MAX_JSON_CHARS = 1_048_576

def dynomax_parse_json_value(value):
    if isinstance(value, str):
        if len(value) > _MAX_JSON_CHARS:
            raise ValueError("JSON input exceeds the 1 MiB Built-in Action limit")
        return json.loads(value)
    return value
""";

    private const string GetJsonValueLibrary = """
import json
import re

_MAX_JSON_CHARS = 1_048_576
_MAX_PATH_CHARS = 1024
_MAX_PATH_TOKENS = 128

def _dynomax_parse_json_value(value):
    if isinstance(value, str):
        if len(value) > _MAX_JSON_CHARS:
            raise ValueError("JSON input exceeds the 1 MiB Built-in Action limit")
        return json.loads(value)
    return value


def dynomax_get_json_path(value, path):
    current = _dynomax_parse_json_value(value)
    path_text = "" if path is None else str(path).strip()
    if path_text == "":
        return current
    if len(path_text) > _MAX_PATH_CHARS:
        raise ValueError("JSON path exceeds the Built-in Action limit")
    token_re = re.compile(r"(?:^|\.)([^.\[\]]+)|\[(\d+)\]")
    cursor = 0
    token_count = 0
    for match in token_re.finditer(path_text):
        token_count += 1
        if token_count > _MAX_PATH_TOKENS:
            raise ValueError("JSON path contains too many segments")
        if match.start() != cursor:
            raise ValueError("Invalid JSON path syntax")
        key, index = match.groups()
        if key is not None:
            if not isinstance(current, dict) or key not in current:
                raise KeyError(key)
            current = current[key]
        else:
            if not isinstance(current, list):
                raise TypeError("JSON path index requires an array")
            current = current[int(index)]
        cursor = match.end()
    if cursor != len(path_text):
        raise ValueError("Invalid JSON path syntax")
    return current
""";

    private const string SensitiveJsonV2RuntimeLibrary = """
from __future__ import annotations

import json
import os
import re
import tempfile
from typing import Any, Dict, List

from robot.api.deco import keyword, library

_MAX_JSON_CHARS = 1_048_576
_MAX_PATH_CHARS = 1024
_MAX_PATH_TOKENS = 128


def _load(path: str) -> Dict[str, Any]:
    with open(path, "r", encoding="utf-8") as stream:
        value = json.load(stream)
    if not isinstance(value, dict):
        raise RuntimeError("Dynomax runtime context is invalid.")
    return value


def _save(path: str, context: Dict[str, Any]) -> None:
    target = os.path.abspath(path)
    fd, temp_name = tempfile.mkstemp(prefix=".dynomax-sensitive-json-", suffix=".tmp", dir=os.path.dirname(target))
    try:
        with os.fdopen(fd, "w", encoding="utf-8", newline="\n") as stream:
            json.dump(context, stream, ensure_ascii=False, indent=2, default=str)
            stream.write("\n")
        os.replace(temp_name, target)
    except Exception:
        try:
            os.unlink(temp_name)
        except OSError:
            pass
        raise


def _values(ctx: Dict[str, Any]) -> Dict[str, Any]:
    values = ctx.setdefault("values", {})
    if not isinstance(values, dict):
        raise RuntimeError("Dynomax runtime context values are invalid.")
    return values


def _secret_keys(ctx: Dict[str, Any]) -> set[str]:
    return {str(value) for value in (ctx.get("secretKeys") or []) if str(value).strip()}


def _get(ctx: Dict[str, Any], name: str, default: Any = None, *, required: bool = False) -> Any:
    value = _values(ctx).get(name, default)
    if required and (value is None or (isinstance(value, str) and value.strip() == "")):
        raise ValueError(f"Required Built-in Action input '{name}' is missing.")
    return value


def _set(ctx: Dict[str, Any], name: str, value: Any, *, sensitive: bool) -> None:
    _values(ctx)[name] = value
    keys = _secret_keys(ctx)
    if sensitive:
        keys.add(name)
    else:
        keys.discard(name)
    ctx["secretKeys"] = sorted(keys)


def _is_sensitive(ctx: Dict[str, Any], *names: str) -> bool:
    keys = _secret_keys(ctx)
    return any(name in keys for name in names)


def _json_value(value: Any) -> Any:
    if isinstance(value, str):
        if len(value) > _MAX_JSON_CHARS:
            raise ValueError("JSON input exceeds the 1 MiB Built-in Action limit.")
        return json.loads(value)
    return value


def _json_object(value: Any) -> Dict[str, Any]:
    parsed = _json_value(value)
    if not isinstance(parsed, dict):
        raise ValueError("Input must be a JSON object.")
    return parsed


def _path_tokens(path: str) -> List[Any]:
    text = str(path or "").strip()
    if text == "":
        return []
    if len(text) > _MAX_PATH_CHARS:
        raise ValueError("JSON path exceeds the Built-in Action limit.")
    token_re = re.compile(r"(?:^|\.)([^.\[\]]+)|\[(\d+)\]")
    cursor = 0
    tokens: List[Any] = []
    for match in token_re.finditer(text):
        if match.start() != cursor:
            raise ValueError("Invalid JSON path syntax.")
        key, index = match.groups()
        tokens.append(key if key is not None else int(index))
        if len(tokens) > _MAX_PATH_TOKENS:
            raise ValueError("JSON path contains too many segments.")
        cursor = match.end()
    if cursor != len(text):
        raise ValueError("Invalid JSON path syntax.")
    return tokens


def _json_set(value: Any, path: str, new_value: Any) -> Any:
    root = _json_value(value)
    tokens = _path_tokens(path)
    if not tokens:
        return new_value
    current = root
    for token in tokens[:-1]:
        if isinstance(token, int):
            if not isinstance(current, list) or token < 0 or token >= len(current):
                raise IndexError(f"JSON array index {token} is unavailable.")
            current = current[token]
        else:
            if not isinstance(current, dict):
                raise TypeError("JSON path object segment requires an object.")
            if token not in current:
                current[token] = {}
            current = current[token]
    last = tokens[-1]
    if isinstance(last, int):
        if not isinstance(current, list) or last < 0 or last >= len(current):
            raise IndexError(f"JSON array index {last} is unavailable.")
        current[last] = new_value
    else:
        if not isinstance(current, dict):
            raise TypeError("JSON path object segment requires an object.")
        current[last] = new_value
    return root


@library(scope="GLOBAL", auto_keywords=False)
class DynomaxBuiltInSensitiveJson:
    @keyword("Execute Dynomax Sensitive JSON Operation")
    def execute(self, operation: str, context_path: str) -> None:
        ctx = _load(str(context_path))
        if operation == "data.json.serialize":
            value = _json_value(_get(ctx, "value", required=True))
            rendered = json.dumps(value, ensure_ascii=False, separators=(",", ":"))
            if len(rendered) > _MAX_JSON_CHARS:
                raise ValueError("Serialized JSON exceeds the Built-in Action limit.")
            _set(ctx, "text", rendered, sensitive=_is_sensitive(ctx, "value"))
        elif operation == "data.json.set-value":
            source = _json_value(_get(ctx, "json", required=True))
            path = str(_get(ctx, "path", required=True))
            new_value = _json_value(_get(ctx, "value"))
            result = _json_set(source, path, new_value)
            _set(ctx, "json", result, sensitive=_is_sensitive(ctx, "json", "value"))
        elif operation == "data.json.merge":
            left = _json_object(_get(ctx, "left", required=True))
            right = _json_object(_get(ctx, "right", required=True))
            merged = dict(left)
            merged.update(right)
            _set(ctx, "json", merged, sensitive=_is_sensitive(ctx, "left", "right"))
        elif operation == "data.json.set-string":
            source = _json_value(_get(ctx, "json", required=True))
            path = str(_get(ctx, "path", required=True))
            new_value = str(_get(ctx, "value", required=True))
            result = _json_set(source, path, new_value)
            _set(ctx, "json", result, sensitive=_is_sensitive(ctx, "json", "value"))
        else:
            raise ValueError("Unsupported sensitive JSON Built-in operation.")
        _save(str(context_path), ctx)
""";

    private const string SensitiveJsonGetStringRuntimeLibrary = """
from __future__ import annotations

import json
import os
import re
import tempfile
from typing import Any, Dict, List

from robot.api.deco import keyword, library

_MAX_JSON_CHARS = 1_048_576
_MAX_PATH_CHARS = 1024
_MAX_PATH_TOKENS = 128


def _load(path: str) -> Dict[str, Any]:
    with open(path, "r", encoding="utf-8") as stream:
        value = json.load(stream)
    if not isinstance(value, dict):
        raise RuntimeError("Dynomax runtime context is invalid.")
    return value


def _save(path: str, context: Dict[str, Any]) -> None:
    target = os.path.abspath(path)
    fd, temp_name = tempfile.mkstemp(prefix=".dynomax-sensitive-json-", suffix=".tmp", dir=os.path.dirname(target))
    try:
        with os.fdopen(fd, "w", encoding="utf-8", newline="\n") as stream:
            json.dump(context, stream, ensure_ascii=False, indent=2, default=str)
            stream.write("\n")
        os.replace(temp_name, target)
    except Exception:
        try:
            os.unlink(temp_name)
        except OSError:
            pass
        raise


def _values(ctx: Dict[str, Any]) -> Dict[str, Any]:
    values = ctx.setdefault("values", {})
    if not isinstance(values, dict):
        raise RuntimeError("Dynomax runtime context values are invalid.")
    return values


def _secret_keys(ctx: Dict[str, Any]) -> set[str]:
    return {str(value) for value in (ctx.get("secretKeys") or []) if str(value).strip()}


def _sensitive_keys(ctx: Dict[str, Any]) -> set[str]:
    keys = _secret_keys(ctx)
    keys.update(str(value) for value in (ctx.get("sensitiveKeys") or []) if str(value).strip())
    return keys


def _get(ctx: Dict[str, Any], name: str, default: Any = None, *, required: bool = False) -> Any:
    value = _values(ctx).get(name, default)
    if required and (value is None or (isinstance(value, str) and value.strip() == "")):
        raise ValueError(f"Required Built-in Action input '{name}' is missing.")
    return value


def _set(ctx: Dict[str, Any], name: str, value: Any, *, sensitive: bool) -> None:
    _values(ctx)[name] = value
    keys = _secret_keys(ctx)
    if sensitive:
        keys.add(name)
    else:
        keys.discard(name)
    ctx["secretKeys"] = sorted(keys)


def _is_sensitive(ctx: Dict[str, Any], *names: str) -> bool:
    keys = _sensitive_keys(ctx)
    return any(name in keys for name in names)


def _json_value(value: Any) -> Any:
    if isinstance(value, str):
        if len(value) > _MAX_JSON_CHARS:
            raise ValueError("JSON input exceeds the 1 MiB Built-in Action limit.")
        return json.loads(value)
    return value


def _json_object(value: Any) -> Dict[str, Any]:
    parsed = _json_value(value)
    if not isinstance(parsed, dict):
        raise ValueError("Input must be a JSON object.")
    return parsed


def _path_tokens(path: str) -> List[Any]:
    text = str(path or "").strip()
    if text == "":
        return []
    if len(text) > _MAX_PATH_CHARS:
        raise ValueError("JSON path exceeds the Built-in Action limit.")
    token_re = re.compile(r"(?:^|\.)([^.\[\]]+)|\[(\d+)\]")
    cursor = 0
    tokens: List[Any] = []
    for match in token_re.finditer(text):
        if match.start() != cursor:
            raise ValueError("Invalid JSON path syntax.")
        key, index = match.groups()
        tokens.append(key if key is not None else int(index))
        if len(tokens) > _MAX_PATH_TOKENS:
            raise ValueError("JSON path contains too many segments.")
        cursor = match.end()
    if cursor != len(text):
        raise ValueError("Invalid JSON path syntax.")
    return tokens


def _json_get(value: Any, path: str) -> Any:
    current = _json_value(value)
    for token in _path_tokens(path):
        if isinstance(token, int):
            if not isinstance(current, list) or token < 0 or token >= len(current):
                raise IndexError(f"JSON array index {token} is unavailable.")
            current = current[token]
        else:
            if not isinstance(current, dict) or token not in current:
                raise KeyError(str(token))
            current = current[token]
    return current


def _json_set(value: Any, path: str, new_value: Any) -> Any:
    root = _json_value(value)
    tokens = _path_tokens(path)
    if not tokens:
        return new_value
    current = root
    for token in tokens[:-1]:
        if isinstance(token, int):
            if not isinstance(current, list) or token < 0 or token >= len(current):
                raise IndexError(f"JSON array index {token} is unavailable.")
            current = current[token]
        else:
            if not isinstance(current, dict):
                raise TypeError("JSON path object segment requires an object.")
            if token not in current:
                current[token] = {}
            current = current[token]
    last = tokens[-1]
    if isinstance(last, int):
        if not isinstance(current, list) or last < 0 or last >= len(current):
            raise IndexError(f"JSON array index {last} is unavailable.")
        current[last] = new_value
    else:
        if not isinstance(current, dict):
            raise TypeError("JSON path object segment requires an object.")
        current[last] = new_value
    return root


@library(scope="GLOBAL", auto_keywords=False)
class DynomaxBuiltInSensitiveJson:
    @keyword("Execute Dynomax Sensitive JSON Operation")
    def execute(self, operation: str, context_path: str) -> None:
        ctx = _load(str(context_path))
        if operation == "data.json.serialize":
            value = _json_value(_get(ctx, "value", required=True))
            rendered = json.dumps(value, ensure_ascii=False, separators=(",", ":"))
            if len(rendered) > _MAX_JSON_CHARS:
                raise ValueError("Serialized JSON exceeds the Built-in Action limit.")
            _set(ctx, "text", rendered, sensitive=_is_sensitive(ctx, "value"))
        elif operation == "data.json.set-value":
            source = _json_value(_get(ctx, "json", required=True))
            path = str(_get(ctx, "path", required=True))
            new_value = _json_value(_get(ctx, "value"))
            result = _json_set(source, path, new_value)
            _set(ctx, "json", result, sensitive=_is_sensitive(ctx, "json", "value"))
        elif operation == "data.json.merge":
            left = _json_object(_get(ctx, "left", required=True))
            right = _json_object(_get(ctx, "right", required=True))
            merged = dict(left)
            merged.update(right)
            _set(ctx, "json", merged, sensitive=_is_sensitive(ctx, "left", "right"))
        elif operation == "data.json.set-string":
            source = _json_value(_get(ctx, "json", required=True))
            path = str(_get(ctx, "path", required=True))
            new_value = str(_get(ctx, "value", required=True))
            result = _json_set(source, path, new_value)
            _set(ctx, "json", result, sensitive=_is_sensitive(ctx, "json", "value"))
        elif operation == "data.json.get-string":
            source = _json_value(_get(ctx, "json", required=True))
            path = str(_get(ctx, "path", required=True))
            selected = _json_get(source, path)
            if not isinstance(selected, str):
                raise ValueError("Selected JSON value must be a string.")
            _set(ctx, "value", selected, sensitive=_is_sensitive(ctx, "json"))
        else:
            raise ValueError("Unsupported sensitive JSON Built-in operation.")
        _save(str(context_path), ctx)
""";

    private static string ImapV3RuntimeLibrary => ImapV2RuntimeLibrary
        .Replace("class DynomaxBuiltInImapV2:", "class DynomaxBuiltInImapV3:", StringComparison.Ordinal)
        .Replace("Execute Dynomax IMAP V2 Operation", "Execute Dynomax IMAP V3 Operation", StringComparison.Ordinal)
        .Replace("_set(ctx, \"message\", messages[-1] if messages else None, sensitive=True)",
            "if not messages:\n                        raise LookupError(\"DYNOMAX_IMAP_NO_MATCH: No IMAP message matched the requested criteria.\")\n                    _set(ctx, \"message\", messages[-1], sensitive=True)", StringComparison.Ordinal);

    private const string ImapV2RuntimeLibrary = """
from __future__ import annotations

import email
import email.header
import email.policy
import imaplib
import json
import os
import re
import ssl
import tempfile
from pathlib import Path
from typing import Any, Dict, List

from robot.api.deco import keyword, library

_MAX_TEXT_CHARS = 1_048_576
_MAX_FILE_BYTES = 50 * 1024 * 1024


def _load(path: str) -> Dict[str, Any]:
    with open(path, "r", encoding="utf-8") as stream:
        value = json.load(stream)
    if not isinstance(value, dict):
        raise RuntimeError("Dynomax runtime context is invalid.")
    return value


def _save(path: str, context: Dict[str, Any]) -> None:
    target = os.path.abspath(path)
    fd, temp_name = tempfile.mkstemp(prefix=".dynomax-imap-v2-", suffix=".tmp", dir=os.path.dirname(target))
    try:
        with os.fdopen(fd, "w", encoding="utf-8", newline="\n") as stream:
            json.dump(context, stream, ensure_ascii=False, indent=2, default=str)
            stream.write("\n")
        os.replace(temp_name, target)
    except Exception:
        try:
            os.unlink(temp_name)
        except OSError:
            pass
        raise


def _values(ctx: Dict[str, Any]) -> Dict[str, Any]:
    values = ctx.setdefault("values", {})
    if not isinstance(values, dict):
        raise RuntimeError("Dynomax runtime context values are invalid.")
    return values


def _secret_keys(ctx: Dict[str, Any]) -> set[str]:
    return {str(value) for value in (ctx.get("secretKeys") or []) if str(value).strip()}


def _get(ctx: Dict[str, Any], name: str, default: Any = None, *, required: bool = False) -> Any:
    value = _values(ctx).get(name, default)
    if required and (value is None or (isinstance(value, str) and value.strip() == "")):
        raise ValueError(f"Required Built-in Action input '{name}' is missing.")
    return value


def _get_secret(ctx: Dict[str, Any], name: str) -> Any:
    if name not in _secret_keys(ctx):
        raise ValueError(f"Built-in Action input '{name}' must be supplied through a secret reference.")
    value = _values(ctx).get(name)
    if value is None or (isinstance(value, str) and value == ""):
        raise ValueError(f"Required Built-in Action secret input '{name}' is unavailable.")
    return value


def _set(ctx: Dict[str, Any], name: str, value: Any, *, sensitive: bool = False) -> None:
    _values(ctx)[name] = value
    keys = _secret_keys(ctx)
    if sensitive:
        keys.add(name)
    else:
        keys.discard(name)
    ctx["secretKeys"] = sorted(keys)


def _as_bool(value: Any, default: bool = False) -> bool:
    if value is None:
        return default
    if isinstance(value, bool):
        return value
    if isinstance(value, (int, float)):
        return value != 0
    return str(value).strip().lower() in {"1", "true", "yes", "y", "on"}


def _as_int(value: Any, default: int, minimum: int, maximum: int) -> int:
    if value is None or str(value).strip() == "":
        parsed = default
    else:
        parsed = int(value)
    if parsed < minimum or parsed > maximum:
        raise ValueError(f"Integer input must be between {minimum} and {maximum}.")
    return parsed


def _profile(ctx: Dict[str, Any]) -> Dict[str, Any]:
    host = str(_get(ctx, "host", required=True)).strip()
    username = str(_get(ctx, "username", required=True)).strip()
    password = _get_secret(ctx, "password")
    port = _as_int(_get(ctx, "port", 993), 993, 1, 65535)
    security = str(_get(ctx, "security", "ssl") or "ssl").strip().lower()
    timeout = _as_int(_get(ctx, "timeoutSeconds", 30), 30, 1, 300)
    if security not in {"ssl", "starttls"}:
        raise ValueError("IMAP security must be 'ssl' or 'starttls'.")
    return {"host": host, "port": port, "security": security, "timeoutSeconds": timeout, "username": username, "password": password}


def _connect(profile: Dict[str, Any]):
    if profile["security"] == "ssl":
        client = imaplib.IMAP4_SSL(profile["host"], profile["port"], ssl_context=ssl.create_default_context(), timeout=profile["timeoutSeconds"])
    else:
        client = imaplib.IMAP4(profile["host"], profile["port"], timeout=profile["timeoutSeconds"])
        client.starttls(ssl_context=ssl.create_default_context())
    client.login(profile["username"], str(profile["password"]))
    return client


def _decode_header(value: str | None) -> str:
    if not value:
        return ""
    out = []
    for part, charset in email.header.decode_header(value):
        out.append(part.decode(charset or "utf-8", errors="replace") if isinstance(part, bytes) else part)
    return "".join(out)


def _message_summary(uid: str, raw: bytes, include_body: bool) -> Dict[str, Any]:
    msg = email.message_from_bytes(raw, policy=email.policy.default)
    body = ""
    attachments = []
    for part in msg.walk():
        if part.is_multipart():
            continue
        filename = part.get_filename()
        if filename:
            payload = part.get_payload(decode=True) or b""
            attachments.append({"fileName": _decode_header(filename), "contentType": part.get_content_type(), "size": len(payload)})
            continue
        if include_body and part.get_content_type() == "text/plain" and not body:
            payload = part.get_payload(decode=True) or b""
            charset = part.get_content_charset() or "utf-8"
            body = payload.decode(charset, errors="replace")[:_MAX_TEXT_CHARS]
    return {"messageId": uid, "from": _decode_header(msg.get("From")), "to": _decode_header(msg.get("To")), "subject": _decode_header(msg.get("Subject")), "date": str(msg.get("Date") or ""), "body": body, "attachments": attachments}


def _search(client, criteria: str, limit: int, include_body: bool) -> List[Dict[str, Any]]:
    typ, data = client.uid("search", None, criteria or "ALL")
    if typ != "OK":
        raise RuntimeError("IMAP search failed.")
    ids = (data[0] or b"").split()[-limit:]
    result = []
    for uid in ids:
        typ, message_data = client.uid("fetch", uid, "(BODY.PEEK[])")
        if typ != "OK" or not message_data:
            continue
        raw = next((item[1] for item in message_data if isinstance(item, tuple) and isinstance(item[1], bytes)), b"")
        if raw:
            result.append(_message_summary(uid.decode("ascii", errors="ignore"), raw, include_body))
    return result


def _run_directory(run_dir: str, relative: Any) -> Path:
    text = str(relative or "").strip().replace("\\", "/")
    if not text:
        raise ValueError("A run-workspace relative destination directory is required.")
    if len(text) > 1024 or text.startswith("/") or re.match(r"^[A-Za-z]:", text):
        raise ValueError("IMAP destinationDirectory must be relative to the disposable run workspace.")
    root = Path(run_dir).resolve()
    candidate = (root / text).resolve(strict=False)
    try:
        candidate.relative_to(root)
    except ValueError as ex:
        raise ValueError("IMAP destinationDirectory escaped the disposable run workspace.") from ex
    candidate.mkdir(parents=True, exist_ok=True)
    return candidate


@library(scope="GLOBAL", auto_keywords=False)
class DynomaxBuiltInImapV2:
    @keyword("Execute Dynomax IMAP V2 Operation")
    def execute(self, operation: str, context_path: str, run_dir: str) -> None:
        ctx = _load(str(context_path))
        profile = _profile(ctx)
        folder = str(_get(ctx, "folder", "INBOX") or "INBOX")
        client = _connect(profile)
        try:
            typ, _ = client.select(folder)
            if typ != "OK":
                raise RuntimeError("IMAP mailbox selection failed.")
            if operation in {"email.imap.read", "email.imap.find", "email.imap.latest"}:
                limit = 1 if operation == "email.imap.latest" else _as_int(_get(ctx, "limit", 20), 20, 1, 200)
                criteria = str(_get(ctx, "criteria", "ALL") or "ALL")
                include_body = _as_bool(_get(ctx, "includeBody", True), True)
                messages = _search(client, criteria, limit, include_body)
                if operation == "email.imap.latest":
                    _set(ctx, "message", messages[-1] if messages else None, sensitive=True)
                else:
                    _set(ctx, "messages", messages, sensitive=True)
                    _set(ctx, "count", len(messages))
            elif operation == "email.imap.download-attachments":
                uid = str(_get(ctx, "messageId", required=True))
                typ, message_data = client.uid("fetch", uid, "(BODY.PEEK[])")
                if typ != "OK":
                    raise RuntimeError("IMAP message fetch failed.")
                raw = next((item[1] for item in message_data if isinstance(item, tuple) and isinstance(item[1], bytes)), b"")
                msg = email.message_from_bytes(raw, policy=email.policy.default)
                target_dir = _run_directory(run_dir, _get(ctx, "destinationDirectory", f"email-attachments/{uid}"))
                saved = []
                for index, part in enumerate(msg.iter_attachments()):
                    if len(saved) >= 50:
                        raise ValueError("Email contains too many attachments.")
                    filename = _decode_header(part.get_filename()) or f"attachment-{index + 1}"
                    filename = re.sub(r"[^A-Za-z0-9._ -]+", "_", filename).strip(" .") or f"attachment-{index + 1}"
                    path = (target_dir / filename).resolve(strict=False)
                    try:
                        path.relative_to(target_dir.resolve())
                    except ValueError as ex:
                        raise ValueError("Attachment filename escaped destination directory.") from ex
                    payload = part.get_payload(decode=True) or b""
                    if len(payload) > _MAX_FILE_BYTES:
                        raise ValueError("Email attachment exceeds the Built-in Action size limit.")
                    path.write_bytes(payload)
                    saved.append(path.relative_to(Path(run_dir).resolve()).as_posix())
                _set(ctx, "attachments", saved)
            elif operation == "email.imap.mark-read":
                uid = str(_get(ctx, "messageId", required=True))
                read = _as_bool(_get(ctx, "read", True), True)
                typ, _ = client.uid("store", uid, "+FLAGS" if read else "-FLAGS", "(\\Seen)")
                if typ != "OK":
                    raise RuntimeError("IMAP read-state update failed.")
                _set(ctx, "updated", True)
            elif operation == "email.imap.move":
                uid = str(_get(ctx, "messageId", required=True))
                destination = str(_get(ctx, "destinationFolder", required=True))
                typ, _ = client.uid("MOVE", uid, destination)
                if typ != "OK":
                    typ, _ = client.uid("COPY", uid, destination)
                    if typ != "OK":
                        raise RuntimeError("IMAP move/copy failed.")
                    client.uid("store", uid, "+FLAGS", "(\\Deleted)")
                    client.expunge()
                _set(ctx, "moved", True)
            elif operation == "email.imap.delete":
                uid = str(_get(ctx, "messageId", required=True))
                typ, _ = client.uid("store", uid, "+FLAGS", "(\\Deleted)")
                if typ != "OK":
                    raise RuntimeError("IMAP delete failed.")
                client.expunge()
                _set(ctx, "deleted", True)
            else:
                raise ValueError("Unsupported IMAP v2 Built-in operation.")
        finally:
            try:
                client.logout()
            except Exception:
                pass
        _save(str(context_path), ctx)
""";

    private const string StructuredFormV2RobotResource = """
Dynomax BuiltIn Snapshot Form Fields
    ${fields}=    Get Dynomax Context Value    fields
    ${root_selector}=    Get Dynomax Context Value    rootSelector    ${EMPTY}
    ${payload_json}=    Evaluate    json.dumps({'fields': $fields, 'rootSelector': $root_selector}, ensure_ascii=True, separators=(',', ':'))    modules=json
    ${snapshot}=    Evaluate JavaScript    css=html    (root, payloadJson) => { const payload=JSON.parse(payloadJson); const definitions=payload.fields; const rootSelector=payload.rootSelector||''; const scope=rootSelector ? document.querySelector(rootSelector) : document; if(!scope) throw new Error('Form snapshot root not found: ' + rootSelector); const result={}; for(const [name,raw] of Object.entries(definitions)){ const descriptor=typeof raw==='string' ? {selector:raw} : raw; if(!descriptor || typeof descriptor.selector!=='string' || !descriptor.selector.trim()) throw new Error("Form snapshot field '" + name + "' requires a selector."); const element=scope.querySelector(descriptor.selector); if(!element) throw new Error("Form snapshot field '" + name + "' not found: " + descriptor.selector); const kind=String(descriptor.kind||'auto').toLowerCase(); let value; if(kind==='checked' || (kind==='auto' && (element.type==='checkbox' || element.type==='radio'))){ value=Boolean(element.checked); } else if(kind==='selectedvalues' || (kind==='auto' && element.tagName==='SELECT' && element.multiple)){ value=[...element.selectedOptions].map(option=>option.value); } else if(kind==='text'){ value=element.textContent ?? ''; } else if(kind==='attribute'){ if(!descriptor.attribute) throw new Error("Form snapshot field '" + name + "' requires attribute."); value=element.getAttribute(descriptor.attribute); } else if(kind==='value' || kind==='auto'){ value='value' in element ? element.value : (element.textContent ?? ''); } else { throw new Error("Unsupported form snapshot kind '" + kind + "' for '" + name + "'."); } result[name]=value; } return result; }    arg=${payload_json}
    Set Dynomax Context Value    snapshot    ${snapshot}

Dynomax BuiltIn Apply Form Values
    ${fields}=    Get Dynomax Context Value    fields
    ${root_selector}=    Get Dynomax Context Value    rootSelector    ${EMPTY}
    ${payload_json}=    Evaluate    json.dumps({'fields': $fields, 'rootSelector': $root_selector}, ensure_ascii=True, separators=(',', ':'))    modules=json
    ${result}=    Evaluate JavaScript    css=html    (root, payloadJson) => { const payload=JSON.parse(payloadJson); const definitions=payload.fields; const rootSelector=payload.rootSelector||''; const scope=rootSelector ? document.querySelector(rootSelector) : document; if(!scope) throw new Error('Form apply root not found: ' + rootSelector); const evidence={}; let applied=0; for(const [name,raw] of Object.entries(definitions)){ const descriptor=(raw && typeof raw==='object' && !Array.isArray(raw)) ? raw : {selector:name,value:raw}; const selector=String(descriptor.selector||name); const element=scope.querySelector(selector); if(!element) throw new Error("Form apply field '" + name + "' not found: " + selector); const value=Object.prototype.hasOwnProperty.call(descriptor,'value') ? descriptor.value : raw; const kind=String(descriptor.kind||'auto').toLowerCase(); let effective=kind; if(effective==='auto'){ if(element.type==='checkbox' || element.type==='radio') effective='checked'; else if(element.tagName==='SELECT') effective='select'; else effective='value'; } if(effective==='checked'){ element.checked=Boolean(value); } else if(effective==='select'){ const values=Array.isArray(value) ? value.map(String) : [String(value ?? '')]; for(const option of element.options){ option.selected=values.includes(option.value); } } else if(effective==='text'){ element.textContent=value == null ? '' : String(value); } else if(effective==='attribute'){ if(!descriptor.attribute) throw new Error("Form apply field '" + name + "' requires attribute."); if(value == null || value === false) element.removeAttribute(descriptor.attribute); else element.setAttribute(descriptor.attribute,String(value)); } else if(effective==='value'){ if(!('value' in element)) throw new Error("Form apply field '" + name + "' has no value property."); element.value=value == null ? '' : String(value); } else { throw new Error("Unsupported form apply kind '" + effective + "' for '" + name + "'."); } element.dispatchEvent(new Event('input',{bubbles:true})); element.dispatchEvent(new Event('change',{bubbles:true})); evidence[name]={selector,kind:effective}; applied++; } return {applied,results:evidence}; }    arg=${payload_json}
    ${applied}=    Evaluate    int($result['applied'])
    ${results}=    Evaluate    $result['results']
    Set Dynomax Context Value    applied    ${applied}
    Set Dynomax Context Value    results    ${results}
""";

    private const string SharedRobotResource = """
*** Keywords ***
Dynomax BuiltIn Open Page
    ${url}=    Get Dynomax Context Value    url    ${EMPTY}
    IF    $url is None or str($url).strip() == ''
        ${url}=    Set Variable    ${DYNOMAX_BASE_URL}
    END
    Go To    ${url}
    Wait For Load State    domcontentloaded
    ${current}=    Get Url
    Set Dynomax Context Value    url    ${current}

Dynomax BuiltIn Navigate
    ${url}=    Get Dynomax Context Value    url
    Should Not Be Empty    ${url}
    Go To    ${url}
    Wait For Load State    domcontentloaded
    ${current}=    Get Url
    Set Dynomax Context Value    url    ${current}

Dynomax BuiltIn Click Element
    ${selector}=    Get Dynomax Context Value    selector
    Click    ${selector}

Dynomax BuiltIn Double Click
    ${selector}=    Get Dynomax Context Value    selector
    Click With Options    ${selector}    clickCount=2

Dynomax BuiltIn Enter Text
    ${selector}=    Get Dynomax Context Value    selector
    ${text}=    Get Dynomax Context Value    text
    ${previous}=    Set Log Level    NONE
    TRY
        Fill Text    ${selector}    ${text}
    FINALLY
        Set Log Level    ${previous}
    END

Dynomax BuiltIn Enter Text V2
    ${selector}=    Get Dynomax Context Value    selector
    ${context}=    Get Dynomax Context
    ${secret_keys}=    Evaluate    set($context.get('secretKeys', []))
    ${sensitive_keys}=    Evaluate    set($context.get('sensitiveKeys', []))
    ${text_is_protected}=    Evaluate    'text' in $secret_keys or 'text' in $sensitive_keys
    IF    ${text_is_protected}
        Fill Dynomax Sensitive    ${selector}    text
        Register Dynomax Sensitive Selector    ${selector}
    ELSE
        ${text}=    Get Dynomax Context Value    text
        ${previous}=    Set Log Level    NONE
        TRY
            Fill Text    ${selector}    ${text}
        FINALLY
            Set Log Level    ${previous}
        END
    END

Dynomax BuiltIn Enter Secret Text
    ${selector}=    Get Dynomax Context Value    selector
    Fill Dynomax Secret    ${selector}    text

Dynomax BuiltIn Enter Sensitive Text V2
    ${selector}=    Get Dynomax Context Value    selector
    Fill Dynomax Sensitive    ${selector}    text
    Register Dynomax Sensitive Selector    ${selector}

Dynomax BuiltIn Clear Field
    ${selector}=    Get Dynomax Context Value    selector
    Fill Text    ${selector}    ${EMPTY}

Dynomax BuiltIn Select Dropdown Option
    ${selector}=    Get Dynomax Context Value    selector
    ${by}=    Get Dynomax Context Value    by    value
    ${value}=    Get Dynomax Context Value    value
    Select Options By    ${selector}    ${by}    ${value}

Dynomax BuiltIn Check Checkbox
    ${selector}=    Get Dynomax Context Value    selector
    Check Checkbox    ${selector}

Dynomax BuiltIn Uncheck Checkbox
    ${selector}=    Get Dynomax Context Value    selector
    Uncheck Checkbox    ${selector}

Dynomax BuiltIn Press Key
    ${selector}=    Get Dynomax Context Value    selector    ${EMPTY}
    ${key}=    Get Dynomax Context Value    key
    IF    $selector is None or str($selector).strip() == ''
        Keyboard Key    press    ${key}
    ELSE
        Click    ${selector}
        Keyboard Key    press    ${key}
    END

Dynomax BuiltIn Submit Form
    ${selector}=    Get Dynomax Context Value    selector
    Evaluate JavaScript    ${selector}    (element) => (element.tagName === 'FORM' ? element : element.closest('form')).requestSubmit()

Dynomax BuiltIn Login
    ${username_selector}=    Get Dynomax Context Value    usernameSelector
    ${password_selector}=    Get Dynomax Context Value    passwordSelector
    ${submit_selector}=    Get Dynomax Context Value    submitSelector
    Fill Dynomax Secret    ${username_selector}    username
    Fill Dynomax Secret    ${password_selector}    password
    Click    ${submit_selector}
    Wait For Load State    domcontentloaded
    ${success_selector}=    Get Dynomax Context Value    successSelector    ${EMPTY}
    IF    $success_selector is not None and str($success_selector).strip() != ''
        Wait For Elements State    ${success_selector}    visible    timeout=30s
    END

Dynomax BuiltIn Login V2
    ${username_selector}=    Get Dynomax Context Value    usernameSelector
    ${password_selector}=    Get Dynomax Context Value    passwordSelector
    ${submit_selector}=    Get Dynomax Context Value    submitSelector
    ${context}=    Get Dynomax Context
    ${secret_keys}=    Evaluate    set($context.get('secretKeys', []))
    ${username_is_secret}=    Evaluate    'username' in $secret_keys
    IF    ${username_is_secret}
        Fill Dynomax Secret    ${username_selector}    username
    ELSE
        ${username}=    Get Dynomax Context Value    username
        Fill Text    ${username_selector}    ${username}
    END
    Fill Dynomax Secret    ${password_selector}    password
    Click    ${submit_selector}
    Wait For Load State    domcontentloaded
    ${success_selector}=    Get Dynomax Context Value    successSelector    ${EMPTY}
    IF    $success_selector is not None and str($success_selector).strip() != ''
        Wait For Elements State    ${success_selector}    visible    timeout=30s
    END

Dynomax BuiltIn Logout
    ${selector}=    Get Dynomax Context Value    selector
    Click    ${selector}
    ${success_selector}=    Get Dynomax Context Value    successSelector    ${EMPTY}
    IF    $success_selector is not None and str($success_selector).strip() != ''
        Wait For Elements State    ${success_selector}    visible    timeout=30s
    END

Dynomax BuiltIn Wait Element
    ${selector}=    Get Dynomax Context Value    selector
    ${state}=    Get Dynomax Context Value    state    visible
    ${timeout}=    Get Dynomax Context Value    timeoutSeconds    30
    Wait For Elements State    ${selector}    ${state}    timeout=${timeout}s

Dynomax BuiltIn Wait Text
    ${text}=    Get Dynomax Context Value    text
    ${timeout}=    Get Dynomax Context Value    timeoutSeconds    30
    Wait For Elements State    text=${text}    visible    timeout=${timeout}s

Dynomax BuiltIn Wait URL
    ${expected}=    Get Dynomax Context Value    url
    ${timeout}=    Get Dynomax Context Value    timeoutSeconds    30
    Wait Until Keyword Succeeds    ${timeout}s    250ms    Dynomax BuiltIn URL Should Equal    ${expected}

Dynomax BuiltIn URL Should Equal
    [Arguments]    ${expected}
    ${actual}=    Get Url
    Should Be Equal As Strings    ${actual}    ${expected}

Dynomax BuiltIn Wait Page Load
    ${state}=    Get Dynomax Context Value    state    domcontentloaded
    Wait For Load State    ${state}

Dynomax BuiltIn Get Element Text
    ${selector}=    Get Dynomax Context Value    selector
    ${value}=    Get Text    ${selector}
    Set Dynomax Context Value    text    ${value}

Dynomax BuiltIn Get Element Attribute
    ${selector}=    Get Dynomax Context Value    selector
    ${attribute}=    Get Dynomax Context Value    attribute
    ${value}=    Get Attribute    ${selector}    ${attribute}
    Set Dynomax Context Value    value    ${value}

Dynomax BuiltIn Get Input Value
    ${selector}=    Get Dynomax Context Value    selector
    ${value}=    Get Property    ${selector}    value
    Set Dynomax Context Value    value    ${value}

Dynomax BuiltIn Element Exists
    ${selector}=    Get Dynomax Context Value    selector
    ${count}=    Get Element Count    ${selector}
    ${exists}=    Evaluate    int($count) > 0
    Set Dynomax Context Value    exists    ${exists}

Dynomax BuiltIn Element Visible
    ${selector}=    Get Dynomax Context Value    selector
    ${visible}=    Run Keyword And Return Status    Wait For Elements State    ${selector}    visible    timeout=100ms
    Set Dynomax Context Value    visible    ${visible}

Dynomax BuiltIn Element Visible V2
    ${selector}=    Get Dynomax Context Value    selector
    ${timeout}=    Get Dynomax Context Value    timeoutSeconds    ${1}
    ${deadline}=    Evaluate    time.monotonic() + max(0, int($timeout))    modules=time
    ${visible}=    Set Variable    ${False}
    TRY
        WHILE    ${True}
            @{elements}=    Get Elements    ${selector}
            FOR    ${element}    IN    @{elements}
                ${states}=    Get Element States    ${element}
                ${visible}=    Evaluate    'visible' in $states
                IF    ${visible}
                    BREAK
                END
            END
            IF    ${visible}
                BREAK
            END
            ${remaining}=    Evaluate    $deadline - time.monotonic()    modules=time
            IF    ${remaining} <= 0
                BREAK
            END
            ${delay}=    Evaluate    min(0.1, max(0.0, $remaining))
            Sleep    ${delay}s
        END
    EXCEPT
        Fail    DMX-PROBE-BROWSER-ERROR: The visibility probe could not inspect the configured selector. Confirm the Browser session is active and the selector is valid, then retry.
    END
    Set Dynomax Context Value    visible    ${visible}

Dynomax BuiltIn Element Visible V3
    ${selector}=    Get Dynomax Context Value    selector
    ${timeout}=    Get Dynomax Context Value    timeoutSeconds    ${1}
    ${timeout}=    Evaluate    max(0.0, float($timeout))
    ${deadline}=    Evaluate    time.monotonic() + $timeout    modules=time
    ${visible}=    Set Variable    ${False}
    TRY
        WHILE    ${True}
            ${count}=    Get Element Count    ${selector}
            IF    ${count} > 0
                @{elements}=    Get Elements    ${selector}
                FOR    ${element}    IN    @{elements}
                    ${states}=    Get Element States    ${element}
                    ${visible}=    Evaluate    'visible' in $states
                    IF    ${visible}
                        BREAK
                    END
                END
            END
            IF    ${visible}
                BREAK
            END
            ${remaining}=    Evaluate    $deadline - time.monotonic()    modules=time
            IF    ${remaining} <= 0
                BREAK
            END
            ${delay}=    Evaluate    min(0.1, max(0.0, $remaining))
            Sleep    ${delay}s
        END
    EXCEPT
        Fail    DMX-PROBE-BROWSER-ERROR: The visibility probe could not inspect the configured selector. Confirm the Browser session is active and the selector is valid, then retry.
    END
    Set Dynomax Context Value    visible    ${visible}

Dynomax BuiltIn Get Current URL
    ${url}=    Get Url
    Set Dynomax Context Value    url    ${url}

Dynomax BuiltIn Get Page Title
    ${title}=    Get Title
    Set Dynomax Context Value    title    ${title}

Dynomax BuiltIn Set Browser Viewport
    ${width_raw}=    Get Dynomax Context Value    width
    ${height_raw}=    Get Dynomax Context Value    height
    TRY
        ${width}=    Evaluate    int(str($width_raw).strip())
        ${height}=    Evaluate    int(str($height_raw).strip())
    EXCEPT
        Fail    DMX-VIEWPORT-DIMENSION-INVALID: width and height must be integer CSS-pixel dimensions.
    END
    IF    ${width} < 1 or ${width} > 10000 or ${height} < 1 or ${height} > 10000
        Fail    DMX-VIEWPORT-DIMENSION-OUT-OF-RANGE: width and height must each be between 1 and 10000 CSS pixels.
    END
    Set Viewport Size    ${width}    ${height}
    Wait For Condition    Viewport Size    width    ==    ${width}    timeout=5s
    Wait For Condition    Viewport Size    height    ==    ${height}    timeout=5s
    ${actual_width}=    Get Viewport Size    width
    ${actual_height}=    Get Viewport Size    height
    ${page_dimensions}=    Evaluate JavaScript    css=html    (root)=>({width:window.innerWidth,height:window.innerHeight})
    ${page_width}=    Evaluate    int($page_dimensions['width'])
    ${page_height}=    Evaluate    int($page_dimensions['height'])
    IF    ${actual_width} != ${width} or ${actual_height} != ${height} or ${page_width} != ${width} or ${page_height} != ${height}
        Fail    DMX-VIEWPORT-APPLY-MISMATCH: Requested ${width}x${height}, Browser reported ${actual_width}x${actual_height}, and page reported ${page_width}x${page_height}.
    END
    Set Dynomax Context Value    requestedWidth    ${width}
    Set Dynomax Context Value    requestedHeight    ${height}
    Set Dynomax Context Value    actualWidth    ${actual_width}
    Set Dynomax Context Value    actualHeight    ${actual_height}
    Set Dynomax Context Value    applied    ${True}

Dynomax BuiltIn Emulate Mobile Device
    ${profile_raw}=    Get Dynomax Context Value    deviceProfile
    ${orientation_raw}=    Get Dynomax Context Value    orientation    portrait
    ${profile}=    Evaluate    str($profile_raw).strip()
    ${orientation}=    Evaluate    str($orientation_raw).strip().lower()
    IF    not $profile
        Fail    DMX-MOBILE-DEVICE-PROFILE-INVALID: deviceProfile is required.
    END
    IF    $profile.lower().endswith(' landscape')
        Fail    DMX-MOBILE-DEVICE-PROFILE-INVALID: Supply the base Playwright device name and orientation separately.
    END
    IF    '${orientation}' != 'portrait' and '${orientation}' != 'landscape'
        Fail    DMX-MOBILE-ORIENTATION-INVALID: orientation must be portrait or landscape.
    END
    ${descriptor_name}=    Evaluate    $profile if $orientation == 'portrait' else $profile + ' landscape'
    TRY
        ${device}=    Get Device    ${descriptor_name}
    EXCEPT
        Fail    DMX-MOBILE-DEVICE-UNSUPPORTED: The requested Playwright device/orientation descriptor is not available in this runtime.
    END
    ${expected_mobile}=    Evaluate    bool($device.get('isMobile', False))
    ${expected_touch}=    Evaluate    bool($device.get('hasTouch', False))
    IF    not ${expected_mobile} or not ${expected_touch}
        Fail    DMX-MOBILE-DEVICE-NOT-MOBILE: The selected descriptor must have isMobile=true and hasTouch=true.
    END
    ${url}=    Get Url
    @{old_context_ids}=    Get Context Ids    context=ACTIVE    browser=ACTIVE
    ${old_context}=    Set Variable    ${old_context_ids}[0]
    ${old_storage}=    Evaluate JavaScript    css=html    (root)=>Object.fromEntries(Array.from({length:sessionStorage.length},(_,i)=>{const k=sessionStorage.key(i);return [k,sessionStorage.getItem(k)]}))
    ${previous_log_level}=    Set Log Level    NONE
    ${state_file}=    Save Storage State
    TRY
        ${new_context}=    New Context    &{device}    storageState=${state_file}
        New Page    ${url}
        ${restored_count}=    Evaluate JavaScript    css=html    (root,values)=>{for(const [k,v] of Object.entries(values||{})){sessionStorage.setItem(k,v)}return Object.keys(values||{}).length}    ${old_storage}
        IF    ${restored_count} > 0
            Reload
        END
        Wait For Load State    domcontentloaded    timeout=10s
    FINALLY
        Evaluate    os.remove($state_file) if os.path.exists($state_file) else None    modules=os
        Set Log Level    ${previous_log_level}
    END
    Switch Context    ${new_context}
    Close Context    ${old_context}
    Switch Context    ${new_context}
    ${metrics}=    Evaluate JavaScript    css=html    (root)=>({viewportWidth:innerWidth,viewportHeight:innerHeight,screenWidth:screen.width,screenHeight:screen.height,deviceScaleFactor:devicePixelRatio,coarsePointer:matchMedia('(pointer: coarse)').matches,maxTouchPoints:navigator.maxTouchPoints,userAgent:navigator.userAgent})
    ${expected_viewport}=    Evaluate    $device.get('viewport') or {}
    ${expected_screen}=    Evaluate    $device.get('screen') or {}
    ${expected_dpr}=    Evaluate    float($device.get('deviceScaleFactor',1))
    ${expected_ua}=    Evaluate    str($device.get('userAgent',''))
    ${actual_width}=    Evaluate    int($metrics['viewportWidth'])
    ${actual_height}=    Evaluate    int($metrics['viewportHeight'])
    ${actual_screen_width}=    Evaluate    int($metrics['screenWidth'])
    ${actual_screen_height}=    Evaluate    int($metrics['screenHeight'])
    ${actual_dpr}=    Evaluate    float($metrics['deviceScaleFactor'])
    ${coarse}=    Evaluate    bool($metrics['coarsePointer'])
    ${touch_points}=    Evaluate    int($metrics['maxTouchPoints'])
    ${actual_ua}=    Evaluate    str($metrics['userAgent'])
    ${expected_width}=    Evaluate    int($expected_viewport.get('width',0))
    ${expected_height}=    Evaluate    int($expected_viewport.get('height',0))
    ${expected_screen_width}=    Evaluate    int($expected_screen.get('width',0))
    ${expected_screen_height}=    Evaluate    int($expected_screen.get('height',0))
    IF    ${actual_width} != ${expected_width} or ${actual_height} != ${expected_height}
        Fail    DMX-MOBILE-VIEWPORT-MISMATCH: The viewport does not match the selected Playwright device descriptor.
    END
    IF    ${expected_screen_width} > 0 and (${actual_screen_width} != ${expected_screen_width} or ${actual_screen_height} != ${expected_screen_height})
        Fail    DMX-MOBILE-SCREEN-MISMATCH: window.screen does not match the selected Playwright device descriptor.
    END
    ${dpr_matches}=    Evaluate    abs($actual_dpr-$expected_dpr) < 0.01
    IF    not ${dpr_matches}
        Fail    DMX-MOBILE-DPR-MISMATCH: devicePixelRatio does not match the selected Playwright device descriptor.
    END
    IF    ${touch_points} < 1 or not ${coarse}
        Fail    DMX-MOBILE-TOUCH-MISMATCH: The page does not expose touch/coarse-pointer mobile semantics.
    END
    IF    $expected_ua and $actual_ua != $expected_ua
        Fail    DMX-MOBILE-UA-MISMATCH: navigator.userAgent does not match the selected Playwright device descriptor.
    END
    ${orientation_matches}=    Evaluate    ($orientation == 'portrait' and $actual_height >= $actual_width) or ($orientation == 'landscape' and $actual_width >= $actual_height)
    IF    not ${orientation_matches}
        Fail    DMX-MOBILE-ORIENTATION-MISMATCH: The rendered viewport orientation does not match the request.
    END
    Set Dynomax Context Value    deviceProfile    ${profile}
    Set Dynomax Context Value    orientation    ${orientation}
    Set Dynomax Context Value    contextId    ${new_context}
    Set Dynomax Context Value    url    ${url}
    Set Dynomax Context Value    viewportWidth    ${actual_width}
    Set Dynomax Context Value    viewportHeight    ${actual_height}
    Set Dynomax Context Value    screenWidth    ${actual_screen_width}
    Set Dynomax Context Value    screenHeight    ${actual_screen_height}
    Set Dynomax Context Value    deviceScaleFactor    ${actual_dpr}
    Set Dynomax Context Value    isMobile    ${expected_mobile}
    Set Dynomax Context Value    hasTouch    ${expected_touch}
    Set Dynomax Context Value    coarsePointer    ${coarse}
    Set Dynomax Context Value    userAgent    ${actual_ua}
    Set Dynomax Context Value    sessionRestored    ${True}
    Set Dynomax Context Value    applied    ${True}
Dynomax BuiltIn Inspect Mobile Layout
    ${max_raw}=    Get Dynomax Context Value    maxFindings    ${100}
    TRY
        ${max_findings}=    Evaluate    int(str($max_raw).strip())
    EXCEPT
        Fail    DMX-MOBILE-INSPECT-LIMIT-INVALID: maxFindings must be an integer.
    END
    IF    ${max_findings} < 1 or ${max_findings} > 200
        Fail    DMX-MOBILE-INSPECT-LIMIT-OUT-OF-RANGE: maxFindings must be between 1 and 200.
    END
    ${result}=    Evaluate JavaScript    css=html    (root,limit)=>{const vw=innerWidth,vh=innerHeight;const visible=e=>{const s=getComputedStyle(e),r=e.getBoundingClientRect();return s.display!=='none'&&s.visibility!=='hidden'&&Number(s.opacity)!==0&&r.width>0&&r.height>0};const desc=e=>({tag:e.tagName.toLowerCase(),id:(e.id||'').slice(0,120),classes:String(e.className||'').split(/\s+/).filter(Boolean).slice(0,6),role:(e.getAttribute('role')||'').slice(0,80)});const rect=e=>{const r=e.getBoundingClientRect();return{x:+r.x.toFixed(2),y:+r.y.toFixed(2),left:+r.left.toFixed(2),top:+r.top.toFixed(2),right:+r.right.toFixed(2),bottom:+r.bottom.toFixed(2),width:+r.width.toFixed(2),height:+r.height.toFixed(2)}};const all=[...document.querySelectorAll('*')].slice(0,5000),overflow=[],fixedSticky=[];for(const e of all){if(!visible(e))continue;const r=e.getBoundingClientRect();if((r.right>vw+1||r.left<-1||r.width>vw+1)&&overflow.length<limit)overflow.push({...desc(e),rect:rect(e)});const p=getComputedStyle(e).position;if((p==='fixed'||p==='sticky')&&fixedSticky.length<limit)fixedSticky.push({...desc(e),position:p,rect:rect(e),zIndex:getComputedStyle(e).zIndex})}const modals=[...document.querySelectorAll('[role="dialog"],dialog,.modal,.modal-dialog,.modal-content')].filter(visible).slice(0,limit).map(e=>{const r=e.getBoundingClientRect(),h=e.querySelector('.modal-header,[data-modal-header]'),f=e.querySelector('.modal-footer,[data-modal-footer]'),hr=h&&visible(h)?h.getBoundingClientRect():null,fr=f&&visible(f)?f.getBoundingClientRect():null;return{...desc(e),rect:rect(e),scrollTop:e.scrollTop,scrollHeight:e.scrollHeight,clientHeight:e.clientHeight,canScroll:e.scrollHeight>e.clientHeight+1,headerInside:!hr||(hr.top>=r.top-1&&hr.bottom<=r.bottom+1),footerInside:!fr||(fr.top>=r.top-1&&fr.bottom<=r.bottom+1)}});const controls=[];for(const e of document.querySelectorAll('button,a[href],input,select,textarea,[role="button"],[tabindex]')){if(controls.length>=limit)break;if(!visible(e))continue;const r=e.getBoundingClientRect(),cx=Math.min(vw-1,Math.max(0,r.left+r.width/2)),cy=Math.min(vh-1,Math.max(0,r.top+r.height/2)),inView=r.right>0&&r.left<vw&&r.bottom>0&&r.top<vh,top=document.elementFromPoint(cx,cy),occluded=!!(inView&&top&&top!==e&&!e.contains(top)&&!top.contains(e)),disabled=!!(e.disabled||e.getAttribute('aria-disabled')==='true');if(!inView||occluded||disabled)controls.push({...desc(e),rect:rect(e),inViewport:inView,occluded,disabled,reachable:inView&&!occluded&&!disabled})}const de=document.documentElement;return{device:{viewportWidth:vw,viewportHeight:vh,screenWidth:screen.width,screenHeight:screen.height,deviceScaleFactor:devicePixelRatio,coarsePointer:matchMedia('(pointer: coarse)').matches,hoverNone:matchMedia('(hover: none)').matches,maxTouchPoints:navigator.maxTouchPoints,orientation:(screen.orientation&&screen.orientation.type)||((vw>vh)?'landscape':'portrait'),userAgent:navigator.userAgent},page:{scrollWidth:de.scrollWidth,scrollHeight:de.scrollHeight,horizontalOverflow:de.scrollWidth>vw+1,scannedElements:all.length,scanCap:5000},overflow,overflowCount:overflow.length,fixedSticky,fixedStickyCount:fixedSticky.length,modals,unreachableControls:controls,unreachableControlCount:controls.length,truncated:{overflow:overflow.length>=limit,fixedSticky:fixedSticky.length>=limit,modals:modals.length>=limit,controls:controls.length>=limit}}}    ${max_findings}
    Set Dynomax Context Value    result    ${result}
Dynomax BuiltIn Emulate Browser Media
    ${reduced_motion_raw}=    Get Dynomax Context Value    reducedMotion
    TRY
        ${requested}=    Evaluate    str($reduced_motion_raw).strip().lower().replace('_', '-')
    EXCEPT
        Fail    DMX-MEDIA-REDUCED-MOTION-INVALID: reducedMotion must be reduce or no-preference.
    END
    IF    '${requested}' != 'reduce' and '${requested}' != 'no-preference'
        Fail    DMX-MEDIA-REDUCED-MOTION-INVALID: reducedMotion must be reduce or no-preference.
    END
    ${browser_value}=    Evaluate    'no_preference' if $requested == 'no-preference' else 'reduce'
    Emulate Media    reducedMotion=${browser_value}
    ${media_state}=    Evaluate JavaScript    css=html    (root)=>({reduce:window.matchMedia('(prefers-reduced-motion: reduce)').matches,noPreference:window.matchMedia('(prefers-reduced-motion: no-preference)').matches})
    ${reduce_matches}=    Evaluate    bool($media_state['reduce'])
    ${no_preference_matches}=    Evaluate    bool($media_state['noPreference'])
    IF    ${reduce_matches} and not ${no_preference_matches}
        ${actual}=    Set Variable    reduce
    ELSE IF    ${no_preference_matches} and not ${reduce_matches}
        ${actual}=    Set Variable    no-preference
    ELSE
        Fail    DMX-MEDIA-APPLY-MISMATCH: The page reported an ambiguous prefers-reduced-motion state after emulation.
    END
    ${matches}=    Evaluate    $actual == $requested
    IF    not ${matches}
        Fail    DMX-MEDIA-APPLY-MISMATCH: Requested ${requested} but the page reported ${actual}.
    END
    Set Dynomax Context Value    requestedReducedMotion    ${requested}
    Set Dynomax Context Value    actualReducedMotion    ${actual}
    Set Dynomax Context Value    reducedMotionMatches    ${matches}
    Set Dynomax Context Value    applied    ${True}

Dynomax BuiltIn Take Screenshot
    ${full}=    Get Dynomax Context Value    fullPage    ${False}
    ${relative}=    Set Variable    screenshots${/}builtin-${DYNOMAX_ACTION_ID}-${DYNOMAX_STEP_ID}.png
    ${path}=    Set Variable    ${DYNOMAX_RUN_DIR}${/}${relative}
    Take Screenshot    ${path}    fullPage=${full}
    Set Dynomax Context Value    fileReference    ${relative}

Dynomax BuiltIn Take Screenshot V2
    ${full}=    Get Dynomax Context Value    fullPage    ${False}
    ${configured}=    Get Dynomax Context Value    sensitiveSelectors    ${EMPTY}
    ${selectors}=    Evaluate    list($configured) if isinstance($configured, list) else ([] if $configured in (None, '') else [str($configured)])
    ${relative}=    Set Variable    screenshots${/}builtin-${DYNOMAX_ACTION_ID}-${DYNOMAX_STEP_ID}.png
    ${path}=    Set Variable    ${DYNOMAX_RUN_DIR}${/}${relative}
    ${mask_path}=    Set Variable    ${path}.mask.json
    ${previous_log_level}=    Set Log Level    NONE
    ${explicit_masked}=    Set Variable    ${0}
    TRY
        ${mask_script}=    Get Discovery Script    mask    ${DYNOMAX_CONTEXT_PATH}
        ${mask_result}=    Evaluate JavaScript    css=html    ${mask_script}
        ${mask_applied}=    Evaluate    bool($mask_result.get('applied')) and bool($mask_result.get('formControlsMasked'))
        Should Be True    ${mask_applied}    DMX-EVIDENCE-MASK-FAILED: Dynomax could not establish the mandatory secret-safe screenshot mask. Retry after confirming the browser session is healthy.
        FOR    ${selector}    IN    @{selectors}
            ${mask_status}    ${masked_count}=    Run Keyword And Ignore Error    Evaluate JavaScript    css=html    (root, selector)=>{window.__dynomaxPortableEvidenceMask=window.__dynomaxPortableEvidenceMask||[];const elements=[...document.querySelectorAll(selector)];for(const element of elements){if(!window.__dynomaxPortableEvidenceMask.some(item=>item[0]===element)){window.__dynomaxPortableEvidenceMask.push([element,element.getAttribute('style')]);}element.style.setProperty('visibility','hidden','important');}return elements.length;}    ${selector}
            IF    '${mask_status}' != 'PASS'
                Fail    DMX-EVIDENCE-SENSITIVE-SELECTOR-INVALID: A configured sensitive selector could not be masked safely. Correct or remove the selector before capturing portable evidence.
            END
            ${explicit_masked}=    Evaluate    $explicit_masked + int($masked_count)
        END
        Take Screenshot    ${path}    fullPage=${full}
        File Should Exist    ${path}
        ${length}=    Get File Size    ${path}
        Should Be True    ${length} > 0    DMX-EVIDENCE-SCREENSHOT-EMPTY: The screenshot Action completed without a retained image.
        ${mask_report}=    Evaluate    json.dumps({'schemaVersion':1,'safeForPortableEvidence':True,'maskApplied':True,'formControlsMasked':True,'exactRuntimeSecretsConsidered':int($mask_result.get('exactRuntimeSecretsConsidered',0)),'textNodesMasked':int($mask_result.get('textNodesMasked',0)),'configuredSensitiveSelectorsMasked':int($explicit_masked),'fullPage':bool($full)}, ensure_ascii=False, indent=2)    modules=json
        Create File    ${mask_path}    ${mask_report}
    FINALLY
        ${portable_unmask}=    Set Variable    (root)=>{const saved=window.__dynomaxPortableEvidenceMask||[];for(const item of saved){try{if(item[1]===null)item[0].removeAttribute('style');else item[0].setAttribute('style',item[1]);}catch{}}window.__dynomaxPortableEvidenceMask=[];return true;}
        Run Keyword And Ignore Error    Evaluate JavaScript    css=html    ${portable_unmask}
        ${unmask_script}=    Get Discovery Script    unmask    ${DYNOMAX_CONTEXT_PATH}
        Run Keyword And Ignore Error    Evaluate JavaScript    css=html    ${unmask_script}
        Set Log Level    ${previous_log_level}
    END
    Set Dynomax Context Value    fileReference    ${relative}

Dynomax BuiltIn Take Screenshot V3
    ${full}=    Get Dynomax Context Value    fullPage    ${False}
    ${configured}=    Get Dynomax Context Value    sensitiveSelectors    ${EMPTY}
    ${selectors}=    Evaluate    list($configured) if isinstance($configured, list) else ([] if $configured in (None, '') else [str($configured)])
    ${relative}=    Set Variable    screenshots${/}builtin-${DYNOMAX_ACTION_ID}-${DYNOMAX_STEP_ID}.png
    ${path}=    Set Variable    ${DYNOMAX_RUN_DIR}${/}${relative}
    ${mask_path}=    Set Variable    ${path}.mask.json
    ${previous_log_level}=    Set Log Level    NONE
    ${explicit_masked}=    Set Variable    ${0}
    ${selector_index}=    Set Variable    ${0}
    TRY
        ${mask_script}=    Get Discovery Script    mask    ${DYNOMAX_CONTEXT_PATH}
        ${mask_result}=    Evaluate JavaScript    css=html    ${mask_script}
        ${mask_applied}=    Evaluate    bool($mask_result.get('applied')) and bool($mask_result.get('formControlsMasked'))
        Should Be True    ${mask_applied}    DMX-EVIDENCE-MASK-FAILED: Dynomax could not establish the mandatory secret-safe screenshot mask. Retry after confirming the browser session is healthy.
        FOR    ${selector}    IN    @{selectors}
            TRY
                ${match_count}=    Get Element Count    ${selector}
            EXCEPT
                Fail    DMX-EVIDENCE-SENSITIVE-SELECTOR-INVALID: sensitiveSelectors[${selector_index}] could not be parsed or inspected safely as Browser selector data. Correct or remove that selector and confirm the Browser session is active before capturing portable evidence.
            END
            IF    ${match_count} > 0
                TRY
                    @{elements}=    Get Elements    ${selector}
                EXCEPT
                    Fail    DMX-EVIDENCE-SENSITIVE-SELECTOR-MASK-FAILED: sensitiveSelectors[${selector_index}] matched page content but Dynomax could not acquire every matching element for safe masking. Retry after the page is stable.
                END
                FOR    ${element}    IN    @{elements}
                    TRY
                        Evaluate JavaScript    ${element}    (element)=>{window.__dynomaxPortableEvidenceMask=window.__dynomaxPortableEvidenceMask||[];if(!window.__dynomaxPortableEvidenceMask.some(item=>item[0]===element)){window.__dynomaxPortableEvidenceMask.push([element,element.getAttribute('style')]);}element.style.setProperty('visibility','hidden','important');return true;}
                    EXCEPT
                        Fail    DMX-EVIDENCE-SENSITIVE-SELECTOR-MASK-FAILED: sensitiveSelectors[${selector_index}] matched page content but Dynomax could not apply the temporary evidence mask safely. Retry after the page is stable.
                    END
                    ${explicit_masked}=    Evaluate    int($explicit_masked) + 1
                END
            END
            ${selector_index}=    Evaluate    int($selector_index) + 1
        END
        Take Screenshot    ${path}    fullPage=${full}
        File Should Exist    ${path}
        ${length}=    Get File Size    ${path}
        Should Be True    ${length} > 0    DMX-EVIDENCE-SCREENSHOT-EMPTY: The screenshot Action completed without a retained image.
        ${mask_report}=    Evaluate    json.dumps({'schemaVersion':1,'safeForPortableEvidence':True,'maskApplied':True,'formControlsMasked':True,'exactRuntimeSecretsConsidered':int($mask_result.get('exactRuntimeSecretsConsidered',0)),'textNodesMasked':int($mask_result.get('textNodesMasked',0)),'configuredSensitiveSelectorsMasked':int($explicit_masked),'configuredSensitiveSelectorCount':len($selectors),'fullPage':bool($full)}, ensure_ascii=False, indent=2)    modules=json
        Create File    ${mask_path}    ${mask_report}
    FINALLY
        ${portable_unmask}=    Set Variable    (root)=>{const saved=window.__dynomaxPortableEvidenceMask||[];for(const item of saved){try{if(item[1]===null)item[0].removeAttribute('style');else item[0].setAttribute('style',item[1]);}catch{}}window.__dynomaxPortableEvidenceMask=[];return true;}
        Run Keyword And Ignore Error    Evaluate JavaScript    css=html    ${portable_unmask}
        ${unmask_script}=    Get Discovery Script    unmask    ${DYNOMAX_CONTEXT_PATH}
        Run Keyword And Ignore Error    Evaluate JavaScript    css=html    ${unmask_script}
        Set Log Level    ${previous_log_level}
    END
    Set Dynomax Context Value    fileReference    ${relative}

Dynomax BuiltIn Take Screenshot V4
    ${full}=    Get Dynomax Context Value    fullPage    ${False}
    ${configured}=    Get Dynomax Context Value    sensitiveSelectors    ${EMPTY}
    ${runtime_sensitive}=    Get Dynomax Context Value    __dynomaxRuntimeSensitiveSelectors    ${EMPTY}
    ${selectors}=    Evaluate    list(dict.fromkeys((list($configured) if isinstance($configured, list) else ([] if $configured in (None, '') else [str($configured)])) + (list($runtime_sensitive) if isinstance($runtime_sensitive, list) else ([] if $runtime_sensitive in (None, '') else [str($runtime_sensitive)]))))
    ${relative}=    Set Variable    screenshots${/}builtin-${DYNOMAX_ACTION_ID}-${DYNOMAX_STEP_ID}.png
    ${path}=    Set Variable    ${DYNOMAX_RUN_DIR}${/}${relative}
    ${mask_path}=    Set Variable    ${path}.mask.json
    ${previous_log_level}=    Set Log Level    NONE
    ${explicit_masked}=    Set Variable    ${0}
    ${selector_index}=    Set Variable    ${0}
    TRY
        ${mask_script}=    Get Discovery Script    mask    ${DYNOMAX_CONTEXT_PATH}
        ${mask_result}=    Evaluate JavaScript    css=html    ${mask_script}
        ${mask_applied}=    Evaluate    bool($mask_result.get('applied')) and bool($mask_result.get('formControlsMasked'))
        Should Be True    ${mask_applied}    DMX-EVIDENCE-MASK-FAILED: Dynomax could not establish the mandatory secret-safe screenshot mask. Retry after confirming the browser session is healthy.
        FOR    ${selector}    IN    @{selectors}
            TRY
                ${match_count}=    Get Element Count    ${selector}
            EXCEPT
                Fail    DMX-EVIDENCE-SENSITIVE-SELECTOR-INVALID: sensitiveSelectors[${selector_index}] could not be parsed or inspected safely as Browser selector data. Correct or remove that selector and confirm the Browser session is active before capturing portable evidence.
            END
            IF    ${match_count} > 0
                TRY
                    @{elements}=    Get Elements    ${selector}
                EXCEPT
                    Fail    DMX-EVIDENCE-SENSITIVE-SELECTOR-MASK-FAILED: sensitiveSelectors[${selector_index}] matched page content but Dynomax could not acquire every matching element for safe masking. Retry after the page is stable.
                END
                FOR    ${element}    IN    @{elements}
                    TRY
                        Evaluate JavaScript    ${element}    (element)=>{window.__dynomaxPortableEvidenceMask=window.__dynomaxPortableEvidenceMask||[];if(!window.__dynomaxPortableEvidenceMask.some(item=>item[0]===element)){window.__dynomaxPortableEvidenceMask.push([element,element.getAttribute('style')]);}element.style.setProperty('visibility','hidden','important');return true;}
                    EXCEPT
                        Fail    DMX-EVIDENCE-SENSITIVE-SELECTOR-MASK-FAILED: sensitiveSelectors[${selector_index}] matched page content but Dynomax could not apply the temporary evidence mask safely. Retry after the page is stable.
                    END
                    ${explicit_masked}=    Evaluate    int($explicit_masked) + 1
                END
            END
            ${selector_index}=    Evaluate    int($selector_index) + 1
        END
        Take Screenshot    ${path}    fullPage=${full}
        File Should Exist    ${path}
        ${length}=    Get File Size    ${path}
        Should Be True    ${length} > 0    DMX-EVIDENCE-SCREENSHOT-EMPTY: The screenshot Action completed without a retained image.
        ${mask_report}=    Evaluate    json.dumps({'schemaVersion':1,'safeForPortableEvidence':True,'maskApplied':True,'formControlsMasked':True,'exactRuntimeSecretsConsidered':int($mask_result.get('exactRuntimeSecretsConsidered',0)),'textNodesMasked':int($mask_result.get('textNodesMasked',0)),'configuredSensitiveSelectorsMasked':int($explicit_masked),'configuredSensitiveSelectorCount':len($selectors),'fullPage':bool($full)}, ensure_ascii=False, indent=2)    modules=json
        Create File    ${mask_path}    ${mask_report}
    FINALLY
        ${portable_unmask}=    Set Variable    (root)=>{const saved=window.__dynomaxPortableEvidenceMask||[];for(const item of saved){try{if(item[1]===null)item[0].removeAttribute('style');else item[0].setAttribute('style',item[1]);}catch{}}window.__dynomaxPortableEvidenceMask=[];return true;}
        Run Keyword And Ignore Error    Evaluate JavaScript    css=html    ${portable_unmask}
        ${unmask_script}=    Get Discovery Script    unmask    ${DYNOMAX_CONTEXT_PATH}
        Run Keyword And Ignore Error    Evaluate JavaScript    css=html    ${unmask_script}
        Set Log Level    ${previous_log_level}
    END
    Set Dynomax Context Value    fileReference    ${relative}

Dynomax BuiltIn Accept Dialog
    Handle Future Dialogs    action=accept

Dynomax BuiltIn Accept Dialog V2
    ${previous}=    Get Variable Value    \${DYNOMAX_DIALOG_PROMISE}    ${None}
    IF    $previous is not None
        Wait For    ${previous}
    END
    ${promise}=    Promise To    Wait For Alert    action=accept
    Set Suite Variable    \${DYNOMAX_DIALOG_PROMISE}    ${promise}

Dynomax BuiltIn Dismiss Dialog
    Handle Future Dialogs    action=dismiss

Dynomax BuiltIn Dismiss Dialog V2
    ${previous}=    Get Variable Value    \${DYNOMAX_DIALOG_PROMISE}    ${None}
    IF    $previous is not None
        Wait For    ${previous}
    END
    ${promise}=    Promise To    Wait For Alert    action=dismiss
    Set Suite Variable    \${DYNOMAX_DIALOG_PROMISE}    ${promise}

Dynomax BuiltIn Switch Window
    ${page}=    Get Dynomax Context Value    page
    ${selected}=    Switch Page    ${page}
    Set Dynomax Context Value    page    ${selected}

Dynomax BuiltIn Close Window
    Close Page

Dynomax BuiltIn Execute JavaScript
    ${script}=    Get Dynomax Context Value    script
    ${result}=    Evaluate JavaScript    css=html    ${script}
    Set Dynomax Context Value    result    ${result}

Dynomax BuiltIn Snapshot Form Fields
    ${fields}=    Get Dynomax Context Value    fields
    ${root_selector}=    Get Dynomax Context Value    rootSelector    ${EMPTY}
    ${fields_json}=    Evaluate    json.dumps($fields, ensure_ascii=True, separators=(',', ':'))    modules=json
    ${snapshot}=    Evaluate JavaScript    css=html    (root, fieldsJson, rootSelector) => { const definitions=JSON.parse(fieldsJson); const scope=rootSelector ? document.querySelector(rootSelector) : document; if(!scope) throw new Error('Form snapshot root not found: ' + rootSelector); const result={}; for(const [name,raw] of Object.entries(definitions)){ const descriptor=typeof raw==='string' ? {selector:raw} : raw; if(!descriptor || typeof descriptor.selector!=='string' || !descriptor.selector.trim()) throw new Error("Form snapshot field '" + name + "' requires a selector."); const element=scope.querySelector(descriptor.selector); if(!element) throw new Error("Form snapshot field '" + name + "' not found: " + descriptor.selector); const kind=String(descriptor.kind||'auto').toLowerCase(); let value; if(kind==='checked' || (kind==='auto' && (element.type==='checkbox' || element.type==='radio'))){ value=Boolean(element.checked); } else if(kind==='selectedvalues' || (kind==='auto' && element.tagName==='SELECT' && element.multiple)){ value=[...element.selectedOptions].map(option=>option.value); } else if(kind==='text'){ value=element.textContent ?? ''; } else if(kind==='attribute'){ if(!descriptor.attribute) throw new Error("Form snapshot field '" + name + "' requires attribute."); value=element.getAttribute(descriptor.attribute); } else if(kind==='value' || kind==='auto'){ value='value' in element ? element.value : (element.textContent ?? ''); } else { throw new Error("Unsupported form snapshot kind '" + kind + "' for '" + name + "'."); } result[name]=value; } return result; }    ${fields_json}    ${root_selector}
    Set Dynomax Context Value    snapshot    ${snapshot}

Dynomax BuiltIn Apply Form Values
    ${fields}=    Get Dynomax Context Value    fields
    ${root_selector}=    Get Dynomax Context Value    rootSelector    ${EMPTY}
    ${fields_json}=    Evaluate    json.dumps($fields, ensure_ascii=True, separators=(',', ':'))    modules=json
    ${result}=    Evaluate JavaScript    css=html    (root, fieldsJson, rootSelector) => { const definitions=JSON.parse(fieldsJson); const scope=rootSelector ? document.querySelector(rootSelector) : document; if(!scope) throw new Error('Form apply root not found: ' + rootSelector); const evidence={}; let applied=0; for(const [name,raw] of Object.entries(definitions)){ const descriptor=(raw && typeof raw==='object' && !Array.isArray(raw)) ? raw : {selector:name,value:raw}; const selector=String(descriptor.selector||name); const element=scope.querySelector(selector); if(!element) throw new Error("Form apply field '" + name + "' not found: " + selector); const value=Object.prototype.hasOwnProperty.call(descriptor,'value') ? descriptor.value : raw; const kind=String(descriptor.kind||'auto').toLowerCase(); let effective=kind; if(effective==='auto'){ if(element.type==='checkbox' || element.type==='radio') effective='checked'; else if(element.tagName==='SELECT') effective='select'; else effective='value'; } if(effective==='checked'){ element.checked=Boolean(value); } else if(effective==='select'){ const values=Array.isArray(value) ? value.map(String) : [String(value ?? '')]; for(const option of element.options){ option.selected=values.includes(option.value); } } else if(effective==='text'){ element.textContent=value == null ? '' : String(value); } else if(effective==='attribute'){ if(!descriptor.attribute) throw new Error("Form apply field '" + name + "' requires attribute."); if(value == null || value === false) element.removeAttribute(descriptor.attribute); else element.setAttribute(descriptor.attribute,String(value)); } else if(effective==='value'){ if(!('value' in element)) throw new Error("Form apply field '" + name + "' has no value property."); element.value=value == null ? '' : String(value); } else { throw new Error("Unsupported form apply kind '" + effective + "' for '" + name + "'."); } element.dispatchEvent(new Event('input',{bubbles:true})); element.dispatchEvent(new Event('change',{bubbles:true})); evidence[name]={selector,kind:effective}; applied++; } return {applied,results:evidence}; }    ${fields_json}    ${root_selector}
    ${applied}=    Evaluate    int($result['applied'])
    ${results}=    Evaluate    $result['results']
    Set Dynomax Context Value    applied    ${applied}
    Set Dynomax Context Value    results    ${results}

Dynomax BuiltIn Verify Text Exists
    ${text}=    Get Dynomax Context Value    text
    Wait For Elements State    text=${text}    visible    timeout=5s
    Set Dynomax Context Value    verified    ${True}

Dynomax BuiltIn Verify Text Exists V2
    ${text}=    Get Dynomax Context Value    text
    ${selector}=    Catenate    SEPARATOR=    text=    ${text}
    ${deadline}=    Evaluate    time.monotonic() + 5.0    modules=time
    ${verified}=    Set Variable    ${False}
    TRY
        WHILE    ${True}
            ${count}=    Get Element Count    ${selector}
            IF    ${count} > 0
                @{elements}=    Get Elements    ${selector}
                FOR    ${element}    IN    @{elements}
                    ${states}=    Get Element States    ${element}
                    ${visible}=    Evaluate    'visible' in $states
                    IF    ${visible}
                        ${verified}=    Set Variable    ${True}
                        BREAK
                    END
                END
            END
            IF    ${verified}
                BREAK
            END
            ${remaining}=    Evaluate    $deadline - time.monotonic()    modules=time
            IF    ${remaining} <= 0
                BREAK
            END
            ${delay}=    Evaluate    min(0.1, max(0.0, $remaining))
            Sleep    ${delay}s
        END
    EXCEPT
        Fail    DMX-VALIDATION-TEXT-BROWSER-ERROR: Dynomax could not inspect visible text in the active Browser session. Confirm that the Browser session is available, then retry.
    END
    Should Be True    ${verified}    DMX-VALIDATION-TEXT-NOT-VISIBLE: Expected visible text was not found within the validation timeout.
    Set Dynomax Context Value    verified    ${True}

Dynomax BuiltIn Verify Element Exists
    ${selector}=    Get Dynomax Context Value    selector
    ${count}=    Get Element Count    ${selector}
    Should Be True    int(${count}) > 0
    Set Dynomax Context Value    verified    ${True}

Dynomax BuiltIn Verify Element Visible
    ${selector}=    Get Dynomax Context Value    selector
    Wait For Elements State    ${selector}    visible    timeout=5s
    Set Dynomax Context Value    verified    ${True}

Dynomax BuiltIn Verify Element Enabled
    ${selector}=    Get Dynomax Context Value    selector
    Wait For Elements State    ${selector}    enabled    timeout=5s
    Set Dynomax Context Value    verified    ${True}

Dynomax BuiltIn Verify URL
    ${expected}=    Get Dynomax Context Value    expectedUrl
    ${actual}=    Get Url
    Should Be Equal As Strings    ${actual}    ${expected}
    Set Dynomax Context Value    verified    ${True}

Dynomax BuiltIn Verify Page Title
    ${expected}=    Get Dynomax Context Value    expectedTitle
    ${actual}=    Get Title
    Should Be Equal As Strings    ${actual}    ${expected}
    Set Dynomax Context Value    title    ${actual}
    Set Dynomax Context Value    verified    ${True}


Dynomax BuiltIn Verify Value
    ${actual}=    Get Dynomax Context Value    actual
    ${expected}=    Get Dynomax Context Value    expected
    Should Be Equal As Strings    ${actual}    ${expected}
    Set Dynomax Context Value    verified    ${True}

Dynomax BuiltIn Verify Structured Object
    ${actual}=    Get Dynomax Context Value    actual
    ${expected}=    Get Dynomax Context Value    expected
    ${actual_json}=    Evaluate    json.dumps($actual, ensure_ascii=True, sort_keys=True, separators=(',', ':'), default=str)    modules=json
    ${expected_json}=    Evaluate    json.dumps($expected, ensure_ascii=True, sort_keys=True, separators=(',', ':'), default=str)    modules=json
    Should Be Equal As Strings    ${actual_json}    ${expected_json}    Structured values differ.
    Set Dynomax Context Value    verified    ${True}

Dynomax BuiltIn Compare Values
    ${left}=    Get Dynomax Context Value    left
    ${right}=    Get Dynomax Context Value    right
    Should Be Equal As Strings    ${left}    ${right}
    Set Dynomax Context Value    equal    ${True}

Dynomax BuiltIn Regex Match
    ${value}=    Get Dynomax Context Value    value
    ${pattern}=    Get Dynomax Context Value    pattern
    Should Match Regexp    ${value}    ${pattern}
    Set Dynomax Context Value    matched    ${True}

Dynomax BuiltIn Contains
    ${value}=    Get Dynomax Context Value    value
    ${expected}=    Get Dynomax Context Value    expected
    Should Contain    ${value}    ${expected}
    Set Dynomax Context Value    matched    ${True}

Dynomax BuiltIn Starts With
    ${value}=    Get Dynomax Context Value    value
    ${expected}=    Get Dynomax Context Value    expected
    ${matched}=    Evaluate    str($value).startswith(str($expected))
    Should Be True    ${matched}
    Set Dynomax Context Value    matched    ${True}

Dynomax BuiltIn Ends With
    ${value}=    Get Dynomax Context Value    value
    ${expected}=    Get Dynomax Context Value    expected
    ${matched}=    Evaluate    str($value).endswith(str($expected))
    Should Be True    ${matched}
    Set Dynomax Context Value    matched    ${True}

Dynomax BuiltIn Parse JSON
    ${text}=    Get Dynomax Context Value    text
    ${value}=    Dynomax Parse Json Value    ${text}
    Set Dynomax Context Value    json    ${value}

Dynomax BuiltIn Get JSON Value
    ${json}=    Get Dynomax Context Value    json
    ${path}=    Get Dynomax Context Value    path
    ${value}=    Dynomax Get Json Path    ${json}    ${path}
    Set Dynomax Context Value    value    ${value}

Dynomax BuiltIn Get JSON String
    ${json}=    Get Dynomax Context Value    json
    ${path}=    Get Dynomax Context Value    path
    ${value}=    Dynomax Get Json Path    ${json}    ${path}
    ${is_string}=    Evaluate    isinstance($value, str)
    Should Be True    ${is_string}    Selected JSON value must be a string.
    Set Dynomax Context Value    value    ${value}

""";
}
