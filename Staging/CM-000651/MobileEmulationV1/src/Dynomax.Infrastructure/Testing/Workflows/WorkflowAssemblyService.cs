using System.Security.Cryptography;
using System.Text;
using System.Text.Json;
using System.Text.Json.Nodes;
using Dynomax.Application.Testing.Actions;
using Dynomax.Application.Testing.ExecutionPolicies;
using Dynomax.Application.Testing.Workflows;
using Dynomax.Domain.Auditing;
using Dynomax.Domain.Projects.Configuration;
using Dynomax.Domain.Testing.Actions;
using Dynomax.Domain.Testing.Tests;
using Dynomax.Domain.Testing.Workflows;
using Dynomax.Infrastructure.Persistence;
using Dynomax.Infrastructure.Testing.Actions;
using Microsoft.EntityFrameworkCore;

namespace Dynomax.Infrastructure.Testing.Workflows;

internal sealed class WorkflowAssemblyService : IWorkflowAssemblyService
{
    private const int MaximumPackageBytes = 4 * 1024 * 1024;
    private const int MaximumSourceBytes = 2 * 1024 * 1024;
    private const int SchemaVersion = 1;

    private readonly DynomaxDbContext _dbContext;
    private readonly IActionLibraryService _actions;
    private readonly IActionSourcePackageService _sourcePackages;
    private readonly IWorkflowDraftService _workflows;

    public WorkflowAssemblyService(
        DynomaxDbContext dbContext,
        IActionLibraryService actions,
        IActionSourcePackageService sourcePackages,
        IWorkflowDraftService workflows)
    {
        _dbContext = dbContext;
        _actions = actions;
        _sourcePackages = sourcePackages;
        _workflows = workflows;
    }

    public Task<WorkflowAssemblyPreview> ValidateAsync(
        Guid projectId,
        string expectedProjectKey,
        string packageJson,
        CancellationToken cancellationToken) =>
        ValidateAsync(projectId, null, expectedProjectKey, packageJson, cancellationToken);

    public async Task<WorkflowAssemblyPreview> ValidateAsync(
        Guid projectId,
        Guid? targetWorkflowDraftId,
        string expectedProjectKey,
        string packageJson,
        CancellationToken cancellationToken)
    {
        ParsedAssemblyPackage package = ParsePackage(packageJson);
        string projectKey = await GetProjectKeyAsync(projectId, cancellationToken);
        EnsureProjectKey(projectKey, expectedProjectKey, package.ProjectKey);
        ProjectTestDraft? targetDraft = package is ParsedWorkflowSeed
            ? null
            : await ResolveTargetDraftAsync(projectId, targetWorkflowDraftId, package.WorkflowId, tracking: false, cancellationToken: cancellationToken);

        return package switch
        {
            ParsedWorkflowSeed seed => await ValidateSeedAsync(projectId, projectKey, seed, cancellationToken),
            ParsedActionAppend append => await ValidateAppendAsync(projectId, projectKey, targetDraft, append, cancellationToken),
            ParsedSystemNodeAppend system => await ValidateSystemNodeAppendAsync(projectId, projectKey, targetDraft, system, cancellationToken),
            ParsedGraphPatch patch => await ValidateGraphPatchAsync(projectId, projectKey, targetDraft, patch, cancellationToken),
            _ => throw new InvalidOperationException("Unsupported Workflow assembly package.")
        };
    }

    public async Task<WorkflowAssemblyApplyResult> ApplyAsync(
        ApplyWorkflowAssemblyRequest request,
        CancellationToken cancellationToken)
    {
        if (request.ProjectId == Guid.Empty) throw new ArgumentException("Project ID is required.", nameof(request));
        if (request.WriteContext.ActorUserId == Guid.Empty) throw new ArgumentException("Actor user ID is required.", nameof(request));

        ParsedAssemblyPackage package = ParsePackage(request.PackageJson);
        string projectKey = await GetProjectKeyAsync(request.ProjectId, cancellationToken);
        EnsureProjectKey(projectKey, request.ExpectedProjectKey, package.ProjectKey);

        var strategy = _dbContext.Database.CreateExecutionStrategy();
        return await strategy.ExecuteAsync(async () =>
        {
            await using var transaction = await _dbContext.Database.BeginTransactionAsync(cancellationToken);
            try
            {
                ProjectTestDraft? targetDraft = package is ParsedWorkflowSeed
                    ? null
                    : await ResolveTargetDraftAsync(request.ProjectId, request.TargetWorkflowDraftId, package.WorkflowId, tracking: true, cancellationToken: cancellationToken);
                WorkflowAssemblyApplyResult result = package switch
                {
                    ParsedWorkflowSeed seed => await ApplySeedAsync(request.ProjectId, projectKey, seed, request.WriteContext, cancellationToken),
                    ParsedActionAppend append => await ApplyAppendAsync(request.ProjectId, projectKey, RequireTargetDraft(targetDraft, append.WorkflowId), append, request.WriteContext, cancellationToken),
                    ParsedSystemNodeAppend system => await ApplySystemNodeAppendAsync(request.ProjectId, projectKey, RequireTargetDraft(targetDraft, system.WorkflowId), system, request.WriteContext, cancellationToken),
                    ParsedGraphPatch patch => await ApplyGraphPatchAsync(request.ProjectId, projectKey, RequireTargetDraft(targetDraft, patch.WorkflowId), patch, request.WriteContext, cancellationToken),
                    _ => throw new InvalidOperationException("Unsupported Workflow assembly package.")
                };
                await transaction.CommitAsync(cancellationToken);
                return result;
            }
            catch
            {
                await transaction.RollbackAsync(cancellationToken);
                _dbContext.ChangeTracker.Clear();
                throw;
            }
        });
    }

    private async Task<WorkflowAssemblyPreview> ValidateSeedAsync(
        Guid projectId,
        string projectKey,
        ParsedWorkflowSeed seed,
        CancellationToken cancellationToken)
    {
        ProjectTestDraft? existing = await _dbContext.ProjectTestDrafts.AsNoTracking()
            .SingleOrDefaultAsync(item => item.ProjectId == projectId && item.Key == seed.WorkflowId && item.Status == WorkflowDraftStatuses.Active, cancellationToken);
        if (existing is not null)
        {
            ProjectTestDraftRevision? applied = await FindRevisionByOperationIdAsync(existing.Id, seed.OperationId, PackageSha256(seed.NormalizedJson), cancellationToken);
            if (applied is not null)
            {
                return Preview(seed, existing.DisplayName, existing.Description, null, null, null, null,
                    willCreateWorkflow: false, willCreateAction: false, willCreateRevision: false, isNoOp: true,
                    applied.DefinitionSha256, [], "This Workflow seed was already applied; importing it again will make no changes.");
            }

            return Preview(seed, seed.DisplayName, seed.Description, null, null, null, null,
                willCreateWorkflow: false, willCreateAction: false, willCreateRevision: false, isNoOp: false,
                null,
                [Error("WF-ASSEMBLY-WORKFLOW-EXISTS", "$.workflowId", $"An active Workflow '{seed.WorkflowId}' already exists. Use an Action/System append or graph-patch package against that Workflow; older source provenance may safely rebase when its touched graph still matches.")]);
        }

        string definitionJson = BuildSeedWorkflowDefinition(projectKey, seed);
        WorkflowDraftValidationResult validation = await _workflows.ValidateJsonAsync(projectId, projectKey, definitionJson, cancellationToken);
        return Preview(seed, seed.DisplayName, seed.Description, null, null, null, null,
            willCreateWorkflow: true, willCreateAction: false, willCreateRevision: true, isNoOp: false,
            validation.DefinitionSha256,
            validation.Issues,
            validation.ValidationStatus == TestValidationStatuses.Valid
                ? "The metadata-only package will create a new empty Workflow revision: START → SUCCEED."
                : null);
    }

    private async Task<WorkflowAssemblyPreview> ValidateAppendAsync(
        Guid projectId,
        string projectKey,
        ProjectTestDraft? draft,
        ParsedActionAppend append,
        CancellationToken cancellationToken)
    {
        var issues = new List<WorkflowDraftValidationIssue>();
        if (draft is null)
        {
            issues.Add(Error("WF-ASSEMBLY-WORKFLOW-MISSING", "$.workflowId", $"The target Workflow was not found in the selected Workspace."));
            return Preview(append, append.WorkflowId, null, null, null, append.NewNodeId, append.Action.Mode,
                false, false, false, false, null, issues);
        }

        ProjectTestDraftRevision? applied = await FindRevisionByOperationIdAsync(draft.Id, append.OperationId, PackageSha256(append.NormalizedJson), cancellationToken);
        if (applied is not null)
        {
            return Preview(append, draft.DisplayName, draft.Description, append.InsertAfterNodeId, null, append.NewNodeId, append.Action.Mode,
                false, false, false, true, applied.DefinitionSha256, [],
                "This Action package was already applied; importing it again will make no changes.", append.Action.ActionId, append.Action.ExactVersion);
        }

        WorkflowDraftRevisionDetails current = await GetCurrentRevisionAsync(projectId, draft, cancellationToken);
        if (!WorkflowAuthoringPersistencePolicy.IsPersistable(current))
        {
            issues.Add(Error(
                "WF-ASSEMBLY-CURRENT-AUTHORING-STATE-NOT-PERSISTABLE",
                "$.workflowId",
                "The current Workflow revision contains a warning-only authoring state that this incremental append path cannot preserve. Only the P003 User Interaction checkpoint WG-RUNTIME-001 warning state is supported."));
        }
        AssemblyBaseResolution provenance = await ResolveAssemblyBaseAsync(
            projectId, draft, current, append.WorkflowId, append.ExpectedRevisionNumber, append.ExpectedDefinitionSha256, issues, cancellationToken);
        string? nextNodeId = ValidateInsertionPoint(current.CanonicalDefinitionJson, append.InsertAfterNodeId, append.NewNodeId, issues);
        ValidateAppendRebasePreconditions(provenance, current, append.InsertAfterNodeId, issues);

        int actionVersion = append.Action.ExactVersion ?? 1;
        bool willCreateAction = false;
        if (append.Action.Mode == WorkflowAssemblyActionModes.Create)
        {
            try
            {
                ValidateCreateAction(append.Action);
                ValidateInlineSource(append.Action);
                ActionLibraryDetails? existing = await FindActionDetailsAsync(projectId, append.Action.ActionId, cancellationToken);
                if (existing is null)
                {
                    willCreateAction = true;
                }
                else
                {
                    PortableCreateReuse? reusable = await FindPortableCreateReuseAsync(projectId, append.Action, cancellationToken);
                    if (reusable is null)
                    {
                        issues.Add(Error("WF-ASSEMBLY-ACTION-EXISTS", "$.action.actionId",
                            $"Action '{append.Action.ActionId}' already exists, but its immutable v1 definition/source does not match this Create package. Dynomax will not overwrite or reinterpret the existing Action."));
                    }
                    else
                    {
                        issues.Add(Info("WF-ASSEMBLY-ACTION-REUSED", "$.action",
                            $"Portable import will reuse existing immutable Action '{append.Action.ActionId}' v{reusable.Version.VersionNumber}; the Create payload matches its stored definition and verified source exactly."));
                    }
                }
            }
            catch (Exception exception) when (exception is ArgumentException or InvalidOperationException or JsonException)
            {
                issues.Add(Error("WF-ASSEMBLY-ACTION-INVALID", "$.action", exception.Message));
            }
        }
        else
        {
            ActionVersionLookup? existingAction = await FindExactActionVersionAsync(projectId, append.Action.ActionId, actionVersion, cancellationToken);
            if (existingAction is null)
            {
                issues.Add(Error("WF-ASSEMBLY-ACTION-MISSING", "$.action",
                    $"Active Action '{append.Action.ActionId}' v{actionVersion} with a verified source package was not found in this project."));
            }
        }

        string? prospectiveHash = null;
        if (issues.All(issue => issue.Severity != TestValidationSeverities.Error) && nextNodeId is not null)
        {
            string prospective = BuildAppendedWorkflowDefinition(
                current.CanonicalDefinitionJson,
                append,
                actionVersion,
                nextNodeId,
                current.RevisionNumber,
                current.DefinitionSha256);
            prospectiveHash = WorkflowDraftCanonicalJson.Hash(prospective);

            if (append.Action.Mode == WorkflowAssemblyActionModes.UseExact)
            {
                WorkflowDraftValidationResult validation = await _workflows.ValidateJsonAsync(projectId, projectKey, prospective, cancellationToken);
                issues.AddRange(validation.Issues);
                prospectiveHash = validation.DefinitionSha256;
            }
            else
            {
                issues.Add(Info("WF-ASSEMBLY-ATOMIC-VALIDATION", "$.action",
                    "The new Action and complete Workflow graph will be validated together inside one transaction before any change is committed."));
            }
        }

        return Preview(
            append,
            draft.DisplayName,
            draft.Description,
            append.InsertAfterNodeId,
            nextNodeId,
            append.NewNodeId,
            append.Action.Mode,
            false,
            willCreateAction,
            issues.All(issue => issue.Severity != TestValidationSeverities.Error),
            false,
            prospectiveHash,
            issues,
            null,
            append.Action.ActionId,
            actionVersion);
    }

    private async Task<WorkflowAssemblyPreview> ValidateSystemNodeAppendAsync(
        Guid projectId,
        string projectKey,
        ProjectTestDraft? draft,
        ParsedSystemNodeAppend append,
        CancellationToken cancellationToken)
    {
        var issues = new List<WorkflowDraftValidationIssue>();
        if (draft is null)
        {
            issues.Add(Error("WF-ASSEMBLY-WORKFLOW-MISSING", "$.workflowId", $"The target Workflow was not found in the selected Workspace."));
            return Preview(append, append.WorkflowId, null, null, null, append.NewNodeId, "System",
                false, false, false, false, null, issues, actionId: "system.condition");
        }

        ProjectTestDraftRevision? applied = await FindRevisionByOperationIdAsync(draft.Id, append.OperationId, PackageSha256(append.NormalizedJson), cancellationToken);
        if (applied is not null)
        {
            return Preview(append, draft.DisplayName, draft.Description, append.InsertAfterNodeId, null, append.NewNodeId, "System",
                false, false, false, true, applied.DefinitionSha256, [],
                "This System-node package was already applied; importing it again will make no changes.", "system.condition");
        }

        WorkflowDraftRevisionDetails current = await GetCurrentRevisionAsync(projectId, draft, cancellationToken);
        if (!WorkflowAuthoringPersistencePolicy.IsPersistable(current))
        {
            issues.Add(Error(
                "WF-ASSEMBLY-CURRENT-AUTHORING-STATE-NOT-PERSISTABLE",
                "$.workflowId",
                "The current Workflow revision contains a warning-only authoring state that this incremental append path cannot preserve. Only the P003 User Interaction checkpoint WG-RUNTIME-001 warning state is supported."));
        }
        AssemblyBaseResolution provenance = await ResolveAssemblyBaseAsync(
            projectId, draft, current, append.WorkflowId, append.ExpectedRevisionNumber, append.ExpectedDefinitionSha256, issues, cancellationToken);
        string? nextNodeId = ValidateInsertionPoint(current.CanonicalDefinitionJson, append.InsertAfterNodeId, append.NewNodeId, issues);
        ValidateAppendRebasePreconditions(provenance, current, append.InsertAfterNodeId, issues);
        ValidateSystemBranchTargets(current.CanonicalDefinitionJson, append, issues);

        string? prospectiveHash = null;
        if (issues.All(issue => issue.Severity != TestValidationSeverities.Error) && nextNodeId is not null)
        {
            string prospective = BuildSystemNodeAppendedWorkflowDefinition(
                current.CanonicalDefinitionJson,
                append,
                nextNodeId,
                current.RevisionNumber,
                current.DefinitionSha256);
            WorkflowDraftValidationResult validation = await _workflows.ValidateJsonAsync(projectId, projectKey, prospective, cancellationToken);
            issues.AddRange(validation.Issues);
            prospectiveHash = validation.DefinitionSha256;
        }

        return Preview(
            append,
            draft.DisplayName,
            draft.Description,
            append.InsertAfterNodeId,
            nextNodeId,
            append.NewNodeId,
            "System",
            false,
            false,
            issues.All(issue => issue.Severity != TestValidationSeverities.Error),
            false,
            prospectiveHash,
            issues,
            null,
            "system.condition");
    }

    private async Task<WorkflowAssemblyPreview> ValidateGraphPatchAsync(
        Guid projectId,
        string projectKey,
        ProjectTestDraft? draft,
        ParsedGraphPatch patch,
        CancellationToken cancellationToken)
    {
        var issues = new List<WorkflowDraftValidationIssue>();
        if (draft is null)
        {
            issues.Add(Error("WF-ASSEMBLY-WORKFLOW-MISSING", "$.workflowId", $"The target Workflow was not found in the selected Workspace."));
            return Preview(patch, patch.WorkflowId, null, null, null, patch.FirstNewNodeId, "WorkflowGraphPatch",
                false, false, false, false, null, issues, actionId: "workflow.graph-patch");
        }

        ProjectTestDraftRevision? applied = await FindRevisionByOperationIdAsync(draft.Id, patch.OperationId, PackageSha256(patch.NormalizedJson), cancellationToken);
        if (applied is not null)
        {
            return Preview(patch, draft.DisplayName, draft.Description, null, null, patch.FirstNewNodeId, "WorkflowGraphPatch",
                false, false, false, true, applied.DefinitionSha256, [],
                "This Workflow graph patch was already applied; importing it again will make no changes.", "workflow.graph-patch");
        }

        WorkflowDraftRevisionDetails current = await GetCurrentRevisionAsync(projectId, draft, cancellationToken);
        AssemblyBaseResolution provenance = await ResolveAssemblyBaseAsync(
            projectId, draft, current, patch.WorkflowId, patch.ExpectedRevisionNumber, patch.ExpectedDefinitionSha256, issues, cancellationToken);
        ValidateGraphPatchRebasePreconditions(provenance, current, patch, issues);
        string? prospectiveHash = null;
        string? prospectiveCanonicalDefinitionJson = null;
        if (issues.All(issue => issue.Severity != TestValidationSeverities.Error))
        {
            try
            {
                string prospective = BuildGraphPatchedWorkflowDefinition(
                    current.CanonicalDefinitionJson,
                    patch,
                    current.RevisionNumber,
                    current.DefinitionSha256);
                WorkflowDraftValidationResult validation = await _workflows.ValidateJsonAsync(projectId, projectKey, prospective, cancellationToken);
                issues.AddRange(validation.Issues);
                prospectiveHash = validation.DefinitionSha256;
                if (WorkflowAuthoringPersistencePolicy.IsPersistable(validation))
                {
                    prospectiveCanonicalDefinitionJson = validation.CanonicalDefinitionJson;
                }
                else if (validation.Issues.All(issue => issue.Severity != TestValidationSeverities.Error))
                {
                    issues.Add(Error(
                        "WF-ASSEMBLY-GRAPH-PATCH-NOT-PERSISTABLE",
                        "$.patch",
                        "The prospective Workflow is valid for authoring but cannot be persisted through WorkflowGraphPatch. Only the P003 User Interaction checkpoint WG-RUNTIME-001 warning state is supported by this authoring path."));
                }
            }
            catch (InvalidOperationException exception)
            {
                issues.Add(Error("WF-ASSEMBLY-GRAPH-PATCH-INVALID", "$.patch", exception.Message));
            }
        }

        return Preview(patch, draft.DisplayName, draft.Description, null, null, patch.FirstNewNodeId, "WorkflowGraphPatch",
            false, false, issues.All(issue => issue.Severity != TestValidationSeverities.Error), false,
            prospectiveHash, issues, null, "workflow.graph-patch", prospectiveCanonicalDefinitionJson: prospectiveCanonicalDefinitionJson);
    }

    private async Task<WorkflowAssemblyApplyResult> ApplySeedAsync(
        Guid projectId,
        string projectKey,
        ParsedWorkflowSeed seed,
        WorkflowDraftWriteContext writeContext,
        CancellationToken cancellationToken)
    {
        ProjectTestDraft? existing = await _dbContext.ProjectTestDrafts.AsNoTracking()
            .SingleOrDefaultAsync(item => item.ProjectId == projectId && item.Key == seed.WorkflowId && item.Status == WorkflowDraftStatuses.Active, cancellationToken);
        if (existing is not null)
        {
            ProjectTestDraftRevision? applied = await FindRevisionByOperationIdAsync(existing.Id, seed.OperationId, PackageSha256(seed.NormalizedJson), cancellationToken);
            if (applied is null)
                throw new InvalidOperationException($"An active Workflow '{seed.WorkflowId}' already exists and was not created by this operation.");

            WorkflowDraftDetails details = await _workflows.GetAsync(projectId, existing.Id, cancellationToken)
                ?? throw new InvalidOperationException("The existing Workflow could not be reloaded.");
            WorkflowDraftRevisionDetails revision = await _workflows.GetRevisionAsync(projectId, existing.Id, applied.RevisionNumber, cancellationToken)
                ?? throw new InvalidOperationException("The previously applied Workflow revision could not be reloaded.");
            return new WorkflowAssemblyApplyResult(details, revision, null, null, false, false, false, true,
                "This Workflow seed was already applied; no changes were made.");
        }

        string definitionJson = BuildSeedWorkflowDefinition(projectKey, seed);
        WorkflowDraftValidationResult validation = await _workflows.ValidateJsonAsync(projectId, projectKey, definitionJson, cancellationToken);
        EnsureFullyValid(validation, "Workflow seed");

        WorkflowDraftSaveResult saved = await _workflows.ImportJsonAsync(
            new ImportWorkflowDraftRequest(
                projectId,
                projectKey,
                definitionJson,
                $"Incremental JSON seed '{seed.OperationId}'.",
                writeContext,
                WorkflowDraftSourceModes.IncrementalJson),
            cancellationToken);
        AddAssemblyAudit(writeContext, saved.Draft.Id, seed, new
        {
            Operation = "CreateWorkflow",
            saved.Draft.Key,
            saved.Revision.RevisionNumber,
            saved.Revision.DefinitionSha256
        });
        await _dbContext.SaveChangesAsync(cancellationToken);

        return new WorkflowAssemblyApplyResult(
            saved.Draft,
            saved.Revision,
            null,
            null,
            true,
            false,
            true,
            false,
            "Empty Workflow created from metadata-only JSON. The current graph is START → SUCCEED.");
    }

