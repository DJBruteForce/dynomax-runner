using Dynomax.Application.Testing.Actions;
using Dynomax.Application.Testing.Workflows;
using Dynomax.Domain.Testing.Actions;
using Dynomax.Domain.Testing.Workflows;

namespace Dynomax.Infrastructure.Testing.Workflows;

internal static class WorkflowGraphPatchAgentContract
{
    internal const int CandidateDocumentSchemaVersion = 1;
    internal const int DescriptorVersion = 8;
    internal const int MaximumNodesToAdd = 100;
    internal const int MaximumNodesToRemove = 100;
    internal const int MaximumNodeInputUpdates = 100;
    internal const int MaximumEdgesToRemove = 250;
    internal const int MaximumEdgesToAdd = 250;
    internal const int MaximumNodeIdLength = 100;
    internal const int MaximumGraphPatchEdgeIdInputLength = 150;
    internal const int MaximumCanonicalEdgeIdLength = 100;
    internal const int MaximumEdgeLabelLength = 150;
    internal const int MaximumEdgePriority = 10000;

    internal static readonly string[] RootProperties =
    [
        "schemaVersion", "definitionType", "operationId", "projectKey", "workflowId",
        "expectedWorkflowRevision", "expectedWorkflowSha256", "patch"
    ];

    internal static readonly string[] RequiredRootProperties =
    [
        "schemaVersion", "definitionType", "operationId", "projectKey", "workflowId",
        "expectedWorkflowRevision", "expectedWorkflowSha256", "patch"
    ];

    internal static readonly string[] PatchProperties =
    [
        "metadata", "workflowInputs", "workflowOutputs", "nodesToAdd", "nodeInputUpdates", "nodesToRemove",
        "edgesToRemove", "edgesToAdd", "cleanup"
    ];

    internal static readonly string[] RequiredPatchProperties =
    [
        "nodesToAdd", "edgesToRemove", "edgesToAdd"
    ];


    internal static readonly string[] CleanupPatchProperties =
    [
        "startNodeId", "failurePolicy", "nodesToAdd", "nodesToRemove", "edgesToRemove", "edgesToAdd"
    ];

    internal static readonly string[] CleanupRequiredPatchProperties =
    [
        "nodesToAdd", "edgesToRemove", "edgesToAdd"
    ];

    internal static readonly string[] CleanupNodeTypeValues =
    [
        WorkflowNodeTypes.Start,
        WorkflowNodeTypes.Action,
        WorkflowNodeTypes.Succeed,
        WorkflowNodeTypes.Fail
    ];

    internal static readonly IReadOnlySet<string> CleanupNodeTypes =
        CleanupNodeTypeValues.ToHashSet(StringComparer.Ordinal);

    internal static readonly string[] CleanupFailurePolicyValues = ["ContinueCleanup", "StopCleanup"];
    internal static readonly IReadOnlySet<string> CleanupFailurePolicies =
        CleanupFailurePolicyValues.ToHashSet(StringComparer.Ordinal);

    internal static readonly string[] NodesToRemoveRequiredProperties = ["nodeId", "type"];
    internal static readonly string[] NodesToRemoveProperties = [.. NodesToRemoveRequiredProperties];
    internal static readonly string[] NodeInputUpdateRequiredProperties = ["nodeId", "inputs"];
    internal static readonly string[] NodeInputUpdateOptionalProperties = ["expectedActionId"];
    internal static readonly string[] NodeInputUpdateProperties = [.. NodeInputUpdateRequiredProperties, .. NodeInputUpdateOptionalProperties];
    internal static readonly string[] EdgesToRemoveRequiredProperties = ["edgeId", "fromNodeId", "toNodeId", "when"];
    internal static readonly string[] EdgesToRemoveProperties = [.. EdgesToRemoveRequiredProperties];
    internal static readonly string[] EdgesToAddRequiredProperties = ["edgeId", "fromNodeId", "toNodeId", "when"];
    internal static readonly string[] EdgesToAddOptionalProperties = ["label", "priority"];
    internal static readonly string[] EdgesToAddProperties = [.. EdgesToAddRequiredProperties, .. EdgesToAddOptionalProperties];

