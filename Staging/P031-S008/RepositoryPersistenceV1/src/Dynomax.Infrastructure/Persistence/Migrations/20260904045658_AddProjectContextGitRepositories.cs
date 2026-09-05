using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace Dynomax.Infrastructure.Persistence.Migrations
{
    /// <inheritdoc />
    public partial class AddProjectContextGitRepositories : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.CreateTable(
                name: "ProjectContextRepositories",
                schema: "DynomaxV2",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                    SourceId = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                    Provider = table.Column<string>(type: "nvarchar(30)", maxLength: 30, nullable: false),
                    ProviderRepositoryId = table.Column<string>(type: "nvarchar(100)", maxLength: 100, nullable: false),
                    Owner = table.Column<string>(type: "nvarchar(100)", maxLength: 100, nullable: false),
                    Name = table.Column<string>(type: "nvarchar(100)", maxLength: 100, nullable: false),
                    FullName = table.Column<string>(type: "nvarchar(220)", maxLength: 220, nullable: false),
                    WebUrl = table.Column<string>(type: "nvarchar(500)", maxLength: 500, nullable: false),
                    CloneUrl = table.Column<string>(type: "nvarchar(500)", maxLength: 500, nullable: false),
                    Visibility = table.Column<string>(type: "nvarchar(30)", maxLength: 30, nullable: false),
                    IsArchived = table.Column<bool>(type: "bit", nullable: false),
                    IsDisabled = table.Column<bool>(type: "bit", nullable: false),
                    IsFork = table.Column<bool>(type: "bit", nullable: true),
                    ProviderDescription = table.Column<string>(type: "nvarchar(1000)", maxLength: 1000, nullable: true),
                    Role = table.Column<string>(type: "nvarchar(100)", maxLength: 100, nullable: true),
                    Purpose = table.Column<string>(type: "nvarchar(1000)", maxLength: 1000, nullable: true),
                    TagsJson = table.Column<string>(type: "nvarchar(max)", nullable: false),
                    DefaultBranch = table.Column<string>(type: "nvarchar(255)", maxLength: 255, nullable: false),
                    DefaultBranchHeadSha = table.Column<string>(type: "nvarchar(64)", maxLength: 64, nullable: false),
                    DefaultTreeSha = table.Column<string>(type: "nvarchar(64)", maxLength: 64, nullable: true),
                    CredentialSecretReferenceId = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                    HealthStatus = table.Column<string>(type: "nvarchar(50)", maxLength: 50, nullable: false),
                    LastErrorCode = table.Column<string>(type: "nvarchar(100)", maxLength: 100, nullable: true),
                    LastValidatedAtUtc = table.Column<DateTime>(type: "datetime2", nullable: true),
                    LastRefreshedAtUtc = table.Column<DateTime>(type: "datetime2", nullable: true),
                    IsActive = table.Column<bool>(type: "bit", nullable: false),
                    CreatedByUserId = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                    UpdatedByUserId = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                    CreatedAtUtc = table.Column<DateTime>(type: "datetime2", nullable: false),
                    UpdatedAtUtc = table.Column<DateTime>(type: "datetime2", nullable: false),
                    RowVersion = table.Column<byte[]>(type: "rowversion", rowVersion: true, nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_ProjectContextRepositories", x => x.Id);
                    table.CheckConstraint("CK_ProjectContextRepositories_TagsJson", "ISJSON([TagsJson]) = 1");
                    table.ForeignKey(
                        name: "FK_ProjectContextRepositories_ProjectContextSources_SourceId",
                        column: x => x.SourceId,
                        principalSchema: "DynomaxV2",
                        principalTable: "ProjectContextSources",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Cascade);
                    table.ForeignKey(
                        name: "FK_ProjectContextRepositories_ProjectSecretReferences_CredentialSecretReferenceId",
                        column: x => x.CredentialSecretReferenceId,
                        principalSchema: "DynomaxV2",
                        principalTable: "ProjectSecretReferences",
                        principalColumn: "Id");
                    table.ForeignKey(
                        name: "FK_ProjectContextRepositories_Users_CreatedByUserId",
                        column: x => x.CreatedByUserId,
                        principalSchema: "DynomaxV2",
                        principalTable: "Users",
                        principalColumn: "Id");
                    table.ForeignKey(
                        name: "FK_ProjectContextRepositories_Users_UpdatedByUserId",
                        column: x => x.UpdatedByUserId,
                        principalSchema: "DynomaxV2",
                        principalTable: "Users",
                        principalColumn: "Id");
                });

            migrationBuilder.CreateTable(
                name: "RepositoryWorkSets",
                schema: "DynomaxV2",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                    ProjectId = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                    Title = table.Column<string>(type: "nvarchar(200)", maxLength: 200, nullable: false),
                    Goal = table.Column<string>(type: "nvarchar(4000)", maxLength: 4000, nullable: false),
                    OwnerUserId = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                    AgentAccessGrantId = table.Column<Guid>(type: "uniqueidentifier", nullable: true),
                    ChangeManagementActorId = table.Column<Guid>(type: "uniqueidentifier", nullable: true),
                    LinkedProjectIssueId = table.Column<Guid>(type: "uniqueidentifier", nullable: true),
                    LinkedProductChangeId = table.Column<Guid>(type: "uniqueidentifier", nullable: true),
                    LinkedTestingStepId = table.Column<Guid>(type: "uniqueidentifier", nullable: true),
                    Status = table.Column<string>(type: "nvarchar(50)", maxLength: 50, nullable: false),
                    CreatedAtUtc = table.Column<DateTime>(type: "datetime2", nullable: false),
                    UpdatedAtUtc = table.Column<DateTime>(type: "datetime2", nullable: false),
                    ExpiresAtUtc = table.Column<DateTime>(type: "datetime2", nullable: true),
                    RowVersion = table.Column<byte[]>(type: "rowversion", rowVersion: true, nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_RepositoryWorkSets", x => x.Id);
                    table.ForeignKey(
                        name: "FK_RepositoryWorkSets_Projects_ProjectId",
                        column: x => x.ProjectId,
                        principalSchema: "DynomaxV2",
                        principalTable: "Projects",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Cascade);
                    table.ForeignKey(
                        name: "FK_RepositoryWorkSets_Users_OwnerUserId",
                        column: x => x.OwnerUserId,
                        principalSchema: "DynomaxV2",
                        principalTable: "Users",
                        principalColumn: "Id");
                });

            migrationBuilder.CreateTable(
                name: "ProjectContextRepositoryPolicies",
                schema: "DynomaxV2",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                    RepositoryContextId = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                    AllowRead = table.Column<bool>(type: "bit", nullable: false),
                    AllowWorkspace = table.Column<bool>(type: "bit", nullable: false),
                    AllowCommitPush = table.Column<bool>(type: "bit", nullable: false),
                    AllowPullRequest = table.Column<bool>(type: "bit", nullable: false),
                    AllowMerge = table.Column<bool>(type: "bit", nullable: false),
                    AllowRemoteBranchDelete = table.Column<bool>(type: "bit", nullable: false),
                    AllowActionsRerun = table.Column<bool>(type: "bit", nullable: false),
                    AllowDirectDefaultBranchWrite = table.Column<bool>(type: "bit", nullable: false),
                    AllowForcePush = table.Column<bool>(type: "bit", nullable: false),
                    RequirePullRequestForDefaultBranch = table.Column<bool>(type: "bit", nullable: false),
                    AllowedTargetBranchPatternsJson = table.Column<string>(type: "nvarchar(max)", nullable: false),
                    AllowedBaseBranchPatternsJson = table.Column<string>(type: "nvarchar(max)", nullable: false),
                    AgentBranchPrefix = table.Column<string>(type: "nvarchar(100)", maxLength: 100, nullable: false),
                    CreatedByUserId = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                    UpdatedByUserId = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                    CreatedAtUtc = table.Column<DateTime>(type: "datetime2", nullable: false),
                    UpdatedAtUtc = table.Column<DateTime>(type: "datetime2", nullable: false),
                    RowVersion = table.Column<byte[]>(type: "rowversion", rowVersion: true, nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_ProjectContextRepositoryPolicies", x => x.Id);
                    table.CheckConstraint("CK_ProjectContextRepositoryPolicies_BasePatterns", "ISJSON([AllowedBaseBranchPatternsJson]) = 1");
                    table.CheckConstraint("CK_ProjectContextRepositoryPolicies_TargetPatterns", "ISJSON([AllowedTargetBranchPatternsJson]) = 1");
                    table.ForeignKey(
                        name: "FK_ProjectContextRepositoryPolicies_ProjectContextRepositories_RepositoryContextId",
                        column: x => x.RepositoryContextId,
                        principalSchema: "DynomaxV2",
                        principalTable: "ProjectContextRepositories",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Cascade);
                    table.ForeignKey(
                        name: "FK_ProjectContextRepositoryPolicies_Users_CreatedByUserId",
                        column: x => x.CreatedByUserId,
                        principalSchema: "DynomaxV2",
                        principalTable: "Users",
                        principalColumn: "Id");
                    table.ForeignKey(
                        name: "FK_ProjectContextRepositoryPolicies_Users_UpdatedByUserId",
                        column: x => x.UpdatedByUserId,
                        principalSchema: "DynomaxV2",
                        principalTable: "Users",
                        principalColumn: "Id");
                });

            migrationBuilder.CreateTable(
                name: "RepositoryWorkspaces",
                schema: "DynomaxV2",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                    WorkSetId = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                    RepositoryContextId = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                    StorageKey = table.Column<string>(type: "nvarchar(200)", maxLength: 200, nullable: false),
                    BaseBranch = table.Column<string>(type: "nvarchar(255)", maxLength: 255, nullable: false),
                    BaseCommitSha = table.Column<string>(type: "nvarchar(64)", maxLength: 64, nullable: false),
                    WorkBranch = table.Column<string>(type: "nvarchar(255)", maxLength: 255, nullable: false),
                    CurrentCommitSha = table.Column<string>(type: "nvarchar(64)", maxLength: 64, nullable: true),
                    LastPushedCommitSha = table.Column<string>(type: "nvarchar(64)", maxLength: 64, nullable: true),
                    RemoteTargetBranch = table.Column<string>(type: "nvarchar(255)", maxLength: 255, nullable: true),
                    State = table.Column<string>(type: "nvarchar(50)", maxLength: 50, nullable: false),
                    LastFetchedAtUtc = table.Column<DateTime>(type: "datetime2", nullable: true),
                    LastSyncedAtUtc = table.Column<DateTime>(type: "datetime2", nullable: true),
                    CreatedByUserId = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                    UpdatedByUserId = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                    AgentAccessGrantId = table.Column<Guid>(type: "uniqueidentifier", nullable: true),
                    ChangeManagementActorId = table.Column<Guid>(type: "uniqueidentifier", nullable: true),
                    CreatedAtUtc = table.Column<DateTime>(type: "datetime2", nullable: false),
                    UpdatedAtUtc = table.Column<DateTime>(type: "datetime2", nullable: false),
                    RowVersion = table.Column<byte[]>(type: "rowversion", rowVersion: true, nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_RepositoryWorkspaces", x => x.Id);
                    table.ForeignKey(
                        name: "FK_RepositoryWorkspaces_ProjectContextRepositories_RepositoryContextId",
                        column: x => x.RepositoryContextId,
                        principalSchema: "DynomaxV2",
                        principalTable: "ProjectContextRepositories",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "FK_RepositoryWorkspaces_RepositoryWorkSets_WorkSetId",
                        column: x => x.WorkSetId,
                        principalSchema: "DynomaxV2",
                        principalTable: "RepositoryWorkSets",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "FK_RepositoryWorkspaces_Users_CreatedByUserId",
                        column: x => x.CreatedByUserId,
                        principalSchema: "DynomaxV2",
                        principalTable: "Users",
                        principalColumn: "Id");
                    table.ForeignKey(
                        name: "FK_RepositoryWorkspaces_Users_UpdatedByUserId",
                        column: x => x.UpdatedByUserId,
                        principalSchema: "DynomaxV2",
                        principalTable: "Users",
                        principalColumn: "Id");
                });

            migrationBuilder.CreateTable(
                name: "RepositoryPullRequestLinks",
                schema: "DynomaxV2",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                    RepositoryContextId = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                    WorkSetId = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                    WorkspaceId = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                    Provider = table.Column<string>(type: "nvarchar(30)", maxLength: 30, nullable: false),
                    ProviderPullRequestId = table.Column<string>(type: "nvarchar(100)", maxLength: 100, nullable: false),
                    PullRequestNumber = table.Column<int>(type: "int", nullable: false),
                    WebUrl = table.Column<string>(type: "nvarchar(500)", maxLength: 500, nullable: false),
                    State = table.Column<string>(type: "nvarchar(50)", maxLength: 50, nullable: false),
                    BaseRef = table.Column<string>(type: "nvarchar(255)", maxLength: 255, nullable: false),
                    HeadRef = table.Column<string>(type: "nvarchar(255)", maxLength: 255, nullable: false),
                    BaseSha = table.Column<string>(type: "nvarchar(64)", maxLength: 64, nullable: false),
                    HeadSha = table.Column<string>(type: "nvarchar(64)", maxLength: 64, nullable: false),
                    LastSeenAtUtc = table.Column<DateTime>(type: "datetime2", nullable: false),
                    CreatedByUserId = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                    UpdatedByUserId = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                    CreatedAtUtc = table.Column<DateTime>(type: "datetime2", nullable: false),
                    UpdatedAtUtc = table.Column<DateTime>(type: "datetime2", nullable: false),
                    RowVersion = table.Column<byte[]>(type: "rowversion", rowVersion: true, nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_RepositoryPullRequestLinks", x => x.Id);
                    table.ForeignKey(
                        name: "FK_RepositoryPullRequestLinks_ProjectContextRepositories_RepositoryContextId",
                        column: x => x.RepositoryContextId,
                        principalSchema: "DynomaxV2",
                        principalTable: "ProjectContextRepositories",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "FK_RepositoryPullRequestLinks_RepositoryWorkSets_WorkSetId",
                        column: x => x.WorkSetId,
                        principalSchema: "DynomaxV2",
                        principalTable: "RepositoryWorkSets",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "FK_RepositoryPullRequestLinks_RepositoryWorkspaces_WorkspaceId",
                        column: x => x.WorkspaceId,
                        principalSchema: "DynomaxV2",
                        principalTable: "RepositoryWorkspaces",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "FK_RepositoryPullRequestLinks_Users_CreatedByUserId",
                        column: x => x.CreatedByUserId,
                        principalSchema: "DynomaxV2",
                        principalTable: "Users",
                        principalColumn: "Id");
                    table.ForeignKey(
                        name: "FK_RepositoryPullRequestLinks_Users_UpdatedByUserId",
                        column: x => x.UpdatedByUserId,
                        principalSchema: "DynomaxV2",
                        principalTable: "Users",
                        principalColumn: "Id");
                });

            migrationBuilder.CreateIndex(
                name: "IX_ProjectContextRepositories_CreatedByUserId",
                schema: "DynomaxV2",
                table: "ProjectContextRepositories",
                column: "CreatedByUserId");

            migrationBuilder.CreateIndex(
                name: "IX_ProjectContextRepositories_CredentialSecretReferenceId",
                schema: "DynomaxV2",
                table: "ProjectContextRepositories",
                column: "CredentialSecretReferenceId");

            migrationBuilder.CreateIndex(
                name: "IX_ProjectContextRepositories_SourceId_IsActive_Role_Name",
                schema: "DynomaxV2",
                table: "ProjectContextRepositories",
                columns: new[] { "SourceId", "IsActive", "Role", "Name" });

            migrationBuilder.CreateIndex(
                name: "IX_ProjectContextRepositories_SourceId_Provider_ProviderRepositoryId",
                schema: "DynomaxV2",
                table: "ProjectContextRepositories",
                columns: new[] { "SourceId", "Provider", "ProviderRepositoryId" },
                unique: true);

            migrationBuilder.CreateIndex(
                name: "IX_ProjectContextRepositories_UpdatedByUserId",
                schema: "DynomaxV2",
                table: "ProjectContextRepositories",
                column: "UpdatedByUserId");

            migrationBuilder.CreateIndex(
                name: "IX_ProjectContextRepositoryPolicies_CreatedByUserId",
                schema: "DynomaxV2",
                table: "ProjectContextRepositoryPolicies",
                column: "CreatedByUserId");

            migrationBuilder.CreateIndex(
                name: "IX_ProjectContextRepositoryPolicies_RepositoryContextId",
                schema: "DynomaxV2",
                table: "ProjectContextRepositoryPolicies",
                column: "RepositoryContextId",
                unique: true);

            migrationBuilder.CreateIndex(
                name: "IX_ProjectContextRepositoryPolicies_UpdatedByUserId",
                schema: "DynomaxV2",
                table: "ProjectContextRepositoryPolicies",
                column: "UpdatedByUserId");

            migrationBuilder.CreateIndex(
                name: "IX_RepositoryPullRequestLinks_CreatedByUserId",
                schema: "DynomaxV2",
                table: "RepositoryPullRequestLinks",
                column: "CreatedByUserId");

            migrationBuilder.CreateIndex(
                name: "IX_RepositoryPullRequestLinks_RepositoryContextId_Provider_ProviderPullRequestId",
                schema: "DynomaxV2",
                table: "RepositoryPullRequestLinks",
                columns: new[] { "RepositoryContextId", "Provider", "ProviderPullRequestId" },
                unique: true);

            migrationBuilder.CreateIndex(
                name: "IX_RepositoryPullRequestLinks_UpdatedByUserId",
                schema: "DynomaxV2",
                table: "RepositoryPullRequestLinks",
                column: "UpdatedByUserId");

            migrationBuilder.CreateIndex(
                name: "IX_RepositoryPullRequestLinks_WorkSetId_WorkspaceId_State",
                schema: "DynomaxV2",
                table: "RepositoryPullRequestLinks",
                columns: new[] { "WorkSetId", "WorkspaceId", "State" });

            migrationBuilder.CreateIndex(
                name: "IX_RepositoryPullRequestLinks_WorkspaceId",
                schema: "DynomaxV2",
                table: "RepositoryPullRequestLinks",
                column: "WorkspaceId");

            migrationBuilder.CreateIndex(
                name: "IX_RepositoryWorkSets_AgentAccessGrantId",
                schema: "DynomaxV2",
                table: "RepositoryWorkSets",
                column: "AgentAccessGrantId");

            migrationBuilder.CreateIndex(
                name: "IX_RepositoryWorkSets_ChangeManagementActorId",
                schema: "DynomaxV2",
                table: "RepositoryWorkSets",
                column: "ChangeManagementActorId");

            migrationBuilder.CreateIndex(
                name: "IX_RepositoryWorkSets_LinkedProductChangeId",
                schema: "DynomaxV2",
                table: "RepositoryWorkSets",
                column: "LinkedProductChangeId");

            migrationBuilder.CreateIndex(
                name: "IX_RepositoryWorkSets_LinkedProjectIssueId",
                schema: "DynomaxV2",
                table: "RepositoryWorkSets",
                column: "LinkedProjectIssueId");

            migrationBuilder.CreateIndex(
                name: "IX_RepositoryWorkSets_LinkedTestingStepId",
                schema: "DynomaxV2",
                table: "RepositoryWorkSets",
                column: "LinkedTestingStepId");

            migrationBuilder.CreateIndex(
                name: "IX_RepositoryWorkSets_OwnerUserId",
                schema: "DynomaxV2",
                table: "RepositoryWorkSets",
                column: "OwnerUserId");

            migrationBuilder.CreateIndex(
                name: "IX_RepositoryWorkSets_ProjectId_Status_UpdatedAtUtc",
                schema: "DynomaxV2",
                table: "RepositoryWorkSets",
                columns: new[] { "ProjectId", "Status", "UpdatedAtUtc" });

            migrationBuilder.CreateIndex(
                name: "IX_RepositoryWorkspaces_CreatedByUserId",
                schema: "DynomaxV2",
                table: "RepositoryWorkspaces",
                column: "CreatedByUserId");

            migrationBuilder.CreateIndex(
                name: "IX_RepositoryWorkspaces_RepositoryContextId_State_UpdatedAtUtc",
                schema: "DynomaxV2",
                table: "RepositoryWorkspaces",
                columns: new[] { "RepositoryContextId", "State", "UpdatedAtUtc" });

            migrationBuilder.CreateIndex(
                name: "IX_RepositoryWorkspaces_StorageKey",
                schema: "DynomaxV2",
                table: "RepositoryWorkspaces",
                column: "StorageKey",
                unique: true);

            migrationBuilder.CreateIndex(
                name: "IX_RepositoryWorkspaces_UpdatedByUserId",
                schema: "DynomaxV2",
                table: "RepositoryWorkspaces",
                column: "UpdatedByUserId");

            migrationBuilder.CreateIndex(
                name: "IX_RepositoryWorkspaces_WorkSetId_RepositoryContextId",
                schema: "DynomaxV2",
                table: "RepositoryWorkspaces",
                columns: new[] { "WorkSetId", "RepositoryContextId" },
                unique: true);
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropTable(
                name: "ProjectContextRepositoryPolicies",
                schema: "DynomaxV2");

            migrationBuilder.DropTable(
                name: "RepositoryPullRequestLinks",
                schema: "DynomaxV2");

            migrationBuilder.DropTable(
                name: "RepositoryWorkspaces",
                schema: "DynomaxV2");

            migrationBuilder.DropTable(
                name: "ProjectContextRepositories",
                schema: "DynomaxV2");

            migrationBuilder.DropTable(
                name: "RepositoryWorkSets",
                schema: "DynomaxV2");
        }
    }
}
