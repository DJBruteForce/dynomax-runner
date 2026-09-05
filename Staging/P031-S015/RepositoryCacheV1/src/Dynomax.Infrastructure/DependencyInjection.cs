using System.Net;
using Dynomax.Application.Auditing;
using Dynomax.Application.Apps;
using Dynomax.Application.Automation;
using Dynomax.Application.Common;
using Dynomax.Application.ChangeManagement;
using Dynomax.Application.Organizations;
using Dynomax.Application.Projects;
using Dynomax.Application.Projects.Configuration;
using Dynomax.Application.Projects.TestData;
using Dynomax.Application.ProjectContext;
using Dynomax.Application.ProjectContext.Repositories;
using Dynomax.Application.Security;
using Dynomax.Application.Testing;
using Dynomax.Application.Testing.Actions;
using Dynomax.Application.Testing.Compilation;
using Dynomax.Application.Testing.Tests;
using Dynomax.Application.Testing.Workflows;
using Dynomax.Application.Testing.Publication;
using Dynomax.Application.Testing.Scheduling;
using Dynomax.Infrastructure.Auditing;
using Dynomax.Infrastructure.Apps;
using Dynomax.Infrastructure.Automation;
using Dynomax.Infrastructure.Common;
using Dynomax.Infrastructure.ChangeManagement;
using Dynomax.Infrastructure.Identity;
using Dynomax.Infrastructure.Organizations;
using Dynomax.Infrastructure.Persistence;
using Dynomax.Infrastructure.Projects;
using Dynomax.Infrastructure.Projects.Configuration;
using Dynomax.Infrastructure.Projects.TestData;
using Dynomax.Infrastructure.ProjectContext;
using Dynomax.Infrastructure.ProjectContext.Repositories;
using Dynomax.Infrastructure.Security;
using Dynomax.Infrastructure.Testing;
using Dynomax.Infrastructure.Testing.Actions;
using Dynomax.Infrastructure.Testing.Compilation;
using Dynomax.Infrastructure.Testing.Tests;
using Dynomax.Infrastructure.Testing.Workflows;
using Dynomax.Infrastructure.Testing.Publication;
using Dynomax.Infrastructure.Testing.Scheduling;
using Microsoft.AspNetCore.Identity;
using Microsoft.Data.SqlClient;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Logging;

namespace Dynomax.Infrastructure;

