using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace PadelClub.Services.Database.Migrations
{
    /// <inheritdoc />
    public partial class AddOperationalRecommendationEvidence : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AddColumn<int>(
                name: "Origin",
                table: "Orders",
                type: "int",
                nullable: false,
                defaultValue: 0);

            // Existing non-demo rows have no independently verifiable source;
            // keep their default UnverifiedLegacy value. Known deterministic
            // seeds stay useful for the local recommender demo, but are
            // explicitly labelled SeedDemo rather than operational evidence.
            migrationBuilder.Sql(
                "UPDATE [Orders] SET [Origin] = 1 WHERE [IsSeededForDemo] = CAST(1 AS bit) OR [OrderNumber] LIKE N'DEMO-%';");

            migrationBuilder.CreateTable(
                name: "OutboxMessages",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                    Type = table.Column<string>(type: "nvarchar(120)", maxLength: 120, nullable: false),
                    Payload = table.Column<string>(type: "nvarchar(max)", nullable: false),
                    OccurredAtUtc = table.Column<DateTime>(type: "datetime2", nullable: false),
                    PublishedAtUtc = table.Column<DateTime>(type: "datetime2", nullable: true),
                    AttemptCount = table.Column<int>(type: "int", nullable: false),
                    NextAttemptAtUtc = table.Column<DateTime>(type: "datetime2", nullable: false),
                    LastError = table.Column<string>(type: "nvarchar(2000)", maxLength: 2000, nullable: true)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_OutboxMessages", x => x.Id);
                });

            migrationBuilder.CreateTable(
                name: "RecommendationEvaluationRuns",
                columns: table => new
                {
                    Id = table.Column<long>(type: "bigint", nullable: false)
                        .Annotation("SqlServer:Identity", "1, 1"),
                    RunId = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                    ExecutedByUserId = table.Column<int>(type: "int", nullable: false),
                    ExecutedAtUtc = table.Column<DateTime>(type: "datetime2", nullable: false),
                    EvidenceSource = table.Column<string>(type: "nvarchar(40)", maxLength: 40, nullable: false),
                    EvidenceTier = table.Column<string>(type: "nvarchar(20)", maxLength: 20, nullable: false),
                    Protocol = table.Column<string>(type: "nvarchar(120)", maxLength: 120, nullable: false),
                    AlgorithmVersion = table.Column<string>(type: "nvarchar(120)", maxLength: 120, nullable: false),
                    ConfigurationSha256 = table.Column<string>(type: "nvarchar(64)", maxLength: 64, nullable: false),
                    InputFingerprintSha256 = table.Column<string>(type: "nvarchar(64)", maxLength: 64, nullable: false),
                    CutoffUtc = table.Column<DateTime>(type: "datetime2", nullable: false),
                    EndUtc = table.Column<DateTime>(type: "datetime2", nullable: false),
                    K = table.Column<int>(type: "int", nullable: false),
                    ReturnMaturityDays = table.Column<int>(type: "int", nullable: false),
                    EligibleDeliveredOrders = table.Column<int>(type: "int", nullable: false),
                    TrainingSignals = table.Column<int>(type: "int", nullable: false),
                    HoldoutSignals = table.Column<int>(type: "int", nullable: false),
                    CandidateProducts = table.Column<int>(type: "int", nullable: false),
                    EvaluatedUsers = table.Column<int>(type: "int", nullable: false),
                    ReportJson = table.Column<string>(type: "nvarchar(max)", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_RecommendationEvaluationRuns", x => x.Id);
                    table.ForeignKey(
                        name: "FK_RecommendationEvaluationRuns_Users_ExecutedByUserId",
                        column: x => x.ExecutedByUserId,
                        principalTable: "Users",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Restrict);
                });

            migrationBuilder.CreateIndex(
                name: "IX_OutboxMessages_OccurredAtUtc",
                table: "OutboxMessages",
                column: "OccurredAtUtc");

            migrationBuilder.CreateIndex(
                name: "IX_OutboxMessages_PublishedAtUtc_NextAttemptAtUtc",
                table: "OutboxMessages",
                columns: new[] { "PublishedAtUtc", "NextAttemptAtUtc" });

            migrationBuilder.CreateIndex(
                name: "IX_Orders_Status_Origin_DeliveredAt",
                table: "Orders",
                columns: new[] { "Status", "Origin", "DeliveredAt" });

            migrationBuilder.CreateIndex(
                name: "IX_RecommendationEvaluationRuns_EvidenceSource_ExecutedAtUtc",
                table: "RecommendationEvaluationRuns",
                columns: new[] { "EvidenceSource", "ExecutedAtUtc" });

            migrationBuilder.CreateIndex(
                name: "IX_RecommendationEvaluationRuns_ExecutedAtUtc",
                table: "RecommendationEvaluationRuns",
                column: "ExecutedAtUtc");

            migrationBuilder.CreateIndex(
                name: "IX_RecommendationEvaluationRuns_ExecutedByUserId",
                table: "RecommendationEvaluationRuns",
                column: "ExecutedByUserId");

            migrationBuilder.CreateIndex(
                name: "IX_RecommendationEvaluationRuns_RunId",
                table: "RecommendationEvaluationRuns",
                column: "RunId",
                unique: true);
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropTable(
                name: "OutboxMessages");

            migrationBuilder.DropTable(
                name: "RecommendationEvaluationRuns");

            migrationBuilder.DropIndex(
                name: "IX_Orders_Status_Origin_DeliveredAt",
                table: "Orders");

            migrationBuilder.DropColumn(
                name: "Origin",
                table: "Orders");
        }
    }
}
