using Dynomax.Domain.ProjectContext;
using Dynomax.Domain.Projects;
using Dynomax.Domain.Projects.Configuration;
using Dynomax.Infrastructure.Identity;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;

namespace Dynomax.Infrastructure.Persistence.Configurations;

internal sealed class ProjectContextRepositoryConfiguration : IEntityTypeConfiguration<ProjectContextRepository>
{
    public void Configure(EntityTypeBuilder<ProjectContextRepository> builder)
    {
        builder.ToTable("ProjectContextRepositories", table => table.HasCheckConstraint("CK_ProjectContextRepositories_TagsJson", "ISJSON([TagsJson]) = 1"));
        builder.HasKey(x => x.Id);
        builder.Property(x => x.Provider).HasMaxLength(30).IsRequired(); builder.Property(x => x.ProviderRepositoryId).HasMaxLength(100).IsRequired();
        builder.Property(x => x.Owner).HasMaxLength(100).IsRequired(); builder.Property(x => x.Name).HasMaxLength(100).IsRequired(); builder.Property(x => x.FullName).HasMaxLength(220).IsRequired();
        builder.Property(x => x.WebUrl).HasMaxLength(500).IsRequired(); builder.Property(x => x.CloneUrl).HasMaxLength(500).IsRequired(); builder.Property(x => x.Visibility).HasMaxLength(30).IsRequired();
        builder.Property(x => x.ProviderDescription).HasMaxLength(1000); builder.Property(x => x.Role).HasMaxLength(100); builder.Property(x => x.Purpose).HasMaxLength(1000); builder.Property(x => x.TagsJson).HasColumnType("nvarchar(max)").IsRequired();
        builder.Property(x => x.DefaultBranch).HasMaxLength(255).IsRequired(); builder.Property(x => x.DefaultBranchHeadSha).HasMaxLength(64).IsRequired(); builder.Property(x => x.DefaultTreeSha).HasMaxLength(64);
        builder.Property(x => x.HealthStatus).HasMaxLength(50).IsRequired(); builder.Property(x => x.LastErrorCode).HasMaxLength(100); builder.Property(x => x.RowVersion).IsRowVersion();
        builder.HasIndex(x => new { x.SourceId, x.Provider, x.ProviderRepositoryId }).IsUnique(); builder.HasIndex(x => new { x.SourceId, x.IsActive, x.Role, x.Name }); builder.HasIndex(x => x.CredentialSecretReferenceId);
        builder.HasOne<ProjectContextSource>().WithMany().HasForeignKey(x => x.SourceId).OnDelete(DeleteBehavior.Cascade);
        builder.HasOne<ProjectSecretReference>().WithMany().HasForeignKey(x => x.CredentialSecretReferenceId).OnDelete(DeleteBehavior.NoAction);
        builder.HasOne<ApplicationUser>().WithMany().HasForeignKey(x => x.CreatedByUserId).OnDelete(DeleteBehavior.NoAction); builder.HasOne<ApplicationUser>().WithMany().HasForeignKey(x => x.UpdatedByUserId).OnDelete(DeleteBehavior.NoAction);
    }
}

internal sealed class ProjectContextRepositoryPolicyConfiguration : IEntityTypeConfiguration<ProjectContextRepositoryPolicy>
{
    public void Configure(EntityTypeBuilder<ProjectContextRepositoryPolicy> builder)
    {
        builder.ToTable("ProjectContextRepositoryPolicies", table => { table.HasCheckConstraint("CK_ProjectContextRepositoryPolicies_TargetPatterns", "ISJSON([AllowedTargetBranchPatternsJson]) = 1"); table.HasCheckConstraint("CK_ProjectContextRepositoryPolicies_BasePatterns", "ISJSON([AllowedBaseBranchPatternsJson]) = 1"); });
        builder.HasKey(x => x.Id); builder.Property(x => x.AllowedTargetBranchPatternsJson).HasColumnType("nvarchar(max)").IsRequired(); builder.Property(x => x.AllowedBaseBranchPatternsJson).HasColumnType("nvarchar(max)").IsRequired(); builder.Property(x => x.AgentBranchPrefix).HasMaxLength(100).IsRequired(); builder.Property(x => x.RowVersion).IsRowVersion();
        builder.HasOne<ProjectContextRepository>().WithOne().HasForeignKey<ProjectContextRepositoryPolicy>(x => x.RepositoryContextId).OnDelete(DeleteBehavior.Cascade);
        builder.HasOne<ApplicationUser>().WithMany().HasForeignKey(x => x.CreatedByUserId).OnDelete(DeleteBehavior.NoAction); builder.HasOne<ApplicationUser>().WithMany().HasForeignKey(x => x.UpdatedByUserId).OnDelete(DeleteBehavior.NoAction);
    }
}

