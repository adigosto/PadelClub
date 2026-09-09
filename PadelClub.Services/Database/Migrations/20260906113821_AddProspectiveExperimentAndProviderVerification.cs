using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace PadelClub.Services.Database.Migrations
{
    /// <inheritdoc />
    public partial class AddProspectiveExperimentAndProviderVerification : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AddColumn<Guid>(
                name: "ExperimentAssignmentId",
                table: "RecommendationExposures",
                type: "uniqueidentifier",
                nullable: true);

            migrationBuilder.CreateTable(
                name: "ProviderVerificationAttempts",
                columns: table => new
                {
                    Id = table.Column<long>(type: "bigint", nullable: false)
                        .Annotation("SqlServer:Identity", "1, 1"),
                    CorrelationId = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                    RequestedByUserId = table.Column<int>(type: "int", nullable: false),
                    Provider = table.Column<string>(type: "nvarchar(20)", maxLength: 20, nullable: false),
                    VerificationKind = table.Column<string>(type: "nvarchar(120)", maxLength: 120, nullable: false),
                    Status = table.Column<string>(type: "nvarchar(20)", maxLength: 20, nullable: false),
                    OutcomeCategory = table.Column<string>(type: "nvarchar(60)", maxLength: 60, nullable: false),
                    StartedAtUtc = table.Column<DateTime>(type: "datetime2", nullable: false),
                    CompletedAtUtc = table.Column<DateTime>(type: "datetime2", nullable: true)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_ProviderVerificationAttempts", x => x.Id);
                    table.ForeignKey(
                        name: "FK_ProviderVerificationAttempts_Users_RequestedByUserId",
                        column: x => x.RequestedByUserId,
                        principalTable: "Users",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Restrict);
                });

            migrationBuilder.CreateTable(
                name: "RecommendationAnalyticsConsents",
                columns: table => new
                {
                    UserId = table.Column<int>(type: "int", nullable: false),
                    GrantedAtUtc = table.Column<DateTime>(type: "datetime2", nullable: true),
                    RevokedAtUtc = table.Column<DateTime>(type: "datetime2", nullable: true),
                    PolicyVersion = table.Column<string>(type: "nvarchar(120)", maxLength: 120, nullable: false),
                    UpdatedAtUtc = table.Column<DateTime>(type: "datetime2", nullable: false, defaultValueSql: "SYSUTCDATETIME()")
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_RecommendationAnalyticsConsents", x => x.UserId);
                    table.ForeignKey(
                        name: "FK_RecommendationAnalyticsConsents_Users_UserId",
                        column: x => x.UserId,
                        principalTable: "Users",
                        principalColumn: "Id");
                });

            migrationBuilder.CreateTable(
                name: "RecommendationExperiments",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                    ExperimentKey = table.Column<string>(type: "nvarchar(120)", maxLength: 120, nullable: false),
                    Status = table.Column<string>(type: "nvarchar(20)", maxLength: 20, nullable: false),
                    CreatedByUserId = table.Column<int>(type: "int", nullable: false),
                    CreatedAtUtc = table.Column<DateTime>(type: "datetime2", nullable: false),
                    StartedAtUtc = table.Column<DateTime>(type: "datetime2", nullable: true),
                    ClosedAtUtc = table.Column<DateTime>(type: "datetime2", nullable: true),
                    Protocol = table.Column<string>(type: "nvarchar(120)", maxLength: 120, nullable: false),
                    TreatmentAlgorithmVersion = table.Column<string>(type: "nvarchar(120)", maxLength: 120, nullable: false),
                    ControlAlgorithmVersion = table.Column<string>(type: "nvarchar(120)", maxLength: 120, nullable: false),
                    TreatmentStrategy = table.Column<string>(type: "nvarchar(80)", maxLength: 80, nullable: false),
                    ControlStrategy = table.Column<string>(type: "nvarchar(80)", maxLength: 80, nullable: false),
                    TreatmentAllocationPercent = table.Column<int>(type: "int", nullable: false),
                    RecommendationLimit = table.Column<int>(type: "int", nullable: false),
                    AttributionWindowDays = table.Column<int>(type: "int", nullable: false),
                    ReturnMaturityDays = table.Column<int>(type: "int", nullable: false),
                    ConfigurationSha256 = table.Column<string>(type: "nvarchar(64)", maxLength: 64, nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_RecommendationExperiments", x => x.Id);
                    table.ForeignKey(
                        name: "FK_RecommendationExperiments_Users_CreatedByUserId",
                        column: x => x.CreatedByUserId,
                        principalTable: "Users",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Restrict);
                });

            migrationBuilder.CreateTable(
                name: "RecommendationExperimentAnalysisRuns",
                columns: table => new
                {
                    Id = table.Column<long>(type: "bigint", nullable: false)
                        .Annotation("SqlServer:Identity", "1, 1"),
                    RunId = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                    ExperimentId = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                    ExecutedByUserId = table.Column<int>(type: "int", nullable: false),
                    ExecutedAtUtc = table.Column<DateTime>(type: "datetime2", nullable: false),
                    EvidenceTier = table.Column<string>(type: "nvarchar(30)", maxLength: 30, nullable: false),
                    Protocol = table.Column<string>(type: "nvarchar(120)", maxLength: 120, nullable: false),
                    ConfigurationSha256 = table.Column<string>(type: "nvarchar(64)", maxLength: 64, nullable: false),
                    InputFingerprintSha256 = table.Column<string>(type: "nvarchar(64)", maxLength: 64, nullable: false),
                    ReportJson = table.Column<string>(type: "nvarchar(max)", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_RecommendationExperimentAnalysisRuns", x => x.Id);
                    table.ForeignKey(
                        name: "FK_RecommendationExperimentAnalysisRuns_RecommendationExperiments_ExperimentId",
                        column: x => x.ExperimentId,
                        principalTable: "RecommendationExperiments",
                        principalColumn: "Id");
                    table.ForeignKey(
                        name: "FK_RecommendationExperimentAnalysisRuns_Users_ExecutedByUserId",
                        column: x => x.ExecutedByUserId,
                        principalTable: "Users",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Restrict);
                });

            migrationBuilder.CreateTable(
                name: "RecommendationExperimentAssignments",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                    ExperimentId = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                    UserId = table.Column<int>(type: "int", nullable: false),
                    Variant = table.Column<int>(type: "int", nullable: false),
                    AssignedAtUtc = table.Column<DateTime>(type: "datetime2", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_RecommendationExperimentAssignments", x => x.Id);
                    table.ForeignKey(
                        name: "FK_RecommendationExperimentAssignments_RecommendationExperiments_ExperimentId",
                        column: x => x.ExperimentId,
                        principalTable: "RecommendationExperiments",
                        principalColumn: "Id");
                    table.ForeignKey(
                        name: "FK_RecommendationExperimentAssignments_Users_UserId",
                        column: x => x.UserId,
                        principalTable: "Users",
                        principalColumn: "Id");
                });

            migrationBuilder.CreateIndex(
                name: "IX_RecommendationExposures_ExperimentAssignmentId_ServedAtUtc",
                table: "RecommendationExposures",
                columns: new[] { "ExperimentAssignmentId", "ServedAtUtc" });

            migrationBuilder.CreateIndex(
                name: "IX_ProviderVerificationAttempts_CorrelationId",
                table: "ProviderVerificationAttempts",
                column: "CorrelationId",
                unique: true);

            migrationBuilder.CreateIndex(
                name: "IX_ProviderVerificationAttempts_Provider_StartedAtUtc",
                table: "ProviderVerificationAttempts",
                columns: new[] { "Provider", "StartedAtUtc" });

            migrationBuilder.CreateIndex(
                name: "IX_ProviderVerificationAttempts_RequestedByUserId",
                table: "ProviderVerificationAttempts",
                column: "RequestedByUserId");

            migrationBuilder.CreateIndex(
                name: "IX_RecommendationExperimentAnalysisRuns_ExecutedByUserId",
                table: "RecommendationExperimentAnalysisRuns",
                column: "ExecutedByUserId");

            migrationBuilder.CreateIndex(
                name: "IX_RecommendationExperimentAnalysisRuns_ExperimentId_ExecutedAtUtc",
                table: "RecommendationExperimentAnalysisRuns",
                columns: new[] { "ExperimentId", "ExecutedAtUtc" });

            migrationBuilder.CreateIndex(
                name: "IX_RecommendationExperimentAnalysisRuns_RunId",
                table: "RecommendationExperimentAnalysisRuns",
                column: "RunId",
                unique: true);

            migrationBuilder.CreateIndex(
                name: "IX_RecommendationExperimentAssignments_ExperimentId_UserId",
                table: "RecommendationExperimentAssignments",
                columns: new[] { "ExperimentId", "UserId" },
                unique: true);

            migrationBuilder.CreateIndex(
                name: "IX_RecommendationExperimentAssignments_ExperimentId_Variant_AssignedAtUtc",
                table: "RecommendationExperimentAssignments",
                columns: new[] { "ExperimentId", "Variant", "AssignedAtUtc" });

            migrationBuilder.CreateIndex(
                name: "IX_RecommendationExperimentAssignments_UserId",
                table: "RecommendationExperimentAssignments",
                column: "UserId");

            migrationBuilder.CreateIndex(
                name: "IX_RecommendationExperiments_CreatedByUserId",
                table: "RecommendationExperiments",
                column: "CreatedByUserId");

            migrationBuilder.CreateIndex(
                name: "IX_RecommendationExperiments_ExperimentKey",
                table: "RecommendationExperiments",
                column: "ExperimentKey",
                unique: true);

            migrationBuilder.CreateIndex(
                name: "IX_RecommendationExperiments_Status",
                table: "RecommendationExperiments",
                column: "Status",
                unique: true,
                filter: "[Status] = N'Running'");

            migrationBuilder.AddForeignKey(
                name: "FK_RecommendationExposures_RecommendationExperimentAssignments_ExperimentAssignmentId",
                table: "RecommendationExposures",
                column: "ExperimentAssignmentId",
                principalTable: "RecommendationExperimentAssignments",
                principalColumn: "Id");
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropForeignKey(
                name: "FK_RecommendationExposures_RecommendationExperimentAssignments_ExperimentAssignmentId",
                table: "RecommendationExposures");

            migrationBuilder.DropTable(
                name: "ProviderVerificationAttempts");

            migrationBuilder.DropTable(
                name: "RecommendationAnalyticsConsents");

            migrationBuilder.DropTable(
                name: "RecommendationExperimentAnalysisRuns");

            migrationBuilder.DropTable(
                name: "RecommendationExperimentAssignments");

            migrationBuilder.DropTable(
                name: "RecommendationExperiments");

            migrationBuilder.DropIndex(
                name: "IX_RecommendationExposures_ExperimentAssignmentId_ServedAtUtc",
                table: "RecommendationExposures");

            migrationBuilder.DropColumn(
                name: "ExperimentAssignmentId",
                table: "RecommendationExposures");
        }
    }
}