    private async Task<WorkflowAssemblyApplyResult> ApplyAppendAsync(
        Guid projectId,
        string projectKey,
        ProjectTestDraft draft,
        ParsedActionAppend append,
        WorkflowDraftWriteContext writeContext,
        CancellationToken cancellationToken)
    {
        ProjectTestDraftRevision? applied = await FindRevisionByOperationIdAsync(draft.Id, append.OperationId, PackageSha256(append.NormalizedJson), cancellationToken);
        if (applied is not null)
        {
            WorkflowDraftDetails existingDetails = await _workflows.GetAsync(projectId, draft.Id, cancellationToken)
                ?? throw new InvalidOperationException("The existing Workflow could not be reloaded.");
            WorkflowDraftRevisionDetails existingRevision = await _workflows.GetRevisionAsync(projectId, draft.Id, applied.RevisionNumber, cancellationToken)
                ?? throw new InvalidOperationException("The previously applied Workflow revision could not be reloaded.");
            ActionLibraryDetails? existingAction = await FindActionDetailsAsync(projectId, append.Action.ActionId, cancellationToken);
            ActionVersionSummary? existingVersion = existingAction?.Versions.SingleOrDefault(version => version.VersionNumber == (append.Action.ExactVersion ?? 1));
            return new WorkflowAssemblyApplyResult(existingDetails, existingRevision, existingAction, existingVersion,
                false, false, false, true, "This Action package was already applied; no changes were made.");
        }

        WorkflowDraftRevisionDetails current = await GetCurrentRevisionAsync(projectId, draft, cancellationToken);
        var issues = new List<WorkflowDraftValidationIssue>();
        AssemblyBaseResolution provenance = await ResolveAssemblyBaseAsync(
            projectId, draft, current, append.WorkflowId, append.ExpectedRevisionNumber, append.ExpectedDefinitionSha256, issues, cancellationToken);
        string? nextNodeId = ValidateInsertionPoint(current.CanonicalDefinitionJson, append.InsertAfterNodeId, append.NewNodeId, issues);
        ValidateAppendRebasePreconditions(provenance, current, append.InsertAfterNodeId, issues);
        ThrowIfErrors(issues, "The Action package cannot be applied");

        ActionLibraryDetails actionDetails;
        ActionVersionSummary actionVersion;
        bool createdAction;
        if (append.Action.Mode == WorkflowAssemblyActionModes.Create)
        {
            ValidateCreateAction(append.Action);
            byte[] sourceBytes = ValidateInlineSource(append.Action);
            PortableCreateReuse? reusable = await FindPortableCreateReuseAsync(projectId, append.Action, cancellationToken);
            if (reusable is not null)
            {
                actionDetails = reusable.Action;
                actionVersion = reusable.Version;
                createdAction = false;
            }
            else
            {
                bool exists = await _dbContext.ProjectActions.AnyAsync(
                    item => item.ProjectId == projectId && item.Key == append.Action.ActionId,
                    cancellationToken);
                if (exists)
                    throw new InvalidOperationException($"Action '{append.Action.ActionId}' already exists, but its immutable v1 definition/source does not match this Create package. Dynomax will not overwrite it.");

                ActionSaveResult actionSave = await _actions.CreateDraftAsync(
                    append.Action.ToCreateRequest(projectId, writeContext.ActorUserId, writeContext.OccurredAtUtc),
                    cancellationToken);
                await using var sourceStream = new MemoryStream(sourceBytes, writable: false);
                await _sourcePackages.AttachAsync(
                    projectId,
                    actionSave.Version.Id,
                    append.Action.EntryPoint!,
                    sourceStream,
                    writeContext.ActorUserId,
                    writeContext.OccurredAtUtc,
                    cancellationToken);
                actionDetails = await _actions.GetAsync(actionSave.Action.Id, cancellationToken)
                    ?? throw new InvalidOperationException("The newly created Action could not be reloaded.");
                actionVersion = actionDetails.Versions.Single(version => version.Id == actionSave.Version.Id);
                createdAction = true;
            }
        }
        else
        {
            int exactVersion = append.Action.ExactVersion
                ?? throw new InvalidOperationException("UseExact requires an exact Action version.");
            ActionVersionLookup lookup = await FindExactActionVersionAsync(projectId, append.Action.ActionId, exactVersion, cancellationToken)
                ?? throw new InvalidOperationException($"Active Action '{append.Action.ActionId}' v{exactVersion} with a verified source package was not found.");
            actionDetails = await _actions.GetAsync(lookup.ActionId, cancellationToken)
                ?? throw new InvalidOperationException("The exact Action could not be reloaded.");
            actionVersion = actionDetails.Versions.Single(version => version.Id == lookup.VersionId);
            createdAction = false;
        }

        string prospective = BuildAppendedWorkflowDefinition(
            current.CanonicalDefinitionJson,
            append,
            actionVersion.VersionNumber,
            nextNodeId!,
            current.RevisionNumber,
            current.DefinitionSha256);
        WorkflowDraftValidationResult validation = await _workflows.ValidateJsonAsync(projectId, projectKey, prospective, cancellationToken);
        EnsureFullyValid(validation, "Incremental Workflow revision");

        WorkflowDraftSaveResult saved = await _workflows.SaveRevisionAsync(
            new SaveWorkflowDraftRevisionRequest(
                projectId,
                draft.Id,
                Convert.ToBase64String(draft.RowVersion),
                projectKey,
                validation.CanonicalDefinitionJson,
                WorkflowDraftSourceModes.IncrementalJson,
                $"Incremental Action package '{append.OperationId}' added node '{append.NewNodeId}' after '{append.InsertAfterNodeId}'.",
                writeContext),
            cancellationToken);

        AddAssemblyAudit(writeContext, saved.Draft.Id, append, new
        {
            Operation = "AppendAction",
            saved.Draft.Key,
            ParentRevision = current.RevisionNumber,
            Revision = saved.Revision.RevisionNumber,
            ParentSha256 = current.DefinitionSha256,
            saved.Revision.DefinitionSha256,
            append.InsertAfterNodeId,
            append.NewNodeId,
            NextNodeId = nextNodeId,
            ActionId = actionDetails.Key,
            ActionVersion = actionVersion.VersionNumber,
            CreatedAction = createdAction
        });
        await _dbContext.SaveChangesAsync(cancellationToken);

        return new WorkflowAssemblyApplyResult(
            saved.Draft,
            saved.Revision,
            actionDetails,
            actionVersion,
            false,
            createdAction,
            true,
            false,
            createdAction
                ? $"Action '{actionDetails.Key}' v{actionVersion.VersionNumber} was created and added as Workflow revision r{saved.Revision.RevisionNumber}."
                : $"Existing Action '{actionDetails.Key}' v{actionVersion.VersionNumber} was added as Workflow revision r{saved.Revision.RevisionNumber}.");
    }

    private async Task<WorkflowAssemblyApplyResult> ApplySystemNodeAppendAsync(
        Guid projectId,
        string projectKey,
        ProjectTestDraft draft,
        ParsedSystemNodeAppend append,
        WorkflowDraftWriteContext writeContext,
        CancellationToken cancellationToken)
    {
        ProjectTestDraftRevision? applied = await FindRevisionByOperationIdAsync(draft.Id, append.OperationId, PackageSha256(append.NormalizedJson), cancellationToken);
        if (applied is not null)
        {
            WorkflowDraftDetails existingDetails = await _workflows.GetAsync(projectId, draft.Id, cancellationToken)
                ?? throw new InvalidOperationException("The existing Workflow could not be reloaded.");
            WorkflowDraftRevisionDetails existingRevision = await _workflows.GetRevisionAsync(projectId, draft.Id, applied.RevisionNumber, cancellationToken)
                ?? throw new InvalidOperationException("The previously applied Workflow revision could not be reloaded.");
            return new WorkflowAssemblyApplyResult(existingDetails, existingRevision, null, null,
                false, false, false, true, "This System-node package was already applied; no changes were made.");
        }

        WorkflowDraftRevisionDetails current = await GetCurrentRevisionAsync(projectId, draft, cancellationToken);
        var issues = new List<WorkflowDraftValidationIssue>();
        AssemblyBaseResolution provenance = await ResolveAssemblyBaseAsync(
            projectId, draft, current, append.WorkflowId, append.ExpectedRevisionNumber, append.ExpectedDefinitionSha256, issues, cancellationToken);
        string? nextNodeId = ValidateInsertionPoint(current.CanonicalDefinitionJson, append.InsertAfterNodeId, append.NewNodeId, issues);
        ValidateAppendRebasePreconditions(provenance, current, append.InsertAfterNodeId, issues);
        ValidateSystemBranchTargets(current.CanonicalDefinitionJson, append, issues);
        ThrowIfErrors(issues, "The System-node package cannot be applied");

        string prospective = BuildSystemNodeAppendedWorkflowDefinition(
            current.CanonicalDefinitionJson,
            append,
            nextNodeId!,
            current.RevisionNumber,
            current.DefinitionSha256);
        WorkflowDraftValidationResult validation = await _workflows.ValidateJsonAsync(projectId, projectKey, prospective, cancellationToken);
        EnsureFullyValid(validation, "Incremental Workflow System-node revision");

        WorkflowDraftSaveResult saved = await _workflows.SaveRevisionAsync(
            new SaveWorkflowDraftRevisionRequest(
                projectId,
                draft.Id,
                Convert.ToBase64String(draft.RowVersion),
                projectKey,
                validation.CanonicalDefinitionJson,
                WorkflowDraftSourceModes.IncrementalJson,
                $"Incremental System-node package '{append.OperationId}' added Condition '{append.NewNodeId}' after '{append.InsertAfterNodeId}'.",
                writeContext),
            cancellationToken);

        AddAssemblyAudit(writeContext, saved.Draft.Id, append, new
        {
            Operation = "AppendSystemCondition",
            saved.Draft.Key,
            ParentRevision = current.RevisionNumber,
            Revision = saved.Revision.RevisionNumber,
            ParentSha256 = current.DefinitionSha256,
            saved.Revision.DefinitionSha256,
            append.InsertAfterNodeId,
            append.NewNodeId,
            ExistingNextNodeId = nextNodeId,
            append.TrueTargetNodeId,
            append.FalseTargetNodeId,
            append.Operator
        });
        await _dbContext.SaveChangesAsync(cancellationToken);

        return new WorkflowAssemblyApplyResult(
            saved.Draft,
            saved.Revision,
            null,
            null,
            false,
            false,
            true,
            false,
            $"System Condition '{append.NodeDisplayName}' was added as Workflow revision r{saved.Revision.RevisionNumber}.");
    }

    private async Task<WorkflowAssemblyApplyResult> ApplyGraphPatchAsync(
        Guid projectId,
        string projectKey,
        ProjectTestDraft draft,
        ParsedGraphPatch patch,
        WorkflowDraftWriteContext writeContext,
        CancellationToken cancellationToken)
    {
        ProjectTestDraftRevision? applied = await FindRevisionByOperationIdAsync(draft.Id, patch.OperationId, PackageSha256(patch.NormalizedJson), cancellationToken);
        if (applied is not null)
        {
            WorkflowDraftDetails existingDetails = await _workflows.GetAsync(projectId, draft.Id, cancellationToken)
                ?? throw new InvalidOperationException("The existing Workflow could not be reloaded.");
            WorkflowDraftRevisionDetails existingRevision = await _workflows.GetRevisionAsync(projectId, draft.Id, applied.RevisionNumber, cancellationToken)
                ?? throw new InvalidOperationException("The previously applied Workflow revision could not be reloaded.");
            return new WorkflowAssemblyApplyResult(existingDetails, existingRevision, null, null,
                false, false, false, true, "This Workflow graph patch was already applied; no changes were made.");
        }

        WorkflowDraftRevisionDetails current = await GetCurrentRevisionAsync(projectId, draft, cancellationToken);
        var issues = new List<WorkflowDraftValidationIssue>();
        AssemblyBaseResolution provenance = await ResolveAssemblyBaseAsync(
            projectId, draft, current, patch.WorkflowId, patch.ExpectedRevisionNumber, patch.ExpectedDefinitionSha256, issues, cancellationToken);
        ValidateGraphPatchRebasePreconditions(provenance, current, patch, issues);
        ThrowIfErrors(issues, "The Workflow graph patch cannot be applied");

        string prospective = BuildGraphPatchedWorkflowDefinition(
            current.CanonicalDefinitionJson,
            patch,
            current.RevisionNumber,
            current.DefinitionSha256);
        WorkflowDraftValidationResult validation = await _workflows.ValidateJsonAsync(projectId, projectKey, prospective, cancellationToken);
        EnsureFullyValid(validation, "Workflow graph patch");

        WorkflowDraftSaveResult saved = await _workflows.SaveRevisionAsync(
            new SaveWorkflowDraftRevisionRequest(
                projectId,
                draft.Id,
                Convert.ToBase64String(draft.RowVersion),
                projectKey,
                validation.CanonicalDefinitionJson,
                WorkflowDraftSourceModes.IncrementalJson,
                $"Atomic Workflow graph patch '{patch.OperationId}' added {patch.NodesToAdd.Count} main node(s), removed {patch.NodesToRemove.Count} main node(s), removed {patch.EdgesToRemove.Count} exact main edge(s), added {patch.EdgesToAdd.Count} main edge(s), Cleanup changed={patch.HasCleanupChanges}, metadata changed={patch.HasDisplayNameChange || patch.HasDescriptionChange}, Workflow inputs replaced={patch.WorkflowInputs is not null}, Workflow outputs replaced={patch.WorkflowOutputs is not null}.",
                writeContext),
            cancellationToken);

        AddAssemblyAudit(writeContext, saved.Draft.Id, patch, new
        {
            Operation = "ApplyWorkflowGraphPatch",
            saved.Draft.Key,
            ParentRevision = current.RevisionNumber,
            Revision = saved.Revision.RevisionNumber,
            ParentSha256 = current.DefinitionSha256,
            saved.Revision.DefinitionSha256,
            AddedNodeIds = patch.NodesToAdd.Select(node => (string?)node.Node["nodeId"]).ToArray(),
            RemovedNodeIds = patch.NodesToRemove.Select(node => node.NodeId).ToArray(),
            RemovedEdgeIds = patch.EdgesToRemove.Select(edge => edge.EdgeId).ToArray(),
            AddedEdgeIds = patch.EdgesToAdd.Select(edge => (string?)edge["edgeId"]).ToArray(),
            CleanupAddedNodeIds = patch.Cleanup?.NodesToAdd.Select(node => (string?)node.Node["nodeId"]).ToArray() ?? [],
            CleanupRemovedNodeIds = patch.Cleanup?.NodesToRemove.Select(node => node.NodeId).ToArray() ?? [],
            CleanupRemovedEdgeIds = patch.Cleanup?.EdgesToRemove.Select(edge => edge.EdgeId).ToArray() ?? [],
            CleanupAddedEdgeIds = patch.Cleanup?.EdgesToAdd.Select(edge => (string?)edge["edgeId"]).ToArray() ?? [],
            CleanupStartNodeChanged = patch.Cleanup?.HasStartNodeIdChange ?? false,
            CleanupFailurePolicyChanged = patch.Cleanup?.HasFailurePolicyChange ?? false,
            patch.HasDisplayNameChange,
            patch.HasDescriptionChange,
            WorkflowInputsReplaced = patch.WorkflowInputs is not null,
            WorkflowOutputsReplaced = patch.WorkflowOutputs is not null
        });
        await _dbContext.SaveChangesAsync(cancellationToken);

        return new WorkflowAssemblyApplyResult(saved.Draft, saved.Revision, null, null,
            false, false, true, false,
            $"Workflow graph patch was applied atomically as Workflow revision r{saved.Revision.RevisionNumber}.");
    }

    private async Task<ProjectTestDraft?> ResolveTargetDraftAsync(
        Guid projectId,
        Guid? targetWorkflowDraftId,
        string originWorkflowId,
        bool tracking,
        CancellationToken cancellationToken)
    {
        IQueryable<ProjectTestDraft> query = tracking
            ? _dbContext.ProjectTestDrafts
            : _dbContext.ProjectTestDrafts.AsNoTracking();
        query = query.Where(item => item.ProjectId == projectId && item.Status == WorkflowDraftStatuses.Active);
        return targetWorkflowDraftId.HasValue
            ? await query.SingleOrDefaultAsync(item => item.Id == targetWorkflowDraftId.Value, cancellationToken)
            : await query.SingleOrDefaultAsync(item => item.Key == originWorkflowId, cancellationToken);
    }

    private static ProjectTestDraft RequireTargetDraft(ProjectTestDraft? draft, string originWorkflowId) =>
        draft ?? throw new InvalidOperationException(
            $"The target Workflow was not found in the selected Workspace. The agent JSON records '{originWorkflowId}' as its source Workflow.");

    private async Task<WorkflowDraftRevisionDetails> GetCurrentRevisionAsync(
        Guid projectId,
        ProjectTestDraft draft,
        CancellationToken cancellationToken)
    {
        if (draft.CurrentRevisionNumber < 1)
            throw new InvalidOperationException("The active Workflow has no current immutable revision.");
        return await _workflows.GetRevisionAsync(projectId, draft.Id, draft.CurrentRevisionNumber, cancellationToken)
            ?? throw new InvalidOperationException("The current Workflow revision could not be loaded.");
    }

    private async Task<ProjectTestDraftRevision?> FindRevisionByOperationIdAsync(
        Guid draftId,
        string operationId,
        string packageSha256,
        CancellationToken cancellationToken)
    {
        ProjectTestDraftRevision[] revisions = await _dbContext.ProjectTestDraftRevisions.AsNoTracking()
            .Where(item => item.ProjectTestDraftId == draftId)
            .OrderBy(item => item.RevisionNumber)
            .ToArrayAsync(cancellationToken);
        ProjectTestDraftRevision? revision = revisions.FirstOrDefault(item => HasIncrementalOperation(item.CanonicalDefinitionJson, operationId));
        if (revision is null) return null;

        string? storedPackageSha256 = ReadIncrementalPackageSha256(revision.CanonicalDefinitionJson);
        if (!string.Equals(storedPackageSha256, packageSha256, StringComparison.Ordinal))
        {
            throw new InvalidOperationException(
                $"Operation ID '{operationId}' was already used by a different Workflow assembly package. Use a new operationId for a different change.");
        }
        return revision;
    }

    private static bool HasIncrementalOperation(string canonicalDefinitionJson, string operationId)
    {
        using JsonDocument document = JsonDocument.Parse(canonicalDefinitionJson);
        return document.RootElement.TryGetProperty("source", out JsonElement source) &&
            source.ValueKind == JsonValueKind.Object &&
            source.TryGetProperty("incrementalImportId", out JsonElement value) &&
            value.ValueKind == JsonValueKind.String &&
            string.Equals(value.GetString(), operationId, StringComparison.Ordinal);
    }

    private static string? ReadIncrementalPackageSha256(string canonicalDefinitionJson)
    {
        using JsonDocument document = JsonDocument.Parse(canonicalDefinitionJson);
        return document.RootElement.TryGetProperty("source", out JsonElement source) &&
            source.ValueKind == JsonValueKind.Object &&
            source.TryGetProperty("incrementalPackageSha256", out JsonElement value) &&
            value.ValueKind == JsonValueKind.String
                ? value.GetString()
                : null;
    }

    private static string PackageSha256(string normalizedPackageJson) =>
        Convert.ToHexString(SHA256.HashData(Encoding.UTF8.GetBytes(normalizedPackageJson))).ToLowerInvariant();

    private async Task<ActionVersionLookup?> FindExactActionVersionAsync(
        Guid projectId,
        string actionKey,
        int versionNumber,
        CancellationToken cancellationToken) =>
        await (
            from action in _dbContext.ProjectActions.AsNoTracking()
            join version in _dbContext.ProjectActionVersions.AsNoTracking()
                on action.Id equals version.ProjectActionId
            join source in _dbContext.ProjectActionSourcePackages.AsNoTracking()
                on version.Id equals source.ProjectActionVersionId
            where action.ProjectId == projectId &&
                  action.Key == actionKey &&
                  action.IsActive &&
                  version.VersionNumber == versionNumber &&
                  source.VerificationStatus == ActionSourcePackageVerificationStatuses.Verified
            select new ActionVersionLookup(action.Id, version.Id, version.VersionNumber))
        .SingleOrDefaultAsync(cancellationToken);

    private async Task<ActionLibraryDetails?> FindActionDetailsAsync(
        Guid projectId,
        string actionKey,
        CancellationToken cancellationToken)
    {
        Guid? actionId = await _dbContext.ProjectActions.AsNoTracking()
            .Where(item => item.ProjectId == projectId && item.Key == actionKey)
            .Select(item => (Guid?)item.Id)
            .SingleOrDefaultAsync(cancellationToken);
        return actionId.HasValue ? await _actions.GetAsync(actionId.Value, cancellationToken) : null;
    }