public static class DependencyInjection
{
    public static IServiceCollection AddDynomaxInfrastructure(
        this IServiceCollection services,
        IConfiguration configuration)
    {
        string connectionString = NormalizeSqlServerConnectionString(
            configuration.GetConnectionString("Dynomax")
            ?? throw new InvalidOperationException(
                "ConnectionStrings:Dynomax is required. Use user secrets or an environment variable; do not commit credentials."));

        services.AddDbContext<DynomaxDbContext>(options =>
            options.UseSqlServer(
                connectionString,
                sql =>
                {
                    sql.MigrationsHistoryTable("__EFMigrationsHistory", DynomaxSchema.Name);
                    sql.EnableRetryOnFailure(3, TimeSpan.FromSeconds(5), null);
                    sql.CommandTimeout(30);
                }));

        services
            .AddIdentity<ApplicationUser, IdentityRole<Guid>>(options =>
            {
                options.SignIn.RequireConfirmedAccount = false;
                options.User.RequireUniqueEmail = true;
                options.Password.RequiredLength = 12;
                options.Password.RequireDigit = true;
                options.Password.RequireLowercase = true;
                options.Password.RequireUppercase = true;
                options.Password.RequireNonAlphanumeric = true;
                options.Lockout.AllowedForNewUsers = true;
                options.Lockout.MaxFailedAccessAttempts = 5;
                options.Lockout.DefaultLockoutTimeSpan = TimeSpan.FromMinutes(15);
            })
            .AddEntityFrameworkStores<DynomaxDbContext>()
            .AddDefaultTokenProviders();

        services
            .AddOptions<BootstrapAdminOptions>()
            .Bind(configuration.GetSection(BootstrapAdminOptions.SectionName))
            .Validate(
                options => !options.Enabled ||
                    (!string.IsNullOrWhiteSpace(options.Email) && !string.IsNullOrWhiteSpace(options.Password)),
                "BootstrapAdmin Email and Password are required when bootstrap is enabled.")
            .ValidateOnStart();

        services
            .AddOptions<DefaultOrganizationOptions>()
            .Bind(configuration.GetSection(DefaultOrganizationOptions.SectionName))
            .Validate(
                options => !string.IsNullOrWhiteSpace(options.Key) && !string.IsNullOrWhiteSpace(options.DisplayName),
                "DefaultOrganization Key and DisplayName are required.")
            .ValidateOnStart();

        services.AddHostedService<DatabaseReadinessHostedService>();
        services.AddHostedService<IdentityBootstrapHostedService>();
        services.AddHostedService<ControlPlaneBootstrapHostedService>();

        services.ConfigureApplicationCookie(options =>
        {
            options.AccessDeniedPath = "/AccessDenied";
            options.LoginPath = "/Account/Login";
            options.LogoutPath = "/Account/Logout";
            options.Cookie.Name = "DynomaxV2.Auth";
            options.Cookie.HttpOnly = true;
            options.Cookie.IsEssential = true;
            options.Cookie.SameSite = Microsoft.AspNetCore.Http.SameSiteMode.Lax;
            options.Cookie.SecurePolicy = Microsoft.AspNetCore.Http.CookieSecurePolicy.Always;
            options.ExpireTimeSpan = TimeSpan.FromHours(8);
            options.SlidingExpiration = true;
        });

        services.AddScoped<IOrganizationService, OrganizationService>();
        services.AddScoped<IProjectRepository, ProjectRepository>();
        services.AddScoped<IProjectEnvironmentService, ProjectEnvironmentService>();
        services.AddScoped<IProjectTestDataService, ProjectTestDataService>();
        services.AddScoped<IProjectConfigurationResolver, ProjectConfigurationResolver>();
        services.AddScoped<IProjectManagedSecretValueResolver, ProjectManagedSecretValueResolver>();
        services.AddScoped<IProjectAccessService, ProjectAccessService>();
        services.AddScoped<IProjectContextService, ProjectContextService>();
        services.AddScoped<IRepositoryCredentialReferenceService, RepositoryCredentialReferenceService>();
        services.AddScoped<IRepositoryCredentialResolver, RepositoryCredentialResolver>();
        services.AddScoped<IRepositoryConnectionService, RepositoryConnectionService>();
        services.AddScoped<IRepositoryReadService, RepositoryReadService>();
        services.AddScoped<IRepositoryHistoryService, RepositoryHistoryService>();
        services.AddScoped<IRepositoryGitCacheService, RepositoryGitCacheService>();
        services.AddTransient<GitHubRepositoryRetryHandler>();
        services.AddScoped<IRepositoryContextPresentationService, RepositoryContextPresentationService>();
        services.AddHttpClient<IRepositoryProviderClient, GitHubRepositoryProviderClient>(client =>
        {
            client.BaseAddress = new Uri("https://api.github.com/");
            client.Timeout = TimeSpan.FromSeconds(30);
        })
        .ConfigurePrimaryHttpMessageHandler(() => new SocketsHttpHandler
        {
            AllowAutoRedirect = false,
            AutomaticDecompression = DecompressionMethods.GZip | DecompressionMethods.Deflate
        })
        .AddHttpMessageHandler<GitHubRepositoryRetryHandler>()
        .RedactLoggedHeaders(static _ => true);
        services.AddHttpClient<IRepositoryHistoryProviderClient, GitHubRepositoryHistoryProviderClient>(client =>
        {
            client.BaseAddress = new Uri("https://api.github.com/");
            client.Timeout = TimeSpan.FromSeconds(30);
        })
        .ConfigurePrimaryHttpMessageHandler(() => new SocketsHttpHandler
        {
            AllowAutoRedirect = false,
            AutomaticDecompression = DecompressionMethods.GZip | DecompressionMethods.Deflate
        })
        .AddHttpMessageHandler<GitHubRepositoryRetryHandler>()
        .RedactLoggedHeaders(static _ => true);
        services.AddHttpClient<IRepositoryReadProviderClient, GitHubRepositoryReadProviderClient>(client =>
        {
            client.BaseAddress = new Uri("https://api.github.com/");
            client.Timeout = TimeSpan.FromSeconds(30);
        })
        .ConfigurePrimaryHttpMessageHandler(() => new SocketsHttpHandler
        {
            AllowAutoRedirect = false,
            AutomaticDecompression = DecompressionMethods.GZip | DecompressionMethods.Deflate
        })
        .AddHttpMessageHandler<GitHubRepositoryRetryHandler>()
        .RedactLoggedHeaders(static _ => true);
        services.AddScoped<IProjectAppService, ProjectAppService>();
        services.AddScoped<IProjectAppRuntimeService, ProjectAppRuntimeService>();
        services.AddScoped<IUserAdministrationService, UserAdministrationService>();
        services.AddScoped<IActionSourcePackageService, ActionSourcePackageService>();
        services.AddScoped<IActionSourcePackageMaterializer, ActionSourcePackageMaterializer>();
        services.AddSingleton<IBuiltInActionCatalog, BuiltInActionCatalog>();
        services.AddScoped<IBuiltInClosureVerificationService, BuiltInClosureVerificationService>();
        services.AddScoped<IActionLibraryService, ActionLibraryService>();
        services.AddScoped<ITestDefinitionService, TestDefinitionService>();
        services.AddScoped<IWorkflowDraftService, WorkflowDraftService>();
        services.AddScoped<IWorkflowAssemblyService, WorkflowAssemblyService>();
        services.AddScoped<IWorkflowEnvironmentService, WorkflowEnvironmentService>();
        services.AddScoped<IWorkflowCompilationService, WorkflowCompilationService>();
        services.AddScoped<ITestCompilationPreviewService, TestCompilationPreviewService>();
        services.AddScoped<ITestPublicationService, TestPublicationService>();
        services.AddScoped<IRuntimeSettingsService, RuntimeSettingsService>();
        services.AddSingleton<IRuntimeInputProtector, RuntimeInputProtector>();
        services.AddScoped<IRuntimeRunService, RuntimeRunService>();
        services.AddScoped<IRuntimeRunCoordinator, RuntimeRunService>();
        services.AddHttpClient<IPublicHolidayProvider, NagerPublicHolidayProvider>(client =>
        {
            client.BaseAddress = new Uri("https://nagerholidays.com/api/v4/");
            client.Timeout = TimeSpan.FromSeconds(20);
        });
        services.AddScoped<IBusinessCalendarService, BusinessCalendarService>();
        services.AddScoped<WorkflowScheduleEligibilityEvaluator>();
        services.AddScoped<IWorkflowScheduleService, WorkflowScheduleService>();
        services.AddScoped<IWorkflowScheduleDispatcher, WorkflowScheduleService>();
        services.AddScoped<IRunContinuationService, RunContinuationService>();
        services.AddScoped<IWorkflowExecutionService, WorkflowExecutionService>();
        services.AddScoped<IWorkflowDiscoveryService, WorkflowDiscoveryService>();
        services.AddScoped<IAuditWriter, AuditWriter>();
        services.AddScoped<IAuditQueryService, AuditQueryService>();
        services.AddScoped<IAgentAccessGrantService, AgentAccessGrantService>();
        services.AddScoped<IAgentFeedbackService, AgentFeedbackService>();
        services.AddScoped<IAgentWorkspaceProvisioningService, AgentWorkspaceProvisioningService>();
        services.AddScoped<IChangeManagementService, ChangeManagementService>();
        services.AddScoped<ITestManagementService, TestManagementService>();
        services.AddScoped<TestingSourceService>();
        services.AddScoped<ITestingSourceService, ActiveTestingSourceService>();
        services.AddScoped<ITestingSourceRetirementService, TestingSourceRetirementService>();
        services.AddScoped<IAgentAutomationSettingsService, AgentAutomationSettingsService>();
        services.AddSingleton<DeveloperDiagnosticsFileStore>();
        services.AddSingleton<ILoggerProvider, DynomaxJsonFileLoggerProvider>();
        services.AddScoped<IDeveloperDiagnosticsService, DeveloperDiagnosticsService>();
        services.AddScoped<AgentAutomationService>();
        services.AddScoped<IAgentAutomationService>(provider => provider.GetRequiredService<AgentAutomationService>());
        services.AddScoped<IAgentAutomationAdministrationService>(provider => provider.GetRequiredService<AgentAutomationService>());
        services.AddScoped<IAgentIdempotencyService, AgentIdempotencyService>();
        services.AddScoped<IAgentApiActivityService, AgentApiActivityService>();
        services.AddScoped<IAgentArtifactStore, SqlAgentArtifactStore>();
        services.AddScoped<IAutomationRunDispatch, SqlAutomationRunDispatch>();
        services.AddScoped<IAutomationOperationsQueryService, AutomationOperationsQueryService>();
        services.AddScoped<IRuntimeAutomationCoordinator, RuntimeAutomationCoordinator>();
        services.AddHostedService<AutomationStuckStateDetector>();
        services.AddHostedService<AutomationRetentionHostedService>();
        services.AddHostedService<ProjectAppExecutionRetentionHostedService>();
        services.AddHostedService<AutomationOutboxHostedService>();
        services.AddSingleton<IClock, SystemClock>();

        return services;
    }
    public static IServiceCollection AddDynomaxRunnerInfrastructure(
        this IServiceCollection services,
        IConfiguration configuration)
    {
        string connectionString = NormalizeSqlServerConnectionString(
            configuration.GetConnectionString("Dynomax")
                ?? throw new InvalidOperationException(
                    "ConnectionStrings:Dynomax is required for the runner. Use environment configuration; do not commit credentials."));

        services.AddDbContext<DynomaxDbContext>(options =>
            options.UseSqlServer(
                connectionString,
                sql =>
                {
                    sql.MigrationsHistoryTable("__EFMigrationsHistory", DynomaxSchema.Name);
                    sql.EnableRetryOnFailure(3, TimeSpan.FromSeconds(5), null);
                    sql.CommandTimeout(30);
                }));
        services.AddSingleton<IBuiltInActionCatalog, BuiltInActionCatalog>();
        services.AddScoped<IBuiltInClosureVerificationService, BuiltInClosureVerificationService>();
        services.AddScoped<IActionSourcePackageService, ActionSourcePackageService>();
        services.AddScoped<IProjectConfigurationResolver, ProjectConfigurationResolver>();
        services.AddScoped<IProjectManagedSecretValueResolver, ProjectManagedSecretValueResolver>();
        services.AddScoped<ITestCompilationPreviewService, TestCompilationPreviewService>();
        services.AddScoped<ITestPublicationService, TestPublicationService>();
        services.AddSingleton<IRuntimeInputProtector, RuntimeInputProtector>();
        services.AddScoped<IRuntimeRunService, RuntimeRunService>();
        services.AddScoped<IRuntimeRunCoordinator, RuntimeRunService>();
        services.AddHttpClient<IPublicHolidayProvider, NagerPublicHolidayProvider>(client =>
        {
            client.BaseAddress = new Uri("https://nagerholidays.com/api/v4/");
            client.Timeout = TimeSpan.FromSeconds(20);
        });
        services.AddScoped<IBusinessCalendarService, BusinessCalendarService>();
        services.AddScoped<WorkflowScheduleEligibilityEvaluator>();
        services.AddScoped<IWorkflowScheduleService, WorkflowScheduleService>();
        services.AddScoped<IWorkflowScheduleDispatcher, WorkflowScheduleService>();
        services.AddScoped<IAgentAutomationSettingsService, AgentAutomationSettingsService>();
        services.AddSingleton<DeveloperDiagnosticsFileStore>();
        services.AddSingleton<ILoggerProvider, DynomaxJsonFileLoggerProvider>();
        services.AddScoped<IDeveloperDiagnosticsService, DeveloperDiagnosticsService>();
        services.AddScoped<IRuntimeAutomationCoordinator, RuntimeAutomationCoordinator>();
        return services;
    }

    private static string NormalizeSqlServerConnectionString(string connectionString)
    {
        var builder = new SqlConnectionStringBuilder(connectionString)
        {
            MultipleActiveResultSets = false
        };
        return builder.ConnectionString;
    }

}
