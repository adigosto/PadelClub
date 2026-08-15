using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace PadelClub.Services.Database.Migrations
{
    /// <inheritdoc />
    public partial class AddPlayerExperience : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AddColumn<string>(
                name: "ProposedScore",
                table: "Matches",
                type: "nvarchar(100)",
                maxLength: 100,
                nullable: true);

            migrationBuilder.AddColumn<int>(
                name: "ProposedWinnerTeamId",
                table: "Matches",
                type: "int",
                nullable: true);

            migrationBuilder.AddColumn<int>(
                name: "ReportedByUserId",
                table: "Matches",
                type: "int",
                nullable: true);

            migrationBuilder.AddColumn<DateTime>(
                name: "ResultConfirmedAt",
                table: "Matches",
                type: "datetime2",
                nullable: true);

            migrationBuilder.AddColumn<DateTime>(
                name: "ResultReportedAt",
                table: "Matches",
                type: "datetime2",
                nullable: true);

            migrationBuilder.AddColumn<string>(
                name: "ResultStatus",
                table: "Matches",
                type: "nvarchar(30)",
                maxLength: 30,
                nullable: false,
                defaultValue: "");

            migrationBuilder.AddColumn<int>(
                name: "TeamOneRatingChange",
                table: "Matches",
                type: "int",
                nullable: true);

            migrationBuilder.AddColumn<int>(
                name: "TeamTwoRatingChange",
                table: "Matches",
                type: "int",
                nullable: true);

            migrationBuilder.CreateTable(
                name: "PartnerInvitations",
                columns: table => new
                {
                    Id = table.Column<int>(type: "int", nullable: false)
                        .Annotation("SqlServer:Identity", "1, 1"),
                    SenderUserId = table.Column<int>(type: "int", nullable: false),
                    RecipientUserId = table.Column<int>(type: "int", nullable: false),
                    Message = table.Column<string>(type: "nvarchar(500)", maxLength: 500, nullable: false),
                    Status = table.Column<string>(type: "nvarchar(20)", maxLength: 20, nullable: false),
                    CreatedAt = table.Column<DateTime>(type: "datetime2", nullable: false),
                    RespondedAt = table.Column<DateTime>(type: "datetime2", nullable: true)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_PartnerInvitations", x => x.Id);
                    table.ForeignKey(
                        name: "FK_PartnerInvitations_Users_RecipientUserId",
                        column: x => x.RecipientUserId,
                        principalTable: "Users",
                        principalColumn: "Id");
                    table.ForeignKey(
                        name: "FK_PartnerInvitations_Users_SenderUserId",
                        column: x => x.SenderUserId,
                        principalTable: "Users",
                        principalColumn: "Id");
                });

            migrationBuilder.CreateTable(
                name: "PlayerProfiles",
                columns: table => new
                {
                    Id = table.Column<int>(type: "int", nullable: false)
                        .Annotation("SqlServer:Identity", "1, 1"),
                    UserId = table.Column<int>(type: "int", nullable: false),
                    SkillLevel = table.Column<string>(type: "nvarchar(30)", maxLength: 30, nullable: false),
                    PreferredSide = table.Column<string>(type: "nvarchar(20)", maxLength: 20, nullable: false),
                    City = table.Column<string>(type: "nvarchar(100)", maxLength: 100, nullable: false),
                    Bio = table.Column<string>(type: "nvarchar(500)", maxLength: 500, nullable: false),
                    Availability = table.Column<string>(type: "nvarchar(300)", maxLength: 300, nullable: false),
                    IsDiscoverable = table.Column<bool>(type: "bit", nullable: false),
                    Rating = table.Column<int>(type: "int", nullable: false),
                    UpdatedAt = table.Column<DateTime>(type: "datetime2", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_PlayerProfiles", x => x.Id);
                    table.ForeignKey(
                        name: "FK_PlayerProfiles_Users_UserId",
                        column: x => x.UserId,
                        principalTable: "Users",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Cascade);
                });

            migrationBuilder.CreateIndex(
                name: "IX_PartnerInvitations_RecipientUserId",
                table: "PartnerInvitations",
                column: "RecipientUserId");

            migrationBuilder.CreateIndex(
                name: "IX_PartnerInvitations_SenderUserId_RecipientUserId_Status",
                table: "PartnerInvitations",
                columns: new[] { "SenderUserId", "RecipientUserId", "Status" });

            migrationBuilder.CreateIndex(
                name: "IX_PlayerProfiles_IsDiscoverable_SkillLevel_City",
                table: "PlayerProfiles",
                columns: new[] { "IsDiscoverable", "SkillLevel", "City" });

            migrationBuilder.CreateIndex(
                name: "IX_PlayerProfiles_UserId",
                table: "PlayerProfiles",
                column: "UserId",
                unique: true);
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropTable(
                name: "PartnerInvitations");

            migrationBuilder.DropTable(
                name: "PlayerProfiles");

            migrationBuilder.DropColumn(
                name: "ProposedScore",
                table: "Matches");

            migrationBuilder.DropColumn(
                name: "ProposedWinnerTeamId",
                table: "Matches");

            migrationBuilder.DropColumn(
                name: "ReportedByUserId",
                table: "Matches");

            migrationBuilder.DropColumn(
                name: "ResultConfirmedAt",
                table: "Matches");

            migrationBuilder.DropColumn(
                name: "ResultReportedAt",
                table: "Matches");

            migrationBuilder.DropColumn(
                name: "ResultStatus",
                table: "Matches");

            migrationBuilder.DropColumn(
                name: "TeamOneRatingChange",
                table: "Matches");

            migrationBuilder.DropColumn(
                name: "TeamTwoRatingChange",
                table: "Matches");
        }
    }
}