    private async Task<AssemblyBaseResolution> ResolveAssemblyBaseAsync(
        Guid projectId,
        ProjectTestDraft targetDraft,
        WorkflowDraftRevisionDetails current,
        string originWorkflowId,
        int expectedRevisionNumber,
        string expectedDefinitionSha256,
        ICollection<WorkflowDraftValidationIssue> issues,
        CancellationToken cancellationToken)
    {
        bool sameWorkflow = string.Equals(targetDraft.Key, originWorkflowId, StringComparison.Ordinal);
        bool exactCurrent = sameWorkflow &&
            current.RevisionNumber == expectedRevisionNumber &&
            string.Equals(current.DefinitionSha256, expectedDefinitionSha256, StringComparison.OrdinalIgnoreCase);
        if (exactCurrent)
            return new AssemblyBaseResolution(current, true, false, targetDraft.Key, originWorkflowId);

        ProjectTestDraft? originDraft = await _dbContext.ProjectTestDrafts.AsNoTracking()
            .SingleOrDefaultAsync(item => item.ProjectId == projectId && item.Key == originWorkflowId, cancellationToken);
        if (originDraft is null)
        {
            issues.Add(Error(
                "WF-ASSEMBLY-BASE-WORKFLOW-MISSING",
                "$.workflowId",
                $"The agent JSON records Workflow '{originWorkflowId}' as its source, but that source Workflow is no longer available to verify a safe rebase. Generate a fresh package from the target Workflow."));
            return new AssemblyBaseResolution(null, false, !sameWorkflow, targetDraft.Key, originWorkflowId);
        }

        WorkflowDraftRevisionDetails? originRevision = await _workflows.GetRevisionAsync(
            projectId,
            originDraft.Id,
            expectedRevisionNumber,
            cancellationToken);
        if (originRevision is null)
        {
            issues.Add(Error(
                "WF-ASSEMBLY-STALE-REVISION",
                "$.expectedWorkflowRevision",
                $"Source Workflow '{originWorkflowId}' does not contain immutable revision r{expectedRevisionNumber}. The package provenance cannot be verified."));
            return new AssemblyBaseResolution(null, false, originDraft.Id != targetDraft.Id, targetDraft.Key, originWorkflowId);
        }
        if (!string.Equals(originRevision.DefinitionSha256, expectedDefinitionSha256, StringComparison.OrdinalIgnoreCase))
        {
            issues.Add(Error(
                "WF-ASSEMBLY-STALE-HASH",
                "$.expectedWorkflowSha256",
                $"Source Workflow '{originWorkflowId}' r{expectedRevisionNumber} does not match the SHA-256 recorded in the agent JSON. The package provenance cannot be verified."));
            return new AssemblyBaseResolution(null, false, originDraft.Id != targetDraft.Id, targetDraft.Key, originWorkflowId);
        }

        return new AssemblyBaseResolution(
            originRevision,
            false,
            originDraft.Id != targetDraft.Id,
            targetDraft.Key,
            originWorkflowId);
    }

    private static void ValidateAppendRebasePreconditions(
        AssemblyBaseResolution provenance,
        WorkflowDraftRevisionDetails current,
        string insertAfterNodeId,
        ICollection<WorkflowDraftValidationIssue> issues)
    {
        if (provenance.BaseRevision is null || provenance.ExactTargetMatch) return;

        SuccessConnection? source = ReadSingleSuccessConnection(provenance.BaseRevision.CanonicalDefinitionJson, insertAfterNodeId);
        SuccessConnection? target = ReadSingleSuccessConnection(current.CanonicalDefinitionJson, insertAfterNodeId);
        if (source is null)
        {
            issues.Add(Error(
                "WF-ASSEMBLY-BASE-PRECONDITION",
                "$.insertAfterNodeId",
                $"The source revision does not have one unambiguous Success connection after '{insertAfterNodeId}', so this older package cannot be safely rebased."));
            return;
        }
        if (target is null || !source.SemanticallyEquals(target))
        {
            issues.Add(Error(
                "WF-ASSEMBLY-REBASE-CONFLICT",
                "$.insertAfterNodeId",
                $"The connection after '{insertAfterNodeId}' changed since the agent JSON was generated. Dynomax will not guess where the imported node belongs."));
            return;
        }

        AddSafeRebaseInfo(provenance, current, issues);
    }

    private static void ValidateGraphPatchRebasePreconditions(
        AssemblyBaseResolution provenance,
        WorkflowDraftRevisionDetails current,
        ParsedGraphPatch patch,
        ICollection<WorkflowDraftValidationIssue> issues)
    {
        if (provenance.BaseRevision is null || provenance.ExactTargetMatch) return;

        if (patch.HasDefinitionContractChanges || patch.HasCleanupChanges)
        {
            string code = patch.HasCleanupChanges
                ? "WF-ASSEMBLY-CLEANUP-PATCH-STALE"
                : "WF-ASSEMBLY-CONTRACT-PATCH-STALE";
            string message = patch.HasCleanupChanges
                ? "This GraphPatch changes the Cleanup graph and must target the exact current immutable revision. Generate a fresh Workflow Pack before applying the Cleanup change."
                : "This GraphPatch changes Workflow metadata or input/output contracts and must target the exact current immutable revision. Generate a fresh Workflow Pack before applying the contract change.";
            issues.Add(Error(code, "$.patch", message));
            return;
        }

        try
        {
            _ = BuildGraphPatchedWorkflowDefinition(
                provenance.BaseRevision.CanonicalDefinitionJson,
                patch,
                provenance.BaseRevision.RevisionNumber,
                provenance.BaseRevision.DefinitionSha256);
        }
        catch (InvalidOperationException exception)
        {
            issues.Add(Error(
                "WF-ASSEMBLY-BASE-PRECONDITION",
                "$.patch",
                $"The graph patch does not match its recorded source revision: {exception.Message}"));
            return;
        }

        if (IsFullGraphReplacement(provenance.BaseRevision.CanonicalDefinitionJson, patch) &&
            !GraphSemanticsEqual(provenance.BaseRevision.CanonicalDefinitionJson, current.CanonicalDefinitionJson))
        {
            issues.Add(Error(
                "WF-ASSEMBLY-FULL-REPLACEMENT-CONFLICT",
                "$.patch",
                "This package replaces the complete mutable main graph, but the target graph has diverged from the recorded source revision. Generate a fresh package or use a localized patch so target-specific changes are not overwritten."));
            return;
        }

        if (!ExactTouchedGraphPreconditionsMatch(
                provenance.BaseRevision.CanonicalDefinitionJson,
                current.CanonicalDefinitionJson,
                patch,
                out string? touchedConflict))
        {
            issues.Add(Error(
                "WF-ASSEMBLY-REBASE-CONFLICT",
                "$.patch",
                touchedConflict ?? "A graph element touched by this package changed after the package was generated."));
            return;
        }

        AddSafeRebaseInfo(provenance, current, issues);
    }

    private static bool ExactTouchedGraphPreconditionsMatch(
        string baseDefinitionJson,
        string targetDefinitionJson,
        ParsedGraphPatch patch,
        out string? conflictMessage)
    {
        using JsonDocument sourceDocument = JsonDocument.Parse(baseDefinitionJson);
        using JsonDocument targetDocument = JsonDocument.Parse(targetDefinitionJson);
        Dictionary<string, string> sourceNodes = sourceDocument.RootElement.GetProperty("nodes").EnumerateArray()
            .Where(node => node.TryGetProperty("nodeId", out JsonElement id) && id.ValueKind == JsonValueKind.String)
            .ToDictionary(node => node.GetProperty("nodeId").GetString()!, node => WorkflowDraftCanonicalJson.Canonicalize(node.GetRawText()), StringComparer.Ordinal);
        Dictionary<string, string> targetNodes = targetDocument.RootElement.GetProperty("nodes").EnumerateArray()
            .Where(node => node.TryGetProperty("nodeId", out JsonElement id) && id.ValueKind == JsonValueKind.String)
            .ToDictionary(node => node.GetProperty("nodeId").GetString()!, node => WorkflowDraftCanonicalJson.Canonicalize(node.GetRawText()), StringComparer.Ordinal);
        foreach (ParsedNodeRemoval removal in patch.NodesToRemove)
        {
            if (!sourceNodes.TryGetValue(removal.NodeId, out string? sourceNode) ||
                !targetNodes.TryGetValue(removal.NodeId, out string? targetNode) ||
                !string.Equals(sourceNode, targetNode, StringComparison.Ordinal))
            {
                conflictMessage = $"Node '{removal.NodeId}' changed since the agent JSON was generated. Because this package removes or replaces that node, Dynomax will not overwrite the target's newer node definition.";
                return false;
            }
        }

        Dictionary<string, string> sourceEdges = sourceDocument.RootElement.GetProperty("edges").EnumerateArray()
            .Where(edge => edge.TryGetProperty("edgeId", out JsonElement id) && id.ValueKind == JsonValueKind.String)
            .ToDictionary(edge => edge.GetProperty("edgeId").GetString()!, edge => WorkflowDraftCanonicalJson.Canonicalize(edge.GetRawText()), StringComparer.Ordinal);
        Dictionary<string, string> targetEdges = targetDocument.RootElement.GetProperty("edges").EnumerateArray()
            .Where(edge => edge.TryGetProperty("edgeId", out JsonElement id) && id.ValueKind == JsonValueKind.String)
            .ToDictionary(edge => edge.GetProperty("edgeId").GetString()!, edge => WorkflowDraftCanonicalJson.Canonicalize(edge.GetRawText()), StringComparer.Ordinal);
        foreach (ParsedEdgeRemoval removal in patch.EdgesToRemove)
        {
            if (!sourceEdges.TryGetValue(removal.EdgeId, out string? sourceEdge) ||
                !targetEdges.TryGetValue(removal.EdgeId, out string? targetEdge) ||
                !string.Equals(sourceEdge, targetEdge, StringComparison.Ordinal))
            {
                conflictMessage = $"Connection '{removal.EdgeId}' changed since the agent JSON was generated. Because this package removes or replaces that connection, Dynomax will not overwrite the target's newer edge definition.";
                return false;
            }
        }

        conflictMessage = null;
        return true;
    }

    private static void AddSafeRebaseInfo(
        AssemblyBaseResolution provenance,
        WorkflowDraftRevisionDetails current,
        ICollection<WorkflowDraftValidationIssue> issues)
    {
        string message = provenance.IsCrossWorkflow
            ? $"Portable import: this package originated from Workflow '{provenance.OriginWorkflowId}' r{provenance.BaseRevision!.RevisionNumber}. Its touched graph preconditions still match target Workflow '{provenance.TargetWorkflowId}' r{current.RevisionNumber}, so Dynomax can apply it safely as one new target revision."
            : $"Safe rebase: this package originated from r{provenance.BaseRevision!.RevisionNumber}. Its touched graph preconditions are unchanged in current r{current.RevisionNumber}, so Dynomax can apply it without regenerating the package.";
        issues.Add(Info(
            provenance.IsCrossWorkflow ? "WF-ASSEMBLY-PORTABLE-IMPORT" : "WF-ASSEMBLY-SAFE-REBASE",
            "$",
            message));
    }

    private static SuccessConnection? ReadSingleSuccessConnection(string canonicalDefinitionJson, string nodeId)
    {
        using JsonDocument document = JsonDocument.Parse(canonicalDefinitionJson);
        JsonElement[] matches = document.RootElement.GetProperty("edges").EnumerateArray()
            .Where(edge =>
                string.Equals(edge.GetProperty("fromNodeId").GetString(), nodeId, StringComparison.Ordinal) &&
                string.Equals(edge.GetProperty("when").GetString(), WorkflowEdgeConditions.Success, StringComparison.Ordinal) &&
                (!edge.TryGetProperty("condition", out JsonElement condition) || condition.ValueKind == JsonValueKind.Null ||
                 (condition.ValueKind == JsonValueKind.String && string.IsNullOrWhiteSpace(condition.GetString()))))
            .ToArray();
        if (matches.Length != 1) return null;
        JsonElement edge = matches[0];
        return new SuccessConnection(
            edge.GetProperty("edgeId").GetString() ?? string.Empty,
            edge.GetProperty("toNodeId").GetString() ?? string.Empty,
            edge.TryGetProperty("priority", out JsonElement priority) && priority.ValueKind == JsonValueKind.Number ? priority.GetInt32() : 0,
            edge.TryGetProperty("label", out JsonElement label) && label.ValueKind == JsonValueKind.String ? label.GetString() : null);
    }

    private static bool IsFullGraphReplacement(string baseDefinitionJson, ParsedGraphPatch patch)
    {
        using JsonDocument document = JsonDocument.Parse(baseDefinitionJson);
        HashSet<string> mutableNodes = document.RootElement.GetProperty("nodes").EnumerateArray()
            .Where(node =>
            {
                string? type = node.GetProperty("type").GetString();
                return !string.Equals(type, WorkflowNodeTypes.Start, StringComparison.Ordinal) &&
                       !string.Equals(type, WorkflowNodeTypes.Succeed, StringComparison.Ordinal) &&
                       !string.Equals(type, WorkflowNodeTypes.Fail, StringComparison.Ordinal);
            })
            .Select(node => node.GetProperty("nodeId").GetString() ?? string.Empty)
            .Where(nodeId => nodeId.Length > 0)
            .ToHashSet(StringComparer.Ordinal);
        HashSet<string> removedNodes = patch.NodesToRemove.Select(node => node.NodeId).ToHashSet(StringComparer.Ordinal);
        if (!mutableNodes.IsSubsetOf(removedNodes)) return false;

        HashSet<string> baseEdges = document.RootElement.GetProperty("edges").EnumerateArray()
            .Select(edge => edge.GetProperty("edgeId").GetString() ?? string.Empty)
            .Where(edgeId => edgeId.Length > 0)
            .ToHashSet(StringComparer.Ordinal);
        HashSet<string> removedEdges = patch.EdgesToRemove.Select(edge => edge.EdgeId).ToHashSet(StringComparer.Ordinal);
        return baseEdges.SetEquals(removedEdges);
    }

    private static bool GraphSemanticsEqual(string leftDefinitionJson, string rightDefinitionJson) =>
        string.Equals(GraphSemanticFingerprint(leftDefinitionJson), GraphSemanticFingerprint(rightDefinitionJson), StringComparison.Ordinal);

    private static string GraphSemanticFingerprint(string canonicalDefinitionJson)
    {
        JsonObject root = JsonNode.Parse(canonicalDefinitionJson)?.AsObject()
            ?? throw new InvalidOperationException("Workflow definition is invalid.");
        JsonObject graph = new()
        {
            ["startNodeId"] = root["startNodeId"]?.DeepClone(),
            ["defaults"] = root["defaults"]?.DeepClone(),
            ["nodes"] = root["nodes"]?.DeepClone(),
            ["edges"] = root["edges"]?.DeepClone(),
            ["cleanup"] = root["cleanup"]?.DeepClone()
        };
        return WorkflowDraftCanonicalJson.Canonicalize(graph.ToJsonString());
    }

    private static string? ValidateInsertionPoint(
        string currentDefinitionJson,
        string insertAfterNodeId,
        string newNodeId,
        ICollection<WorkflowDraftValidationIssue> issues)
    {
        using JsonDocument document = JsonDocument.Parse(currentDefinitionJson);
        JsonElement root = document.RootElement;
        JsonElement[] nodes = root.GetProperty("nodes").EnumerateArray().ToArray();
        if (nodes.Any(node => string.Equals(node.GetProperty("nodeId").GetString(), newNodeId, StringComparison.Ordinal)))
        {
            issues.Add(Error("WF-ASSEMBLY-NODE-EXISTS", "$.newNodeId", $"Node '{newNodeId}' already exists in the current Workflow revision."));
            return null;
        }
        if (!nodes.Any(node => string.Equals(node.GetProperty("nodeId").GetString(), insertAfterNodeId, StringComparison.Ordinal)))
        {
            issues.Add(Error("WF-ASSEMBLY-ANCHOR-MISSING", "$.insertAfterNodeId", $"Existing node '{insertAfterNodeId}' was not found in the current Workflow revision."));
            return null;
        }

        JsonElement[] outgoing = root.GetProperty("edges").EnumerateArray()
            .Where(edge =>
                string.Equals(edge.GetProperty("fromNodeId").GetString(), insertAfterNodeId, StringComparison.Ordinal) &&
                string.Equals(edge.GetProperty("when").GetString(), WorkflowEdgeConditions.Success, StringComparison.Ordinal) &&
                (!edge.TryGetProperty("condition", out JsonElement condition) || condition.ValueKind == JsonValueKind.Null ||
                 (condition.ValueKind == JsonValueKind.String && string.IsNullOrWhiteSpace(condition.GetString()))))
            .ToArray();
        if (outgoing.Length != 1)
        {
            issues.Add(Error("WF-ASSEMBLY-ANCHOR-AMBIGUOUS", "$.insertAfterNodeId",
                $"Node '{insertAfterNodeId}' must have exactly one unconditional Success connection before a single node can be inserted safely."));
            return null;
        }
        return outgoing[0].GetProperty("toNodeId").GetString();
    }

    private async Task<PortableCreateReuse?> FindPortableCreateReuseAsync(
        Guid projectId,
        ParsedAction action,
        CancellationToken cancellationToken)
    {
        ActionLibraryDetails? existing = await FindActionDetailsAsync(projectId, action.ActionId, cancellationToken);
        if (existing is null) return null;
        ActionVersionSummary? version = existing.Versions.SingleOrDefault(item => item.VersionNumber == 1);
        if (version is null || version.SourcePackage is null ||
            !string.Equals(version.SourcePackage.VerificationStatus, ActionSourcePackageVerificationStatuses.Verified, StringComparison.Ordinal))
            return null;

        CreateActionDraftRequest request = action.ToCreateRequest(projectId, Guid.NewGuid(), DateTime.UnixEpoch);
        ActionExecutionPolicyContract executionPolicy = ActionExecutionPolicyRules.ValidateContract(
            request.ExecutionPolicy,
            request.IsReplaySafe,
            request.Inputs.Any(input =>
                input.IsSecret ||
                string.Equals(input.Classification, ActionInputClassifications.Secret, StringComparison.Ordinal) ||
                string.Equals(input.Classification, ActionInputClassifications.Sensitive, StringComparison.Ordinal)),
            request.Engine,
            request.SessionBehavior);
        string canonical = ActionLibraryService.BuildPortalDraftCanonicalJson(
            request,
            ProjectAction.NormalizeKey(request.Key),
            executionPolicy);
        string definitionSha256 = Convert.ToHexString(SHA256.HashData(Encoding.UTF8.GetBytes(canonical))).ToLowerInvariant();
        string implementationSha256 = Convert.ToHexString(SHA256.HashData(Encoding.UTF8.GetBytes(action.SourceText!))).ToLowerInvariant();
        if (!string.Equals(version.DefinitionSha256, definitionSha256, StringComparison.OrdinalIgnoreCase) ||
            !string.Equals(version.ImplementationSha256, implementationSha256, StringComparison.OrdinalIgnoreCase))
            return null;

        return new PortableCreateReuse(existing, version);
    }

    private static void ValidateSystemBranchTargets(
        string currentDefinitionJson,
        ParsedSystemNodeAppend append,
        ICollection<WorkflowDraftValidationIssue> issues)
    {
        using JsonDocument document = JsonDocument.Parse(currentDefinitionJson);
        JsonElement root = document.RootElement;
        string startNodeId = root.GetProperty("startNodeId").GetString() ?? string.Empty;
        HashSet<string> nodeIds = root.GetProperty("nodes").EnumerateArray()
            .Select(node => node.GetProperty("nodeId").GetString() ?? string.Empty)
            .Where(nodeId => nodeId.Length > 0)
            .ToHashSet(StringComparer.Ordinal);

        foreach ((string path, string nodeId) in new[]
        {
            ("$.branches.trueTargetNodeId", append.TrueTargetNodeId),
            ("$.branches.falseTargetNodeId", append.FalseTargetNodeId)
        })
        {
            if (!nodeIds.Contains(nodeId))
                issues.Add(Error("WF-ASSEMBLY-BRANCH-TARGET-MISSING", path, $"Branch target node '{nodeId}' does not exist in the current Workflow revision."));
            else if (string.Equals(nodeId, startNodeId, StringComparison.Ordinal))
                issues.Add(Error("WF-ASSEMBLY-BRANCH-TARGET-START", path, "A Condition branch cannot target the Workflow Start node."));
            if (string.Equals(nodeId, append.NewNodeId, StringComparison.Ordinal))
                issues.Add(Error("WF-ASSEMBLY-BRANCH-TARGET-SELF", path, "A Condition branch cannot target itself."));
        }
    }

    private static void ValidateCreateAction(ParsedAction action)
    {
        CreateActionDraftRequest request = action.ToCreateRequest(Guid.NewGuid(), Guid.NewGuid(), DateTime.UtcNow);
        ActionExecutionPolicyContract normalized = ActionExecutionPolicyRules.ValidateContract(
            request.ExecutionPolicy,
            request.IsReplaySafe,
            request.Inputs.Any(input =>
                input.IsSecret ||
                string.Equals(input.Classification, ActionInputClassifications.Secret, StringComparison.Ordinal) ||
                string.Equals(input.Classification, ActionInputClassifications.Sensitive, StringComparison.Ordinal)),
            request.Engine,
            request.SessionBehavior);
        _ = normalized;

        Guid versionId = Guid.NewGuid();
        foreach (ActionValueDefinitionInput input in request.Inputs)
        {
            _ = new ProjectActionInputDefinition(
                versionId,
                input.Name,
                input.DisplayName ?? input.Name,
                input.DataType,
                input.Format,
                input.IsRequired,
                input.IsSecret,
                input.Classification ?? (input.IsSecret ? ActionInputClassifications.Secret : ActionInputClassifications.Normal),
                input.DefaultValueJson,
                input.AllowedBindingKindsJson ?? (input.IsSecret ? "[\"SecretReference\"]" : "[\"Literal\",\"WorkflowInput\",\"WorkflowDefault\",\"ProjectVariable\",\"NodeOutput\",\"RuntimeValue\"]"),
                input.ValidationJson ?? "{}",
                input.UiHintsJson ?? "{}",
                input.UiGroup ?? "General",
                input.UiOrder,
                input.IsAdvanced,
                input.Description);
        }
        foreach (ActionValueDefinitionInput output in request.Outputs)
        {
            _ = new ProjectActionOutputDefinition(
                versionId,
                output.Name,
                output.DisplayName ?? output.Name,
                output.DataType,
                output.Format,
                output.IsRequired,
                output.Classification ?? ActionOutputClassifications.Normal,
                output.PersistInResult,
                output.UiHintsJson ?? "{}",
                output.UiGroup ?? "Outputs",
                output.UiOrder,
                output.IsAdvanced,
                output.Description);
        }
        foreach (ActionDependencyInput dependency in request.Dependencies)
            _ = new ProjectActionDependency(versionId, dependency.ActionKey, dependency.Kind, dependency.IsRequired, dependency.Description);
    }

