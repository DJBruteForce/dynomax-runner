using Dynomax.Domain.Apps;
using Dynomax.Domain.Projects;
using Dynomax.Infrastructure.Identity;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;

namespace Dynomax.Infrastructure.Persistence.Configurations;

internal sealed class ProjectAppExecutionConfiguration : IEntityTypeConfiguration<ProjectAppExecution>
{
    public void Configure(EntityTypeBuilder<ProjectAppExecution> builder)
    {
        builder.ToTable("ProjectAppExecutions");
        builder.HasKey(item => item.Id);

        builder.HasIndex(item => item.ProjectId).HasDatabaseName("IX_ProjectAppExecutions_ProjectId");

        builder.HasIndex(item => item.RunRequestId).IsUnique().HasDatabaseName("UX_ProjectAppExecutions_RunRequest");
        builder.HasIndex(item => new { item.ProjectId, item.ProjectAppId, item.RequestedByUserId, item.RequestedAtUtc })
            .HasDatabaseName("IX_ProjectAppExecutions_Project_App_User_Requested");
        builder.HasIndex(item => item.ProjectAppRevisionId).HasDatabaseName("IX_ProjectAppExecutions_AppRevision");
        builder.Property(item => item.PublicAccessTokenSha256).HasMaxLength(64).IsUnicode(false);
        builder.Property(item => item.PublicAccessTokenProtected).HasMaxLength(2048);
        builder.Property(item => item.PublicIpSha256).HasMaxLength(64).IsUnicode(false);
        builder.Property(item => item.PublicSessionSha256).HasMaxLength(64).IsUnicode(false);
        builder.HasIndex(item => item.PublicAccessTokenSha256).IsUnique()
            .HasFilter("[PublicAccessTokenSha256] IS NOT NULL")
            .HasDatabaseName("UX_ProjectAppExecutions_PublicAccessTokenSha256");
        builder.HasIndex(item => new { item.ProjectId, item.ProjectAppId, item.OperationId }).IsUnique()
            .HasFilter("[PublicAccessTokenSha256] IS NOT NULL")
            .HasDatabaseName("UX_ProjectAppExecutions_PublicSubmissionOperation");
        builder.HasIndex(item => new { item.ProjectId, item.ProjectAppId, item.RequestedAtUtc })
            .HasFilter("[PublicAccessTokenSha256] IS NOT NULL")
            .HasDatabaseName("IX_ProjectAppExecutions_Public_App_Requested");
        builder.HasIndex(item => new { item.ProjectId, item.ProjectAppId, item.PublicIpSha256, item.RequestedAtUtc })
            .HasFilter("[PublicIpSha256] IS NOT NULL")
            .HasDatabaseName("IX_ProjectAppExecutions_Public_Ip_Requested");
        builder.HasIndex(item => new { item.ProjectId, item.ProjectAppId, item.PublicSessionSha256, item.RequestedAtUtc })
            .HasFilter("[PublicSessionSha256] IS NOT NULL")
            .HasDatabaseName("IX_ProjectAppExecutions_Public_Session_Requested");

        builder.HasOne<Project>().WithMany().HasForeignKey(item => item.ProjectId).OnDelete(DeleteBehavior.Restrict);
        builder.HasOne<ProjectApp>().WithMany().HasForeignKey(item => item.ProjectAppId).OnDelete(DeleteBehavior.Restrict);
        builder.HasOne<ProjectAppRevision>().WithMany().HasForeignKey(item => item.ProjectAppRevisionId).OnDelete(DeleteBehavior.Restrict);
        builder.HasOne<ApplicationUser>().WithMany().HasForeignKey(item => item.RequestedByUserId).OnDelete(DeleteBehavior.Restrict);
    }
}