    internal static readonly string[] RemovableNodeTypeValues =
    [
        WorkflowNodeTypes.Action,
        WorkflowNodeTypes.Condition,
        WorkflowNodeTypes.Fork,
        WorkflowNodeTypes.Join,
        WorkflowNodeTypes.Loop,
        WorkflowNodeTypes.Switch,
        WorkflowNodeTypes.Assert,
        WorkflowNodeTypes.Repeat,
        WorkflowNodeTypes.Break,
        WorkflowNodeTypes.Continue,
        WorkflowNodeTypes.WorkflowCall,
        WorkflowNodeTypes.Return,
        WorkflowNodeTypes.UserInteraction,
        WorkflowNodeTypes.Succeed,
        WorkflowNodeTypes.Fail
    ];

    internal static readonly IReadOnlySet<string> RemovableNodeTypes =
        RemovableNodeTypeValues.ToHashSet(StringComparer.Ordinal);

    internal static readonly string[] EdgeConditionValues =
    [
        WorkflowEdgeConditions.Success,
        WorkflowEdgeConditions.Failure,
        WorkflowEdgeConditions.Always,
        WorkflowEdgeConditions.True,
        WorkflowEdgeConditions.False,
        WorkflowEdgeConditions.Branch,
        WorkflowEdgeConditions.Iteration,
        WorkflowEdgeConditions.JoinComplete
    ];

    internal static readonly IReadOnlySet<string> EdgeConditions = WorkflowEdgeConditions.All;
    internal static readonly string[] CleanupEdgeConditionValues = [WorkflowEdgeConditions.Success, WorkflowEdgeConditions.Failure];
    internal static readonly IReadOnlySet<string> CleanupEdgeConditions =
        CleanupEdgeConditionValues.ToHashSet(StringComparer.Ordinal);

