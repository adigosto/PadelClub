using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace PadelClub.Services.Database.Migrations
{
    /// <inheritdoc />
    public partial class AddRecommendationImpactAndMessagingReliability : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AddColumn<DateTime>(
                name: "LeaseExpiresAtUtc",
                table: "OutboxMessages",
                type: "datetime2",
                nullable: true);

            migrationBuilder.AddColumn<Guid>(
                name: "LeaseId",
                table: "OutboxMessages",
                type: "uniqueidentifier",
                nullable: true);

            migrationBuilder.CreateTable(
                name: "InboxMessages",
                columns: table => new
                {
                    Id = table.Column<long>(type: "bigint", nullable: false)
                        .Annotation("SqlServer:Identity", "1, 1"),
                    Consumer = table.Column<string>(type: "nvarchar(120)", maxLength: 120, nullable: false),
                    EventId = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                    MessageType = table.Column<string>(type: "nvarchar(120)", maxLength: 120, nullable: false),
                    ReceivedAtUtc = table.Column<DateTime>(type: "datetime2", nullable: false, defaultValueSql: "SYSUTCDATETIME()")
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_InboxMessages", x => x.Id);
                });

            migrationBuilder.CreateTable(
                name: "RecommendationExposures",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                    UserId = table.Column<int>(type: "int", nullable: false),
                    ProductId = table.Column<int>(type: "int", nullable: false),
                    AlgorithmVersion = table.Column<string>(type: "nvarchar(120)", maxLength: 120, nullable: false),
                    Strategy = table.Column<string>(type: "nvarchar(80)", maxLength: 80, nullable: false),
                    Rank = table.Column<int>(type: "int", nullable: false),
                    ServedAtUtc = table.Column<DateTime>(type: "datetime2", nullable: false),
                    ClickedAtUtc = table.Column<DateTime>(type: "datetime2", nullable: true),
                    PurchasedOrderId = table.Column<int>(type: "int", nullable: true),
                    PurchasedAtUtc = table.Column<DateTime>(type: "datetime2", nullable: true)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_RecommendationExposures", x => x.Id);
                    table.ForeignKey(
                        name: "FK_RecommendationExposures_Orders_PurchasedOrderId",
                        column: x => x.PurchasedOrderId,
                        principalTable: "Orders",
                        principalColumn: "Id");
                    table.ForeignKey(
                        name: "FK_RecommendationExposures_Products_ProductId",
                        column: x => x.ProductId,
                        principalTable: "Products",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "FK_RecommendationExposures_Users_UserId",
                        column: x => x.UserId,
                        principalTable: "Users",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Restrict);
                });

            migrationBuilder.CreateIndex(
                name: "IX_OutboxMessages_PublishedAtUtc_NextAttemptAtUtc_LeaseExpiresAtUtc",
                table: "OutboxMessages",
                columns: new[] { "PublishedAtUtc", "NextAttemptAtUtc", "LeaseExpiresAtUtc" });

            migrationBuilder.CreateIndex(
                name: "IX_InboxMessages_Consumer_EventId",
                table: "InboxMessages",
                columns: new[] { "Consumer", "EventId" },
                unique: true);

            migrationBuilder.CreateIndex(
                name: "IX_InboxMessages_ReceivedAtUtc",
                table: "InboxMessages",
                column: "ReceivedAtUtc");

            migrationBuilder.CreateIndex(
                name: "IX_RecommendationExposures_ProductId_ServedAtUtc",
                table: "RecommendationExposures",
                columns: new[] { "ProductId", "ServedAtUtc" });

            migrationBuilder.CreateIndex(
                name: "IX_RecommendationExposures_PurchasedOrderId",
                table: "RecommendationExposures",
                column: "PurchasedOrderId");

            migrationBuilder.CreateIndex(
                name: "IX_RecommendationExposures_UserId_ServedAtUtc",
                table: "RecommendationExposures",
                columns: new[] { "UserId", "ServedAtUtc" });
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropTable(
                name: "InboxMessages");

            migrationBuilder.DropTable(
                name: "RecommendationExposures");

            migrationBuilder.DropIndex(
                name: "IX_OutboxMessages_PublishedAtUtc_NextAttemptAtUtc_LeaseExpiresAtUtc",
                table: "OutboxMessages");

            migrationBuilder.DropColumn(
                name: "LeaseExpiresAtUtc",
                table: "OutboxMessages");

            migrationBuilder.DropColumn(
                name: "LeaseId",
                table: "OutboxMessages");
        }
    }
}