    private byte[] ValidateInlineSource(ParsedAction action)
    {
        if (action.Mode != WorkflowAssemblyActionModes.Create)
            return [];
        if (string.IsNullOrWhiteSpace(action.EntryPoint))
            throw new InvalidOperationException("Create mode requires action.entryPoint.");
        if (string.IsNullOrWhiteSpace(action.SourceText))
            throw new InvalidOperationException("Create mode requires non-empty action.sourceText.");
        string canonicalEntryPoint = action.EntryPoint.Replace('\\', '/').Trim('/');
        if (!string.Equals(canonicalEntryPoint, action.EntryPoint, StringComparison.Ordinal) ||
            canonicalEntryPoint.Contains("..", StringComparison.Ordinal) ||
            Path.IsPathRooted(canonicalEntryPoint))
            throw new InvalidOperationException("action.entryPoint must be a canonical relative path using '/' separators.");
        byte[] bytes = new UTF8Encoding(false, true).GetBytes(action.SourceText);
        if (bytes.Length == 0 || bytes.Length > MaximumSourceBytes)
            throw new InvalidOperationException($"action.sourceText must be between 1 byte and {MaximumSourceBytes} bytes.");
        if (action.SourceText.IndexOf('\0') >= 0)
            throw new InvalidOperationException("action.sourceText contains a NUL character.");

        _sourcePackages.ValidateDirectSource(
            action.Engine!,
            action.EntryPoint,
            action.EntryPoint,
            bytes);
        return bytes;
    }

    private static string BuildSeedWorkflowDefinition(string projectKey, ParsedWorkflowSeed seed)
    {
        JsonObject root = BaseWorkflowDefinition(
            projectKey,
            seed.WorkflowId,
            seed.DisplayName,
            seed.Description,
            seed.EnvironmentKey,
            seed.OperationId,
            PackageSha256(seed.NormalizedJson),
            null,
            null);
        return WorkflowDraftCanonicalJson.Canonicalize(root.ToJsonString());
    }

    private static JsonObject BaseWorkflowDefinition(
        string projectKey,
        string workflowId,
        string displayName,
        string? description,
        string? environmentKey,
        string operationId,
        string packageSha256,
        int? parentRevisionNumber,
        string? parentDefinitionSha256) => new()
    {
        ["schemaVersion"] = 2,
        ["definitionType"] = "Dynomax.WorkflowDraft",
        ["workflowId"] = workflowId,
        ["projectKey"] = projectKey,
        ["displayName"] = displayName,
        ["description"] = description,
        ["environmentKey"] = environmentKey,
        ["workflowInputs"] = new JsonArray(),
        ["workflowOutputs"] = new JsonArray(),
        ["defaults"] = new JsonObject
        {
            ["timeoutSeconds"] = 300,
            ["sessionAlias"] = "default",
            ["bindings"] = new JsonObject()
        },
        ["startNodeId"] = "start",
        ["nodes"] = new JsonArray
        {
            new JsonObject { ["nodeId"] = "start", ["type"] = "Start", ["displayName"] = "Start" },
            new JsonObject { ["nodeId"] = "complete", ["type"] = "Succeed", ["displayName"] = "Complete" }
        },
        ["edges"] = new JsonArray
        {
            new JsonObject
            {
                ["edgeId"] = "start.complete",
                ["fromNodeId"] = "start",
                ["toNodeId"] = "complete",
                ["when"] = "Success",
                ["priority"] = 0
            }
        },
        ["cleanup"] = new JsonObject
        {
            ["startNodeId"] = null,
            ["nodes"] = new JsonArray(),
            ["edges"] = new JsonArray(),
            ["failurePolicy"] = "ContinueCleanup"
        },
        ["policies"] = new JsonObject
        {
            ["maximumDurationSeconds"] = 300,
            ["maximumNodeAttempts"] = 2,
            ["allowedOriginKeys"] = new JsonArray(),
            ["requireCleanupForSideEffects"] = true,
            ["failOnUnexpectedConsoleErrors"] = false
        },
        ["source"] = BuildSourceMetadata(operationId, packageSha256, parentRevisionNumber, parentDefinitionSha256),
        ["ui"] = new JsonObject
        {
            ["viewport"] = new JsonObject { ["x"] = 0, ["y"] = 0, ["zoom"] = 1 },
            ["nodes"] = new JsonObject
            {
                ["start"] = new JsonObject { ["x"] = 0, ["y"] = 0, ["collapsed"] = false, ["lane"] = "main" },
                ["complete"] = new JsonObject { ["x"] = 300, ["y"] = 0, ["collapsed"] = false, ["lane"] = "main" }
            }
        }
    };

    private static JsonObject BuildSourceMetadata(
        string operationId,
        string packageSha256,
        int? parentRevisionNumber,
        string? parentDefinitionSha256)
    {
        JsonObject source = new()
        {
            ["authoringMode"] = WorkflowDraftSourceModes.IncrementalJson,
            ["incrementalImportId"] = operationId,
            ["incrementalPackageSha256"] = packageSha256
        };
        if (parentRevisionNumber.HasValue) source["parentRevisionNumber"] = parentRevisionNumber.Value;
        if (!string.IsNullOrWhiteSpace(parentDefinitionSha256)) source["parentDefinitionSha256"] = parentDefinitionSha256;
        return source;
    }

    private static string BuildAppendedWorkflowDefinition(
        string currentDefinitionJson,
        ParsedActionAppend append,
        int actionVersion,
        string nextNodeId,
        int parentRevisionNumber,
        string parentDefinitionSha256)
    {
        JsonObject root = JsonNode.Parse(currentDefinitionJson)?.AsObject()
            ?? throw new InvalidOperationException("The current Workflow definition is invalid.");
        JsonArray nodes = root["nodes"]?.AsArray()
            ?? throw new InvalidOperationException("The current Workflow has no nodes array.");
        JsonArray edges = root["edges"]?.AsArray()
            ?? throw new InvalidOperationException("The current Workflow has no edges array.");

        JsonObject oldEdge = edges.OfType<JsonObject>().Single(edge =>
            string.Equals((string?)edge["fromNodeId"], append.InsertAfterNodeId, StringComparison.Ordinal) &&
            string.Equals((string?)edge["toNodeId"], nextNodeId, StringComparison.Ordinal) &&
            string.Equals((string?)edge["when"], WorkflowEdgeConditions.Success, StringComparison.Ordinal));
        edges.Remove(oldEdge);

        JsonObject newNode = new()
        {
            ["nodeId"] = append.NewNodeId,
            ["type"] = WorkflowNodeTypes.Action,
            ["displayName"] = append.NodeDisplayName,
            ["description"] = append.NodeDescription,
            ["actionRef"] = new JsonObject
            {
                ["actionId"] = append.Action.ActionId,
                ["versionPolicy"] = WorkflowActionVersionPolicies.Exact,
                ["version"] = actionVersion
            },
            ["inputs"] = append.NodeInputs.DeepClone(),
            ["continuePolicy"] = "FailWorkflow",
            ["disabled"] = false
        };
        if (append.NodeExecutionPolicy is not null)
            newNode["executionPolicy"] = append.NodeExecutionPolicy.DeepClone();
        nodes.Add(newNode);

        int priority = oldEdge["priority"]?.GetValue<int>() ?? 0;
        edges.Add(new JsonObject
        {
            ["edgeId"] = UniqueEdgeId(edges, $"{append.InsertAfterNodeId}.{append.NewNodeId}"),
            ["fromNodeId"] = append.InsertAfterNodeId,
            ["toNodeId"] = append.NewNodeId,
            ["when"] = WorkflowEdgeConditions.Success,
            ["priority"] = priority
        });
        edges.Add(new JsonObject
        {
            ["edgeId"] = UniqueEdgeId(edges, $"{append.NewNodeId}.{nextNodeId}"),
            ["fromNodeId"] = append.NewNodeId,
            ["toNodeId"] = nextNodeId,
            ["when"] = WorkflowEdgeConditions.Success,
            ["priority"] = priority
        });

        root["source"] = BuildSourceMetadata(
            append.OperationId,
            PackageSha256(append.NormalizedJson),
            parentRevisionNumber,
            parentDefinitionSha256);
        PositionNewNode(root, append.InsertAfterNodeId, append.NewNodeId);
        return WorkflowDraftCanonicalJson.Canonicalize(root.ToJsonString());
    }

    private static string BuildSystemNodeAppendedWorkflowDefinition(
        string currentDefinitionJson,
        ParsedSystemNodeAppend append,
        string nextNodeId,
        int parentRevisionNumber,
        string parentDefinitionSha256)
    {
        JsonObject root = JsonNode.Parse(currentDefinitionJson)?.AsObject()
            ?? throw new InvalidOperationException("The current Workflow definition is invalid.");
        JsonArray nodes = root["nodes"]?.AsArray()
            ?? throw new InvalidOperationException("The current Workflow has no nodes array.");
        JsonArray edges = root["edges"]?.AsArray()
            ?? throw new InvalidOperationException("The current Workflow has no edges array.");

        JsonObject oldEdge = edges.OfType<JsonObject>().Single(edge =>
            string.Equals((string?)edge["fromNodeId"], append.InsertAfterNodeId, StringComparison.Ordinal) &&
            string.Equals((string?)edge["toNodeId"], nextNodeId, StringComparison.Ordinal) &&
            string.Equals((string?)edge["when"], WorkflowEdgeConditions.Success, StringComparison.Ordinal));
        int priority = oldEdge["priority"]?.GetValue<int>() ?? 0;
        edges.Remove(oldEdge);

        JsonObject condition = new()
        {
            ["nodeId"] = append.NewNodeId,
            ["type"] = WorkflowNodeTypes.Condition,
            ["displayName"] = append.NodeDisplayName,
            ["description"] = append.NodeDescription,
            ["left"] = append.Left.DeepClone(),
            ["operator"] = append.Operator
        };
        if (append.Right is not null)
            condition["right"] = append.Right.DeepClone();
        nodes.Add(condition);

        edges.Add(new JsonObject
        {
            ["edgeId"] = UniqueEdgeId(edges, $"{append.InsertAfterNodeId}.{append.NewNodeId}"),
            ["fromNodeId"] = append.InsertAfterNodeId,
            ["toNodeId"] = append.NewNodeId,
            ["when"] = WorkflowEdgeConditions.Success,
            ["priority"] = priority
        });
        JsonObject trueEdge = new()
        {
            ["edgeId"] = UniqueEdgeId(edges, $"{append.NewNodeId}.true.{append.TrueTargetNodeId}"),
            ["fromNodeId"] = append.NewNodeId,
            ["toNodeId"] = append.TrueTargetNodeId,
            ["when"] = WorkflowEdgeConditions.True,
            ["priority"] = 0
        };
        if (!string.IsNullOrWhiteSpace(append.TrueLabel)) trueEdge["label"] = append.TrueLabel;
        edges.Add(trueEdge);
        JsonObject falseEdge = new()
        {
            ["edgeId"] = UniqueEdgeId(edges, $"{append.NewNodeId}.false.{append.FalseTargetNodeId}"),
            ["fromNodeId"] = append.NewNodeId,
            ["toNodeId"] = append.FalseTargetNodeId,
            ["when"] = WorkflowEdgeConditions.False,
            ["priority"] = 1
        };
        if (!string.IsNullOrWhiteSpace(append.FalseLabel)) falseEdge["label"] = append.FalseLabel;
        edges.Add(falseEdge);

        root["source"] = BuildSourceMetadata(
            append.OperationId,
            PackageSha256(append.NormalizedJson),
            parentRevisionNumber,
            parentDefinitionSha256);
        PositionNewNode(root, append.InsertAfterNodeId, append.NewNodeId);
        return WorkflowDraftCanonicalJson.Canonicalize(root.ToJsonString());
    }

    private static string BuildGraphPatchedWorkflowDefinition(
        string currentDefinitionJson,
        ParsedGraphPatch patch,
        int parentRevisionNumber,
        string parentDefinitionSha256)
    {
        JsonObject root = JsonNode.Parse(currentDefinitionJson)?.AsObject()
            ?? throw new InvalidOperationException("The current Workflow definition is invalid.");

        if (patch.HasDisplayNameChange) root["displayName"] = patch.DisplayName;
        if (patch.HasDescriptionChange) root["description"] = patch.Description;
        if (patch.WorkflowInputs is not null) root["workflowInputs"] = patch.WorkflowInputs.DeepClone();
        if (patch.WorkflowOutputs is not null) root["workflowOutputs"] = patch.WorkflowOutputs.DeepClone();

        JsonArray nodes = root["nodes"]?.AsArray()
            ?? throw new InvalidOperationException("The current Workflow has no nodes array.");
        JsonArray edges = root["edges"]?.AsArray()
            ?? throw new InvalidOperationException("The current Workflow has no edges array.");

        Dictionary<string, JsonObject> existingNodes = nodes.OfType<JsonObject>()
            .Where(node => !string.IsNullOrWhiteSpace((string?)node["nodeId"]))
            .ToDictionary(node => (string)node["nodeId"]!, StringComparer.Ordinal);
        foreach (ParsedNodeInputUpdate update in patch.NodeInputUpdates)
        {
            if (!existingNodes.TryGetValue(update.NodeId, out JsonObject? existing))
                throw new InvalidOperationException($"Exact node-input update precondition '{update.NodeId}' no longer exists in the current Workflow graph.");
            string existingType = (string?)existing["type"] ?? string.Empty;
            if (!string.Equals(existingType, WorkflowNodeTypes.Action, StringComparison.Ordinal))
                throw new InvalidOperationException($"Exact node-input update '{update.NodeId}' targets '{existingType}', but only Action nodes can update inputs in place.");
            JsonObject? actionRef = existing["actionRef"] as JsonObject;
            string currentActionId = (string?)actionRef?["actionId"] ?? string.Empty;
            if (!string.IsNullOrWhiteSpace(update.ExpectedActionId) && !string.Equals(currentActionId, update.ExpectedActionId, StringComparison.Ordinal))
                throw new InvalidOperationException($"Exact node-input update '{update.NodeId}' expected actionId '{update.ExpectedActionId}', but the current Action is '{currentActionId}'.");
            existing["inputs"] = update.Inputs.DeepClone();
        }

        foreach (ParsedNodeRemoval removal in patch.NodesToRemove)
        {
            if (!existingNodes.TryGetValue(removal.NodeId, out JsonObject? existing))
                throw new InvalidOperationException($"Exact node precondition '{removal.NodeId}' no longer exists in the current Workflow graph.");
            string existingType = (string?)existing["type"] ?? string.Empty;
            if (!string.Equals(existingType, removal.Type, StringComparison.Ordinal))
                throw new InvalidOperationException($"Exact node precondition '{removal.NodeId}' expected type '{removal.Type}' but the current node is '{existingType}'.");
            if (string.Equals(existingType, WorkflowNodeTypes.Start, StringComparison.Ordinal))
                throw new InvalidOperationException("WorkflowGraphPatch cannot remove the current Start node. A Workflow must retain exactly one Start boundary.");
        }

        foreach (ParsedEdgeRemoval removal in patch.EdgesToRemove)
        {
            JsonObject[] matchesById = edges.OfType<JsonObject>().Where(edge =>
                string.Equals((string?)edge["edgeId"], removal.EdgeId, StringComparison.Ordinal)).ToArray();
            if (matchesById.Length == 0)
                throw new InvalidOperationException(
                    $"Exact edge precondition '{removal.EdgeId}' expected {DescribeEdge(removal.FromNodeId, removal.ToNodeId, removal.When)}, but no edge with that ID exists in the graph.");
            if (matchesById.Length > 1)
                throw new InvalidOperationException(
                    $"Exact edge precondition '{removal.EdgeId}' is ambiguous because the graph contains {matchesById.Length} edges with that ID.");

            JsonObject existing = matchesById[0];
            string existingFromNodeId = (string?)existing["fromNodeId"] ?? string.Empty;
            string existingToNodeId = (string?)existing["toNodeId"] ?? string.Empty;
            string existingWhen = (string?)existing["when"] ?? string.Empty;
            if (!string.Equals(existingFromNodeId, removal.FromNodeId, StringComparison.Ordinal) ||
                !string.Equals(existingToNodeId, removal.ToNodeId, StringComparison.Ordinal) ||
                !string.Equals(existingWhen, removal.When, StringComparison.Ordinal))
            {
                throw new InvalidOperationException(
                    $"Exact edge precondition '{removal.EdgeId}' expected {DescribeEdge(removal.FromNodeId, removal.ToNodeId, removal.When)}, but the graph contains {DescribeEdge(existingFromNodeId, existingToNodeId, existingWhen)}.");
            }

            edges.Remove(existing);
        }

        foreach (ParsedNodeRemoval removal in patch.NodesToRemove)
        {
            JsonObject existing = existingNodes[removal.NodeId];
            if (edges.OfType<JsonObject>().Any(edge =>
                string.Equals((string?)edge["fromNodeId"], removal.NodeId, StringComparison.Ordinal) ||
                string.Equals((string?)edge["toNodeId"], removal.NodeId, StringComparison.Ordinal)))
            {
                throw new InvalidOperationException($"Node '{removal.NodeId}' cannot be removed while an incident edge remains. Include every incident edge in edgesToRemove.");
            }
            nodes.Remove(existing);
            existingNodes.Remove(removal.NodeId);
        }

        foreach (ParsedGraphPatchNode addition in patch.NodesToAdd)
        {
            string nodeId = (string?)addition.Node["nodeId"] ?? throw new InvalidOperationException("A graph-patch node has no nodeId.");
            if (existingNodes.ContainsKey(nodeId))
                throw new InvalidOperationException($"Graph patch node '{nodeId}' already exists in the current Workflow revision. Remove that exact node first if it is intentionally being replaced.");
            JsonObject clone = addition.Node.DeepClone().AsObject();
            nodes.Add(clone);
            existingNodes.Add(nodeId, clone);
        }

        HashSet<string> edgeIds = edges.OfType<JsonObject>()
            .Select(edge => (string?)edge["edgeId"])
            .Where(id => !string.IsNullOrWhiteSpace(id))
            .Select(id => id!)
            .ToHashSet(StringComparer.Ordinal);
        foreach (JsonObject edge in patch.EdgesToAdd)
        {
            string edgeId = (string?)edge["edgeId"] ?? throw new InvalidOperationException("A graph-patch edge has no edgeId.");
            string fromNodeId = (string?)edge["fromNodeId"] ?? string.Empty;
            string toNodeId = (string?)edge["toNodeId"] ?? string.Empty;
            if (!edgeIds.Add(edgeId)) throw new InvalidOperationException($"Graph patch edge '{edgeId}' already exists in the current Workflow revision.");
            if (!existingNodes.ContainsKey(fromNodeId) || !existingNodes.ContainsKey(toNodeId))
                throw new InvalidOperationException($"Graph patch edge '{edgeId}' references a node that does not exist after the patch.");
            edges.Add(edge.DeepClone());
        }

        if (patch.Cleanup is not null)
            ApplyCleanupGraphPatch(root, patch.Cleanup);

        root["source"] = BuildSourceMetadata(
            patch.OperationId,
            PackageSha256(patch.NormalizedJson),
            parentRevisionNumber,
            parentDefinitionSha256);
        PositionGraphPatchNodes(root, patch);
        if (patch.Cleanup is not null)
            PositionCleanupPatchNodes(root, patch.Cleanup);
        return WorkflowDraftCanonicalJson.Canonicalize(root.ToJsonString());
    }

