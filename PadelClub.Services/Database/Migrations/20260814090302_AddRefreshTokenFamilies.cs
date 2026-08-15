using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace PadelClub.Services.Database.Migrations
{
    /// <inheritdoc />
    public partial class AddRefreshTokenFamilies : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AddColumn<string>(
                name: "FamilyId",
                table: "AuthTokens",
                type: "nvarchar(32)",
                maxLength: 32,
                nullable: true);

            migrationBuilder.CreateIndex(
                name: "IX_AuthTokens_FamilyId",
                table: "AuthTokens",
                column: "FamilyId");
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropIndex(
                name: "IX_AuthTokens_FamilyId",
                table: "AuthTokens");

            migrationBuilder.DropColumn(
                name: "FamilyId",
                table: "AuthTokens");
        }
    }
}
