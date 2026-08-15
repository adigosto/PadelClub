using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace PadelClub.Services.Database.Migrations
{
    /// <inheritdoc />
    public partial class AddBookingLifecycle : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AddColumn<DateTime>(
                name: "CancelledAt",
                table: "Reservations",
                type: "datetime2",
                nullable: true);

            migrationBuilder.AddColumn<bool>(
                name: "IsNoShow",
                table: "Reservations",
                type: "bit",
                nullable: false,
                defaultValue: false);

            migrationBuilder.AddColumn<Guid>(
                name: "SeriesId",
                table: "Reservations",
                type: "uniqueidentifier",
                nullable: true);

            migrationBuilder.CreateTable(
                name: "AccountCredits",
                columns: table => new
                {
                    Id = table.Column<int>(type: "int", nullable: false)
                        .Annotation("SqlServer:Identity", "1, 1"),
                    UserId = table.Column<int>(type: "int", nullable: false),
                    ReservationId = table.Column<int>(type: "int", nullable: true),
                    Amount = table.Column<decimal>(type: "decimal(18,2)", nullable: false),
                    Reason = table.Column<string>(type: "nvarchar(300)", maxLength: 300, nullable: false),
                    CreatedAt = table.Column<DateTime>(type: "datetime2", nullable: false),
                    UsedAt = table.Column<DateTime>(type: "datetime2", nullable: true)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_AccountCredits", x => x.Id);
                    table.ForeignKey(
                        name: "FK_AccountCredits_Reservations_ReservationId",
                        column: x => x.ReservationId,
                        principalTable: "Reservations",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.SetNull);
                    table.ForeignKey(
                        name: "FK_AccountCredits_Users_UserId",
                        column: x => x.UserId,
                        principalTable: "Users",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Cascade);
                });

            migrationBuilder.CreateTable(
                name: "MaintenanceBlocks",
                columns: table => new
                {
                    Id = table.Column<int>(type: "int", nullable: false)
                        .Annotation("SqlServer:Identity", "1, 1"),
                    CourtId = table.Column<int>(type: "int", nullable: true),
                    StartTimeUtc = table.Column<DateTime>(type: "datetime2", nullable: false),
                    EndTimeUtc = table.Column<DateTime>(type: "datetime2", nullable: false),
                    Reason = table.Column<string>(type: "nvarchar(500)", maxLength: 500, nullable: false),
                    IsActive = table.Column<bool>(type: "bit", nullable: false),
                    CreatedAt = table.Column<DateTime>(type: "datetime2", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_MaintenanceBlocks", x => x.Id);
                    table.ForeignKey(
                        name: "FK_MaintenanceBlocks_Courts_CourtId",
                        column: x => x.CourtId,
                        principalTable: "Courts",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Cascade);
                });

            migrationBuilder.CreateTable(
                name: "WaitlistEntries",
                columns: table => new
                {
                    Id = table.Column<int>(type: "int", nullable: false)
                        .Annotation("SqlServer:Identity", "1, 1"),
                    CourtId = table.Column<int>(type: "int", nullable: false),
                    UserId = table.Column<int>(type: "int", nullable: false),
                    StartTimeUtc = table.Column<DateTime>(type: "datetime2", nullable: false),
                    EndTimeUtc = table.Column<DateTime>(type: "datetime2", nullable: false),
                    Status = table.Column<string>(type: "nvarchar(30)", maxLength: 30, nullable: false),
                    CreatedAt = table.Column<DateTime>(type: "datetime2", nullable: false),
                    PromotedAt = table.Column<DateTime>(type: "datetime2", nullable: true)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_WaitlistEntries", x => x.Id);
                    table.ForeignKey(
                        name: "FK_WaitlistEntries_Courts_CourtId",
                        column: x => x.CourtId,
                        principalTable: "Courts",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "FK_WaitlistEntries_Users_UserId",
                        column: x => x.UserId,
                        principalTable: "Users",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Cascade);
                });

            migrationBuilder.CreateIndex(
                name: "IX_Reservations_SeriesId",
                table: "Reservations",
                column: "SeriesId");

            migrationBuilder.CreateIndex(
                name: "IX_AccountCredits_ReservationId",
                table: "AccountCredits",
                column: "ReservationId");

            migrationBuilder.CreateIndex(
                name: "IX_AccountCredits_UserId",
                table: "AccountCredits",
                column: "UserId");

            migrationBuilder.CreateIndex(
                name: "IX_MaintenanceBlocks_CourtId_StartTimeUtc_EndTimeUtc",
                table: "MaintenanceBlocks",
                columns: new[] { "CourtId", "StartTimeUtc", "EndTimeUtc" });

            migrationBuilder.CreateIndex(
                name: "IX_WaitlistEntries_CourtId_StartTimeUtc_EndTimeUtc_Status",
                table: "WaitlistEntries",
                columns: new[] { "CourtId", "StartTimeUtc", "EndTimeUtc", "Status" });

            migrationBuilder.CreateIndex(
                name: "IX_WaitlistEntries_UserId_CourtId_StartTimeUtc_EndTimeUtc",
                table: "WaitlistEntries",
                columns: new[] { "UserId", "CourtId", "StartTimeUtc", "EndTimeUtc" },
                unique: true);
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropTable(
                name: "AccountCredits");

            migrationBuilder.DropTable(
                name: "MaintenanceBlocks");

            migrationBuilder.DropTable(
                name: "WaitlistEntries");

            migrationBuilder.DropIndex(
                name: "IX_Reservations_SeriesId",
                table: "Reservations");

            migrationBuilder.DropColumn(
                name: "CancelledAt",
                table: "Reservations");

            migrationBuilder.DropColumn(
                name: "IsNoShow",
                table: "Reservations");

            migrationBuilder.DropColumn(
                name: "SeriesId",
                table: "Reservations");
        }
    }
}