    private static void ApplyCleanupGraphPatch(JsonObject root, ParsedCleanupGraphPatch patch)
    {
        JsonObject cleanup = root["cleanup"] as JsonObject
            ?? throw new InvalidOperationException("The current Workflow has no cleanup object.");
        JsonArray nodes = cleanup["nodes"]?.AsArray()
            ?? throw new InvalidOperationException("The current Workflow cleanup graph has no nodes array.");
        JsonArray edges = cleanup["edges"]?.AsArray()
            ?? throw new InvalidOperationException("The current Workflow cleanup graph has no edges array.");

        Dictionary<string, JsonObject> existingNodes = nodes.OfType<JsonObject>()
            .Where(node => !string.IsNullOrWhiteSpace((string?)node["nodeId"]))
            .ToDictionary(node => (string)node["nodeId"]!, StringComparer.Ordinal);

        foreach (ParsedNodeRemoval removal in patch.NodesToRemove)
        {
            if (!existingNodes.TryGetValue(removal.NodeId, out JsonObject? existing))
                throw new InvalidOperationException($"Exact Cleanup node precondition '{removal.NodeId}' no longer exists in the current Cleanup graph.");
            string existingType = (string?)existing["type"] ?? string.Empty;
            if (!string.Equals(existingType, removal.Type, StringComparison.Ordinal))
                throw new InvalidOperationException($"Exact Cleanup node precondition '{removal.NodeId}' expected type '{removal.Type}' but the current node is '{existingType}'.");
        }

        foreach (ParsedEdgeRemoval removal in patch.EdgesToRemove)
        {
            JsonObject[] matchesById = edges.OfType<JsonObject>().Where(edge =>
                string.Equals((string?)edge["edgeId"], removal.EdgeId, StringComparison.Ordinal)).ToArray();
            if (matchesById.Length == 0)
                throw new InvalidOperationException(
                    $"Exact Cleanup edge precondition '{removal.EdgeId}' expected {DescribeEdge(removal.FromNodeId, removal.ToNodeId, removal.When)}, but no edge with that ID exists in the Cleanup graph.");
            if (matchesById.Length > 1)
                throw new InvalidOperationException(
                    $"Exact Cleanup edge precondition '{removal.EdgeId}' is ambiguous because the Cleanup graph contains {matchesById.Length} edges with that ID.");

            JsonObject existing = matchesById[0];
            string existingFromNodeId = (string?)existing["fromNodeId"] ?? string.Empty;
            string existingToNodeId = (string?)existing["toNodeId"] ?? string.Empty;
            string existingWhen = (string?)existing["when"] ?? string.Empty;
            if (!string.Equals(existingFromNodeId, removal.FromNodeId, StringComparison.Ordinal) ||
                !string.Equals(existingToNodeId, removal.ToNodeId, StringComparison.Ordinal) ||
                !string.Equals(existingWhen, removal.When, StringComparison.Ordinal))
            {
                throw new InvalidOperationException(
                    $"Exact Cleanup edge precondition '{removal.EdgeId}' expected {DescribeEdge(removal.FromNodeId, removal.ToNodeId, removal.When)}, but the Cleanup graph contains {DescribeEdge(existingFromNodeId, existingToNodeId, existingWhen)}.");
            }

            edges.Remove(existing);
        }

        foreach (ParsedNodeRemoval removal in patch.NodesToRemove)
        {
            JsonObject existing = existingNodes[removal.NodeId];
            if (edges.OfType<JsonObject>().Any(edge =>
                string.Equals((string?)edge["fromNodeId"], removal.NodeId, StringComparison.Ordinal) ||
                string.Equals((string?)edge["toNodeId"], removal.NodeId, StringComparison.Ordinal)))
            {
                throw new InvalidOperationException($"Cleanup node '{removal.NodeId}' cannot be removed while an incident Cleanup edge remains. Include every incident edge in cleanup.edgesToRemove.");
            }
            nodes.Remove(existing);
            existingNodes.Remove(removal.NodeId);
        }

        foreach (ParsedGraphPatchNode addition in patch.NodesToAdd)
        {
            string nodeId = (string?)addition.Node["nodeId"] ?? throw new InvalidOperationException("A Cleanup graph-patch node has no nodeId.");
            if (existingNodes.ContainsKey(nodeId))
                throw new InvalidOperationException($"Cleanup graph patch node '{nodeId}' already exists in the current Cleanup graph. Remove that exact node first if it is intentionally being replaced.");
            JsonObject clone = addition.Node.DeepClone().AsObject();
            nodes.Add(clone);
            existingNodes.Add(nodeId, clone);
        }

        HashSet<string> edgeIds = edges.OfType<JsonObject>()
            .Select(edge => (string?)edge["edgeId"])
            .Where(id => !string.IsNullOrWhiteSpace(id))
            .Select(id => id!)
            .ToHashSet(StringComparer.Ordinal);
        foreach (JsonObject edge in patch.EdgesToAdd)
        {
            string edgeId = (string?)edge["edgeId"] ?? throw new InvalidOperationException("A Cleanup graph-patch edge has no edgeId.");
            string fromNodeId = (string?)edge["fromNodeId"] ?? string.Empty;
            string toNodeId = (string?)edge["toNodeId"] ?? string.Empty;
            if (!edgeIds.Add(edgeId)) throw new InvalidOperationException($"Cleanup graph patch edge '{edgeId}' already exists in the current Cleanup graph.");
            if (!existingNodes.ContainsKey(fromNodeId) || !existingNodes.ContainsKey(toNodeId))
                throw new InvalidOperationException($"Cleanup graph patch edge '{edgeId}' references a node that does not exist in the prospective Cleanup graph.");
            edges.Add(edge.DeepClone());
        }

        if (patch.HasStartNodeIdChange)
            cleanup["startNodeId"] = patch.StartNodeId is null ? null : JsonValue.Create(patch.StartNodeId);
        if (patch.HasFailurePolicyChange)
            cleanup["failurePolicy"] = patch.FailurePolicy;
    }

    private static void PositionCleanupPatchNodes(JsonObject root, ParsedCleanupGraphPatch patch)
    {
        JsonObject ui = root["ui"] as JsonObject ?? new JsonObject();
        root["ui"] = ui;
        JsonObject uiNodes = ui["nodes"] as JsonObject ?? new JsonObject();
        ui["nodes"] = uiNodes;

        foreach (ParsedNodeRemoval removal in patch.NodesToRemove)
            uiNodes.Remove(removal.NodeId);

        JsonObject? cleanup = root["cleanup"] as JsonObject;
        string? anchorNodeId = patch.EdgesToRemove.Count > 0
            ? patch.EdgesToRemove[0].FromNodeId
            : cleanup?["startNodeId"]?.GetValue<string>();
        JsonObject? anchor = anchorNodeId is null ? null : uiNodes[anchorNodeId] as JsonObject;
        decimal anchorX = ReadDecimal(anchor, "x") ?? 0;
        decimal anchorY = ReadDecimal(anchor, "y") ?? 350;

        for (int index = 0; index < patch.NodesToAdd.Count; index++)
        {
            ParsedGraphPatchNode addition = patch.NodesToAdd[index];
            string nodeId = (string?)addition.Node["nodeId"] ?? string.Empty;
            if (addition.Ui is not null)
            {
                uiNodes[nodeId] = addition.Ui.DeepClone();
                continue;
            }

            uiNodes[nodeId] = new JsonObject
            {
                ["x"] = anchorX + 300 + ((index % 4) * 260),
                ["y"] = anchorY + ((index / 4) * 150),
                ["collapsed"] = false,
                ["lane"] = "cleanup"
            };
        }
    }

    private static string DescribeEdge(string fromNodeId, string toNodeId, string when) =>
        $"'{fromNodeId}' -> '{toNodeId}' when '{when}'";

    private static void PositionGraphPatchNodes(JsonObject root, ParsedGraphPatch patch)
    {
        JsonObject ui = root["ui"] as JsonObject ?? new JsonObject();
        root["ui"] = ui;
        JsonObject uiNodes = ui["nodes"] as JsonObject ?? new JsonObject();
        ui["nodes"] = uiNodes;

        foreach (ParsedNodeRemoval removal in patch.NodesToRemove)
            uiNodes.Remove(removal.NodeId);

        string? anchorNodeId = patch.EdgesToRemove.Count > 0
            ? patch.EdgesToRemove[0].FromNodeId
            : root["startNodeId"]?.GetValue<string>();
        JsonObject? anchor = anchorNodeId is null ? null : uiNodes[anchorNodeId] as JsonObject;
        decimal anchorX = ReadDecimal(anchor, "x") ?? 0;
        decimal anchorY = ReadDecimal(anchor, "y") ?? 0;

        for (int index = 0; index < patch.NodesToAdd.Count; index++)
        {
            ParsedGraphPatchNode addition = patch.NodesToAdd[index];
            string nodeId = (string?)addition.Node["nodeId"] ?? string.Empty;
            if (addition.Ui is not null)
            {
                uiNodes[nodeId] = addition.Ui.DeepClone();
                continue;
            }

            uiNodes[nodeId] = new JsonObject
            {
                ["x"] = anchorX + 300 + ((index % 4) * 260),
                ["y"] = anchorY + ((index / 4) * 150),
                ["collapsed"] = false,
                ["lane"] = "main"
            };
        }
    }

    private static string UniqueEdgeId(JsonArray edges, string baseId)
    {
        HashSet<string> existing = edges.OfType<JsonObject>()
            .Select(edge => (string?)edge["edgeId"])
            .Where(value => !string.IsNullOrWhiteSpace(value))
            .Select(value => value!)
            .ToHashSet(StringComparer.Ordinal);
        if (!existing.Contains(baseId)) return baseId;
        for (int suffix = 2; suffix < 10000; suffix++)
        {
            string candidate = $"{baseId}.{suffix}";
            if (!existing.Contains(candidate)) return candidate;
        }
        throw new InvalidOperationException("A unique edge ID could not be allocated.");
    }

    private static void PositionNewNode(JsonObject root, string insertAfterNodeId, string newNodeId)
    {
        JsonObject ui = root["ui"] as JsonObject ?? new JsonObject();
        root["ui"] = ui;
        JsonObject uiNodes = ui["nodes"] as JsonObject ?? new JsonObject();
        ui["nodes"] = uiNodes;
        JsonObject? anchor = uiNodes[insertAfterNodeId] as JsonObject;
        decimal anchorX = ReadDecimal(anchor, "x") ?? 0;
        decimal anchorY = ReadDecimal(anchor, "y") ?? 0;
        foreach ((string _, JsonNode? value) in uiNodes.ToArray())
        {
            if (value is not JsonObject node) continue;
            decimal? x = ReadDecimal(node, "x");
            if (x.HasValue && x.Value > anchorX) node["x"] = x.Value + 300;
        }
        uiNodes[newNodeId] = new JsonObject
        {
            ["x"] = anchorX + 300,
            ["y"] = anchorY,
            ["collapsed"] = false,
            ["lane"] = "main"
        };
    }

    private static decimal? ReadDecimal(JsonObject? item, string propertyName)
    {
        if (item?[propertyName] is not JsonValue value) return null;
        return value.TryGetValue(out decimal parsed) ? parsed : null;
    }

    private static WorkflowAssemblyPreview Preview(
        ParsedAssemblyPackage package,
        string displayName,
        string? description,
        string? insertAfterNodeId,
        string? existingNextNodeId,
        string? newNodeId,
        string? actionMode,
        bool willCreateWorkflow,
        bool willCreateAction,
        bool willCreateRevision,
        bool isNoOp,
        string? prospectiveHash,
        IReadOnlyList<WorkflowDraftValidationIssue> issues,
        string? informationalMessage = null,
        string? actionId = null,
        int? actionVersion = null,
        string? prospectiveCanonicalDefinitionJson = null)
    {
        WorkflowDraftValidationIssue[] combined = informationalMessage is null
            ? issues.ToArray()
            : issues.Concat([Info("WF-ASSEMBLY-PREVIEW", "$", informationalMessage)]).ToArray();
        return new WorkflowAssemblyPreview(
            package.SchemaVersion,
            package.DefinitionType,
            package.OperationId,
            package.ProjectKey,
            package.WorkflowId,
            displayName,
            description,
            package.EnvironmentKey,
            package switch { ParsedActionAppend append => append.ExpectedRevisionNumber, ParsedSystemNodeAppend system => system.ExpectedRevisionNumber, ParsedGraphPatch patch => patch.ExpectedRevisionNumber, _ => null },
            package switch { ParsedActionAppend append => append.ExpectedDefinitionSha256, ParsedSystemNodeAppend system => system.ExpectedDefinitionSha256, ParsedGraphPatch patch => patch.ExpectedDefinitionSha256, _ => null },
            insertAfterNodeId,
            existingNextNodeId,
            newNodeId,
            actionMode,
            actionId,
            actionVersion,
            willCreateWorkflow,
            willCreateAction,
            willCreateRevision,
            isNoOp,
            prospectiveHash,
            combined,
            package.NormalizedJson,
            prospectiveCanonicalDefinitionJson);
    }

    private static void EnsureFullyValid(WorkflowDraftValidationResult validation, string label)
    {
        if (WorkflowAuthoringPersistencePolicy.IsPersistable(validation))
            return;
        string details = string.Join(Environment.NewLine, validation.Issues
            .Where(issue => issue.Severity == TestValidationSeverities.Error)
            .Select(issue => $"{issue.Code} at {issue.Path}: {issue.Message}"));
        throw new InvalidOperationException($"{label} validation failed.{Environment.NewLine}{details}".TrimEnd());
    }

    private static void ThrowIfErrors(IEnumerable<WorkflowDraftValidationIssue> issues, string prefix)
    {
        WorkflowDraftValidationIssue[] errors = issues.Where(issue => issue.Severity == TestValidationSeverities.Error).ToArray();
        if (errors.Length == 0) return;
        throw new InvalidOperationException(prefix + ":" + Environment.NewLine + string.Join(Environment.NewLine,
            errors.Select(issue => $"{issue.Code} at {issue.Path}: {issue.Message}")));
    }

    private async Task<string> GetProjectKeyAsync(Guid projectId, CancellationToken cancellationToken)
    {
        if (projectId == Guid.Empty) throw new ArgumentException("Project ID is required.", nameof(projectId));
        return await _dbContext.Projects.AsNoTracking()
            .Where(project => project.Id == projectId && project.IsActive)
            .Select(project => project.Key)
            .SingleOrDefaultAsync(cancellationToken)
            ?? throw new InvalidOperationException("The selected active project was not found.");
    }

    private static void EnsureProjectKey(string actual, string expected, string package)
    {
        if (string.IsNullOrWhiteSpace(expected) || !string.Equals(actual, expected.Trim(), StringComparison.OrdinalIgnoreCase))
            throw new InvalidOperationException("The expected project key does not match the selected project.");
        if (!string.Equals(actual, package, StringComparison.OrdinalIgnoreCase))
            throw new InvalidOperationException($"Package projectKey '{package}' does not match selected project '{actual}'.");
    }

    private void AddAssemblyAudit(
        WorkflowDraftWriteContext context,
        Guid draftId,
        ParsedAssemblyPackage package,
        object details)
    {
        _dbContext.AuditEvents.Add(new AuditEvent(
            context.OccurredAtUtc,
            context.ActorUserId,
            "WorkflowAssembly.Applied",
            nameof(ProjectTestDraft),
            draftId.ToString("D"),
            true,
            JsonSerializer.Serialize(new { package.OperationId, package.DefinitionType, Details = details }),
            context.CorrelationId,
            context.ClientAddress));
    }

    private static ParsedAssemblyPackage ParsePackage(string json)
    {
        if (string.IsNullOrWhiteSpace(json)) throw new InvalidOperationException("Workflow assembly JSON is required.");
        if (Encoding.UTF8.GetByteCount(json) > MaximumPackageBytes)
            throw new InvalidOperationException($"Workflow assembly JSON may not exceed {MaximumPackageBytes} bytes.");

        string normalized = WorkflowDraftCanonicalJson.Canonicalize(json);
        using JsonDocument document = JsonDocument.Parse(normalized, new JsonDocumentOptions
        {
            AllowTrailingCommas = false,
            CommentHandling = JsonCommentHandling.Disallow,
            MaxDepth = 64
        });
        JsonElement root = document.RootElement;
        if (root.ValueKind != JsonValueKind.Object)
            throw new InvalidOperationException("Workflow assembly JSON must contain one root object.");

        int schemaVersion = RequiredInt(root, "schemaVersion", "$", 1, 1);
        if (schemaVersion != SchemaVersion)
            throw new InvalidOperationException($"Workflow assembly schemaVersion must be {SchemaVersion}.");
        string definitionType = RequiredString(root, "definitionType", "$", 100);
        if (!WorkflowAssemblyDefinitionTypes.All.Contains(definitionType))
            throw new InvalidOperationException($"Unsupported definitionType '{definitionType}'.");
        string operationId = NormalizeOperationId(RequiredString(root, "operationId", "$", 200));
        string projectKey = NormalizeKey(RequiredString(root, "projectKey", "$", 150), "projectKey");
        string workflowId = ProjectTestDraft.NormalizeKey(RequiredString(root, "workflowId", "$", 200));

        return definitionType switch
        {
            WorkflowAssemblyDefinitionTypes.WorkflowSeed => ParseSeed(root, schemaVersion, definitionType, operationId, projectKey, workflowId, normalized),
            WorkflowAssemblyDefinitionTypes.ActionAppend => ParseAppend(root, schemaVersion, definitionType, operationId, projectKey, workflowId, normalized),
            WorkflowAssemblyDefinitionTypes.SystemNodeAppend => ParseSystemNodeAppend(root, schemaVersion, definitionType, operationId, projectKey, workflowId, normalized),
            WorkflowAssemblyDefinitionTypes.GraphPatch => ParseGraphPatch(root, schemaVersion, definitionType, operationId, projectKey, workflowId, normalized),
            _ => throw new InvalidOperationException($"Unsupported definitionType '{definitionType}'.")
        };
    }

    private static ParsedWorkflowSeed ParseSeed(
        JsonElement root,
        int schemaVersion,
        string definitionType,
        string operationId,
        string projectKey,
        string workflowId,
        string normalized)
    {
        EnsureOnlyProperties(root,
            "schemaVersion", "definitionType", "operationId", "projectKey", "workflowId", "displayName", "description", "environmentKey");
        string displayName = RequiredString(root, "displayName", "$", 250);
        string? description = OptionalString(root, "description", 4000);
        string? environmentKey = OptionalString(root, "environmentKey", 100)?.ToLowerInvariant();
        return new ParsedWorkflowSeed(schemaVersion, definitionType, operationId, projectKey, workflowId,
            environmentKey, normalized, displayName, description);
    }

    private static ParsedActionAppend ParseAppend(
        JsonElement root,
        int schemaVersion,
        string definitionType,
        string operationId,
        string projectKey,
        string workflowId,
        string normalized)
    {
        EnsureOnlyProperties(root,
            "schemaVersion", "definitionType", "operationId", "projectKey", "workflowId",
            "expectedWorkflowRevision", "expectedWorkflowSha256", "insertAfterNodeId", "newNodeId",
            "node", "action");
        int expectedRevision = RequiredInt(root, "expectedWorkflowRevision", "$", 1, int.MaxValue);
        string expectedHash = NormalizeHash(RequiredString(root, "expectedWorkflowSha256", "$", 64));
        string insertAfter = NormalizeNodeId(RequiredString(root, "insertAfterNodeId", "$", 100), "insertAfterNodeId");
        string newNodeId = NormalizeNodeId(RequiredString(root, "newNodeId", "$", 100), "newNodeId");
        if (string.Equals(insertAfter, newNodeId, StringComparison.Ordinal))
            throw new InvalidOperationException("newNodeId must differ from insertAfterNodeId.");

        JsonElement node = RequiredObject(root, "node", "$");
        EnsureOnlyProperties(node, "displayName", "description", "inputs", "executionPolicy");
        string nodeDisplayName = RequiredString(node, "displayName", "$.node", 250);
        string? nodeDescription = OptionalString(node, "description", 4000);
        JsonObject inputs = JsonNode.Parse(RequiredObject(node, "inputs", "$.node").GetRawText())!.AsObject();
        JsonObject? executionPolicy = node.TryGetProperty("executionPolicy", out JsonElement policy) && policy.ValueKind != JsonValueKind.Null
            ? JsonNode.Parse(policy.GetRawText())?.AsObject()
            : null;

        ParsedAction action = ParseAction(RequiredObject(root, "action", "$"));
        return new ParsedActionAppend(schemaVersion, definitionType, operationId, projectKey, workflowId,
            null, normalized, expectedRevision, expectedHash, insertAfter, newNodeId,
            nodeDisplayName, nodeDescription, inputs, executionPolicy, action);
    }

    private static ParsedSystemNodeAppend ParseSystemNodeAppend(
        JsonElement root,
        int schemaVersion,
        string definitionType,
        string operationId,
        string projectKey,
        string workflowId,
        string normalized)
    {
        EnsureOnlyProperties(root,
            "schemaVersion", "definitionType", "operationId", "projectKey", "workflowId",
            "expectedWorkflowRevision", "expectedWorkflowSha256", "insertAfterNodeId", "newNodeId",
            "node", "branches");
        int expectedRevision = RequiredInt(root, "expectedWorkflowRevision", "$", 1, int.MaxValue);
        string expectedHash = NormalizeHash(RequiredString(root, "expectedWorkflowSha256", "$", 64));
        string insertAfter = NormalizeNodeId(RequiredString(root, "insertAfterNodeId", "$", 100), "insertAfterNodeId");
        string newNodeId = NormalizeNodeId(RequiredString(root, "newNodeId", "$", 100), "newNodeId");
        if (string.Equals(insertAfter, newNodeId, StringComparison.Ordinal))
            throw new InvalidOperationException("newNodeId must differ from insertAfterNodeId.");

        JsonElement node = RequiredObject(root, "node", "$");
        EnsureOnlyProperties(node, "type", "displayName", "description", "left", "operator", "right");
        string type = RequiredString(node, "type", "$.node", 50);
        if (!string.Equals(type, WorkflowNodeTypes.Condition, StringComparison.Ordinal))
            throw new InvalidOperationException($"The first System-node append release supports only node.type '{WorkflowNodeTypes.Condition}'.");
        string displayName = RequiredString(node, "displayName", "$.node", 250);
        string? description = OptionalString(node, "description", 4000);
        JsonElement leftElement = RequiredObject(node, "left", "$.node");
        EnsureOnlyProperties(leftElement, "kind", "nodeId", "outputName");
        string leftKind = RequiredString(leftElement, "kind", "$.node.left", 50);
        if (!string.Equals(leftKind, WorkflowBindingKinds.NodeOutput, StringComparison.Ordinal))
            throw new InvalidOperationException("$.node.left.kind must be 'NodeOutput' for a Condition.");
        _ = NormalizeNodeId(RequiredString(leftElement, "nodeId", "$.node.left", 100), "node.left.nodeId");
        _ = RequiredString(leftElement, "outputName", "$.node.left", 100);
        JsonObject left = JsonNode.Parse(leftElement.GetRawText())!.AsObject();
        string conditionOperator = RequiredMember(node, "operator", WorkflowConditionOperators.All, "$.node");
        JsonObject? right = null;
        if (node.TryGetProperty("right", out JsonElement rightElement) && rightElement.ValueKind != JsonValueKind.Null)
        {
            if (rightElement.ValueKind != JsonValueKind.Object)
                throw new InvalidOperationException("$.node.right must be a binding object or null.");
            EnsureOnlyProperties(rightElement, "kind", "value");
            string rightKind = RequiredString(rightElement, "kind", "$.node.right", 50);
            if (!string.Equals(rightKind, WorkflowBindingKinds.Literal, StringComparison.Ordinal))
                throw new InvalidOperationException("$.node.right.kind must be 'Literal' for a Condition.");
            if (!rightElement.TryGetProperty("value", out _))
                throw new InvalidOperationException("$.node.right.value is required for a Literal binding.");
            right = JsonNode.Parse(rightElement.GetRawText())!.AsObject();
        }
        if (WorkflowConditionOperators.Unary.Contains(conditionOperator) && right is not null)
            throw new InvalidOperationException($"Condition operator '{conditionOperator}' does not accept node.right.");
        if (!WorkflowConditionOperators.Unary.Contains(conditionOperator) && right is null)
            throw new InvalidOperationException($"Condition operator '{conditionOperator}' requires node.right.");

        JsonElement branches = RequiredObject(root, "branches", "$");
        EnsureOnlyProperties(branches, "trueTargetNodeId", "falseTargetNodeId", "trueLabel", "falseLabel");
        string trueTarget = NormalizeNodeId(RequiredString(branches, "trueTargetNodeId", "$.branches", 100), "branches.trueTargetNodeId");
        string falseTarget = NormalizeNodeId(RequiredString(branches, "falseTargetNodeId", "$.branches", 100), "branches.falseTargetNodeId");
        string? trueLabel = OptionalString(branches, "trueLabel", 150);
        string? falseLabel = OptionalString(branches, "falseLabel", 150);

        return new ParsedSystemNodeAppend(schemaVersion, definitionType, operationId, projectKey, workflowId,
            null, normalized, expectedRevision, expectedHash, insertAfter, newNodeId, displayName, description,
            left, conditionOperator, right, trueTarget, falseTarget, trueLabel, falseLabel);
    }

