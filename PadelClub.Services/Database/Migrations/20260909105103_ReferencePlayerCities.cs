using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

#pragma warning disable CA1814 // Prefer jagged arrays over multidimensional

namespace PadelClub.Services.Database.Migrations
{
    /// <inheritdoc />
    public partial class ReferencePlayerCities : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropIndex(
                name: "IX_PlayerProfiles_IsDiscoverable_SkillLevel_City",
                table: "PlayerProfiles");

            migrationBuilder.AddColumn<int>(
                name: "CityId",
                table: "PlayerProfiles",
                type: "int",
                nullable: false,
                defaultValue: 0);

            migrationBuilder.CreateTable(
                name: "Cities",
                columns: table => new
                {
                    Id = table.Column<int>(type: "int", nullable: false)
                        .Annotation("SqlServer:Identity", "1, 1"),
                    Name = table.Column<string>(type: "nvarchar(100)", maxLength: 100, nullable: false),
                    IsActive = table.Column<bool>(type: "bit", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_Cities", x => x.Id);
                });

            migrationBuilder.InsertData(
                table: "Cities",
                columns: new[] { "Id", "IsActive", "Name" },
                values: new object[,]
                {
                    { 1, true, "Sarajevo" },
                    { 2, true, "Mostar" },
                    { 3, true, "Tuzla" },
                    { 4, true, "Zenica" },
                    { 5, true, "Banja Luka" },
                    { 6, true, "Bihać" },
                    { 7, true, "Čapljina" }
                });

            // Preserve every legacy city before replacing the free-text column.
            migrationBuilder.Sql("""
                INSERT INTO Cities (Name, IsActive)
                SELECT DISTINCT p.City, 1 FROM PlayerProfiles p
                WHERE NOT EXISTS (SELECT 1 FROM Cities c WHERE c.Name = p.City);
                UPDATE p SET CityId = c.Id
                FROM PlayerProfiles p INNER JOIN Cities c ON c.Name = p.City;
                """);

            migrationBuilder.DropColumn(
                name: "City",
                table: "PlayerProfiles");

            migrationBuilder.CreateIndex(
                name: "IX_PlayerProfiles_CityId",
                table: "PlayerProfiles",
                column: "CityId");

            migrationBuilder.CreateIndex(
                name: "IX_PlayerProfiles_IsDiscoverable_SkillLevel_CityId",
                table: "PlayerProfiles",
                columns: new[] { "IsDiscoverable", "SkillLevel", "CityId" });

            migrationBuilder.CreateIndex(
                name: "IX_Cities_Name",
                table: "Cities",
                column: "Name",
                unique: true);

            migrationBuilder.AddForeignKey(
                name: "FK_PlayerProfiles_Cities_CityId",
                table: "PlayerProfiles",
                column: "CityId",
                principalTable: "Cities",
                principalColumn: "Id",
                onDelete: ReferentialAction.Restrict);
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropForeignKey(
                name: "FK_PlayerProfiles_Cities_CityId",
                table: "PlayerProfiles");

            migrationBuilder.AddColumn<string>(
                name: "City", table: "PlayerProfiles", type: "nvarchar(100)",
                maxLength: 100, nullable: false, defaultValue: "");
            migrationBuilder.Sql("""
                UPDATE p SET City = c.Name
                FROM PlayerProfiles p INNER JOIN Cities c ON c.Id = p.CityId;
                """);
            migrationBuilder.DropIndex(name: "IX_PlayerProfiles_CityId", table: "PlayerProfiles");
            migrationBuilder.DropIndex(name: "IX_PlayerProfiles_IsDiscoverable_SkillLevel_CityId", table: "PlayerProfiles");
            migrationBuilder.DropColumn(name: "CityId", table: "PlayerProfiles");
            migrationBuilder.DropTable(name: "Cities");

            migrationBuilder.CreateIndex(
                name: "IX_PlayerProfiles_IsDiscoverable_SkillLevel_City",
                table: "PlayerProfiles",
                columns: new[] { "IsDiscoverable", "SkillLevel", "City" });
        }
    }
}