internal sealed class RepositoryWorkSetConfiguration : IEntityTypeConfiguration<RepositoryWorkSet>
{
    public void Configure(EntityTypeBuilder<RepositoryWorkSet> builder)
    {
        builder.ToTable("RepositoryWorkSets"); builder.HasKey(x => x.Id); builder.Property(x => x.Title).HasMaxLength(200).IsRequired(); builder.Property(x => x.Goal).HasMaxLength(4000).IsRequired(); builder.Property(x => x.Status).HasMaxLength(50).IsRequired(); builder.Property(x => x.RowVersion).IsRowVersion();
        builder.HasIndex(x => new { x.ProjectId, x.Status, x.UpdatedAtUtc }); builder.HasIndex(x => x.AgentAccessGrantId); builder.HasIndex(x => x.ChangeManagementActorId); builder.HasIndex(x => x.LinkedProjectIssueId); builder.HasIndex(x => x.LinkedProductChangeId); builder.HasIndex(x => x.LinkedTestingStepId);
        builder.HasOne<Project>().WithMany().HasForeignKey(x => x.ProjectId).OnDelete(DeleteBehavior.Cascade); builder.HasOne<ApplicationUser>().WithMany().HasForeignKey(x => x.OwnerUserId).OnDelete(DeleteBehavior.NoAction);
    }
}

internal sealed class RepositoryWorkspaceConfiguration : IEntityTypeConfiguration<RepositoryWorkspace>
{
    public void Configure(EntityTypeBuilder<RepositoryWorkspace> builder)
    {
        builder.ToTable("RepositoryWorkspaces"); builder.HasKey(x => x.Id); builder.Property(x => x.StorageKey).HasMaxLength(200).IsRequired(); builder.Property(x => x.BaseBranch).HasMaxLength(255).IsRequired(); builder.Property(x => x.BaseCommitSha).HasMaxLength(64).IsRequired(); builder.Property(x => x.WorkBranch).HasMaxLength(255).IsRequired(); builder.Property(x => x.CurrentCommitSha).HasMaxLength(64); builder.Property(x => x.LastPushedCommitSha).HasMaxLength(64); builder.Property(x => x.RemoteTargetBranch).HasMaxLength(255); builder.Property(x => x.State).HasMaxLength(50).IsRequired(); builder.Property(x => x.RowVersion).IsRowVersion();
        builder.HasIndex(x => new { x.WorkSetId, x.RepositoryContextId }).IsUnique(); builder.HasIndex(x => x.StorageKey).IsUnique(); builder.HasIndex(x => new { x.RepositoryContextId, x.State, x.UpdatedAtUtc });
        builder.HasOne<RepositoryWorkSet>().WithMany().HasForeignKey(x => x.WorkSetId).OnDelete(DeleteBehavior.Restrict); builder.HasOne<ProjectContextRepository>().WithMany().HasForeignKey(x => x.RepositoryContextId).OnDelete(DeleteBehavior.Restrict);
        builder.HasOne<ApplicationUser>().WithMany().HasForeignKey(x => x.CreatedByUserId).OnDelete(DeleteBehavior.NoAction); builder.HasOne<ApplicationUser>().WithMany().HasForeignKey(x => x.UpdatedByUserId).OnDelete(DeleteBehavior.NoAction);
    }
}

internal sealed class RepositoryPullRequestLinkConfiguration : IEntityTypeConfiguration<RepositoryPullRequestLink>
{
    public void Configure(EntityTypeBuilder<RepositoryPullRequestLink> builder)
    {
        builder.ToTable("RepositoryPullRequestLinks"); builder.HasKey(x => x.Id); builder.Property(x => x.Provider).HasMaxLength(30).IsRequired(); builder.Property(x => x.ProviderPullRequestId).HasMaxLength(100).IsRequired(); builder.Property(x => x.WebUrl).HasMaxLength(500).IsRequired(); builder.Property(x => x.State).HasMaxLength(50).IsRequired(); builder.Property(x => x.BaseRef).HasMaxLength(255).IsRequired(); builder.Property(x => x.HeadRef).HasMaxLength(255).IsRequired(); builder.Property(x => x.BaseSha).HasMaxLength(64).IsRequired(); builder.Property(x => x.HeadSha).HasMaxLength(64).IsRequired(); builder.Property(x => x.RowVersion).IsRowVersion();
        builder.HasIndex(x => new { x.RepositoryContextId, x.Provider, x.ProviderPullRequestId }).IsUnique(); builder.HasIndex(x => new { x.WorkSetId, x.WorkspaceId, x.State });
        builder.HasOne<ProjectContextRepository>().WithMany().HasForeignKey(x => x.RepositoryContextId).OnDelete(DeleteBehavior.Restrict); builder.HasOne<RepositoryWorkSet>().WithMany().HasForeignKey(x => x.WorkSetId).OnDelete(DeleteBehavior.Restrict); builder.HasOne<RepositoryWorkspace>().WithMany().HasForeignKey(x => x.WorkspaceId).OnDelete(DeleteBehavior.Restrict);
        builder.HasOne<ApplicationUser>().WithMany().HasForeignKey(x => x.CreatedByUserId).OnDelete(DeleteBehavior.NoAction); builder.HasOne<ApplicationUser>().WithMany().HasForeignKey(x => x.UpdatedByUserId).OnDelete(DeleteBehavior.NoAction);
    }
}