    private static ParsedGraphPatch ParseGraphPatch(
        JsonElement root,
        int schemaVersion,
        string definitionType,
        string operationId,
        string projectKey,
        string workflowId,
        string normalized)
    {
        EnsureOnlyProperties(root, WorkflowGraphPatchAgentContract.RootProperties);
        int expectedRevision = RequiredInt(root, "expectedWorkflowRevision", "$", 1, int.MaxValue);
        string expectedHash = NormalizeHash(RequiredString(root, "expectedWorkflowSha256", "$", 64));
        JsonElement patchElement = RequiredObject(root, "patch", "$");
        EnsureOnlyProperties(patchElement, WorkflowGraphPatchAgentContract.PatchProperties);

        bool hasDisplayNameChange = false;
        string? displayName = null;
        bool hasDescriptionChange = false;
        string? description = null;
        if (patchElement.TryGetProperty("metadata", out JsonElement metadataElement))
        {
            if (metadataElement.ValueKind != JsonValueKind.Object)
                throw new InvalidOperationException("$.patch.metadata must be an object when supplied.");
            EnsureOnlyProperties(metadataElement, "displayName", "description");
            if (metadataElement.TryGetProperty("displayName", out _))
            {
                hasDisplayNameChange = true;
                displayName = RequiredString(metadataElement, "displayName", "$.patch.metadata", 250);
            }
            if (metadataElement.TryGetProperty("description", out JsonElement descriptionElement))
            {
                hasDescriptionChange = true;
                if (descriptionElement.ValueKind is not (JsonValueKind.String or JsonValueKind.Null))
                    throw new InvalidOperationException("$.patch.metadata.description must be a string or null.");
                description = OptionalString(metadataElement, "description", 2000);
            }
        }

        JsonArray? workflowInputs = null;
        if (patchElement.TryGetProperty("workflowInputs", out JsonElement workflowInputsElement))
        {
            if (workflowInputsElement.ValueKind != JsonValueKind.Array)
                throw new InvalidOperationException("$.patch.workflowInputs must be an array when supplied.");
            if (workflowInputsElement.GetArrayLength() > 100)
                throw new InvalidOperationException("$.patch.workflowInputs may contain at most 100 Workflow inputs.");
            workflowInputs = JsonNode.Parse(workflowInputsElement.GetRawText())!.AsArray();
        }

        JsonArray? workflowOutputs = null;
        if (patchElement.TryGetProperty("workflowOutputs", out JsonElement workflowOutputsElement))
        {
            if (workflowOutputsElement.ValueKind != JsonValueKind.Array)
                throw new InvalidOperationException("$.patch.workflowOutputs must be an array when supplied.");
            if (workflowOutputsElement.GetArrayLength() > 100)
                throw new InvalidOperationException("$.patch.workflowOutputs may contain at most 100 Workflow outputs.");
            workflowOutputs = JsonNode.Parse(workflowOutputsElement.GetRawText())!.AsArray();
        }

        ParsedCleanupGraphPatch? cleanupPatch = null;
        if (patchElement.TryGetProperty("cleanup", out JsonElement cleanupElement))
        {
            if (cleanupElement.ValueKind != JsonValueKind.Object)
                throw new InvalidOperationException("$.patch.cleanup must be an object when supplied.");
            cleanupPatch = ParseCleanupGraphPatch(cleanupElement);
        }

        JsonElement nodesElement = RequiredArray(patchElement, "nodesToAdd", "$.patch");
        JsonElement removalsElement = RequiredArray(patchElement, "edgesToRemove", "$.patch");
        JsonElement additionsElement = RequiredArray(patchElement, "edgesToAdd", "$.patch");
        JsonElement nodeRemovalsElement = default;
        if (patchElement.TryGetProperty("nodesToRemove", out JsonElement suppliedNodeRemovals))
        {
            if (suppliedNodeRemovals.ValueKind != JsonValueKind.Array)
                throw new InvalidOperationException("$.patch.nodesToRemove must be an array when supplied.");
            nodeRemovalsElement = suppliedNodeRemovals;
        }
        JsonElement nodeInputUpdatesElement = default;
        if (patchElement.TryGetProperty("nodeInputUpdates", out JsonElement suppliedNodeInputUpdates))
        {
            if (suppliedNodeInputUpdates.ValueKind != JsonValueKind.Array)
                throw new InvalidOperationException("$.patch.nodeInputUpdates must be an array when supplied.");
            nodeInputUpdatesElement = suppliedNodeInputUpdates;
        }

        int nodeAddCount = nodesElement.GetArrayLength();
        int nodeInputUpdateCount = nodeInputUpdatesElement.ValueKind == JsonValueKind.Array ? nodeInputUpdatesElement.GetArrayLength() : 0;
        int nodeRemoveCount = nodeRemovalsElement.ValueKind == JsonValueKind.Array ? nodeRemovalsElement.GetArrayLength() : 0;
        int edgeRemoveCount = removalsElement.GetArrayLength();
        int edgeAddCount = additionsElement.GetArrayLength();
        if (nodeAddCount > WorkflowGraphPatchAgentContract.MaximumNodesToAdd)
            throw new InvalidOperationException($"$.patch.nodesToAdd may contain at most {WorkflowGraphPatchAgentContract.MaximumNodesToAdd} nodes.");
        if (nodeInputUpdateCount > WorkflowGraphPatchAgentContract.MaximumNodeInputUpdates)
            throw new InvalidOperationException($"$.patch.nodeInputUpdates may contain at most {WorkflowGraphPatchAgentContract.MaximumNodeInputUpdates} updates.");
        if (nodeRemoveCount > WorkflowGraphPatchAgentContract.MaximumNodesToRemove)
            throw new InvalidOperationException($"$.patch.nodesToRemove may contain at most {WorkflowGraphPatchAgentContract.MaximumNodesToRemove} exact node preconditions.");
        if (edgeRemoveCount > WorkflowGraphPatchAgentContract.MaximumEdgesToRemove)
            throw new InvalidOperationException($"$.patch.edgesToRemove may contain at most {WorkflowGraphPatchAgentContract.MaximumEdgesToRemove} exact edge preconditions.");
        if (edgeAddCount > WorkflowGraphPatchAgentContract.MaximumEdgesToAdd)
            throw new InvalidOperationException($"$.patch.edgesToAdd may contain at most {WorkflowGraphPatchAgentContract.MaximumEdgesToAdd} explicit edges.");
        bool hasDefinitionContractChanges = hasDisplayNameChange || hasDescriptionChange || workflowInputs is not null || workflowOutputs is not null;
        if (nodeAddCount + nodeInputUpdateCount + nodeRemoveCount + edgeRemoveCount + edgeAddCount == 0 &&
            !hasDefinitionContractChanges && !(cleanupPatch?.HasChanges ?? false))
            throw new InvalidOperationException("WorkflowGraphPatch must contain at least one main graph, Cleanup, metadata, Workflow input or Workflow output change.");

        var nodes = new List<ParsedGraphPatchNode>();
        var newNodeIds = new HashSet<string>(StringComparer.Ordinal);
        int nodeIndex = 0;
        foreach (JsonElement nodeElement in nodesElement.EnumerateArray())
        {
            if (nodeElement.ValueKind != JsonValueKind.Object) throw new InvalidOperationException($"$.patch.nodesToAdd[{nodeIndex}] must be an object.");
            string path = $"$.patch.nodesToAdd[{nodeIndex}]";
            string nodeId = NormalizeNodeId(RequiredString(nodeElement, "nodeId", path, 100), $"nodesToAdd[{nodeIndex}].nodeId");
            if (!newNodeIds.Add(nodeId)) throw new InvalidOperationException($"Graph patch nodeId '{nodeId}' is duplicated.");
            string type = RequiredString(nodeElement, "type", path, 50);
            JsonObject? ui = ParseGraphPatchUi(nodeElement, path);
            switch (type)
            {
                case WorkflowNodeTypes.Action:
                    EnsureOnlyProperties(nodeElement, "nodeId", "type", "displayName", "description", "actionRef", "inputs", "session", "timeoutSeconds", "retryPolicy", "executionPolicy", "continuePolicy", "disabled", "notes", "ui");
                    ValidatePatchActionNode(nodeElement, path);
                    break;
                case WorkflowNodeTypes.Condition:
                    EnsureOnlyProperties(nodeElement, "nodeId", "type", "displayName", "description", "left", "operator", "right", "ui");
                    ValidatePatchConditionBindings(nodeElement, path, isLoop: false);
                    break;
                case WorkflowNodeTypes.Switch:
                    EnsureOnlyProperties(nodeElement, "nodeId", "type", "displayName", "description", "value", "caseSensitive", "ui");
                    _ = RequiredObject(nodeElement, "value", path);
                    if (nodeElement.TryGetProperty("caseSensitive", out JsonElement caseSensitive) && caseSensitive.ValueKind is not (JsonValueKind.True or JsonValueKind.False))
                        throw new InvalidOperationException($"{path}.caseSensitive must be Boolean when supplied.");
                    break;
                case WorkflowNodeTypes.Assert:
                    EnsureOnlyProperties(nodeElement, "nodeId", "type", "displayName", "description", "left", "operator", "right", "classification", "message", "ui");
                    _ = RequiredObject(nodeElement, "left", path);
                    _ = RequiredString(nodeElement, "operator", path, 50);
                    _ = OptionalString(nodeElement, "classification", 100);
                    _ = OptionalString(nodeElement, "message", 2000);
                    break;
                case WorkflowNodeTypes.Fork:
                    EnsureOnlyProperties(nodeElement, "nodeId", "type", "displayName", "description", "failurePolicy", "maximumParallelism", "ui");
                    if (nodeElement.TryGetProperty("failurePolicy", out JsonElement failurePolicy) &&
                        !string.Equals(failurePolicy.GetString(), "FailFast", StringComparison.Ordinal))
                        throw new InvalidOperationException($"{path}.failurePolicy must be 'FailFast'.");
                    if (nodeElement.TryGetProperty("maximumParallelism", out _))
                        _ = RequiredInt(nodeElement, "maximumParallelism", path, 1, 16);
                    break;
                case WorkflowNodeTypes.Join:
                    EnsureOnlyProperties(nodeElement, "nodeId", "type", "displayName", "description", "mode", "ui");
                    if (nodeElement.TryGetProperty("mode", out JsonElement mode) && !string.Equals(mode.GetString(), "All", StringComparison.Ordinal))
                        throw new InvalidOperationException($"{path}.mode must be 'All'.");
                    break;
                case WorkflowNodeTypes.Loop:
                    EnsureOnlyProperties(nodeElement, "nodeId", "type", "displayName", "description", "left", "operator", "right", "maximumIterations", "overallTimeoutSeconds", "ui");
                    ValidatePatchConditionBindings(nodeElement, path, isLoop: true);
                    _ = RequiredInt(nodeElement, "maximumIterations", path, 1, 100);
                    _ = RequiredInt(nodeElement, "overallTimeoutSeconds", path, 1, 14400);
                    break;
                case WorkflowNodeTypes.Repeat:
                    EnsureOnlyProperties(nodeElement, "nodeId", "type", "displayName", "description", "count", "overallTimeoutSeconds", "ui");
                    _ = RequiredInt(nodeElement, "count", path, 1, 1000);
                    _ = RequiredInt(nodeElement, "overallTimeoutSeconds", path, 1, 14400);
                    break;
                case WorkflowNodeTypes.Break:
                case WorkflowNodeTypes.Continue:
                    EnsureOnlyProperties(nodeElement, "nodeId", "type", "displayName", "description", "ui");
                    break;
                case WorkflowNodeTypes.WorkflowCall:
                    EnsureOnlyProperties(nodeElement, "nodeId", "type", "displayName", "description", "workflowRef", "inputs", "ui");
                    JsonElement workflowRef = RequiredObject(nodeElement, "workflowRef", path);
                    EnsureOnlyProperties(workflowRef, "workflowId", "versionPolicy", "version", "resolvedWorkflowVersionId");
                    _ = RequiredString(workflowRef, "workflowId", $"{path}.workflowRef", 200);
                    string workflowPolicy = RequiredString(workflowRef, "versionPolicy", $"{path}.workflowRef", 50);
                    if (!WorkflowReferenceVersionPolicies.All.Contains(workflowPolicy))
                        throw new InvalidOperationException($"{path}.workflowRef.versionPolicy '{workflowPolicy}' is not supported.");
                    if (workflowPolicy == WorkflowReferenceVersionPolicies.Exact)
                        _ = RequiredInt(workflowRef, "version", $"{path}.workflowRef", 1, int.MaxValue);
                    _ = RequiredObject(nodeElement, "inputs", path);
                    break;
                case WorkflowNodeTypes.Return:
                    EnsureOnlyProperties(nodeElement, "nodeId", "type", "displayName", "description", "ui");
                    break;
                case WorkflowNodeTypes.UserInteraction:
                    EnsureOnlyProperties(nodeElement, "nodeId", "type", "displayName", "description", "pageKey", "responseFields", "assignmentMode", "assignedUserId", "assignedRoleKey", "expiresAfterSeconds", "ui");
                    _ = RequiredString(nodeElement, "pageKey", path, 100);
                    JsonElement responseFields = RequiredArray(nodeElement, "responseFields", path);
                    if (responseFields.GetArrayLength() is < 1 or > 100)
                        throw new InvalidOperationException($"{path}.responseFields must contain between 1 and 100 typed fields.");
                    string assignmentMode = OptionalString(nodeElement, "assignmentMode", 30) ?? "Starter";
                    if (assignmentMode is not ("Starter" or "User" or "Role" or "Group"))
                        throw new InvalidOperationException($"{path}.assignmentMode '{assignmentMode}' is not supported.");
                    string? assignedUserId = OptionalString(nodeElement, "assignedUserId", 36);
                    string? assignedRoleKey = OptionalString(nodeElement, "assignedRoleKey", 100);
                    if (assignmentMode == "User" && (!Guid.TryParse(assignedUserId, out Guid assignedUser) || assignedUser == Guid.Empty))
                        throw new InvalidOperationException($"{path}.assignedUserId is required for User assignment.");
                    if (assignmentMode is "Role" or "Group" && string.IsNullOrWhiteSpace(assignedRoleKey))
                        throw new InvalidOperationException($"{path}.assignedRoleKey is required for Role/Group assignment.");
                    if (nodeElement.TryGetProperty("expiresAfterSeconds", out JsonElement expiresAfterSeconds))
                        _ = RequiredInt(nodeElement, "expiresAfterSeconds", path, 1, 86400);
                    break;
                case WorkflowNodeTypes.Succeed:
                    EnsureOnlyProperties(nodeElement, "nodeId", "type", "displayName", "ui");
                    break;
                case WorkflowNodeTypes.Fail:
                    EnsureOnlyProperties(nodeElement, "nodeId", "type", "displayName", "classification", "message", "ui");
                    _ = OptionalString(nodeElement, "classification", 100);
                    _ = OptionalString(nodeElement, "message", 2000);
                    break;
                default:
                    throw new InvalidOperationException($"{path}.type '{type}' is not supported by WorkflowGraphPatch. Use an available User/Built-in Action or one of the supported first-class System Nodes.");
            }
            _ = RequiredString(nodeElement, "displayName", path, 250);
            JsonObject canonicalNode = JsonNode.Parse(nodeElement.GetRawText())!.AsObject();
            canonicalNode.Remove("ui");
            nodes.Add(new ParsedGraphPatchNode(canonicalNode, ui));
            nodeIndex++;
        }

        var nodeInputUpdates = new List<ParsedNodeInputUpdate>();
        var nodeInputUpdateIds = new HashSet<string>(StringComparer.Ordinal);
        if (nodeInputUpdatesElement.ValueKind == JsonValueKind.Array)
        {
            int updateIndex = 0;
            foreach (JsonElement nodeUpdate in nodeInputUpdatesElement.EnumerateArray())
            {
                string path = $"$.patch.nodeInputUpdates[{updateIndex}]";
                if (nodeUpdate.ValueKind != JsonValueKind.Object) throw new InvalidOperationException($"{path} must be an object.");
                EnsureOnlyProperties(nodeUpdate, WorkflowGraphPatchAgentContract.NodeInputUpdateProperties);
                string nodeId = NormalizeNodeId(RequiredString(nodeUpdate, "nodeId", path, WorkflowGraphPatchAgentContract.MaximumNodeIdLength), $"nodeInputUpdates[{updateIndex}].nodeId");
                if (!nodeInputUpdateIds.Add(nodeId)) throw new InvalidOperationException($"Graph patch node-input update '{nodeId}' is duplicated.");
                string? expectedActionId = OptionalString(nodeUpdate, "expectedActionId", 200);
                JsonElement inputsElement = RequiredObject(nodeUpdate, "inputs", path);
                int inputCount = 0;
                foreach (JsonProperty _ in inputsElement.EnumerateObject()) inputCount++;
                if (inputCount > 100) throw new InvalidOperationException($"{path}.inputs may contain at most 100 Action inputs.");
                nodeInputUpdates.Add(new ParsedNodeInputUpdate(nodeId, expectedActionId, JsonNode.Parse(inputsElement.GetRawText())!.AsObject()));
                updateIndex++;
            }
        }

        var nodeRemovals = new List<ParsedNodeRemoval>();
        var nodeRemovalIds = new HashSet<string>(StringComparer.Ordinal);
        if (nodeRemovalsElement.ValueKind == JsonValueKind.Array)
        {
            int index = 0;
            foreach (JsonElement nodeRemoval in nodeRemovalsElement.EnumerateArray())
            {
                string path = $"$.patch.nodesToRemove[{index}]";
                if (nodeRemoval.ValueKind != JsonValueKind.Object) throw new InvalidOperationException($"{path} must be an object.");
                EnsureOnlyProperties(nodeRemoval, WorkflowGraphPatchAgentContract.NodesToRemoveProperties);
                string nodeId = NormalizeNodeId(
                    RequiredString(nodeRemoval, "nodeId", path, WorkflowGraphPatchAgentContract.MaximumNodeIdLength),
                    $"nodesToRemove[{index}].nodeId");
                if (!nodeRemovalIds.Add(nodeId)) throw new InvalidOperationException($"Graph patch node removal '{nodeId}' is duplicated.");
                string type = RequiredString(nodeRemoval, "type", path, 50);
                if (string.Equals(type, WorkflowNodeTypes.Start, StringComparison.Ordinal))
                    throw new InvalidOperationException($"{path} cannot remove Start. WorkflowGraphPatch retains the current Workflow Start boundary.");
                if (!WorkflowGraphPatchAgentContract.RemovableNodeTypes.Contains(type))
                    throw new InvalidOperationException($"{path}.type '{type}' is not removable through WorkflowGraphPatch.");
                nodeRemovals.Add(new ParsedNodeRemoval(nodeId, type));
                index++;
            }
        }

        var removals = new List<ParsedEdgeRemoval>();
        var removalIds = new HashSet<string>(StringComparer.Ordinal);
        int removalIndex = 0;
        foreach (JsonElement edge in removalsElement.EnumerateArray())
        {
            if (edge.ValueKind != JsonValueKind.Object) throw new InvalidOperationException($"$.patch.edgesToRemove[{removalIndex}] must be an object.");
            EnsureOnlyProperties(edge, WorkflowGraphPatchAgentContract.EdgesToRemoveProperties);
            string path = $"$.patch.edgesToRemove[{removalIndex}]";
            string edgeId = RequiredString(edge, "edgeId", path, WorkflowGraphPatchAgentContract.MaximumGraphPatchEdgeIdInputLength);
            if (!removalIds.Add(edgeId)) throw new InvalidOperationException($"Graph patch removal edgeId '{edgeId}' is duplicated.");
            string fromNodeId = NormalizeNodeId(
                RequiredString(edge, "fromNodeId", path, WorkflowGraphPatchAgentContract.MaximumNodeIdLength),
                $"edgesToRemove[{removalIndex}].fromNodeId");
            string toNodeId = NormalizeNodeId(
                RequiredString(edge, "toNodeId", path, WorkflowGraphPatchAgentContract.MaximumNodeIdLength),
                $"edgesToRemove[{removalIndex}].toNodeId");
            string when = RequiredMember(edge, "when", WorkflowGraphPatchAgentContract.EdgeConditions, path);
            removals.Add(new ParsedEdgeRemoval(edgeId, fromNodeId, toNodeId, when));
            removalIndex++;
        }

        var additions = new List<JsonObject>();
        var additionIds = new HashSet<string>(StringComparer.Ordinal);
        int additionIndex = 0;
        foreach (JsonElement edge in additionsElement.EnumerateArray())
        {
            if (edge.ValueKind != JsonValueKind.Object) throw new InvalidOperationException($"$.patch.edgesToAdd[{additionIndex}] must be an object.");
            EnsureOnlyProperties(edge, WorkflowGraphPatchAgentContract.EdgesToAddProperties);
            string path = $"$.patch.edgesToAdd[{additionIndex}]";
            string edgeId = RequiredString(edge, "edgeId", path, WorkflowGraphPatchAgentContract.MaximumGraphPatchEdgeIdInputLength);
            if (!additionIds.Add(edgeId)) throw new InvalidOperationException($"Graph patch added edgeId '{edgeId}' is duplicated.");
            _ = NormalizeNodeId(
                RequiredString(edge, "fromNodeId", path, WorkflowGraphPatchAgentContract.MaximumNodeIdLength),
                $"edgesToAdd[{additionIndex}].fromNodeId");
            _ = NormalizeNodeId(
                RequiredString(edge, "toNodeId", path, WorkflowGraphPatchAgentContract.MaximumNodeIdLength),
                $"edgesToAdd[{additionIndex}].toNodeId");
            _ = RequiredMember(edge, "when", WorkflowGraphPatchAgentContract.EdgeConditions, path);
            additions.Add(JsonNode.Parse(edge.GetRawText())!.AsObject());
            additionIndex++;
        }

        return new ParsedGraphPatch(schemaVersion, definitionType, operationId, projectKey, workflowId,
            null, normalized, expectedRevision, expectedHash,
            hasDisplayNameChange, displayName, hasDescriptionChange, description, workflowInputs, workflowOutputs,
            nodes, nodeInputUpdates, nodeRemovals, removals, additions, cleanupPatch);
    }

