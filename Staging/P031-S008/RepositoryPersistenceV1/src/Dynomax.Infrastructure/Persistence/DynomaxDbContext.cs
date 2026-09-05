using Dynomax.Domain.Auditing;
using Dynomax.Domain.Apps;
using Dynomax.Domain.Automation;
using Dynomax.Domain.ChangeManagement;
using Dynomax.Domain.Organizations;
using Dynomax.Domain.Projects;
using Dynomax.Domain.ProjectContext;
using Dynomax.Domain.Projects.Configuration;
using Dynomax.Domain.Runners;
using Dynomax.Domain.Security;
using Dynomax.Domain.Testing.Actions;
using Dynomax.Domain.Testing.Scheduling;
using Dynomax.Domain.Testing.Tests;
using Dynomax.Domain.Testing.Workflows;
using Dynomax.Infrastructure.Identity;
using Microsoft.AspNetCore.Identity;
using Microsoft.AspNetCore.Identity.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore;

namespace Dynomax.Infrastructure.Persistence;

public sealed class DynomaxDbContext
    : IdentityDbContext<ApplicationUser, IdentityRole<Guid>, Guid>
{
    public DynomaxDbContext(DbContextOptions<DynomaxDbContext> options)
        : base(options)
    {
    }

    public DbSet<Organization> Organizations => Set<Organization>();
    public DbSet<OrganizationMembership> OrganizationMemberships => Set<OrganizationMembership>();
    public DbSet<Project> Projects => Set<Project>();
    public DbSet<ProjectContextSource> ProjectContextSources => Set<ProjectContextSource>();
    public DbSet<ProjectContextResource> ProjectContextResources => Set<ProjectContextResource>();
    public DbSet<ProjectContextResourceVersion> ProjectContextResourceVersions => Set<ProjectContextResourceVersion>();
    public DbSet<ProjectContextArchiveEntry> ProjectContextArchiveEntries => Set<ProjectContextArchiveEntry>();
    public DbSet<ProjectContextRepository> ProjectContextRepositories => Set<ProjectContextRepository>();
    public DbSet<ProjectContextRepositoryPolicy> ProjectContextRepositoryPolicies => Set<ProjectContextRepositoryPolicy>();
    public DbSet<RepositoryWorkSet> RepositoryWorkSets => Set<RepositoryWorkSet>();
    public DbSet<RepositoryWorkspace> RepositoryWorkspaces => Set<RepositoryWorkspace>();
    public DbSet<RepositoryPullRequestLink> RepositoryPullRequestLinks => Set<RepositoryPullRequestLink>();
    public DbSet<ProjectApp> ProjectApps => Set<ProjectApp>();
    public DbSet<ProjectAppRevision> ProjectAppRevisions => Set<ProjectAppRevision>();
    public DbSet<ProjectAppExecution> ProjectAppExecutions => Set<ProjectAppExecution>();
    public DbSet<ProjectEnvironment> ProjectEnvironments => Set<ProjectEnvironment>();
    public DbSet<ProjectAllowedHost> ProjectAllowedHosts => Set<ProjectAllowedHost>();
    public DbSet<ProjectVariable> ProjectVariables => Set<ProjectVariable>();
    public DbSet<ProjectSecretReference> ProjectSecretReferences => Set<ProjectSecretReference>();
    public DbSet<ProjectAccessGrant> ProjectAccessGrants => Set<ProjectAccessGrant>();
    public DbSet<ProjectActionGroup> ProjectActionGroups => Set<ProjectActionGroup>();
    public DbSet<ProjectAction> ProjectActions => Set<ProjectAction>();
    public DbSet<ProjectActionVersion> ProjectActionVersions => Set<ProjectActionVersion>();
    public DbSet<ProjectActionCoreMapping> ProjectActionCoreMappings => Set<ProjectActionCoreMapping>();
    public DbSet<ProjectActionSourcePackage> ProjectActionSourcePackages => Set<ProjectActionSourcePackage>();
    public DbSet<ProjectActionInputDefinition> ProjectActionInputs => Set<ProjectActionInputDefinition>();
    public DbSet<ProjectActionOutputDefinition> ProjectActionOutputs => Set<ProjectActionOutputDefinition>();
    public DbSet<ProjectActionDependency> ProjectActionDependencies => Set<ProjectActionDependency>();
    public DbSet<ProjectTestDefinition> ProjectTestDefinitions => Set<ProjectTestDefinition>();
    public DbSet<ProjectTestVersion> ProjectTestVersions => Set<ProjectTestVersion>();
    public DbSet<ProjectTestStep> ProjectTestSteps => Set<ProjectTestStep>();
    public DbSet<ProjectTestStepBinding> ProjectTestStepBindings => Set<ProjectTestStepBinding>();
    public DbSet<ProjectTestAdaptiveCheckpoint> ProjectTestAdaptiveCheckpoints => Set<ProjectTestAdaptiveCheckpoint>();
    public DbSet<ProjectTestDraft> ProjectTestDrafts => Set<ProjectTestDraft>();
    public DbSet<ProjectTestDraftRevision> ProjectTestDraftRevisions => Set<ProjectTestDraftRevision>();
    public DbSet<ProjectTestDraftRevisionNode> ProjectTestDraftRevisionNodes => Set<ProjectTestDraftRevisionNode>();
    public DbSet<ProjectTestDraftRevisionEdge> ProjectTestDraftRevisionEdges => Set<ProjectTestDraftRevisionEdge>();
    public DbSet<ProjectTestDraftRevisionBinding> ProjectTestDraftRevisionBindings => Set<ProjectTestDraftRevisionBinding>();
    public DbSet<ProjectTestDraftRevisionUiNode> ProjectTestDraftRevisionUiNodes => Set<ProjectTestDraftRevisionUiNode>();
    public DbSet<ProjectTestDraftRevisionInput> ProjectTestDraftRevisionInputs => Set<ProjectTestDraftRevisionInput>();
    public DbSet<ProjectTestDraftRevisionOutput> ProjectTestDraftRevisionOutputs => Set<ProjectTestDraftRevisionOutput>();
    public DbSet<ProjectWorkflowEnvironment> ProjectWorkflowEnvironments => Set<ProjectWorkflowEnvironment>();
    public DbSet<ProjectWorkflowCompilation> ProjectWorkflowCompilations => Set<ProjectWorkflowCompilation>();
    public DbSet<ProjectWorkflowCompilationPublication> ProjectWorkflowCompilationPublications => Set<ProjectWorkflowCompilationPublication>();
    public DbSet<ProjectWorkflowFavorite> ProjectWorkflowFavorites => Set<ProjectWorkflowFavorite>();
    public DbSet<BusinessCalendar> BusinessCalendars => Set<BusinessCalendar>();
    public DbSet<BusinessCalendarRevision> BusinessCalendarRevisions => Set<BusinessCalendarRevision>();
    public DbSet<BusinessCalendarDate> BusinessCalendarDates => Set<BusinessCalendarDate>();
    public DbSet<WorkflowSchedule> WorkflowSchedules => Set<WorkflowSchedule>();
    public DbSet<WorkflowScheduleOccurrence> WorkflowScheduleOccurrences => Set<WorkflowScheduleOccurrence>();
    public DbSet<AuditEvent> AuditEvents => Set<AuditEvent>();
    public DbSet<RunnerRegistration> RunnerRegistrations => Set<RunnerRegistration>();
    public DbSet<AutomationRuntimeSettings> AutomationRuntimeSettings => Set<AutomationRuntimeSettings>();
    public DbSet<AgentAccessGrant> AgentAccessGrants => Set<AgentAccessGrant>();
    public DbSet<AgentAutomationSession> AgentAutomationSessions => Set<AgentAutomationSession>();
    public DbSet<AgentAutomationCandidate> AgentAutomationCandidates => Set<AgentAutomationCandidate>();
    public DbSet<AgentAutomationApproval> AgentAutomationApprovals => Set<AgentAutomationApproval>();
    public DbSet<AgentIdempotencyRecord> AgentIdempotencyRecords => Set<AgentIdempotencyRecord>();
    public DbSet<AgentArtifact> AgentArtifacts => Set<AgentArtifact>();
    public DbSet<AgentArtifactContent> AgentArtifactContents => Set<AgentArtifactContent>();
    public DbSet<AgentApiActivity> AgentApiActivities => Set<AgentApiActivity>();
    public DbSet<AutomationLifecycleEvent> AutomationLifecycleEvents => Set<AutomationLifecycleEvent>();
    public DbSet<PlatformIncident> PlatformIncidents => Set<PlatformIncident>();
    public DbSet<AgentIssueRequest> AgentIssueRequests => Set<AgentIssueRequest>();
    public DbSet<AgentIssueHistory> AgentIssueHistory => Set<AgentIssueHistory>();
    public DbSet<ProductChangeLog> ProductChangeLogs => Set<ProductChangeLog>();
    public DbSet<ChangeManagementApplication> ChangeManagementApplications => Set<ChangeManagementApplication>();
    public DbSet<ChangeManagementRelease> ChangeManagementReleases => Set<ChangeManagementRelease>();
    public DbSet<ChangeManagementBuild> ChangeManagementBuilds => Set<ChangeManagementBuild>();
    public DbSet<ChangeManagementBuildDeployment> ChangeManagementBuildDeployments => Set<ChangeManagementBuildDeployment>();
    public DbSet<ProjectIssue> ProjectIssues => Set<ProjectIssue>();
    public DbSet<ProjectIssueHistory> ProjectIssueHistory => Set<ProjectIssueHistory>();
    public DbSet<ProjectIssueComment> ProjectIssueComments => Set<ProjectIssueComment>();
    public DbSet<ProjectIssueEvidence> ProjectIssueEvidence => Set<ProjectIssueEvidence>();
    public DbSet<ProjectIssueRelationship> ProjectIssueRelationships => Set<ProjectIssueRelationship>();
    public DbSet<ProjectIssueAcceptanceCriterion> ProjectIssueAcceptanceCriteria => Set<ProjectIssueAcceptanceCriterion>();
    public DbSet<ProjectIssueDevelopmentCycle> ProjectIssueDevelopmentCycles => Set<ProjectIssueDevelopmentCycle>();
    public DbSet<ProjectIssueFixAttempt> ProjectIssueFixAttempts => Set<ProjectIssueFixAttempt>();
    public DbSet<ProjectIssueRetest> ProjectIssueRetests => Set<ProjectIssueRetest>();
    public DbSet<ProjectIssueTesterAcceptance> ProjectIssueTesterAcceptances => Set<ProjectIssueTesterAcceptance>();
    public DbSet<ProjectIssueSignOff> ProjectIssueSignOffs => Set<ProjectIssueSignOff>();
    public DbSet<ChangeManagementActor> ChangeManagementActors => Set<ChangeManagementActor>();
    public DbSet<ChangeManagementWorkAssignment> ChangeManagementWorkAssignments => Set<ChangeManagementWorkAssignment>();
    public DbSet<ChangeManagementNotice> ChangeManagementNotices => Set<ChangeManagementNotice>();
    public DbSet<ChangeManagementNoticeSeen> ChangeManagementNoticeSeen => Set<ChangeManagementNoticeSeen>();
    public DbSet<ChangeManagementTestingSource> ChangeManagementTestingSources => Set<ChangeManagementTestingSource>();
    public DbSet<ChangeManagementTestingChapter> ChangeManagementTestingChapters => Set<ChangeManagementTestingChapter>();
    public DbSet<ChangeManagementTestingPhase> ChangeManagementTestingPhases => Set<ChangeManagementTestingPhase>();
    public DbSet<ChangeManagementTestingStep> ChangeManagementTestingSteps => Set<ChangeManagementTestingStep>();
    public DbSet<ChangeManagementTestingRevision> ChangeManagementTestingRevisions => Set<ChangeManagementTestingRevision>();
    public DbSet<ChangeManagementTestingStepHistory> ChangeManagementTestingStepHistory => Set<ChangeManagementTestingStepHistory>();
    public DbSet<ChangeManagementTestingStepLink> ChangeManagementTestingStepLinks => Set<ChangeManagementTestingStepLink>();
    public DbSet<ChangeManagementTestPlan> ChangeManagementTestPlans => Set<ChangeManagementTestPlan>();
    public DbSet<ChangeManagementTestSuite> ChangeManagementTestSuites => Set<ChangeManagementTestSuite>();
    public DbSet<ChangeManagementTestCase> ChangeManagementTestCases => Set<ChangeManagementTestCase>();
    public DbSet<ChangeManagementTestCaseStep> ChangeManagementTestCaseSteps => Set<ChangeManagementTestCaseStep>();
    public DbSet<ChangeManagementTestPlanCase> ChangeManagementTestPlanCases => Set<ChangeManagementTestPlanCase>();
    public DbSet<ChangeManagementTestExecution> ChangeManagementTestExecutions => Set<ChangeManagementTestExecution>();
    public DbSet<ChangeManagementTestStepResult> ChangeManagementTestStepResults => Set<ChangeManagementTestStepResult>();
    public DbSet<ChangeManagementTestEvidence> ChangeManagementTestEvidence => Set<ChangeManagementTestEvidence>();
    public DbSet<ProjectIssueTestLink> ProjectIssueTestLinks => Set<ProjectIssueTestLink>();
    public DbSet<RuntimeRunStageEvent> RuntimeRunStageEvents => Set<RuntimeRunStageEvent>();
    public DbSet<AutomationOutboxMessage> AutomationOutboxMessages => Set<AutomationOutboxMessage>();

    protected override void OnModelCreating(ModelBuilder builder)
    {
        base.OnModelCreating(builder);

        builder.HasDefaultSchema(DynomaxSchema.Name);
        ConfigureIdentity(builder);

        builder.ApplyConfigurationsFromAssembly(typeof(DynomaxDbContext).Assembly);
    }

    private static void ConfigureIdentity(ModelBuilder builder)
    {
        builder.Entity<ApplicationUser>().ToTable("Users");
        builder.Entity<IdentityRole<Guid>>().ToTable("Roles");
        builder.Entity<IdentityUserRole<Guid>>().ToTable("UserRoles");
        builder.Entity<IdentityUserClaim<Guid>>().ToTable("UserClaims");

        builder.Entity<IdentityUserLogin<Guid>>(entity =>
        {
            entity.ToTable("UserLogins");
            entity.Property(login => login.LoginProvider).HasMaxLength(128);
            entity.Property(login => login.ProviderKey).HasMaxLength(128);
        });

        builder.Entity<IdentityRoleClaim<Guid>>().ToTable("RoleClaims");

        builder.Entity<IdentityUserToken<Guid>>(entity =>
        {
            entity.ToTable("UserTokens");
            entity.Property(token => token.LoginProvider).HasMaxLength(128);
            entity.Property(token => token.Name).HasMaxLength(128);
        });
    }
}