    internal static object BuildDescriptor() => new
    {
        schemaVersion = DescriptorVersion,
        descriptorVersion = DescriptorVersion,
        candidateRootSchemaVersion = CandidateDocumentSchemaVersion,
        definitionType = WorkflowAssemblyDefinitionTypes.GraphPatch,
        source = "Dynomax production WorkflowGraphPatch contract and validator constants",
        important = $"This file is the model-facing GraphPatch descriptor v{DescriptorVersion}. It is NOT a candidate document. Actual Dynomax.WorkflowGraphPatch JSON must use root schemaVersion 1; start from workflow-graph-patch-template.json or workflow-redesign-template.json.",
        purpose = "Apply one atomic bounded Workflow change against one immutable Workflow revision. It can change the main graph, target the Cleanup graph, and, when targeting the exact current revision, replace Workflow input/output contracts or change mutable display metadata without changing the stable Workflow root/key.",
        documentSchema = new
        {
            type = "object",
            additionalProperties = false,
            required = RequiredRootProperties,
            properties = new
            {
                schemaVersion = new { type = "integer", @const = CandidateDocumentSchemaVersion },
                definitionType = new { type = "string", @const = WorkflowAssemblyDefinitionTypes.GraphPatch },
                operationId = new
                {
                    type = "string",
                    minLength = 32,
                    maxLength = 36,
                    format = "uuid",
                    acceptedForms = new[]
                    {
                        "lowercase 32-hexadecimal-digit GUID (N format)",
                        "lowercase hyphenated 8-4-4-4-12 GUID (D format)"
                    },
                    automationApiRule = "Must parse as a non-empty GUID at the Automation API boundary.",
                    workflowAssemblyRule = "The same text must already be lowercase and contain only letters, numbers, '.', '_' or '-'; after the GUID rule this leaves lowercase N or D GUID formats."
                },
                projectKey = new { type = "string", minLength = 1, maxLength = 150 },
                workflowId = new { type = "string", minLength = 1, maxLength = 200 },
                expectedWorkflowRevision = new { type = "integer", minimum = 1 },
                expectedWorkflowSha256 = new { type = "string", minLength = 64, maxLength = 64, format = "lowercase-or-uppercase hexadecimal SHA-256 accepted and normalized" },
                patch = new
                {
                    type = "object",
                    additionalProperties = false,
                    required = RequiredPatchProperties,
                    allowedProperties = PatchProperties
                }
            }
        },
        mutationElementSchemas = new
        {
            cleanup = new
            {
                type = "object",
                requiredAtPatchLevel = false,
                additionalProperties = false,
                required = CleanupRequiredPatchProperties,
                optional = new[] { "startNodeId", "failurePolicy", "nodesToRemove" },
                semantics = "Exact-current targeted Cleanup-graph mutation. Cleanup changes never safe-rebase; expectedWorkflowRevision and expectedWorkflowSha256 must still identify the current immutable revision.",
                properties = new
                {
                    startNodeId = new
                    {
                        type = new[] { "string", "null" },
                        maxLength = MaximumNodeIdLength,
                        semantics = "Optional replacement of cleanup.startNodeId. Supply a Cleanup Start node ID when creating Cleanup; supply null only when the prospective Cleanup has no nodes."
                    },
                    failurePolicy = new
                    {
                        type = "string",
                        @enum = CleanupFailurePolicyValues,
                        semantics = "Optional replacement of cleanup.failurePolicy. Omission preserves the current value."
                    },
                    nodesToAdd = new
                    {
                        type = "array",
                        minItems = 0,
                        maxItems = MaximumNodesToAdd,
                        allowedNodeTypes = CleanupNodeTypeValues,
                        semantics = "Cleanup supports Start, Action, Succeed and Fail only. Added Action nodes use the same Action reference, binding, secret and execution-policy validation as main-graph Action nodes. Cleanup Action NodeOutput bindings may consume normal outputs produced by main-graph Actions; if an early main failure means the producer never ran, runtime binding resolution fails closed rather than inventing a value."
                    },
                    nodesToRemove = new
                    {
                        type = "array",
                        minItems = 0,
                        maxItems = MaximumNodesToRemove,
                        requiredItemProperties = NodesToRemoveRequiredProperties,
                        allowedNodeTypes = CleanupNodeTypeValues,
                        semantics = "Exact Cleanup node selector/precondition. Cleanup Start may be removed only when startNodeId is also changed so the complete prospective Cleanup remains valid."
                    },
                    edgesToRemove = new
                    {
                        type = "array",
                        minItems = 0,
                        maxItems = MaximumEdgesToRemove,
                        requiredItemProperties = EdgesToRemoveRequiredProperties,
                        allowedWhen = CleanupEdgeConditionValues,
                        semantics = "Exact Cleanup edge selector/precondition using edgeId, fromNodeId, toNodeId and when."
                    },
                    edgesToAdd = new
                    {
                        type = "array",
                        minItems = 0,
                        maxItems = MaximumEdgesToAdd,
                        requiredItemProperties = EdgesToAddRequiredProperties,
                        optionalItemProperties = EdgesToAddOptionalProperties,
                        allowedWhen = CleanupEdgeConditionValues,
                        semantics = "Explicit final Cleanup edges. Endpoints must exist in the prospective Cleanup graph."
                    }
                }
            },
            nodeInputUpdates = new
            {
                type = "array",
                requiredAtPatchLevel = false,
                minItems = 0,
                maxItems = MaximumNodeInputUpdates,
                semantics = "Exact-current in-place Action-node input replacement. Node identity, actionRef, execution settings, UI placement and every graph edge are preserved; stale revision/hash requests fail closed.",
                items = new
                {
                    type = "object",
                    additionalProperties = false,
                    required = NodeInputUpdateRequiredProperties,
                    optional = NodeInputUpdateOptionalProperties,
                    properties = new
                    {
                        nodeId = new { type = "string", minLength = 1, maxLength = MaximumNodeIdLength, format = "Dynomax node ID" },
                        expectedActionId = new { type = new[] { "string", "null" }, maxLength = 200, semantics = "Optional exact actionId precondition." },
                        inputs = new { type = "object", maxProperties = 100, semantics = "Complete replacement Action inputs object; bindings are revalidated against the unchanged actionRef." }
                    },
                    selectorRules = new[]
                    {
                        "nodeId values must be unique within nodeInputUpdates.",
                        "The selected current node must exist and be type Action.",
                        "When expectedActionId is supplied it must exactly match the current actionRef.actionId.",
                        "No graph edges are removed or re-added by this operation."
                    }
                }
            },            nodesToRemove = new
            {
                type = "array",
                requiredAtPatchLevel = false,
                minItems = 0,
                maxItems = MaximumNodesToRemove,
                semantics = "Exact target-node selector/precondition. This is not a full saved graph node object.",
                items = new
                {
                    type = "object",
                    additionalProperties = false,
                    required = NodesToRemoveRequiredProperties,
                    optional = Array.Empty<string>(),
                    properties = new
                    {
                        nodeId = new
                        {
                            type = "string",
                            minLength = 1,
                            maxLength = MaximumNodeIdLength,
                            format = "Dynomax node ID: starts with a letter; letters, numbers, '.', '_' and '-' only"
                        },
                        type = new { type = "string", @enum = RemovableNodeTypeValues }
                    },
                    selectorRules = new[]
                    {
                        "nodeId values must be unique within nodesToRemove.",
                        "The selected current node must exist and its saved type must exactly equal type.",
                        "Start cannot be removed.",
                        "Every incident current edge must be selected in edgesToRemove before the node can be removed."
                    }
                }
            },
            edgesToRemove = new
            {
                type = "array",
                requiredAtPatchLevel = true,
                minItems = 0,
                maxItems = MaximumEdgesToRemove,
                semantics = "Exact target-edge selector/precondition. This is a four-field mutation selector, not a full saved graph edge object.",
                items = new
                {
                    type = "object",
                    additionalProperties = false,
                    required = EdgesToRemoveRequiredProperties,
                    optional = Array.Empty<string>(),
                    properties = new
                    {
                        edgeId = new
                        {
                            type = "string",
                            minLength = 1,
                            maxLength = MaximumCanonicalEdgeIdLength,
                            mutationParserMaxLength = MaximumGraphPatchEdgeIdInputLength,
                            canonicalGraphMaxLength = MaximumCanonicalEdgeIdLength,
                            format = "Dynomax edge ID: starts with a letter; letters, numbers, '.', '_' and '-' only"
                        },
                        fromNodeId = new
                        {
                            type = "string",
                            minLength = 1,
                            maxLength = MaximumNodeIdLength,
                            format = "Dynomax node ID: starts with a letter; letters, numbers, '.', '_' and '-' only"
                        },
                        toNodeId = new
                        {
                            type = "string",
                            minLength = 1,
                            maxLength = MaximumNodeIdLength,
                            format = "Dynomax node ID: starts with a letter; letters, numbers, '.', '_' and '-' only"
                        },
                        when = new { type = "string", @enum = EdgeConditionValues }
                    },
                    selectorRules = new[]
                    {
                        "edgeId values must be unique within edgesToRemove.",
                        "The current graph must contain exactly one edge with edgeId.",
                        "That edge's fromNodeId, toNodeId and when must exactly equal the selector values."
                    }
                }
            },
            edgesToAdd = new
            {
                type = "array",
                requiredAtPatchLevel = true,
                minItems = 0,
                maxItems = MaximumEdgesToAdd,
                semantics = "Explicit final graph edge mutation object. Only the listed fields are accepted.",
                items = new
                {
                    type = "object",
                    additionalProperties = false,
                    required = EdgesToAddRequiredProperties,
                    optional = EdgesToAddOptionalProperties,
                    properties = new
                    {
                        edgeId = new
                        {
                            type = "string",
                            minLength = 1,
                            maxLength = MaximumCanonicalEdgeIdLength,
                            mutationParserMaxLength = MaximumGraphPatchEdgeIdInputLength,
                            canonicalGraphMaxLength = MaximumCanonicalEdgeIdLength,
                            format = "Dynomax edge ID: starts with a letter; letters, numbers, '.', '_' and '-' only after canonical graph validation"
                        },
                        fromNodeId = new
                        {
                            type = "string",
                            minLength = 1,
                            maxLength = MaximumNodeIdLength,
                            format = "Dynomax node ID: starts with a letter; letters, numbers, '.', '_' and '-' only"
                        },
                        toNodeId = new
                        {
                            type = "string",
                            minLength = 1,
                            maxLength = MaximumNodeIdLength,
                            format = "Dynomax node ID: starts with a letter; letters, numbers, '.', '_' and '-' only"
                        },
                        when = new { type = "string", @enum = EdgeConditionValues },
                        label = new { type = new[] { "string", "null" }, maxLength = MaximumEdgeLabelLength },
                        priority = new { type = "integer", minimum = 0, maximum = MaximumEdgePriority, @default = 0 }
                    },
                    validationRules = new[]
                    {
                        "edgeId values must be unique within edgesToAdd and must not collide with an edge remaining after removals.",
                        "fromNodeId and toNodeId must exist in the prospective graph after all node removals/additions.",
                        "The complete prospective graph must satisfy the normal Dynomax edge-cardinality, topology and control-flow validator."
                    }
                }
            }
        },
        root = new
        {
            required = RequiredRootProperties,
            patch = new
            {
                required = RequiredPatchProperties,
                optional = new[] { "nodesToRemove", "metadata", "workflowInputs", "workflowOutputs" },
                metadata = "Optional object. Supports displayName and description only. displayName must be non-empty when supplied; description may be string or null. Stable workflowId/key is never mutable.",
                workflowInputs = "Optional full replacement array for canonical workflowInputs (0..100). Each item uses name/displayName/dataType/required/classification/defaultBinding/description. Supplying [] clears the contract. Required caller-supplied inputs in Return-based callable Workflows may omit defaultBinding; direct execution then requires caller context. Secret-reference inputs use classification 'SecretReference'.",
                workflowOutputs = "Optional full replacement array for canonical workflowOutputs (0..100). Supplying [] clears the contract.",
                nodesToAdd = $"0..{MaximumNodesToAdd} nodes. Allowed: Action (BuiltIn or existing Workspace UserAction), Condition, Fork, Join, Loop, Switch, Assert, Repeat, Break, Continue, WorkflowCall, Return, UserInteraction, Succeed, Fail. Fork supports optional maximumParallelism 1..16 (default 1). Each added node may carry optional ui {{ x, y, collapsed, lane }} which is stored only in Workflow UI metadata.",
                nodesToRemove = $"Optional 0..{MaximumNodesToRemove} exact target-node preconditions {{ nodeId, type }}. Start cannot be removed. Removing/replacing a node requires every incident target edge to appear in edgesToRemove.",
                edgesToRemove = $"0..{MaximumEdgesToRemove} exact target-edge preconditions. Each item contains edgeId, fromNodeId, toNodeId and when exactly as expected.",
                edgesToAdd = $"0..{MaximumEdgesToAdd} explicit final graph edges. Endpoints must exist after node removals/additions.",
                cleanup = $"Optional exact-current targeted Cleanup patch with startNodeId/failurePolicy replacements plus 0..{MaximumNodesToAdd} nodesToAdd, optional nodesToRemove, 0..{MaximumEdgesToRemove} edgesToRemove and 0..{MaximumEdgesToAdd} edgesToAdd. Cleanup supports Start, Action, Succeed and Fail only. At least one main graph, Cleanup, metadata, Workflow input or Workflow output change is required overall."
            }
        },
        workflowInputItemSchema = WorkflowAgentContractSchema.BuildWorkflowInputItemSchema(),
        callableWorkflowInputSemantics = WorkflowAgentContractSchema.CallableInputSemantics(),
        definitionContractChanges = new
        {
            exactCurrentRevisionOnly = true,
            immutableRevisionRule = "A metadata/workflowInputs/workflowOutputs or Cleanup patch always validates the complete prospective canonical Workflow and saves one new immutable revision. Historical revisions remain byte-stable.",
            stableIdentityRule = "displayName/description may change, but workflowId and the Workflow root/key do not change.",
            replacementRule = "workflowInputs and workflowOutputs are complete replacement arrays when present; omission means leave unchanged; [] means clear.",
            staleRule = "Definition-contract and Cleanup changes do not safe-rebase. If expected revision/hash is no longer the exact current target, generate a fresh Workflow Pack and patch."
        },
        authoringModes = new
        {
            incrementalChange = new
            {
                template = "workflow-graph-patch-template.json",
                rule = "Use for localized additions/removals/replacements. Include only exact nodes/edges the requested change touches, preserving unrelated current graph elements."
            },
            fullRedesign = new
            {
                template = "workflow-redesign-template.json",
                rule = "Use when the user explicitly wants the current main Workflow redesigned/replaced. The generated template retains Start, pre-populates exact removal preconditions for every other current main-graph node and every current main-graph edge, and leaves nodesToAdd/edgesToAdd for the complete replacement graph. Import creates one new immutable Workflow revision; the source revision remains unchanged."
            }
        },
        supportedNodeTypes = RemovableNodeTypeValues,
        cleanupSupportedNodeTypes = CleanupNodeTypeValues,
        actionNode = new
        {
            rule = "GraphPatch adds executable Action nodes from one explicit origin. BuiltIn references the source-owned Dynomax catalogue; UserAction references an existing Workspace Action. GraphPatch never creates or modifies reusable implementation source.",
            actionRef = new
            {
                required = new[] { "origin", "actionId", "versionPolicy" },
                origins = new[] { ActionCapabilityOrigins.BuiltIn, ActionCapabilityOrigins.UserAction },
                builtInVersionPolicy = new[] { BuiltInActionVersionPolicies.Shipped, BuiltInActionVersionPolicies.Exact },
                userActionVersionPolicy = new[] { WorkflowActionVersionPolicies.Current, WorkflowActionVersionPolicies.Exact },
                exactVersionRule = "version is required for Exact. BuiltIn/Shipped and UserAction/Current forbid version. Dynomax resolves the appropriate source-owned or Workspace-owned immutable contract before saving."
            },
            inputs = "Object of Dynomax bindings validated against the exact Action input contract. Secret Action inputs remain SecretReference-only unless the exact contract says otherwise. A Sensitive input may consume a sensitive NodeOutput only when the contract explicitly permits NodeOutput. A Normal input may consume a SensitiveRedacted NodeOutput only when the exact Built-in input advertises acceptSensitiveNodeOutput=true, in which case the declared output propagation policy keeps derived values SensitiveRedacted and runtime-only. Implicit sensitive-to-Normal downgrade is forbidden; secret/sensitive values are never permitted as Literal or ordinary project values.",
            optional = new[] { "description", "session", "timeoutSeconds", "retryPolicy", "executionPolicy", "continuePolicy", "disabled", "notes", "ui" }
        },
        forkNode = new
        {
            failurePolicy = new { type = "string", @enum = new[] { "FailFast" }, defaultValue = "FailFast" },
            maximumParallelism = new
            {
                type = "integer",
                minimum = 1,
                maximum = 16,
                defaultValue = 1,
                semantics = "1 preserves deterministic sequential branch scheduling. Values 2..16 request bounded isolated parallel branch execution; the compiler rejects overlapping branch regions and inherited browser-session dependencies before publication."
            }
        },
        workflowCompositionNodes = new
        {
            WorkflowCall = "Use workflow-call-contract.json. workflowRef.workflowId must name a same-Workspace Workflow from workspace-workflows.json; versionPolicy is Current or Exact; exactly one Success edge. If a child input is classified SecretReference, its call-site binding must be an exact SecretReference { kind, key }; WorkflowInput/ProjectVariable/Literal/NodeOutput are not accepted at that boundary. Sensitive/SensitiveRedacted values are not permitted to cross WorkflowCall boundaries in the initial sensitivity-preserving release; keep the sensitive chain within one Workflow root.",
            Return = "Use workflow-call-contract.json. Return is a child-success boundary with no outgoing edge. Do not use End successfully inside a Workflow intended to be called."
        },
        userInteractionNode = new
        {
            runtimeSupport = "Durable same-Run interaction checkpoints support authenticated Starter, User, Role and Group assignment plus optional bounded expiry.",
            allowedProperties = new[] { "nodeId", "type", "displayName", "description", "pageKey", "responseFields", "assignmentMode", "assignedUserId", "assignedRoleKey", "expiresAfterSeconds", "ui" },
            pageKey = "Required stable semantic App page key; mutable App layout/presentation is never embedded in the Workflow.",
            expiresAfterSeconds = "Optional integer 1..86400. The Worker converts this relative duration into an absolute durable checkpoint expiry; omit for no automatic expiry.",
            assignment = new
            {
                modes = new[] { "Starter", "User", "Role", "Group" },
                defaultMode = "Starter",
                user = "User requires assignedUserId as one non-empty user GUID.",
                role = "Role requires assignedRoleKey matching an active Workspace role.",
                group = "Group requires assignedRoleKey matching a named active identity group."
            },
            responseFields = new
            {
                minimum = 1,
                maximum = 100,
                allowedDataTypes = new[] { WorkflowDataTypes.String, WorkflowDataTypes.Boolean, WorkflowDataTypes.Integer, WorkflowDataTypes.Decimal, WorkflowDataTypes.Guid, WorkflowDataTypes.Json, WorkflowDataTypes.FileReference },
                allowedClassifications = new[] { WorkflowValueClassifications.Normal, WorkflowValueClassifications.Sensitive },
                requiredItemProperties = new[] { "name", "dataType", "required" },
                optionalItemProperties = new[] { "classification" },
                uniqueness = "Field names are case-insensitively unique."
            },
            edgeRule = "Exactly one outgoing Success edge. UserInteraction is Main-only and is never valid in Cleanup.",
            safety = "Do not emulate the checkpoint with RunContinuation or a child/new Run."
        },
        inputBindingShapes = WorkflowAgentContractSchema.BuildBindingShapes(),
        topologyRules = new[]
        {
            "expectedWorkflowRevision + expectedWorkflowSha256 identify the immutable source revision for provenance and conflict checking; they are not a blanket current-revision lock. The package remains idempotent per target Workflow by operationId + package SHA-256.",
            "The patch always transforms the target Workflow's current saved revision and saves exactly one new immutable revision; historical revisions are never edited. Main-graph-only packages may safe-rebase after exact touched-element checks. Cleanup and metadata/workflowInputs/workflowOutputs changes require the recorded revision/hash to be the exact current target and never safe-rebase.",
            "A node may be replaced under the same logical nodeId only by listing the exact old { nodeId, type } in nodesToRemove first.",
            "The current Start boundary is retained. The prospective graph must still contain exactly one Start and at least one terminal Succeed/Fail/Return node. A Workflow intended to be called uses Return for successful child completion.",
            "The prospective complete Workflow is validated by the normal Dynomax graph validator, Action-version resolver, binding validator and secret rules before it is saved.",
            "Fork remains FailFast with 2+ unique named Branch edges and one paired Join mode All. maximumParallelism defaults to 1 for backward-compatible sequential scheduling; 2..16 explicitly requests bounded isolated parallel execution.",
            "Loop remains a real bounded graph cycle with mandatory maximumIterations 1..100 and overallTimeoutSeconds 1..14400.",
            "Repeat is a first-class bounded count loop with count 1..1000 and overallTimeoutSeconds 1..14400.",
            "Switch routes one typed value over unique Branch labels with at most one Default edge; Assert evaluates a typed condition and fails closed on false.",
            "Break and Continue are valid only inside one enclosing Loop/Repeat scope and must target the validator-proven loop exit/next-iteration boundary.",
            "Nested Fork before its paired Join, Loop/Repeat inside Fork, and unsupported nested control flow inside a loop cycle remain rejected by the validator.",
            "Main-graph WorkflowGraphPatch cannot add Start, Wait, Parallel or ForEach nodes and cannot embed Action implementation/source text. It may add WorkflowCall, Return and the P003 UserInteraction durable checkpoint contract. UserInteraction is executable and Main-only. Cleanup patching may add Start, Action, Succeed and Fail only; the full prospective main + Cleanup Workflow is validated before persistence."
        },
        security = new
        {
            rule = "Never include credentials, tokens, cookies, OTPs or secret/sensitive values. Action secret inputs use safe SecretReference keys. SensitiveRedacted NodeOutputs may flow only through inputs explicitly declared sensitivity-preserving and into explicit Sensitive sinks. Condition/Loop/Switch/Assert operands remain Normal-only in this release. Compared runtime operand values are not durable control-flow evidence."
        }
    };
}