    private static ParsedCleanupGraphPatch ParseCleanupGraphPatch(JsonElement cleanupElement)
    {
        EnsureOnlyProperties(cleanupElement, WorkflowGraphPatchAgentContract.CleanupPatchProperties);

        bool hasStartNodeIdChange = cleanupElement.TryGetProperty("startNodeId", out JsonElement startNodeElement);
        string? startNodeId = null;
        if (hasStartNodeIdChange)
        {
            if (startNodeElement.ValueKind == JsonValueKind.String)
            {
                startNodeId = NormalizeNodeId(
                    RequiredString(cleanupElement, "startNodeId", "$.patch.cleanup", WorkflowGraphPatchAgentContract.MaximumNodeIdLength),
                    "cleanup.startNodeId");
            }
            else if (startNodeElement.ValueKind != JsonValueKind.Null)
            {
                throw new InvalidOperationException("$.patch.cleanup.startNodeId must be a node ID string or null.");
            }
        }

        bool hasFailurePolicyChange = cleanupElement.TryGetProperty("failurePolicy", out _);
        string? failurePolicy = hasFailurePolicyChange
            ? RequiredMember(cleanupElement, "failurePolicy", WorkflowGraphPatchAgentContract.CleanupFailurePolicies, "$.patch.cleanup")
            : null;

        JsonElement nodesElement = RequiredArray(cleanupElement, "nodesToAdd", "$.patch.cleanup");
        JsonElement removalsElement = RequiredArray(cleanupElement, "edgesToRemove", "$.patch.cleanup");
        JsonElement additionsElement = RequiredArray(cleanupElement, "edgesToAdd", "$.patch.cleanup");
        JsonElement nodeRemovalsElement = default;
        if (cleanupElement.TryGetProperty("nodesToRemove", out JsonElement suppliedNodeRemovals))
        {
            if (suppliedNodeRemovals.ValueKind != JsonValueKind.Array)
                throw new InvalidOperationException("$.patch.cleanup.nodesToRemove must be an array when supplied.");
            nodeRemovalsElement = suppliedNodeRemovals;
        }

        int nodeAddCount = nodesElement.GetArrayLength();
        int nodeRemoveCount = nodeRemovalsElement.ValueKind == JsonValueKind.Array ? nodeRemovalsElement.GetArrayLength() : 0;
        int edgeRemoveCount = removalsElement.GetArrayLength();
        int edgeAddCount = additionsElement.GetArrayLength();
        if (nodeAddCount > WorkflowGraphPatchAgentContract.MaximumNodesToAdd)
            throw new InvalidOperationException($"$.patch.cleanup.nodesToAdd may contain at most {WorkflowGraphPatchAgentContract.MaximumNodesToAdd} nodes.");
        if (nodeRemoveCount > WorkflowGraphPatchAgentContract.MaximumNodesToRemove)
            throw new InvalidOperationException($"$.patch.cleanup.nodesToRemove may contain at most {WorkflowGraphPatchAgentContract.MaximumNodesToRemove} exact node preconditions.");
        if (edgeRemoveCount > WorkflowGraphPatchAgentContract.MaximumEdgesToRemove)
            throw new InvalidOperationException($"$.patch.cleanup.edgesToRemove may contain at most {WorkflowGraphPatchAgentContract.MaximumEdgesToRemove} exact edge preconditions.");
        if (edgeAddCount > WorkflowGraphPatchAgentContract.MaximumEdgesToAdd)
            throw new InvalidOperationException($"$.patch.cleanup.edgesToAdd may contain at most {WorkflowGraphPatchAgentContract.MaximumEdgesToAdd} explicit edges.");

        var nodes = new List<ParsedGraphPatchNode>();
        var newNodeIds = new HashSet<string>(StringComparer.Ordinal);
        int nodeIndex = 0;
        foreach (JsonElement nodeElement in nodesElement.EnumerateArray())
        {
            if (nodeElement.ValueKind != JsonValueKind.Object)
                throw new InvalidOperationException($"$.patch.cleanup.nodesToAdd[{nodeIndex}] must be an object.");
            string path = $"$.patch.cleanup.nodesToAdd[{nodeIndex}]";
            string nodeId = NormalizeNodeId(RequiredString(nodeElement, "nodeId", path, WorkflowGraphPatchAgentContract.MaximumNodeIdLength), $"cleanup.nodesToAdd[{nodeIndex}].nodeId");
            if (!newNodeIds.Add(nodeId)) throw new InvalidOperationException($"Cleanup graph patch nodeId '{nodeId}' is duplicated.");
            string type = RequiredString(nodeElement, "type", path, 50);
            JsonObject? ui = ParseGraphPatchUi(nodeElement, path);
            switch (type)
            {
                case WorkflowNodeTypes.Start:
                    EnsureOnlyProperties(nodeElement, "nodeId", "type", "displayName", "ui");
                    break;
                case WorkflowNodeTypes.Action:
                    EnsureOnlyProperties(nodeElement, "nodeId", "type", "displayName", "description", "actionRef", "inputs", "session", "timeoutSeconds", "retryPolicy", "executionPolicy", "continuePolicy", "disabled", "notes", "ui");
                    ValidatePatchActionNode(nodeElement, path);
                    break;
                case WorkflowNodeTypes.Succeed:
                    EnsureOnlyProperties(nodeElement, "nodeId", "type", "displayName", "ui");
                    break;
                case WorkflowNodeTypes.Fail:
                    EnsureOnlyProperties(nodeElement, "nodeId", "type", "displayName", "classification", "message", "ui");
                    _ = OptionalString(nodeElement, "classification", 100);
                    _ = OptionalString(nodeElement, "message", 2000);
                    break;
                default:
                    throw new InvalidOperationException($"{path}.type '{type}' is not supported in Cleanup. Cleanup supports Start, Action, Succeed and Fail only.");
            }
            _ = RequiredString(nodeElement, "displayName", path, 250);
            JsonObject canonicalNode = JsonNode.Parse(nodeElement.GetRawText())!.AsObject();
            canonicalNode.Remove("ui");
            nodes.Add(new ParsedGraphPatchNode(canonicalNode, ui));
            nodeIndex++;
        }

        var nodeRemovals = new List<ParsedNodeRemoval>();
        var nodeRemovalIds = new HashSet<string>(StringComparer.Ordinal);
        if (nodeRemovalsElement.ValueKind == JsonValueKind.Array)
        {
            int index = 0;
            foreach (JsonElement nodeRemoval in nodeRemovalsElement.EnumerateArray())
            {
                string path = $"$.patch.cleanup.nodesToRemove[{index}]";
                if (nodeRemoval.ValueKind != JsonValueKind.Object) throw new InvalidOperationException($"{path} must be an object.");
                EnsureOnlyProperties(nodeRemoval, WorkflowGraphPatchAgentContract.NodesToRemoveProperties);
                string nodeId = NormalizeNodeId(
                    RequiredString(nodeRemoval, "nodeId", path, WorkflowGraphPatchAgentContract.MaximumNodeIdLength),
                    $"cleanup.nodesToRemove[{index}].nodeId");
                if (!nodeRemovalIds.Add(nodeId)) throw new InvalidOperationException($"Cleanup graph patch node removal '{nodeId}' is duplicated.");
                string type = RequiredString(nodeRemoval, "type", path, 50);
                if (!WorkflowGraphPatchAgentContract.CleanupNodeTypes.Contains(type))
                    throw new InvalidOperationException($"{path}.type '{type}' is not removable from Cleanup through WorkflowGraphPatch.");
                nodeRemovals.Add(new ParsedNodeRemoval(nodeId, type));
                index++;
            }
        }

        var removals = new List<ParsedEdgeRemoval>();
        var removalIds = new HashSet<string>(StringComparer.Ordinal);
        int removalIndex = 0;
        foreach (JsonElement edge in removalsElement.EnumerateArray())
        {
            string path = $"$.patch.cleanup.edgesToRemove[{removalIndex}]";
            if (edge.ValueKind != JsonValueKind.Object) throw new InvalidOperationException($"{path} must be an object.");
            EnsureOnlyProperties(edge, WorkflowGraphPatchAgentContract.EdgesToRemoveProperties);
            string edgeId = RequiredString(edge, "edgeId", path, WorkflowGraphPatchAgentContract.MaximumGraphPatchEdgeIdInputLength);
            if (!removalIds.Add(edgeId)) throw new InvalidOperationException($"Cleanup graph patch removal edgeId '{edgeId}' is duplicated.");
            string fromNodeId = NormalizeNodeId(RequiredString(edge, "fromNodeId", path, WorkflowGraphPatchAgentContract.MaximumNodeIdLength), $"cleanup.edgesToRemove[{removalIndex}].fromNodeId");
            string toNodeId = NormalizeNodeId(RequiredString(edge, "toNodeId", path, WorkflowGraphPatchAgentContract.MaximumNodeIdLength), $"cleanup.edgesToRemove[{removalIndex}].toNodeId");
            string when = RequiredMember(edge, "when", WorkflowGraphPatchAgentContract.CleanupEdgeConditions, path);
            removals.Add(new ParsedEdgeRemoval(edgeId, fromNodeId, toNodeId, when));
            removalIndex++;
        }

        var additions = new List<JsonObject>();
        var additionIds = new HashSet<string>(StringComparer.Ordinal);
        int additionIndex = 0;
        foreach (JsonElement edge in additionsElement.EnumerateArray())
        {
            string path = $"$.patch.cleanup.edgesToAdd[{additionIndex}]";
            if (edge.ValueKind != JsonValueKind.Object) throw new InvalidOperationException($"{path} must be an object.");
            EnsureOnlyProperties(edge, WorkflowGraphPatchAgentContract.EdgesToAddProperties);
            string edgeId = RequiredString(edge, "edgeId", path, WorkflowGraphPatchAgentContract.MaximumGraphPatchEdgeIdInputLength);
            if (!additionIds.Add(edgeId)) throw new InvalidOperationException($"Cleanup graph patch added edgeId '{edgeId}' is duplicated.");
            _ = NormalizeNodeId(RequiredString(edge, "fromNodeId", path, WorkflowGraphPatchAgentContract.MaximumNodeIdLength), $"cleanup.edgesToAdd[{additionIndex}].fromNodeId");
            _ = NormalizeNodeId(RequiredString(edge, "toNodeId", path, WorkflowGraphPatchAgentContract.MaximumNodeIdLength), $"cleanup.edgesToAdd[{additionIndex}].toNodeId");
            _ = RequiredMember(edge, "when", WorkflowGraphPatchAgentContract.CleanupEdgeConditions, path);
            additions.Add(JsonNode.Parse(edge.GetRawText())!.AsObject());
            additionIndex++;
        }

        return new ParsedCleanupGraphPatch(
            hasStartNodeIdChange, startNodeId, hasFailurePolicyChange, failurePolicy,
            nodes, nodeRemovals, removals, additions);
    }

    private static void ValidatePatchActionNode(JsonElement node, string path)
    {
        JsonElement actionRef = RequiredObject(node, "actionRef", path);
        EnsureOnlyProperties(actionRef, "origin", "actionId", "versionPolicy", "version");
        _ = ProjectAction.NormalizeKey(RequiredString(actionRef, "actionId", $"{path}.actionRef", 200));
        string origin = actionRef.TryGetProperty("origin", out JsonElement originElement) && originElement.ValueKind == JsonValueKind.String
            ? originElement.GetString() ?? ActionCapabilityOrigins.UserAction
            : ActionCapabilityOrigins.UserAction;
        if (!ActionCapabilityOrigins.All.Contains(origin))
            throw new InvalidOperationException($"{path}.actionRef.origin must be 'UserAction' or 'BuiltIn'.");
        string versionPolicy = RequiredString(actionRef, "versionPolicy", $"{path}.actionRef", 50);
        bool hasVersion = actionRef.TryGetProperty("version", out JsonElement versionElement) && versionElement.ValueKind != JsonValueKind.Null;
        if (origin == ActionCapabilityOrigins.BuiltIn)
        {
            if (versionPolicy is not (WorkflowActionVersionPolicies.Shipped or WorkflowActionVersionPolicies.Exact))
                throw new InvalidOperationException($"{path}.actionRef.versionPolicy for Built-in Actions must be 'Shipped' or 'Exact'.");
            if (versionPolicy == WorkflowActionVersionPolicies.Exact)
                _ = RequiredInt(actionRef, "version", $"{path}.actionRef", 1, int.MaxValue);
            else if (hasVersion)
                throw new InvalidOperationException($"{path}.actionRef.version is not allowed when Built-in versionPolicy is 'Shipped'.");
        }
        else
        {
            if (versionPolicy is not (WorkflowActionVersionPolicies.Current or WorkflowActionVersionPolicies.Exact))
                throw new InvalidOperationException($"{path}.actionRef.versionPolicy for User Actions must be 'Current' or 'Exact'.");
            if (versionPolicy == WorkflowActionVersionPolicies.Exact)
                _ = RequiredInt(actionRef, "version", $"{path}.actionRef", 1, int.MaxValue);
            else if (hasVersion)
                throw new InvalidOperationException($"{path}.actionRef.version is not allowed when User Action versionPolicy is 'Current'.");
        }

        JsonElement inputs = RequiredObject(node, "inputs", path);
        if (inputs.EnumerateObject().Count() > 100)
            throw new InvalidOperationException($"{path}.inputs may contain at most 100 bindings.");
        foreach (JsonProperty binding in inputs.EnumerateObject())
            ValidatePatchBinding(binding.Value, $"{path}.inputs.{binding.Name}");

        if (node.TryGetProperty("continuePolicy", out JsonElement continuePolicy) && continuePolicy.ValueKind != JsonValueKind.Null)
        {
            string value = continuePolicy.GetString() ?? string.Empty;
            if (value is not ("FailWorkflow" or "FollowFailureEdge"))
                throw new InvalidOperationException($"{path}.continuePolicy must be 'FailWorkflow' or 'FollowFailureEdge'.");
        }
        if (node.TryGetProperty("disabled", out JsonElement disabled) && disabled.ValueKind is not (JsonValueKind.True or JsonValueKind.False))
            throw new InvalidOperationException($"{path}.disabled must be Boolean.");
        _ = OptionalString(node, "notes", 4000);
        if (node.TryGetProperty("session", out JsonElement session) && session.ValueKind is not (JsonValueKind.Object or JsonValueKind.Null))
            throw new InvalidOperationException($"{path}.session must be an object when supplied.");
        if (node.TryGetProperty("executionPolicy", out JsonElement executionPolicy) && executionPolicy.ValueKind is not (JsonValueKind.Object or JsonValueKind.Null))
            throw new InvalidOperationException($"{path}.executionPolicy must be an object when supplied.");
        if (node.TryGetProperty("retryPolicy", out JsonElement retryPolicy) && retryPolicy.ValueKind is not (JsonValueKind.Object or JsonValueKind.Null))
            throw new InvalidOperationException($"{path}.retryPolicy must be an object when supplied.");
        if (node.TryGetProperty("timeoutSeconds", out JsonElement timeout) && (timeout.ValueKind != JsonValueKind.Number || !timeout.TryGetInt32(out int timeoutSeconds) || timeoutSeconds is < 1 or > 86400))
            throw new InvalidOperationException($"{path}.timeoutSeconds must be an integer from 1 to 86400 when supplied.");
    }

    private static void ValidatePatchBinding(JsonElement binding, string path)
    {
        if (binding.ValueKind != JsonValueKind.Object)
            throw new InvalidOperationException($"{path} must be a binding object.");
        string kind = RequiredString(binding, "kind", path, 50);
        if (!WorkflowBindingKinds.All.Contains(kind))
            throw new InvalidOperationException($"{path}.kind '{kind}' is not supported.");
        switch (kind)
        {
            case WorkflowBindingKinds.Literal:
                EnsureOnlyProperties(binding, "kind", "value");
                if (!binding.TryGetProperty("value", out _)) throw new InvalidOperationException($"{path}.value is required.");
                break;
            case WorkflowBindingKinds.ProjectVariable:
            case WorkflowBindingKinds.SecretReference:
                EnsureOnlyProperties(binding, "kind", "key");
                _ = RequiredString(binding, "key", path, 150);
                break;
            case WorkflowBindingKinds.WorkflowInput:
            case WorkflowBindingKinds.WorkflowDefault:
            case WorkflowBindingKinds.RuntimeValue:
                EnsureOnlyProperties(binding, "kind", "name");
                _ = RequiredString(binding, "name", path, 150);
                break;
            case WorkflowBindingKinds.NodeOutput:
                EnsureOnlyProperties(binding, "kind", "nodeId", "outputName");
                _ = NormalizeNodeId(RequiredString(binding, "nodeId", path, 100), $"{path}.nodeId");
                _ = RequiredString(binding, "outputName", path, 150);
                break;
        }
    }

    private static JsonObject? ParseGraphPatchUi(JsonElement node, string path)
    {
        if (!node.TryGetProperty("ui", out JsonElement ui) || ui.ValueKind == JsonValueKind.Null)
            return null;
        if (ui.ValueKind != JsonValueKind.Object)
            throw new InvalidOperationException($"{path}.ui must be an object when supplied.");
        EnsureOnlyProperties(ui, "x", "y", "collapsed", "lane");
        decimal x = 0;
        decimal y = 0;
        if (!ui.TryGetProperty("x", out JsonElement xElement) || xElement.ValueKind != JsonValueKind.Number || !xElement.TryGetDecimal(out x) || x is < -1000000 or > 1000000)
            throw new InvalidOperationException($"{path}.ui.x must be a number between -1000000 and 1000000.");
        if (!ui.TryGetProperty("y", out JsonElement yElement) || yElement.ValueKind != JsonValueKind.Number || !yElement.TryGetDecimal(out y) || y is < -1000000 or > 1000000)
            throw new InvalidOperationException($"{path}.ui.y must be a number between -1000000 and 1000000.");
        bool collapsed = false;
        if (ui.TryGetProperty("collapsed", out JsonElement collapsedElement))
        {
            if (collapsedElement.ValueKind is not (JsonValueKind.True or JsonValueKind.False))
                throw new InvalidOperationException($"{path}.ui.collapsed must be Boolean.");
            collapsed = collapsedElement.GetBoolean();
        }
        string lane = OptionalString(ui, "lane", 100) ?? "main";
        return new JsonObject
        {
            ["x"] = x,
            ["y"] = y,
            ["collapsed"] = collapsed,
            ["lane"] = lane
        };
    }

    private static void ValidatePatchConditionBindings(JsonElement node, string path, bool isLoop)
    {
        JsonElement left = RequiredObject(node, "left", path);
        EnsureOnlyProperties(left, "kind", "nodeId", "outputName");
        if (!string.Equals(RequiredString(left, "kind", $"{path}.left", 50), WorkflowBindingKinds.NodeOutput, StringComparison.Ordinal))
            throw new InvalidOperationException($"{path}.left.kind must be 'NodeOutput'.");
        _ = NormalizeNodeId(RequiredString(left, "nodeId", $"{path}.left", 100), $"{path}.left.nodeId");
        _ = RequiredString(left, "outputName", $"{path}.left", 100);
        string conditionOperator = RequiredMember(node, "operator", WorkflowConditionOperators.All, path);
        bool unary = WorkflowConditionOperators.Unary.Contains(conditionOperator);
        if (node.TryGetProperty("right", out JsonElement right) && right.ValueKind != JsonValueKind.Null)
        {
            if (unary) throw new InvalidOperationException($"{path}.right is not allowed for unary operator '{conditionOperator}'.");
            if (right.ValueKind != JsonValueKind.Object) throw new InvalidOperationException($"{path}.right must be a Literal binding object.");
            string rightKind = RequiredString(right, "kind", $"{path}.right", 50);
            if (!string.Equals(rightKind, WorkflowBindingKinds.Literal, StringComparison.Ordinal))
                throw new InvalidOperationException($"{path}.right.kind must be 'Literal'. SecretReference values are not accepted by the agent graph-patch contract.");
            EnsureOnlyProperties(right, "kind", "value");
            if (!right.TryGetProperty("value", out _)) throw new InvalidOperationException($"{path}.right.value is required.");
        }
        else if (!unary)
        {
            throw new InvalidOperationException($"{path}.right is required for operator '{conditionOperator}'.");
        }
        _ = isLoop;
    }

