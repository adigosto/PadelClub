using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace PadelClub.Services.Database.Migrations
{
    /// <inheritdoc />
    public partial class AddTournamentAndMembershipLifecycle : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AddColumn<int>(
                name: "Seed",
                table: "TournamentParticipants",
                type: "int",
                nullable: true);

            migrationBuilder.AddColumn<int>(
                name: "TeamNumber",
                table: "TournamentParticipants",
                type: "int",
                nullable: true);

            migrationBuilder.AddColumn<bool>(
                name: "AutoRenew",
                table: "Memberships",
                type: "bit",
                nullable: false,
                defaultValue: false);

            migrationBuilder.AddColumn<bool>(
                name: "CancelAtPeriodEnd",
                table: "Memberships",
                type: "bit",
                nullable: false,
                defaultValue: false);

            migrationBuilder.AddColumn<DateTime>(
                name: "CancelledAt",
                table: "Memberships",
                type: "datetime2",
                nullable: true);

            migrationBuilder.AddColumn<string>(
                name: "Status",
                table: "Memberships",
                type: "nvarchar(30)",
                maxLength: 30,
                nullable: false,
                defaultValue: "");

            migrationBuilder.AddColumn<DateTime>(
                name: "SuspendedAt",
                table: "Memberships",
                type: "datetime2",
                nullable: true);

            migrationBuilder.AddColumn<int>(
                name: "BracketPosition",
                table: "Matches",
                type: "int",
                nullable: true);

            migrationBuilder.AddColumn<int>(
                name: "BracketRound",
                table: "Matches",
                type: "int",
                nullable: true);

            migrationBuilder.AddColumn<bool>(
                name: "IsBye",
                table: "Matches",
                type: "bit",
                nullable: false,
                defaultValue: false);

            migrationBuilder.AddColumn<int>(
                name: "NextMatchId",
                table: "Matches",
                type: "int",
                nullable: true);

            migrationBuilder.AddColumn<int>(
                name: "NextMatchTeamNumber",
                table: "Matches",
                type: "int",
                nullable: true);

            migrationBuilder.CreateTable(
                name: "MembershipEvents",
                columns: table => new
                {
                    Id = table.Column<long>(type: "bigint", nullable: false)
                        .Annotation("SqlServer:Identity", "1, 1"),
                    MembershipId = table.Column<int>(type: "int", nullable: false),
                    EventType = table.Column<string>(type: "nvarchar(40)", maxLength: 40, nullable: false),
                    Notes = table.Column<string>(type: "nvarchar(500)", maxLength: 500, nullable: false),
                    ActorUserId = table.Column<int>(type: "int", nullable: true),
                    CreatedAt = table.Column<DateTime>(type: "datetime2", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_MembershipEvents", x => x.Id);
                    table.ForeignKey(
                        name: "FK_MembershipEvents_Memberships_MembershipId",
                        column: x => x.MembershipId,
                        principalTable: "Memberships",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Cascade);
                });

            migrationBuilder.CreateIndex(
                name: "IX_TournamentParticipants_TournamentId_TeamNumber",
                table: "TournamentParticipants",
                columns: new[] { "TournamentId", "TeamNumber" });

            migrationBuilder.CreateIndex(
                name: "IX_Memberships_Status_EndDate",
                table: "Memberships",
                columns: new[] { "Status", "EndDate" });

            migrationBuilder.CreateIndex(
                name: "IX_Matches_NextMatchId",
                table: "Matches",
                column: "NextMatchId");

            migrationBuilder.CreateIndex(
                name: "IX_Matches_TournamentId_BracketRound_BracketPosition",
                table: "Matches",
                columns: new[] { "TournamentId", "BracketRound", "BracketPosition" },
                unique: true,
                filter: "[BracketRound] IS NOT NULL AND [BracketPosition] IS NOT NULL");

            migrationBuilder.CreateIndex(
                name: "IX_MembershipEvents_MembershipId_CreatedAt",
                table: "MembershipEvents",
                columns: new[] { "MembershipId", "CreatedAt" });

            migrationBuilder.AddForeignKey(
                name: "FK_Matches_Matches_NextMatchId",
                table: "Matches",
                column: "NextMatchId",
                principalTable: "Matches",
                principalColumn: "Id");
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropForeignKey(
                name: "FK_Matches_Matches_NextMatchId",
                table: "Matches");

            migrationBuilder.DropTable(
                name: "MembershipEvents");

            migrationBuilder.DropIndex(
                name: "IX_TournamentParticipants_TournamentId_TeamNumber",
                table: "TournamentParticipants");

            migrationBuilder.DropIndex(
                name: "IX_Memberships_Status_EndDate",
                table: "Memberships");

            migrationBuilder.DropIndex(
                name: "IX_Matches_NextMatchId",
                table: "Matches");

            migrationBuilder.DropIndex(
                name: "IX_Matches_TournamentId_BracketRound_BracketPosition",
                table: "Matches");

            migrationBuilder.DropColumn(
                name: "Seed",
                table: "TournamentParticipants");

            migrationBuilder.DropColumn(
                name: "TeamNumber",
                table: "TournamentParticipants");

            migrationBuilder.DropColumn(
                name: "AutoRenew",
                table: "Memberships");

            migrationBuilder.DropColumn(
                name: "CancelAtPeriodEnd",
                table: "Memberships");

            migrationBuilder.DropColumn(
                name: "CancelledAt",
                table: "Memberships");

            migrationBuilder.DropColumn(
                name: "Status",
                table: "Memberships");

            migrationBuilder.DropColumn(
                name: "SuspendedAt",
                table: "Memberships");

            migrationBuilder.DropColumn(
                name: "BracketPosition",
                table: "Matches");

            migrationBuilder.DropColumn(
                name: "BracketRound",
                table: "Matches");

            migrationBuilder.DropColumn(
                name: "IsBye",
                table: "Matches");

            migrationBuilder.DropColumn(
                name: "NextMatchId",
                table: "Matches");

            migrationBuilder.DropColumn(
                name: "NextMatchTeamNumber",
                table: "Matches");
        }
    }
}
