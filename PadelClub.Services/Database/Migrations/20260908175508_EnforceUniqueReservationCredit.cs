using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace PadelClub.Services.Database.Migrations
{
    /// <inheritdoc />
    public partial class EnforceUniqueReservationCredit : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropIndex(
                name: "IX_AccountCredits_ReservationId",
                table: "AccountCredits");

            migrationBuilder.CreateIndex(
                name: "IX_AccountCredits_ReservationId",
                table: "AccountCredits",
                column: "ReservationId",
                unique: true,
                filter: "[ReservationId] IS NOT NULL");
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropIndex(
                name: "IX_AccountCredits_ReservationId",
                table: "AccountCredits");

            migrationBuilder.CreateIndex(
                name: "IX_AccountCredits_ReservationId",
                table: "AccountCredits",
                column: "ReservationId");
        }
    }
}