    private static ParsedAction ParseAction(JsonElement action)
    {
        string mode = RequiredString(action, "mode", "$.action", 20);
        if (!WorkflowAssemblyActionModes.All.Contains(mode))
            throw new InvalidOperationException($"Unsupported action.mode '{mode}'.");
        string actionId = ProjectAction.NormalizeKey(RequiredString(action, "actionId", "$.action", 200));

        if (mode == WorkflowAssemblyActionModes.UseExact)
        {
            EnsureOnlyProperties(action, "mode", "actionId", "version");
            int version = RequiredInt(action, "version", "$.action", 1, int.MaxValue);
            return ParsedAction.UseExact(actionId, version);
        }

        EnsureOnlyProperties(action,
            "mode", "actionId", "displayName", "description", "category", "engine", "entryPoint", "keyword",
            "sessionBehavior", "timeoutSeconds", "evidenceOnPass", "evidenceOnFailure", "sideEffectKind",
            "cleanupPolicy", "isReplaySafe", "executionPolicy", "inputs", "outputs", "dependencies", "sourceText");
        string displayName = RequiredString(action, "displayName", "$.action", 250);
        string? description = OptionalString(action, "description", 4000);
        string category = RequiredString(action, "category", "$.action", 100);
        string engine = RequiredMember(action, "engine", ActionEngines.All, "$.action");
        string entryPoint = RequiredString(action, "entryPoint", "$.action", 500).Replace('\\', '/');
        string? keyword = OptionalString(action, "keyword", 250);
        string sessionBehavior = RequiredMember(action, "sessionBehavior", ActionSessionBehaviors.All, "$.action");
        int timeoutSeconds = RequiredInt(action, "timeoutSeconds", "$.action", 1, 86400);
        string evidenceOnPass = RequiredMember(action, "evidenceOnPass", ActionEvidenceModes.All, "$.action");
        string evidenceOnFailure = RequiredMember(action, "evidenceOnFailure", ActionEvidenceModes.All, "$.action");
        string sideEffectKind = RequiredMember(action, "sideEffectKind", ActionSideEffectKinds.All, "$.action");
        string cleanupPolicy = RequiredMember(action, "cleanupPolicy", ActionCleanupPolicies.All, "$.action");
        bool isReplaySafe = RequiredBoolean(action, "isReplaySafe", "$.action");
        ActionExecutionPolicyContract executionPolicy = ParseExecutionPolicy(action, timeoutSeconds);
        IReadOnlyList<ActionValueDefinitionInput> inputs = ParseValues(action, "inputs", isOutput: false);
        IReadOnlyList<ActionValueDefinitionInput> outputs = ParseValues(action, "outputs", isOutput: true);
        IReadOnlyList<ActionDependencyInput> dependencies = ParseDependencies(action);
        string sourceText = RequiredRawString(action, "sourceText", "$.action", MaximumSourceBytes);
        return ParsedAction.Create(actionId, displayName, description, category, engine, entryPoint, keyword,
            sessionBehavior, timeoutSeconds, evidenceOnPass, evidenceOnFailure, sideEffectKind, cleanupPolicy,
            isReplaySafe, executionPolicy, inputs, outputs, dependencies, sourceText);
    }

    private static ActionExecutionPolicyContract ParseExecutionPolicy(JsonElement action, int timeoutSeconds)
    {
        if (!action.TryGetProperty("executionPolicy", out JsonElement policy) || policy.ValueKind == JsonValueKind.Null)
            return ActionExecutionPolicyContract.SingleAttempt(timeoutSeconds);
        if (policy.ValueKind != JsonValueKind.Object)
            throw new InvalidOperationException("action.executionPolicy must be an object.");
        string wrapper = new JsonObject { ["executionPolicy"] = JsonNode.Parse(policy.GetRawText()) }.ToJsonString();
        return ActionExecutionPolicyRules.ParseContract(wrapper, timeoutSeconds);
    }

    private static IReadOnlyList<ActionValueDefinitionInput> ParseValues(JsonElement action, string propertyName, bool isOutput)
    {
        if (!action.TryGetProperty(propertyName, out JsonElement array) || array.ValueKind != JsonValueKind.Array)
            throw new InvalidOperationException($"$.action.{propertyName} must be an array.");
        var result = new List<ActionValueDefinitionInput>();
        int index = 0;
        foreach (JsonElement item in array.EnumerateArray())
        {
            string path = $"$.action.{propertyName}[{index++}]";
            if (item.ValueKind != JsonValueKind.Object) throw new InvalidOperationException($"{path} must be an object.");
            EnsureOnlyProperties(item,
                "name", "displayName", "dataType", "format", "isRequired", "classification", "defaultValue",
                "allowedBindingKinds", "validation", "uiHints", "uiGroup", "uiOrder", "isAdvanced",
                "persistInResult", "description");
            string name = RequiredString(item, "name", path, 150);
            string displayName = OptionalString(item, "displayName", 250) ?? name;
            string dataType = RequiredString(item, "dataType", path, 100);
            string? format = OptionalString(item, "format", 100);
            bool isRequired = RequiredBoolean(item, "isRequired", path);
            string classification = RequiredString(item, "classification", path, 50);
            bool isSecret = !isOutput && classification == ActionInputClassifications.Secret;
            string? defaultValueJson = item.TryGetProperty("defaultValue", out JsonElement defaultValue) && defaultValue.ValueKind != JsonValueKind.Null
                ? defaultValue.GetRawText()
                : null;
            string? allowedBindingsJson = item.TryGetProperty("allowedBindingKinds", out JsonElement bindings) && bindings.ValueKind != JsonValueKind.Null
                ? bindings.GetRawText()
                : null;
            string? validationJson = item.TryGetProperty("validation", out JsonElement validation) && validation.ValueKind != JsonValueKind.Null
                ? validation.GetRawText()
                : null;
            string? uiHintsJson = item.TryGetProperty("uiHints", out JsonElement uiHints) && uiHints.ValueKind != JsonValueKind.Null
                ? uiHints.GetRawText()
                : null;
            string? uiGroup = OptionalString(item, "uiGroup", 100);
            int uiOrder = item.TryGetProperty("uiOrder", out JsonElement order) && order.ValueKind == JsonValueKind.Number && order.TryGetInt32(out int parsedOrder)
                ? parsedOrder
                : 0;
            bool isAdvanced = item.TryGetProperty("isAdvanced", out JsonElement advanced) && advanced.ValueKind == JsonValueKind.True;
            bool persist = !isOutput || !item.TryGetProperty("persistInResult", out JsonElement persistElement) || persistElement.ValueKind != JsonValueKind.False;
            string? description = OptionalString(item, "description", 2000);
            result.Add(new ActionValueDefinitionInput(
                name, dataType, isRequired, isSecret, description, displayName, format, classification,
                defaultValueJson, allowedBindingsJson, validationJson, uiHintsJson, uiGroup, uiOrder,
                isAdvanced, persist));
        }
        return result;
    }

    private static IReadOnlyList<ActionDependencyInput> ParseDependencies(JsonElement action)
    {
        if (!action.TryGetProperty("dependencies", out JsonElement array) || array.ValueKind != JsonValueKind.Array)
            throw new InvalidOperationException("$.action.dependencies must be an array.");
        var result = new List<ActionDependencyInput>();
        int index = 0;
        foreach (JsonElement item in array.EnumerateArray())
        {
            string path = $"$.action.dependencies[{index++}]";
            if (item.ValueKind != JsonValueKind.Object) throw new InvalidOperationException($"{path} must be an object.");
            EnsureOnlyProperties(item, "actionId", "kind", "isRequired", "description");
            result.Add(new ActionDependencyInput(
                ProjectAction.NormalizeKey(RequiredString(item, "actionId", path, 200)),
                RequiredMember(item, "kind", ActionDependencyKinds.All, path),
                RequiredBoolean(item, "isRequired", path),
                OptionalString(item, "description", 2000)));
        }
        return result;
    }

    private static string RequiredMember(JsonElement parent, string propertyName, IReadOnlySet<string> allowed, string path)
    {
        string value = RequiredString(parent, propertyName, path, 100);
        return allowed.Contains(value)
            ? value
            : throw new InvalidOperationException($"{path}.{propertyName} contains unsupported value '{value}'.");
    }

    private static JsonElement RequiredArray(JsonElement parent, string propertyName, string path)
    {
        if (!parent.TryGetProperty(propertyName, out JsonElement value) || value.ValueKind != JsonValueKind.Array)
            throw new InvalidOperationException($"{path}.{propertyName} must be an array.");
        return value;
    }

    private static JsonElement RequiredObject(JsonElement parent, string propertyName, string path)
    {
        if (!parent.TryGetProperty(propertyName, out JsonElement value) || value.ValueKind != JsonValueKind.Object)
            throw new InvalidOperationException($"{path}.{propertyName} must be an object.");
        return value;
    }

    private static string RequiredString(JsonElement parent, string propertyName, string path, int maxLength)
    {
        if (!parent.TryGetProperty(propertyName, out JsonElement value) || value.ValueKind != JsonValueKind.String)
            throw new InvalidOperationException($"{path}.{propertyName} is required and must be a string.");
        string result = value.GetString()?.Trim() ?? string.Empty;
        if (result.Length == 0) throw new InvalidOperationException($"{path}.{propertyName} is required.");
        if (Encoding.UTF8.GetByteCount(result) > maxLength && maxLength >= MaximumSourceBytes)
            throw new InvalidOperationException($"{path}.{propertyName} exceeds the {maxLength}-byte limit.");
        if (result.Length > maxLength && maxLength < MaximumSourceBytes)
            throw new InvalidOperationException($"{path}.{propertyName} may not exceed {maxLength} characters.");
        return result;
    }

    private static string RequiredRawString(JsonElement parent, string propertyName, string path, int maximumBytes)
    {
        if (!parent.TryGetProperty(propertyName, out JsonElement value) || value.ValueKind != JsonValueKind.String)
            throw new InvalidOperationException($"{path}.{propertyName} is required and must be a string.");
        string result = value.GetString() ?? string.Empty;
        if (string.IsNullOrWhiteSpace(result))
            throw new InvalidOperationException($"{path}.{propertyName} is required.");
        if (Encoding.UTF8.GetByteCount(result) > maximumBytes)
            throw new InvalidOperationException($"{path}.{propertyName} exceeds the {maximumBytes}-byte limit.");
        return result;
    }

    private static string? OptionalString(JsonElement parent, string propertyName, int maxLength)
    {
        if (!parent.TryGetProperty(propertyName, out JsonElement value) || value.ValueKind == JsonValueKind.Null) return null;
        if (value.ValueKind != JsonValueKind.String) throw new InvalidOperationException($"{propertyName} must be a string or null.");
        string? result = value.GetString()?.Trim();
        if (string.IsNullOrWhiteSpace(result)) return null;
        if (result.Length > maxLength) throw new InvalidOperationException($"{propertyName} may not exceed {maxLength} characters.");
        return result;
    }

    private static int RequiredInt(JsonElement parent, string propertyName, string path, int min, int max)
    {
        if (!parent.TryGetProperty(propertyName, out JsonElement value) || value.ValueKind != JsonValueKind.Number || !value.TryGetInt32(out int result))
            throw new InvalidOperationException($"{path}.{propertyName} is required and must be an integer.");
        if (result < min || result > max) throw new InvalidOperationException($"{path}.{propertyName} must be between {min} and {max}.");
        return result;
    }

    private static bool RequiredBoolean(JsonElement parent, string propertyName, string path)
    {
        if (!parent.TryGetProperty(propertyName, out JsonElement value) || value.ValueKind is not (JsonValueKind.True or JsonValueKind.False))
            throw new InvalidOperationException($"{path}.{propertyName} is required and must be boolean.");
        return value.GetBoolean();
    }

    private static void EnsureOnlyProperties(JsonElement parent, params string[] allowed)
    {
        HashSet<string> set = allowed.ToHashSet(StringComparer.Ordinal);
        string? unknown = parent.EnumerateObject().Select(property => property.Name).FirstOrDefault(name => !set.Contains(name));
        if (unknown is not null) throw new InvalidOperationException($"Unsupported property '{unknown}' was found in Workflow assembly JSON.");
    }

    private static string NormalizeOperationId(string value)
    {
        string trimmed = value.Trim();
        string normalized = trimmed.ToLowerInvariant();
        if (!string.Equals(trimmed, normalized, StringComparison.Ordinal) ||
            normalized.Length is < 1 or > 200 ||
            !char.IsLetterOrDigit(normalized[0]) ||
            normalized.Any(character => !(char.IsLetterOrDigit(character) || character is '.' or '_' or '-')))
        {
            throw new InvalidOperationException(
                "operationId must already be lowercase, start with a letter or number, and contain only letters, numbers, '.', '_' or '-'.");
        }
        return normalized;
    }

    private static string NormalizeKey(string value, string label)
    {
        string normalized = value.Trim().ToLowerInvariant();
        if (normalized.Length == 0) throw new InvalidOperationException($"{label} is required.");
        return normalized;
    }

    private static string NormalizeNodeId(string value, string label)
    {
        try
        {
            return ProjectTestDraftRevisionNode.NormalizeKey(value);
        }
        catch (ArgumentException exception)
        {
            throw new InvalidOperationException($"{label} is invalid. {exception.Message}", exception);
        }
    }

    private static string NormalizeHash(string value)
    {
        string normalized = value.Trim().ToLowerInvariant();
        if (normalized.Length != 64 || normalized.Any(character => !Uri.IsHexDigit(character)))
            throw new InvalidOperationException("expectedWorkflowSha256 must be a 64-character hexadecimal SHA-256.");
        return normalized;
    }

    private static WorkflowDraftValidationIssue Error(string code, string path, string message) =>
        new(TestValidationSeverities.Error, code, path, message);

    private static WorkflowDraftValidationIssue Info(string code, string path, string message) =>
        new("Info", code, path, message);

    private abstract record ParsedAssemblyPackage(
        int SchemaVersion,
        string DefinitionType,
        string OperationId,
        string ProjectKey,
        string WorkflowId,
        string? EnvironmentKey,
        string NormalizedJson);

    private sealed record ParsedWorkflowSeed(
        int SchemaVersion,
        string DefinitionType,
        string OperationId,
        string ProjectKey,
        string WorkflowId,
        string? EnvironmentKey,
        string NormalizedJson,
        string DisplayName,
        string? Description)
        : ParsedAssemblyPackage(SchemaVersion, DefinitionType, OperationId, ProjectKey, WorkflowId, EnvironmentKey, NormalizedJson);

    private sealed record ParsedActionAppend(
        int SchemaVersion,
        string DefinitionType,
        string OperationId,
        string ProjectKey,
        string WorkflowId,
        string? EnvironmentKey,
        string NormalizedJson,
        int ExpectedRevisionNumber,
        string ExpectedDefinitionSha256,
        string InsertAfterNodeId,
        string NewNodeId,
        string NodeDisplayName,
        string? NodeDescription,
        JsonObject NodeInputs,
        JsonObject? NodeExecutionPolicy,
        ParsedAction Action)
        : ParsedAssemblyPackage(SchemaVersion, DefinitionType, OperationId, ProjectKey, WorkflowId, EnvironmentKey, NormalizedJson);

    private sealed record ParsedSystemNodeAppend(
        int SchemaVersion,
        string DefinitionType,
        string OperationId,
        string ProjectKey,
        string WorkflowId,
        string? EnvironmentKey,
        string NormalizedJson,
        int ExpectedRevisionNumber,
        string ExpectedDefinitionSha256,
        string InsertAfterNodeId,
        string NewNodeId,
        string NodeDisplayName,
        string? NodeDescription,
        JsonObject Left,
        string Operator,
        JsonObject? Right,
        string TrueTargetNodeId,
        string FalseTargetNodeId,
        string? TrueLabel,
        string? FalseLabel)
        : ParsedAssemblyPackage(SchemaVersion, DefinitionType, OperationId, ProjectKey, WorkflowId, EnvironmentKey, NormalizedJson);

    private sealed record AssemblyBaseResolution(
        WorkflowDraftRevisionDetails? BaseRevision,
        bool ExactTargetMatch,
        bool IsCrossWorkflow,
        string TargetWorkflowId,
        string OriginWorkflowId);

    private sealed record SuccessConnection(string EdgeId, string ToNodeId, int Priority, string? Label)
    {
        public bool SemanticallyEquals(SuccessConnection other) =>
            string.Equals(EdgeId, other.EdgeId, StringComparison.Ordinal) &&
            string.Equals(ToNodeId, other.ToNodeId, StringComparison.Ordinal) &&
            Priority == other.Priority &&
            string.Equals(Label, other.Label, StringComparison.Ordinal);
    }

    private sealed record ParsedEdgeRemoval(string EdgeId, string FromNodeId, string ToNodeId, string When);

    private sealed record ParsedNodeRemoval(string NodeId, string Type);

    private sealed record ParsedGraphPatchNode(JsonObject Node, JsonObject? Ui);

    private sealed record ParsedNodeInputUpdate(string NodeId, string? ExpectedActionId, JsonObject Inputs);

    private sealed record ParsedCleanupGraphPatch(
        bool HasStartNodeIdChange,
        string? StartNodeId,
        bool HasFailurePolicyChange,
        string? FailurePolicy,
        IReadOnlyList<ParsedGraphPatchNode> NodesToAdd,
        IReadOnlyList<ParsedNodeRemoval> NodesToRemove,
        IReadOnlyList<ParsedEdgeRemoval> EdgesToRemove,
        IReadOnlyList<JsonObject> EdgesToAdd)
    {
        public bool HasChanges =>
            HasStartNodeIdChange || HasFailurePolicyChange || NodesToAdd.Count > 0 || NodesToRemove.Count > 0 || EdgesToRemove.Count > 0 || EdgesToAdd.Count > 0;
    }

    private sealed record ParsedGraphPatch(
        int SchemaVersion,
        string DefinitionType,
        string OperationId,
        string ProjectKey,
        string WorkflowId,
        string? EnvironmentKey,
        string NormalizedJson,
        int ExpectedRevisionNumber,
        string ExpectedDefinitionSha256,
        bool HasDisplayNameChange,
        string? DisplayName,
        bool HasDescriptionChange,
        string? Description,
        JsonArray? WorkflowInputs,
        JsonArray? WorkflowOutputs,
        IReadOnlyList<ParsedGraphPatchNode> NodesToAdd,
        IReadOnlyList<ParsedNodeInputUpdate> NodeInputUpdates,
        IReadOnlyList<ParsedNodeRemoval> NodesToRemove,
        IReadOnlyList<ParsedEdgeRemoval> EdgesToRemove,
        IReadOnlyList<JsonObject> EdgesToAdd,
        ParsedCleanupGraphPatch? Cleanup)
        : ParsedAssemblyPackage(SchemaVersion, DefinitionType, OperationId, ProjectKey, WorkflowId, EnvironmentKey, NormalizedJson)
    {
        public string? FirstNewNodeId => NodesToAdd.Count > 0
            ? (string?)NodesToAdd[0].Node["nodeId"]
            : Cleanup?.NodesToAdd.Count > 0 ? (string?)Cleanup.NodesToAdd[0].Node["nodeId"] : null;
        public bool HasCleanupChanges => Cleanup?.HasChanges ?? false;
        public bool HasDefinitionContractChanges =>
            HasDisplayNameChange || HasDescriptionChange || WorkflowInputs is not null || WorkflowOutputs is not null;
    }

    private sealed record ParsedAction(
        string Mode,
        string ActionId,
        int? ExactVersion,
        string? DisplayName,
        string? Description,
        string? Category,
        string? Engine,
        string? EntryPoint,
        string? Keyword,
        string? SessionBehavior,
        int TimeoutSeconds,
        string? EvidenceOnPass,
        string? EvidenceOnFailure,
        string? SideEffectKind,
        string? CleanupPolicy,
        bool IsReplaySafe,
        ActionExecutionPolicyContract? ExecutionPolicy,
        IReadOnlyList<ActionValueDefinitionInput> Inputs,
        IReadOnlyList<ActionValueDefinitionInput> Outputs,
        IReadOnlyList<ActionDependencyInput> Dependencies,
        string? SourceText)
    {
        public static ParsedAction UseExact(string actionId, int version) => new(
            WorkflowAssemblyActionModes.UseExact, actionId, version, null, null, null, null, null, null, null,
            1, null, null, null, null, false, null, [], [], [], null);

        public static ParsedAction Create(
            string actionId,
            string displayName,
            string? description,
            string category,
            string engine,
            string entryPoint,
            string? keyword,
            string sessionBehavior,
            int timeoutSeconds,
            string evidenceOnPass,
            string evidenceOnFailure,
            string sideEffectKind,
            string cleanupPolicy,
            bool isReplaySafe,
            ActionExecutionPolicyContract executionPolicy,
            IReadOnlyList<ActionValueDefinitionInput> inputs,
            IReadOnlyList<ActionValueDefinitionInput> outputs,
            IReadOnlyList<ActionDependencyInput> dependencies,
            string sourceText) => new(
                WorkflowAssemblyActionModes.Create, actionId, null, displayName, description, category, engine,
                entryPoint, keyword, sessionBehavior, timeoutSeconds, evidenceOnPass, evidenceOnFailure,
                sideEffectKind, cleanupPolicy, isReplaySafe, executionPolicy, inputs, outputs, dependencies, sourceText);

        public CreateActionDraftRequest ToCreateRequest(Guid projectId, Guid actorUserId, DateTime createdAtUtc)
        {
            if (Mode != WorkflowAssemblyActionModes.Create)
                throw new InvalidOperationException("Only Create mode can build a new Action request.");
            return new CreateActionDraftRequest(
                projectId,
                ActionId,
                DisplayName!,
                Description,
                Category!,
                Engine!,
                EntryPoint!,
                Keyword,
                SessionBehavior!,
                TimeoutSeconds,
                EvidenceOnPass!,
                EvidenceOnFailure!,
                SideEffectKind!,
                CleanupPolicy!,
                IsReplaySafe,
                ExecutionPolicy!,
                Inputs,
                Outputs,
                Dependencies,
                actorUserId,
                createdAtUtc);
        }
    }

    private sealed record ActionVersionLookup(Guid ActionId, Guid VersionId, int VersionNumber);
    private sealed record PortableCreateReuse(ActionLibraryDetails Action, ActionVersionSummary Version);
}
